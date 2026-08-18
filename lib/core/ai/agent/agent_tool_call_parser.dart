import 'dart:convert';
import 'package:ritmo/core/logging/ritmo_logger.dart';

import 'package:ritmo/core/ai/agent/agent_tool.dart';

/// حاصل پویش متن مدل برای یافتن فراخوانی ابزار
class AgentToolCallScan {
  /// فراخوانی‌های کامل و یکتا (تکراری‌های عیناً مشابه حذف شده‌اند)
  final List<AgentToolCall> calls;

  /// متن قابل نمایش به کاربر (بدون تگ ابزار/اکشن/حافظه)
  final String cleanText;

  /// تگ `<tool_call>` باز شده ولی هنوز بسته نشده (استریم در حال نوشتن است)
  final bool hasOpenTag;

  /// تعداد کاراکترهایی که مدل پس از آخرین `</tool_call>` نوشته است.
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

  static final RegExp _blockRe = RegExp(
      r'<(?:tool_call|tool)>([\s\S]*?)<\/(?:tool_call|tool)>|\[TOOL_CALL\]([\s\S]*?)\[\/TOOL_CALL\]|\[TOOL\]([\s\S]*?)\[\/TOOL\]',
      caseSensitive: false);
  static final RegExp _functionTagRe = RegExp(
      r'<(?:function|tool)=([a-zA-Z0-9_\-]+)>([\s\S]*?)<\/(?:function|tool)>',
      caseSensitive: false);
  static final RegExp _codeBlockJsonRe =
      RegExp(r'```(?:json|tool)?\s*(\{[\s\S]*?\})\s*```', caseSensitive: false);
  static final RegExp _danglingToolRe = RegExp(
      r'<(?:tool_call|tool)>[\s\S]*$|\[TOOL_CALL\][\s\S]*$|\[TOOL\][\s\S]*$',
      caseSensitive: false);
  static final RegExp _actionsRe = RegExp(r'<actions>[\s\S]*?<\/actions>', caseSensitive: false);
  static final RegExp _memOpsRe = RegExp(r'<memory_ops>[\s\S]*?<\/memory_ops>', caseSensitive: false);
  static final RegExp _danglingTagRe = RegExp(
      r'<(actions|memory_ops|memory|tool_call|function|tool)[^>]*>[\s\S]*$|\[(actions|memory_ops|memory|TOOL_CALL|TOOL)\][\s\S]*$',
      caseSensitive: false);
  static final RegExp _partialTagRe = RegExp(
      r'<\/?(action|tool|memory|actions|tool_call|memory_ops|function)[^>]*$|\[\/?(action|tool|memory|actions|TOOL_CALL|TOOL)[^\]]*$',
      caseSensitive: false);
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

    // ۱. تگ استاندارد <tool_call>, <tool>, [TOOL_CALL], [TOOL]
    for (final match in _blockRe.allMatches(raw)) {
      final body = match.group(1) ?? match.group(2) ?? match.group(3) ?? '';
      for (final call in _decodeCalls(body, errors)) {
        final signature = '${call.toolName}|${stableArgs(call.parameters)}';
        if (seen.add(signature)) {
          calls.add(call);
        }
      }
    }

    // ۲. تگ <function=name> یا <tool=name>
    for (final match in _functionTagRe.allMatches(raw)) {
      final name = match.group(1) ?? '';
      final body = match.group(2) ?? '';
      final parsedCalls = _decodeFunctionTagCall(name, body, errors);
      for (final call in parsedCalls) {
        final signature = '${call.toolName}|${stableArgs(call.parameters)}';
        if (seen.add(signature)) {
          calls.add(call);
        }
      }
    }

    // ۳. بلوک کد مارک‌داون شامل JSON ابزار
    if (calls.isEmpty) {
      for (final match in _codeBlockJsonRe.allMatches(raw)) {
        final jsonText = match.group(1) ?? '';
        final bare = _decodeBareJsonCall(jsonText);
        if (bare != null) {
          final signature = '${bare.toolName}|${stableArgs(bare.parameters)}';
          if (seen.add(signature)) {
            calls.add(bare);
          }
        }
      }
    }

    final lastClose = raw.lastIndexOf(_closeTag);
    final tail =
        lastClose >= 0 ? raw.substring(lastClose + _closeTag.length).trim() : '';

    final lastOpen = raw.lastIndexOf(_openTag);
    final hasDanglingTag = _danglingTagRe.hasMatch(raw) || _partialTagRe.hasMatch(raw);

    // بررسی بلوک کد مارک‌داون باز (تعداد فرد ```)
    final fenceMatches = RegExp(r'```').allMatches(raw).toList();
    var hasOpenFenceTool = false;
    if (fenceMatches.length % 2 != 0) {
      final lastFencePos = fenceMatches.last.start;
      final fenceTail = raw.substring(lastFencePos);
      if (RegExp(r'^```(?:json|tool)?\s*\{?', caseSensitive: false).hasMatch(fenceTail)) {
        hasOpenFenceTool = true;
      }
    }

    final hasOpenTag = hasDanglingTag || hasOpenFenceTool || (lastOpen >= 0 && lastOpen > lastClose);

