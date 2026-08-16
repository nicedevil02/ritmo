import 'package:flutter/foundation.dart';
import 'package:ritmo/core/ai/agent/agent_tool.dart';
import 'package:ritmo/core/ai/agent/agent_tool_registry.dart';
import 'package:ritmo/core/ai/agent/agent_tool_scope.dart';
import 'package:ritmo/core/ai/agent/intent/ritmo_date_parser.dart';

/// نتیجه مرور شبانه
class AgentReviewResult {
  const AgentReviewResult({
    required this.textFa,
    required this.toolsUsed,
    required this.failures,
    required this.dateIso,
  });

  /// متن فارسی آماده برای نمایش یا تزریق به پرامپت بریفینگ
  final String textFa;

  /// ابزارهایی که واقعا داده دادند
  final List<String> toolsUsed;

  /// ابزارهایی که خطا دادند (برای افشای صادقانه، نه پنهان‌کردن)
  final List<String> failures;

  final String dateIso;

  bool get hasData => toolsUsed.isNotEmpty;

  static const AgentReviewResult empty = AgentReviewResult(
    textFa: '',
    toolsUsed: <String>[],
    failures: <String>[],
    dateIso: '',
  );
}

/// مرور شبانه ایجنت (فاز ۵ · P5-3)
///
/// قرارداد سختگیرانه و عمدی: این مسیر فقط می‌خواند.
///  - هر ابزاری که policy آن readOnly نباشد، حتی اگر در فهرست بیاید، رد می‌شود.
///  - هیچ نوتیفیکیشنی از این‌جا فرستاده نمی‌شود؛ خروجی فقط متن است و تصمیم
///    نمایش یا ارسال، کار لایه بالاتر (بریفینگ/ورکر) است.
///  - اگر داده‌ای نباشد، متن صریحا می‌گوید داده نبود؛ عدد ساخته نمی‌شود.
class AgentNightlyReview {
  AgentNightlyReview._();

  static final AgentNightlyReview instance = AgentNightlyReview._();

  /// ابزارهای مرور شبانه و پارامترهایشان.
  /// برای get_day_agenda تاریخ در زمان اجرا تزریق می‌شود.
  static const Map<String, Map<String, dynamic>> reviewPlan =
      <String, Map<String, dynamic>>{
    'get_day_agenda': <String, dynamic>{},
    'get_routine_streak_stats': <String, dynamic>{},
    'get_energy_trends': <String, dynamic>{'days': 7},
    'get_sleep_diagnostics': <String, dynamic>{'days': 7},
  };

  /// اجرای مرور روز (برای ورکر شبانه یا دکمه دستی در صفحه ژورنال)
  Future<AgentReviewResult> run({
    DateTime? now,
    String personaId = 'global',
  }) async {
    final today = RitmoDateParser.parse('امروز', now: now);
    final allowed = AgentToolScope.instance.allowedToolNames(personaId);

    final used = <String>[];
    final failures = <String>[];
    final lines = <String>[];

    final entries = reviewPlan.entries.toList();
    await Future.wait(entries.map((entry) async {
      final toolName = entry.key;
      final tool = AgentToolRegistry.instance.getTool(toolName);
      if (tool == null) {
        debugPrint('[AgentReview] tool not registered: $toolName');
        return;
      }
      if (tool.policy != ToolPolicy.readOnly) {
        // خط قرمز: مرور شبانه هرگز چیزی نمی‌نویسد.
        debugPrint('[AgentReview] refused non-read tool: $toolName');
        return;
      }
      if (!allowed.contains(toolName)) {
        debugPrint(
            '[AgentReview] out of persona scope: $toolName | persona=$personaId');
        return;
      }

      final args = <String, dynamic>{...entry.value};
      if (toolName == 'get_day_agenda') {
        args['targetDate'] = today.startIso;
      }

      try {
        final res =
            await AgentToolRegistry.instance.executeTool(toolName, args);
        if (res.isSuccess) {
          used.add(toolName);
          lines.add('• ${res.summaryFa}');
        } else {
          failures.add('$toolName: ${res.errorMessage}');
        }
      } catch (e, st) {
        failures.add('$toolName: $e');
        debugPrint('[AgentReview] guard caught error for $toolName: $e\n$st');
      }
    }).toList());

    final buffer = StringBuffer();
    buffer.writeln('مرور شبانه ریتمو — ${today.labelFa}');

    if (lines.isEmpty) {
      buffer.writeln(
          'هیچ داده‌ای برای امروز خوانده نشد، پس هیچ تحلیلی ساخته نمی‌شود.');
    } else {
      buffer.writeln('خلاصه داده‌های واقعی امروز:');
      for (final line in lines) {
        buffer.writeln(line);
      }
    }

    if (failures.isNotEmpty) {
      buffer.writeln(
          'در این موارد داده در دسترس نبود (درباره‌شان نتیجه‌گیری نشود):');
      for (final failure in failures) {
        buffer.writeln('• $failure');
      }
    }

    debugPrint(
        '[AgentReview] date=${today.startIso} | tools=${used.join(', ')} | failed=${failures.length}');

    return AgentReviewResult(
      textFa: buffer.toString().trim(),
      toolsUsed: used,
      failures: failures,
      dateIso: today.startIso,
    );
  }
}
