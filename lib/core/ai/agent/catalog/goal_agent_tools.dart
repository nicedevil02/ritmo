import 'package:ritmo/core/ai/agent/agent_tool.dart';
import 'package:ritmo/core/ai/agent/catalog/kernel_command_tool.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/domain/commands/command_plan.dart';

/// ۱. ابزار دریافت اهداف فعال و پیشرفت
class GetActiveGoalsSummaryTool extends AgentTool {
  const GetActiveGoalsSummaryTool()
      : super(
          name: 'get_active_goals_summary',
          categoryFa: 'اهداف و گام‌ها',
          titleFa: 'اهداف فعال و درصد پیشرفت',
          descriptionFa: 'لیست اهداف فعال، درصد پیشرفت و مهلت‌های تعیین‌شده را بازمی‌گرداند.',
          policy: ToolPolicy.readOnly,
        );

  @override
  Future<AgentToolResult> execute(Map<String, dynamic> args) async {
    final db = await DatabaseHelper.instance.database;

    final goals = await db.query(
      'goals',
      where: 'status != ? OR status IS NULL',
      whereArgs: ['completed'],
      orderBy: 'createdAt DESC',
    );

    final goalSteps = await db.query('goal_steps');

    final formatted = goals.map((g) {
      final id = g['id'];
      final steps = goalSteps.where((s) => s['goalId'] == id).toList();
      final doneCount = steps.where((s) => s['isCompleted'] == 1).length;
      final progressPercent = steps.isNotEmpty ? ((doneCount / steps.length) * 100).round() : 0;

      return {
        'id': id,
        'title': g['title'],
        'category': g['category'] ?? 'عمومی',
        'progressPercent': progressPercent,
        'totalSteps': steps.length,
        'completedSteps': doneCount,
      };
    }).toList();

    return AgentToolResult.success(
      toolName: name,
      data: {'goals': formatted, 'count': formatted.length},
      summaryFa: '${formatted.length} هدف فعال در پایگاه داده یافت شد.',
    );
  }
}

/// ۲. ابزار ایجاد هدف جدید
class CreateGoalWithMilestonesTool extends KernelCommandTool {
  const CreateGoalWithMilestonesTool()
      : super(
          name: 'create_goal_with_milestones',
          categoryFa: 'اهداف و گام‌ها',
          titleFa: 'ایجاد هدف جدید با گام‌ها',
          descriptionFa: 'یک هدف جدید به همراه گام‌های عملیاتی برای کاربر تعریف می‌کند.',
          commandId: 'goal.create',
          policy: ToolPolicy.actionDirect,
          parameters: const [
            ToolParameter(
              name: 'title',
              descriptionFa: 'عنوان هدف',
              type: 'string',
              isRequired: true,
            ),
            ToolParameter(
              name: 'category',
              descriptionFa: 'دسته‌بندی (شغلی، یادگیری، مالی، سلامت)',
              type: 'string',
              defaultValue: 'عمومی',
            ),
          ],
        );

  @override
  Future<List<PlanStep>> buildSteps(Map<String, dynamic> args) async {
    final title = KernelCommandTool.optionalString(args['title']);
    if (title == null || title.isEmpty) {
      throw const ToolArgumentError('عنوان هدف (title) الزامی است.');
    }
    return [
      PlanStep(
        commandId: commandId,
        payload: {
          'title': title,
          'goalType': 'HABIT',
        },
      ),
    ];
  }

  @override
  String buildSummaryFa(Map<String, dynamic> args, Map<String, dynamic> output) {
    final title = args['title'] ?? 'هدف جدید';
    return 'هدف جدید «$title» با موفقیت در سیستم ایجاد شد.';
  }
}
