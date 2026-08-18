import 'dart:convert';

/// Utilities and JavaScript scripts for injecting into ChatGPT Web (chatgpt.com)
class ChatGptJsInjector {
  /// Source of truth version for the JavaScript bridge script.
  static const int bridgeVersion = 7;

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
  static String get setupBridgeScript => '''
(function() {
  var requiredVersion = $bridgeVersion;
  var currentVersion = window.__RITMO_BRIDGE_V;

  // Safe PostMessage to Flutter JavascriptChannel 'RitmoChatBridge'.
  function notifyFlutter(type, payload) {
    try {
      var data = {};
      data.type = type;
      if (payload && typeof payload === 'object') {
        for (var k in payload) {
          if (Object.prototype.hasOwnProperty.call(payload, k)) {
            data[k] = payload[k];
          }
        }
      }
      var jsonStr = JSON.stringify(data);
      if (window.RitmoChatBridge && window.RitmoChatBridge.postMessage) {
        window.RitmoChatBridge.postMessage(jsonStr);
      }
    } catch(e) {
      console.error('[Ritmo] Error posting to Flutter:', e);
    }
  }

  function checkComposerPresent() {
    return !!(
      document.querySelector('#prompt-textarea') ||
      document.querySelector('textarea') ||
      document.querySelector('div[contenteditable="true"]') ||
      document.querySelector('.ProseMirror')
    );
  }

  // Idempotent guard: if the current document is already running this exact bridge version,
  // report warm readiness immediately and do not duplicate listeners or watchers.
  if (currentVersion === requiredVersion) {
    console.log('[Ritmo] Bridge already active at version ' + requiredVersion + ' (warm document).');
    notifyFlutter('ready', {
      version: requiredVersion,
      isWarm: true,
      currentPath: window.location.pathname || '',
      hasComposer: checkComposerPresent()
    });
    return;
  }

  // If a previous different bridge version was present, clean up existing timers.
  if (typeof window.__ritmo_cleanup === 'function') {
    try {
      window.__ritmo_cleanup();
    } catch (e) {
      console.warn('[Ritmo] Cleanup of prior bridge instance threw:', e);
    }
  }

  window.__RITMO_BRIDGE_V = requiredVersion;
  console.log('[Ritmo] Initializing ChatGPT Web Bridge version ' + requiredVersion + '...');
$_bridgeScriptBody''';

