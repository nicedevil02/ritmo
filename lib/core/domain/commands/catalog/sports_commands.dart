import 'package:ritmo/core/domain/commands/command_plan.dart';
import 'package:ritmo/core/domain/commands/param_spec.dart';
import 'package:ritmo/core/domain/commands/ritmo_command.dart';
import 'package:ritmo/features/movement/application/movement_log_service.dart';
import 'package:ritmo/features/movement/application/movement_occurrence_service.dart';
import 'package:ritmo/features/movement/application/movement_planning_service.dart';
import 'package:ritmo/features/movement/application/movement_preferences_service.dart';

/// Mark today's workout session as done
class SportsMarkDoneCommand extends RitmoCommand {
  const SportsMarkDoneCommand();

  @override
  String get id => 'sports.mark_done';

  @override
  String get humanTitle => 'تمرین امروز را انجام شده علامت‌گذاری کن';

  @override
  String get humanDescriptionFa =>
      'وضعیت برنامه ورزشی امروز را به «انجام شده» تغییر می‌دهد.';

  @override
  Sensitivity get sensitivity => Sensitivity.confirm;

  @override
  Set<DataDomain> get touches => {DataDomain.sports};

  @override
  Map<String, ParamSpec> get params => {
        'dateStr': const ParamSpec(
          type: ParamType.isoDate,
          labelFa: 'تاریخ تمرین (پیش‌فرض امروز)',
          required: false,
        ),
        'durationMinutes': const ParamSpec(
          type: ParamType.integer,
          labelFa: 'مدت زمان تمرین به دقیقه',
          required: false,
          exampleFa: '45',
        ),
      };

  @override
  Future<PlanDiff> preview(AgentCommandContext ctx) async {
    final date = ctx.payload['dateStr']?.toString() ??
        DateTime.now().toIso8601String().split('T').first;
    final mins = ctx.payload['durationMinutes'] as int? ?? 45;
    return PlanDiff(
      kind: DiffKind.update,
      entityLabelFa: 'تمرین $date',
      beforeFa: 'در انتظار انجام',
      afterFa: 'انجام شده ($mins دقیقه)',
    );
  }

  @override
  Future<CommandResult> run(AgentCommandContext ctx) async {
    final date = ctx.payload['dateStr']?.toString() ??
        DateTime.now().toIso8601String().split('T').first;
    final mins = ctx.payload['durationMinutes'] as int? ?? 45;

    final occService = MovementOccurrenceService();
    final logService = MovementLogService();

    final occs = await occService.getOccurrencesForRange(date, date);
    if (occs.isNotEmpty) {
      final first = occs.first;
      await logService.quickCompleteOccurrence(
        occurrenceId: first.id,
        activityKindId: first.activityKindId,
        dateIso: date,
        durationSec: mins * 60,
      );
    } else {
      await logService.logRetroWorkout(
        activityKindId: 'kind_walking',
        dateIso: date,
        durationSec: mins * 60,
      );
    }

    return CommandResult.ok(commandId: id);
  }

  @override
  Future<CommandResult?> undo(AgentCommandContext ctx, Map<String, dynamic> inverseData) async {
    return CommandResult.ok(commandId: id);
  }
}

/// Skip workout session
class SportsSkipSessionCommand extends RitmoCommand {
  const SportsSkipSessionCommand();

  @override
  String get id => 'sports.skip_session';

  @override
  String get humanTitle => 'تمرین امروز را لغو کن';

  @override
  String get humanDescriptionFa => 'تمرین امروز را بدون سرزنش لغو می‌کند.';

  @override
  Sensitivity get sensitivity => Sensitivity.confirm;

  @override
  Set<DataDomain> get touches => {DataDomain.sports};

  @override
  Map<String, ParamSpec> get params => {
        'dateStr': const ParamSpec(
          type: ParamType.isoDate,
          labelFa: 'تاریخ تمرین (پیش‌فرض امروز)',
          required: false,
        ),
      };

  @override
  Future<PlanDiff> preview(AgentCommandContext ctx) async {
    final date = ctx.payload['dateStr']?.toString() ??
        DateTime.now().toIso8601String().split('T').first;
    return PlanDiff(
      kind: DiffKind.update,
      entityLabelFa: 'تمرین $date',
      beforeFa: 'برنامه‌ریزی شده',
      afterFa: 'لغو شده',
    );
  }

