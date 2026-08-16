import 'package:ritmo/core/ai/agent/agent_tool.dart';
import 'package:ritmo/core/database/database_helper.dart';

/// ۱. ابزار دریافت لیست و وضعیت روتین‌های روزانه
class GetRoutinesOverviewTool extends AgentTool {
  const GetRoutinesOverviewTool()
      : super(
          name: 'get_routines_overview',
          categoryFa: 'روتین‌ها و عادات',
          titleFa: 'دریافت روتین‌های کاربر',
          descriptionFa: 'لیست کامل روتین‌های فعال، زمان انجام، دسته‌بندی و وضعیت آن‌ها را بازمی‌گرداند.',
          policy: ToolPolicy.readOnly,
          parameters: const [
            ToolParameter(
              name: 'category',
              descriptionFa: 'فیلتر بر اساس دسته (اختیاری: صبحگاهی، شبانگاهی، کاری، سلامت)',
              type: 'string',
            ),
          ],
        );

  @override
  Future<AgentToolResult> execute(Map<String, dynamic> args) async {
    final category = args['category']?.toString();
    final db = await DatabaseHelper.instance.database;

    String query = 'SELECT * FROM routines WHERE isArchived = 0 OR isArchived IS NULL';
    List<dynamic> queryArgs = [];

    if (category != null && category.isNotEmpty) {
      query += ' AND category LIKE ?';
      queryArgs.add('%$category%');
    }

    query += ' ORDER BY scheduledTime ASC';

    final rows = await db.rawQuery(query, queryArgs);

    final routines = rows.map((r) {
      return {
        'id': r['id'],
        'title': r['title'] ?? r['name'],
        'time': r['scheduledTime'] ?? r['time'] ?? 'نامشخص',
        'category': r['category'] ?? 'عمومی',
        'durationMinutes': r['estimatedDurationMinutes'] ?? r['durationMinutes'] ?? 15,
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
class GetRoutineStreakStatsTool extends AgentTool {
  const GetRoutineStreakStatsTool()
      : super(
          name: 'get_routine_streak_stats',
          categoryFa: 'روتین‌ها و عادات',
          titleFa: 'آمار پایبندی و استریک روتین‌ها',
          descriptionFa: 'آمار تعداد دفعات انجام روتین‌ها و زنجیره پیوستگی (Streak) را بازمی‌گرداند.',
          policy: ToolPolicy.readOnly,
        );

  @override
  Future<AgentToolResult> execute(Map<String, dynamic> args) async {
    final db = await DatabaseHelper.instance.database;
    final completions = await db.query('routine_completions', orderBy: 'completedAt DESC', limit: 50);

    return AgentToolResult.success(
      toolName: name,
      data: {'totalCompletions': completions.length, 'recentLogs': completions.take(10).toList()},
      summaryFa: 'آمار انجام روتین‌ها با موفقیت واکشی شد (${completions.length} مورد ثبت‌شده اخیر).',
    );
  }
}

/// ۳. ابزار ایجاد روتین جدید
class CreateNewRoutineTool extends AgentTool {
  const CreateNewRoutineTool()
      : super(
          name: 'create_new_routine',
          categoryFa: 'روتین‌ها و عادات',
          titleFa: 'ایجاد روتین جدید',
          descriptionFa: 'یک روتین یا عادت جدید با زمان و مشخصات معین به برنامه کاربر اضافه می‌کند.',
          policy: ToolPolicy.actionDirect,
          parameters: const [
            ToolParameter(
              name: 'title',
              descriptionFa: 'عنوان روتین (مثلاً مطالعه کتاب، پیاده‌روی صبحگاهی)',
              type: 'string',
              isRequired: true,
            ),
            ToolParameter(
              name: 'time',
              descriptionFa: 'ساعت انجام به فرمت HH:MM (مثلاً 08:30)',
              type: 'string',
              isRequired: true,
            ),
            ToolParameter(
              name: 'category',
              descriptionFa: 'دسته روتین (سلامت، مطالعه، رشد فردی، کار)',
              type: 'string',
              defaultValue: 'عمومی',
            ),
            ToolParameter(
              name: 'durationMinutes',
              descriptionFa: 'مدت زمان به دقیقه',
              type: 'int',
              defaultValue: 15,
            ),
          ],
        );

  @override
  Future<AgentToolResult> execute(Map<String, dynamic> args) async {
    final title = args['title']?.toString() ?? 'روتین جدید';
    final time = args['time']?.toString() ?? '08:00';
    final category = args['category']?.toString() ?? 'عمومی';
    final duration = (args['durationMinutes'] is int)
        ? args['durationMinutes'] as int
        : (int.tryParse(args['durationMinutes']?.toString() ?? '15') ?? 15);

    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = 'rt_${now}';

    await db.insert('routines', {
      'id': id,
      'title': title,
      'scheduledTime': time,
      'category': category,
      'estimatedDurationMinutes': duration,
      'isArchived': 0,
      'createdAt': now,
    });

    return AgentToolResult.success(
      toolName: name,
      data: {'id': id, 'title': title, 'time': time, 'category': category, 'duration': duration},
      summaryFa: 'روتین جدید «$title» برای ساعت $time با موفقیت ثبت و فعال شد.',
    );
  }
}
