import 'dart:convert';

import 'package:ritmo/core/ai/agent/agent_tool.dart';

/// حاصل پویش متن مدل برای یافتن فراخوانی ابزار
class AgentToolCallScan {
  /// فراخوانی‌های کامل و یکتا (تکراری‌های عیناً مشابه حذف شده‌اند)
  final List<AgentToolCall> calls;

  /// متن قابل نمایش به کاربر (بدون تگ ابزار/اکشن/حافظه)
  final String cleanText;

  /// تگ <tool_call> باز شده ولی هنوز بسته نشده (استریم در حال نوشتن است)
  final bool hasOpenTag;

  /// تعداد کاراکترهایی که مدل پس از آخرین </tool_call> نوشته است.
  /// حلقه با این عدد استریم را زود قطع می‌کند تا مدل پس از فراخوانی ابزار
  /// شروع به ساختن پاسخ خیالی نکند.
  final int tailLength;

  /// خطاهای پارس برای لاگ تشخیصی و بازخورد به مدل
  final List<String> parseErrors;

  const AgentToolCallScan({
    required this.calls,
    required this.cleanText,
    required this.hasOpenTag,
    required this.tailLength,
    required this.parseErrors,
  });

  bool get hasCalls => calls.isNotEmpty;

  static const AgentToolCallScan empty = AgentToolCallScan(
    calls: [],
    cleanText: '',
    hasOpenTag: false,
    tailLength: 0,
    parseErrors: [],
  );
}

/// استخراج امن فراخوانی ابزار از متن (احتمالاً نیمه‌کارهٔ) مدل
///
/// متن به‌صورت استریم می‌رسد؛ در لحظه‌ای که تگ باز شده ولی بسته نشده، نه باید
/// به کاربر نشان داده شود و نه باید اجرا شود. مدل‌های مختلف هم JSON را در
/// قالب‌های متفاوت (بلوک کد، آرایه، arguments رشته‌ای، function) می‌فرستند و همه
/// باید بدون شکست تحمل شوند.
class AgentToolCallParser {
  const AgentToolCallParser._();

  static final RegExp _blockRe = RegExp(r'<tool_call>([\s\S]*?)<\/tool_call>');
  static final RegExp _danglingToolRe = RegExp(r'<tool_call>[\s\S]*$');
  static final RegExp _actionsRe = RegExp(r'<actions>[\s\S]*?<\/actions>', caseSensitive: false);
  static final RegExp _memOpsRe = RegExp(r'<memory_ops>[\s\S]*?<\/memory_ops>', caseSensitive: false);
  static final RegExp _danglingTagRe =
      RegExp(r'<(actions|memory_ops|memory|tool_call)[^>]*>[\s\S]*$', caseSensitive: false);
  static final RegExp _partialTagRe =
      RegExp(r'<\/?(action|tool|memory|actions|tool_call|memory_ops)[^>]*$', caseSensitive: false);
  static final RegExp _fenceOpenRe = RegExp(r'^\s*```[a-zA-Z0-9_-]*\s*');
  static final RegExp _fenceCloseRe = RegExp(r'\s*```\s*$');

  static const String _openTag = '<tool_call>';
  static const String _closeTag = '</tool_call>';

  /// پویش کامل متن خام یک نوبت
  static AgentToolCallScan scan(String raw) {
    if (raw.isEmpty) return AgentToolCallScan.empty;

    final calls = <AgentToolCall>[];
    final errors = <String>[];
    final seen = <String>{};

    for (final match in _blockRe.allMatches(raw)) {
      for (final call in _decodeCalls(match.group(1) ?? '', errors)) {
        final signature = '${call.toolName}|${stableArgs(call.parameters)}';
        if (seen.add(signature)) {
          calls.add(call);
        }
      }
    }

    final lastClose = raw.lastIndexOf(_closeTag);
    final tail =
        lastClose >= 0 ? raw.substring(lastClose + _closeTag.length).trim() : '';

    final lastOpen = raw.lastIndexOf(_openTag);
    final hasOpenTag = lastOpen >= 0 && lastOpen > lastClose;

    // حالت لبه: مدل بدون تگ، تنها یک JSON با کلید tool فرستاده است
    if (calls.isEmpty && !hasOpenTag) {
      final bare = _decodeBareJsonCall(raw);
      if (bare != null) {
        return AgentToolCallScan(
          calls: <AgentToolCall>[bare],
          cleanText: '',
          hasOpenTag: false,
          tailLength: 0,
          parseErrors: errors,
        );
      }
    }

    return AgentToolCallScan(
      calls: calls,
      cleanText: cleanForDisplay(raw),
      hasOpenTag: hasOpenTag,
      tailLength: tail.length,
      parseErrors: errors,
    );
  }

