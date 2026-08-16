import 'package:ritmo/core/ai/agent/agent_tool.dart';
import 'package:ritmo/core/ai/agent/catalog/kernel_command_tool.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/domain/commands/command_plan.dart';

/// ۱. ابزار دریافت لیست و وضعیت روتین‌های روزانه
///
/// منبع زمان روتین جدول routine_schedules.timeOfDay است، نه ستونی روی routines.
/// جدول routines هیچ‌وقت ستون scheduledTime یا estimatedDurationMinutes نداشته.
class GetRoutinesOverviewTool extends AgentTool {
  const GetRoutinesOverviewTool()
      : super(
          name: 'get_routines_overview',
          categoryFa: 'روتین‌ها و عادات',
          titleFa: 'دریافت روتین‌های کاربر',
          descriptionFa:
              'لیست روتین‌های فعال (بایگانی‌نشده) همراه ساعت، نوع تکرار، دسته‌بندی و مدت‌زمان را بازمی‌گرداند. برای برنامه یک روز خاص از get_day_agenda استفاده کن.',
          policy: ToolPolicy.readOnly,
          parameters: const [
            ToolParameter(
              name: 'category',
              descriptionFa:
                  'فیلتر بر اساس دسته (اختیاری: صبحگاهی، شبانگاهی، کاری، سلامت)',
              type: 'string',
            ),
          ],
        );

  @override
  Future<AgentToolResult> execute(Map<String, dynamic> args) async {
    final category = args['category']?.toString();
    final db = await DatabaseHelper.instance.database;

    final whereClause =
        StringBuffer('(r.isArchived = 0 OR r.isArchived IS NULL)');
    final queryArgs = <Object?>[];

    if (category != null && category.isNotEmpty) {
      whereClause.write(' AND r.category LIKE ?');
      queryArgs.add('%$category%');
    }

    final rows = await db.rawQuery('''
      SELECT
        r.id AS id,
        r.title AS title,
        r.category AS category,
        r.itemType AS itemType,
        r.isEssential AS isEssential,
        r.displayOrder AS displayOrder,
        COALESCE(r.targetDurationMinutes, r.defaultDurationMinutes) AS durationMinutes,
        (SELECT s.timeOfDay FROM routine_schedules s
           WHERE s.routineId = r.id AND s.timeOfDay IS NOT NULL AND s.timeOfDay != ''
           ORDER BY s.timeOfDay ASC LIMIT 1) AS timeOfDay,
        (SELECT s.scheduleType FROM routine_schedules s
           WHERE s.routineId = r.id ORDER BY s.createdAt ASC LIMIT 1) AS scheduleType,
        (SELECT s.daysOfWeek FROM routine_schedules s
           WHERE s.routineId = r.id ORDER BY s.createdAt ASC LIMIT 1) AS daysOfWeek
      FROM routines r
      WHERE ${whereClause.toString()}
      LIMIT 60
    ''', queryArgs);

    // مرتب‌سازی در Dart انجام می‌شود تا به تفسیر alias در ORDER BY وابسته نباشیم؛
    // روتین‌های بدون ساعت مشخص به انتها می‌روند.
    final sorted = rows.toList()
      ..sort((a, b) {
        final ta = (a['timeOfDay'] as String?)?.trim() ?? '';
        final tb = (b['timeOfDay'] as String?)?.trim() ?? '';
        if (ta.isEmpty && tb.isEmpty) {
          final oa = (a['displayOrder'] as num?)?.toInt() ?? 0;
          final ob = (b['displayOrder'] as num?)?.toInt() ?? 0;
          return oa.compareTo(ob);
        }
        if (ta.isEmpty) return 1;
        if (tb.isEmpty) return -1;
        return ta.compareTo(tb);
      });

    final routines = sorted.map((r) {
      final time = (r['timeOfDay'] as String?)?.trim() ?? '';
      return {
        'id': r['id'],
        'title': r['title'],
        'time': time.isEmpty ? 'ساعت ثابت ندارد' : time,
        'scheduleType': r['scheduleType'] ?? 'نامشخص',
        'daysOfWeek': r['daysOfWeek'],
        'category': r['category'] ?? 'عمومی',
        'itemType': r['itemType'] ?? 'ROUTINE',
        'durationMinutes': r['durationMinutes'],
        'isEssential': r['isEssential'] == 1,
      };
    }).toList();

    return AgentToolResult.success(
      toolName: name,
      data: {'routines': routines, 'count': routines.length},
      summaryFa: '${routines.length} روتین فعال در سیستم یافت شد.',
    );
  }
}

