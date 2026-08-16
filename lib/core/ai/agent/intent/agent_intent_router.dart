import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:ritmo/core/ai/agent/agent_event.dart';
import 'package:ritmo/core/ai/agent/agent_tool.dart';
import 'package:ritmo/core/ai/agent/agent_tool_registry.dart';
import 'package:ritmo/core/ai/agent/intent/ritmo_date_parser.dart';

/// نتیجه مسیریابی نیت و پیش‌واکشی داده
class PrefetchResult {
  final List<AgentStep> initialSteps;
  final String formattedContextBlock;
  final List<AgentToolResult> toolResults;

  /// ابزارهایی که روتر تشخیص داد و اجرا کرد (برای لاگ و تست)
  final List<String> executedCalls;

  const PrefetchResult({
    required this.initialSteps,
    required this.formattedContextBlock,
    required this.toolResults,
    this.executedCalls = const <String>[],
  });

  static const empty = PrefetchResult(
    initialSteps: <AgentStep>[],
    formattedContextBlock: '',
    toolResults: <AgentToolResult>[],
  );
}

/// روتر نیت ایجنت (فاز ۴ · P4-2) — جایگزین منطق contains خام
///
/// دو تفاوت اساسی با نسخه قبلی:
///  ۱. تطبیق در سطح توکن انجام می‌شود نه زیررشته؛ پس «مودم» دیگر نیت
///     مود/انرژی را فعال نمی‌کند و «دربی» به «بی» تبدیل نمی‌شود.
///  ۲. تاریخ با RitmoDateParser حل می‌شود، پس «برنامه شنبه آینده» و
///     «۲۰ مرداد» هم درست به تاریخ واقعی ترجمه می‌شوند.
class AgentIntentRouter {
  AgentIntentRouter._();

  static final AgentIntentRouter instance = AgentIntentRouter._();

  /// سقف ابزار پیش‌واکشی در یک نوبت (کنترل حجم پرامپت)
  static const int maxToolsPerTurn = 4;

  /// سقف طول داده هر ابزار در پرامپت
  static const int maxDataCharsPerTool = 1200;

  /// جداکننده توکن: هر چیزی جز حرف و عدد
  static final RegExp _splitter = RegExp(r'[^\p{L}\p{N}]+', unicode: true);

