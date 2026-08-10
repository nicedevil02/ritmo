import 'package:ritmo/core/domain/commands/ritmo_command.dart';
import 'package:ritmo/core/domain/commands/param_spec.dart';
import 'package:ritmo/core/domain/commands/command_plan.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/features/supplementary_sports/data/repositories/ss_prescription_repository.dart';
import 'package:ritmo/features/supplementary_sports/data/repositories/ss_profile_repository.dart';
import 'package:ritmo/features/supplementary_sports/data/repositories/ss_plan_generator.dart';
import 'package:ritmo/features/supplementary_sports/domain/prescription/session_prescription.dart';
import 'package:ritmo/features/supplementary_sports/domain/ss_session_completion_gateway.dart';
import 'package:ritmo/features/supplementary_sports/movement/data/movement_repository.dart';
import 'package:ritmo/features/supplementary_sports/movement/domain/movement_event.dart';
import 'package:ritmo/features/supplementary_sports/movement/domain/movement_kind.dart';
import 'package:sqflite/sqflite.dart';

String _genId() => DateTime.now().microsecondsSinceEpoch.toString();

/// Mark today's workout session as done (skips to next day logic, links a workout_log_id)
class SportsMarkDoneCommand extends RitmoCommand {
  const SportsMarkDoneCommand();

  @override
  String get id => 'sports.mark_done';

  @override
  String get humanTitle => 'تمرین امروز را انجام شده علامت‌گذاری کن';

  @override
  String get humanDescriptionFa =>
      'وضعیت برنامه ورزشی امروز را به «انجام شده» تغییر می‌دهد. '
      'برای وقتی استفاده می‌شود که کاربر خارج از اپ تمرین کرده باشد.';

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
      entityLabelFa: 'تمرین $date — $mins دقیقه انجام شد ✅',
    );
  }

  @override
  Future<CommandResult> run(AgentCommandContext ctx) async {
    final date = ctx.payload['dateStr']?.toString() ??
        DateTime.now().toIso8601String().split('T').first;
    final mins = ctx.payload['durationMinutes'] as int? ?? 45;

    final pres = await SsPrescriptionRepository.instance.getPrescriptionForDate(date);
    String? logId;
    if (pres != null) {
      logId = await SsSessionCompletionGateway.completeSession(
        dateIso: date,
        actualMinutes: mins,
        actualRpe: 6, // Default to moderate for basic command
      );
    }

    return CommandResult.ok(
      commandId: id,
      outputData: {'date': date},
      inverseData: {
        'date': date,
        'prevStatus': pres?.status.code ?? 'PLANNED',
        'prevLogId': pres?.workoutLogId,
        'newLogId': logId,
      },
    );
  }

  @override
  Future<CommandResult?> undo(
      AgentCommandContext ctx, Map<String, dynamic> inverseData) async {
    final date = inverseData['date']?.toString();
    final prevStatus = inverseData['prevStatus']?.toString() ?? 'PLANNED';
    final prevLogId = inverseData['prevLogId']?.toString();
    final newLogId = inverseData['newLogId']?.toString();
    if (date == null) return null;

    final pres = await SsPrescriptionRepository.instance.getPrescriptionForDate(date);
    if (pres != null) {
      await SsPrescriptionRepository.instance.savePrescription(
        pres.copyWith(
          status: PrescriptionStatus.fromCode(prevStatus),
          workoutLogId: prevLogId,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        ),
      );
    }

    // Clean up the movement log created by the gateway
    if (newLogId != null) {
      await MovementRepository.instance.deleteEvent(newLogId);
    }

    return CommandResult.ok(commandId: id);
  }
}

/// Skip today's or a specific day's workout
class SportsSkipSessionCommand extends RitmoCommand {
  const SportsSkipSessionCommand();

  @override
  String get id => 'sports.skip_session';

  @override
  String get humanTitle => 'جلسه تمرین را رد کن';

