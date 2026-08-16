import 'dart:convert';

import 'package:ritmo/core/ai/agent/agent_tool.dart';

/// حاصل پویش متن مدل برای یافتن فراخوانی ابزار
class AgentToolCallScan {
  /// فراخوانی‌های کامل و یکتا (تکراری‌های عیناً مشابه حذف شده‌اند)
  final List<AgentToolCall> calls;

  /// متن قابل نمایش به کاربر (بدون تگ ابزار/اکشن/حافظه)
  final String cleanText;

  /// تگ <tool_call> باز شده ولی هنوز بسته نشده است (استریم در حال نوشتن)
  final bool hasOpenTag;

  /// تعداد کاراکترهای معنی‌داری که مدل پس از آخرین </tool_call> نوشته است.
  /// حلقه از این عدد برای قطع زودهنگام استریم استفاده می‌کند تا مدل بعد از
  /// فراخوانی ابزار شروع به ساختن پاسخ خیالی نکند.
  final int tailLength;

  /// خطاهای پارس، برای بازگرداندن پیام دقیق به مدل و لاگ تشخیصی
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

/// استخراج امنِ فراخوانی ابزار از متن (احتمالاً نیمه‌کارهٔ) مدل
///
/// چرا یک پارسر اختصاصی؟ چون متن به‌صورت استریم می‌آید و در لحظه‌ای که تگ باز
/// شده ولی بسته نشده، نه باید به کاربر نشان داده شود و نه باید به عنوان
/// فراخوانی معتبر اجرا شود. علاوه بر آن مدل‌های سبک، JSON را با بلوک ```json،
/// آرایه، پارامترهای رشته‌ای یا کلید arguments می‌فرستند و همهٔ این حالت‌ها
/// باید بدون شکست تحمل شوند.
class AgentToolCallParser {
  const AgentToolCallParser._();

  static final RegExp _blockRe =
      RegExp(r'<tool_call>([\s\S]*?)<\/tool_call>');
  static final RegExp _danglingToolRe = RegExp(r'<tool_call>[\s\S]*$');
  static final RegExp _actionsRe = RegExp(r'<actions>[\s\S]*?<\/actions>');
  static final RegExp _memOpsRe =
      RegExp(r'<memory_ops>[\s\S]*?<\/memory_ops>');
  static final RegExp _danglingTagRe =
      RegExp(r'<(actions|memory_ops|memory)>[\s\S]*$');
  static final RegExp _fenceOpenRe = RegExp(r'^\s*```[a-zA-Z0-9_-]*\s*');
  static final RegExp _fenceCloseRe = RegExp(r'\s*```\s*$');

  static const String _closeTag = '</tool_call>';
  static const String _openTag = '<tool_call>';

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
    final tail = lastClose >= 0
        ? raw.substring(lastClose + _closeTag.length).trim()
        : '';

    final lastOpen = raw.lastIndexOf(_openTag);
    final hasOpenTag = lastOpen >= 0 && lastOpen > lastClose;

    // حالت لبه: مدل بدون هیچ تگی، تنها یک JSON با کلید tool فرستاده است
    if (calls.isEmpty && !hasOpenTag) {
      final bare = _decodeBareJsonCall(raw);
      if (bare != null) {
        return AgentToolCallScan(
          calls: [bare],
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
  /// خروجی این تابع همان چیزی است که به ChatActionParser داده می‌شود؛ اگر
  /// tool_call حذف نشود، JSON خام در پیام ذخیره‌شدهٔ چت ظاهر می‌گردد.
  static String stripToolCalls(String raw) {
    var text = raw.replaceAll(_blockRe, '');
    text = text.replaceAll(_danglingToolRe, '');
    return text;
  }

  /// متن نهایی قابل نمایش به کاربر
  static String cleanForDisplay(String raw) {
    var text = stripToolCalls(raw);
    text = text.replaceAll(_actionsRe, '');
    text = text.replaceAll(_memOpsRe, '');
    text = text.replaceAll(_danglingTagRe, '');
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

  static List<AgentToolCall> _decodeCalls(