  /// کلمات ایست برای استخراج عبارت جستجوی یادداشت
  static const List<String> _noteStopWords = <String>[
    'یادداشت',
    'یادداشتم',
    'یادداشتها',
    'یادداشتهای',
    'نوت',
    'نوتم',
    'دفترچه',
    'جستجو',
    'جستوجو',
    'سرچ',
    'کن',
    'بکن',
    'کنی',
    'ببین',
    'پیدا',
    'در',
    'درباره',
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

  /// توکن‌سازی نرمال‌شده (بدون نیم‌فاصله و با ارقام لاتین)
  static List<String> tokenize(String input) {
    return RitmoDateParser.normalize(input)
        .split(_splitter)
        .where((t) => t.isNotEmpty)
        .toList();
  }

  static bool _hasAny(
    List<String> tokens,
    String joined,
    List<String> keywords,
  ) {
    for (final keyword in keywords) {
      final normalized = RitmoDateParser.normalize(keyword);
      if (normalized.isEmpty) continue;
      if (normalized.contains(' ')) {
        // عبارت چندکلمه‌ای: با مرز کلمه در متن توکن‌شده
        if (joined.contains(' $normalized ')) return true;
      } else if (tokens.contains(normalized)) {
        return true;
      }
    }
    return false;
  }

  /// تشخیص نیت و اجرای موازی ابزارهای خواندنی مرتبط
  Future<PrefetchResult> route(String userQuery, {DateTime? now}) async {
    final tokens = tokenize(userQuery);
    if (tokens.isEmpty) return PrefetchResult.empty;
    final joined = ' ${tokens.join(' ')} ';

    final toolsToRun = <String, Map<String, dynamic>>{};

    // ۱. ورزش
    if (_hasAny(tokens, joined, <String>[
      'ورزش',
      'ورزشی',
      'تمرین',
      'تمرینات',
      'باشگاه',
      'دویدن',
      'دو',
      'پیادهروی',
      'کاردیو',
      'بدنسازی',
      'شنا',
    ])) {
      toolsToRun['get_sports_history'] = <String, dynamic>{'days': 7};
      toolsToRun['get_sports_plan'] = <String, dynamic>{};
    }

    // ۲. روتین و عادت
    if (_hasAny(tokens, joined, <String>[
      'روتین',
      'روتینها',
      'روتینهایم',
      'عادت',
      'عادتها',
      'استریک',
      'پیوستگی',
      'کارهای من',
    ])) {
      toolsToRun['get_routines_overview'] = <String, dynamic>{};
      toolsToRun['get_routine_streak_stats'] = <String, dynamic>{};
    }

    // ۳. برنامه روز — تاریخ با پارسر واقعی حل می‌شود
    final wantsAgenda = _hasAny(tokens, joined, <String>[
      'برنامه',
      'برنامهام',
      'اجندا',
      'بچین',
      'زمانبندی',
      'تایم',
      'تقویم',
      'کارها',
    ]);
    final dateRange = RitmoDateParser.parse(userQuery, now: now);
    if (wantsAgenda || dateRange.matched) {
      toolsToRun['get_day_agenda'] = <String, dynamic>{
        'targetDate': dateRange.startIso,
      };
    }

    // ۴. خواب و انرژی
    if (_hasAny(tokens, joined, <String>[
      'خواب',
      'خوابیدن',
      'بیدار',
      'بیداری',
      'انرژی',
      'خستگی',
      'خسته',
      'مود',
      'حالم',
      'حوصله',
    ])) {
      toolsToRun['get_sleep_diagnostics'] = <String, dynamic>{'days': 7};
      toolsToRun['get_energy_trends'] = <String, dynamic>{'days': 7};
    }

    // ۵. اهداف
    if (_hasAny(tokens, joined, <String>[
      'هدف',
      'هدفم',
      'اهداف',
      'اهدافم',
      'تارگت',
      'پیشرفت',
    ])) {
      toolsToRun['get_active_goals_summary'] = <String, dynamic>{};
    }

    // ۶. یادداشت‌ها
    if (_hasAny(tokens, joined, <String>[
      'یادداشت',
      'یادداشتم',
      'یادداشتها',
      'یادداشتهایم',
      'نوت',
      'دفترچه',
      'نوشتم',
    ])) {
      toolsToRun['search_user_notes'] = <String, dynamic>{
        'query': extractNoteQuery(userQuery),
      };
    }

    // ۷. مطالعه و کنکور
    if (_hasAny(tokens, joined, <String>[
      'کنکور',
      'مطالعه',
      'درس',
      'درسها',
      'تست',
      'آزمون',
    ])) {
      toolsToRun['get_study_progress_summary'] = <String, dynamic>{};
    }

    // ۸. عبادت
    if (_hasAny(tokens, joined, <String>[
      'نماز',
      'قران',
      'قرآن',
      'دعا',
      'عبادت',
      'زیارت',
    ])) {
      toolsToRun['get_worship_routines'] = <String, dynamic>{};
    }

    if (toolsToRun.isEmpty) return PrefetchResult.empty;

    final entries = toolsToRun.entries.take(maxToolsPerTurn).toList();
    final steps = <AgentStep>[];
    final results = <AgentToolResult>[];
    final executed = <String>[];

    // اجرا از مسیر executeTool رجیستری انجام می‌شود که خودش try/catch دارد؛
    // هیچ استثنایی نباید از پیش‌واکشی بیرون بزند و حلقه را ساقط کند.
    await Future.wait(entries.map((entry) async {
      final toolName = entry.key;
      final args = entry.value;
      try {
        final tool = AgentToolRegistry.instance.getTool(toolName);
        if (tool == null) {
          debugPrint('[AgentIntent] skipped unknown tool: $toolName');
          return;
        }
        final startTime = DateTime.now();
        final res =
            await AgentToolRegistry.instance.executeTool(toolName, args);
        results.add(res);
        executed.add(toolName);
        steps.add(AgentStep(
          id: 'step_${startTime.microsecondsSinceEpoch}_$toolName',
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
        debugPrint('[AgentIntent] guard caught error for $toolName: $e\n$st');
      }
    }).toList());

    final context = StringBuffer();
    final okResults = results.where((r) => r.isSuccess && r.data != null);
    final failed = results.where((r) => !r.isSuccess).toList();

    if (okResults.isNotEmpty) {
      context.writeln(
          '\n[داده‌های زنده استخراج‌شده از دیتابیس توسط ابزارهای ایجنت]:');
      if (dateRange.matched) {
        context.writeln('• بازه تاریخ درخواستی کاربر: ${dateRange.labelFa}');
      }
      for (final r in okResults) {
        context.writeln('• ${r.toolName}: ${r.summaryFa}');
        context.writeln('  داده‌ها: ${_encodeData(r.data)}');
      }
    }

    if (failed.isNotEmpty) {
      context.writeln(
          '\n[هشدار: ابزارهای زیر با خطا مواجه شدند و داده‌ای برنگرداندند. درباره این حوزه‌ها هیچ عدد یا واقعیتی نساز؛ صادقانه بگو در دسترس نیست]:');
      for (final r in failed) {
        context.writeln('• ${r.toolName}: ${r.errorMessage}');
      }
    }

    debugPrint(
        '[AgentIntent] tokens=${tokens.length} | tools=${executed.join(', ')} | date=${dateRange.matched ? dateRange.startIso : 'none'}');

    return PrefetchResult(
      initialSteps: steps,
      formattedContextBlock: context.toString(),
      toolResults: results,
      executedCalls: executed,
    );
  }

  /// استخراج عبارت جستجو با حذف توکن‌های ایست (بدون آسیب به واژه‌های واقعی)
  static String extractNoteQuery(String userQuery) {
    final stop = _noteStopWords.map(RitmoDateParser.normalize).toSet();
    final tokens = tokenize(userQuery).where((t) => !stop.contains(t)).toList();
    final joined = tokens.join(' ').trim();
    return joined.isEmpty ? userQuery.trim() : joined;
  }

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
