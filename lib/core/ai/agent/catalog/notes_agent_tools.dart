import 'package:ritmo/core/ai/agent/agent_tool.dart';
import 'package:ritmo/core/ai/agent/catalog/kernel_command_tool.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/domain/commands/command_plan.dart';

/// ۱. ابزار جستجوی متنی در یادداشت‌ها
class SearchUserNotesTool extends AgentTool {
  const SearchUserNotesTool()
      : super(
          name: 'search_user_notes',
          categoryFa: 'یادداشت‌ها و تجارب',
          titleFa: 'جستجوی یادداشت‌ها',
          descriptionFa: 'در عنوان، متن و برچسب‌های یادداشت‌های شخصی کاربر جستجو می‌کند.',
          policy: ToolPolicy.readOnly,
          parameters: const [
            ToolParameter(
              name: 'query',
              descriptionFa: 'کلمه یا عبارت مورد جستجو',
              type: 'string',
              isRequired: true,
            ),
          ],
        );

  @override
  Future<AgentToolResult> execute(Map<String, dynamic> args) async {
    final q = args['query']?.toString() ?? '';
    final db = await DatabaseHelper.instance.database;

    final rows = await db.rawQuery('''
      SELECT id, title, content, tags, updatedAt FROM notes
      WHERE title LIKE ? OR content LIKE ? OR tags LIKE ?
      ORDER BY updatedAt DESC LIMIT 10
    ''', ['%$q%', '%$q%', '%$q%']);

    if (rows.isEmpty) {
      return AgentToolResult.success(
        toolName: name,
        data: {'results': []},
        summaryFa: 'هیچ یادداشتی منطبق با عبارت «$q» یافت نشد.',
      );
    }

    return AgentToolResult.success(
      toolName: name,
      data: {'results': rows, 'count': rows.length},
      summaryFa: '${rows.length} یادداشت منطبق با جستجو پیدا شد.',
    );
  }
}

/// ۲. ابزار ایجاد یادداشت سریع
class CreateQuickNoteTool extends KernelCommandTool {
  const CreateQuickNoteTool()
      : super(
          name: 'create_quick_note',
          categoryFa: 'یادداشت‌ها و تجارب',
          titleFa: 'ثبت یادداشت سریع',
          descriptionFa: 'یک یادداشت جدید در دفترچه یادداشت‌های کاربر ذخیره می‌کند.',
          commandId: 'note.create',
          policy: ToolPolicy.actionDirect,
          parameters: const [
            ToolParameter(
              name: 'title',
              descriptionFa: 'عنوان یادداشت',
              type: 'string',
              isRequired: true,
            ),
            ToolParameter(
              name: 'content',
              descriptionFa: 'متن یادداشت',
              type: 'string',
              isRequired: true,
            ),
            ToolParameter(
              name: 'tags',
              descriptionFa: 'برچسب‌ها (جدا شده با کاما)',
              type: 'string',
            ),
          ],
        );

  @override
  Future<List<PlanStep>> buildSteps(Map<String, dynamic> args) async {
    final title = KernelCommandTool.optionalString(args['title']);
    final content = KernelCommandTool.optionalString(args['content']);
    if (content == null || content.isEmpty) {
      throw const ToolArgumentError('متن یادداشت (content) الزامی است.');
    }
    final tagsStr = KernelCommandTool.optionalString(args['tags']);
    final tagsList = tagsStr != null && tagsStr.isNotEmpty
        ? tagsStr.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList()
        : <String>[];

    return [
      PlanStep(
        commandId: commandId,
        payload: {
          'title': title ?? 'یادداشت جدید',
          'body': content,
          'kind': 'NOTE',
          if (tagsList.isNotEmpty) 'tags': tagsList,
        },
      ),
    ];
  }

  @override
  String buildSummaryFa(Map<String, dynamic> args, Map<String, dynamic> output) {
    final title = args['title'] ?? 'یادداشت جدید';
    return 'یادداشت «$title» با موفقیت در سیستم ذخیره گردید.';
  }
}
