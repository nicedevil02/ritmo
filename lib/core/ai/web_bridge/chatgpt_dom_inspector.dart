import 'dart:convert';
import 'package:ritmo/core/ai/web_bridge/bridge_trace_log.dart';
import 'package:ritmo/core/logging/ritmo_logger.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Comprehensive DOM & HTML Inspector for ChatGPT Web Bridge.
/// Captures page structure, localized Persian texts, error banners,
/// active elements, and the full HTML document for debugging.
class ChatGptDomInspector {
  ChatGptDomInspector._();

  static const String _inspectionScript = r'''
(function() {
  try {
    var result = {
      url: window.location.href || '',
      title: document.title || '',
      readyState: document.readyState || '',
      userAgent: navigator.userAgent || '',
      language: navigator.language || '',
      languages: navigator.languages || [],
      isRtl: document.documentElement.dir === 'rtl' || document.body.dir === 'rtl',
      textareas: [],
      inputs: [],
      buttons: [],
      alerts: [],
      persianSnippets: [],
      hasCloudflareIframe: false,
      visibleBodyTextSample: ''
    };

    // 1. Textareas & Contenteditables
    var textareas = document.querySelectorAll('textarea, div[contenteditable="true"], [role="textbox"]');
    for (var i = 0; i < textareas.length; i++) {
      var el = textareas[i];
      result.textareas.push({
        tag: el.tagName.toLowerCase(),
        id: el.id || '',
        name: el.name || '',
        placeholder: el.placeholder || el.getAttribute('placeholder') || el.getAttribute('data-placeholder') || '',
        ariaLabel: el.getAttribute('aria-label') || '',
        dataTestId: el.getAttribute('data-testid') || '',
        disabled: el.disabled === true || el.getAttribute('aria-disabled') === 'true',
        readOnly: el.readOnly === true,
        valueLength: (el.value || el.innerText || '').length,
        rect: {
          width: Math.round(el.offsetWidth || 0),
          height: Math.round(el.offsetHeight || 0),
          visible: (el.offsetWidth > 0 && el.offsetHeight > 0)
        }
      });
    }

    // 2. Form Inputs
    var inputs = document.querySelectorAll('input:not([type="hidden"])');
    for (var i = 0; i < inputs.length; i++) {
      var inp = inputs[i];
      result.inputs.push({
        type: inp.type || 'text',
        id: inp.id || '',
        name: inp.name || '',
        placeholder: inp.placeholder || '',
        ariaLabel: inp.getAttribute('aria-label') || '',
        dataTestId: inp.getAttribute('data-testid') || '',
        disabled: inp.disabled === true
      });
    }

    // 3. Relevant Buttons
    var buttons = document.querySelectorAll('button, [role="button"], a[role="button"]');
    for (var i = 0; i < Math.min(buttons.length, 30); i++) {
      var btn = buttons[i];
      var text = (btn.innerText || btn.textContent || '').trim();
      var aria = btn.getAttribute('aria-label') || '';
      var testId = btn.getAttribute('data-testid') || '';
      if (text || aria || testId) {
        result.buttons.push({
          text: text.substring(0, 60),
          ariaLabel: aria,
          dataTestId: testId,
          disabled: btn.disabled === true || btn.getAttribute('aria-disabled') === 'true',
          classes: (btn.className || '').toString().substring(0, 80)
        });
      }
    }

    // 4. Alerts, Error Banners, and Restrictions
    var alertNodes = document.querySelectorAll('[role="alert"], .error, .alert, .banner, .text-red-500, [data-testid*="error"]');
    for (var i = 0; i < alertNodes.length; i++) {
      var alertEl = alertNodes[i];
      var alertText = (alertEl.innerText || alertEl.textContent || '').trim();
      if (alertText.length > 0) {
        result.alerts.push(alertText.substring(0, 200));
      }
    }

    // 5. Detect Persian / Arabic Characters in Headings and Paragraphs
    var textElements = document.querySelectorAll('h1, h2, h3, h4, p, span, div');
    var persianRegex = /[\u0600-\u06FF\u0750-\u077F\uFB50-\uFDFF\uFE70-\uFEFF]/;
    var seenSnippets = {};
    for (var i = 0; i < textElements.length; i++) {
      var tEl = textElements[i];
      if (tEl.children.length === 0) {
        var str = (tEl.innerText || tEl.textContent || '').trim();
        if (str.length > 3 && persianRegex.test(str) && !seenSnippets[str]) {
          seenSnippets[str] = true;
          result.persianSnippets.push(str.substring(0, 150));
          if (result.persianSnippets.length >= 15) break;
        }
      }
    }

    // 6. Cloudflare detection
    var iframes = document.querySelectorAll('iframe');
    for (var i = 0; i < iframes.length; i++) {
      var src = iframes[i].src || '';
      if (src.indexOf('cloudflare') !== -1 || src.indexOf('challenges') !== -1 || src.indexOf('turnstile') !== -1) {
        result.hasCloudflareIframe = true;
        break;
      }
    }

    // 7. Visible Body Text Sample (first 1000 chars)
    if (document.body) {
      result.visibleBodyTextSample = (document.body.innerText || '').trim().substring(0, 1000);
    }

    return JSON.stringify(result);
  } catch (err) {
    return JSON.stringify({ error: err.toString() });
  }
})();
''';

