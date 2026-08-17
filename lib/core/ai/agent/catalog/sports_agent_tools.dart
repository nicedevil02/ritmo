import 'package:ritmo/core/ai/agent/agent_tool.dart';
import 'package:ritmo/core/ai/agent/catalog/kernel_command_tool.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/domain/commands/command_plan.dart';
import 'package:ritmo/core/logging/ritmo_logger.dart';

/// تشخیص تاریخ از مقداری که فرمتش تأیید نشده است.
///
/// در این پروژه برخی جدول‌ها تاریخ را millis و برخی به صورت متن ISO ذخیره
/// می‌کنند. نسخهٔ قبلی این ابزار در SQL مستقیماً millis را با ستون مقایسه می‌کرد؛
/// اگر ستون متنی بود، شرط هیچ‌وقت برقرار نمی‌شد و نتیجه همیشه «هیچ جلسه‌ای
/// ثبت نشده» می‌شد — یک دروغ خاموش.
DateTime? _parseWhen(Object? value) {
  if (value == null) return null;
  if (value is int) {
    if (value > 100000000000) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value > 1000000000) {
      return DateTime.fromMillisecondsSinceEpoch(value * 1000);
    }
    return null;
  }
  final s = value.toString().trim();
  if (s.isEmpty) return null;
  final n = int.tryParse(s);
  if (n != null) {
    if (n > 100000000000) return DateTime.fromMillisecondsSinceEpoch(n);
    if (n > 1000000000) return DateTime.fromMillisecondsSinceEpoch(n * 1000);
    return null;
  }
  return DateTime.tryParse(s);
}

/// ۱. ابزار دریافت تاریخچه ورزش‌ها و تمرینات
class GetSportsHistoryTool extends AgentTool {
  const GetSportsHistoryTool()
      : super(
          name: 'get_sports_history',
          categoryFa: 'ورزش و تحرک',
          titleFa: 'دریافت تاریخچه ورزش‌ها',
          descriptionFa:
              'سوابق جلسات تمرینی و فعالیت‌های بدنی کاربر را در بازهٔ مشخص بازمی‌گرداند.',
          policy: ToolPolicy.readOnly,
          parameters: const [
            ToolParameter(
              name: 'days',
              descriptionFa: 'تعداد روزهای گذشته (پیش‌فرض ۷، حداکثر ۹۰)',
              type: 'int',
              defaultValue: 7,
            ),
          ],
        );

  @override
  Future<AgentToolResult> execute(Map<String, dynamic> args) async {
    final days = KernelCommandTool.clampedInt(args['days'], 7, 1, 90);
    final db = await DatabaseHelper.instance.database;
    final cutoff = DateTime.now().subtract(Duration(days: days));

    final rows = <Map<String, Object?>>[];
    final failures = <String>[];

    try {
      rows.addAll(await db.rawQuery(
        'SELECT * FROM sports_sessions ORDER BY rowid DESC LIMIT 60',
      ));
    } catch (e, st) {
      RitmoLog.error('GetSportsHistoryTool', 'sports_sessions query failed', e, st);
      failures.add('sports_sessions: $e');
    }

    try {
      rows.addAll(await db.rawQuery(
        'SELECT * FROM movement_logs ORDER BY rowid DESC LIMIT 60',
      ));
    } catch (e, st) {
      RitmoLog.error('GetSportsHistoryTool', 'movement_logs query failed', e, st);
      failures.add('movement_logs: $e');
    }

    // هر دو منبع شکست = هیچ داده‌ای در دست نیست. ادعای «چیزی ثبت نشده» دروغ است.
    if (failures.length == 2) {
      return AgentToolResult.failure(
        toolName: name,
        errorMessage:
            'هیچ‌یک از جدول‌های ورزش قابل خواندن نبود، پس نتیجه‌گیری نکن که کاربر ورزش نکرده. جزئیات: ${failures.join(' | ')}',
      );
    }

    final inRange = <Map<String, dynamic>>[];
    var unknownDateCount = 0;

    for (final r in rows) {
      final when = _parseWhen(r['completedAt']) ??
          _parseWhen(r['createdAt']) ??
          _parseWhen(r['timestamp']) ??
          _parseWhen(r['date']) ??
          _parseWhen(r['loggedAt']);

      if (when != null && when.isBefore(cutoff)) continue;
      if (when == null) unknownDateCount++;

      inRange.add(<String, dynamic>{
        'id': r['id'],
        'title': r['title'] ?? r['activityName'] ?? r['name'] ?? 'تمرین ورزشی',
        'type': r['type'] ?? r['category'] ?? 'عمومی',
        'durationMinutes': r['durationMinutes'] ?? r['duration'],
        'status': r['status'] ?? ((r['isCompleted'] as num?)?.toInt() == 1 ? 'انجام شد' : 'ثبت‌شده'),
        'date': when == null ? null : AgentDateResolver.iso(when),
        if (when == null) 'dateUnknown': true,
      });
    }

    final warning = failures.isEmpty
        ? ''
        : ' هشدار: یک منبع خوانده نشد (${failures.first})، پس لیست ممکن است ناقص باشد.';

    if (inRange.isEmpty) {
      return AgentToolResult.success(
        toolName: name,
        data: {
          'sessions': <Map<String, dynamic>>[],
          'totalCount': 0,
          'daysChecked': days,
          if (failures.isNotEmpty) 'partialFailures': failures,
        },
        summaryFa:
            'در $days روز گذشته هیچ جلسهٔ ورزشی ثبت‌شده‌ای پیدا نشد (جدول‌ها خوانده شدند).$warning',
      );
    }

    return AgentToolResult.success(
      toolName: name,
      data: {
        'sessions': inRange,
        'totalCount': inRange.length,
        'daysChecked': days,
        if (unknownDateCount > 0) 'itemsWithUnknownDate': unknownDateCount,
        if (failures.isNotEmpty) 'partialFailures': failures,
      },
      summaryFa:
          '${inRange.length} جلسهٔ ورزشی در بازهٔ $days روز اخیر یافت شد.'
          '${unknownDateCount > 0 ? ' ($unknownDateCount مورد تاریخ مشخصی نداشت و احتیاطاً نگه داشته شد.)' : ''}'
          '$warning',
    );
  }
}