  @override
  String get humanDescriptionFa =>
      'وضعیت برنامه ورزشی یک روز مشخص را به «رد شده» تغییر می‌دهد.';

  @override
  Sensitivity get sensitivity => Sensitivity.confirm;

  @override
  Set<DataDomain> get touches => {DataDomain.sports};

  @override
  Map<String, ParamSpec> get params => {
    'dateStr': const ParamSpec(
      type: ParamType.isoDate,
      labelFa: 'تاریخ جلسه (پیش‌فرض امروز)',
      required: false,
    ),
    'reason': const ParamSpec(
      type: ParamType.text,
      labelFa: 'دلیل رد شدن',
      required: false,
      exampleFa: 'بیماری',
    ),
  };

  @override
  Future<PlanDiff> preview(AgentCommandContext ctx) async {
    final date = ctx.payload['dateStr']?.toString() ??
        DateTime.now().toIso8601String().split('T').first;
    final reason = ctx.payload['reason']?.toString() ?? '';
    return PlanDiff(
      kind: DiffKind.delete,
      entityLabelFa: 'تمرین $date رد شد${reason.isNotEmpty ? " — $reason" : ""} 🚫',
    );
  }

  @override
  Future<CommandResult> run(AgentCommandContext ctx) async {
    final date = ctx.payload['dateStr']?.toString() ??
        DateTime.now().toIso8601String().split('T').first;

    final pres = await SsPrescriptionRepository.instance.getPrescriptionForDate(date);
    if (pres != null) {
      await SsPrescriptionRepository.instance.savePrescription(
        pres.copyWith(
          status: PrescriptionStatus.skipped,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        ),
      );
    }

    return CommandResult.ok(
      commandId: id,
      outputData: {'date': date},
      inverseData: {'date': date, 'prevStatus': pres?.status.code ?? 'PLANNED'},
    );
  }

  @override
  Future<CommandResult?> undo(
      AgentCommandContext ctx, Map<String, dynamic> inverseData) async {
    final date = inverseData['date']?.toString();
    final prevStatus = inverseData['prevStatus']?.toString() ?? 'PLANNED';
    if (date == null) return null;

    final pres = await SsPrescriptionRepository.instance.getPrescriptionForDate(date);
    if (pres != null) {
      await SsPrescriptionRepository.instance.savePrescription(
        pres.copyWith(
          status: PrescriptionStatus.fromCode(prevStatus),
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        ),
      );
    }
    return CommandResult.ok(commandId: id);
  }
}

/// Reschedule (move) a session from one date to another
class SportsMoveSessionCommand extends RitmoCommand {
  const SportsMoveSessionCommand();

  @override
  String get id => 'sports.move_session';

  @override
  String get humanTitle => 'جلسه تمرین را جابه‌جا کن';

  @override
  String get humanDescriptionFa =>
      'تمرین یک روز مشخص را به روز دیگری منتقل می‌کند. '
      'روز اصلی به «جابه‌جا شده» و روز مقصد به برنامه اضافه می‌شود.';

  @override
  Sensitivity get sensitivity => Sensitivity.confirm;

  @override
  Set<DataDomain> get touches => {DataDomain.sports};

  @override
  Map<String, ParamSpec> get params => {
    'fromDate': const ParamSpec(
      type: ParamType.isoDate,
      labelFa: 'تاریخ جلسه فعلی',
      required: true,
      exampleFa: '2026-08-08',
    ),
    'toDate': const ParamSpec(
      type: ParamType.isoDate,
      labelFa: 'تاریخ جدید',
      required: true,
      exampleFa: '2026-08-09',
    ),
  };

  @override
  Future<PlanDiff> preview(AgentCommandContext ctx) async {
    final from = ctx.payload['fromDate']?.toString() ?? '؟';
    final to = ctx.payload['toDate']?.toString() ?? '؟';
    return PlanDiff(
      kind: DiffKind.update,
      entityLabelFa: 'تمرین $from به $to منتقل شد 📅',
    );
  }

