import 'package:ritmo/core/ai/agent/agent_tool.dart';
import 'package:ritmo/core/ai/agent/catalog/kernel_command_tool.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/domain/commands/command_plan.dart';
import 'package:ritmo/core/logging/ritmo_logger.dart';

/// ۱. ابزار بررسی پیشرفت دروس و کنکور
///
/// فاز ۲: قبلاً خطا در `catch (_) {}` بلعیده می‌شد و لیست خالی به عنوان واقعیت
/// تحویل داده می‌شد؛ پس دستیار می‌گفت «مطالعه‌ای ثبت نکرده‌ای» در حالی که فقط
/// کوئری شکست خورده بود. (ستون timestamp هم تأییدنشده بود.)
class GetStudyProgressSummaryTool extends AgentTool {
  const GetStudyProgressSummaryTool()
      : super(
          name: 'get_study_progress_summary',
          categoryFa: 'یادگیری و کنکور',
          titleFa: 'پیشرفت دروس و مطالعه',
          descriptionFa:
              'سوابق جلسات مطالعه و تست را بازمی‌گرداند. اگر این بخش در دسترس نباشد، صریحاً خطا می‌دهد و عدد صفر جعلی نمی‌سازد.',
          policy: ToolPolicy.readOnly,
        );

  @override
  Future<AgentToolResult> execute(Map<String, dynamic> args) async {
    final db = await DatabaseHelper.instance.database;

    try {
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
        ['konkur_study_sessions'],
      );
      if (tables.isEmpty) {
        return AgentToolResult.failure(
          toolName: name,
          errorMessage:
              'جدول جلسات مطالعه در این نسخهٔ برنامه وجود ندارد. به کاربر نگو که مطالعه‌ای ثبت نکرده؛ بگو این بخش فعلاً داده‌ای برای خواندن ندارد.',
        );
      }

      // rowid در هر جدول معمولی SQLite وجود دارد؛ برخلاف timestamp که تأیید نشده بود.
      final rows = await db.rawQuery(
        'SELECT * FROM konkur_study_sessions ORDER BY rowid DESC LIMIT 20',
      );

      return AgentToolResult.success(
        toolName: name,
        data: {'sessions': rows, 'count': rows.length},
        summaryFa: rows.isEmpty
            ? 'جدول جلسات مطالعه خوانده شد و واقعاً خالی بود.'
            : '${rows.length} جلسهٔ مطالعه/تست در سوابق یافت شد.',
      );
    } catch (e, st) {
      RitmoLog.error('GetStudyProgressSummaryTool', 'study sessions query failed', e, st);
      return AgentToolResult.failure(
        toolName: name,
        errorMessage:
            'خواندن سوابق مطالعه با خطا متوقف شد، پس هیچ نتیجه‌ای قابل اعتماد نیست: $e',
      );
    }
  }
}

/// ۲. ابزار دریافت برنامه‌های عبادی، تلاوت قرآن و اعمال مستحبی
class GetWorshipPracticesTool extends AgentTool {
  const GetWorshipPracticesTool()
      : super(
          name: 'get_worship_practices',
          categoryFa: 'عبادات و معنویت',
          titleFa: 'برنامه‌های عبادی و قرآنی',
          descriptionFa:
              'لیست برنامه‌های عبادی، ختم و تلاوت روزانه قرآن، اذکار و مستحبات فعال کاربر را بازمی‌گرداند.',
          policy: ToolPolicy.readOnly,
        );

  @override
  Future<AgentToolResult> execute(Map<String, dynamic> args) async {
    final db = await DatabaseHelper.instance.database;

    try {
      final rows = await db.query(
        'worship_practices',
        where: 'isActive = 1',
        orderBy: 'sortOrder ASC, updatedAt DESC',
      );

      final formatted = rows.map((r) => {
        'id': r['id'],
        'title': r['title'],
        'type': r['practiceType'], // PRAYER, MUSTAHAB, QURAN, DHIKR
        'dailyTarget': r['dailyTarget'] ?? 1,
        'dailyDone': r['dailyDone'] ?? 0,
        'reminderTime': r['reminderTime'] ?? 'نامشخص',
        'reminderEnabled': r['reminderEnabled'] == 1,
      }).toList();

      return AgentToolResult.success(
        toolName: name,
        data: {'practices': formatted, 'count': formatted.length},
        summaryFa: formatted.isEmpty
            ? 'هیچ برنامه عبادی یا قرآنی فعالی در سیستم ثبت نشده است.'
            : '${formatted.length} برنامه عبادی/قرآنی فعال یافت شد.',
      );
    } catch (e, st) {
      RitmoLog.error('GetWorshipPracticesTool', 'worship_practices query failed', e, st);
      return AgentToolResult.failure(
        toolName: name,
        errorMessage: 'خواندن برنامه‌های عبادی با خطا مواجه شد: $e',
      );
    }
  }
}

/// ۳. ابزار ایجاد برنامه تلاوت قرآن، ذکر یا اعمال مستحبی در بخش عبادات
class CreateWorshipPracticeTool extends KernelCommandTool {
  const CreateWorshipPracticeTool()
      : super(
          name: 'create_worship_practice',
          categoryFa: 'عبادات و معنویت',
          titleFa: 'ایجاد برنامه عبادی یا تلاوت قرآن',
          descriptionFa:
              'یک برنامه اختصاصی تلاوت قرآن، اعمال مستحبی یا ذکر در بخش عبادات ریتمو ثبت می‌کند.',
          commandId: 'worship.create',
          policy: ToolPolicy.actionDirect,
          parameters: const [
            ToolParameter(
              name: 'title',
              descriptionFa: 'عنوان برنامه (مثلاً خواندن قرآن، زیارت عاشورا، دعای عهد)',
              type: 'string',
              isRequired: true,
            ),
          ],
        );

  @override
  Future<List<PlanStep>> buildSteps(Map<String, dynamic> args) async {
    final title = KernelCommandTool.optionalString(args['title']);
    if (title == null || title.isEmpty) {
      throw const ToolArgumentError('عنوان برنامه عبادی (title) الزامی است.');
    }
    return [
      PlanStep(
        commandId: commandId,
        payload: {'title': title},
      ),
    ];
  }

  @override
  String buildSummaryFa(Map<String, dynamic> args, Map<String, dynamic> output) {
    final title = args['title'] ?? 'برنامه عبادی جدید';
    return 'برنامه عبادی «$title» با موفقیت در سیستم ثبت گردید.';
  }
}