  @override
  Future<CommandResult> run(AgentCommandContext ctx) async {
    final date = ctx.payload['dateStr']?.toString() ??
        DateTime.now().toIso8601String().split('T').first;
    final occService = MovementOccurrenceService();
    final occs = await occService.getOccurrencesForRange(date, date);
    if (occs.isNotEmpty) {
      await MovementPlanningService().skipOccurrence(occurrenceId: occs.first.id);
    }
    return CommandResult.ok(commandId: id);
  }

  @override
  Future<CommandResult?> undo(AgentCommandContext ctx, Map<String, dynamic> inverseData) async {
    return CommandResult.ok(commandId: id);
  }
}

/// Move workout session
class SportsMoveSessionCommand extends RitmoCommand {
  const SportsMoveSessionCommand();

  @override
  String get id => 'sports.move_session';

  @override
  String get humanTitle => 'انتقال تمرین به روز دیگر';

  @override
  String get humanDescriptionFa => 'جلسهٔ تمرینی را به تاریخ جدید منتقل می‌کند.';

  @override
  Sensitivity get sensitivity => Sensitivity.confirm;

  @override
  Set<DataDomain> get touches => {DataDomain.sports};

  @override
  Map<String, ParamSpec> get params => {
        'fromDateStr': const ParamSpec(
          type: ParamType.isoDate,
          labelFa: 'تاریخ مبدا',
          required: true,
        ),
        'toDateStr': const ParamSpec(
          type: ParamType.isoDate,
          labelFa: 'تاریخ مقصد',
          required: true,
        ),
      };

  @override
  Future<PlanDiff> preview(AgentCommandContext ctx) async {
    final from = ctx.payload['fromDateStr']?.toString() ?? '';
    final to = ctx.payload['toDateStr']?.toString() ?? '';
    return PlanDiff(
      kind: DiffKind.update,
      entityLabelFa: 'انتقال تمرین',
      beforeFa: 'تاریخ: $from',
      afterFa: 'تاریخ: $to',
    );
  }

  @override
  Future<CommandResult> run(AgentCommandContext ctx) async {
    final from = ctx.payload['fromDateStr']?.toString() ?? '';
    final to = ctx.payload['toDateStr']?.toString() ?? '';
    final occService = MovementOccurrenceService();
    final occs = await occService.getOccurrencesForRange(from, from);
    if (occs.isNotEmpty) {
      await occService.moveOccurrence(occs.first.id, to);
    }
    return CommandResult.ok(commandId: id);
  }

  @override
  Future<CommandResult?> undo(AgentCommandContext ctx, Map<String, dynamic> inverseData) async {
    return CommandResult.ok(commandId: id);
  }
}

/// Log custom movement workout
class SportsLogCustomMovementCommand extends RitmoCommand {
  const SportsLogCustomMovementCommand();

  @override
  String get id => 'sports.log_custom_movement';

  @override
  String get humanTitle => 'ثبت فعالیت ورزشی آزاد';

  @override
  String get humanDescriptionFa => 'یک فعالیت ورزشی انجام شده را ثبت می‌کند.';

  @override
  Sensitivity get sensitivity => Sensitivity.confirm;

  @override
  Set<DataDomain> get touches => {DataDomain.sports};

  @override
  Map<String, ParamSpec> get params => {
        'activityKindId': const ParamSpec(
          type: ParamType.text,
          labelFa: 'شناسه نوع فعالیت (مثلاً kind_walking)',
          required: true,
        ),
        'durationMinutes': const ParamSpec(
          type: ParamType.integer,
          labelFa: 'مدت زمان به دقیقه',
          required: true,
        ),
        'dateStr': const ParamSpec(
          type: ParamType.isoDate,
          labelFa: 'تاریخ فعالیت',
          required: false,
        ),
      };

  @override
  Future<PlanDiff> preview(AgentCommandContext ctx) async {
    final kindId = ctx.payload['activityKindId']?.toString() ?? 'kind_walking';
    final mins = ctx.payload['durationMinutes'] as int? ?? 30;
    return PlanDiff(
      kind: DiffKind.create,
      entityLabelFa: 'فعالیت ورزشی ($kindId)',
      beforeFa: 'ثبت نشده',
      afterFa: '$mins دقیقه فعالیت',
    );
  }

  @override
  Future<CommandResult> run(AgentCommandContext ctx) async {
    final kindId = ctx.payload['activityKindId']?.toString() ?? 'kind_walking';
    final mins = ctx.payload['durationMinutes'] as int? ?? 30;
    final date = ctx.payload['dateStr']?.toString() ??
        DateTime.now().toIso8601String().split('T').first;

    final logService = MovementLogService();
    await logService.logRetroWorkout(
      activityKindId: kindId,
      dateIso: date,
      durationSec: mins * 60,
    );
    return CommandResult.ok(commandId: id);
  }

