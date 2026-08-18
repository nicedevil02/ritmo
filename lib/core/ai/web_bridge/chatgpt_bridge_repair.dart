/// Standalone repair/rescue layer for the ChatGPT Web Bridge.
///
/// چرا این فایل جدا است؟
/// اسکریپت اصلی (`ChatGptJsInjector.setupBridgeScript`) فقط زمانی واچر استریم را
/// روشن می‌کند که دکمهٔ ارسال با موفقیت کلیک شود، و تشخیص متن پاسخ را بر پایهٔ
/// «مقایسهٔ رشته‌ای با متن پایه» انجام می‌دهد. هر دو مورد شکننده‌اند:
///
/// - اگر استخراج‌کننده روی همان گرهٔ قدیمی قفل شود، `currentText` برابر
///   `previousBaselineText` می‌ماند، هیچ chunk ای منتشر نمی‌شود، `lastLength`
///   صفر می‌ماند و رأی‌گیری پایان استریم هرگز اجرا نمی‌شود. نتیجه: کاربر پاسخ را
///   داخل پنجرهٔ کرومیوم می‌بیند ولی صفحهٔ چت برنامه خالی می‌ماند تا تایم‌اوت.
/// - اگر کلیک ارسال از مسیر دیگری انجام شود (Enter، ارسال دستی کاربر داخل
///   همان پنجره، یا خطای میانی)، واچر اصلاً روشن نمی‌شود.
///
/// این لایه مستقل از مسیر ارسال کار می‌کند: یک `MutationObserver` در سطح داکیومنت
/// نصب می‌کند که به محض ظاهر شدن یک نوبت پاسخ تازه، واچر را خودش روشن می‌کند.
/// همچنین `__ritmo_pullLatestAnswer()` را اضافه می‌کند تا سمت دارت بتواند به‌جای
/// تایم‌اوت شدن، متنِ همین حالا قابل مشاهده را مستقیم بخواند.
class ChatGptBridgeRepair {
  const ChatGptBridgeRepair._();

  /// نسخهٔ لایهٔ ترمیم. با بالا بردن این عدد، نصب مجدد روی صفحات گرم اجباری می‌شود.
  static const int repairVersion = 2;

  /// اسکریپت نصب لایهٔ ترمیم. اجرای مکرر آن بی‌خطر و idempotent است.
  static String get installScript => '''
(function() {
  var REQUIRED = $repairVersion;
  if (window.__RITMO_REPAIR_V === REQUIRED) {
    return;
  }
  window.__RITMO_REPAIR_V = REQUIRED;
$_repairBody''';

