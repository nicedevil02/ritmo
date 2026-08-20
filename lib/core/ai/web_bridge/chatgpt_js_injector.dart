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

  /// Early hook script injected at `onPageStarted` to intercept network streams
  /// before application code caches original references (A-34, A-35, A-36).
  static String get earlyHookScript => r'''
(function() {
  if (window.__ritmo_early_hooks_injected) return;
  window.__ritmo_early_hooks_injected = true;

  // 1. Fetch Hook with response.body.tee availability guard (A-34)
  var originalFetch = window.fetch;
  if (originalFetch && !window.__ritmo_fetch_hooked) {
    window.__ritmo_fetch_hooked = true;
    window.__ritmo_original_fetch = originalFetch;
    window.fetch = function() {
      var args = arguments;
      var url = (args[0] && typeof args[0] === 'string') ? args[0] : (args[0] && args[0].url) ? args[0].url : '';

      var isConvo = typeof url === 'string' && (
        url.indexOf('/backend-api/conversation') !== -1 ||
        url.indexOf('/backend-anon/conversation') !== -1
      ) && url.indexOf('/lat/r') === -1;

      if (isConvo) {
        var activeReqId = window.__ritmo_active_req_id || '';
        try {
          if (window.RitmoChatBridge && window.RitmoChatBridge.postMessage) {
            window.RitmoChatBridge.postMessage(JSON.stringify({
              type: 'network_conversation_started',
              url: url,
              timestamp: Date.now(),
              requestId: activeReqId,
              source: 'fetch'
            }));
          }
        } catch (e) {}

        try {
          return originalFetch.apply(this, args).then(function(response) {
            if (response && response.status === 200) {
              if (!response.body || typeof response.body.tee !== 'function') {
                console.warn('[Ritmo] response.body.tee unavailable, falling back to DOM watcher only');
                try {
                  if (window.RitmoChatBridge && window.RitmoChatBridge.postMessage) {
                    window.RitmoChatBridge.postMessage(JSON.stringify({
                      type: 'selector_health',
                      issue: 'tee_unavailable',
                      source: 'fetch'
                    }));
                  }
                } catch (e) {}
                return response;
              }
              try {
                var branches = response.body.tee();
                var ritmoReader = branches[0].getReader();
                if (typeof window.__ritmo_readSSEStream === 'function') {
                  window.__ritmo_readSSEStream(ritmoReader, activeReqId);
                }
                return new Response(branches[1], {
                  headers: response.headers,
                  status: response.status,
                  statusText: response.statusText
                });
              } catch (teeErr) {
                console.warn('[Ritmo] response.body.tee failed, falling back to original response:', teeErr);
                return response;
              }
            }
            return response;
          }).catch(function(err) {
            return Promise.reject(err);
          });
        } catch (fetchErr) {
          console.warn('[Ritmo] Intercepted fetch error:', fetchErr);
        }
      }
      return originalFetch.apply(this, args);
    };
  }

  // 2. XMLHttpRequest Hook (A-35)
  if (window.XMLHttpRequest && !window.__ritmo_xhr_hooked) {
    window.__ritmo_xhr_hooked = true;
    var origOpen = window.XMLHttpRequest.prototype.open;
    var origSend = window.XMLHttpRequest.prototype.send;
    window.XMLHttpRequest.prototype.open = function(method, url) {
      this.__ritmo_url = url;
      return origOpen.apply(this, arguments);
    };
    window.XMLHttpRequest.prototype.send = function() {
      var url = this.__ritmo_url || '';
      var isConvo = typeof url === 'string' && (
        url.indexOf('/backend-api/conversation') !== -1 ||
        url.indexOf('/backend-anon/conversation') !== -1
      ) && url.indexOf('/lat/r') === -1;

      if (isConvo) {
        var xhr = this;
        var sseState = { accumulatedText: '', firstTokenEmitted: false, startTime: Date.now() };
        var lastIdx = 0;
        xhr.addEventListener('progress', function() {
          try {
            var text = xhr.responseText || '';
            var newChunk = text.substring(lastIdx);
            lastIdx = text.length;
            var lines = newChunk.split('\n');
            for (var i = 0; i < lines.length; i++) {
              var trimmed = lines[i].trim();
              if (trimmed && typeof window.__ritmo_parseSSELine === 'function') {
                var evt = window.__ritmo_parseSSELine(trimmed, sseState, window.__ritmo_active_req_id || '');
                if (evt && window.RitmoChatBridge && window.RitmoChatBridge.postMessage) {
                  window.RitmoChatBridge.postMessage(JSON.stringify(evt));
                }
              }
            }
          } catch (xhrErr) {}
        });
      }
      return origSend.apply(this, arguments);
    };
  }

  // 3. EventSource Hook (A-35)
  if (window.EventSource && !window.__ritmo_es_hooked) {
    window.__ritmo_es_hooked = true;
    var OrigEventSource = window.EventSource;
    window.EventSource = function(url, options) {
      var es = new OrigEventSource(url, options);
      var isConvo = typeof url === 'string' && (
        url.indexOf('/backend-api/conversation') !== -1 ||
        url.indexOf('/backend-anon/conversation') !== -1
      ) && url.indexOf('/lat/r') === -1;

      if (isConvo) {
        var sseState = { accumulatedText: '', firstTokenEmitted: false, startTime: Date.now() };
        es.addEventListener('message', function(e) {
          try {
            if (e && e.data && typeof window.__ritmo_parseSSELine === 'function') {
              var line = 'data: ' + e.data;
              var evt = window.__ritmo_parseSSELine(line, sseState, window.__ritmo_active_req_id || '');
              if (evt && window.RitmoChatBridge && window.RitmoChatBridge.postMessage) {
                window.RitmoChatBridge.postMessage(JSON.stringify(evt));
              }
            }
          } catch (esErr) {}
        });
      }
      return es;
    };
  }

  // 4. Early Cookie Banner Suppression & Auto-Consent (A-38, A-106)
  try {
    var styleId = '__ritmo_cookie_suppress_css';
    if (!document.getElementById(styleId)) {
      var st = document.createElement('style');
      st.id = styleId;
      st.textContent = '#onetrust-banner-sdk, #onetrust-consent-sdk, .onetrust-pc-dark-filter, .cookie-banner, [data-testid="cookie-banner"], [id*="cookie-banner"], #onetrust-style { display: none !important; opacity: 0 !important; pointer-events: none !important; }';
      (document.head || document.documentElement).appendChild(st);
    }
    if (typeof window.OnetrustActiveGroups === 'undefined') {
      window.OnetrustActiveGroups = ',C0001,C0002,C0003,C0004,';
    }
  } catch (cookieEarlyErr) {}
})();
''';

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
      if (typeof data.source === 'undefined' || !data.source) {
        data.source = 'lifecycle';
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
      hasComposer: checkComposerPresent(),
      source: 'lifecycle'
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
  // --- 0. Global Fetch Interceptor Hook (A-34, A-35) ---
  var originalFetch = window.fetch;
  if (originalFetch && !window.__ritmo_fetch_hooked) {
    window.__ritmo_fetch_hooked = true;
    window.__ritmo_original_fetch = originalFetch;
    window.fetch = function() {
      var args = arguments;
      var url = (args[0] && typeof args[0] === 'string') ? args[0] : (args[0] && args[0].url) ? args[0].url : '';
      
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
              } else {
                console.warn('[Ritmo] response.body.tee unavailable, falling back to DOM watcher only');
                notifyFlutter('selector_health', { issue: 'tee_unavailable', source: 'fetch' });
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

  // --- 0.1 SSE Stream Parser & Reader (A-31) ---
  function parseSSELine(line, state, reqId) {
    if (!line || typeof line !== 'string' || line.indexOf('data: ') !== 0) return null;
    var rawData = line.substring(6).trim();
    if (rawData === '[DONE]') {
      return { type: 'done', fullText: (state && state.accumulatedText) || '', requestId: reqId, source: 'sse' };
    }
    try {
      var json = JSON.parse(rawData);
      var text = '';
      var isReplace = false;

      // Format 1: Patch operations array (A-31)
      if (json.o === 'patch' && Array.isArray(json.v)) {
        var patchDelta = '';
        for (var p = 0; p < json.v.length; p++) {
          var op = json.v[p];
          if (op && op.p && typeof op.p === 'string' && op.p.indexOf('/message/content/parts/') === 0) {
            if (op.o === 'append' && typeof op.v === 'string') {
              patchDelta += op.v;
            } else if (op.o === 'replace' && typeof op.v === 'string') {
              text = op.v;
              isReplace = true;
            }
          }
        }
        if (patchDelta && !isReplace) {
          text = ((state && state.accumulatedText) || '') + patchDelta;
        }
      } else if (json.o === 'append' && json.p && typeof json.p === 'string' && json.p.indexOf('/message/content/parts/') === 0 && typeof json.v === 'string') {
        text = ((state && state.accumulatedText) || '') + json.v;
      } else if (json.o === 'replace' && json.p && typeof json.p === 'string' && json.p.indexOf('/message/content/parts/') === 0 && typeof json.v === 'string') {
        text = json.v;
        isReplace = true;
      } else if (json.message && json.message.content && json.message.content.parts && json.message.content.parts.length > 0) {
        text = json.message.content.parts.join('');
      } else if (json.delta && json.delta.content) {
        text = ((state && state.accumulatedText) || '') + json.delta.content;
      } else if (json.v && json.v.message && json.v.message.content && json.v.message.content.parts) {
        text = json.v.message.content.parts.join('');
      }

      if (text && text !== (state && state.accumulatedText)) {
        var prev = (state && state.accumulatedText) || '';
        var delta = '';
        if (isReplace) {
          delta = text;
        } else if (text.length > prev.length && text.indexOf(prev) === 0) {
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
            setTimeout(function() {
              notifyFlutter('done', { fullText: state.accumulatedText, requestId: reqId, source: 'sse' });
            }, 500);
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
              if (event.type === 'done') {
                setTimeout(function() {
                  notifyFlutter('done', { fullText: state.accumulatedText, requestId: reqId, source: 'sse' });
                }, 500);
                return;
              }
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

  // --- Centralized RITMO Selector Table (A-27) ---
  var RITMO_SELECTORS = {
    composer: [
      '#prompt-textarea',
      'div[contenteditable="true"][id="prompt-textarea"]',
      'form div[contenteditable="true"]',
      'textarea[data-id]',
      'textarea[placeholder]',
      'textarea',
      'div[contenteditable="true"]',
      '.ProseMirror'
    ].join(', '),

    sendButton: [
      'button[data-testid="send-button"]',
      'button[data-testid="fruitjuice-send-button"]',
      'button[aria-label*="Send" i]',
      'button[aria-label*="ارسال"]',
      'form button[type="submit"]',
      'button.send-button'
    ].join(', '),

    stopButton: [
      'button[data-testid="stop-button"]',
      'button[data-testid="fruitjuice-stop-button"]',
      'button[aria-label*="Stop" i]',
      'button[aria-label*="توقف"]',
      'button[data-testid*="stop" i]',
      'button.stop-button'
    ].join(', '),

    assistantMessage: [
      '[data-message-author-role="assistant"]',
      'article[data-testid*="conversation-turn"] [data-message-author-role="assistant"]',
      '[data-testid*="assistant"]',
      'div.agent-turn',
      '[class*="agent-turn"]'
    ].join(', '),

    unseenAssistantMessage: [
      '[data-message-author-role="assistant"]:not([data-ritmo-seen="true"])',
      'article[data-testid*="conversation-turn"] [data-message-author-role="assistant"]:not([data-ritmo-seen="true"])',
      '[data-testid*="assistant"]:not([data-ritmo-seen="true"])',
      'div.agent-turn:not([data-ritmo-seen="true"])',
      '[class*="agent-turn"]:not([data-ritmo-seen="true"])'
    ].join(', '),

    userMessage: [
      '[data-message-author-role="user"]',
      'article[data-testid*="conversation-turn"] [data-message-author-role="user"]',
      '[data-testid*="user"]',
      'div.font-user-message'
    ].join(', '),

    markdownBodies: [
      'div.markdown',
      'div.prose',
      '[class*="markdown"]',
      '[class*="prose"]',
      'div.whitespace-pre-wrap',
      '[data-conversation-part="body"]',
      '[data-assistant-writing-block-body]'
    ].join(', '),

    unseenMarkdownBodies: [
      'div.markdown:not([data-ritmo-seen="true"])',
      'div.prose:not([data-ritmo-seen="true"])',
      '[class*="markdown"]:not([data-ritmo-seen="true"])',
      '[class*="prose"]:not([data-ritmo-seen="true"])',
      'div.whitespace-pre-wrap:not([data-ritmo-seen="true"])',
      '[data-conversation-part="body"]:not([data-ritmo-seen="true"])',
      '[data-assistant-writing-block-body]:not([data-ritmo-seen="true"])'
    ].join(', '),

    conversationTurns: [
      'article',
      '[data-testid*="conversation-turn"]',
      '[data-testid*="conversation-turn-"]'
    ].join(', '),

    unseenConversationTurns: [
      'article:not([data-ritmo-seen="true"])',
      '[data-testid*="conversation-turn"]:not([data-ritmo-seen="true"])',
      '[data-testid*="conversation-turn-"]:not([data-ritmo-seen="true"])'
    ].join(', '),

    streamingIndicator: [
      '.result-streaming',
      '.streaming',
      '[data-message-streaming="true"]',
      '[data-is-streaming="true"]',
      'button[data-testid="stop-button"]',
      'button[data-testid="fruitjuice-stop-button"]',
      'button[aria-label*="Stop" i]'
    ].join(', '),

    cloudflare: [
      'iframe[src*="cloudflare"]',
      'iframe[src*="challenges.cloudflare.com"]',
      '#cf-turnstile',
      '#challenge-stage',
      '#challenge-running',
      '.cf-turnstile-wrapper'
    ].join(', '),

    sidebarClose: [
      'button[aria-label*="Close sidebar" i]',
      'button[aria-label*="بستن نوار" i]',
      'button[data-testid*="close-sidebar" i]',
      'button[aria-label="Close navigation"]',
      'button[aria-label="بستن منو"]'
    ].join(', '),

    loginButton: [
      'button[data-testid="login-button"]',
      'a[href*="/login"]',
      'button[data-testid="signup-button"]',
      'a[href*="/signup"]'
    ].join(', '),

    userProfile: [
      'img[alt*="User" i]',
      'button[data-testid*="user-menu" i]',
      'div[data-testid*="profile" i]',
      '[data-testid="accounts-profile-button"]'
    ].join(', ')
  };

  // --- Complete Anchorable Elements for Seen Tagging (A-29) ---
  var RITMO_ANCHORABLE = [
    'article',
    '[data-message-author-role]',
    '[data-testid*="conversation-turn"]',
    '[data-testid*="conversation-turn-"]',
    '[data-testid*="assistant"]',
    'div.agent-turn',
    '[class*="agent-turn"]',
    'div.markdown',
    '[class*="markdown"]',
    'div.prose',
    '[class*="prose"]',
    'div.whitespace-pre-wrap',
    '[data-conversation-part="body"]',
    '[data-assistant-writing-block-body]'
  ].join(', ');

  function querySafe(selector) {
    try {
      return document.querySelector(selector);
    } catch (e) {
      console.warn('[Ritmo] querySafe skipped invalid selector:', selector);
      return null;
    }
  }

  function queryAllSafe(selector) {
    try {
      var r = document.querySelectorAll(selector);
      return r ? Array.prototype.slice.call(r) : [];
    } catch (e) {
      console.warn('[Ritmo] Unsupported selector skipped:', selector);
      return [];
    }
  }

  // --- Selector Self-Test Diagnostic (A-28) ---
  function runSelectorSelfTest() {
    var report = {};
    var keys = ['composer', 'sendButton', 'assistantMessage', 'conversationTurns', 'markdownBodies', 'userMessage'];
    for (var i = 0; i < keys.length; i++) {
      var k = keys[i];
      report[k] = queryAllSafe(RITMO_SELECTORS[k]).length;
    }
    return report;
  }

  // --- 1. Cloudflare Turnstile, Geo-Block & VPN Watcher ---
  var lastCfState = null;
  var lastVpnState = null;

  function checkVpnAndGeoBlockStatus() {
    try {
      var title = document.title || '';
      var bodyEl = document.body;
      var text = bodyEl ? (bodyEl.innerText || bodyEl.textContent || '') : '';
      var lowerText = text.toLowerCase();
      var lowerTitle = title.toLowerCase();

      var isUnableToLoad = lowerText.indexOf('unable to load site') !== -1 || lowerTitle.indexOf('unable to load site') !== -1;
      var isVpnNotice = lowerText.indexOf('if you are using a vpn') !== -1 || lowerText.indexOf('using a vpn, try turning it off') !== -1;
      var isGeoBlocked = lowerText.indexOf('not available in your country') !== -1 ||
                         lowerText.indexOf('services are not available in your country') !== -1 ||
                         lowerText.indexOf('banned your ip') !== -1 ||
                         lowerText.indexOf('banned your country') !== -1 ||
                         lowerText.indexOf('you have been blocked') !== -1 ||
                         lowerText.indexOf('unable to access chatgpt.com') !== -1;
      var isRayBlocked = lowerText.indexOf('ray id:') !== -1 && (lowerText.indexOf('access denied') !== -1 || lowerText.indexOf('error') !== -1 || isUnableToLoad || isVpnNotice);
      var isAccessDenied = lowerTitle.indexOf('access denied') !== -1 || (lowerText.indexOf('access denied') !== -1 && lowerText.indexOf('error code') !== -1);

      var isVpnRequired = isUnableToLoad || isVpnNotice || isGeoBlocked || isRayBlocked || isAccessDenied;

      if (isVpnRequired !== lastVpnState) {
        lastVpnState = isVpnRequired;
        if (isVpnRequired) {
          var rayMatch = text.match(/ray id:\s*([a-f0-9]+)/i);
          var ipMatch = text.match(/ip:\s*([a-f0-9:.]+)/i);
          notifyFlutter('vpn_required', {
            detected: true,
            reason: isUnableToLoad ? 'unable_to_load_site' : (isVpnNotice ? 'vpn_notice' : 'geo_blocked'),
            rayId: rayMatch ? rayMatch[1] : null,
            ip: ipMatch ? ipMatch[1] : null,
            title: title,
            source: 'lifecycle'
          });
        }
      }
      return isVpnRequired;
    } catch (e) {
      console.warn('[Ritmo] checkVpnAndGeoBlockStatus error:', e);
      return false;
    }
  }

  function checkCloudflareStatus() {
    var title = document.title || '';
    var isCfTitle = title.includes('Just a moment') || title.includes('Security Check') || title.includes('Cloudflare') || title.includes('Attention Required');
    var hasCfIframe = !!querySafe(RITMO_SELECTORS.cloudflare);
    var isChallenged = isCfTitle || hasCfIframe;

    if (isChallenged !== lastCfState) {
      lastCfState = isChallenged;
      if (isChallenged) {
        notifyFlutter('cloudflare_challenge', { detected: true, title: title, source: 'lifecycle' });
      } else {
        notifyFlutter('cloudflare_resolved', { detected: false, source: 'lifecycle' });
      }
    }
    return isChallenged;
  }

  function checkSecurityAndBlockStatus() {
    var isVpn = checkVpnAndGeoBlockStatus();
    var isCf = checkCloudflareStatus();
    return { isVpn: isVpn, isCf: isCf, isBlocked: isVpn || isCf };
  }

  // --- 2. Auto Cookie Consent & Login Modal Dismissal (A-38, A-106) ---
  function autoDismissCookiesAndModals() {
    try {
      // 2.1 Native OneTrust API Consent
      try {
        if (window.OneTrust && typeof window.OneTrust.AllowAll === 'function') {
          window.OneTrust.AllowAll();
          notifyFlutter('auto_dismiss', { label: 'OneTrust.AllowAll', source: 'lifecycle' });
        } else if (window.OneTrust && typeof window.OneTrust.Close === 'function') {
          window.OneTrust.Close();
        }
        if (typeof window.OnetrustActiveGroups !== 'undefined') {
          window.OnetrustActiveGroups = ',C0001,C0002,C0003,C0004,';
        }
      } catch (otErr) {}

      // 2.2 Inject CSS rule to hide cookie overlays immediately
      try {
        var styleId = '__ritmo_cookie_suppress_css';
        if (!document.getElementById(styleId)) {
          var st = document.createElement('style');
          st.id = styleId;
          st.textContent = '#onetrust-banner-sdk, #onetrust-consent-sdk, .onetrust-pc-dark-filter, .cookie-banner, [data-testid="cookie-banner"], [id*="cookie-banner"], #onetrust-style { display: none !important; opacity: 0 !important; pointer-events: none !important; }';
          (document.head || document.documentElement).appendChild(st);
        }
      } catch (cssErr) {}

      // Never dismiss or click buttons while active generation is ongoing (A-38)
      if (window.__ritmo_active_req_id) return;

      var directSelectors = [
        '#onetrust-accept-btn-handler',
        '#onetrust-pc-btn-handler',
        '#accept-recommended-btn-handler',
        'button[id*="onetrust-accept"]',
        'button[data-testid="accept-cookies"]',
        'button[data-testid="cookie-banner-accept"]',
        'button[data-testid="close-button"]',
        'button[aria-label*="Accept all" i]',
        'button[aria-label*="Accept cookies" i]',
        'button[aria-label*="Allow all" i]',
        '.osano-cm-accept-all',
        '.cc-btn.cc-allow',
        '#cookie-accept',
        '.cookie-accept',
        'button[class*="cookie-accept"]',
        'button[class*="accept-cookie"]'
      ];

      for (var i = 0; i < directSelectors.length; i++) {
        var el = querySafe(directSelectors[i]);
        if (el && el.offsetParent !== null) {
          el.click();
          notifyFlutter('auto_dismiss', { label: directSelectors[i], source: 'lifecycle' });
        }
      }

      // Restrict keyword dismissal strictly to modal dialog containers (A-38)
      var modalContainers = queryAllSafe('[role="dialog"], [aria-modal="true"], [data-testid*="modal"], [id*="cookie"], [class*="cookie"], #onetrust-banner-sdk');
      var dismissKeywords = [
        'accept all', 'accept cookies', 'allow all', 'i accept', 'got it',
        'accept essential cookies', 'accept recommended cookies', 'allow cookies',
        'قبول همه', 'موافقم', 'پذیرش همه', 'قبول'
      ];

      for (var m = 0; m < modalContainers.length; m++) {
        var container = modalContainers[m];
        var buttons = container.querySelectorAll('button, [role="button"]');
        for (var j = 0; j < buttons.length; j++) {
          var btn = buttons[j];
          if (btn.closest('form') || btn.closest('main') || btn.closest('article')) continue;
          if (btn.offsetParent === null) continue;
          var txt = (btn.innerText || btn.textContent || '').trim().toLowerCase();
          if (dismissKeywords.indexOf(txt) !== -1) {
            btn.click();
            notifyFlutter('auto_dismiss', { label: txt, source: 'lifecycle' });
          }
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

  function autoCloseSidebar() {
    try {
      if (window.__ritmo_active_req_id) return;

      var closeBtn = querySafe(RITMO_SELECTORS.sidebarClose);
      if (closeBtn && isVisiblyOnScreen(closeBtn)) {
        closeBtn.click();
        return;
      }

      var backdrops = queryAllSafe('div.fixed.inset-0, div[class*="backdrop"], div[class*="sidebar-mask"]');
      for (var j = 0; j < backdrops.length; j++) {
        var bd = backdrops[j];
        if (bd && isVisiblyOnScreen(bd)) {
          bd.click();
          return;
        }
      }
    } catch (e) {
      console.warn('[Ritmo] Auto-close sidebar error:', e);
    }
  }

  // --- 4. Robust Live Assistant Text Extractor (A-30, A-33) ---
  var RITMO_STRIP = [
    'button',
    '[role="button"]',
    '[data-testid*="thinking"]',
    '[data-testid*="reasoning"]',
    'details[data-testid*="thought"]',
    '[class*="sr-only"]',
    '[aria-hidden="true"]'
  ].join(', ');

  function extractCleanText(el) {
    if (!el) return '';
    try {
      var clone = el.cloneNode(true);
      var stripElements = clone.querySelectorAll(RITMO_STRIP);
      for (var s = 0; s < stripElements.length; s++) {
        var stripEl = stripElements[s];
        if (!stripEl.closest('pre')) {
          stripEl.remove();
        }
      }

      var target = clone.querySelector('.markdown, .prose, [class*="markdown"], [class*="prose"], [data-conversation-part="body"], [data-assistant-writing-block-body], div.whitespace-pre-wrap') || clone;
      var rawText = (target.innerText || target.textContent || '').trim();
      if (!rawText && clone !== target) {
        rawText = (clone.innerText || clone.textContent || '').trim();
      }
      if (!rawText) return '';

      rawText = rawText.replace(/^[•\-\*\s:]*(ChatGPT\s*said:?|:ChatGPT\s*said:?|ChatGPT:?|You\s*said:?|:You\s*said:?|Assistant\s*said:?)[\s:]*/gmi, '');
      rawText = rawText.replace(/^[•\-\*\s:]+/g, '');

      if (rawText.indexOf('[data-conversation-') !== -1 || rawText.indexOf('--component-') !== -1) {
        rawText = rawText.replace(/\[data-[^\]]+\]\s*\{[^}]*\}/g, '');
        rawText = rawText.replace(/--[a-zA-Z0-9_-]+:[^;]+;?/g, '');
      }
      return rawText.trim();
    } catch (e) {
      console.warn('[Ritmo] extractCleanText clone error:', e);
      var directTarget = el.querySelector('.markdown, .prose') || el;
      return (directTarget.innerText || directTarget.textContent || '').trim();
    }
  }

  function findLatestAssistantText() {
    try {
      // Strategy 1: ID/Turn-count based anchor (A-30)
      var turnCountAtSend = window.__ritmo_turn_count_at_send || 0;
      var articles = queryAllSafe(RITMO_SELECTORS.conversationTurns);
      if (articles.length > turnCountAtSend && articles.length > 0) {
        var lastTurn = articles[articles.length - 1];
        var isUser = !!lastTurn.querySelector(RITMO_SELECTORS.userMessage) || (lastTurn.getAttribute('data-testid') || '').indexOf('user') !== -1;
        if (!isUser) {
          var t1 = extractCleanText(lastTurn);
          if (t1) return t1;
        }
      }

      // Strategy 2: Last assistant message after the last user message (A-30)
      var allRoles = queryAllSafe('[data-message-author-role]');
      if (allRoles.length > 0) {
        var lastUserIdx = -1;
        for (var u = allRoles.length - 1; u >= 0; u--) {
          if (allRoles[u].getAttribute('data-message-author-role') === 'user') {
            lastUserIdx = u;
            break;
          }
        }
        if (lastUserIdx !== -1 && lastUserIdx < allRoles.length - 1) {
          for (var a = allRoles.length - 1; a > lastUserIdx; a--) {
            if (allRoles[a].getAttribute('data-message-author-role') === 'assistant') {
              var t2 = extractCleanText(allRoles[a]);
              if (t2) return t2;
            }
          }
        }
      }

      // Strategy 3: data-ritmo-seen (A-30 fallback)
      var unseenAssistants = queryAllSafe(RITMO_SELECTORS.unseenAssistantMessage);
      if (unseenAssistants.length > 0) {
        var lastUnseen = unseenAssistants[unseenAssistants.length - 1];
        var t3 = extractCleanText(lastUnseen);
        if (t3) return t3;
      }

      var unseenMarkdowns = queryAllSafe(RITMO_SELECTORS.unseenMarkdownBodies);
      for (var j = unseenMarkdowns.length - 1; j >= 0; j--) {
        var md = unseenMarkdowns[j];
        if (!md.closest(RITMO_SELECTORS.userMessage)) {
          var tMd = extractCleanText(md);
          if (tMd) return tMd;
        }
      }

      var unseenArticles = queryAllSafe(RITMO_SELECTORS.unseenConversationTurns);
      for (var i = unseenArticles.length - 1; i >= 0; i--) {
        var art = unseenArticles[i];
        var isUserArt = !!art.querySelector(RITMO_SELECTORS.userMessage) || (art.getAttribute('data-testid') || '').indexOf('user') !== -1;
        if (!isUserArt) {
          var tArt = extractCleanText(art);
          if (tArt) return tArt;
        }
      }

      // Fallback 4: Global assistant search
      var assistants = queryAllSafe(RITMO_SELECTORS.assistantMessage);
      if (assistants.length > 0) {
        var tAll = extractCleanText(assistants[assistants.length - 1]);
        if (tAll) return tAll;
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
  var tickCount = 0;

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
    tickCount = 0;
    previousBaselineText = (previousBaselineText || '').trim();

    if (streamCheckTimer) clearInterval(streamCheckTimer);
    stopDomObserver();

    // Emits delta when extending previous text, and fullText on periodic sync or rewrite (A-37)
    function checkAndEmitChunk(forceFull) {
      var currentText = findLatestAssistantText();
      if (!currentText || currentText === previousBaselineText) return;

      tickCount++;
      var isPeriodicSync = (tickCount % 10 === 0) || forceFull === true;

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
        var isPrefix = (currentText.length > lastLength && currentText.indexOf(lastText) === 0);
        if (isPrefix && !isPeriodicSync) {
          delta = currentText.substring(lastLength);
          lastText = currentText;
          lastLength = currentText.length;
          lastChangeTimestamp = Date.now();
          notifyFlutter('chunk', { delta: delta, requestId: reqId, source: 'dom' });
        } else {
          delta = isPrefix ? currentText.substring(lastLength) : currentText;
          lastText = currentText;
          lastLength = currentText.length;
          lastChangeTimestamp = Date.now();
          notifyFlutter('chunk', { delta: delta, fullText: currentText, requestId: reqId, source: 'dom' });
        }
      }
    }

    if (typeof MutationObserver !== 'undefined') {
      try {
        domObserver = new MutationObserver(function() {
          checkAndEmitChunk(false);
        });
        domObserver.observe(document.body, { childList: true, subtree: true, characterData: true });
        console.log('[Ritmo] MutationObserver attached for DOM stream watching.');
      } catch (obsErr) {
        console.warn('[Ritmo] MutationObserver init failed, using polling timer only:', obsErr);
      }
    }

    var lastWatcherTickTime = Date.now();

    streamCheckTimer = setInterval(function() {
      checkAndEmitChunk(false);

      var now = Date.now();
      if (!lastWatcherTickTime || (now - lastWatcherTickTime >= 5000)) {
        lastWatcherTickTime = now;
        var stopBtnEl = querySafe(RITMO_SELECTORS.stopButton);
        var isStreamingEl = querySafe(RITMO_SELECTORS.streamingIndicator);
        var assistantNodesCount = queryAllSafe(RITMO_SELECTORS.assistantMessage).length;
        var turnCountNum = queryAllSafe(RITMO_SELECTORS.conversationTurns).length;
        var markdownBodiesCount = queryAllSafe(RITMO_SELECTORS.markdownBodies).length;
        var idleMsNum = now - lastChangeTimestamp;
        var elapsedMsNum = now - streamStartTime;
        notifyFlutter('watcher_tick', {
          requestId: reqId,
          source: 'dom',
          textLength: lastLength,
          hasStopButton: !!stopBtnEl,
          hasStreamingIndicator: !!isStreamingEl,
          assistantNodes: assistantNodesCount,
          turnCount: turnCountNum,
          markdownBodies: markdownBodiesCount,
          idleMs: idleMsNum,
          elapsedMs: elapsedMsNum
        });
      }

      var totalDuration = Date.now() - streamStartTime;
      var currentText = findLatestAssistantText();

      if (!currentText || currentText === previousBaselineText) {
        if (totalDuration > 170000) {
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
      } else if (totalDuration > 175000) {
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

    var sawGeneratingSignal = false;

    function evaluateStreamCompletion() {
      var stopButton = querySafe(RITMO_SELECTORS.stopButton);
      var isStreamingClass = querySafe(RITMO_SELECTORS.streamingIndicator);
      var isGenerating = !!stopButton || !!isStreamingClass;

      if (isGenerating) {
        sawGeneratingSignal = true;
        return false;
      }

      var idleMs = Date.now() - lastChangeTimestamp;

      // Confirmed generating transition: stop button observed then disappeared (A-15)
      if (sawGeneratingSignal && lastLength > 0 && idleMs > 800) {
        return true;
      }

      // Unconfirmed generating fallback (A-15)
      if (lastLength > 0 && idleMs > 4000) {
        return true;
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
            notifyFlutter('composer_not_found', { requestId: reqId, source: 'dom' });
            notifyFlutter('error', { message: 'فیلد ورودی متن ChatGPT هنوز لود نشده است.', requestId: reqId, source: 'dom' });
          }
        }, 500);
        return;
      }

      injectAndTriggerSend(textarea, promptText, reqId);

      function injectAndTriggerSend(editor, text, currentReqId) {
        autoCloseSidebar();
        autoDismissCookiesAndModals();

        window.__ritmo_active_req_id = currentReqId || '';
        window.__ritmo_turn_count_at_send = queryAllSafe(RITMO_SELECTORS.conversationTurns).length;

        // Anchor existing messages with complete set of elements (A-29)
        queryAllSafe(RITMO_ANCHORABLE).forEach(function(el) {
          el.setAttribute('data-ritmo-seen', 'true');
        });

        var previousBaselineText = findLatestAssistantText();
        window.__ritmo_turn_baseline = previousBaselineText || '';

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

        notifyFlutter('prompt_typed', { length: text.length, requestId: currentReqId, source: 'dom' });

        var sendCheckAttempts = 0;
        var sendClicked = false;
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
            var matchedSel = RITMO_SELECTORS.sendButton;
            var candidateNodes = queryAllSafe(RITMO_SELECTORS.sendButton);
            notifyFlutter('send_clicked', {
              requestId: currentReqId,
              matchedSelector: matchedSel,
              candidateCount: candidateNodes.length,
              source: 'dom'
            });
            window.__ritmo_startStreamingWatcher(previousBaselineText, currentReqId);
          } else if (sendCheckAttempts >= 8) {
            clearInterval(sendInterval);
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
              notifyFlutter('send_fallback_enter', { requestId: currentReqId, source: 'dom' });
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

      window.__ritmo_active_req_id = reqId;

      console.log('[Ritmo] __ritmo_resume invoked for reqId: ' + reqId + ' (stage: ' + stage + ', received: ' + receivedLength + ')');

      var currentText = findLatestAssistantText();

      if (currentText && currentText.length > 0) {
        notifyFlutter('resumed', { stage: 'streaming', requestId: reqId, recoveredLength: currentText.length, source: 'dom' });
        notifyFlutter('chunk', { fullText: currentText, requestId: reqId, source: 'dom' });
      } else {
        notifyFlutter('resumed', { stage: 'streaming', requestId: reqId, recoveredLength: 0, source: 'dom' });
      }

      window.__ritmo_startStreamingWatcher(window.__ritmo_turn_baseline || '', reqId);
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

  // --- 8.1 Force Harvest Visible Answer ---
  window.__ritmo_forceHarvest = function(reqId) {
    try {
      reqId = reqId || window.__ritmo_active_req_id || '';
      var text = findLatestAssistantText() || '';
      notifyFlutter('harvest_result', {
        fullText: text,
        requestId: reqId,
        strategy: 'dom_direct',
        source: 'harvest'
      });
      return text;
    } catch (e) {
      notifyFlutter('harvest_result', {
        fullText: '',
        error: e.toString(),
        requestId: reqId,
        strategy: 'dom_direct_failed',
        source: 'harvest'
      });
      return '';
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

  var securityStatus = checkSecurityAndBlockStatus();
  autoDismissCookiesAndModals();
  autoCloseSidebar();
  checkAuthState();
  cfCheckTimer = setInterval(checkSecurityAndBlockStatus, 2000);

  // Self-test report at boot (A-28)
  try {
    var selfTestReport = runSelectorSelfTest();
    notifyFlutter('selector_health', {
      report: selfTestReport,
      bridgeVersion: requiredVersion,
      source: 'lifecycle'
    });
  } catch (stErr) {
    console.warn('[Ritmo] Selector self test error:', stErr);
  }

  console.log('[Ritmo] Bridge setup complete.');

  if (!securityStatus.isBlocked) {
    notifyFlutter('ready', {
      version: requiredVersion,
      isWarm: false,
      currentPath: window.location.pathname || '',
      hasComposer: checkComposerPresent(),
      source: 'lifecycle'
    });
  } else {
    if (securityStatus.isVpn) {
      console.warn('[Ritmo] VPN/Geo-block detected at boot; withholding ready.');
    } else {
      console.warn('[Ritmo] Cloudflare challenge active at boot; withholding ready.');
    }
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