  @override
  Future<CommandResult> run(AgentCommandContext ctx) async {
    final from = ctx.payload['fromDate']?.toString();
    final to = ctx.payload['toDate']?.toString();
    if (from == null || to == null) {
      return CommandResult.failure(commandId: id, errorMessage: 'fromDate و toDate الزامی هستند.');
    }

    final repo = SsPrescriptionRepository.instance;
    final sourcePres = await repo.getPrescriptionForDate(from);

    if (sourcePres != null) {
      // Mark source as moved
      await repo.savePrescription(sourcePres.copyWith(
        status: PrescriptionStatus.moved,
        movedToDateIso: to,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ));

      // Create or update destination prescription
      final destPres = await repo.getPrescriptionForDate(to);
      if (destPres == null) {
        await repo.savePrescription(sourcePres.copyWith(
          id: 'pres_${to}_${DateTime.now().millisecondsSinceEpoch}',
          dateIso: to,
          status: PrescriptionStatus.planned,
          movedToDateIso: null,
          workoutLogId: null,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
          createdAt: DateTime.now().millisecondsSinceEpoch,
        ));
      }
    }

    return CommandResult.ok(
      commandId: id,
      outputData: {'from': from, 'to': to},
      inverseData: {'from': from, 'to': to, 'sourceId': sourcePres?.id},
    );
  }

  @override
  Future<CommandResult?> undo(
      AgentCommandContext ctx, Map<String, dynamic> inverseData) async {
    final from = inverseData['from']?.toString();
    final to = inverseData['to']?.toString();
    if (from == null || to == null) return null;

    final repo = SsPrescriptionRepository.instance;
    final sourcePres = await repo.getPrescriptionForDate(from);
    if (sourcePres != null) {
      await repo.savePrescription(sourcePres.copyWith(
        status: PrescriptionStatus.planned,
        movedToDateIso: null,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ));
    }
    final destPres = await repo.getPrescriptionForDate(to);
    if (destPres != null) {
      await repo.deletePrescriptionsBulk([destPres.id]);
    }
    return CommandResult.ok(commandId: id);
  }
}

/// Log a custom movement or sport activity
class SportsLogCustomMovementCommand extends RitmoCommand {
  const SportsLogCustomMovementCommand();

  @override
  String get id => 'sports.log_movement';

  @override
  String get humanTitle => 'ثبت فعالیت حرکتی یا ورزشی';

  @override
  String get humanDescriptionFa => 'یک فعالیت حرکتی یا ورزشی دلخواه را در تایم‌لاین ثبت می‌کند.';

  @override
  Sensitivity get sensitivity => Sensitivity.safe;

  @override
  Set<DataDomain> get touches => {DataDomain.sports};

  @override
  Map<String, ParamSpec> get params => {
    'kindCode': const ParamSpec(
      type: ParamType.text,
      labelFa: 'نوع فعالیت',
      required: true,
      exampleFa: 'WALKING',
    ),
    'durationMinutes': const ParamSpec(
      type: ParamType.integer,
      labelFa: 'مدت به دقیقه',
      required: true,
      exampleFa: '30',
    ),
    'intensity': const ParamSpec(
      type: ParamType.text,
      labelFa: 'شدت (LOW, MEDIUM, HIGH)',
      required: false,
      exampleFa: 'MEDIUM',
    ),
    'distanceKm': const ParamSpec(
      type: ParamType.text,
      labelFa: 'مسافت به کیلومتر',
      required: false,
      exampleFa: '3.5',
    ),
    'note': const ParamSpec(
      type: ParamType.text,
      labelFa: 'یادداشت',
      required: false,
    ),
  };