  static const String _repairBody = r'''
  function post(type, payload) {
    try {
      var data = { type: type };
      if (payload && typeof payload === 'object') {
        for (var k in payload) {
          if (Object.prototype.hasOwnProperty.call(payload, k)) data[k] = payload[k];
        }
      }
      var json = JSON.stringify(data);
      if (window.RitmoChatBridge && typeof window.RitmoChatBridge.postMessage === 'function') {
        window.RitmoChatBridge.postMessage(json);
        window.__ritmo_last_post_ok = Date.now();
        return true;
      }
      window.__ritmo_dropped_events = (window.__ritmo_dropped_events || 0) + 1;
      console.error('[Ritmo/repair] RitmoChatBridge channel MISSING - dropped event: ' + type);
      return false;
    } catch (e) {
      window.__ritmo_last_error = e.toString();
      console.error('[Ritmo/repair] post failed:', e);
      return false;
    }
  }

  function qAll(sel) {
    try {
      var r = document.querySelectorAll(sel);
      return r ? Array.prototype.slice.call(r) : [];
    } catch (e) {
      return [];
    }
  }

  function qOne(sel) {
    try {
      return document.querySelector(sel);
    } catch (e) {
      return null;
    }
  }

  // یک فهرست واحد برای هر دو کار: علامت‌گذاری «دیده‌شده» و پیدا کردن نوبت تازه.
  // ناهماهنگی میان این دو، ریشهٔ اصلی باگ «پاسخ تشخیص داده نمی‌شود» بود.
  var TRACKED = [
    '[data-message-author-role]',
    '[data-testid*="conversation-turn"]',
    '[data-testid*="assistant"]',
    'article',
    'div.agent-turn',
    '[class*="agent-turn"]',
    'div.markdown',
    'div.prose',
    '[class*="markdown"]',
    '[class*="prose"]'
  ].join(', ');

  var STOP_BTN = 'button[data-testid="stop-button"], button[data-testid="fruitjuice-stop-button"], button[aria-label*="Stop" i], button[aria-label*="توقف"], button[data-testid*="stop" i], button.stop-button';
  var SEND_BTN = 'button[data-testid="send-button"], button[data-testid="fruitjuice-send-button"], button[aria-label="Send prompt"], button[aria-label="ارسال پیام"], form button[type="submit"]';
  var STREAMING = '.result-streaming, .streaming, [data-is-streaming="true"]';
  var USER_MSG = '[data-message-author-role="user"], [data-testid*="user"], div.font-user-message';
  var SEEN = 'data-ritmo-seen';

  function isUserNode(el) {
    if (!el) return true;
    try {
      if (el.getAttribute && el.getAttribute('data-message-author-role') === 'user') return true;
      var tid = (el.getAttribute && el.getAttribute('data-testid')) || '';
      if (tid.indexOf('user') !== -1) return true;
      if (el.closest && el.closest(USER_MSG)) return true;
      if (el.querySelector && el.querySelector('[data-message-author-role="user"]')) return true;
    } catch (e) {}
    return false;
  }

  function cleanText(el) {
    if (!el) return '';
    var target = null;
    try {
      target = el.querySelector('.markdown, .prose, [class*="markdown"], [class*="prose"], [data-conversation-part="body"], [data-assistant-writing-block-body], div.whitespace-pre-wrap');
    } catch (e) {}
    target = target || el;
    var txt = (target.innerText || target.textContent || '').trim();
    if (!txt && el !== target) txt = (el.innerText || el.textContent || '').trim();
    if (!txt) return '';
    txt = txt.replace(/^[•\-\*\s:]*(ChatGPT\s*said:?|:ChatGPT\s*said:?|ChatGPT:?|You\s*said:?|:You\s*said:?|Assistant\s*said:?)[\s:]*/gmi, '');
    txt = txt.replace(/^[•\-\*\s:]+/g, '');
    if (txt.indexOf('[data-conversation-') !== -1 || txt.indexOf('--component-') !== -1) {
      txt = txt.replace(/\[data-[^\]]+\]\s*\{[^}]*\}/g, '');
      txt = txt.replace(/--[a-zA-Z0-9_-]+:[^;]+;?/g, '');
    }
    return txt.trim();
  }

  // همهٔ گره‌های موجود را «دیده‌شده» علامت می‌زند. دقیقا همان فهرستی که بعدا
  // برای پیدا کردن نوبت تازه استفاده می‌شود.
  window.__ritmo_anchorSeen = function() {
    var n = 0;
    qAll(TRACKED).forEach(function(el) {
      try {
        el.setAttribute(SEEN, 'true');
        n++;
      } catch (e) {}
    });
    return n;
  };

  // تازه‌ترین گرهِ پاسخ که بعد از لنگرگذاری ظاهر شده است.
  // بر پایهٔ هویت گره کار می‌کند، نه مقایسهٔ رشته‌ای با متن پایه.
  window.__ritmo_findFreshNode = function() {
    var nodes = qAll(TRACKED);
    var best = null;
    var bestLen = 0;
    for (var i = nodes.length - 1; i >= 0; i--) {
      var el = nodes[i];
      try {
        if (el.getAttribute(SEEN) === 'true') continue;
      } catch (e) {
        continue;
      }
      if (isUserNode(el)) continue;
      var t = cleanText(el);
      if (t && t.length > bestLen) {
        best = el;
        bestLen = t.length;
      }
    }
    return best;
  };

  // متن پاسخ همین لحظه، بدون هیچ وابستگی به واچر. مسیر نجات سمت دارت.
  window.__ritmo_pullLatestAnswer = function() {
    var out = {
      text: '',
      isGenerating: !!qOne(STOP_BTN) || !!qOne(STREAMING),
      hasChannel: !!(window.RitmoChatBridge && typeof window.RitmoChatBridge.postMessage === 'function'),
      droppedEvents: window.__ritmo_dropped_events || 0,
      watcherActive: !!window.__ritmo_repair_timer,
      bridgeVersion: window.__RITMO_BRIDGE_V || 0,
      repairVersion: window.__RITMO_REPAIR_V || 0,
      activeReqId: window.__ritmo_active_req_id || ''
    };
    try {
      var fresh = window.__ritmo_findFreshNode();
      if (fresh) out.text = cleanText(fresh);
      if (!out.text) {
        var all = qAll('[data-message-author-role="assistant"], [data-testid*="assistant"], div.agent-turn, [class*="agent-turn"]');
        for (var i = all.length - 1; i >= 0; i--) {
          if (isUserNode(all[i])) continue;
          var t = cleanText(all[i]);
          if (t) {
            out.text = t;
            out.fromFallback = true;
            break;
          }
        }
      }
    } catch (e) {
      out.error = e.toString();
    }
    return out;
  };

  window.__ritmo_getDiagnostics = function() {
    var d = window.__ritmo_pullLatestAnswer();
    d.textLength = (d.text || '').length;
    delete d.text;
    d.lastPostOk = window.__ritmo_last_post_ok || 0;
    d.lastError = window.__ritmo_last_error || '';
    d.hasComposer = !!qOne('#prompt-textarea, textarea, div[contenteditable="true"], .ProseMirror');
    d.hasSendButton = !!qOne(SEND_BTN);
    d.path = window.location.pathname || '';
    return d;
  };

  // ---- واچر مقاوم ----
  // تفاوت کلیدی با واچر اصلی: هیچ‌جا با یک «رشتهٔ پایه» مقایسه نمی‌کند.
  // مرجع، خودِ گره تازه است؛ پس قفل شدن روی متن قبلی ممکن نیست.
  window.__ritmo_repair_timer = null;
  window.__ritmo_repair_observer = null;
  var repairReqId = null;
  var emitted = '';
  var lastChange = 0;
  var startedAt = 0;
  var sawText = false;

  function stopRepairWatcher() {
    if (window.__ritmo_repair_timer) {
      clearInterval(window.__ritmo_repair_timer);
      window.__ritmo_repair_timer = null;
    }
    if (window.__ritmo_repair_observer) {
      try {
        window.__ritmo_repair_observer.disconnect();
      } catch (e) {}
      window.__ritmo_repair_observer = null;
    }
  }
  window.__ritmo_stopRepairWatcher = stopRepairWatcher;

  function tick() {
    var node = window.__ritmo_findFreshNode();
    var text = node ? cleanText(node) : '';

    if (text && text !== emitted) {
      if (!sawText) {
        sawText = true;
        post('first_token', {
          length: text.length,
          requestId: repairReqId,
          latencyMs: Date.now() - startedAt,
          source: 'dom_repair'
        });
      }
      var delta = (text.length > emitted.length && text.indexOf(emitted) === 0)
        ? text.substring(emitted.length)
        : text;
      emitted = text;
      lastChange = Date.now();
      post('chunk', { delta: delta, fullText: text, requestId: repairReqId, source: 'dom_repair' });
    }

    var generating = !!qOne(STOP_BTN) || !!qOne(STREAMING);
    var sendBtn = qOne(SEND_BTN);
    var sendBack = !!sendBtn && !sendBtn.disabled;
    var idle = Date.now() - lastChange;
    var total = Date.now() - startedAt;

    if (!generating && emitted.length > 0 && ((sendBack && idle > 500) || idle > 2500)) {
      stopRepairWatcher();
      post('done', { fullText: emitted, requestId: repairReqId, source: 'dom_repair' });
      return;
    }

    // مسیر نجات: پاسخ روی صفحه هست ولی هرگز منتشر نشده. واچر اصلی اینجا گیر می‌کرد.
    if (!generating && emitted.length === 0 && sendBack && total > 6000) {
      var rescue = window.__ritmo_pullLatestAnswer();
      if (rescue && rescue.text) {
        emitted = rescue.text;
        stopRepairWatcher();
        post('chunk', { delta: rescue.text, fullText: rescue.text, requestId: repairReqId, source: 'dom_rescue' });
        post('done', { fullText: rescue.text, requestId: repairReqId, source: 'dom_rescue' });
        return;
      }
    }

    if (total > 88000) {
      stopRepairWatcher();
      if (emitted.length > 0) {
        post('done', { fullText: emitted, requestId: repairReqId, source: 'dom_repair' });
      } else {
        var last = window.__ritmo_pullLatestAnswer();
        if (last && last.text) {
          post('chunk', { delta: last.text, fullText: last.text, requestId: repairReqId, source: 'dom_rescue' });
          post('done', { fullText: last.text, requestId: repairReqId, source: 'dom_rescue' });
        } else {
          post('error', { message: 'زمان انتظار برای پاسخ به پایان رسید.', requestId: repairReqId, source: 'dom_repair' });
        }
      }
    }
  }

  // idempotent: فراخوانی دوباره برای همان requestId واچر را دوباره صفر نمی‌کند.
  window.__ritmo_startRepairWatcher = function(reqId) {
    reqId = reqId || window.__ritmo_active_req_id || '';
    if (window.__ritmo_repair_timer && repairReqId === reqId) return false;
    stopRepairWatcher();
    repairReqId = reqId;
    emitted = '';
    sawText = false;
    startedAt = Date.now();
    lastChange = Date.now();

    if (typeof MutationObserver !== 'undefined' && document.body) {
      try {
        window.__ritmo_repair_observer = new MutationObserver(function() { tick(); });
        window.__ritmo_repair_observer.observe(document.body, {
          childList: true,
          subtree: true,
          characterData: true
        });
      } catch (e) {}
    }
    window.__ritmo_repair_timer = setInterval(tick, 300);
    console.log('[Ritmo/repair] watcher started for reqId=' + reqId);
    return true;
  };

  // ناظر همیشه‌روشن: اگر نوبت پاسخ تازه‌ای ظاهر شود ولی واچر خاموش باشد
  // (مثلا چون کلیک ارسال از مسیر دیگری انجام شده)، خودش واچر را روشن می‌کند.
  function installAutoStart() {
    if (window.__ritmo_autostart_observer || typeof MutationObserver === 'undefined' || !document.body) return;
    try {
      window.__ritmo_autostart_observer = new MutationObserver(function() {
        if (window.__ritmo_repair_timer) return;
        if (!window.__ritmo_active_req_id) return;
        var fresh = window.__ritmo_findFreshNode();
        if (fresh && cleanText(fresh)) {
          console.log('[Ritmo/repair] fresh assistant turn detected - auto-starting watcher.');
          window.__ritmo_startRepairWatcher(window.__ritmo_active_req_id);
        }
      });
      window.__ritmo_autostart_observer.observe(document.body, { childList: true, subtree: true });
      console.log('[Ritmo/repair] auto-start observer installed.');
    } catch (e) {
      console.warn('[Ritmo/repair] auto-start observer failed:', e);
    }
  }

  if (document.body) {
    installAutoStart();
  } else {
    document.addEventListener('DOMContentLoaded', installAutoStart);
  }

  console.log('[Ritmo/repair] repair layer v' + REQUIRED + ' installed.');
})();
''';