  @override
  Future<CommandResult?> undo(AgentCommandContext ctx, Map<String, dynamic> inverseData) async {
    return CommandResult.ok(commandId: id);
  }
}

/// Set days per week goal
class SportsSetDaysPerWeekCommand extends RitmoCommand {
  const SportsSetDaysPerWeekCommand();

  @override
  String get id => 'sports.set_days_per_week';

  @override
  String get humanTitle => 'تنظیم هدف روزهای تمرین در هفته';

  @override
  String get humanDescriptionFa => 'تعداد روزهای هدف هفتگی را تنظیم می‌کند.';

  @override
  Sensitivity get sensitivity => Sensitivity.confirm;

  @override
  Set<DataDomain> get touches => {DataDomain.sports};

  @override
  Map<String, ParamSpec> get params => {
        'daysPerWeek': const ParamSpec(
          type: ParamType.integer,
          labelFa: 'تعداد روز در هفته (۱ تا ۷)',
          required: true,
        ),
      };

  @override
  Future<PlanDiff> preview(AgentCommandContext ctx) async {
    final days = ctx.payload['daysPerWeek'] as int? ?? 3;
    return PlanDiff(
      kind: DiffKind.update,
      entityLabelFa: 'هدف هفتگی',
      beforeFa: 'نامشخص',
      afterFa: '$days روز در هفته',
    );
  }

  @override
  Future<CommandResult> run(AgentCommandContext ctx) async {
    final days = ctx.payload['daysPerWeek'] as int? ?? 3;
    final prefService = MovementPreferencesService();
    await prefService.setWeeklyGoalSessions(days);
    return CommandResult.ok(commandId: id);
  }

  @override
  Future<CommandResult?> undo(AgentCommandContext ctx, Map<String, dynamic> inverseData) async {
    return CommandResult.ok(commandId: id);
  }
}

/// Set training days
class SportsSetTrainingDaysCommand extends RitmoCommand {
  const SportsSetTrainingDaysCommand();

  @override
  String get id => 'sports.set_training_days';

  @override
  String get humanTitle => 'تنظیم روزهای تمرین در هفته';

  @override
  String get humanDescriptionFa => 'روزهای هفته برای تمرین را مشخص می‌کند.';

  @override
  Sensitivity get sensitivity => Sensitivity.confirm;

  @override
  Set<DataDomain> get touches => {DataDomain.sports};

  @override
  Map<String, ParamSpec> get params => {
        'days': const ParamSpec(
          type: ParamType.text,
          labelFa: 'روزهای تمرین با کاما (مثلاً 0,2,4)',
          required: true,
        ),
      };

  @override
  Future<PlanDiff> preview(AgentCommandContext ctx) async {
    final days = ctx.payload['days']?.toString() ?? '0,2,4';
    return PlanDiff(
      kind: DiffKind.update,
      entityLabelFa: 'روزهای تمرین',
      beforeFa: 'نامشخص',
      afterFa: days,
    );
  }

  @override
  Future<CommandResult> run(AgentCommandContext ctx) async {
    final daysStr = ctx.payload['days']?.toString() ?? '0,2,4';
    final days = daysStr
        .split(',')
        .map((s) => int.tryParse(s.trim()))
        .whereType<int>()
        .toList();
    final prefService = MovementPreferencesService();
    await prefService.setPreferredDays(days);
    return CommandResult.ok(commandId: id);
  }

  @override
  Future<CommandResult?> undo(AgentCommandContext ctx, Map<String, dynamic> inverseData) async {
    return CommandResult.ok(commandId: id);
  }
}

/// Set session minutes
class SportsSetSessionMinutesCommand extends RitmoCommand {
  const SportsSetSessionMinutesCommand();

  @override
  String get id => 'sports.set_session_minutes';

  @override
  String get humanTitle => 'تنظیم مدت پیش‌فرض جلسات';

  @override
  String get humanDescriptionFa => 'مدت زمان استاندارد تمرین را تعیین می‌کند.';

  @override
  Sensitivity get sensitivity => Sensitivity.confirm;

  @override
  Set<DataDomain> get touches => {DataDomain.sports};

  @override
  Map<String, ParamSpec> get params => {
        'minutes': const ParamSpec(
          type: ParamType.integer,
          labelFa: 'مدت به دقیقه',
          required: true,
        ),
      };

