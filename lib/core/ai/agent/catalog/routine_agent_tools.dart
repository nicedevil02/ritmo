import 'package:ritmo/core/ai/agent/agent_tool.dart';
import 'package:ritmo/core/database/database_helper.dart';

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

/// ۳. ابزار ایجاد روتین جدید — غیرفعال تا فاز ۲
///
/// نسخه قبلی مستقیم در جدول routines می‌نوشت و سه مشکل مرگ‌آور داشت:
/// ۱) ستون‌های scheduledTime و estimatedDurationMinutes وجود ندارند.
/// ۲) ستون‌های NOT NULL مانند routineType، notificationLevel، displayOrder و updatedAt
///    مقدار نمی‌گرفتند.
/// ۳) هیچ رکوردی در routine_schedules و routine_occurrences ساخته نمی‌شد، پس
///    روتین در تقویم نامرئی می‌ماند (همان کلاس باگ C-FIX-5 و B-FIX-EVENT-6).
///
/// در فاز ۲ این ابزار به آداپتوری روی RitmoCommandBus / RitmoExecutionKernel
/// (CreateRoutineCommand) بازنویسی می‌شود که روتین و زمان‌بندی و اکیورنس‌ها را
/// با هم و درست می‌سازد.
class CreateNewRoutineTool extends AgentTool {
  const CreateNewRoutineTool()
      : super(
          name: 'create_new_routine',
          categoryFa: 'روتین‌ها و عادات',
          titleFa: 'ایجاد روتین جدید',
          descriptionFa:
              'فعلاً غیرفعال است. برای ساخت روتین، کاربر را به بخش «کار جدید» در برنامه راهنمایی کن.',
          policy: ToolPolicy.actionDirect,
          parameters: const [
            ToolParameter(
              name: 'title',
              descriptionFa: 'عنوان روتین',
              type: 'string',
              isRequired: true,
            ),
            ToolParameter(
              name: 'time',
              descriptionFa: 'ساعت انجام به فرمت HH:MM',
              type: 'string',
              isRequired: true,
            ),
          ],
        );

  @override
  Future<AgentToolResult> execute(Map<String, dynamic> args) async {
    return AgentToolResult.failure(
      toolName: name,
      errorMessage:
          'این ابزار فعلاً غیرفعال است و هیچ داده‌ای ثبت نکرد. ادعا نکن که روتین ساخته شد؛ از کاربر بخواه از بخش «کار جدید» در برنامه روتین را اضافه کند.',
    );
  }
}
