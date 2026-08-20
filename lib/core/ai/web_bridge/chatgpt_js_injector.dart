import 'dart:convert';
import 'chatgpt_bridge_timeouts.dart';

/// Utilities and JavaScript scripts for injecting into ChatGPT Web (chatgpt.com)
class ChatGptJsInjector {
  /// The current protocol version of the bridge script. Bump whenever JS/Dart communication contract changes.
  static const int bridgeVersion = 19;

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
        : 'شما دستیار هوشمند و اختصاصی اپلیکیشن «ریتمو» (Ritmo AI) هستید. شما یک ایجنت فعال و متصل به ابزارهای دیتابیس برنامه هستید. وظیفه شما راهنمایی دقیق، دلسوزانه، مختصر و کاربردی به زبان فارسی در زمینه مدیریت روتین‌ها، اهداف، سبک زندگی و برنامه‌ریزی روزانه کاربر است. قوانین: ۱. همیشه به زبان فارسی روان و شمرده پاسخ دهید. ۲. برای ساخت، تغییر یا ثبت هر بخش برنامه، مستقیماً از ابزارهای تعریف‌شده استفاده کنید. ۳. از تعارفات زائد پرهیز کنید و پاسخ‌ها را ساختاریافته ارائه دهید.';

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

  function isConversationEndpoint(url) {
    if (typeof url !== 'string') return false;
    return /[\/\.-]backend-(?:api|anon)\/(?:conversation|lat\/r|f\/r|synthesize)/i.test(url)
        || /[\/\.-]backend-api\/conversation/i.test(url)
        || /[\/\.-]unauth-mweb\/(?:conversation|sentinel|lat\/r)/i.test(url)
        || (/[\/\.-]conversation/i.test(url) && !/[\/\.-]conversation\/prepare/i.test(url));
  }

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
    } catch (e) {}
    return null;
  }
  window.__ritmo_parseSSELine = parseSSELine;

  function readSSEStream(reader, reqId) {
    var state = { accumulatedText: '', firstTokenEmitted: false, startTime: Date.now() };
    var decoder = typeof TextDecoder !== 'undefined' ? new TextDecoder('utf-8') : null;
    var buffer = '';

    function emitEvent(evtType, payload) {
      try {
        if (typeof notifyFlutter === 'function') {
          notifyFlutter(evtType, payload);
        } else if (window.RitmoChatBridge && window.RitmoChatBridge.postMessage) {
          var data = payload || {};
          data.type = evtType;
          if (!data.source) data.source = 'sse';
          window.RitmoChatBridge.postMessage(JSON.stringify(data));
        }
      } catch (e) {}
    }

    function pump() {
      return reader.read().then(function(result) {
        if (result.done) {
          if (state.accumulatedText.length > 0) {
            setTimeout(function() {
              emitEvent('done', { fullText: state.accumulatedText, requestId: reqId, source: 'sse' });
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
                  emitEvent('done', { fullText: state.accumulatedText, requestId: reqId, source: 'sse' });
                }, 500);
                return;
              }
              if (!state.firstTokenEmitted && event.type === 'chunk') {
                state.firstTokenEmitted = true;
                emitEvent('first_token', {
                  length: (event.delta && event.delta.length) || 0,
                  requestId: reqId,
                  latencyMs: Date.now() - state.startTime,
                  source: 'sse'
                });
              }
              emitEvent(event.type, event);
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

  // 1. Fetch Hook with response.body.tee availability guard (A-34)
  var originalFetch = window.fetch;
  if (originalFetch && !window.__ritmo_fetch_hooked) {
    window.__ritmo_fetch_hooked = true;
    window.__ritmo_original_fetch = originalFetch;
    window.fetch = function() {
      var args = arguments;
      var input = args[0];
      var init = args[1];
      var url = '';
      var method = 'GET';

      if (typeof input === 'string') {
        url = input;
        method = (init && init.method) || 'GET';
      } else if (input && typeof input === 'object') {
        url = input.url || '';
        method = (init && init.method) || input.method || 'GET';
      }

      var isConvo = isConversationEndpoint(url);
      var activeReqId = window.__ritmo_active_req_id || (window.__ritmo_state && window.__ritmo_state.activeRequestId) || '';

      if (window.RitmoChatBridge && window.RitmoChatBridge.postMessage) {
        try {
          window.RitmoChatBridge.postMessage(JSON.stringify({
            type: 'fetch_matched',
            url: (typeof url === 'string') ? url.slice(0, 150) : '',
            method: method,
            isStream: isConvo,
            requestId: activeReqId,
            source: 'fetch_hook'
          }));
        } catch (e) {}
      }

      if (isConvo) {
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
      var isConvo = isConversationEndpoint(url);

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
      var isConvo = isConversationEndpoint(url);

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

  // --- Centralized RITMO Timeout Constants (DET-32) ---
  var RITMO_TIMEOUTS = {
    watcherTimeoutMs: ${ChatGptBridgeTimeouts.generationTimeout.inMilliseconds - 10000},
    watcherHardTimeoutMs: ${ChatGptBridgeTimeouts.generationTimeout.inMilliseconds - 5000},
    heartbeatIntervalMs: 5000,
    streamPollIntervalMs: ${ChatGptBridgeTimeouts.heartbeatInterval.inMilliseconds},
    cfCheckIntervalMs: 300,
    fastPollMs: ${ChatGptBridgeTimeouts.pollFastInterval.inMilliseconds}
  };

  window.__RITMO_BRIDGE_V = requiredVersion;
  console.log('[Ritmo] Initializing ChatGPT Web Bridge version ' + requiredVersion + '...');
$_bridgeScriptBody''';

  static const String _bridgeScriptBody = r'''
  function isConversationEndpoint(url) {
    if (typeof url !== 'string') return false;
    return /[\/\.-]backend-(?:api|anon)\/(?:conversation|lat\/r|f\/r|synthesize)/i.test(url)
        || /[\/\.-]backend-api\/conversation/i.test(url)
        || /[\/\.-]unauth-mweb\/(?:conversation|sentinel|lat\/r)/i.test(url)
        || (/[\/\.-]conversation/i.test(url) && !/[\/\.-]conversation\/prepare/i.test(url));
  }

  // --- 0. Global Fetch Interceptor Hook (A-34, A-35) ---
  var originalFetch = window.fetch;
  if (originalFetch && !window.__ritmo_fetch_hooked) {
    window.__ritmo_fetch_hooked = true;
    window.__ritmo_original_fetch = originalFetch;
    window.fetch = function() {
      var args = arguments;
      var input = args[0];
      var init = args[1];
      var url = '';
      var method = 'GET';

      if (typeof input === 'string') {
        url = input;
        method = (init && init.method) || 'GET';
      } else if (input && typeof input === 'object') {
        url = input.url || '';
        method = (init && init.method) || input.method || 'GET';
      }

      var isConvo = isConversationEndpoint(url);
      var activeReqId = window.__ritmo_active_req_id || (window.__ritmo_state && window.__ritmo_state.activeRequestId) || '';

      notifyFlutter('fetch_matched', {
        url: (typeof url === 'string') ? url.slice(0, 150) : '',
        method: method,
        isStream: isConvo,
        requestId: activeReqId,
        source: 'fetch_hook'
      });

      if (isConvo) {
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
      'button.send-button',
      'button[data-testid*="send" i]',
      'button[aria-label="Send prompt"]',
      'button[aria-label="Send message"]'
    ].join(', '),

    stopButton: [
      'button[data-testid="stop-button"]',
      'button[data-testid="fruitjuice-stop-button"]',
      'button[aria-label*="Stop" i]',
      'button[aria-label*="توقف"]',
      'button[data-testid*="stop" i]',
      'button.stop-button',
      'button[aria-label="Stop generating"]',
      'button[aria-label="Stop streaming"]'
    ].join(', '),

    assistantMessage: [
      '[data-message-author-role="assistant"]',
      '[data-message-model-slug]',
      'article [data-message-author-role="assistant"]',
      '[data-testid*="assistant"]',
      'div.agent-turn',
      '[class*="agent-turn"]',
      'div[data-message-id]:not([data-message-author-role="user"])',
      'div.text-message[data-role="assistant"]',
      'div[data-testid*="conversation-turn"]:not([data-testid*="user"])'
    ].join(', '),

    unseenAssistantMessage: [
      '[data-message-author-role="assistant"]:not([data-ritmo-seen="true"])',
      '[data-message-model-slug]:not([data-ritmo-seen="true"])',
      'article [data-message-author-role="assistant"]:not([data-ritmo-seen="true"])',
      '[data-testid*="assistant"]:not([data-ritmo-seen="true"])',
      'div.agent-turn:not([data-ritmo-seen="true"])',
      '[class*="agent-turn"]:not([data-ritmo-seen="true"])',
      'div[data-message-id]:not([data-message-author-role="user"]):not([data-ritmo-seen="true"])'
    ].join(', '),

    userMessage: [
      '[data-message-author-role="user"]',
      'article[data-testid*="conversation-turn"] [data-message-author-role="user"]',
      '[data-testid*="user"]',
      'div.font-user-message',
      '[class*="user-message"]',
      'div[class*="user-turn"]'
    ].join(', '),

    markdownBodies: [
      'div.markdown',
      'div.prose',
      '[class*="markdown"]',
      '[class*="prose"]',
      'div.whitespace-pre-wrap',
      '[data-conversation-part="body"]',
      '[data-assistant-writing-block-body]',
      'div[class*="text-message"]',
      'div.text-base'
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
      '[data-testid*="conversation-turn-"]',
      '[class*="conversation-turn"]',
      'div[class*="group/conversation-turn"]',
      'div[data-message-id]'
    ].join(', '),

    unseenConversationTurns: [
      'article:not([data-ritmo-seen="true"])',
      '[data-testid*="conversation-turn"]:not([data-ritmo-seen="true"])',
      '[data-testid*="conversation-turn-"]:not([data-ritmo-seen="true"])',
      '[class*="conversation-turn"]:not([data-ritmo-seen="true"])',
      'div[class*="group/conversation-turn"]:not([data-ritmo-seen="true"])',
      'div[data-message-id]:not([data-ritmo-seen="true"])'
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
  var hadCloudflareChallenge = false;
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
                         lowerText.indexOf('unable to access chatgpt.com') !== -1 ||
                         lowerTitle.indexOf('not available in your country') !== -1 ||
                         lowerText.indexOf('access denied') !== -1;
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
    if (isChallenged) {
      try {
        var styleId = '__ritmo_cf_isolation_style';
        var styleEl = document.getElementById(styleId);
        if (!styleEl) {
          styleEl = document.createElement('style');
          styleEl.id = styleId;
          styleEl.textContent = 'html, body { background: #ffffff !important; overflow: hidden !important; display: flex !important; flex-direction: column !important; align-items: center !important; justify-content: center !important; min-height: 100vh !important; margin: 0 !important; padding: 0 !important; } header, nav, aside, footer, #stage, .sidebar, [data-testid*="sidebar"], [data-testid*="login"], [data-testid*="signup"], a[href*="/login"], a[href*="/signup"], .auth-header, div[class*="logo"], div[class*="brand"], div.text-token-text-primary, #app { opacity: 0 !important; pointer-events: none !important; } #challenge-stage, #challenge-form, .challenge-form, #cf-turnstile, .cf-turnstile-wrapper, iframe[src*="cloudflare"], iframe[src*="challenges"] { opacity: 1 !important; display: block !important; margin: 0 auto !important; pointer-events: auto !important; visibility: visible !important; transform: scale(1.1) !important; transform-origin: center center !important; }';
          (document.head || document.documentElement).appendChild(styleEl);
        }
      } catch (cfStyleErr) {
        console.warn('[Ritmo] Error applying CF isolation style:', cfStyleErr);
      }
    } else {
      try {
        var existingStyle = document.getElementById('__ritmo_cf_isolation_style');
        if (existingStyle && existingStyle.parentNode) {
          existingStyle.parentNode.removeChild(existingStyle);
        }
      } catch (rmErr) {}
    }

    if (isChallenged !== lastCfState) {
      lastCfState = isChallenged;
      if (isChallenged) {
        hadCloudflareChallenge = true;
        notifyFlutter('cloudflare_challenge', { detected: true, title: title, source: 'lifecycle' });
      } else if (hadCloudflareChallenge) {
        hadCloudflareChallenge = false;
        notifyFlutter('cloudflare_resolved', { detected: false, source: 'lifecycle' });
        notifyFlutter('ready', {
          version: requiredVersion,
          isWarm: true,
          currentPath: window.location.pathname || '',
          hasComposer: checkComposerPresent(),
          source: 'lifecycle'
        });
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
  function isNonMessageOrDisclaimer(el) {
    if (!el) return true;
    if (el.closest && el.closest('header, footer, nav, [role="navigation"], form, [data-testid*="banner"], [class*="banner"], [class*="auth"], [data-testid*="auth"], [data-testid*="login"], [data-testid*="signup"], [id*="auth"]')) {
      return true;
    }
    var text = (el.innerText || el.textContent || '').trim().toLowerCase();
    if (!text) return true;

    // Disclaimers & Footers
    if (text.indexOf('make mistakes') !== -1 || text.indexOf('is ai and can') !== -1 || text.indexOf('important info') !== -1 || text.indexOf('اشتباه کند') !== -1 || text.indexOf('خطا کند') !== -1) {
      return true;
    }

    // Login & Promo Banners
    if (text.indexOf('smarter responses') !== -1 || text.indexOf('upload files') !== -1 || text.indexOf('sign up for free') !== -1 || text.indexOf('stay logged out') !== -1 || text === 'log in' || text === 'sign up' || text === 'terms' || text === 'privacy') {
      return true;
    }

    // Composer & Placeholders
    if (text === 'ask anything' || text === 'message chatgpt' || text === 'send message' || text.indexOf('پرسیدن هر سوالی') !== -1) {
      return true;
    }

    var curr = el;
    for (var i = 0; i < 5 && curr && curr !== document.body; i++) {
      if (curr.querySelector && (curr.querySelector('button[data-testid*="signup"], a[href*="signup"], button[data-testid*="login"], a[href*="login"]') || (curr.innerText && curr.innerText.indexOf('Sign up for free') !== -1))) {
        var cText = (curr.innerText || '').trim();
        if (cText.length < 600 && (cText.indexOf('Sign up for free') !== -1 || cText.indexOf('Log in') !== -1 || cText.indexOf('smarter responses') !== -1)) {
          return true;
        }
      }
      curr = curr.parentElement;
    }

    return false;
  }

  function domNodeToMarkdown(node) {
    if (!node) return '';
    if (node.nodeType === 3) {
      return node.nodeValue || '';
    }
    if (node.nodeType === 1) {
      var tag = (node.tagName || '').toUpperCase();
      if (tag === 'SCRIPT' || tag === 'STYLE' || tag === 'NOSCRIPT' || tag === 'SVG' || tag === 'BUTTON' || tag === 'NAV') {
        return '';
      }
      if (node.getAttribute) {
        var testId = (node.getAttribute('data-testid') || '').toLowerCase();
        if (testId.indexOf('thought') !== -1 || testId.indexOf('thinking') !== -1 || testId.indexOf('reasoning') !== -1) {
          return '';
        }
        var className = (node.className || '');
        if (typeof className === 'string' && (className.indexOf('code-header') !== -1 || className.indexOf('copy-button') !== -1 || className.indexOf('sr-only') !== -1)) {
          return '';
        }
      }
      if (tag === 'DETAILS' && (node.getAttribute('data-testid') || '').indexOf('thought') !== -1) {
        return '';
      }

      if (tag === 'BR') return '\n';
      if (tag === 'HR') return '\n\n---\n\n';

      if (tag === 'PRE') {
        var codeEl = node.querySelector('code');
        var lang = '';
        if (codeEl) {
          var cls = (codeEl.className || '');
          var m = cls.match(/language-([a-zA-Z0-9_-]+)/);
          if (m) lang = m[1];
          var codeText = codeEl.innerText || codeEl.textContent || '';
          return '\n\n```' + lang + '\n' + codeText.replace(/\r\n/g, '\n').trim() + '\n```\n\n';
        }
        var rawPre = node.innerText || node.textContent || '';
        return '\n\n```\n' + rawPre.replace(/\r\n/g, '\n').trim() + '\n```\n\n';
      }

      if (tag === 'CODE') {
        var codeInner = (node.innerText || node.textContent || '').trim();
        if (!codeInner) return '';
        return '`' + codeInner + '`';
      }

      var children = node.childNodes;
      var inner = '';
      for (var i = 0; i < children.length; i++) {
        inner += domNodeToMarkdown(children[i]);
      }

      if (tag === 'H1') return '\n\n# ' + inner.trim() + '\n\n';
      if (tag === 'H2') return '\n\n## ' + inner.trim() + '\n\n';
      if (tag === 'H3') return '\n\n### ' + inner.trim() + '\n\n';
      if (tag === 'H4') return '\n\n#### ' + inner.trim() + '\n\n';
      if (tag === 'H5') return '\n\n##### ' + inner.trim() + '\n\n';
      if (tag === 'H6') return '\n\n###### ' + inner.trim() + '\n\n';

      if (tag === 'STRONG' || tag === 'B') {
        var trimmedBold = inner.trim();
        if (!trimmedBold) return inner;
        var leadSpace = /^\s/.test(inner) ? ' ' : '';
        var trailSpace = /\s$/.test(inner) ? ' ' : '';
        return leadSpace + '**' + trimmedBold + '**' + trailSpace;
      }

      if (tag === 'EM' || tag === 'I') {
        var trimmedItalic = inner.trim();
        if (!trimmedItalic) return inner;
        var leadSpaceI = /^\s/.test(inner) ? ' ' : '';
        var trailSpaceI = /\s$/.test(inner) ? ' ' : '';
        return leadSpaceI + '*' + trimmedItalic + '*' + trailSpaceI;
      }

      if (tag === 'DEL' || tag === 'S' || tag === 'STRIKE') {
        var trimmedStrike = inner.trim();
        if (!trimmedStrike) return inner;
        return '~~' + trimmedStrike + '~~';
      }

      if (tag === 'BLOCKQUOTE') {
        var lines = inner.trim().split('\n');
        var quoted = [];
        for (var q = 0; q < lines.length; q++) {
          quoted.push('> ' + lines[q]);
        }
        return '\n\n' + quoted.join('\n') + '\n\n';
      }

      if (tag === 'UL') {
        var lis = node.children;
        var ulResult = '\n';
        for (var u = 0; u < lis.length; u++) {
          var liEl = lis[u];
          if ((liEl.tagName || '').toUpperCase() === 'LI') {
            var liMd = domNodeToMarkdown(liEl).trim();
            if (liMd) ulResult += '• ' + liMd + '\n';
          }
        }
        return ulResult + '\n';
      }

      if (tag === 'OL') {
        var olLis = node.children;
        var olResult = '\n';
        var itemIndex = 1;
        for (var o = 0; o < olLis.length; o++) {
          var olLiEl = olLis[o];
          if ((olLiEl.tagName || '').toUpperCase() === 'LI') {
            var olLiMd = domNodeToMarkdown(olLiEl).trim();
            if (olLiMd) {
              olResult += itemIndex + '. ' + olLiMd + '\n';
              itemIndex++;
            }
          }
        }
        return olResult + '\n';
      }

      if (tag === 'LI') {
        return inner;
      }

      if (tag === 'P') {
        var pTrim = inner.trim();
        return pTrim ? (pTrim + '\n\n') : '';
      }

      if (tag === 'DIV' || tag === 'ARTICLE' || tag === 'SECTION') {
        return inner;
      }

      if (tag === 'A') {
        var href = node.getAttribute('href') || '';
        var linkText = inner.trim() || href;
        return href ? ('[' + linkText + '](' + href + ')') : inner;
      }

      return inner;
    }
    return '';
  }

  function extractCleanText(el) {
    if (!el) return '';
    try {
      if (isNonMessageOrDisclaimer(el)) return '';

      // 1. Locate the inner markdown / prose container if present
      var target = (el.querySelector && el.querySelector('.markdown, .prose, [class*="markdown"], [class*="prose"], [data-conversation-part="body"], [data-assistant-writing-block-body]')) || el;

      // 2. Extract rich structured Markdown via domNodeToMarkdown
      var rawText = domNodeToMarkdown(target).trim();

      // Fallback if domNodeToMarkdown produced nothing
      if (!rawText) {
        rawText = (target.innerText || target.textContent || el.innerText || el.textContent || '').trim();
      }

      if (!rawText) return '';

      var lowerRaw = rawText.toLowerCase();
      if (lowerRaw.indexOf('make mistakes') !== -1 || lowerRaw.indexOf('is ai and can') !== -1 || lowerRaw.indexOf('smarter responses') !== -1) {
        return '';
      }

      // 3. Strip unwanted system prefixes
      rawText = rawText.replace(/^[•\-\*\s:]*(ChatGPT\s*said:?|:ChatGPT\s*said:?|ChatGPT:?|You\s*said:?|:You\s*said:?|Assistant\s*said:?)[\s:]*/gmi, '');

      // 4. Strip CSS / data leakage artifacts
      if (rawText.indexOf('[data-conversation-') !== -1 || rawText.indexOf('--component-') !== -1) {
        rawText = rawText.replace(/\[data-[^\]]+\]\s*\{[^}]*\}/g, '');
        rawText = rawText.replace(/--[a-zA-Z0-9_-]+:[^;]+;?/g, '');
      }

      // Normalize multiple newlines
      rawText = rawText.replace(/\n{3,}/g, '\n\n');

      return rawText.trim();
    } catch (e) {
      console.warn('[Ritmo] extractCleanText error:', e);
      try {
        var fallbackTarget = (el.querySelector && el.querySelector('.markdown, .prose')) || el;
        return (fallbackTarget.innerText || fallbackTarget.textContent || '').trim();
      } catch (fbErr) {
        return '';
      }
    }
  }

  function findLatestAssistantText() {
    try {
      var mainContainer = querySafe('main, [role="main"], div#app, div[class*="react-scroll-to-bottom"]') || document.body;

      // Tier 1: Search for high-level assistant message turn containers (contains all paragraphs, lists, formatting)
      var turnContainers = mainContainer.querySelectorAll([
        '[data-message-author-role="assistant"]',
        'div.agent-turn',
        '[class*="agent-turn"]',
        'div[data-message-id]:not([data-message-author-role="user"])',
        'div.text-message',
        'div.markdown',
        'div.prose',
        '[class*="markdown"]',
        '[class*="prose"]',
        'div[class*="group/conversation-turn"]',
        'div[data-testid*="conversation-turn"]',
        'article:not([data-testid*="user"])'
      ].join(', '));

      var validContainers = [];

      for (var i = 0; i < turnContainers.length; i++) {
        var cEl = turnContainers[i];
        if (isNonMessageOrDisclaimer(cEl)) continue;
        if (cEl.closest('#prompt-textarea') || cEl.closest('form') || cEl.closest('header') || cEl.closest('footer')) continue;
        if (cEl.querySelector(RITMO_SELECTORS.userMessage)) continue;

        var fullClean = extractCleanText(cEl);
        if (fullClean && fullClean.length >= 2) {
          var lower = fullClean.toLowerCase();
          if (lower.indexOf('make mistakes') !== -1 || lower.indexOf('is ai and can') !== -1 || lower.indexOf('smarter responses') !== -1) {
            continue;
          }
          if (fullClean.indexOf('[درخواست جدید کاربر]') !== -1 || fullClean.indexOf('[دستورالعمل سیستم ریتمو]') !== -1) continue;
          if (window.__ritmo_last_user_prompt && (fullClean === window.__ritmo_last_user_prompt || fullClean.indexOf(window.__ritmo_last_user_prompt) !== -1)) continue;

          validContainers.push(fullClean);
        }
      }

      if (validContainers.length > 0) {
        return validContainers[validContainers.length - 1];
      }

      // Tier 2: Unauth-mweb / Mobile fallback: Find the lowest common parent of all paragraphs in the message
      var paragraphs = mainContainer.querySelectorAll('p, div[class*="whitespace-pre-wrap"], div[class*="leading-relaxed"]');
      var parentGroupMap = [];

      for (var j = 0; j < paragraphs.length; j++) {
        var p = paragraphs[j];
        if (isNonMessageOrDisclaimer(p)) continue;
        if (p.closest('#prompt-textarea') || p.closest('form') || p.closest('header') || p.closest('footer')) continue;

        var pRaw = (p.innerText || p.textContent || '').trim();
        if (!pRaw || pRaw.length < 2) continue;
        if (pRaw.indexOf('[درخواست جدید کاربر]') !== -1 || pRaw.indexOf('[دستورالعمل سیستم ریتمو]') !== -1) continue;
        if (window.__ritmo_last_user_prompt && (pRaw === window.__ritmo_last_user_prompt || pRaw.indexOf(window.__ritmo_last_user_prompt) !== -1)) continue;

        var pLower = pRaw.toLowerCase();
        if (pLower.indexOf('make mistakes') !== -1 || pLower.indexOf('is ai and can') !== -1 || pLower.indexOf('smarter responses') !== -1) {
          continue;
        }

        var turnParent = p.closest('div.group, div.relative, div[class*="min-h-"], div[class*="flex-1"], div[class*="space-y-"]') || p.parentElement;
        var parentClean = extractCleanText(turnParent);
        if (parentClean && parentClean.length >= pRaw.length) {
          var exists = false;
          for (var k = 0; k < parentGroupMap.length; k++) {
            if (parentGroupMap[k].el === turnParent) {
              exists = true;
              parentGroupMap[k].text = parentClean;
              break;
            }
          }
          if (!exists) {
            parentGroupMap.push({ el: turnParent, text: parentClean });
          }
        }
      }

      if (parentGroupMap.length > 0) {
        return parentGroupMap[parentGroupMap.length - 1].text;
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
    window.__ritmo_watcher_running = false;
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

  window.__ritmo_startStreamingWatcher = function(baselineOrText, reqId) {
    window.__ritmo_watcher_running = true;
    lastLength = 0;
    lastText = '';
    lastChangeTimestamp = Date.now();
    streamStartTime = Date.now();
    tickCount = 0;

    var baseline = {
      text: '',
      length: 0,
      turnCount: 0,
      assistantNodes: 0
    };

    if (baselineOrText && typeof baselineOrText === 'object') {
      baseline.text = (baselineOrText.text || '').trim();
      baseline.length = baselineOrText.length || baseline.text.length;
      baseline.turnCount = baselineOrText.turnCount || 0;
      baseline.assistantNodes = baselineOrText.assistantNodes || 0;
    } else if (typeof baselineOrText === 'string') {
      baseline.text = baselineOrText.trim();
      baseline.length = baseline.text.length;
    }

    var previousBaselineText = baseline.text;

    if (streamCheckTimer) clearInterval(streamCheckTimer);
    stopDomObserver();

    // Emits delta when extending previous text, and fullText on periodic sync or rewrite (A-37)
    function checkAndEmitChunk(forceFull) {
      var currentText = findLatestAssistantText();
      var currentAssistantNodes = queryAllSafe(RITMO_SELECTORS.assistantMessage).length;
      var currentTurnCount = queryAllSafe(RITMO_SELECTORS.conversationTurns).length;

      var hasNewNode = (baseline.assistantNodes > 0 && currentAssistantNodes > baseline.assistantNodes) ||
                       (baseline.turnCount > 0 && currentTurnCount > baseline.turnCount);

      if (!currentText || (currentText === previousBaselineText && !hasNewNode)) return;

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
          setTimeout(function() {
            try {
              notifyFlutter('selector_health', {
                report: runSelectorSelfTest(),
                bridgeVersion: requiredVersion,
                phase: 'post_first_text',
                requestId: reqId,
                source: 'lifecycle'
              });
            } catch (stPostErr) {}
          }, 3000);
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
      if (!lastWatcherTickTime || (now - lastWatcherTickTime >= RITMO_TIMEOUTS.heartbeatIntervalMs)) {
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
      var currentAssistantNodes = queryAllSafe(RITMO_SELECTORS.assistantMessage).length;
      var currentTurnCount = queryAllSafe(RITMO_SELECTORS.conversationTurns).length;
      var hasNewNode = (baseline.assistantNodes > 0 && currentAssistantNodes > baseline.assistantNodes) ||
                       (baseline.turnCount > 0 && currentTurnCount > baseline.turnCount);

      if (!currentText || (currentText === previousBaselineText && !hasNewNode)) {
        if (totalDuration > RITMO_TIMEOUTS.watcherTimeoutMs) {
          window.__ritmo_watcher_running = false;
          clearInterval(streamCheckTimer);
          streamCheckTimer = null;
          stopDomObserver();
          try {
            notifyFlutter('selector_health', {
              report: runSelectorSelfTest(),
              bridgeVersion: requiredVersion,
              phase: 'pre_timeout',
              requestId: reqId,
              source: 'lifecycle'
            });
          } catch (stPreTimeoutErr) {}
          notifyFlutter('error', { message: 'زمان انتظار برای پاسخ به پایان رسید.', requestId: reqId, source: 'dom' });
        }
        return;
      }

      var isFinished = evaluateStreamCompletion();
      if (isFinished) {
        window.__ritmo_watcher_running = false;
        var finalFullText = findLatestAssistantText() || currentText;
        clearInterval(streamCheckTimer);
        streamCheckTimer = null;
        stopDomObserver();
        notifyFlutter('done', { fullText: finalFullText, requestId: reqId, source: 'dom' });
        console.log('[Ritmo] Stream completed via multi-signal vote with ' + finalFullText.length + ' characters (reqId: ' + reqId + ')');
      } else if (totalDuration > RITMO_TIMEOUTS.watcherHardTimeoutMs) {
        window.__ritmo_watcher_running = false;
        var finalFullText = findLatestAssistantText() || currentText;
        clearInterval(streamCheckTimer);
        streamCheckTimer = null;
        stopDomObserver();
        if (finalFullText.length > 0) {
          notifyFlutter('done', { fullText: finalFullText, requestId: reqId, source: 'dom' });
        } else {
          try {
            notifyFlutter('selector_health', {
              report: runSelectorSelfTest(),
              bridgeVersion: requiredVersion,
              phase: 'pre_timeout',
              requestId: reqId,
              source: 'lifecycle'
            });
          } catch (stPreTimeoutErr) {}
          notifyFlutter('error', { message: 'زمان انتظار برای پاسخ به پایان رسید.', requestId: reqId, source: 'dom' });
        }
      }
    }, RITMO_TIMEOUTS.streamPollIntervalMs);

    var sawGeneratingSignal = false;

    function evaluateStreamCompletion() {
      var stopButton = querySafe(RITMO_SELECTORS.stopButton);
      var isStreamingClass = querySafe(RITMO_SELECTORS.streamingIndicator);
      var isGenerating = !!stopButton || !!isStreamingClass;

      if (isGenerating) {
        sawGeneratingSignal = true;
        return false;
      }

      var currentText = findLatestAssistantText() || '';
      var effectiveLen = (currentText.length > 0) ? currentText.length : lastLength;
      var idleMs = Date.now() - lastChangeTimestamp;

      // Confirmed generating transition: stop button observed then disappeared (A-15, DET-33)
      if (sawGeneratingSignal && effectiveLen > 0 && idleMs >= 1200) {
        notifyFlutter('stream_completion_evaluated', {
          reason: 'stop_button_disappeared_and_silence_1200ms',
          idleMs: idleMs,
          textLength: effectiveLen,
          requestId: reqId,
          source: 'dom'
        });
        return true;
      }

      // Steady state when stop button and streaming indicator are absent (allow adequate pause for long multi-paragraph responses)
      if (effectiveLen > 0 && idleMs >= 3000) {
        notifyFlutter('watcher_steady_done', {
          textLength: effectiveLen,
          idleMs: idleMs,
          requestId: reqId,
          source: 'dom'
        });
        return true;
      }

      return false;
    }
  };

  // --- 5. Prompt Sender Implementation ---
  window.__ritmo_cancelGeneration = function() {
    var stopBtn = querySafe(RITMO_SELECTORS.stopButton);
    if (stopBtn) {
      stopBtn.click();
      console.log('[Ritmo] Stop generation button clicked.');
    }
    window.__ritmo_cleanup();
  };

  window.__ritmo_sendPrompt = function(promptText, reqId) {
    try {
      window.__ritmo_active_req_id = reqId || '';
      window.__ritmo_last_user_prompt = promptText ? promptText.trim() : '';

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

        try {
          notifyFlutter('selector_health', {
            report: runSelectorSelfTest(),
            bridgeVersion: requiredVersion,
            phase: 'pre_send',
            requestId: currentReqId,
            source: 'lifecycle'
          });
        } catch (stPreErr) {}

        window.__ritmo_active_req_id = currentReqId || '';
        window.__ritmo_turn_count_at_send = queryAllSafe(RITMO_SELECTORS.conversationTurns).length;

        // Anchor existing messages with complete set of elements (A-29)
        queryAllSafe(RITMO_ANCHORABLE).forEach(function(el) {
          el.setAttribute('data-ritmo-seen', 'true');
        });

        var latestAssistant = findLatestAssistantText() || '';
        var baseline = {
          text: latestAssistant,
          length: latestAssistant.length,
          turnCount: queryAllSafe(RITMO_SELECTORS.conversationTurns).length,
          assistantNodes: queryAllSafe(RITMO_SELECTORS.assistantMessage).length
        };
        window.__ritmo_turn_baseline = baseline.text;
        window.__ritmo_turn_baseline_obj = baseline;

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
          var pasted = false;
          try {
            document.execCommand('selectAll', false, null);
            var dt = new DataTransfer();
            dt.setData('text/plain', text);
            var pasteEvt = new ClipboardEvent('paste', {
              clipboardData: dt,
              bubbles: true,
              cancelable: true
            });
            pasted = editor.dispatchEvent(pasteEvt);
          } catch (clipErr) {
            console.warn('[Ritmo] Clipboard paste error:', clipErr);
          }

          var currentContent = (editor.innerText || editor.textContent || '').trim();
          if (!pasted || currentContent === '' || currentContent === 'Ask anything') {
            try {
              document.execCommand('selectAll', false, null);
              document.execCommand('delete', false, null);
              document.execCommand('insertText', false, text);
            } catch (cmdErr) {
              console.warn('[Ritmo] insertText error:', cmdErr);
            }
          }

          currentContent = (editor.innerText || editor.textContent || '').trim();
          if (currentContent === '' || currentContent === 'Ask anything') {
            try {
              while (editor.firstChild) editor.removeChild(editor.firstChild);
              var p = document.createElement('p');
              p.textContent = text;
              editor.appendChild(p);
            } catch (domErr) {
              console.warn('[Ritmo] DOM fallback error:', domErr);
            }
          }

          editor.dispatchEvent(new InputEvent('input', { bubbles: true, inputType: 'insertText', data: text }));
          editor.dispatchEvent(new Event('input', { bubbles: true }));
          editor.dispatchEvent(new Event('change', { bubbles: true }));
        }

        notifyFlutter('prompt_typed', { length: text.length, requestId: currentReqId, source: 'dom' });

        function isButtonEnabled(btn) {
          if (!btn) return false;
          if (btn.disabled) return false;
          if (btn.getAttribute('aria-disabled') === 'true') return false;
          if (btn.classList && btn.classList.contains('disabled')) return false;
          return true;
        }

        function verifySubmissionAndRetry(isEnter) {
          var verifyAttempts = 0;
          var verifyInterval = setInterval(function() {
            verifyAttempts++;
            var stopBtn = querySafe(RITMO_SELECTORS.stopButton);
            var isGenerating = !!stopBtn;
            var currentEditorText = (editor.value || editor.innerText || '').trim();
            var editorCleared = currentEditorText === '' || currentEditorText !== text.trim();

            if (isGenerating || editorCleared) {
              clearInterval(verifyInterval);
              return;
            }

            if (verifyAttempts >= 3) {
              clearInterval(verifyInterval);
              console.log('[Ritmo] Prompt submission unconfirmed after 1s, triggering send retry...');
              notifyFlutter('send_retry_triggered', { requestId: currentReqId, source: 'dom' });
              if (!isEnter) {
                var retryBtn = findSendButton();
                if (retryBtn && isButtonEnabled(retryBtn)) {
                  retryBtn.dispatchEvent(new PointerEvent('pointerdown', { bubbles: true }));
                  retryBtn.dispatchEvent(new MouseEvent('mousedown', { bubbles: true }));
                  retryBtn.dispatchEvent(new PointerEvent('pointerup', { bubbles: true }));
                  retryBtn.dispatchEvent(new MouseEvent('mouseup', { bubbles: true }));
                  retryBtn.click();
                  return;
                }
              }
              editor.focus();
              var enterRetry = new KeyboardEvent('keydown', {
                bubbles: true,
                cancelable: true,
                key: 'Enter',
                code: 'Enter',
                keyCode: 13,
                which: 13
              });
              editor.dispatchEvent(enterRetry);
            }
          }, 300);
        }

        var sendCheckAttempts = 0;
        var sendClicked = false;
        var sendInterval = setInterval(function() {
          sendCheckAttempts++;
          var sendBtn = findSendButton();

          if (sendBtn && isButtonEnabled(sendBtn)) {
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
            window.__ritmo_startStreamingWatcher(baseline, currentReqId);
            verifySubmissionAndRetry(false);
          } else if (sendCheckAttempts >= 30) {
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
              console.log('[Ritmo] Fallback Enter key dispatched (no active send button found after 30 attempts)');
              notifyFlutter('send_fallback_enter', { requestId: currentReqId, source: 'dom' });
              window.__ritmo_startStreamingWatcher(baseline, currentReqId);
              verifySubmissionAndRetry(true);
            }
          }
        }, RITMO_TIMEOUTS.fastPollMs);
      }

    } catch (e) {
      notifyFlutter('error', { message: 'خطا در ارسال پرامپت: ' + e.toString(), requestId: reqId, source: 'dom' });
    }
  };

  // --- 6. Resume After Navigation Implementation ---
  window.__ritmo_resume = function(payload) {
    try {
      payload = payload || {};
      var reqId = (payload && typeof payload.requestId === 'string') ? payload.requestId : '';
      if (!reqId && window.__ritmo_active_req_id) {
        reqId = window.__ritmo_active_req_id;
      }
      var promptPrefix = payload.promptPrefix || '';
      var stage = payload.stage || 'sending';
      var receivedLength = payload.receivedLength || 0;

      if (window.__ritmo_watcher_running && window.__ritmo_active_req_id === reqId && reqId) {
        console.log('[Ritmo] __ritmo_resume skipped: watcher already running for reqId ' + reqId);
        notifyFlutter('resume_skipped_duplicate', { requestId: reqId, source: 'dom' });
        return;
      }

      if (streamCheckTimer) {
        clearInterval(streamCheckTimer);
        streamCheckTimer = null;
      }
      stopDomObserver();

      window.__ritmo_active_req_id = reqId;

      console.log('[Ritmo] __ritmo_resume invoked for reqId: ' + reqId + ' (stage: ' + stage + ', received: ' + receivedLength + ')');

      var currentText = findLatestAssistantText();

      if (currentText && currentText.length > 0) {
        notifyFlutter('resumed', { stage: 'streaming', requestId: reqId, recoveredLength: currentText.length, source: 'dom' });
        notifyFlutter('chunk', { fullText: currentText, requestId: reqId, source: 'dom' });
      } else {
        notifyFlutter('resumed', { stage: 'streaming', requestId: reqId, recoveredLength: 0, source: 'dom' });
      }

      window.__ritmo_startStreamingWatcher(window.__ritmo_turn_baseline_obj || window.__ritmo_turn_baseline || '', reqId);
    } catch (e) {
      window.__ritmo_watcher_running = false;
      console.error('[Ritmo] Error in __ritmo_resume: ' + e);
      notifyFlutter('error', { message: 'خطا در بازیابی پاسخ پس از جابجایی صفحه: ' + e.toString(), requestId: reqId || (payload && payload.requestId), source: 'dom' });
    }
  };

  // --- 7. Cancellation Implementation ---
  window.__ritmo_cancelGeneration = function() {
    try {
      window.__ritmo_watcher_running = false;
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
      var pathname = window.location.pathname || '';
      var isExplicitLoginPage = pathname.indexOf('/auth/login') !== -1 || pathname.indexOf('/login') === 0;
      var hasLoginModal = !!querySafe('#login-modal, [data-testid="login-modal"]');
      var hasComposer = !!querySafe(RITMO_SELECTORS.composer);
      var hasLoginBtn = !!querySafe(RITMO_SELECTORS.loginButton);
      var hasUserProfile = !!querySafe(RITMO_SELECTORS.userProfile);
      var hasGuestBanner = !!querySafe('div[data-testid="guest-mode-banner"], div[data-testid*="guest" i]');
      var isGuestUrl = pathname.indexOf('/g/') !== -1;

      // Guest session: not explicitly blocked, composer present, but login button present / guest indicators
      if (hasComposer && !hasUserProfile && (hasLoginBtn || hasGuestBanner || isGuestUrl)) {
        notifyFlutter('guest_session_detected', {
          hasComposer: true,
          hasLoginButton: hasLoginBtn,
          currentPath: pathname,
          isGuest: true,
          source: 'lifecycle'
        });
        return true;
      }

      var isAuth = !isExplicitLoginPage && !hasLoginModal;

      if ((isExplicitLoginPage || hasLoginModal) && !hasComposer) {
        notifyFlutter('auth_required', {
          hasLoginButton: hasLoginBtn,
          currentPath: pathname,
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
  cfCheckTimer = setInterval(checkSecurityAndBlockStatus, RITMO_TIMEOUTS.cfCheckIntervalMs);

  // Self-test report at boot (A-28, DET-04)
  try {
    var selfTestReport = runSelectorSelfTest();
    notifyFlutter('selector_health', {
      report: selfTestReport,
      bridgeVersion: requiredVersion,
      phase: 'boot',
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
