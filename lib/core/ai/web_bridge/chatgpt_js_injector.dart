import 'dart:convert';

/// Utilities and JavaScript scripts for injecting into ChatGPT Web (chatgpt.com)
class ChatGptJsInjector {
  /// Wraps user query with Ritmo's Persona, Context (RAG/Goals/Routines) and System Directives
  static String formatPromptWithSystemDirective({
    required String userPrompt,
    String? personaTitle,
    String? personaSystemPrompt,
    String? userName,
    String? contextSummary,
    List<String>? recentHistory,
  }) {
    final systemDirective = personaSystemPrompt?.trim().isNotEmpty == true
        ? personaSystemPrompt!.trim()
        : 'شما دستیار هوشمند و اختصاصی اپلیکیشن «ریتمو» (Ritmo AI) هستید. وظیفه شما راهنمایی دقیق، دلسوزانه، مختصر و کاربردی به زبان فارسی در زمینه مدیریت روتین‌ها، اهداف، سبک زندگی و برنامه‌ریزی روزانه کاربر است. قوانین: ۱. همیشه به زبان فارسی روان و شمرده پاسخ دهید. ۲. از تعارفات زائد پرهیز کنید و مستقیماً به اصل موضوع بپردازید. ۳. پاسخ‌ها را ساختاریافته و با بولت‌پوینت‌های کوتاه ارائه دهید.';

    final userContext = (userName != null && userName.trim().isNotEmpty)
        ? 'نام کاربر مخاطب شما: «${userName.trim()}» است. در مکالمات در صورت لزوم کاربر را با همین نام محترمانه خطاب قرار دهید.\n'
        : '';

    final contextBlock = (contextSummary != null && contextSummary.trim().isNotEmpty)
        ? '\n[اطلاعات پرونده و وضعیت جاری کاربر]:\n${contextSummary.trim()}\n'
        : '';

    final historyBlock = (recentHistory != null && recentHistory.isNotEmpty)
        ? '\n[تاریخچه آخرین پیام‌های مکالمه]:\n${recentHistory.join('\n')}\n'
        : '';

    return '''
[دستورالعمل سیستم ریتمو]:
$userContext$systemDirective$contextBlock$historyBlock
[درخواست جدید کاربر]:
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

  // --- 4. Pure Content Extractor Directly from Markdown/Prose Body ---
  function isUserPromptText(text) {
    if (!text) return true;
    if (text.indexOf('[دستورالعمل سیستم ریتمو]') !== -1 ||
        text.indexOf('[درخواست جدید کاربر]') !== -1 ||
        text.indexOf('[تاریخچه آخرین پیام') !== -1 ||
        text.indexOf('[داده‌های بازیابی‌شده]') !== -1 ||
        text.indexOf('نام کاربر مخاطب شما:') !== -1 ||
        text.indexOf('قوانین قطعی:') !== -1) {
      return true;
    }
    return false;
  }

  function extractCleanText(el) {
    if (!el) return '';
    
    // Quick rejection if element is explicitly marked as user
    if (el.getAttribute && el.getAttribute('data-message-author-role') === 'user') return '';
    if (el.querySelector && (el.querySelector('[data-message-author-role="user"]') || el.querySelector('button[aria-label*="Edit"], button[aria-label*="ویرایش"]'))) return '';

    // Directly target the pure markdown/content element inside the assistant container
    var contentEl = (el.matches && (el.matches('.markdown, .prose, [data-conversation-part="body"], [data-assistant-writing-block-body]') || el.matches('div[class*="markdown"], div[class*="prose"]')))
        ? el
        : (el.querySelector('[data-conversation-part="body"], [data-assistant-writing-block-body], .markdown, .prose, div[class*="markdown"], div[class*="prose"], div.whitespace-pre-wrap') || el);

    // Read native innerText directly from the live connected DOM element
    var rawText = (contentEl.innerText || contentEl.textContent || '').trim();

    // Reject if this text contains the user's prompt or system instructions
    if (isUserPromptText(rawText)) return '';

    // Strip CSS artifacts if any
    if (rawText.indexOf('[data-conversation-') !== -1 || rawText.indexOf('--component-') !== -1) {
      rawText = rawText.replace(/\[data-[^\]]+\]\s*\{[^}]*\}/g, '');
      rawText = rawText.replace(/--[a-zA-Z0-9_-]+:[^;]+;?/g, '');
    }

    // Strip any leading author header (e.g. ChatGPT said:)
    rawText = rawText.replace(/^[•\-\*\s:]*(ChatGPT\s*said:?|:ChatGPT\s*said:?|ChatGPT:?|You\s*said:?|:You\s*said:?|Assistant\s*said:?)[\s:]*/gmi, '');
    return rawText.trim();
  }

  function findLatestAssistantText() {
    try {
      // 1. Direct Markdown/Prose blocks inside assistant messages (highest priority)
      var markdowns = document.querySelectorAll('[data-message-author-role="assistant"] .markdown, [data-message-author-role="assistant"] .prose, [data-message-author-role="assistant"] [data-conversation-part="body"], [data-message-author-role="assistant"] [data-assistant-writing-block-body]');
      for (var m = markdowns.length - 1; m >= 0; m--) {
        var t = extractCleanText(markdowns[m]);
        if (t && !isUserPromptText(t)) return t;
      }

      // 2. Explicit assistant role container
      var assistants = document.querySelectorAll('[data-message-author-role="assistant"]');
      for (var a = assistants.length - 1; a >= 0; a--) {
        var t = extractCleanText(assistants[a]);
        if (t && !isUserPromptText(t)) return t;
      }

      // 3. Assistant action bar (Copy / Share / Thumbs buttons)
      var copyBtns = document.querySelectorAll('button[aria-label*="Copy"], button[aria-label*="کپی"], button[data-testid*="copy"], button[aria-label*="Read aloud"], button[aria-label*="Good response"]');
      for (var c = copyBtns.length - 1; c >= 0; c--) {
        var btn = copyBtns[c];
        var parentTurn = btn.closest('article, [data-testid*="conversation-turn"], div[class*="agent-turn"], div[class*="text-base"]');
        if (parentTurn) {
          var t = extractCleanText(parentTurn);
          if (t && !isUserPromptText(t)) return t;
        }
      }

      // 4. Articles from bottom up excluding user
      var articles = document.querySelectorAll('article, [data-testid*="conversation-turn-"]');
      for (var i = articles.length - 1; i >= 0; i--) {
        var art = articles[i];
        var isUser = (art.getAttribute('data-message-author-role') === 'user') ||
                     !!art.querySelector('[data-message-author-role="user"]') ||
                     !!art.querySelector('button[aria-label*="Edit"], button[aria-label*="ویرایش"]');
        if (!isUser) {
          var t = extractCleanText(art);
          if (t && !isUserPromptText(t)) return t;
        }
      }
    } catch (e) {
      console.warn('[Ritmo] findLatestAssistantText error:', e);
    }
    return '';
  }

  var streamCheckTimer = null;
  var lastLength = 0;
  var lastText = '';
  var lastChangeTimestamp = Date.now();
  var streamStartTime = 0;

  window.__ritmo_startStreamingWatcher = function(previousBaselineText) {
    lastLength = 0;
    lastText = '';
    lastChangeTimestamp = Date.now();
    streamStartTime = Date.now();
    previousBaselineText = (previousBaselineText || '').trim();

    if (streamCheckTimer) clearInterval(streamCheckTimer);

    streamCheckTimer = setInterval(function() {
      var totalDuration = Date.now() - streamStartTime;
      var currentText = findLatestAssistantText();

      // If no new text yet, check for timeout
      if (!currentText || currentText === previousBaselineText) {
        if (totalDuration > 30000) {
          clearInterval(streamCheckTimer);
          streamCheckTimer = null;
          notifyFlutter('error', { message: 'پاسخی از ChatGPT دریافت نشد.' });
        }
        return;
      }

      // New/growing assistant text detected!
      if (currentText !== lastText && currentText.length > 0) {
        var delta = '';
        if (currentText.length > lastLength) {
          delta = currentText.substring(lastLength);
        } else {
          delta = currentText;
        }
        lastText = currentText;
        lastLength = currentText.length;
        lastChangeTimestamp = Date.now();
        notifyFlutter('chunk', { delta: delta, fullText: currentText });
      }

      var stopButton = document.querySelector(
        'button[data-testid="stop-button"], button[aria-label="Stop generating"], button[aria-label="توقف تولید"], button[data-testid="fruitjuice-stop-button"]'
      );
      var isStreamingClass = document.querySelector('.result-streaming');
      var timeSinceLastChange = Date.now() - lastChangeTimestamp;

      if (!stopButton && !isStreamingClass && lastLength > 0 && timeSinceLastChange > 800) {
        var finalFullText = findLatestAssistantText() || currentText;
        clearInterval(streamCheckTimer);
        streamCheckTimer = null;
        notifyFlutter('done', { fullText: finalFullText });
        console.log('[Ritmo] Stream completed with ' + finalFullText.length + ' characters');
      } else if (totalDuration > 70000) {
        var finalFullText = findLatestAssistantText() || currentText;
        clearInterval(streamCheckTimer);
        streamCheckTimer = null;
        if (finalFullText.length > 0) {
          notifyFlutter('done', { fullText: finalFullText });
        } else {
          notifyFlutter('error', { message: 'زمان انتظار برای پاسخ به پایان رسید.' });
        }
      }
    }, 100);
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

        // Snapshot assistant text BEFORE sending
        var previousBaselineText = findLatestAssistantText();

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
            window.__ritmo_startStreamingWatcher(previousBaselineText);
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
            window.__ritmo_startStreamingWatcher(previousBaselineText);
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
