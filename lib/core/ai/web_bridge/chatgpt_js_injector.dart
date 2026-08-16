import 'dart:convert';

/// Utilities and JavaScript scripts for injecting into ChatGPT Web (chatgpt.com)
class ChatGptJsInjector {
  /// Wraps user query with Ritmo's Persona and System Directives
  static String formatPromptWithSystemDirective({
    required String userPrompt,
    String? personaTitle,
    String? personaSystemPrompt,
    String? userName,
  }) {
    final systemDirective = personaSystemPrompt?.trim().isNotEmpty == true
        ? personaSystemPrompt!.trim()
        : 'شما دستیار هوشمند و اختصاصی اپلیکیشن «ریتمو» (Ritmo AI) هستید. وظیفه شما راهنمایی دقیق، دلسوزانه، مختصر و کاربردی به زبان فارسی در زمینه مدیریت روتین‌ها، اهداف، سبک زندگی و برنامه‌ریزی روزانه کاربر است. قوانین: ۱. همیشه به زبان فارسی روان و شمرده پاسخ دهید. ۲. از تعارفات زائد پرهیز کنید و مستقیماً به اصل موضوع بپردازید. ۳. پاسخ‌ها را ساختاریافته و با بولت‌پوینت‌های کوتاه ارائه دهید.';

    final userContext = (userName != null && userName.trim().isNotEmpty)
        ? 'نام کاربر مخاطب شما: «${userName.trim()}» است. در مکالمات در صورت لزوم کاربر را با همین نام محترمانه خطاب قرار دهید.\n'
        : '';

    return '''
[دستورالعمل سیستم ریتمو]:
$userContext$systemDirective

[درخواست کاربر]:
$userPrompt
'''.trim();
  }