  @override
  Future<PlanDiff> preview(AgentCommandContext ctx) async {
    final kind = ctx.payload['kindCode']?.toString() ?? 'فعالیت';
    final mins = ctx.payload['durationMinutes'] as int? ?? 30;
    return PlanDiff(
      kind: DiffKind.create,
      entityLabelFa: '$kind — $mins دقیقه ثبت می‌شود ⚡',
    );
  }

  @override
  Future<CommandResult> run(AgentCommandContext ctx) async {
    final kindCode = ctx.payload['kindCode']?.toString() ?? 'OTHER';
    final mins = (ctx.payload['durationMinutes'] as num?)?.toInt() ?? 30;
    final intensityStr = ctx.payload['intensity']?.toString() ?? 'MEDIUM';
    final distanceKm = (ctx.payload['distanceKm'] as num?)?.toDouble();
    final note = ctx.payload['note']?.toString();
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final logId = 'wlog_mov_${_genId()}';

    final event = MovementEvent(
      id: logId,
      kindCode: kindCode,
      durationMinutes: mins,
      intensity: MovementIntensity.fromCode(intensityStr),
      distanceMeters: distanceKm != null ? (distanceKm * 1000.0) : null,
      loggedAt: nowMs,
      sourceModule: 'movement_tracker',
      note: note,
    );

    await MovementRepository.instance.logEvent(event);

    return CommandResult.ok(
      commandId: id,
      outputData: {'id': logId},
      inverseData: {'id': logId},
    );
  }

  @override
  Future<CommandResult?> undo(AgentCommandContext ctx, Map<String, dynamic> inverseData) async {
    final logId = inverseData['id']?.toString();
    if (logId != null) {
      await MovementRepository.instance.deleteEvent(logId);
    }
    return CommandResult.ok(commandId: id);
  }
}

/// Set days per week in sports profile
class SportsSetDaysPerWeekCommand extends RitmoCommand {
  const SportsSetDaysPerWeekCommand();

  @override
  String get id => 'sports.set_days_per_week';

  @override
  String get humanTitle => 'تنظیم تعداد روزهای تمرین در هفته';

  @override
  String get humanDescriptionFa => 'تعداد روزهای تمرین در هفته را در پروفایل ورزشی تغییر می‌دهد.';

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
      exampleFa: '3',
    ),
  };

  @override
  Future<PlanDiff> preview(AgentCommandContext ctx) async {
    final days = ctx.payload['daysPerWeek'] as int? ?? 3;
    return PlanDiff(
      kind: DiffKind.update,
      entityLabelFa: 'برنامه به $days روز در هفته تغییر می‌یابد 🏋️',
    );
  }

  @override
  Future<CommandResult> run(AgentCommandContext ctx) async {
    final days = (ctx.payload['daysPerWeek'] as num?)?.toInt() ?? 3;
    final repo = SSProfileRepository.instance;
    final profile = await repo.getProfile();
    final prevDays = profile?.daysPerWeek ?? 3;

    if (profile != null) {
      await repo.saveProfile(profile.copyWith(daysPerWeek: days));
      final db = await DatabaseHelper.instance.database;
      await SSPlanGenerator.generateWeeklyAndMonthlyPlan(db, profile.copyWith(daysPerWeek: days), week: 1);
    }

    return CommandResult.ok(
      commandId: id,
      outputData: {'daysPerWeek': days},
      inverseData: {'prevDays': prevDays},
    );
  }

  @override
  Future<CommandResult?> undo(AgentCommandContext ctx, Map<String, dynamic> inverseData) async {
    final prevDays = inverseData['prevDays'] as int? ?? 3;
    final repo = SSProfileRepository.instance;
    final profile = await repo.getProfile();
    if (profile != null) {
      await repo.saveProfile(profile.copyWith(daysPerWeek: prevDays));
    }
    return CommandResult.ok(commandId: id);
  }
}

/// Lock a specific prescription day against auto-regeneration
class SportsLockDayCommand extends RitmoCommand {
  const SportsLockDayCommand();