/// ۲. ابزار دریافت آمار استریک و پایبندی به روتین‌ها
///
/// ستون‌های واقعی routine_completions: completionDate / completionTime / resultType.
/// ستون completedAt وجود ندارد.
class GetRoutineStreakStatsTool extends AgentTool {
  const GetRoutineStreakStatsTool()
      : super(
          name: 'get_routine_streak_stats',
          categoryFa: 'روتین‌ها و عادات',
          titleFa: 'آمار پایبندی و استریک روتین‌ها',
          descriptionFa:
              'برای هر روتین، تعداد دفعات انجام، تعداد روزهای متمایز و آخرین تاریخ انجام را بازمی‌گرداند.',
          policy: ToolPolicy.readOnly,
        );

  /// مقادیر resultType که به معنای انجام‌شدن تلقی می‌شوند (مطابق ویو routine_actual_completions)
  static const List<String> _doneResultTypes = [
    'FULL',
    'PARTIAL',
    'MINIMAL',
    'DONE',
    'LIGHT',
    'COMPLETED',
  ];

  @override
  Future<AgentToolResult> execute(Map<String, dynamic> args) async {
    final db = await DatabaseHelper.instance.database;

    final totalRows =
        await db.rawQuery('SELECT COUNT(*) AS total FROM routine_completions');
    final total = (totalRows.first['total'] as num?)?.toInt() ?? 0;

    final perRoutine = await db.rawQuery('''
      SELECT
        c.routineId AS routineId,
        COALESCE(r.title, 'روتین حذف‌شده') AS title,
        COUNT(*) AS doneCount,
        COUNT(DISTINCT c.completionDate) AS doneDays,
        MAX(c.completionDate) AS lastDate
      FROM routine_completions c
      LEFT JOIN routines r ON r.id = c.routineId
      WHERE c.resultType IN (?, ?, ?, ?, ?, ?)
      GROUP BY c.routineId
      ORDER BY COUNT(*) DESC
      LIMIT 15
    ''', _doneResultTypes);

    final recent = await db.rawQuery('''
      SELECT
        COALESCE(r.title, 'نامشخص') AS title,
        c.completionDate AS completionDate,
        c.completionTime AS completionTime,
        c.resultType AS resultType
      FROM routine_completions c
      LEFT JOIN routines r ON r.id = c.routineId
      ORDER BY c.completionDate DESC, c.completionTime DESC
      LIMIT 12
    ''');

    return AgentToolResult.success(
      toolName: name,
      data: {
        'totalCompletions': total,
        'perRoutine': perRoutine,
        'recentLogs': recent,
      },
      summaryFa:
          'آمار پایبندی واکشی شد: مجموع $total ثبت انجام در ${perRoutine.length} روتین دارای سابقه.',
    );
  }
}

