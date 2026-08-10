import 'package:ritmo/core/domain/commands/ritmo_command_bus.dart';
import 'package:ritmo/core/domain/commands/catalog/app_commands.dart';
import 'package:ritmo/core/domain/commands/catalog/routine_commands.dart';
import 'package:ritmo/core/domain/commands/catalog/goal_commands.dart';
import 'package:ritmo/core/domain/commands/catalog/study_commands.dart';
import 'package:ritmo/core/domain/commands/catalog/worship_commands.dart';
import 'package:ritmo/core/domain/commands/catalog/wellbeing_commands.dart';
import 'package:ritmo/core/domain/commands/catalog/sports_commands.dart';
import 'package:ritmo/core/domain/commands/catalog/planning_commands.dart';
import 'package:ritmo/core/domain/commands/catalog/notes_commands.dart';

void registerAllRitmoCommands() {
  RitmoCommandBus.instance.registerAll([
    // App & System commands
    const AppOpenPageCommand(),
    const AssistantHandoffCommand(),
    const AssistantUndoLastCommand(),

    // Routine commands
    const RoutineCreateCommand(),
    const RoutineCreateFromPhraseCommand(),
    const RoutineEditCommand(),
    const RoutineArchiveCommand(),
    const RoutineDeleteCommand(),
    const RoutineCompleteCommand(),
    const RoutineSkipCommand(),
    const RoutineSnoozeCommand(),
    const RoutineRescheduleCommand(),
    const RoutineSetReminderOffsetCommand(),
    const RoutineSetEssentialCommand(),
    const RoutineSetPrivateCommand(),
    const RoutineBulkRescheduleCommand(),

    // Goal commands
    const GoalCreateCommand(),
    const GoalEditCommand(),
    const GoalCompleteStepCommand(),

    // Planning commands (Prompt 072)
    const PlanningApplyWeekCommand(),
    const PlanningCreateCycleCommand(),
    const PlanningCloseCycleCommand(),
    const PlanningAddCommitmentCommand(),
    const PlanningDropCommitmentCommand(),
    const PlanningMoveAllocationCommand(),
    const PlanningSplitCommitmentCommand(),
    const PlanningLockAllocationCommand(),
    const PlanningSetDayLightCommand(),
    const PlanningMaterializeDayCommand(),

    // Study commands
    const CourseCreateCommand(),
    const KonkurCreateTopicCommand(),

    // Worship commands
    const WorshipCreateCommand(),
    const WorshipDeleteCommand(),

    // Wellbeing commands
    const SleepLogCommand(),
    const EnergyLogCommand(),
    const ReflectionLogCommand(),
    const SettingUpdateCommand(),

    // Sports & Movement commands
    const SportsMarkDoneCommand(),
    const SportsSkipSessionCommand(),
    const SportsMoveSessionCommand(),
    const SportsLogCustomMovementCommand(),
    const SportsSetDaysPerWeekCommand(),
    const SportsLockDayCommand(),
    const SportsUnlockDayCommand(),
    const SportsApplyDeloadCommand(),
    const SportsRegenerateWeekCommand(),
    const SportsSwapExerciseCommand(),

    // Notes & Experience commands (Prompt 071)
    const NoteCreateCommand(),
    const NoteAppendCommand(),
    const NoteEditCommand(),
    const NoteRetitleCommand(),
    const NoteTagCommand(),
    const NoteUntagCommand(),
    const NoteLinkCommand(),
    const NoteUnlinkCommand(),
    const NotePinCommand(),
    const NoteUnpinCommand(),
    const NoteArchiveCommand(),
    const NoteRestoreCommand(),
    const NoteDeleteCommand(),
    const NoteScheduleReviewCommand(),
    const NoteExtractActionsCommand(),
    const NoteSummarizeCommand(),
    const NotesSearchCommand(),
    const NotesDailyNoteCommand(),
    const ExperienceCreateCommand(),
    const ExperienceEditCommand(),
    const ExperienceSetActiveCommand(),
    const ExperienceSetImportanceCommand(),
  ]);
}