  @override
  String get id => 'sports.lock_day';

  @override
  String get humanTitle => 'قفل کردن برنامه یک روز';

  @override
  String get humanDescriptionFa => 'برنامه این روز را قفل می‌کند تا با تغییرات خودکار بازتولید نشود.';

  @override
  Sensitivity get sensitivity => Sensitivity.safe;

  @override
  Set<DataDomain> get touches => {DataDomain.sports};

  @override
  Map<String, ParamSpec> get params => {
    'dateStr': const ParamSpec(
      type: ParamType.isoDate,
      labelFa: 'تاریخ روز',
      required: true,
    ),
  };

  @override
  Future<PlanDiff> preview(AgentCommandContext ctx) async {
    final d = ctx.payload['dateStr']?.toString() ?? '؟';
    return PlanDiff(kind: DiffKind.update, entityLabelFa: 'برنامه روز $d قفل می‌شود 🔒');
  }

  @override
  Future<CommandResult> run(AgentCommandContext ctx) async {
    final dateStr = ctx.payload['dateStr']?.toString();
    if (dateStr == null) return CommandResult.failure(commandId: id, errorMessage: 'dateStr الزامی است.');
    final repo = SsPrescriptionRepository.instance;
    final pres = await repo.getPrescriptionForDate(dateStr);
    if (pres != null) {
      await repo.savePrescription(pres.copyWith(isLocked: true));
    }
    return CommandResult.ok(commandId: id, inverseData: {'dateStr': dateStr, 'wasLocked': pres?.isLocked ?? false});
  }

  @override
  Future<CommandResult?> undo(AgentCommandContext ctx, Map<String, dynamic> inverseData) async {
    final dateStr = inverseData['dateStr']?.toString();
    final wasLocked = inverseData['wasLocked'] as bool? ?? false;
    if (dateStr != null) {
      final repo = SsPrescriptionRepository.instance;
      final pres = await repo.getPrescriptionForDate(dateStr);
      if (pres != null) {
        await repo.savePrescription(pres.copyWith(isLocked: wasLocked));
      }
    }
    return CommandResult.ok(commandId: id);
  }
}

/// Unlock a specific prescription day
class SportsUnlockDayCommand extends RitmoCommand {
  const SportsUnlockDayCommand();

  @override
  String get id => 'sports.unlock_day';

  @override
  String get humanTitle => 'باز کردن قفل برنامه یک روز';

  @override
  String get humanDescriptionFa => 'قفل این روز را برمی‌دارد تا در تغییرات خودکار بازتولید شود.';

  @override
  Sensitivity get sensitivity => Sensitivity.safe;

  @override
  Set<DataDomain> get touches => {DataDomain.sports};

  @override
  Map<String, ParamSpec> get params => {
    'dateStr': const ParamSpec(
      type: ParamType.isoDate,
      labelFa: 'تاریخ روز',
      required: true,
    ),
  };

  @override
  Future<PlanDiff> preview(AgentCommandContext ctx) async {
    final d = ctx.payload['dateStr']?.toString() ?? '؟';
    return PlanDiff(kind: DiffKind.update, entityLabelFa: 'قفل برنامه روز $d باز می‌شود 🔓');
  }

  @override
  Future<CommandResult> run(AgentCommandContext ctx) async {
    final dateStr = ctx.payload['dateStr']?.toString();
    if (dateStr == null) return CommandResult.failure(commandId: id, errorMessage: 'dateStr الزامی است.');
    final repo = SsPrescriptionRepository.instance;
    final pres = await repo.getPrescriptionForDate(dateStr);
    if (pres != null) {
      await repo.savePrescription(pres.copyWith(isLocked: false));
    }
    return CommandResult.ok(commandId: id, inverseData: {'dateStr': dateStr, 'wasLocked': pres?.isLocked ?? true});
  }

