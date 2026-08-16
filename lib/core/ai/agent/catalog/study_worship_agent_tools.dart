import 'package:ritmo/core/ai/agent/agent_tool.dart';
import 'package:ritmo/core/database/database_helper.dart';
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

/// ۲. ابزار دریافت روتین‌های معنوی و عبادات
///
/// همان اصلاح: وجود جدول بررسی می‌شود و خطا بلعیده نمی‌شود.
class GetWorshipRoutinesTool extends AgentTool {
  const GetWorshipRoutinesTool()
      : super(
          name: 'get_worship_routines',
          categoryFa: 'عبادات و معنویت',
          titleFa: 'اعمال و روتین‌های معنوی',
          descriptionFa:
              'لیست آیتم‌های عبادی ثبت‌شده را بازمی‌گرداند. اگر این بخش در دسترس نباشد، صریحاً خطا می‌دهد.',
          policy: ToolPolicy.readOnly,
        );

  @override
  Future<AgentToolResult> execute(Map<String, dynamic> args) async {
    final db = await DatabaseHelper.instance.database;

    try {
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
        ['worship_items'],
      );
      if (tables.isEmpty) {
        return AgentToolResult.failure(
          toolName: name,
          errorMessage:
              'جدول آیتم‌های عبادی در این نسخهٔ برنامه وجود ندارد، پس وضعیت عبادات را از این مسیر نمی‌توان خواند. به جایش از ابزار برنامهٔ روز یا مرور روتین‌ها استفاده کن.',
        );
      }

      final rows = await db.rawQuery(
        'SELECT * FROM worship_items ORDER BY rowid DESC LIMIT 20',
      );

      return AgentToolResult.success(
        toolName: name,
        data: {'items': rows, 'count': rows.length},
        summaryFa: rows.isEmpty
            ? 'جدول آیتم‌های عبادی خوانده شد و واقعاً خالی بود.'
            : '${rows.length} آیتم عبادی ثبت شده است.',
      );
    } catch (e, st) {
      RitmoLog.error('GetWorshipRoutinesTool', 'worship_items query failed', e, st);
      return AgentToolResult.failure(
        toolName: name,
        errorMessage:
            'خواندن آیتم‌های عبادی با خطا متوقف شد: $e',
      );
    }
  }
}