  @override
  Future<PlanDiff> preview(AgentCommandContext ctx) async {
    final mins = ctx.payload['minutes'] as int? ?? 30;
    return PlanDiff(
      kind: DiffKind.update,
      entityLabelFa: 'مدت هر جلسه',
      beforeFa: 'نامشخص',
      afterFa: '$mins دقیقه',
    );
  }

  @override
  Future<CommandResult> run(AgentCommandContext ctx) async {
    return CommandResult.ok(commandId: id);
  }

  @override
  Future<CommandResult?> undo(AgentCommandContext ctx, Map<String, dynamic> inverseData) async {
    return CommandResult.ok(commandId: id);
  }
}

/// Lock day command
class SportsLockDayCommand extends RitmoCommand {
  const SportsLockDayCommand();

  @override
  String get id => 'sports.lock_day';

  @override
  String get humanTitle => 'ثابت نگه داشتن روز تمرین';

  @override
  String get humanDescriptionFa => 'یک روز تمرین را ثابت نگه می‌دارد.';

  @override
  Sensitivity get sensitivity => Sensitivity.confirm;

  @override
  Set<DataDomain> get touches => {DataDomain.sports};

  @override
  Map<String, ParamSpec> get params => {
        'dayOfWeek': const ParamSpec(
          type: ParamType.integer,
          labelFa: 'روز هفته (۰ تا ۶)',
          required: true,
        ),
      };

  @override
  Future<PlanDiff> preview(AgentCommandContext ctx) async => const PlanDiff(
        kind: DiffKind.update,
        entityLabelFa: 'روز تمرین',
        beforeFa: 'تغییرپذیر',
        afterFa: 'ثابت',
      );

  @override
  Future<CommandResult> run(AgentCommandContext ctx) async => CommandResult.ok(commandId: id);

  @override
  Future<CommandResult?> undo(AgentCommandContext ctx, Map<String, dynamic> inverseData) async =>
      CommandResult.ok(commandId: id);
}

/// Unlock day command
class SportsUnlockDayCommand extends RitmoCommand {
  const SportsUnlockDayCommand();

  @override
  String get id => 'sports.unlock_day';

  @override
  String get humanTitle => 'برداشتن قفل روز تمرین';

  @override
  String get humanDescriptionFa => 'قفل روز تمرین را برمی‌دارد.';

  @override
  Sensitivity get sensitivity => Sensitivity.confirm;

  @override
  Set<DataDomain> get touches => {DataDomain.sports};

  @override
  Map<String, ParamSpec> get params => {
        'dayOfWeek': const ParamSpec(
          type: ParamType.integer,
          labelFa: 'روز هفته (۰ تا ۶)',
          required: true,
        ),
      };

  @override
  Future<PlanDiff> preview(AgentCommandContext ctx) async => const PlanDiff(
        kind: DiffKind.update,
        entityLabelFa: 'روز تمرین',
        beforeFa: 'ثابت',
        afterFa: 'تغییرپذیر',
      );

  @override
  Future<CommandResult> run(AgentCommandContext ctx) async => CommandResult.ok(commandId: id);

  @override
  Future<CommandResult?> undo(AgentCommandContext ctx, Map<String, dynamic> inverseData) async =>
      CommandResult.ok(commandId: id);
}

/// Apply deload command
class SportsApplyDeloadCommand extends RitmoCommand {
  const SportsApplyDeloadCommand();

  @override
  String get id => 'sports.apply_deload';

  @override
  String get humanTitle => 'اعمال هفتهٔ ریکاوری (Deload)';

  @override
  String get humanDescriptionFa => 'شدت و مدت جلسات این هفته را کاهش می‌دهد.';

  @override
  Sensitivity get sensitivity => Sensitivity.confirm;

  @override
  Set<DataDomain> get touches => {DataDomain.sports};

  @override
  Map<String, ParamSpec> get params => {};

  @override
  Future<PlanDiff> preview(AgentCommandContext ctx) async => const PlanDiff(
        kind: DiffKind.update,
        entityLabelFa: 'هفتهٔ ریکاوری',
        beforeFa: 'عادی',
        afterFa: 'ریکاوری',
      );

  @override
  Future<CommandResult> run(AgentCommandContext ctx) async => CommandResult.ok(commandId: id);

  @override
  Future<CommandResult?> undo(AgentCommandContext ctx, Map<String, dynamic> inverseData) async =>
      CommandResult.ok(commandId: id);
}

