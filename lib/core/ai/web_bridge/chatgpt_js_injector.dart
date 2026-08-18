import 'dart:convert';

/// Utilities and JavaScript scripts for injecting into ChatGPT Web (chatgpt.com)
class ChatGptJsInjector {
  /// Source of truth version for the JavaScript bridge script.
  static const int bridgeVersion = 8;

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
      querySafe('#prompt-textarea') ||
      querySafe('textarea') ||
      querySafe('div[contenteditable="true"]') ||
      querySafe('.ProseMirror')
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
      
      // FIX: Only intercept actual conversation endpoints (NOT /lat/r telemetry pings).
      // Previously /backend-api/lat/r was included, causing spurious http_errors on 204 pings.
      var isConvo = typeof url === 'string' && (
        url.indexOf('/backend-api/conversation') !== -1 ||
        url.indexOf('/backend-anon/conversation') !== -1
      ) && url.indexOf('/lat/r') === -1;

      if (isConvo) {
        var activeReqId = window.__ritmo_active_req_id || '';
        console.log('[Ritmo] Intercepted conversation network request: ' + url + ' (reqId: ' + activeReqId + ')');
        notifyFlutter('network_conversation_started', {
          url: url,
          timestamp: Date.now(),
          requestId: activeReqId,
          source: 'fetch'
        });

        try {
          return originalFetch.apply(this, args).then(function(response) {
            if (response) {
              if (response.status !== 200) {
                console.warn('[Ritmo] Conversation HTTP error: ' + response.status + ' ' + response.statusText);
                // FIX: Only emit http_error when DOM is NOT actively streaming tokens.
                // This prevents a rate-limit or redirect (e.g. 307) from aborting an active DOM stream.
                var isActivelyStreaming = lastLength > 0 || !!querySafe(RITMO_SELECTORS.stopButton);
                if (!isActivelyStreaming) {
                  notifyFlutter('http_error', {
                    statusCode: response.status,
                    statusText: response.statusText,
                    url: url,
                    requestId: activeReqId,
                    source: 'fetch'
                  });
                } else {
                  console.log('[Ritmo] Suppressed http_error ' + response.status + ' - DOM stream is active (lastLength=' + lastLength + ').');
                }
              } else if (response.body && typeof response.body.tee === 'function') {
                try {
                  var branches = response.body.tee();
                  var ritmoReader = branches[0].getReader();
                  readSSEStream(ritmoReader, activeReqId);

                  var clonedResponse = new Response(branches[1], {
                    headers: response.headers,
                    status: response.status,
                    statusText: response.statusText
                  });
                  return clonedResponse;
                } catch (teeErr) {
                  console.warn('[Ritmo] response.body.tee failed, falling back to original response:', teeErr);
                  return response;
                }
              }
            }
            return response;
          }).catch(function(err) {
            console.error('[Ritmo] Fetch promise rejected:', err);
            throw err;
          });
        } catch (e) {
          console.error('[Ritmo] Error initiating fetch:', e);
          throw e;
        }
      }