  /// حذف بلوک‌های ابزار (کامل و نیمه‌کاره) با حفظ تگ‌های actions و memory_ops.
  /// خروجی همین تابع به ChatActionParser داده می‌شود؛ اگر tool_call حذف نشود،
  /// JSON خام در پیام ذخیره‌شدهٔ چت برای کاربر ظاهر می‌شود.
  static String stripToolCalls(String raw) {
    var text = raw.replaceAll(_blockRe, '');
    text = text.replaceAll(_danglingToolRe, '');
    return text;
  }

  static final RegExp _noisePrefixRe = RegExp(
    r'^[•\-\*\s:]*(ChatGPT\s*said:?|:ChatGPT\s*said:?|ChatGPT:?|You\s*said:?|:You\s*said:?|Assistant\s*said:?)[\s:]*',
    caseSensitive: false,
    multiLine: true,
  );

  /// متن نهایی قابل نمایش به کاربر
  static String cleanForDisplay(String raw) {
    var text = stripToolCalls(raw);
    text = text.replaceAll(_actionsRe, '');
    text = text.replaceAll(_memOpsRe, '');
    text = text.replaceAll(_danglingTagRe, '');
    text = text.replaceAll(_partialTagRe, '');
    while (true) {
      final before = text;
      text = text.replaceFirst(_noisePrefixRe, '').trimLeft();
      text = text.replaceFirst(RegExp(r'^[•\-\*:\s]+'), '').trimLeft();
      if (text == before) break;
    }
    return text.trim();
  }

  /// امضای پایدار پارامترها (کلیدهای مرتب) برای تشخیص فراخوانی تکراری
  static String stableArgs(Map<String, dynamic> args) {
    final keys = args.keys.toList()..sort();
    final ordered = <String, dynamic>{};
    for (final key in keys) {
      ordered[key] = args[key];
    }
    try {
      return jsonEncode(ordered);
    } catch (_) {
      return ordered.toString();
    }
  }

  static List<AgentToolCall> _decodeCalls(String body, List<String> errors) {
    final out = <AgentToolCall>[];
    var text = body.trim();
    if (text.isEmpty) return out;

    text = text
        .replaceFirst(_fenceOpenRe, '')
        .replaceFirst(_fenceCloseRe, '')
        .trim();
    if (text.isEmpty) return out;

    dynamic decoded;
    try {
      decoded = jsonDecode(text);
    } catch (_) {
      final extracted = _extractFirstJsonObject(text);
      if (extracted == null) {
        errors.add('بدنهٔ tool_call قابل پارس نبود: ${_short(text)}');
        return out;
      }
      try {
        decoded = jsonDecode(extracted);
      } catch (_) {
        errors.add('JSON نامعتبر در tool_call: ${_short(text)}');
        return out;
      }
    }

    if (decoded is List) {
      for (final item in decoded) {
        if (item is Map) {
          out.addAll(_fromMap(item.cast<String, dynamic>(), errors));
        }
      }
    } else if (decoded is Map) {
      out.addAll(_fromMap(decoded.cast<String, dynamic>(), errors));
    } else {
      errors.add('ساختار tool_call نه شیء بود و نه آرایه.');
    }
    return out;
  }

