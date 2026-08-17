import 'package:ritmo/core/ai/agent/agent_tool_registry.dart';
import 'package:ritmo/core/ai/agent/catalog/sports_agent_tools.dart';
import 'package:ritmo/core/ai/agent/catalog/routine_agent_tools.dart';
import 'package:ritmo/core/ai/agent/catalog/planning_agent_tools.dart';
import 'package:ritmo/core/ai/agent/catalog/wellbeing_agent_tools.dart';
import 'package:ritmo/core/ai/agent/catalog/goal_agent_tools.dart';
import 'package:ritmo/core/ai/agent/catalog/notes_agent_tools.dart';
import 'package:ritmo/core/ai/agent/catalog/study_worship_agent_tools.dart';
import 'package:ritmo/core/ai/agent/catalog/system_agent_tools.dart';
import 'package:ritmo/core/ai/agent/catalog/meta_agent_tools.dart';
import 'package:ritmo/core/ai/agent/catalog/memory_agent_tools.dart';

/// مقداردهی اولیه و ثبت تمامی ابزارهای سراسری برنامه در رجیستری ایجنت
///
/// وضعیت فاز ۲:
///  - سه ابزار نوشتنی‌ای که در فاز ۰ قفل شده بودند بازگشتند، این بار بدون SQL
///    مستقیم: `create_new_routine` روی فرمان routine.create و `update_app_preference`
///    روی SettingsService با allowlist. (`apply_smart_day_plan` حذف شد.)
///  - دو ابزار جدید انضباطی اضافه شد: `verify_state` (خودبازرسی بعد از نوشتن)
///    و `ask_user` (توقف و پرسیدن جای حدس زدن).
///  - `complete_routine` هم اضافه شد تا ایجنت بتواند چرخهٔ کامل روتین
///    (ساخت ← دیدن ← ثبت انجام) را پوشش دهد.
///
/// افزودهٔ فاز ۵:
///  - `remember_fact` و `recall_facts` جایگزین تگ متنی `<memory_ops>` شدند؛ ایجنت
///    حالا نوشتن در حافطه را مستقیم و قابل تأیید انجام می‌دهد.
///
/// عمدا ثبت نمی‌شود: `MaterializeDayPlanTool`. فرمانش به دامنهٔ اهداف دست
/// می‌زند و تا وقتی ماژول اهداف و چرخهٔ برنامه‌ریزی در عمل استفاده نشوند،
/// افزودنش فقط طول پرامپت را زیاد می‌کند (انضباط تعداد ابزار).
void initializeAllAgentTools() {
  final registry = AgentToolRegistry.instance;

  registry.registerAll([
    // ۱. ورزش و تحرک
    const GetSportsHistoryTool(),
    const GetSportsPlanTool(),
    const LogSportsSessionTool(),

    // ۲. روتین‌ها و عادات
    const GetRoutinesOverviewTool(),
    const GetRoutineStreakStatsTool(),
    const CreateNewRoutineTool(),
    const CompleteRoutineTool(),

    // ۳. برنامه‌ریزی روز
    const GetDayAgendaTool(),

    // ۴. خواب و انرژی
    const GetSleepDiagnosticsTool(),
    const GetEnergyTrendsTool(),
    const LogEnergyMoodLevelTool(),

    // ۵. اهداف و گام‌ها
    const GetActiveGoalsSummaryTool(),
    const CreateGoalWithMilestonesTool(),

    // ۶. یادداشت‌ها و تجارب
    const SearchUserNotesTool(),
    const CreateQuickNoteTool(),

    // ۷. یادگیری و عبادات
    const GetStudyProgressSummaryTool(),
    const GetWorshipPracticesTool(),
    const CreateWorshipPracticeTool(),

    // ۸. سیستم و ناوبری
    const NavigateToAppScreenTool(),
    const UpdateAppPreferenceTool(),
    const UndoLastActionTool(),

    // ۹. بازرسی و دقت (فاز ۲)
    const VerifyStateTool(),
    const AskUserTool(),

    // ۱۰. حافظه دستیار (فاز ۵)
    const RememberFactTool(),
    const RecallFactsTool(),
  ]);
}
