import 'package:ritmo/core/ai/agent/agent_tool.dart';
import 'package:ritmo/core/database/database_helper.dart';

/// ۱. ابزار هدایت کاربر به صفحات مختلف اپلیکیشن
class NavigateToAppScreenTool extends AgentTool {
  const NavigateToAppScreenTool()
      : super(
          name: 'navigate_to_app_screen',
          categoryFa: 'سیستم و ناوبری',
          titleFa: 'هدایت به بخش‌های اپلیکیشن',
          descriptionFa: 'کاربر را مستقیماً به صفحه مورد نظر در برنامه (ورزش، تقویم، تنظیمات، خواب، اهداف و...) هدایت می‌کند.',
          policy: ToolPolicy.actionDirect,
          parameters: const [
            ToolParameter(
              name: 'route',
              descriptionFa: 'مسیر یا شناسه صفحه (sports, calendar, settings, sleep, goals, notes, routine)',
              type: 'string',
              isRequired: true,
              allowedValues: ['sports', 'calendar', 'settings', 'sleep', 'goals', 'notes', 'routine', 'energy'],
            ),
          ],
        );

  @override
  Future<AgentToolResult> execute(Map<String, dynamic> args) async {
    final route = args['route']?.toString() ?? 'calendar';
    return AgentToolResult.success(
      toolName: name,
      data: {'targetRoute': route, 'action': 'navigate'},
      summaryFa: 'دستور هدایت به بخش «$route» صادر شد.',
    );
  }
}

/// ۲. ابزار تغییر تنظیمات کاربری
class UpdateAppPreferenceTool extends AgentTool {
  const UpdateAppPreferenceTool()
      : super(
          name: 'update_app_preference',
          categoryFa: 'سیستم و ناوبری',
          titleFa: 'تغییر تنظیمات برنامه',
          descriptionFa: 'یک متغیر یا ترجیح کاربری در تنظیمات برنامه را به‌روزرسانی می‌کند.',
          policy: ToolPolicy.actionDirect,
          parameters: const [
            ToolParameter(
              name: 'key',
              descriptionFa: 'کلید تنظیمات (مثلاً user_name, assistant_briefing_enabled)',
              type: 'string',
              isRequired: true,
            ),
            ToolParameter(
              name: 'value',
              descriptionFa: 'مقدار جدید',
              type: 'string',
              isRequired: true,
            ),
          ],
        );

  @override
  Future<AgentToolResult> execute(Map<String, dynamic> args) async {
    final key = args['key']?.toString() ?? '';
    final value = args['value']?.toString() ?? '';

    final db = await DatabaseHelper.instance.database;

    await db.insert('app_settings', {
      'key': key,
      'value': value,
    });

    return AgentToolResult.success(
      toolName: name,
      data: {'key': key, 'value': value},
      summaryFa: 'تنظیمات «$key» با موفقیت به مقدار جدید تغییر یافت.',
    );
  }
}