    // ۴. حالت لبه: مدل بدون تگ، تنها یک JSON با کلید tool فرستاده است
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
    text = text.replaceAll(_functionTagRe, '');
    text = text.replaceAll(_danglingToolRe, '');
    text = text.replaceAllMapped(_codeBlockJsonRe, (match) {
      final jsonText = match.group(1) ?? '';
      if (_decodeBareJsonCall(jsonText) != null) {
        return '';
      }
      return match.group(0) ?? '';
    });
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

    // اگر بلوک کد ابزار نیمه‌کاره باز مانده، تا ابتدای آن را پاک کن
    final fenceMatches = RegExp(r'```').allMatches(text).toList();
    if (fenceMatches.length % 2 != 0) {
      final lastFencePos = fenceMatches.last.start;
      final fenceTail = text.substring(lastFencePos);
      if (RegExp(r'^```(?:json|tool)?\s*\{?', caseSensitive: false).hasMatch(fenceTail)) {
        text = text.substring(0, lastFencePos);
      }
    }

    text = text.replaceAll(RegExp(r'[ \t]{2,}'), ' ');
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
      if (extracted != null) {
        try {
          decoded = jsonDecode(extracted);
        } catch (_) {
          decoded = null;
        }
      }
      if (decoded == null) {
        final xmlCall = _parseXmlToolCall(text);
        if (xmlCall != null) {
          return [xmlCall];
        }
        errors.add('بدنهٔ tool_call قابل پارس نبود: ${_short(text)}');
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

    final hasNameKey = text.contains('"tool"') ||
        text.contains('"action"') ||
        text.contains('"name"') ||
        text.contains('"tool_name"') ||
        text.contains('"function"');

    final hasArgsKey = text.contains('"parameters"') ||
        text.contains('"arguments"') ||
        text.contains('"args"') ||
        text.contains('"params"') ||
        text.contains('"data"') ||
        text.contains('"input"');

    if (!hasNameKey && !hasArgsKey) return null;

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

  static List<AgentToolCall> _decodeFunctionTagCall(
    String name,
    String body,
    List<String> errors,
  ) {
    final cleanBody = body
        .replaceFirst(_fenceOpenRe, '')
        .replaceFirst(_fenceCloseRe, '')
        .trim();
    if (cleanBody.isEmpty) {
      return [AgentToolCall(toolName: name, parameters: const {})];
    }
    try {
      final decoded = jsonDecode(cleanBody);
      if (decoded is Map) {
        return [
          AgentToolCall(
            toolName: name,
            parameters: decoded.cast<String, dynamic>(),
          )
        ];
      }
    } catch (_) {
      final extracted = _extractFirstJsonObject(cleanBody);
      if (extracted != null) {
        try {
          final decoded = jsonDecode(extracted);
          if (decoded is Map) {
            return [
              AgentToolCall(
                toolName: name,
                parameters: decoded.cast<String, dynamic>(),
              )
            ];
          }
        } catch (e) {
          RitmoLog.debug('AgentToolCallParser', 'XML body JSON parse fallback failed: $e');
        }
      }
      final xmlParams = _extractXmlTags(cleanBody);
      return [AgentToolCall(toolName: name, parameters: xmlParams)];
    }
    return [AgentToolCall(toolName: name, parameters: const {})];
  }

  static AgentToolCall? _parseXmlToolCall(String text) {
    final nameMatch = RegExp(
      r'<(?:name|tool)>([a-zA-Z0-9_\-]+)<\/(?:name|tool)>',
      caseSensitive: false,
    ).firstMatch(text);
    if (nameMatch == null) return null;
    final toolName = nameMatch.group(1)!.trim();

    final paramsMatch = RegExp(
      r'<(?:parameters|arguments|args)>([\s\S]*?)<\/(?:parameters|arguments|args)>',
      caseSensitive: false,
    ).firstMatch(text);

    Map<String, dynamic> params = {};
    if (paramsMatch != null) {
      final pText = paramsMatch.group(1)!.trim();
      try {
        final decoded = jsonDecode(pText);
        if (decoded is Map) {
          params = decoded.cast<String, dynamic>();
        }
      } catch (_) {
        params = _extractXmlTags(pText);
      }
    } else {
      params = _extractXmlTags(text, ignoreTags: {'name', 'tool'});
    }

    return AgentToolCall(toolName: toolName, parameters: params);
  }

  static Map<String, dynamic> _extractXmlTags(
    String text, {
    Set<String> ignoreTags = const {},
  }) {
    final result = <String, dynamic>{};
    final tagRe = RegExp(r'<([a-zA-Z0-9_\-]+)>([\s\S]*?)<\/\1>');
    for (final match in tagRe.allMatches(text)) {
      final tagName = match.group(1)!.trim();
      if (ignoreTags.contains(tagName.toLowerCase())) continue;
      final val = match.group(2)!.trim();
      final numVal = num.tryParse(val);
      if (numVal != null) {
        result[tagName] = numVal is int ? numVal.toInt() : numVal;
      } else if (val.toLowerCase() == 'true') {
        result[tagName] = true;
      } else if (val.toLowerCase() == 'false') {
        result[tagName] = false;
      } else {
        result[tagName] = val;
      }
    }
    return result;
  }

  static String _short(String text) =>
      text.length <= 120 ? text : '${text.substring(0, 120)}…';
}
