import 'package:ritmo/core/ai/agent/agent_event.dart';
import 'package:ritmo/core/ai/agent/agent_tool.dart';
import 'package:ritmo/core/ai/agent/agent_tool_registry.dart';

/// نتیجه واکشی سریع نیت و داده‌های مرتبط
class PrefetchResult {
  final List<AgentStep> initialSteps;
  final String formattedContextBlock;
  final List<AgentToolResult> toolResults;

  const PrefetchResult({
    required this.initialSteps,
    required this.formattedContextBlock,
    required this.toolResults,
  });

  static const empty = PrefetchResult(
    initialSteps: [],
    formattedContextBlock: '',
    toolResults: [],
  );
}

/// موتور تحلیل سریع نیت و واکشی موازی داده‌ها (Hybrid Intent Prefetcher)
class AgentIntentPrefetcher {
  static Future<PrefetchResult> prefetchForQuery(String userQuery) async {
    final clean = userQuery.trim().toLowerCase();
    final toolsToRun = <String, Map<String, dynamic>>{};

    // ۱. بررسی نیت ورزشی
    if (clean.contains('ورزش') ||
        clean.contains('تمرین') ||
        clean.contains('باشگاه') ||
        clean.contains('دویدن') ||
        clean.contains('پیاده‌روی') ||
        clean.contains('کاردیو') ||
        clean.contains('بدنسازی')) {
      toolsToRun['get_sports_history'] = {'days': 7};
      toolsToRun['get_sports_plan'] = {};
    }

    // ۲. بررسی نیت روتین و عادات
    if (clean.contains('روتین') ||
        clean.contains('عادت') ||
        clean.contains('کارهای من') ||
        clean.contains('استریک') ||
        clean.contains('پیوستگی')) {
      toolsToRun['get_routines_overview'] = {};
      toolsToRun['get_routine_streak_stats'] = {};
    }

    // ۳. بررسی نیت برنامه‌ریزی و چیدمان روز
    if (clean.contains('برنامه') ||
        clean.contains('بچین') ||
        clean.contains('امروز') ||
        clean.contains('فردا') ||
        clean.contains('تایم') ||
        clean.contains('زمان‌بندی')) {
      toolsToRun['get_day_agenda'] = {'targetDate': clean.contains('فردا') ? 'tomorrow' : 'today'};
    }

    // ۴. بررسی نیت خواب، خستگی و انرژی
    if (clean.contains('خواب') ||
        clean.contains('بیدار') ||
        clean.contains('انرژی') ||
        clean.contains('خستگی') ||
        clean.contains('کسر خواب') ||
        clean.contains('مود') ||
        clean.contains('حالم')) {
      toolsToRun['get_sleep_diagnostics'] = {'days': 7};
      toolsToRun['get_energy_trends'] = {'days': 7};
    }

    // ۵. بررسی نیت اهداف
    if (clean.contains('هدف') ||
        clean.contains('اهداف') ||
        clean.contains('تارگت') ||
        clean.contains('پیشرفت')) {
      toolsToRun['get_active_goals_summary'] = {};
    }

    // ۶. بررسی نیت یادداشت‌ها
    if (clean.contains('یادداشت') ||
        clean.contains('نوشتم') ||
        clean.contains('نوت') ||
        clean.contains('دفترچه')) {
      toolsToRun['search_user_notes'] = {'query': clean.replaceAll(RegExp(r'(یادداشت|نوت|جستجو|کن|در|درباره)'), '').trim()};
    }

    if (toolsToRun.isEmpty) {
      return PrefetchResult.empty;
    }

    final steps = <AgentStep>[];
    final results = <AgentToolResult>[];
    final contextBuffer = StringBuffer();

    // اجرای موازی ابزارهای شناسایی‌شده
    final futures = toolsToRun.entries.map((entry) async {
      final toolName = entry.key;
      final args = entry.value;
      final tool = AgentToolRegistry.instance.getTool(toolName);
      if (tool == null) return;

      final stepId = 'step_${DateTime.now().millisecondsSinceEpoch}_${toolName}';
      final startTime = DateTime.now();

      final res = await tool.execute(args);
      results.add(res);

      steps.add(AgentStep(
        id: stepId,
        titleFa: tool.titleFa,
        descriptionFa: res.summaryFa,
        toolName: toolName,
        status: res.isSuccess ? AgentStepStatus.success : AgentStepStatus.failed,
        startTime: startTime,
        endTime: DateTime.now(),
        resultData: res.data,
      ));
    });

    await Future.wait(futures);

    if (results.isNotEmpty) {
      contextBuffer.writeln('\n[داده‌های زنده استخراج‌شده از دیتابیس توسط ابزارهای ایجنت]:');
      for (final r in results) {
        if (r.isSuccess && r.data != null) {
          contextBuffer.writeln('• ${r.toolName}: ${r.summaryFa}');
          contextBuffer.writeln('  داده‌ها: ${r.data}');
        }
      }
    }

    return PrefetchResult(
      initialSteps: steps,
      formattedContextBlock: contextBuffer.toString(),
      toolResults: results,
    );
  }
}