/// ۲. ابزار دریافت برنامهٔ ورزشی
class GetSportsPlanTool extends AgentTool {
  const GetSportsPlanTool()
      : super(
          name: 'get_sports_plan',
          categoryFa: 'ورزش و تحرک',
          titleFa: 'دریافت برنامه ورزشی',
          descriptionFa:
              'برنامهٔ تمرینی ثبت‌شدهٔ کاربر را بازمی‌گرداند. اگر برنامه‌ای نباشد، همین را صریح می‌گوید.',
          policy: ToolPolicy.readOnly,
        );

  @override
  Future<AgentToolResult> execute(Map<String, dynamic> args) async {
    final db = await DatabaseHelper.instance.database;

    try {
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
        ['sports_plans'],
      );
      if (tables.isEmpty) {
        return AgentToolResult.failure(
          toolName: name,
          errorMessage:
              'جدول برنامهٔ ورزشی در این نسخه وجود ندارد؛ این بخش قابل خواندن نیست.',
        );
      }

      final rows = await db.rawQuery(
        'SELECT * FROM sports_plans ORDER BY rowid DESC LIMIT 5',
      );

      if (rows.isEmpty) {
        return AgentToolResult.success(
          toolName: name,
          data: {'plans': <Map<String, Object?>>[], 'count': 0},
          summaryFa: 'جدول برنامهٔ ورزشی خوانده شد و هیچ برنامه‌ای ثبت نشده است.',
        );
      }

      return AgentToolResult.success(
        toolName: name,
        data: {'plans': rows, 'count': rows.length},
        summaryFa: '${rows.length} برنامهٔ ورزشی ثبت‌شده یافت شد.',
      );
    } catch (e, st) {
      RitmoLog.error('GetSportsPlanTool', 'sports_plans query failed', e, st);
      return AgentToolResult.failure(
        toolName: name,
        errorMessage: 'خواندن برنامهٔ ورزشی با خطا متوقف شد: $e',
      );
    }
  }
}

/// ۳. ابزار ثبت فعالیت ورزشی
///
/// هنوز مستقیم می‌نویسد (بدون عبور از RitmoCommandBus)، پس نه audit دارد و نه undo.
/// انتقالش به فرمان‌های ورزش به فاز بعد موکول شد؛ ولی دروغ گفتنش همین الان
/// متوقف شد.
/// ۴. ابزار ثبت فعالیت ورزشی از طریق RitmoCommandBus
class LogSportsSessionTool extends KernelCommandTool {
  const LogSportsSessionTool()
      : super(
          name: 'log_sports_session',
          categoryFa: 'ورزش و تحرک',
          titleFa: 'ثبت فعالیت ورزشی',
          descriptionFa: 'یک جلسهٔ ورزشی یا فعالیت حرکتی انجام‌شده را در سوابق کاربر ثبت می‌کند.',
          commandId: 'sports.log_movement',
          policy: ToolPolicy.actionDirect,
          parameters: const [
            ToolParameter(
              name: 'title',
              descriptionFa: 'عنوان یا نوع تمرین (مانند دویدن، بدنسازی، پیاده‌روی)',
              type: 'string',
              isRequired: true,
            ),
            ToolParameter(
              name: 'durationMinutes',
              descriptionFa: 'مدت زمان به دقیقه',
              type: 'int',
              isRequired: true,
            ),
            ToolParameter(
              name: 'type',
              descriptionFa: 'دسته‌بندی (کاردیو، قدرتی، کششی)',
              type: 'string',
              defaultValue: 'عمومی',
            ),
          ],
        );

  @override
  Future<List<PlanStep>> buildSteps(Map<String, dynamic> args) async {
    final title = KernelCommandTool.optionalString(args['title']);
    if (title == null || title.isEmpty) {
      throw const ToolArgumentError('عنوان تمرین (title) الزامی است و چیزی ثبت نشد.');
    }

    final duration = KernelCommandTool.clampedInt(args['durationMinutes'], 30, 1, 600);
    final type = KernelCommandTool.optionalString(args['type']) ?? 'GENERAL';

    return [
      PlanStep(
        commandId: commandId,
        payload: {
          'kindCode': type.toUpperCase(),
          'durationMinutes': duration,
          'note': title,
        },
      ),
    ];
  }

  @override
  String buildSummaryFa(Map<String, dynamic> args, Map<String, dynamic> output) {
    final title = args['title'] ?? 'تمرین';
    final duration = args['durationMinutes'] ?? 30;
    return 'فعالیت ورزشی «$title» به مدت $duration دقیقه با موفقیت ثبت شد.';
  }
}
