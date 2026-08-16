import 'package:ritmo/core/ai/agent/agent_tool.dart';
import 'package:ritmo/core/database/database_helper.dart';

/// ۱. ابزار بررسی پیشرفت دروس و کنکور
class GetStudyProgressSummaryTool extends AgentTool {
  const GetStudyProgressSummaryTool()
      : super(
          name: 'get_study_progress_summary',
          categoryFa: 'یادگیری و کنکور',
          titleFa: 'پیشرفت دروس و مطالعه',
          descriptionFa: 'ساعات مطالعه ثبت‌شده، سرفصل‌ها و آمار تست‌های زده‌شده را بازمی‌گرداند.',
          policy: ToolPolicy.readOnly,
        );

  @override
  Future<AgentToolResult> execute(Map<String, dynamic> args) async {
    final db = await DatabaseHelper.instance.database;
    final sessions = <Map<String, dynamic>>[];

    try {
      final rows = await db.query('konkur_study_sessions', orderBy: 'timestamp DESC', limit: 20);
      sessions.addAll(rows);
    } catch (_) {}

    return AgentToolResult.success(
      toolName: name,
      data: {'sessions': sessions, 'count': sessions.length},
      summaryFa: '${sessions.length} جلسه مطالعه و تست در سوابق یافت شد.',
    );
  }
}

/// ۲. ابزار دریافت روتین‌های معنوی و عبادات
class GetWorshipRoutinesTool extends AgentTool {
  const GetWorshipRoutinesTool()
      : super(
          name: 'get_worship_routines',
          categoryFa: 'عبادات و معنویت',
          titleFa: 'اعمال و روتین‌های معنوی',
          descriptionFa: 'لیست روتین‌های عبادی و وضعیت انجام اعمال روزانه را بازمی‌گرداند.',
          policy: ToolPolicy.readOnly,
        );

  @override
  Future<AgentToolResult> execute(Map<String, dynamic> args) async {
    final db = await DatabaseHelper.instance.database;
    final items = <Map<String, dynamic>>[];

    try {
      final rows = await db.query('worship_items', limit: 20);
      items.addAll(rows);
    } catch (_) {}

    return AgentToolResult.success(
      toolName: name,
      data: {'items': items, 'count': items.length},
      summaryFa: '${items.length} آیتم عبادی در سیستم ثبت شده است.',
    );
  }
}