  static const String _bridgeScriptBody = r'''
  // --- 0. Global Fetch Interceptor Hook ---
  var originalFetch = window.fetch;
  if (originalFetch && !window.__ritmo_fetch_hooked) {
    window.__ritmo_fetch_hooked = true;
    window.__ritmo_original_fetch = originalFetch;
    window.fetch = function() {
      var args = arguments;
      var url = (args[0] && typeof args[0] === 'string') ? args[0] : (args[0] && args[0].url) ? args[0].url : '';
      var isConvo = typeof url === 'string' && (
        url.indexOf('/backend-api/conversation') !== -1 ||
        url.indexOf('/backend-anon/conversation') !== -1 ||
        url.indexOf('/backend-api/lat/r') !== -1 ||
        url.indexOf('/backend-anon/lat/r') !== -1
      );

      if (isConvo) {
        console.log('[Ritmo] Intercepted conversation network request: ' + url);
        notifyFlutter('network_conversation_started', {
          url: url,
          timestamp: Date.now(),
          source: 'fetch'
        });
      }

      try {
        return originalFetch.apply(this, args);
      } catch (e) {
        console.error('[Ritmo] Error executing original fetch:', e);
        throw e;
      }
    };
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

  // --- 4. Robust Live Assistant Text Extractor ---
  function extractCleanText(el) {
    if (!el) return '';
    
    var target = el.querySelector('.markdown, .prose, [class*="markdown"], [class*="prose"], [data-conversation-part="body"], [data-assistant-writing-block-body], div.whitespace-pre-wrap') || el;
    var rawText = (target.innerText || target.textContent || '').trim();
    
    if (!rawText && el !== target) {
      rawText = (el.innerText || el.textContent || '').trim();
    }
    
    if (!rawText) return '';

    rawText = rawText.replace(/^[•\-\*\s:]*(ChatGPT\s*said:?|:ChatGPT\s*said:?|ChatGPT:?|You\s*said:?|:You\s*said:?|Assistant\s*said:?)[\s:]*/gmi, '');
    rawText = rawText.replace(/^[•\-\*\s:]+/g, '');
    
    if (rawText.indexOf('[data-conversation-') !== -1 || rawText.indexOf('--component-') !== -1) {
      rawText = rawText.replace(/\[data-[^\]]+\]\s*\{[^}]*\}/g, '');
      rawText = rawText.replace(/--[a-zA-Z0-9_-]+:[^;]+;?/g, '');
    }
    return rawText.trim();
  }

  function findLatestAssistantText() {
    try {
      var assistants = document.querySelectorAll('[data-message-author-role="assistant"]');
      if (assistants && assistants.length > 0) {
        var lastAssistant = assistants[assistants.length - 1];
        var t = extractCleanText(lastAssistant);
        if (t) return t;
      }

      var markdowns = document.querySelectorAll('div.markdown, div.prose, [class*="markdown"], [class*="prose"]');
      for (var j = markdowns.length - 1; j >= 0; j--) {
        var md = markdowns[j];
        var isUser = !!md.closest('[data-message-author-role="user"], [data-testid*="user"], div.font-user-message');
        if (!isUser) {
          var t = extractCleanText(md);
          if (t) return t;
        }
      }

      var articles = document.querySelectorAll('article, [data-testid*="conversation-turn-"]');
      for (var i = articles.length - 1; i >= 0; i--) {
        var art = articles[i];
        var isUser = !!art.querySelector('[data-message-author-role="user"]') ||
                     (art.getAttribute('data-testid') || '').indexOf('user') !== -1;
        if (!isUser) {
          var t = extractCleanText(art);
          if (t) return t;
        }
      }
    } catch (e) {
      console.warn('[Ritmo] findLatestAssistantText error:', e);
    }
    return '';
  }

  var streamCheckTimer = null;
  var cfCheckTimer = null;
  var lastLength = 0;
  var lastText = '';
  var lastChangeTimestamp = Date.now();
  var streamStartTime = 0;

  window.__ritmo_cleanup = function() {
    if (streamCheckTimer) {
      clearInterval(streamCheckTimer);
      streamCheckTimer = null;
    }
    if (cfCheckTimer) {
      clearInterval(cfCheckTimer);
      cfCheckTimer = null;
    }
    if (window.__ritmo_fetch_hooked && window.__ritmo_original_fetch) {
      window.fetch = window.__ritmo_original_fetch;
      window.__ritmo_fetch_hooked = false;
    }
  };

  window.__ritmo_startStreamingWatcher = function(previousBaselineText, reqId) {
    lastLength = 0;
    lastText = '';
    lastChangeTimestamp = Date.now();
    streamStartTime = Date.now();
    previousBaselineText = (previousBaselineText || '').trim();

    if (streamCheckTimer) clearInterval(streamCheckTimer);

    streamCheckTimer = setInterval(function() {
      var totalDuration = Date.now() - streamStartTime;
      var currentText = findLatestAssistantText();

      if (!currentText || currentText === previousBaselineText) {
        if (totalDuration > 35000) {
          clearInterval(streamCheckTimer);
          streamCheckTimer = null;
          notifyFlutter('error', { message: 'پاسخی از ChatGPT دریافت نشد.', requestId: reqId, source: 'dom' });
        }
        return;
      }

      if (currentText !== lastText && currentText.length > 0) {
        var delta = '';
        if (currentText.length > lastLength && currentText.indexOf(lastText) === 0) {
          delta = currentText.substring(lastLength);
        } else {
          delta = currentText;
        }
        lastText = currentText;
        lastLength = currentText.length;
        lastChangeTimestamp = Date.now();
        notifyFlutter('chunk', { delta: delta, fullText: currentText, requestId: reqId, source: 'dom' });
      }

      var stopButton = document.querySelector(
        'button[data-testid="stop-button"], button[aria-label*="Stop" i], button[aria-label*="توقف"], button[data-testid*="stop" i], button.stop-button'
      );
      var isStreamingClass = document.querySelector('.result-streaming, .streaming');
      var timeSinceLastChange = Date.now() - lastChangeTimestamp;

      var isGenerating = !!stopButton || !!isStreamingClass;

      if (!isGenerating && lastLength > 0 && timeSinceLastChange > 500) {
        var finalFullText = findLatestAssistantText() || currentText;
        clearInterval(streamCheckTimer);
        streamCheckTimer = null;
        notifyFlutter('done', { fullText: finalFullText, requestId: reqId, source: 'dom' });
        console.log('[Ritmo] Stream completed with ' + finalFullText.length + ' characters (reqId: ' + reqId + ')');
      } else if (lastLength > 0 && timeSinceLastChange > 3000) {
        var finalFullText = findLatestAssistantText() || currentText;
        clearInterval(streamCheckTimer);
        streamCheckTimer = null;
        notifyFlutter('done', { fullText: finalFullText, requestId: reqId, source: 'dom' });
        console.log('[Ritmo] Stream fallback completed after 3s idle (reqId: ' + reqId + ')');
      } else if (totalDuration > 70000) {
        var finalFullText = findLatestAssistantText() || currentText;
        clearInterval(streamCheckTimer);
        streamCheckTimer = null;
        if (finalFullText.length > 0) {
          notifyFlutter('done', { fullText: finalFullText, requestId: reqId, source: 'dom' });
        } else {
          notifyFlutter('error', { message: 'زمان انتظار برای پاسخ به پایان رسید.', requestId: reqId, source: 'dom' });
        }
      }
    }, 100);
  };

  // --- 5. Prompt Sender Implementation ---
  window.__ritmo_sendPrompt = function(promptText, reqId) {
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
            injectAndTriggerSend(textarea, promptText, reqId);
          } else if (waitCount > 20) {
            clearInterval(pageWaitInterval);
            notifyFlutter('error', { message: 'فیلد ورودی متن ChatGPT هنوز لود نشده است.', requestId: reqId, source: 'dom' });
          }
        }, 500);
        return;
      }

      injectAndTriggerSend(textarea, promptText, reqId);

      function injectAndTriggerSend(editor, text, currentReqId) {
        autoCloseSidebar();
        autoDismissCookiesAndModals();

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
            window.__ritmo_startStreamingWatcher(previousBaselineText, currentReqId);
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
            window.__ritmo_startStreamingWatcher(previousBaselineText, currentReqId);
          }
        }, 250);
      }

    } catch (e) {
      notifyFlutter('error', { message: 'خطا در ارسال پرامپت: ' + e.toString(), requestId: reqId, source: 'dom' });
    }
  };

  // --- 6. Resume After Navigation Implementation ---
  window.__ritmo_resume = function(payload) {
    try {
      payload = payload || {};
      var reqId = payload.requestId || '';
      var promptPrefix = payload.promptPrefix || '';
      var stage = payload.stage || 'sending';
      var receivedLength = payload.receivedLength || 0;

      console.log('[Ritmo] __ritmo_resume invoked for reqId: ' + reqId + ' (stage: ' + stage + ', received: ' + receivedLength + ')');

      var stopButton = document.querySelector(
        'button[data-testid="stop-button"], button[aria-label*="Stop" i], button[aria-label*="توقف"], button[data-testid*="stop" i], button.stop-button'
      );
      var isStreamingClass = document.querySelector('.result-streaming, .streaming');
      var isCurrentlyGenerating = !!stopButton || !!isStreamingClass;

      var currentText = findLatestAssistantText();

      if (isCurrentlyGenerating) {
        notifyFlutter('resumed', { stage: 'streaming', requestId: reqId, source: 'dom' });
        window.__ritmo_startStreamingWatcher('', reqId);
        return;
      }

      if (currentText && currentText.length > 0) {
        if (currentText.length >= receivedLength) {
          notifyFlutter('resumed', { stage: 'done', requestId: reqId, source: 'dom' });
          notifyFlutter('done', { fullText: currentText, requestId: reqId, source: 'dom' });
          return;
        } else {
          notifyFlutter('resumed', { stage: 'streaming', requestId: reqId, source: 'dom' });
          window.__ritmo_startStreamingWatcher('', reqId);
          return;
        }
      }

      if (stage === 'awaitingFirstToken' && isCurrentlyGenerating) {
        notifyFlutter('resumed', { stage: 'awaitingFirstToken', requestId: reqId, source: 'dom' });
        window.__ritmo_startStreamingWatcher('', reqId);
        return;
      }

      console.warn('[Ritmo] No generated response found in DOM after navigation; requesting resend.');
      notifyFlutter('resend_required', { requestId: reqId, source: 'dom' });
    } catch (e) {
      console.error('[Ritmo] Error in __ritmo_resume: ' + e);
      notifyFlutter('error', { message: 'خطا در بازیابی پاسخ پس از جابجایی صفحه: ' + e.toString(), requestId: payload && payload.requestId, source: 'dom' });
    }
  };

  // --- 7. Cancellation Implementation ---
  window.__ritmo_cancelGeneration = function() {
    try {
      if (streamCheckTimer) {
        clearInterval(streamCheckTimer);
        streamCheckTimer = null;
      }
      var stopBtn = document.querySelector(
        'button[data-testid="stop-button"], button[aria-label*="Stop" i], button[aria-label*="توقف"], button[data-testid*="stop" i], button.stop-button'
      );
      if (stopBtn) {
        stopBtn.click();
        console.log('[Ritmo] Clicked stop button in DOM on cancel.');
      }
    } catch (e) {
      console.error('[Ritmo] Error cancelling generation:', e);
    }
  };

  // --- 8. Composer Readiness Check ---
  window.__ritmo_checkComposerReady = function() {
    try {
      var el = document.querySelector('#prompt-textarea') ||
               document.querySelector('textarea') ||
               document.querySelector('div[contenteditable="true"]') ||
               document.querySelector('.ProseMirror');
      if (!el) return { ready: false, reason: 'not_found' };
      var isGenerating = !!document.querySelector(
        'button[data-testid="stop-button"], button[aria-label*="Stop" i], button[aria-label*="توقف"], button[data-testid*="stop" i], button.stop-button'
      );
      if (isGenerating) return { ready: false, reason: 'still_generating' };
      if (el.disabled || el.getAttribute('aria-disabled') === 'true') return { ready: false, reason: 'disabled' };
      return { ready: true };
    } catch (e) {
      return { ready: false, reason: e.toString() };
    }
  };

  var challengedAtBoot = checkCloudflareStatus();
  autoDismissCookiesAndModals();
  autoCloseSidebar();
  cfCheckTimer = setInterval(checkCloudflareStatus, 2000);

  console.log('[Ritmo] Bridge setup complete.');

  if (!challengedAtBoot) {
    notifyFlutter('ready', {
      version: requiredVersion,
      isWarm: false,
      currentPath: window.location.pathname || '',
      hasComposer: checkComposerPresent()
    });
  } else {
    console.warn('[Ritmo] Cloudflare challenge active at boot; withholding ready.');
  }
})();
''';

  /// Generates the call to send a specific formatted prompt correlated with [requestId]
  static String buildSendPromptScript(String prompt, {String requestId = ''}) {
    final encoded = jsonEncode(prompt);
    final reqEncoded = jsonEncode(requestId);
    return '''
(() => {
  if (typeof window.__ritmo_sendPrompt === 'function') {
    window.__ritmo_sendPrompt($encoded, $reqEncoded);
  } else {
    console.warn("[Ritmo] __ritmo_sendPrompt missing, injecting setupBridgeScript...");
    ${ChatGptJsInjector.setupBridgeScript}
    setTimeout(function() {
      if (typeof window.__ritmo_sendPrompt === 'function') {
        window.__ritmo_sendPrompt($encoded, $reqEncoded);
      }
    }, 500);
  }
})();
''';
  }

  /// Script to cancel any running generation in the DOM and clear watchers
  static const String cancelScript = '''
if (typeof window.__ritmo_cancelGeneration === 'function') {
  window.__ritmo_cancelGeneration();
}
''';
}