/// ۳. ابزار ایجاد روتین روزانه — فاز ۲: آداپتور روی RitmoCommandBus
///
/// نسخهٔ فاز ۰ عمداً غیرفعال بود چون مستقیم در جدول routines می‌نوشت و سه اشکال
/// مرگ‌آور داشت (ستون ناموجود، NOT NULL خالی، و نساختن schedule/occurrences که
/// روتین را در تقویم نامرئی می‌کرد).
///
/// اکنون هیچ SQL ای اینجا نیست: فرمان `routine.create` روی باس اجرا می‌شود و آن
/// فرمان خودش `CreateRoutineCommand` کرنل را صدا می‌زند که در یک تراکنش،
/// routines + routine_schedules + سی روز routine_occurrences را می‌سازد. پس هر
/// روتینی که ایجنت بسازد، دقیقاً مثل روتینِ ساخته‌شده از UI رفتار می‌کند.
///
/// محدودیت آگاهانه: فقط تکرار «روزانه». نوع weekly/custom_days بدون daysOfWeek
/// درست، آیتم را در منابع اجندا نامرئی می‌کند؛ تا وقتی آن مسیر تست نشده، مدل
/// اجازهٔ ساختنش را ندارد و باید کاربر را به بخش «کار جدید» راهنمایی کند.
class CreateNewRoutineTool extends KernelCommandTool {
  const CreateNewRoutineTool()
      : super(
          name: 'create_new_routine',
          categoryFa: 'روتین‌ها و عادات',
          titleFa: 'ایجاد روتین روزانه',
          descriptionFa:
              'یک روتین روزانهٔ تکرارشونده با ساعت مشخص می‌سازد و بلافاصله در برنامهٔ روز و تقویم ظاهر می‌شود. فقط برای تکرار «هر روز» است؛ برای روتین چندروز-در-هفته کاربر را به بخش «کار جدید» راهنمایی کن. بعد از ساخت، می‌توانی با verify_state درستی آن را بررسی کنی.',
          commandId: 'routine.create',
          policy: ToolPolicy.actionDirect,
          parameters: const [
            ToolParameter(
              name: 'title',
              descriptionFa: 'عنوان روتین (کوتاه و روشن، حداکثر ۸۰ نویسه)',
              type: 'string',
              isRequired: true,
            ),
            ToolParameter(
              name: 'time',
              descriptionFa: 'ساعت انجام با فرمت ۲۴ساعتی HH:MM (مثال: 07:30)',
              type: 'string',
              isRequired: true,
            ),
            ToolParameter(
              name: 'durationMinutes',
              descriptionFa: 'مدت زمان هدف به دقیقه (پیش‌فرض ۳۰، بین ۵ تا ۴۸۰)',
              type: 'int',
              defaultValue: 30,
            ),
          ],
        );

  @override
  Future<List<PlanStep>> buildSteps(Map<String, dynamic> args) async {
    final title = KernelCommandTool.requiredString(args['title'], 'عنوان روتین');
    if (title.length > 80) {
      throw const ToolArgumentError(
        'عنوان روتین بیش از حد بلند است؛ آن را به کمتر از ۸۰ نویسه خلاصه کن.',
      );
    }

    final time = KernelCommandTool.requiredTimeOfDay(
      args['time'] ?? args['scheduledTime'] ?? args['timeOfDay'],
      'ساعت روتین',
    );

    final duration = KernelCommandTool.clampedInt(
      args['durationMinutes'] ?? args['targetDurationMinutes'],
      30,
      5,
      480,
    );

    return <PlanStep>[
      PlanStep(
        commandId: commandId,
        payload: <String, dynamic>{
          'title': title,
          // دستهٔ 'personal' عمدی است: دستهٔ 'medical' معنای دارویی دارد و
          // فیلترهای مخصوص خودش را فعال می‌کند، پس مدل اجازهٔ تعیین دسته ندارد.
          'category': 'personal',
          'scheduleType': 'daily',
          'scheduledTime': time,
          'targetDurationMinutes': duration,
        },
        note: 'ساخته‌شده توسط دستیار ریتمو',
      ),
    ];
  }

  @override
  String buildSummaryFa(Map<String, dynamic> args, Map<String, dynamic> output) {
    final title = KernelCommandTool.optionalString(args['title']) ?? 'روتین جدید';
    final time = KernelCommandTool.normalizeTimeOfDay(
          args['time'] ?? args['scheduledTime'] ?? args['timeOfDay'],
        ) ??
        '';
    final id = output['routineId']?.toString() ?? '';
    final timePart = time.isEmpty ? '' : ' برای هر روز ساعت $time';
    return 'روتین «$title»$timePart ساخته شد و از امروز در برنامهٔ روز و تقویم دیده می‌شود'
        '${id.isEmpty ? '' : ' (شناسه: $id)'}.';
  }
}

