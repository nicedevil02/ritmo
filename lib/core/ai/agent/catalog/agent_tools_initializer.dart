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

    // ۳. برنامه‌ریزی روز
    const GetDayAgendaTool(),
    const ApplySmartDayPlanTool(),

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
    const UpdateAppPreferenceTool(),
  ]);
}