  @override
  Future<CommandResult?> undo(AgentCommandContext ctx, Map<String, dynamic> inverseData) async {
    final dateStr = inverseData['dateStr']?.toString();
    final wasLocked = inverseData['wasLocked'] as bool? ?? true;
    if (dateStr != null) {
      final repo = SsPrescriptionRepository.instance;
      final pres = await repo.getPrescriptionForDate(dateStr);
      if (pres != null) {
        await repo.savePrescription(pres.copyWith(isLocked: wasLocked));
      }
    }
    return CommandResult.ok(commandId: id);
  }
}

/// Apply a deload week
class SportsApplyDeloadCommand extends RitmoCommand {
  const SportsApplyDeloadCommand();

  @override
  String get id => 'sports.apply_deload';

  @override
  String get humanTitle => 'اعمال هفته دیلود (ریکاوری سبک)';

  @override
  String get humanDescriptionFa => 'حجم و شدت تمرینات هفته مشخص‌شده را برای ریکاوری کاهش می‌دهد.';

  @override
  Sensitivity get sensitivity => Sensitivity.confirm;

  @override
  Set<DataDomain> get touches => {DataDomain.sports};

  @override
  Map<String, ParamSpec> get params => {
    'week': const ParamSpec(
      type: ParamType.integer,
      labelFa: 'شماره هفته (۱ تا ۴)',
      required: true,
      exampleFa: '4',
    ),
  };

  @override
  Future<PlanDiff> preview(AgentCommandContext ctx) async {
    final wk = ctx.payload['week'] as int? ?? 4;
    return PlanDiff(kind: DiffKind.update, entityLabelFa: 'هفته $wk به هفته دیلود (سبک) تبدیل می‌شود 🔋');
  }

  @override
  Future<CommandResult> run(AgentCommandContext ctx) async {
    final wk = (ctx.payload['week'] as num?)?.toInt() ?? 4;
    final repo = SSProfileRepository.instance;
    final profile = await repo.getProfile();
    if (profile == null) return CommandResult.failure(commandId: id, errorMessage: 'پروفایل ورزشی یافت نشد.');

    final db = await DatabaseHelper.instance.database;
    await SSPlanGenerator.generateWeeklyAndMonthlyPlan(
      db,
      profile,
      week: wk,
      isDeload: true,
    );

    return CommandResult.ok(commandId: id, outputData: {'week': wk});
  }

  @override
  Future<CommandResult?> undo(AgentCommandContext ctx, Map<String, dynamic> inverseData) async {
    return CommandResult.ok(commandId: id);
  }
}

/// Regenerate a specific week plan
class SportsRegenerateWeekCommand extends RitmoCommand {
  const SportsRegenerateWeekCommand();

  @override
  String get id => 'sports.regenerate_week';

  @override
  String get humanTitle => 'بازتولید برنامه یک هفته';

  @override
  String get humanDescriptionFa => 'برنامه تمرینی هفته مشخص‌شده را بر اساس آخرین فیدبک‌ها بازتولید می‌کند.';

  @override
  Sensitivity get sensitivity => Sensitivity.confirm;

  @override
  Set<DataDomain> get touches => {DataDomain.sports};

  @override
  Map<String, ParamSpec> get params => {
    'week': const ParamSpec(
      type: ParamType.integer,
      labelFa: 'شماره هفته (۱ تا ۴)',
      required: true,
      exampleFa: '2',
    ),
  };

  @override
  Future<PlanDiff> preview(AgentCommandContext ctx) async {
    final wk = ctx.payload['week'] as int? ?? 2;
    return PlanDiff(kind: DiffKind.update, entityLabelFa: 'برنامه هفته $wk بازتولید می‌شود 🔄');
  }