/// ۴. ابزار ثبت انجام روتین (فاز ۲)
///
/// روی فرمان `routine.complete` سوار است که خودش `CompleteOccurrenceCommand`
/// کرنل را اجرا می‌کند: هم routine_completions ثبت می‌شود، هم وضعیت اکیورنس آن
/// روز به‌روز می‌شود، هم استریک‌ها و اسنپ‌شات‌ها هماهنگ می‌مانند.
class CompleteRoutineTool extends KernelCommandTool {
  const CompleteRoutineTool()
      : super(
          name: 'complete_routine',
          categoryFa: 'روتین‌ها و عادات',
          titleFa: 'ثبت انجام روتین',
          descriptionFa:
              'یک روتین را برای امروز (یا تاریخ مشخص) «انجام‌شده» ثبت می‌کند. اگر شناسهٔ روتین را نداری، ابتدا get_routines_overview را صدا بزن؛ عنوان تکراری یا مبهم را با ask_user روشن کن.',
          commandId: 'routine.complete',
          policy: ToolPolicy.actionDirect,
          parameters: const [
            ToolParameter(
              name: 'routineId',
              descriptionFa: 'شناسهٔ دقیق روتین (از get_routines_overview)',
              type: 'string',
            ),
            ToolParameter(
              name: 'title',
              descriptionFa:
                  'عنوان روتین؛ فقط وقتی شناسه را نداری. باید تک‌معنا باشد.',
              type: 'string',
            ),
            ToolParameter(
              name: 'date',
              descriptionFa:
                  'تاریخ انجام: امروز، دیروز، یا YYYY-MM-DD (شمسی هم پذیرفته می‌شود). پیش‌فرض امروز.',
              type: 'string',
              defaultValue: 'امروز',
            ),
          ],
        );

  @override
  Future<List<PlanStep>> buildSteps(Map<String, dynamic> args) async {
    final explicitId = KernelCommandTool.optionalString(args['routineId']);
    final title =
        KernelCommandTool.optionalString(args['title'] ?? args['routineTitle']);

    final routineId = explicitId ?? await _resolveRoutineIdByTitle(title);
    final dateStr =
        AgentDateResolver.iso(AgentDateResolver.resolve(args['date'] ?? args['dateStr']));

    return <PlanStep>[
      PlanStep(
        commandId: commandId,
        payload: <String, dynamic>{
          'routineId': routineId,
          'dateStr': dateStr,
        },
        note: 'ثبت‌شده توسط دستیار ریتمو',
      ),
    ];
  }

  /// تبدیل عنوان به شناسه. این یک «خواندن» است، نه نوشتن؛ خودِ ثبت کاملاً از
  /// مسیر فرمان انجام می‌شود. ابهام هرگز حدس زده نمی‌شود.
  Future<String> _resolveRoutineIdByTitle(String? title) async {
    if (title == null) {
      throw const ToolArgumentError(
        'برای ثبت انجام، یا routineId را بفرست یا عنوان روتین را. اگر شناسه را نداری اول get_routines_overview را صدا بزن.',
      );
    }

    final db = await DatabaseHelper.instance.database;
    final rows = await db.rawQuery('''
      SELECT r.id AS id, r.title AS title
      FROM routines r
      WHERE (r.isArchived = 0 OR r.isArchived IS NULL) AND r.title LIKE ?
      LIMIT 6
    ''', ['%$title%']);

    if (rows.isEmpty) {
      throw ToolArgumentError(
        'روتینی با عنوان «$title» پیدا نشد. با get_routines_overview فهرست واقعی روتین‌ها را ببین و دوباره تلاش کن.',
      );
    }
    if (rows.length > 1) {
      final titles = rows.map((r) => r['title']?.toString() ?? '').join('، ');
      throw ToolArgumentError(
        'عنوان «$title» به چند روتین می‌خورد: $titles. با ask_user بپرس کدام‌یک را ثبت کند؛ حدس نزن.',
      );
    }

    return rows.first['id']?.toString() ?? '';
  }

  @override
  String buildSummaryFa(Map<String, dynamic> args, Map<String, dynamic> output) {
    final label = KernelCommandTool.optionalString(args['title']) ??
        KernelCommandTool.optionalString(args['routineId']) ??
        'روتین';
    final date = AgentDateResolver.resolve(args['date'] ?? args['dateStr']);
    return 'انجام «$label» برای ${AgentDateResolver.label(date)} ثبت شد.';
  }
}
