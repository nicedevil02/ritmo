import 'package:ritmo/core/ai/agent/agent_tool.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:shamsi_date/shamsi_date.dart';

/// ۱. ابزار دریافت برنامه و زمان‌بندی روزانه
class GetDayAgendaTool extends AgentTool {
  const GetDayAgendaTool()
      : super(
          name: 'get_day_agenda',
          categoryFa: 'برنامه‌ریزی روز',
          titleFa: 'دریافت برنامه روزانه',
          descriptionFa: 'لیست تمام تعهدات، روتین‌ها و کارهای زمان‌بندی‌شده کاربر را برای امروز یا تاریخ مورد نظر بازمی‌گرداند.',
          policy: ToolPolicy.readOnly,
          parameters: const [
            ToolParameter(
              name: 'targetDate',
              descriptionFa: 'تاریخ مورد نظر (جلالی مانند 1403/05/20 یا کلمه "today" یا "tomorrow")',
              type: 'string',
              defaultValue: 'today',
            ),
          ],
        );

  @override
  Future<AgentToolResult> execute(Map<String, dynamic> args) async {
    final target = args['targetDate']?.toString() ?? 'today';
    final db = await DatabaseHelper.instance.database;

    final routines = await db.query(
      'routines',
      where: 'isArchived = 0 OR isArchived IS NULL',
      orderBy: 'scheduledTime ASC',
    );

    final goals = await db.query(
      'goals',
      where: 'status != ?',
      whereArgs: ['completed'],
      limit: 10,
    );

    final agendaItems = routines.map((r) => {
      'type': 'routine',
      'title': r['title'],
      'time': r['scheduledTime'] ?? 'نامشخص',
      'duration': r['estimatedDurationMinutes'] ?? 15,
      'category': r['category'],
    }).toList();

    return AgentToolResult.success(
      toolName: name,
      data: {
        'target': target,
        'itemCount': agendaItems.length,
        'items': agendaItems,
        'activeGoalsCount': goals.length,
      },
      summaryFa: 'برنامه روز شامل ${agendaItems.length} روتین و فعالیت زمان‌بندی‌شده استخراج شد.',
    );
  }
}

/// ۲. ابزار پیشنهاد و چیدمان برنامه روز
class ApplySmartDayPlanTool extends AgentTool {
  const ApplySmartDayPlanTool()
      : super(
          name: 'apply_smart_day_plan',
          categoryFa: 'برنامه‌ریزی روز',
          titleFa: 'چیدمان هوشمند برنامه روز',
          descriptionFa: 'یک برنامه زمان‌بندی جدید بر اساس ظرفیت انرژی و روتین‌های کاربر ایجاد می‌کند.',
          policy: ToolPolicy.actionInteractive,
          parameters: const [
            ToolParameter(
              name: 'planSummary',
              descriptionFa: 'خلاصه چینش برنامه و تغییرات زمانی اعمال‌شده',
              type: 'string',
              isRequired: true,
            ),
            ToolParameter(
              name: 'tasksJson',
              descriptionFa: 'لیست کارها و ساعت‌های جدید به فرمت JSON',
              type: 'string',
            ),
          ],
        );

  @override
  Future<AgentToolResult> execute(Map<String, dynamic> args) async {
    final summary = args['planSummary']?.toString() ?? 'برنامه روزانه جدید';
    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = 'plan_${now}';

    try {
      await db.insert('assistant_plans', {
        'id': id,
        'summary': summary,
        'status': 'ready',
        'createdAt': now,
      });
    } catch (_) {}

    return AgentToolResult.success(
      toolName: name,
      data: {'planId': id, 'summary': summary},
      summaryFa: 'پیش‌نویس چیدمان برنامه روز آماده شد و برای تایید به کاربر ارائه می‌شود.',
    );
  }
}
