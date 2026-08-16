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
  /// Sets up bridge listeners, MutationObserver for streaming deltas, and Cloudflare detection.
  static String get setupBridgeScript => r'''
(function() {
  if (window.__RITMO_BRIDGE_INITIALIZED__) return;
  window.__RITMO_BRIDGE_INITIALIZED__ = true;

  console.log('[Ritmo] Initializing ChatGPT Web Bridge...');

  // Safe PostMessage to Flutter JavascriptChannel 'RitmoChatBridge'
  function notifyFlutter(type, payload) {
    try {
      if (window.RitmoChatBridge && window.RitmoChatBridge.postMessage) {
        window.RitmoChatBridge.postMessage(JSON.stringify({ type: type, ...payload }));
      }
    } catch(e) {
      console.error('[Ritmo] Error posting to Flutter:', e);
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
        'stay logged out',
        'continue without logging in',
        'continue logged out',
        'continue as guest',
        'not now',
        'dismiss',
        'close',
        'accept essential cookies',
        'قبول همه',
        'موافقم',
        'تایید',
        'ادامه بدون ورود',
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

      var dialogs = document.querySelectorAll('div[role="dialog"], [data-state="open"]');
      for (var d = 0; d < dialogs.length; d++) {
        var dlg = dialogs[d];
        var dlgText = (dlg.innerText || '').toLowerCase();
        if (dlgText.includes('log in') || dlgText.includes('sign up') || dlgText.includes('welcome back')) {
          var closeBtn = dlg.querySelector('button[aria-label*="Close"], button[aria-label*="بستن"], button[data-testid*="close"], button.close');
          if (closeBtn && closeBtn.offsetParent !== null) {
            closeBtn.click();
            console.log('[Ritmo] Auto-closed login modal via close button');
          }
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
        'button[aria-label="Close sidebar"], button[aria-label="Close navigation"], button[data-testid="close-sidebar-button"], button[aria-label*="Close"], button[aria-label="بستن منو"]'
      );
      if (closeBtn && isVisiblyOnScreen(closeBtn)) {
        return true;
      }

      var backdrop = document.querySelector(
        'div.fixed.inset-0.bg-black\\/50, div.fixed.inset-0.bg-black, div.fixed.inset-0.bg-token-main-surface-primary'
      );
      if (backdrop && isVisiblyOnScreen(backdrop)) {
        return true;
      }

      var navDrawer = document.querySelector('#headlessui-dialog-panel, nav[aria-label="Chat history"], div[data-state="open"]');
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
        'button[aria-label="Close sidebar"], button[aria-label="Close navigation"], button[data-testid="close-sidebar-button"], button[aria-label*="Close"], button[aria-label="بستن منو"], button[aria-label="بستن"]'
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
        'div.fixed.inset-0.bg-black\\/50, div.fixed.inset-0.bg-black, div.fixed.inset-0.bg-token-main-surface-primary, div[class*="backdrop"]'
      );
      for (var j = 0; j < backdrops.length; j++) {
        var bd = backdrops[j];
        if (bd && isVisiblyOnScreen(bd)) {
          bd.click();
          console.log('[Ritmo] Auto-closed sidebar via backdrop click');
          return;
        }
      }

      var navDrawer = document.querySelector('#headlessui-dialog-panel, nav[aria-label="Chat history"]');
      if (navDrawer && isVisiblyOnScreen(navDrawer)) {
        var clickX = window.innerWidth - 15;
        var clickY = Math.min(window.innerHeight / 2, 300);
        var outsideEl = document.elementFromPoint(clickX, clickY);
        if (outsideEl && !navDrawer.contains(outsideEl)) {
          outsideEl.dispatchEvent(new MouseEvent('click', { bubbles: true, cancelable: true }));
          console.log('[Ritmo] Clicked outside sidebar panel');
        }
      }
    } catch (e) {
      console.warn('[Ritmo] Auto-close sidebar error:', e);
    }
  }

  // Initial check on bridge setup
  checkCloudflareStatus();
  autoDismissCookiesAndModals();
  autoCloseSidebar();

  // --- 4. Multi-Turn Live Assistant Message Streamer ---
  function getAssistantElements() {
    return document.querySelectorAll(
      '[data-message-author-role="assistant"], ' +
      'div[data-testid*="conversation-turn-"]:not([data-testid*="user"]), ' +
      'article:not(:has([data-message-author-role="user"])), ' +
      '.agent-turn, ' +
      'div.markdown, ' +
      'div.prose'
    );
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
  var lastChangeTimestamp = Date.now();
  var streamStartTime = 0;

  window.__ritmo_startStreamingWatcher = function(initialAssistantCount) {
    lastLength = 0;
    lastChangeTimestamp = Date.now();
    streamStartTime = Date.now();
    initialAssistantCount = initialAssistantCount || 0;

    if (streamCheckTimer) clearInterval(streamCheckTimer);

    streamCheckTimer = setInterval(function() {
      var allCandidates = getAssistantElements();

      // Only inspect the NEW assistant message that appeared after this prompt
      if (allCandidates.length <= initialAssistantCount) {
        // New assistant message hasn't appeared yet
        return;
      }

      var targetEl = allCandidates[allCandidates.length - 1];
      var currentText = extractCleanText(targetEl);

      if (currentText.length > lastLength) {
        var delta = currentText.substring(lastLength);
        lastLength = currentText.length;
        lastChangeTimestamp = Date.now();
        notifyFlutter('chunk', { delta: delta, fullText: currentText });
      }

      // Check completion criteria:
      var stopButton = document.querySelector(
        'button[data-testid="stop-button"], ' +
        'button[aria-label="Stop generating"], ' +
        'button[aria-label="توقف تولید"], ' +
        'button[data-testid="fruitjuice-stop-button"]'
      );
      var isStreamingClass = document.querySelector('.result-streaming');
      var timeSinceLastChange = Date.now() - lastChangeTimestamp;
      var totalDuration = Date.now() - streamStartTime;

      if (!stopButton && !isStreamingClass && lastLength > 0 && timeSinceLastChange > 1200) {
        clearInterval(streamCheckTimer);
        streamCheckTimer = null;
        notifyFlutter('done', { fullText: currentText });
        console.log('[Ritmo] Multi-turn stream completed with ' + lastLength + ' characters');
      } else if (totalDuration > 45000 && lastLength > 0) {
        clearInterval(streamCheckTimer);
        streamCheckTimer = null;
        notifyFlutter('done', { fullText: currentText });
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
               document.querySelector('form button[type="submit"]') ||
               document.querySelector('button[data-testid="composer-speech-button"] + button');
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

        // Record initial count of assistant messages for multi-turn isolation
        var initialAssistantCount = getAssistantElements().length;

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

        // Wait 600ms for React/ProseMirror state to update and enable send button
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
            window.__ritmo_startStreamingWatcher(initialAssistantCount);
          } else if (sendCheckAttempts >= 8) {
            clearInterval(sendInterval);
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
            window.__ritmo_startStreamingWatcher(initialAssistantCount);
          }
        }, 250);
      }

    } catch (e) {
      notifyFlutter('error', { message: 'خطا در ارسال پرامپت: ' + e.toString() });
    }
  };

  console.log('[Ritmo] Bridge setup complete.');
  notifyFlutter('ready', { status: 'ok' });
})();
''';

  /// Generates the call to send a specific formatted prompt
  static String buildSendPromptScript(String prompt) {
    final encoded = jsonEncode(prompt);
    return 'if (window.__ritmo_sendPrompt) { window.__ritmo_sendPrompt($encoded); } else { console.error("Ritmo bridge not ready"); }';
  }
}