  /// اسکریپت لنگرگذاری پیش از ارسال پرامپت.
  static const String anchorScript = '''
(function() {
  if (typeof window.__ritmo_anchorSeen === 'function') {
    var n = window.__ritmo_anchorSeen();
    console.log('[Ritmo/repair] anchored ' + n + ' existing nodes.');
  }
})();
''';

  /// روشن کردن واچر ترمیم برای یک درخواست مشخص.
  static String startWatcherScript(String requestId) {
    final safe = requestId.replaceAll(RegExp(r'[^A-Za-z0-9_\-]'), '');
    return '''
(function() {
  if (typeof window.__ritmo_startRepairWatcher === 'function') {
    window.__ritmo_active_req_id = '$safe';
    window.__ritmo_startRepairWatcher('$safe');
  }
})();
''';
  }

  /// خواندن مستقیم پاسخ قابل مشاهده (مسیر نجات سمت دارت).
  static const String pullAnswerScript =
      "window.__ritmo_pullLatestAnswer ? JSON.stringify(window.__ritmo_pullLatestAnswer()) : '{}'";

  /// خواندن وضعیت تشخیصی پل.
  static const String diagnosticsScript =
      "window.__ritmo_getDiagnostics ? JSON.stringify(window.__ritmo_getDiagnostics()) : '{}'";

  /// خاموش کردن واچر ترمیم.
  static const String stopWatcherScript = '''
if (typeof window.__ritmo_stopRepairWatcher === 'function') {
  window.__ritmo_stopRepairWatcher();
}
''';
}