      try {
        return originalFetch.apply(this, args);
      } catch (e) {
        console.error('[Ritmo] Error executing original fetch:', e);
        throw e;
      }
    };
  }

  // --- 0.1 SSE Stream Parser & Reader ---
  function parseSSELine(line, state, reqId) {
    if (!line || typeof line !== 'string' || line.indexOf('data: ') !== 0) return null;
    var rawData = line.substring(6).trim();
    if (rawData === '[DONE]') {
      return { type: 'done', fullText: (state && state.accumulatedText) || '', requestId: reqId, source: 'sse' };
    }
    try {
      var json = JSON.parse(rawData);
      var text = '';
      if (json.message && json.message.content && json.message.content.parts && json.message.content.parts.length > 0) {
        text = json.message.content.parts.join('');
      } else if (json.delta && json.delta.content) {
        text = ((state && state.accumulatedText) || '') + json.delta.content;
      } else if (json.v && json.v.message && json.v.message.content && json.v.message.content.parts) {
        text = json.v.message.content.parts.join('');
      }

      if (text && text !== (state && state.accumulatedText)) {
        var prev = (state && state.accumulatedText) || '';
        var delta = '';
        if (text.length > prev.length && text.indexOf(prev) === 0) {
          delta = text.substring(prev.length);
        } else {
          delta = text;
        }
        if (state) state.accumulatedText = text;
        return { type: 'chunk', delta: delta, fullText: text, requestId: reqId, source: 'sse' };
      }
    } catch (e) {
      // Non-JSON SSE line or commentary
    }
    return null;
  }
  window.__ritmo_parseSSELine = parseSSELine;

  function readSSEStream(reader, reqId) {
    var state = { accumulatedText: '', firstTokenEmitted: false, startTime: Date.now() };
    var decoder = typeof TextDecoder !== 'undefined' ? new TextDecoder('utf-8') : null;
    var buffer = '';

    function pump() {
      return reader.read().then(function(result) {
        if (result.done) {
          if (state.accumulatedText.length > 0) {
            notifyFlutter('done', { fullText: state.accumulatedText, requestId: reqId, source: 'sse' });
          }
          return;
        }

        var chunkStr = decoder ? decoder.decode(result.value, { stream: true }) : String.fromCharCode.apply(null, result.value);
        buffer += chunkStr;
        var lines = buffer.split('\n');
        buffer = lines.pop() || '';

        for (var i = 0; i < lines.length; i++) {
          var trimmed = lines[i].trim();
          if (trimmed.length > 0) {
            var event = parseSSELine(trimmed, state, reqId);
            if (event) {
              if (!state.firstTokenEmitted && event.type === 'chunk') {
                state.firstTokenEmitted = true;
                notifyFlutter('first_token', {
                  length: (event.delta && event.delta.length) || 0,
                  requestId: reqId,
                  latencyMs: Date.now() - state.startTime,
                  source: 'sse'
                });
              }
              notifyFlutter(event.type, event);
            }
          }
        }

        return pump();
      }).catch(function(err) {
        console.warn('[Ritmo] SSE stream read error:', err);
      });
    }

    return pump();
  }
  window.__ritmo_readSSEStream = readSSEStream;

  // --- Centralized RITMO Selector Table ---
  var RITMO_SELECTORS = {
    composer: '#prompt-textarea, textarea, div[contenteditable="true"], .ProseMirror',
    sendButton: 'button[data-testid="send-button"], button[data-testid="fruitjuice-send-button"], button[aria-label="Send prompt"], button[aria-label="ارسال پیام"], form button[type="submit"]',
    stopButton: 'button[data-testid="stop-button"], button[data-testid="fruitjuice-stop-button"], button[aria-label*="Stop" i], button[aria-label*="توقف"], button[data-testid*="stop" i], button.stop-button',
    assistantMessage: '[data-message-author-role="assistant"], [data-testid*="assistant"], div.agent-turn, [class*="agent-turn"]',
    unseenAssistantMessage: '[data-message-author-role="assistant"]:not([data-ritmo-seen="true"]), [data-testid*="assistant"]:not([data-ritmo-seen="true"]), div.agent-turn:not([data-ritmo-seen="true"]), [class*="agent-turn"]:not([data-ritmo-seen="true"])',
    userMessage: '[data-message-author-role="user"], [data-testid*="user"], div.font-user-message',
    markdownBodies: 'div.markdown, div.prose, [class*="markdown"], [class*="prose"], div.whitespace-pre-wrap',
    unseenMarkdownBodies: 'div.markdown:not([data-ritmo-seen="true"]), div.prose:not([data-ritmo-seen="true"]), [class*="markdown"]:not([data-ritmo-seen="true"]), [class*="prose"]:not([data-ritmo-seen="true"])',
    conversationTurns: 'article, [data-testid*="conversation-turn-"]',
    unseenConversationTurns: 'article:not([data-ritmo-seen="true"]), [data-testid*="conversation-turn-"]:not([data-ritmo-seen="true"])',
    streamingIndicator: '.result-streaming, .streaming, [data-is-streaming="true"]',
    cloudflare: 'iframe[src*="cloudflare"], iframe[src*="challenges.cloudflare.com"], #cf-turnstile, #challenge-stage, #challenge-running, .cf-turnstile-wrapper',
    sidebarClose: 'button[aria-label*="Close sidebar" i], button[aria-label*="بستن نوار" i], button[data-testid*="close-sidebar" i]',
    loginButton: 'button[data-testid="login-button"], a[href*="/login"], button[data-testid="signup-button"], a[href*="/signup"]',
    userProfile: 'img[alt*="User" i], button[data-testid*="user-menu" i], div[data-testid*="profile" i], [data-testid="accounts-profile-button"]'
  };

  function querySafe(selector) {
    try {
      return document.querySelector(selector);
    } catch (e) {
      console.warn('[Ritmo] querySafe skipped invalid selector:', selector);
      return null;
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
    var hasCfIframe = !!querySafe(RITMO_SELECTORS.cloudflare);
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
        var el = querySafe(directSelectors[i]);
        if (el && el.offsetParent !== null) {
          el.click();
          console.log('[Ritmo] Auto-clicked cookie accept button:', directSelectors[i]);
        }
      }

      var buttons = queryAllSafe('button, div[role="button"], a[role="button"], a');
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

      var bannerContainers = queryAllSafe('#onetrust-banner-sdk, #onetrust-consent-sdk, .onetrust-pc-dark-filter, .cookie-banner');
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
      var closeBtn = querySafe(
        'button[aria-label="Close sidebar"], button[aria-label="Close navigation"], button[data-testid="close-sidebar-button"], button[aria-label="بستن منو"]'
      );
      if (closeBtn && isVisiblyOnScreen(closeBtn)) {
        return true;
      }

      var backdrop = querySafe(
        'div.fixed.inset-0.bg-black\\/50, div.fixed.inset-0.bg-black'
      );
      if (backdrop && isVisiblyOnScreen(backdrop)) {
        return true;
      }

      var navDrawer = querySafe('#headlessui-dialog-panel, nav[aria-label="Chat history"]');
      if (navDrawer && isVisiblyOnScreen(navDrawer)) {
        var rect = navDrawer.getBoundingClientRect();
        if (rect.left >= 0 && rect.right > 50) {
          return true;
        }
      }
    } catch (e) {
      console.warn('[Ritmo] isSidebarOpen check failed: ' + e);
    }
    return false;
  }

  function autoCloseSidebar() {
    try {
      var closeBtn = querySafe(RITMO_SELECTORS.sidebarClose);
      if (closeBtn && isVisiblyOnScreen(closeBtn)) {
        closeBtn.click();
        console.log('[Ritmo] Auto-closed sidebar via close button');
        return;
      }

      var backdrops = queryAllSafe('div.fixed.inset-0, div[class*="backdrop"], div[class*="sidebar-mask"]');
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
      // 1. Prioritize newly generated assistant elements not present before this turn
      var unseenAssistants = queryAllSafe(RITMO_SELECTORS.unseenAssistantMessage);
      if (unseenAssistants.length > 0) {
        var lastUnseen = unseenAssistants[unseenAssistants.length - 1];
        var t = extractCleanText(lastUnseen);
        if (t) return t;
      }

      var unseenMarkdowns = queryAllSafe(RITMO_SELECTORS.unseenMarkdownBodies);
      for (var j = unseenMarkdowns.length - 1; j >= 0; j--) {
        var md = unseenMarkdowns[j];
        var isUser = !!md.closest(RITMO_SELECTORS.userMessage);
        if (!isUser) {
          var t = extractCleanText(md);
          if (t) return t;
        }
      }

      var unseenArticles = queryAllSafe(RITMO_SELECTORS.unseenConversationTurns);
      for (var i = unseenArticles.length - 1; i >= 0; i--) {
        var art = unseenArticles[i];
        var isUser = !!art.querySelector('[data-message-author-role="user"]') ||
                     (art.getAttribute('data-testid') || '').indexOf('user') !== -1;
        if (!isUser) {
          var t = extractCleanText(art);
          if (t) return t;
        }
      }

      // 2. Fallback to all assistant elements if no unseen flag match found
      var assistants = queryAllSafe(RITMO_SELECTORS.assistantMessage);
      if (assistants.length > 0) {
        var lastAssistant = assistants[assistants.length - 1];
        var tAll = extractCleanText(lastAssistant);
        if (tAll) return tAll;
      }

      var markdowns = queryAllSafe(RITMO_SELECTORS.markdownBodies);
      for (var k = markdowns.length - 1; k >= 0; k--) {
        var mdAll = markdowns[k];
        var isUserMd = !!mdAll.closest(RITMO_SELECTORS.userMessage);
        if (!isUserMd) {
          var tAllMd = extractCleanText(mdAll);
          if (tAllMd) return tAllMd;
        }
      }

      var articles = queryAllSafe(RITMO_SELECTORS.conversationTurns);
      for (var m = articles.length - 1; m >= 0; m--) {
        var artAll = articles[m];
        var isUserArt = !!artAll.querySelector('[data-message-author-role="user"]') ||
                        (artAll.getAttribute('data-testid') || '').indexOf('user') !== -1;
        if (!isUserArt) {
          var tAllArt = extractCleanText(artAll);
          if (tAllArt) return tAllArt;
        }
      }
    } catch (e) {
      console.warn('[Ritmo] findLatestAssistantText error:', e);
    }
    return '';
  }

  var streamCheckTimer = null;
  var cfCheckTimer = null;
  var domObserver = null;
  var lastLength = 0;
  var lastText = '';
  var lastChangeTimestamp = Date.now();
  var streamStartTime = 0;

  function stopDomObserver() {
    if (domObserver) {
      try {
        domObserver.disconnect();
      } catch (e) {
        console.warn('[Ritmo] domObserver disconnect error:', e);
      }
      domObserver = null;
    }
  }

  window.__ritmo_cleanup = function() {
    if (streamCheckTimer) {
      clearInterval(streamCheckTimer);
      streamCheckTimer = null;
    }
    if (cfCheckTimer) {
      clearInterval(cfCheckTimer);
      cfCheckTimer = null;
    }
    stopDomObserver();
    if (window.__ritmo_fetch_hooked && window.__ritmo_original_fetch) {
      window.fetch = window.__ritmo_original_fetch;
      window.__ritmo_fetch_hooked = false;
    }
    window.__ritmo_active_req_id = null;
  };

  window.__ritmo_startStreamingWatcher = function(previousBaselineText, reqId) {
    lastLength = 0;
    lastText = '';
    lastChangeTimestamp = Date.now();
    streamStartTime = Date.now();
    previousBaselineText = (previousBaselineText || '').trim();

    if (streamCheckTimer) clearInterval(streamCheckTimer);
    stopDomObserver();

    function checkAndEmitChunk() {
      var currentText = findLatestAssistantText();
      if (!currentText || currentText === previousBaselineText) return;

      if (currentText !== lastText && currentText.length > 0) {
        if (lastLength === 0) {
          notifyFlutter('first_token', {
            length: currentText.length,
            requestId: reqId,
            latencyMs: Date.now() - streamStartTime,
            source: 'dom'
          });
        }
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
    }

    if (typeof MutationObserver !== 'undefined') {
      try {
        domObserver = new MutationObserver(function() {
          checkAndEmitChunk();
        });
        domObserver.observe(document.body, { childList: true, subtree: true, characterData: true });
        console.log('[Ritmo] MutationObserver attached for DOM stream watching.');
      } catch (obsErr) {
        console.warn('[Ritmo] MutationObserver init failed, using polling timer only:', obsErr);
      }
    }

    streamCheckTimer = setInterval(function() {
      checkAndEmitChunk();

      var totalDuration = Date.now() - streamStartTime;
      var currentText = findLatestAssistantText();

      if (!currentText || currentText === previousBaselineText) {
        if (totalDuration > 80000) {
          clearInterval(streamCheckTimer);
          streamCheckTimer = null;
          stopDomObserver();
          notifyFlutter('error', { message: 'زمان انتظار برای پاسخ به پایان رسید.', requestId: reqId, source: 'dom' });
        }
        return;
      }

      var isFinished = evaluateStreamCompletion();
      if (isFinished) {
        var finalFullText = findLatestAssistantText() || currentText;
        clearInterval(streamCheckTimer);
        streamCheckTimer = null;
        stopDomObserver();
        notifyFlutter('done', { fullText: finalFullText, requestId: reqId, source: 'dom' });
        console.log('[Ritmo] Stream completed via multi-signal vote with ' + finalFullText.length + ' characters (reqId: ' + reqId + ')');
      } else if (totalDuration > 85000) {
        var finalFullText = findLatestAssistantText() || currentText;
        clearInterval(streamCheckTimer);
        streamCheckTimer = null;
        stopDomObserver();
        if (finalFullText.length > 0) {
          notifyFlutter('done', { fullText: finalFullText, requestId: reqId, source: 'dom' });
        } else {
          notifyFlutter('error', { message: 'زمان انتظار برای پاسخ به پایان رسید.', requestId: reqId, source: 'dom' });
        }
      }
    }, 350);

    function evaluateStreamCompletion() {
      var stopButton = querySafe(RITMO_SELECTORS.stopButton);
      var isStreamingClass = querySafe(RITMO_SELECTORS.streamingIndicator);
      var isGenerating = !!stopButton || !!isStreamingClass;

      var sendButton = querySafe(RITMO_SELECTORS.sendButton);
      var hasSendButton = !!sendButton && !sendButton.disabled;
      var idleMs = Date.now() - lastChangeTimestamp;

      // 1. If stop button or streaming class is present, stream is strictly continuing
      if (isGenerating) return false;

      // 2. Multi-signal vote: Stop button gone AND we have received content
      if (lastLength > 0) {
        if (hasSendButton && idleMs > 400) {
          return true; // Fast completion when composer send button is restored
        }
        if (idleMs > 2500) {
          return true; // Idle fallback completion
        }
      }
      return false;
    }
  };

  // --- 5. Prompt Sender Implementation ---
  window.__ritmo_sendPrompt = function(promptText, reqId) {
    try {
      window.__ritmo_active_req_id = reqId || '';

      function findTextarea() {
        return querySafe(RITMO_SELECTORS.composer);
      }

      function findSendButton() {
        return querySafe(RITMO_SELECTORS.sendButton);
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

        // WEB-18: Anchor existing messages so only the new incoming turn is tracked
        queryAllSafe('article, [data-message-author-role], [data-testid*="conversation-turn"], div.markdown, div.prose').forEach(function(el) {
          el.setAttribute('data-ritmo-seen', 'true');
        });

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
        var sendClicked = false; // FIX: guard against duplicate Enter fallback after successful click
        var sendInterval = setInterval(function() {
          sendCheckAttempts++;
          var sendBtn = findSendButton();

          if (sendBtn && !sendBtn.disabled) {
            clearInterval(sendInterval);
            sendClicked = true;
            sendBtn.dispatchEvent(new PointerEvent('pointerdown', { bubbles: true }));
            sendBtn.dispatchEvent(new MouseEvent('mousedown', { bubbles: true }));
            sendBtn.dispatchEvent(new PointerEvent('pointerup', { bubbles: true }));
            sendBtn.dispatchEvent(new MouseEvent('mouseup', { bubbles: true }));
            sendBtn.click();
            console.log('[Ritmo] Send button clicked successfully!');
            window.__ritmo_startStreamingWatcher(previousBaselineText, currentReqId);
          } else if (sendCheckAttempts >= 8) {
            clearInterval(sendInterval);
            // FIX: Only dispatch Enter key if we NEVER successfully clicked the send button.
            // Previously this fired even after a successful click, causing duplicate sends.
            if (!sendClicked) {
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
              console.log('[Ritmo] Fallback Enter key dispatched (no send button found after 8 attempts)');
              window.__ritmo_startStreamingWatcher(previousBaselineText, currentReqId);
            }
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

      var currentText = findLatestAssistantText();

      if (currentText && currentText.length > 0 && currentText.length >= receivedLength) {
        notifyFlutter('resumed', { stage: 'done', requestId: reqId, source: 'dom' });
        notifyFlutter('done', { fullText: currentText, requestId: reqId, source: 'dom' });
        return;
      }

      // Note: resend_required is deprecated and removed to prevent duplicate sends after navigation
      // Seamlessly resume watching the DOM for live streaming tokens without duplicate resending
      notifyFlutter('resumed', { stage: 'streaming', requestId: reqId, source: 'dom' });
      window.__ritmo_startStreamingWatcher('', reqId);
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
      stopDomObserver();
      var stopBtn = querySafe(RITMO_SELECTORS.stopButton);
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
      var el = querySafe(RITMO_SELECTORS.composer);
      if (!el) return { ready: false, reason: 'not_found' };
      var isGenerating = !!querySafe(RITMO_SELECTORS.stopButton);
      if (isGenerating) return { ready: false, reason: 'still_generating' };
      if (el.disabled || el.getAttribute('aria-disabled') === 'true') return { ready: false, reason: 'disabled' };
      return { ready: true };
    } catch (e) {
      return { ready: false, reason: e.toString() };
    }
  };

  // --- 9. Page Auth State Detection ---
  function checkAuthState() {
    try {
      var isExplicitLoginPage = (window.location.pathname || '').indexOf('/auth/login') !== -1 || (window.location.pathname || '').indexOf('/login') === 0;
      var hasLoginModal = !!querySafe('#login-modal, [data-testid="login-modal"]');
      var hasComposer = !!querySafe(RITMO_SELECTORS.composer);
      var hasLoginBtn = !!querySafe(RITMO_SELECTORS.loginButton);

      var isAuth = !isExplicitLoginPage && !hasLoginModal;

      if ((isExplicitLoginPage || hasLoginModal) && !hasComposer) {
        notifyFlutter('auth_required', {
          hasLoginButton: hasLoginBtn,
          currentPath: window.location.pathname || '',
          source: 'lifecycle'
        });
      }
      return isAuth;
    } catch (e) {
      console.warn('[Ritmo] checkAuthState error:', e);
      return true;
    }
  }
  window.__ritmo_checkAuthState = checkAuthState;

  var challengedAtBoot = checkCloudflareStatus();
  autoDismissCookiesAndModals();
  autoCloseSidebar();
  checkAuthState();
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