  static List<AgentToolCall> _fromMap(
    Map<String, dynamic> map,
    List<String> errors,
  ) {
    // قالب {"tool_calls": [...]} یا {"calls": [...]}
    final nested = map['tool_calls'] ?? map['calls'];
    if (nested is List) {
      final out = <AgentToolCall>[];
      for (final item in nested) {
        if (item is Map) {
          out.addAll(_fromMap(item.cast<String, dynamic>(), errors));
        }
      }
      return out;
    }

    final normalized = Map<String, dynamic>.from(map);

    // پارامترهایی که به شکل رشتهٔ JSON فرستاده شده‌اند
    for (final key in const ['parameters', 'args', 'arguments']) {
      final value = normalized[key];
      if (value is String && value.trim().startsWith('{')) {
        try {
          final inner = jsonDecode(value);
          if (inner is Map) {
            normalized[key] = inner.cast<String, dynamic>();
          }
        } catch (_) {
          errors.add('پارامترهای ابزار به شکل رشته بودند و پارس نشدند.');
        }
      }
    }

    // قالب فراخوانی بومی: {"function": {"name": ..., "arguments": ...}}
    final fn = normalized['function'];
    if (fn is Map) {
      final fnMap = fn.cast<String, dynamic>();
      normalized['name'] ??= fnMap['name'];
      dynamic fnArgs = fnMap['arguments'] ?? fnMap['parameters'];
      if (fnArgs is String && fnArgs.trim().startsWith('{')) {
        try {
          fnArgs = jsonDecode(fnArgs);
        } catch (_) {
          fnArgs = null;
        }
      }
      if (fnArgs is Map) {
        normalized['parameters'] ??= fnArgs.cast<String, dynamic>();
      }
    }

    if (normalized['parameters'] == null && normalized['arguments'] is Map) {
      normalized['parameters'] =
          (normalized['arguments'] as Map).cast<String, dynamic>();
    }

    final call = AgentToolCall.fromJson(normalized);
    if (call.toolName.trim().isEmpty) {
      errors.add('نام ابزار در tool_call خالی بود.');
      return const <AgentToolCall>[];
    }
    return <AgentToolCall>[call];
  }

  /// کاوش اولین شیء JSON کامل با تطبیق آکولاد (مقاوم به متن اضافی اطراف JSON)
  static String? _extractFirstJsonObject(String text) {
    final start = text.indexOf('{');
    if (start < 0) return null;

    var depth = 0;
    var inString = false;
    var escaped = false;

    for (var i = start; i < text.length; i++) {
      final ch = text[i];
      if (inString) {
        if (escaped) {
          escaped = false;
          continue;
        }
        if (ch == '\\') {
          escaped = true;
          continue;
        }
        if (ch == '"') inString = false;
        continue;
      }
      if (ch == '"') {
        inString = true;
        continue;
      }
      if (ch == '{') depth++;
      if (ch == '}') {
        depth--;
        if (depth == 0) return text.substring(start, i + 1);
      }
    }
    return null;
  }

  /// تشخیص حالتی که کل پاسخ فقط یک JSON فراخوانی ابزار بدون تگ است
  static AgentToolCall? _decodeBareJsonCall(String raw) {
    var text = raw.trim();
    text = text
        .replaceFirst(_fenceOpenRe, '')
        .replaceFirst(_fenceCloseRe, '')
        .trim();
    if (!text.startsWith('{') || !text.endsWith('}')) return null;

    final looksLikeCall = text.contains('"tool"') ||
        (text.contains('"name"') &&
            (text.contains('"parameters"') ||
                text.contains('"arguments"') ||
                text.contains('"args"')));
    if (!looksLikeCall) return null;

    try {
      final decoded = jsonDecode(text);
      if (decoded is Map) {
        final calls = _fromMap(decoded.cast<String, dynamic>(), <String>[]);
        if (calls.length == 1) return calls.first;
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  static String _short(String text) =>
      text.length <= 120 ? text : '${text.substring(0, 120)}…';
}