  /// Master JavaScript injected once page finishes loading.
  /// Sets up bridge listeners, the streaming watcher, and Cloudflare detection.
  static String get setupBridgeScript => r'''
(function() {
  if (window.__RITMO_BRIDGE_INITIALIZED__) return;
  window.__RITMO_BRIDGE_INITIALIZED__ = true;

  console.log('[Ritmo] Initializing ChatGPT Web Bridge...');

  // Safe PostMessage to Flutter JavascriptChannel 'RitmoChatBridge'.
  // NOTE: the payload is SPREAD into the envelope, so every field lands at the
  // top level. The Dart side reads it from there.
  function notifyFlutter(type, payload) {
    try {
      if (window.RitmoChatBridge && window.RitmoChatBridge.postMessage) {
        window.RitmoChatBridge.postMessage(JSON.stringify({ type: type, ...payload }));
      }
    } catch(e) {
      console.error('[Ritmo] Error posting to Flutter:', e);
    }
  }

  // A selector that the current WebView cannot parse makes querySelectorAll
  // throw for the ENTIRE list, taking the caller down with it. Never query raw.
  function queryAllSafe(selector) {
    try {
      var r = document.querySelectorAll(selector);
      return r ? Array.prototype.slice.call(r) : [];
    } catch (e) {
      console.warn('[Ritmo] Unsupported selector skipped:', selector);
      return [];
    }
  }

  // --- 1. Cloudflare Turnstile & Security Challenge Watcher ---
  var lastCfState = null;
  function checkCloudflareStatus() {
    var title = document.title || '';
    var isCfTitle = title.includes('Just a moment') || title.includes('Security Check') || title.includes('Cloudflare') || title.includes('Attention Required');
    var hasCfIframe = !!document.querySelector('iframe[src*="cloudflare"], iframe[src*="challenges.cloudflare.com"], #cf-turnstile, #challenge-stage, #challenge-running, .cf-turnstile-wrapper');
    var isChallenged = isCfTitle || hasCfIframe;

    if (isChallenged !== lastCfState) {
      lastCfState = isChallenged;
      if (isChallenged) {
        notifyFlutter('cloudflare_challenge', { detected: true, title: title });
      } else {
        notifyFlutter('cloudflare_resolved', { detected: false });
      }
    }
    return isChallenged;
  }

  // --- 2. Auto Cookie Consent & Login Modal Dismissal ---
  function autoDismissCookiesAndModals() {
    try {
      var directSelectors = [
        '#onetrust-accept-btn-handler',
        '#onetrust-pc-btn-handler',
        '#accept-recommended-btn-handler',
        'button[id*="onetrust-accept"]',
        'button[data-testid="accept-cookies"]',
        'button[data-testid="cookie-banner-accept"]',
        'button[data-testid="close-button"]',
        '.osano-cm-accept-all',
        '.cc-btn.cc-allow',
        '#cookie-accept',
        '.cookie-accept'
      ];

      for (var i = 0; i < directSelectors.length; i++) {
        var el = document.querySelector(directSelectors[i]);
        if (el && el.offsetParent !== null) {
          el.click();
          console.log('[Ritmo] Auto-clicked cookie accept button:', directSelectors[i]);
        }
      }

      var buttons = document.querySelectorAll('button, div[role="button"], a[role="button"], a');
      var dismissKeywords = [
        'accept all',
        'accept cookies',
        'accept all cookies',
        'allow all',
        'allow all cookies',
        'accept',
        'i accept',
        'got it',
        'agree',
        'not now',
        'dismiss',
        'close',
        'accept essential cookies',
        'قبول همه',
        'موافقم',
        'تایید',
        'بستن'
      ];

      for (var j = 0; j < buttons.length; j++) {
        var btn = buttons[j];
        if (btn.offsetParent === null) continue;
        var txt = (btn.innerText || btn.textContent || '').trim().toLowerCase();
        if (dismissKeywords.indexOf(txt) !== -1) {
          btn.click();
          console.log('[Ritmo] Auto-clicked modal/cookie dismiss button by text:', txt);
        }
      }

      var bannerContainers = document.querySelectorAll('#onetrust-banner-sdk, #onetrust-consent-sdk, .onetrust-pc-dark-filter, .cookie-banner');
      for (var k = 0; k < bannerContainers.length; k++) {
        bannerContainers[k].style.display = 'none';
      }
    } catch (e) {
      console.warn('[Ritmo] Modal/Cookie auto-dismiss error:', e);
    }
  }

  // --- 3. Auto Close Sidebar / Drawer ---
  function isVisiblyOnScreen(el) {
    if (!el) return false;
    var rect = el.getBoundingClientRect();
    var style = window.getComputedStyle(el);
    return (
      style.display !== 'none' &&
      style.visibility !== 'hidden' &&
      style.opacity !== '0' &&
      rect.width > 20 &&
      rect.height > 20 &&
      rect.right > 0 &&
      rect.left < window.innerWidth &&
      el.getAttribute('aria-hidden') !== 'true'
    );
  }

  function isSidebarOpen() {
    try {
      var closeBtn = document.querySelector(
        'button[aria-label="Close sidebar"], button[aria-label="Close navigation"], button[data-testid="close-sidebar-button"], button[aria-label="بستن منو"]'
      );
      if (closeBtn && isVisiblyOnScreen(closeBtn)) {
        return true;
      }

      var backdrop = document.querySelector(
        'div.fixed.inset-0.bg-black\\/50, div.fixed.inset-0.bg-black'
      );
      if (backdrop && isVisiblyOnScreen(backdrop)) {
        return true;
      }

      var navDrawer = document.querySelector('#headlessui-dialog-panel, nav[aria-label="Chat history"]');
      if (navDrawer && isVisiblyOnScreen(navDrawer)) {
        var rect = navDrawer.getBoundingClientRect();
        if (rect.left >= 0 && rect.right > 50) {
          return true;
        }
      }
    } catch (e) {}
    return false;
  }

  function autoCloseSidebar() {
    try {
      if (!isSidebarOpen()) return;

      var closeBtns = document.querySelectorAll(
        'button[aria-label="Close sidebar"], button[aria-label="Close navigation"], button[data-testid="close-sidebar-button"], button[aria-label="بستن منو"]'
      );
      for (var i = 0; i < closeBtns.length; i++) {
        var btn = closeBtns[i];
        if (btn && isVisiblyOnScreen(btn)) {
          btn.click();
          console.log('[Ritmo] Auto-closed sidebar via close button');
          return;
        }
      }

      var backdrops = document.querySelectorAll(
        'div.fixed.inset-0.bg-black\\/50, div.fixed.inset-0.bg-black, div[class*="backdrop"]'
      );
      for (var j = 0; j < backdrops.length; j++) {
        var bd = backdrops[j];
        if (bd && isVisiblyOnScreen(bd)) {
          bd.click();
          console.log('[Ritmo] Auto-closed sidebar via backdrop click');
          return;
        }
      }
    } catch (e) {
      console.warn('[Ritmo] Auto-close sidebar error:', e);
    }
  }

  // --- 4. Live Assistant Message Streamer ---
  //
  // The selector MUST be assistant-only and MUST yield one node per turn.
  // The previous union broke both rules: div[data-testid*="conversation-turn-"]
  // also matched the USER's turn (testids are conversation-turn-2, -3, ... so
  // the :not([data-testid*="user"]) guard never fired) and div.markdown /
  // div.prose added that same turn's descendants. The watcher therefore locked
  // onto the user's own prompt and the real answer never grew past it.
  //
  // Families are tried in priority order; the first non-empty one wins. The
  // baseline count is only meaningful inside one family, so the family index
  // travels with it.
  var ASSISTANT_SELECTORS = [
    '[data-message-author-role="assistant"]',
    '.agent-turn',
    'div.markdown',
    'div.prose'
  ];

  function getAssistantTurns() {
    for (var i = 0; i < ASSISTANT_SELECTORS.length; i++) {
      var nodes = queryAllSafe(ASSISTANT_SELECTORS[i]);
      if (nodes.length) return { nodes: nodes, family: i };
    }
    return { nodes: [], family: -1 };
  }

  function extractCleanText(el) {
    if (!el) return '';
    var textContainer = el.querySelector('.markdown, .prose, div[class*="markdown"], div[class*="prose"], div.whitespace-pre-wrap') || el;
    var clone = textContainer.cloneNode(true);
    var noisy = clone.querySelectorAll('button, svg, nav, [aria-label*="Copy"], [aria-label*="کپی"], .sr-only');
    for (var i = 0; i < noisy.length; i++) {
      noisy[i].remove();
    }
    return (clone.innerText || clone.textContent || '').trim();
  }

  var streamCheckTimer = null;
  var lastLength = 0;
  var lastText = '';
  var currentTargetEl = null;
  var lastChangeTimestamp = Date.now();
  var streamStartTime = 0;

  // No assistant turn within this window means the send never landed (login
  // wall, challenge, disabled composer). Report it instead of spinning.
  var NO_REPLY_TIMEOUT_MS = 40000;
  // Absolute ceiling for one generation.
  var HARD_TIMEOUT_MS = 90000;

  function stopWatcher() {
    if (streamCheckTimer) clearInterval(streamCheckTimer);
    streamCheckTimer = null;
  }

  window.__ritmo_startStreamingWatcher = function(initialAssistantCount, initialFamily) {
    lastLength = 0;
    lastText = '';
    currentTargetEl = null;
    lastChangeTimestamp = Date.now();
    streamStartTime = Date.now();
    initialAssistantCount = initialAssistantCount || 0;
    if (typeof initialFamily !== 'number') initialFamily = -1;

    stopWatcher();

    streamCheckTimer = setInterval(function() {
      var totalDuration = Date.now() - streamStartTime;
      var snap = getAssistantTurns();

      // Comparing counts across two different families is meaningless: a
      // div.prose matched on the welcome screen would otherwise set a baseline
      // that the first real assistant turn can never beat.
      var baseline = (snap.family === initialFamily) ? initialAssistantCount : 0;

      if (snap.nodes.length <= baseline) {
        if (totalDuration > NO_REPLY_TIMEOUT_MS) {
          stopWatcher();
          notifyFlutter('error', { message: 'پاسخی از ChatGPT دریافت نشد. ممکن است نیاز به ورود به حساب یا تایید امنیتی باشد.' });
        }
        return;
      }

      var targetEl = snap.nodes[snap.nodes.length - 1];

      // React can swap the node mid-stream, and the first pass may still be
      // looking at a carry-over from the previous turn. Restart the bookkeeping
      // on identity change -- otherwise a shorter new answer never emits,
      // because lastLength still holds the previous element's length.
      if (targetEl !== currentTargetEl) {
        currentTargetEl = targetEl;
        lastLength = 0;
        lastText = '';
      }

      var currentText = extractCleanText(targetEl);

      if (currentText !== lastText) {
        // ChatGPT re-renders markdown while streaming, so growth is not always a
        // clean append. Only claim a delta on a real prefix extension; fullText
        // rides along every time so Flutter can reconcile either way.
        var isExtension = currentText.length > lastLength && currentText.indexOf(lastText) === 0;
        var delta = isExtension ? currentText.substring(lastLength) : '';
        lastText = currentText;
        lastLength = currentText.length;
        lastChangeTimestamp = Date.now();
        notifyFlutter('chunk', { delta: delta, fullText: currentText });
      }

      var stopButton = document.querySelector(
        'button[data-testid="stop-button"], ' +
        'button[aria-label="Stop generating"], ' +
        'button[aria-label="توقف تولید"], ' +
        'button[data-testid="fruitjuice-stop-button"]'
      );
      var isStreamingClass = document.querySelector('.result-streaming');
      var timeSinceLastChange = Date.now() - lastChangeTimestamp;

      if (!stopButton && !isStreamingClass && lastLength > 0 && timeSinceLastChange > 1200) {
        stopWatcher();
        notifyFlutter('done', { fullText: currentText });
        console.log('[Ritmo] Stream completed with ' + lastLength + ' characters');
      } else if (totalDuration > HARD_TIMEOUT_MS) {
        // Deliberately NOT gated on lastLength > 0. The old escape hatch was,
        // so a page that produced nothing kept this interval alive forever and
        // the chat waited on a stream that could never close.
        stopWatcher();
        if (lastLength > 0) {
          notifyFlutter('done', { fullText: currentText });
        } else {
          notifyFlutter('error', { message: 'زمان انتظار برای پاسخ ChatGPT به پایان رسید.' });
        }
      }
    }, 150);
  };

  // --- 5. Prompt Sender Implementation ---
  window.__ritmo_sendPrompt = function(promptText) {
    try {
      function findTextarea() {
        return document.querySelector('#prompt-textarea') ||
               document.querySelector('textarea') ||
               document.querySelector('div[contenteditable="true"]') ||
               document.querySelector('.ProseMirror');
      }

      function findSendButton() {
        return document.querySelector('button[data-testid="send-button"]') ||
               document.querySelector('button[data-testid="fruitjuice-send-button"]') ||
               document.querySelector('button[aria-label="Send prompt"]') ||
               document.querySelector('button[aria-label="ارسال پیام"]') ||
               document.querySelector('form button[type="submit"]');
      }

      var textarea = findTextarea();
      if (!textarea) {
        var waitCount = 0;
        var pageWaitInterval = setInterval(function() {
          textarea = findTextarea();
          waitCount++;
          if (textarea) {
            clearInterval(pageWaitInterval);
            injectAndTriggerSend(textarea, promptText);
          } else if (waitCount > 20) {
            clearInterval(pageWaitInterval);
            notifyFlutter('error', { message: 'فیلد ورودی متن ChatGPT هنوز لود نشده است.' });
          }
        }, 500);
        return;
      }

      injectAndTriggerSend(textarea, promptText);

      function injectAndTriggerSend(editor, text) {
        autoCloseSidebar();
        autoDismissCookiesAndModals();

        // Snapshot BEFORE sending, so the watcher can tell the new answer apart
        // from everything already on the page. Family travels with the count.
        var before = getAssistantTurns();
        var initialAssistantCount = before.nodes.length;
        var initialFamily = before.family;

        editor.focus();

        if (editor.tagName && editor.tagName.toLowerCase() === 'textarea') {
          var nativeSetter = Object.getOwnPropertyDescriptor(window.HTMLTextAreaElement.prototype, 'value').set;
          if (nativeSetter) {
            nativeSetter.call(editor, text);
          } else {
            editor.value = text;
          }
          editor.dispatchEvent(new Event('input', { bubbles: true }));
          editor.dispatchEvent(new Event('change', { bubbles: true }));
        } else {
          editor.focus();
          document.execCommand('selectAll', false, null);
          document.execCommand('delete', false, null);
          var inserted = document.execCommand('insertText', false, text);
          if (!inserted || (editor.innerText || '').trim() === '') {
            while (editor.firstChild) editor.removeChild(editor.firstChild);
            var p = document.createElement('p');
            p.textContent = text;
            editor.appendChild(p);
            editor.dispatchEvent(new InputEvent('input', { bubbles: true, inputType: 'insertText', data: text }));
          }
          editor.dispatchEvent(new Event('input', { bubbles: true }));
          editor.dispatchEvent(new Event('change', { bubbles: true }));
        }

        var sendCheckAttempts = 0;
        var sendInterval = setInterval(function() {
          sendCheckAttempts++;
          var sendBtn = findSendButton();

          if (sendBtn && !sendBtn.disabled) {
            clearInterval(sendInterval);
            sendBtn.dispatchEvent(new PointerEvent('pointerdown', { bubbles: true }));
            sendBtn.dispatchEvent(new MouseEvent('mousedown', { bubbles: true }));
            sendBtn.dispatchEvent(new PointerEvent('pointerup', { bubbles: true }));
            sendBtn.dispatchEvent(new MouseEvent('mouseup', { bubbles: true }));
            sendBtn.click();
            console.log('[Ritmo] Send button clicked successfully!');
            window.__ritmo_startStreamingWatcher(initialAssistantCount, initialFamily);
          } else if (sendCheckAttempts >= 8) {
            clearInterval(sendInterval);
            // The composer never enabled the send button. Enter is the last
            // resort; if it does not land either, the watcher's 40s no-reply
            // branch reports it rather than hanging.
            editor.focus();
            var enterDown = new KeyboardEvent('keydown', {
              bubbles: true,
              cancelable: true,
              key: 'Enter',
              code: 'Enter',
              keyCode: 13,
              which: 13
            });
            editor.dispatchEvent(enterDown);
            console.log('[Ritmo] Fallback Enter key dispatched');
            window.__ritmo_startStreamingWatcher(initialAssistantCount, initialFamily);
          }
        }, 250);
      }

    } catch (e) {
      notifyFlutter('error', { message: 'خطا در ارسال پرامپت: ' + e.toString() });
    }
  };

  // Initial pass, then keep watching. A single call could only ever catch a
  // challenge that was already on screen at injection time, and it made
  // cloudflare_resolved unreachable.
  var challengedAtBoot = checkCloudflareStatus();
  autoDismissCookiesAndModals();
  autoCloseSidebar();
  setInterval(checkCloudflareStatus, 2000);

  console.log('[Ritmo] Bridge setup complete.');

  // Do NOT report ready while a challenge is up. This used to be the last
  // unconditional statement of the script, and the Dart 'ready' handler clears
  // the Cloudflare flag -- so the challenge raised a few lines earlier was
  // wiped out instantly and the modal could never appear.
  if (!challengedAtBoot) {
    notifyFlutter('ready', { status: 'ok' });
  } else {
    console.warn('[Ritmo] Cloudflare challenge active at boot; withholding ready.');
  }
})();
''';

  /// Generates the call to send a specific formatted prompt
  static String buildSendPromptScript(String prompt) {
    final encoded = jsonEncode(prompt);
    return 'if (window.__ritmo_sendPrompt) { window.__ritmo_sendPrompt($encoded); } else { console.error("Ritmo bridge not ready"); }';
  }
}