  @override
  Future<CommandResult> run(AgentCommandContext ctx) async {
    final wk = (ctx.payload['week'] as num?)?.toInt() ?? 2;
    final repo = SSProfileRepository.instance;
    final profile = await repo.getProfile();
    if (profile == null) return CommandResult.failure(commandId: id, errorMessage: 'پروفایل ورزشی یافت نشد.');

    final db = await DatabaseHelper.instance.database;
    await SSPlanGenerator.generateWeeklyAndMonthlyPlan(
      db,
      profile,
      week: wk,
    );

    return CommandResult.ok(commandId: id, outputData: {'week': wk});
  }

  @override
  Future<CommandResult?> undo(AgentCommandContext ctx, Map<String, dynamic> inverseData) async {
    return CommandResult.ok(commandId: id);
  }
}

/// Swap an exercise in a workout plan
class SportsSwapExerciseCommand extends RitmoCommand {
  const SportsSwapExerciseCommand();

  @override
  String get id => 'sports.swap_exercise';

  @override
  String get humanTitle => 'تعویض یک حرکت در برنامه';

  @override
  String get humanDescriptionFa => 'یک حرکت ورزشی را در برنامه تمرینی با حرکت دیگری جایگزین می‌کند.';

  @override
  Sensitivity get sensitivity => Sensitivity.safe;

  @override
  Set<DataDomain> get touches => {DataDomain.sports};

  @override
  Map<String, ParamSpec> get params => {
    'planId': const ParamSpec(
      type: ParamType.text,
      labelFa: 'شناسه برنامه',
      required: true,
    ),
    'oldExerciseId': const ParamSpec(
      type: ParamType.text,
      labelFa: 'شناسه حرکت قبلی',
      required: true,
    ),
    'newExerciseId': const ParamSpec(
      type: ParamType.text,
      labelFa: 'شناسه حرکت جدید',
      required: true,
    ),
  };

  @override
  Future<PlanDiff> preview(AgentCommandContext ctx) async {
    final oldId = ctx.payload['oldExerciseId']?.toString() ?? 'حرکت';
    final newId = ctx.payload['newExerciseId']?.toString() ?? 'حرکت جدید';
    return PlanDiff(kind: DiffKind.update, entityLabelFa: 'تعویض $oldId با $newId 🔄');
  }

  @override
  Future<CommandResult> run(AgentCommandContext ctx) async {
    final planId = ctx.payload['planId']?.toString();
    final oldExerciseId = ctx.payload['oldExerciseId']?.toString();
    final newExerciseId = ctx.payload['newExerciseId']?.toString();
    if (planId == null || oldExerciseId == null || newExerciseId == null) {
      return CommandResult.failure(commandId: id, errorMessage: 'پارامترهای الزامی فرستاده نشده‌اند.');
    }

    final db = await DatabaseHelper.instance.database;
    await db.update(
      'ss_workout_exercise_crossref',
      {'exerciseId': newExerciseId},
      where: 'planId = ? AND exerciseId = ?',
      whereArgs: [planId, oldExerciseId],
    );

    return CommandResult.ok(
      commandId: id,
      outputData: {'planId': planId, 'newExerciseId': newExerciseId},
      inverseData: {'planId': planId, 'oldExerciseId': oldExerciseId, 'newExerciseId': newExerciseId},
    );
  }

  @override
  Future<CommandResult?> undo(AgentCommandContext ctx, Map<String, dynamic> inverseData) async {
    final planId = inverseData['planId']?.toString();
    final oldExerciseId = inverseData['oldExerciseId']?.toString();
    final newExerciseId = inverseData['newExerciseId']?.toString();
    if (planId != null && oldExerciseId != null && newExerciseId != null) {
      final db = await DatabaseHelper.instance.database;
      await db.update(
        'ss_workout_exercise_crossref',
        {'exerciseId': oldExerciseId},
        where: 'planId = ? AND exerciseId = ?',
        whereArgs: [planId, newExerciseId],
      );
    }
    return CommandResult.ok(commandId: id);
  }
}
