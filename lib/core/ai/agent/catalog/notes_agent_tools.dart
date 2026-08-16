import 'package:ritmo/core/ai/agent/agent_tool.dart';
import 'package:ritmo/core/database/database_helper.dart';

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
class CreateQuickNoteTool extends AgentTool {
  const CreateQuickNoteTool()
      : super(
          name: 'create_quick_note',
          categoryFa: 'یادداشت‌ها و تجارب',
          titleFa: 'ثبت یادداشت سریع',
          descriptionFa: 'یک یادداشت جدید در دفترچه یادداشت‌های کاربر ذخیره می‌کند.',
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
  Future<AgentToolResult> execute(Map<String, dynamic> args) async {
    final title = args['title']?.toString() ?? 'یادداشت جدید';
    final content = args['content']?.toString() ?? '';
    final tags = args['tags']?.toString() ?? '';

    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = 'note_${now}';

    await db.insert('notes', {
      'id': id,
      'title': title,
      'content': content,
      'tags': tags,
      'createdAt': now,
      'updatedAt': now,
    });

    return AgentToolResult.success(
      toolName: name,
      data: {'id': id, 'title': title},
      summaryFa: 'یادداشت «$title» با موفقیت در سیستم ذخیره گردید.',
    );
  }
}
