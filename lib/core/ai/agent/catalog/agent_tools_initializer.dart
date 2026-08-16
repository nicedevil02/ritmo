import 'package:ritmo/core/ai/agent/agent_tool_registry.dart';
import 'package:ritmo/core/ai/agent/catalog/sports_agent_tools.dart';
import 'package:ritmo/core/ai/agent/catalog/routine_agent_tools.dart';
import 'package:ritmo/core/ai/agent/catalog/planning_agent_tools.dart';
import 'package:ritmo/core/ai/agent/catalog/wellbeing_agent_tools.dart';
import 'package:ritmo/core/ai/agent/catalog/goal_agent_tools.dart';
import 'package:ritmo/core/ai/agent/catalog/notes_agent_tools.dart';
import 'package:ritmo/core/ai/agent/catalog/study_worship_agent_tools.dart';
import 'package:ritmo/core/ai/agent/catalog/system_agent_tools.dart';

/// مقداردهی اولیه و ثبت تمامی ابزارهای سراسری برنامه در رجیستری ایجنت
///
/// فاز ۰: سه ابزار نوشتنی زیر عمداً ثبت نمی‌شوند چون داده را خراب می‌کردند یا
/// موفقیت جعلی گزارش می‌دادند. مدل چیزی را که نبیند نمی‌تواند فراخوانی کند،
/// پس حذف از رجیستری مطمئن‌ترین قفل است:
///   - CreateNewRoutineTool  : ستون‌های ناموجود + عدم ساخت schedule/occurrences
///   - ApplySmartDayPlanTool : جدول assistant_plans وجود ندارد و خطا بلعیده می‌شد
///   - UpdateAppPreferenceTool: بدون allowlist و دور زدن SettingsService (خطر تغییر module_*)
/// فاز ۲ هر سه را به شکل آداپتور روی RitmoCommandBus بازمی‌گرداند.
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
    const GetWorshipRoutinesTool(),

    // ۸. سیستم و ناوبری
    const NavigateToAppScreenTool(),
  ]);
}
