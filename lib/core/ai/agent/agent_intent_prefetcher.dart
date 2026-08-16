import 'dart:convert';

import 'package:flutter/foundation.dart';
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
///
/// نکته معماری: این لایه فقط ابزارهای خواندنی را از پیش اجرا می‌کند تا مدل با
/// داده واقعی شروع کند. اجرای واقعی ابزار بر اساس تصمیم مدل (حلقه ReAct) در
/// فاز ۱ به AgentLoopRunner اضافه می‌شود.
class AgentIntentPrefetcher {
  /// حداکثر تعداد ابزاری که در یک نوبت پیش‌واکشی می‌شود (کنترل حجم پرامپت)
  static const int maxToolsPerTurn = 4;

  /// حداکثر طول متن داده هر ابزار که به پرامپت تزریق می‌شود
  static const int maxDataCharsPerTool = 1200;

  /// کلمات ایست برای استخراج عبارت جستجوی یادداشت.
  /// حذف توکنی انجام می‌شود نه حذف زیررشته‌ای؛ در نسخه قبلی regex زیررشته‌ای
  /// باعث می‌شد «کنکور» به «ور» و «دربی» به «بی» تبدیل شود.
  static const List<String> _noteStopWords = [
    'یادداشت',
    'یادداشتم',
    'یادداشت‌ها',
    'یادداشت‌های',
    'یادداشتهای',
    'نوت',
    'نوتم',
    'دفترچه',
    'جستجو',
    'جست‌وجو',
    'سرچ',
    'کن',
    'بکن',
    'کنی',
    'ببین',
    'پیدا',
    'در',
    'درباره',
    'دربارهٔ',
    'راجع',
    'راجب',
    'به',
    'از',
    'برای',
    'من',
    'رو',
    'را',
    'چی',
    'چه',
    'نوشتم',
  ];

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
      toolsToRun['get_day_agenda'] = {
        'targetDate': clean.contains('فردا')
            ? 'tomorrow'
            : (clean.contains('دیروز') ? 'yesterday' : 'today'),
      };
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
      toolsToRun['search_user_notes'] = {'query': _extractNoteQuery(userQuery)};
    }

    if (toolsToRun.isEmpty) {
      return PrefetchResult.empty;
    }

    final entries = toolsToRun.entries.take(maxToolsPerTurn).toList();
    final steps = <AgentStep>[];
    final results = <AgentToolResult>[];
    final contextBuffer = StringBuffer();

    // اجرای موازی ابزارهای شناسایی‌شده.
    // نکته حیاتی (P0-1): اجرا از مسیر executeTool رجیستری انجام می‌شود که خودش
    // try/catch دارد و در صورت خطا AgentToolResult.failure برمی‌گرداند. قبلاً
    // مستقیم tool.execute صدا زده می‌شد و اولین استثنا کل Future.wait را reject
    // می‌کرد، از runAgent بیرون می‌زد و ایجنت بی‌صدا به چت ساده سقوط می‌کرد.
    final futures = entries.map((entry) async {
      final toolName = entry.key;
      final args = entry.value;
      try {
        final tool = AgentToolRegistry.instance.getTool(toolName);
        if (tool == null) {
          debugPrint('[Agent] Prefetch skipped unknown tool: $toolName');
          return;
        }

        final stepId =
            'step_${DateTime.now().microsecondsSinceEpoch}_$toolName';
        final startTime = DateTime.now();

        final res = await AgentToolRegistry.instance.executeTool(toolName, args);
        results.add(res);

        steps.add(AgentStep(
          id: stepId,
          titleFa: tool.titleFa,
          descriptionFa: res.isSuccess ? res.summaryFa : res.errorMessage,
          toolName: toolName,
          status:
              res.isSuccess ? AgentStepStatus.success : AgentStepStatus.failed,
          startTime: startTime,
          endTime: DateTime.now(),
          resultData: res.data,
          errorMessage: res.isSuccess ? null : res.errorMessage,
        ));
      } catch (e, st) {
        // لایه دفاعی دوم: هیچ خطایی نباید از پیش‌واکشی بیرون بزند.
        debugPrint('[Agent] Prefetch guard caught error for $toolName: $e\n$st');
      }
    }).toList();

    await Future.wait(futures);

    final okResults = results.where((r) => r.isSuccess && r.data != null);
    final failedResults = results.where((r) => !r.isSuccess).toList();

    if (okResults.isNotEmpty) {
      contextBuffer.writeln(
          '\n[داده‌های زنده استخراج‌شده از دیتابیس توسط ابزارهای ایجنت]:');
      for (final r in okResults) {
        contextBuffer.writeln('• ${r.toolName}: ${r.summaryFa}');
        contextBuffer.writeln('  داده‌ها: ${_encodeData(r.data)}');
      }
    }

    // افشای شفاف خطاها به مدل تا به‌جای حدس زدن، صادقانه بگوید داده در دسترس نیست.
    if (failedResults.isNotEmpty) {
      contextBuffer.writeln(
          '\n[هشدار: ابزارهای زیر با خطا مواجه شدند و داده‌ای برنگرداندند. درباره این حوزه‌ها هیچ عدد یا واقعیتی نساز؛ صادقانه بگو در دسترس نیست]:');
      for (final r in failedResults) {
        contextBuffer.writeln('• ${r.toolName}: ${r.errorMessage}');
      }
    }

    return PrefetchResult(
      initialSteps: steps,
      formattedContextBlock: contextBuffer.toString(),
      toolResults: results,
    );
  }

  /// استخراج عبارت جستجو با حذف توکن‌های ایست (بدون آسیب به واژه‌های واقعی)
  static String _extractNoteQuery(String userQuery) {
    final tokens = userQuery
        .trim()
        .split(RegExp(r'[\s،,\.؟?!:؛]+'))
        .where((t) => t.isNotEmpty)
        .where((t) => !_noteStopWords.contains(t))
        .toList();
    final joined = tokens.join(' ').trim();
    return joined.isEmpty ? userQuery.trim() : joined;
  }

  /// سریال‌سازی داده ابزار به JSON خوانا برای مدل، با سقف طول
  static String _encodeData(dynamic data) {
    String text;
    try {
      text = jsonEncode(data);
    } catch (_) {
      text = data.toString();
    }
    if (text.length > maxDataCharsPerTool) {
      return '${text.substring(0, maxDataCharsPerTool)}… [بریده‌شده]';
    }
    return text;
  }
}
