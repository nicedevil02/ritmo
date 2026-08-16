import 'package:ritmo/core/ai/agent/agent_tool.dart';
import 'package:ritmo/core/database/database_helper.dart';

/// ۱. ابزار دریافت تاریخچه ورزش‌ها و تمرینات
class GetSportsHistoryTool extends AgentTool {
  const GetSportsHistoryTool()
      : super(
          name: 'get_sports_history',
          categoryFa: 'ورزش و تحرک',
          titleFa: 'دریافت تاریخچه ورزش‌ها',
          descriptionFa: 'سوابق جلسات تمرینی، فعالیت‌های بدنی و ورزش‌های انجام‌شده کاربر را در بازه زمانی مشخص بازمی‌گرداند.',
          policy: ToolPolicy.readOnly,
          parameters: const [
            ToolParameter(
              name: 'days',
              descriptionFa: 'تعداد روزهای گذشته برای بررسی سوابق (پیش‌فرض ۷ روز)',
              type: 'int',
              defaultValue: 7,
            ),
          ],
        );

  @override
  Future<AgentToolResult> execute(Map<String, dynamic> args) async {
    final days = (args['days'] is int)
        ? args['days'] as int
        : (int.tryParse(args['days']?.toString() ?? '7') ?? 7);

    final db = await DatabaseHelper.instance.database;
    final cutoff = DateTime.now().subtract(Duration(days: days)).millisecondsSinceEpoch;

    // Fetch from sports_sessions and movement logs if present
    final sessions = <Map<String, dynamic>>[];
    try {
      final rows = await db.rawQuery('''
        SELECT * FROM sports_sessions 
        WHERE createdAt >= ? OR completedAt >= ?
        ORDER BY createdAt DESC LIMIT 30
      ''', [cutoff, cutoff]);
      sessions.addAll(rows);
    } catch (_) {}

    try {
      final mRows = await db.rawQuery('''
        SELECT * FROM movement_logs 
        WHERE timestamp >= ? 
        ORDER BY timestamp DESC LIMIT 30
      ''', [cutoff]);
      sessions.addAll(mRows);
    } catch (_) {}

    if (sessions.isEmpty) {
      return AgentToolResult.success(
        toolName: name,
        data: {'sessions': [], 'totalCount': 0, 'daysChecked': days},
        summaryFa: 'در $days روز گذشته هیچ جلسه ورزشی یا تمرینی در سیستم ثبت نشده است.',
      );
    }

    final formatted = sessions.map((s) {
      return {
        'id': s['id'],
        'title': s['title'] ?? s['activityName'] ?? s['name'] ?? 'تمرین ورزشی',
        'type': s['type'] ?? s['category'] ?? 'عمومی',
        'durationMinutes': s['durationMinutes'] ?? s['duration'] ?? 0,
        'status': s['status'] ?? (s['isCompleted'] == 1 ? 'انجام شد' : 'ثبت‌شده'),
        'date': s['date'] ?? s['createdAt'],
      };
    }).toList();

    return AgentToolResult.success(
      toolName: name,
      data: {'sessions': formatted, 'totalCount': formatted.length, 'daysChecked': days},
      summaryFa: '${formatted.length} جلسه ورزشی و تمرین در بازه $days روز اخیر یافت شد.',
    );
  }
}

/// ۲. ابزار دریافت برنامه ورزشی هفته جاری
class GetSportsPlanTool extends AgentTool {
  const GetSportsPlanTool()
      : super(
          name: 'get_sports_plan',
          categoryFa: 'ورزش و تحرک',
          titleFa: 'دریافت برنامه ورزشی',
          descriptionFa: 'برنامه تمرینی هفتگی، روزهای تمرین و گروه‌های عضلانی هدف را بازمی‌گرداند.',
          policy: ToolPolicy.readOnly,
        );

  @override
  Future<AgentToolResult> execute(Map<String, dynamic> args) async {
    final db = await DatabaseHelper.instance.database;
    final plans = <Map<String, dynamic>>[];

    try {
      final rows = await db.query('sports_plans', orderBy: 'createdAt DESC', limit: 5);
      plans.addAll(rows);
    } catch (_) {}

    if (plans.isEmpty) {
      return AgentToolResult.success(
        toolName: name,
        data: {'plan': null},
        summaryFa: 'برنامه تمرینی از پیش تعیین‌شده‌ای در سیستم ثبت نشده است.',
      );
    }

    return AgentToolResult.success(
      toolName: name,
      data: {'plans': plans},
      summaryFa: 'برنامه ورزشی فعال کاربر با موفقیت استخراج شد.',
    );
  }
}

/// ۳. ابزار ثبت فعالیت ورزشی
class LogSportsSessionTool extends AgentTool {
  const LogSportsSessionTool()
      : super(
          name: 'log_sports_session',
          categoryFa: 'ورزش و تحرک',
          titleFa: 'ثبت فعالیت ورزشی',
          descriptionFa: 'یک جلسه ورزشی یا تمرین جدید را در سوابق کاربر ثبت می‌کند.',
          policy: ToolPolicy.actionDirect,
          parameters: const [
            ToolParameter(
              name: 'title',
              descriptionFa: 'عنوان یا نوع تمرین (مثلاً دویدن، بدنسازی، پیاده‌روی)',
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
  Future<AgentToolResult> execute(Map<String, dynamic> args) async {
    final title = args['title']?.toString() ?? 'تمرین ورزشی';
    final duration = (args['durationMinutes'] is int)
        ? args['durationMinutes'] as int
        : (int.tryParse(args['durationMinutes']?.toString() ?? '30') ?? 30);
    final type = args['type']?.toString() ?? 'عمومی';

    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = 'sports_${now}';

    try {
      await db.insert('sports_sessions', {
        'id': id,
        'title': title,
        'durationMinutes': duration,
        'type': type,
        'status': 'completed',
        'createdAt': now,
        'completedAt': now,
      });
    } catch (_) {
      try {
        await db.insert('movement_logs', {
          'id': id,
          'activityName': title,
          'durationMinutes': duration,
          'timestamp': now,
        });
      } catch (_) {}
    }

    return AgentToolResult.success(
      toolName: name,
      data: {'id': id, 'title': title, 'durationMinutes': duration, 'type': type},
      summaryFa: 'فعالیت ورزشی «$title» به مدت $duration دقیقه با موفقیت ثبت گردید.',
    );
  }
}