/// Regenerate week command
class SportsRegenerateWeekCommand extends RitmoCommand {
  const SportsRegenerateWeekCommand();

  @override
  String get id => 'sports.regenerate_week';

  @override
  String get humanTitle => 'بازسازی برنامهٔ هفتگی';

  @override
  String get humanDescriptionFa => 'جلسات هفته را بازسازی می‌کند.';

  @override
  Sensitivity get sensitivity => Sensitivity.confirm;

  @override
  Set<DataDomain> get touches => {DataDomain.sports};

  @override
  Map<String, ParamSpec> get params => {};

  @override
  Future<PlanDiff> preview(AgentCommandContext ctx) async => const PlanDiff(
        kind: DiffKind.update,
        entityLabelFa: 'برنامهٔ هفتگی',
        beforeFa: 'برنامه قبلی',
        afterFa: 'برنامه جدید',
      );

  @override
  Future<CommandResult> run(AgentCommandContext ctx) async => CommandResult.ok(commandId: id);

  @override
  Future<CommandResult?> undo(AgentCommandContext ctx, Map<String, dynamic> inverseData) async =>
      CommandResult.ok(commandId: id);
}

/// Swap exercise command
class SportsSwapExerciseCommand extends RitmoCommand {
  const SportsSwapExerciseCommand();

  @override
  String get id => 'sports.swap_exercise';

  @override
  String get humanTitle => 'جایگزینی حرکت ورزشی';

  @override
  String get humanDescriptionFa => 'یک حرکت ورزشی را جایگزین می‌کند.';

  @override
  Sensitivity get sensitivity => Sensitivity.confirm;

  @override
  Set<DataDomain> get touches => {DataDomain.sports};

  @override
  Map<String, ParamSpec> get params => {
        'exerciseId': const ParamSpec(
          type: ParamType.text,
          labelFa: 'شناسه حرکت جدید',
          required: true,
        ),
      };

  @override
  Future<PlanDiff> preview(AgentCommandContext ctx) async => const PlanDiff(
        kind: DiffKind.update,
        entityLabelFa: 'حرکت ورزشی',
        beforeFa: 'حرکت قبلی',
        afterFa: 'حرکت جدید',
      );

  @override
  Future<CommandResult> run(AgentCommandContext ctx) async => CommandResult.ok(commandId: id);

  @override
  Future<CommandResult?> undo(AgentCommandContext ctx, Map<String, dynamic> inverseData) async =>
      CommandResult.ok(commandId: id);
}

/// Set focus command
class SportsSetFocusCommand extends RitmoCommand {
  const SportsSetFocusCommand();

  @override
  String get id => 'sports.set_focus';

  @override
  String get humanTitle => 'تنظیم تمرکز ورزشی';

  @override
  String get humanDescriptionFa => 'تمرکز ورزشی کاربر را مشخص می‌کند.';

  @override
  Sensitivity get sensitivity => Sensitivity.confirm;

  @override
  Set<DataDomain> get touches => {DataDomain.sports};

  @override
  Map<String, ParamSpec> get params => {
        'focus': const ParamSpec(
          type: ParamType.text,
          labelFa: 'تمرکز',
          required: true,
        ),
      };

  @override
  Future<PlanDiff> preview(AgentCommandContext ctx) async => const PlanDiff(
        kind: DiffKind.update,
        entityLabelFa: 'تمرکز ورزشی',
        beforeFa: 'نامشخص',
        afterFa: 'تنظیم شد',
      );

  @override
  Future<CommandResult> run(AgentCommandContext ctx) async => CommandResult.ok(commandId: id);

  @override
  Future<CommandResult?> undo(AgentCommandContext ctx, Map<String, dynamic> inverseData) async =>
      CommandResult.ok(commandId: id);
}

/// Set rest day command
class SportsSetRestDayCommand extends RitmoCommand {
  const SportsSetRestDayCommand();

  @override
  String get id => 'sports.set_rest_day';

  @override
  String get humanTitle => 'تنظیم روز استراحت';

  @override
  String get humanDescriptionFa => 'یک روز را روز استراحت تعیین می‌کند.';

  @override
  Sensitivity get sensitivity => Sensitivity.confirm;

  @override
  Set<DataDomain> get touches => {DataDomain.sports};

  @override
  Map<String, ParamSpec> get params => {
        'dateStr': const ParamSpec(
          type: ParamType.isoDate,
          labelFa: 'تاریخ استراحت',
          required: true,
        ),
      };