  /// Captures a structured diagnostic report with full HTML from the given [controller].
  static Future<String> captureSnapshot(
    WebViewController? controller, {
    String? currentStatus,
    String? lastError,
    bool includeFullHtml = true,
  }) async {
    final buffer = StringBuffer();
    final now = DateTime.now().toIso8601String();

    buffer.writeln('========================================');
    buffer.writeln('🔍 RITMO CHATGPT WEB BRIDGE DIAGNOSTIC REPORT');
    buffer.writeln('Timestamp: $now');
    buffer.writeln('Bridge Status: ${currentStatus ?? "Unknown"}');
    if (lastError != null) {
      buffer.writeln('Last Recorded Error: $lastError');
    }
    buffer.writeln('========================================\n');

    if (controller == null) {
      buffer.writeln('⚠️ WebViewController is null (WebView is not initialized or mounted).');
      _appendTraceLog(buffer);
      return buffer.toString();
    }

    try {
      // 1. Evaluate DOM Structure & Elements
      final rawDomJson = await controller.runJavaScriptReturningResult(_inspectionScript).timeout(
        const Duration(seconds: 4),
        onTimeout: () => '{"error": "DOM evaluation timed out after 4s"}',
      );

      Map<String, dynamic> domData = {};
      try {
        final parsed = rawDomJson is String ? jsonDecode(rawDomJson) : rawDomJson;
        if (parsed is String) {
          domData = jsonDecode(parsed) as Map<String, dynamic>;
        } else if (parsed is Map) {
          domData = Map<String, dynamic>.from(parsed);
        }
      } catch (parseErr) {
        domData = {'raw': rawDomJson.toString(), 'parseError': parseErr.toString()};
      }

      buffer.writeln('📌 PAGE OVERVIEW:');
      buffer.writeln('- URL: ${domData['url'] ?? '—'}');
      buffer.writeln('- Title: ${domData['title'] ?? '—'}');
      buffer.writeln('- Ready State: ${domData['readyState'] ?? '—'}');
      buffer.writeln('- User Agent: ${domData['userAgent'] ?? '—'}');
      buffer.writeln('- Language: ${domData['language'] ?? '—'} (All: ${domData['languages']})');
      buffer.writeln('- Is RTL Layout: ${domData['isRtl'] ?? false}');
      buffer.writeln('- Cloudflare IFrame: ${domData['hasCloudflareIframe'] ?? false}\n');

      buffer.writeln('📝 INPUTS & TEXTAREAS (${(domData['textareas'] as List?)?.length ?? 0}):');
      final textareas = domData['textareas'] as List? ?? [];
      for (var i = 0; i < textareas.length; i++) {
        final ta = textareas[i];
        buffer.writeln('  [$i] <${ta['tag']}> id="${ta['id']}" placeholder="${ta['placeholder']}" aria-label="${ta['ariaLabel']}" testid="${ta['dataTestId']}" disabled=${ta['disabled']} visible=${ta['rect']?['visible']} (${ta['rect']?['width']}x${ta['rect']?['height']})');
      }
      buffer.writeln();

      buffer.writeln('🔘 DETECTED BUTTONS (${(domData['buttons'] as List?)?.length ?? 0}):');
      final buttons = domData['buttons'] as List? ?? [];
      for (var i = 0; i < buttons.length; i++) {
        final b = buttons[i];
        buffer.writeln('  [$i] text="${b['text']}" aria-label="${b['ariaLabel']}" testid="${b['dataTestId']}" disabled=${b['disabled']}');
      }
      buffer.writeln();

      buffer.writeln('⚠️ DETECTED ALERTS & RESTRICTIONS (${(domData['alerts'] as List?)?.length ?? 0}):');
      final alerts = domData['alerts'] as List? ?? [];
      for (final alert in alerts) {
        buffer.writeln('  - $alert');
      }
      buffer.writeln();

      buffer.writeln('🇮🇷 DETECTED PERSIAN / LOCALIZED TEXTS (${(domData['persianSnippets'] as List?)?.length ?? 0}):');
      final persian = domData['persianSnippets'] as List? ?? [];
      for (final snippet in persian) {
        buffer.writeln('  - "$snippet"');
      }
      buffer.writeln();

      buffer.writeln('📄 VISIBLE BODY TEXT SAMPLE:');
      buffer.writeln(domData['visibleBodyTextSample'] ?? '—');
      buffer.writeln();

      // 2. Fetch Full HTML Document
      if (includeFullHtml) {
        buffer.writeln('========================================');
        buffer.writeln('🌐 COMPLETE PAGE HTML SOURCE (outerHTML)');
        buffer.writeln('========================================');
        try {
          final rawHtml = await controller.runJavaScriptReturningResult('document.documentElement.outerHTML').timeout(
            const Duration(seconds: 4),
            onTimeout: () => '<!-- HTML extraction timed out -->',
          );
          var htmlStr = rawHtml.toString();
          if (htmlStr.startsWith('"') && htmlStr.endsWith('"')) {
            try {
              htmlStr = jsonDecode(htmlStr) as String;
            } catch (_) {}
          }
          buffer.writeln(htmlStr);
        } catch (htmlErr) {
          buffer.writeln('<!-- Error fetching outerHTML: $htmlErr -->');
        }
        buffer.writeln('\n========================================\n');
      }
    } catch (e, st) {
      RitmoLog.error('ChatGptDomInspector', 'Error during DOM snapshot: $e', e, st);
      buffer.writeln('❌ Error executing DOM snapshot: $e');
    }

    _appendTraceLog(buffer);
    return buffer.toString();
  }

  static void _appendTraceLog(StringBuffer buffer) {
    buffer.writeln('📜 RECENT BRIDGE TRACE LOGS:');
    try {
      buffer.writeln(BridgeTraceLog.instance.exportAsText());
    } catch (_) {
      buffer.writeln('No trace log available.');
    }
  }
}