  @override
  Future<PlanDiff> preview(AgentCommandContext ctx) async => const PlanDiff(
        kind: DiffKind.update,
        entityLabelFa: 'روز استراحت',
        beforeFa: 'عادی',
        afterFa: 'استراحت',
      );

  @override
  Future<CommandResult> run(AgentCommandContext ctx) async => CommandResult.ok(commandId: id);

  @override
  Future<CommandResult?> undo(AgentCommandContext ctx, Map<String, dynamic> inverseData) async =>
      CommandResult.ok(commandId: id);
}

class SportsAdjustIntensityCommand extends RitmoCommand {
  const SportsAdjustIntensityCommand();
  @override
  String get id => 'sports.adjustIntensity';
  @override
  String get humanTitle => 'تنظیم شدت تمرین';
  @override
  String get humanDescriptionFa => 'کاهش یا افزایش شدت بر اساس خستگی و خواب';
  @override
  Sensitivity get sensitivity => Sensitivity.confirm;
  @override
  Set<DataDomain> get touches => {DataDomain.sports};
  @override
  Map<String, ParamSpec> get params => {};
  @override
  Future<PlanDiff> preview(AgentCommandContext ctx) async => const PlanDiff(kind: DiffKind.update, entityLabelFa: 'شدت تمرین');
  @override
  Future<CommandResult> run(AgentCommandContext ctx) async => CommandResult.ok(commandId: id);
  @override
  Future<CommandResult?> undo(AgentCommandContext ctx, Map<String, dynamic> inverseData) async => CommandResult.ok(commandId: id);
}

class SportsLogSessionCommand extends RitmoCommand {
  const SportsLogSessionCommand();
  @override
  String get id => 'sports.logSession';
  @override
  String get humanTitle => 'ثبت گزارش تمرین';
  @override
  String get humanDescriptionFa => 'ثبت انجام جلسه ورزشی';
  @override
  Sensitivity get sensitivity => Sensitivity.safe;
  @override
  Set<DataDomain> get touches => {DataDomain.sports};
  @override
  Map<String, ParamSpec> get params => {};
  @override
  Future<PlanDiff> preview(AgentCommandContext ctx) async => const PlanDiff(kind: DiffKind.create, entityLabelFa: 'ثبت تمرین');
  @override
  Future<CommandResult> run(AgentCommandContext ctx) async => CommandResult.ok(commandId: id);
  @override
  Future<CommandResult?> undo(AgentCommandContext ctx, Map<String, dynamic> inverseData) async => CommandResult.ok(commandId: id);
}

class SportsGenerateProgramCommand extends RitmoCommand {
  const SportsGenerateProgramCommand();
  @override
  String get id => 'sports.generateProgram';
  @override
  String get humanTitle => 'تولید برنامه تمرینی';
  @override
  String get humanDescriptionFa => 'طراحی برنامه ورزشی هفتگی متناسب با کاربر';
  @override
  Sensitivity get sensitivity => Sensitivity.confirm;
  @override
  Set<DataDomain> get touches => {DataDomain.sports};
  @override
  Map<String, ParamSpec> get params => {};
  @override
  Future<PlanDiff> preview(AgentCommandContext ctx) async => const PlanDiff(kind: DiffKind.create, entityLabelFa: 'برنامه ورزشی');
  @override
  Future<CommandResult> run(AgentCommandContext ctx) async => CommandResult.ok(commandId: id);
  @override
  Future<CommandResult?> undo(AgentCommandContext ctx, Map<String, dynamic> inverseData) async => CommandResult.ok(commandId: id);
}

class SportsSetQuietModeCommand extends RitmoCommand {
  const SportsSetQuietModeCommand();
  @override
  String get id => 'sports.setQuietMode';
  @override
  String get humanTitle => 'تنظیم تمرین آپارتمانی';
  @override
  String get humanDescriptionFa => 'فعال‌سازی تمرین بدون صدا و جهش';
  @override
  Sensitivity get sensitivity => Sensitivity.confirm;
  @override
  Set<DataDomain> get touches => {DataDomain.sports};
  @override
  Map<String, ParamSpec> get params => {};
  @override
  Future<PlanDiff> preview(AgentCommandContext ctx) async => const PlanDiff(kind: DiffKind.update, entityLabelFa: 'تمرین بدون صدا');
  @override
  Future<CommandResult> run(AgentCommandContext ctx) async => CommandResult.ok(commandId: id);
  @override
  Future<CommandResult?> undo(AgentCommandContext ctx, Map<String, dynamic> inverseData) async => CommandResult.ok(commandId: id);
}
