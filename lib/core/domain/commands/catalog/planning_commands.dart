import 'package:ritmo/core/domain/commands/command_plan.dart';
import 'package:ritmo/core/domain/commands/param_spec.dart';
import 'package:ritmo/core/domain/commands/ritmo_command.dart';
import 'package:ritmo/features/assistant/logic/assistant_action_registry.dart';
import 'package:ritmo/features/assistant/models/day_plan_models.dart';
import 'package:sqflite/sqflite.dart';

class PlanningApplyWeekCommand extends RitmoCommand {
  const PlanningApplyWeekCommand({this.drafts = const []});

  final List<DayPlanDraft> drafts;

  @override
  String get id => 'planning.applyWeek';

  @override
  String get humanTitle => 'ثبت برنامهٔ هفتگی';

  @override
  String get humanDescriptionFa =>
      'ثبت اتمیک برنامهٔ هفته در یک تراکنش واحد';

  @override
  Sensitivity get sensitivity => Sensitivity.confirm;

  @override
  Set<DataDomain> get touches => const {DataDomain.routines, DataDomain.goals};

  @override
  Map<String, ParamSpec> get params => const {};

  @override
  Future<PlanDiff> preview(AgentCommandContext ctx) async {
    final rawDrafts = (ctx.payload['drafts'] as List?) ?? drafts.map((d) => d.toJson()).toList();
    final itemCount = rawDrafts.fold<int>(0, (a, d) {
      final items = (d is Map ? d['items'] as List? : (d as DayPlanDraft).items);
      return a + (items?.length ?? 0);
    });

    if (rawDrafts.isEmpty || itemCount == 0) {
      return const PlanDiff(
        kind: DiffKind.noop,
        entityLabelFa: 'برنامهٔ هفتگی خالی است',
      );
    }

    final dates = rawDrafts.map((d) => (d is Map ? d['planDate'] as String? : (d as DayPlanDraft).planDate) ?? '').where((s) => s.isNotEmpty).toList()..sort();
    final first = dates.isNotEmpty ? dates.first : '';
    final last = dates.isNotEmpty ? dates.last : '';

    return PlanDiff(
      kind: DiffKind.create,
      entityLabelFa:
          'برنامهٔ هفتهٔ $first تا $last — $itemCount فعالیت در ${rawDrafts.length} روز',
    );
  }

  @override
  Future<CommandResult> run(AgentCommandContext ctx) async {
    final rawDrafts = ctx.payload['drafts'] as List?;
    final targetDrafts = rawDrafts != null
        ? rawDrafts.map((e) => DayPlanDraft.fromJson(Map<String, dynamic>.from(e as Map))).toList()
        : drafts;

    if (targetDrafts.isEmpty) {
      return CommandResult.failure(
        commandId: id,
        errorMessage: 'برنامهٔ خالی قابل ثبت نیست.',
      );
    }

    final groupId = 'week_plan_${ctx.now.millisecondsSinceEpoch}';
    final commitIds = <String>[];
    final createdTokens = <String>[];

    final exec = ctx.txn;
    if (exec is Database) {
      await exec.transaction((txn) async {
        for (final draft in targetDrafts) {
          final outcome = await DayPlanApplyExecutor.applyWithTxn(
            txn: txn,
            draft: draft,
            groupId: groupId,
            now: ctx.now,
          );
          commitIds.addAll(outcome.commitIds);
          createdTokens.addAll(outcome.undoTokens);
        }
      });
    } else {
      for (final draft in targetDrafts) {
        final outcome = await DayPlanApplyExecutor.applyWithTxn(
          txn: exec,
          draft: draft,
          groupId: groupId,
          now: ctx.now,
        );
        commitIds.addAll(outcome.commitIds);
        createdTokens.addAll(outcome.undoTokens);
      }
    }

    return CommandResult.ok(
      commandId: id,
      inverseData: {
        'groupId': groupId,
        'commitIds': commitIds,
        'undoTokens': createdTokens,
      },
      outputData: {'days': targetDrafts.length},
    );
  }

  @override
  Future<CommandResult?> undo(AgentCommandContext ctx, Map<String, dynamic> inverseData) async {
    final groupId = inverseData['groupId'] as String?;
    if (groupId == null || groupId.isEmpty) return null;
    await AssistantUndoBridge.undoDayPlanGroup(ctx, groupId);
    return CommandResult.ok(commandId: id);
  }
}

class PlanningCreateCycleCommand extends RitmoCommand {
  const PlanningCreateCycleCommand();

  @override
  String get id => 'planning.createCycle';
  @override
  String get humanTitle => 'ایجاد چرخهٔ برنامه‌ریزی';
  @override
  String get humanDescriptionFa => 'ساخت چرخهٔ جدید روزانه، هفتگی یا ماهانه';
  @override
  Sensitivity get sensitivity => Sensitivity.safe;
  @override
  Set<DataDomain> get touches => const {DataDomain.goals};
  @override
  Map<String, ParamSpec> get params => const {};

  @override
  Future<PlanDiff> preview(AgentCommandContext ctx) async {
    return const PlanDiff(kind: DiffKind.create, entityLabelFa: 'ایجاد چرخه برنامه‌ریزی');
  }

  @override
  Future<CommandResult> run(AgentCommandContext ctx) async {
    final cycleId = ctx.payload['id']?.toString() ?? 'cycle_${ctx.now.millisecondsSinceEpoch}';
    final horizon = ctx.payload['horizon']?.toString() ?? 'WEEK';
    final startDayKey = ctx.payload['startDayKey']?.toString() ?? '';
    final endDayKey = ctx.payload['endDayKey']?.toString() ?? '';

    await ctx.txn.insert('planning_cycles', {
      'id': cycleId,
      'horizon': horizon,
      'startDayKey': startDayKey,
      'endDayKey': endDayKey,
      'status': 'DRAFT',
      'title': ctx.payload['title']?.toString(),
      'theme': ctx.payload['theme']?.toString(),
      'capacityMinutes': (ctx.payload['capacityMinutes'] as num?)?.toInt() ?? 0,
      'reserveMinutes': (ctx.payload['reserveMinutes'] as num?)?.toInt() ?? 0,
      'version': 1,
      'createdAt': ctx.now.millisecondsSinceEpoch,
    });

    return CommandResult.ok(commandId: id, outputData: {'cycleId': cycleId});
  }

  @override
  Future<CommandResult?> undo(AgentCommandContext ctx, Map<String, dynamic> inverseData) async {
    return CommandResult.ok(commandId: id);
  }
}

class PlanningCloseCycleCommand extends RitmoCommand {
  const PlanningCloseCycleCommand();

  @override
  String get id => 'planning.closeCycle';
  @override
  String get humanTitle => 'بستن چرخهٔ برنامه‌ریزی';
  @override
  String get humanDescriptionFa => 'پایان چرخه و ثبت مرور';
  @override
  Sensitivity get sensitivity => Sensitivity.confirm;
  @override
  Set<DataDomain> get touches => const {DataDomain.goals};
  @override
  Map<String, ParamSpec> get params => const {};

  @override
  Future<PlanDiff> preview(AgentCommandContext ctx) async {
    return const PlanDiff(kind: DiffKind.update, entityLabelFa: 'بستن چرخه برنامه‌ریزی');
  }

  @override
  Future<CommandResult> run(AgentCommandContext ctx) async {
    final cycleId = ctx.payload['cycleId']?.toString() ?? '';
    await ctx.txn.update(
      'planning_cycles',
      {'status': 'CLOSED', 'closedAt': ctx.now.millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [cycleId],
    );
    return CommandResult.ok(commandId: id);
  }

  @override
  Future<CommandResult?> undo(AgentCommandContext ctx, Map<String, dynamic> inverseData) async {
    return CommandResult.ok(commandId: id);
  }
}

class PlanningAddCommitmentCommand extends RitmoCommand {
  const PlanningAddCommitmentCommand();

  @override
  String get id => 'planning.addCommitment';
  @override
  String get humanTitle => 'افزودن تعهد به چرخه';
  @override
  String get humanDescriptionFa => 'تعریف تعهد جدید برای افق برنامه';
  @override
  Sensitivity get sensitivity => Sensitivity.safe;
  @override
  Set<DataDomain> get touches => const {DataDomain.goals};
  @override
  Map<String, ParamSpec> get params => const {};

  @override
  Future<PlanDiff> preview(AgentCommandContext ctx) async {
    return PlanDiff(kind: DiffKind.create, entityLabelFa: 'افزودن تعهد: ${ctx.payload['title']}');
  }

  @override
  Future<CommandResult> run(AgentCommandContext ctx) async {
    final commitmentId = ctx.payload['id']?.toString() ?? 'commit_${ctx.now.millisecondsSinceEpoch}';
    await ctx.txn.insert('planning_commitments', {
      'id': commitmentId,
      'cycleId': ctx.payload['cycleId']?.toString() ?? '',
      'title': ctx.payload['title']?.toString() ?? '',
      'sourceType': ctx.payload['sourceType']?.toString() ?? 'MANUAL',
      'sourceId': ctx.payload['sourceId']?.toString(),
      'goalId': ctx.payload['goalId']?.toString(),
      'importance': ctx.payload['importance']?.toString() ?? 'SHOULD',
      'flexibility': ctx.payload['flexibility']?.toString() ?? 'FLEXIBLE',
      'effortMinutes': (ctx.payload['effortMinutes'] as num?)?.toInt() ?? 30,
      'workKind': ctx.payload['workKind']?.toString() ?? 'LIGHT',
      'earliestDayKey': ctx.payload['earliestDayKey']?.toString(),
      'latestDayKey': ctx.payload['latestDayKey']?.toString(),
      'preferredDayPartsJson': ctx.payload['preferredDayPartsJson']?.toString(),
      'status': ctx.payload['status']?.toString() ?? 'PROPOSED',
      'isUserLocked': (ctx.payload['isUserLocked'] == true || ctx.payload['isUserLocked'] == 1) ? 1 : 0,
      'origin': ctx.payload['origin']?.toString() ?? 'USER',
      'planningReason': ctx.payload['planningReason']?.toString(),
      'createdAt': ctx.now.millisecondsSinceEpoch,
      'updatedAt': ctx.now.millisecondsSinceEpoch,
    });
    return CommandResult.ok(commandId: id, outputData: {'commitmentId': commitmentId});
  }

  @override
  Future<CommandResult?> undo(AgentCommandContext ctx, Map<String, dynamic> inverseData) async {
    return CommandResult.ok(commandId: id);
  }
}

class PlanningDropCommitmentCommand extends RitmoCommand {
  const PlanningDropCommitmentCommand();

  @override
  String get id => 'planning.dropCommitment';
  @override
  String get humanTitle => 'حذف یا رهاسازی تعهد';
  @override
  String get humanDescriptionFa => 'تغییر وضعیت تعهد به DROPPED با دلیل';
  @override
  Sensitivity get sensitivity => Sensitivity.confirm;
  @override
  Set<DataDomain> get touches => const {DataDomain.goals};
  @override
  Map<String, ParamSpec> get params => const {};

  @override
  Future<PlanDiff> preview(AgentCommandContext ctx) async {
    return const PlanDiff(kind: DiffKind.delete, entityLabelFa: 'رهاسازی تعهد');
  }

  @override
  Future<CommandResult> run(AgentCommandContext ctx) async {
    final idVal = ctx.payload['id']?.toString() ?? '';
    final reason = ctx.payload['reason']?.toString();
    await ctx.txn.update(
      'planning_commitments',
      {
        'status': 'DROPPED',
        'planningReason': reason,
        'updatedAt': ctx.now.millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [idVal],
    );
    return CommandResult.ok(commandId: id);
  }

  @override
  Future<CommandResult?> undo(AgentCommandContext ctx, Map<String, dynamic> inverseData) async {
    return CommandResult.ok(commandId: id);
  }
}

class PlanningMoveAllocationCommand extends RitmoCommand {
  const PlanningMoveAllocationCommand();

  @override
  String get id => 'planning.moveAllocation';
  @override
  String get humanTitle => 'انتقال تخصیص به روز دیگر';
  @override
  String get humanDescriptionFa => 'جابه‌جایی برنامهٔ یک تعهد به تاریخ جدید';
  @override
  Sensitivity get sensitivity => Sensitivity.safe;
  @override
  Set<DataDomain> get touches => const {DataDomain.goals, DataDomain.routines};
  @override
  Map<String, ParamSpec> get params => const {};

  @override
  Future<PlanDiff> preview(AgentCommandContext ctx) async {
    return PlanDiff(kind: DiffKind.update, entityLabelFa: 'انتقال به روز ${ctx.payload['newDayKey']}');
  }

  @override
  Future<CommandResult> run(AgentCommandContext ctx) async {
    final allocId = ctx.payload['allocationId']?.toString() ?? '';
    final newDayKey = ctx.payload['newDayKey']?.toString() ?? '';

    final existing = await ctx.txn.query(
      'planning_allocations',
      where: 'id = ?',
      whereArgs: [allocId],
    );

    if (existing.isNotEmpty) {
      final old = existing.first;
      await ctx.txn.update(
        'planning_allocations',
        {'status': 'MOVED', 'updatedAt': ctx.now.millisecondsSinceEpoch},
        where: 'id = ?',
        whereArgs: [allocId],
      );

      final newAllocId = 'alloc_${ctx.now.millisecondsSinceEpoch}';
      await ctx.txn.insert('planning_allocations', {
        'id': newAllocId,
        'commitmentId': old['commitmentId'],
        'dayKey': newDayKey,
        'plannedMinutes': old['plannedMinutes'],
        'timeWindowStart': old['timeWindowStart'],
        'timeWindowEnd': old['timeWindowEnd'],
        'exactTime': old['exactTime'],
        'status': 'PLANNED',
        'materializedEntityType': old['materializedEntityType'],
        'materializedEntityId': old['materializedEntityId'],
        'idempotencyKey': '$allocId|moved|$newDayKey',
        'createdAt': ctx.now.millisecondsSinceEpoch,
        'updatedAt': ctx.now.millisecondsSinceEpoch,
      });
    }

    return CommandResult.ok(commandId: id);
  }

  @override
  Future<CommandResult?> undo(AgentCommandContext ctx, Map<String, dynamic> inverseData) async {
    return CommandResult.ok(commandId: id);
  }
}

class PlanningSplitCommitmentCommand extends RitmoCommand {
  const PlanningSplitCommitmentCommand();

  @override
  String get id => 'planning.splitCommitment';
  @override
  String get humanTitle => 'تقسیم تعهد به دو بخش';
  @override
  String get humanDescriptionFa => 'شکستن یک تعهد بزرگ به دو بخش کوچکتر';
  @override
  Sensitivity get sensitivity => Sensitivity.safe;
  @override
  Set<DataDomain> get touches => const {DataDomain.goals};
  @override
  Map<String, ParamSpec> get params => const {};

  @override
  Future<PlanDiff> preview(AgentCommandContext ctx) async {
    return const PlanDiff(kind: DiffKind.update, entityLabelFa: 'تقسیم تعهد');
  }

  @override
  Future<CommandResult> run(AgentCommandContext ctx) async {
    final commitmentId = ctx.payload['commitmentId']?.toString() ?? '';
    final part1Minutes = (ctx.payload['part1Minutes'] as num?)?.toInt() ?? 30;

    final existing = await ctx.txn.query(
      'planning_commitments',
      where: 'id = ?',
      whereArgs: [commitmentId],
    );

    if (existing.isNotEmpty) {
      final old = existing.first;
      final total = (old['effortMinutes'] as num).toInt();
      final part2Minutes = total - part1Minutes;

      if (part2Minutes > 0) {
        await ctx.txn.update(
          'planning_commitments',
          {
            'effortMinutes': part1Minutes,
            'updatedAt': ctx.now.millisecondsSinceEpoch,
          },
          where: 'id = ?',
          whereArgs: [commitmentId],
        );

        final newCommitmentId = '${commitmentId}_split';
        await ctx.txn.insert('planning_commitments', {
          'id': newCommitmentId,
          'cycleId': old['cycleId'],
          'title': '${old['title']} (بخش دوم)',
          'sourceType': old['sourceType'],
          'sourceId': old['sourceId'],
          'goalId': old['goalId'],
          'importance': old['importance'],
          'flexibility': old['flexibility'],
          'effortMinutes': part2Minutes,
          'workKind': old['workKind'],
          'earliestDayKey': old['earliestDayKey'],
          'latestDayKey': old['latestDayKey'],
          'preferredDayPartsJson': old['preferredDayPartsJson'],
          'status': old['status'],
          'isUserLocked': old['isUserLocked'],
          'origin': old['origin'],
          'planningReason': old['planningReason'],
          'createdAt': ctx.now.millisecondsSinceEpoch,
          'updatedAt': ctx.now.millisecondsSinceEpoch,
        });
      }
    }

    return CommandResult.ok(commandId: id);
  }

  @override
  Future<CommandResult?> undo(AgentCommandContext ctx, Map<String, dynamic> inverseData) async {
    return CommandResult.ok(commandId: id);
  }
}

class PlanningLockAllocationCommand extends RitmoCommand {
  const PlanningLockAllocationCommand();

  @override
  String get id => 'planning.lockAllocation';
  @override
  String get humanTitle => 'قفل تعهد در روز مشخص';
  @override
  String get humanDescriptionFa => 'جلوگیری از تغییر یا جابه‌جایی تعهد توسط سیستم';
  @override
  Sensitivity get sensitivity => Sensitivity.safe;
  @override
  Set<DataDomain> get touches => const {DataDomain.goals};
  @override
  Map<String, ParamSpec> get params => const {};

  @override
  Future<PlanDiff> preview(AgentCommandContext ctx) async {
    return const PlanDiff(kind: DiffKind.update, entityLabelFa: 'قفل تعهد');
  }

  @override
  Future<CommandResult> run(AgentCommandContext ctx) async {
    final idVal = ctx.payload['commitmentId']?.toString() ?? '';
    await ctx.txn.update(
      'planning_commitments',
      {'isUserLocked': 1, 'updatedAt': ctx.now.millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [idVal],
    );
    return CommandResult.ok(commandId: id);
  }

  @override
  Future<CommandResult?> undo(AgentCommandContext ctx, Map<String, dynamic> inverseData) async {
    return CommandResult.ok(commandId: id);
  }
}

class PlanningSetDayLightCommand extends RitmoCommand {
  const PlanningSetDayLightCommand();

  @override
  String get id => 'planning.setDayLight';
  @override
  String get humanTitle => 'علامت‌گذاری روز سبک';
  @override
  String get humanDescriptionFa => 'تعیین یک روز به‌عنوان روز استراحت یا فعالیت سبک';
  @override
  Sensitivity get sensitivity => Sensitivity.safe;
  @override
  Set<DataDomain> get touches => const {DataDomain.goals};
  @override
  Map<String, ParamSpec> get params => const {};

  @override
  Future<PlanDiff> preview(AgentCommandContext ctx) async {
    return PlanDiff(kind: DiffKind.update, entityLabelFa: 'سبک‌سازی روز ${ctx.payload['dayKey']}');
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

class PlanningMaterializeDayCommand extends RitmoCommand {
  const PlanningMaterializeDayCommand();

  @override
  String get id => 'planning.materializeDay';
  @override
  String get humanTitle => 'مادی‌سازی برنامهٔ امروز';
  @override
  String get humanDescriptionFa => 'تبدیل تخصیص‌های تعهد امروز به کارهای واقعی یا روتین';
  @override
  Sensitivity get sensitivity => Sensitivity.confirm;
  @override
  Set<DataDomain> get touches => const {DataDomain.routines, DataDomain.goals};
  @override
  Map<String, ParamSpec> get params => const {};

  @override
  Future<PlanDiff> preview(AgentCommandContext ctx) async {
    return const PlanDiff(kind: DiffKind.create, entityLabelFa: 'مادی‌سازی برنامه‌های امروز');
  }

  @override
  Future<CommandResult> run(AgentCommandContext ctx) async {
    final dayKey = ctx.payload['dayKey']?.toString() ?? ctx.now.toIso8601String().substring(0, 10);
    final allocations = await ctx.txn.query(
      'planning_allocations',
      where: 'dayKey = ? AND status = ?',
      whereArgs: [dayKey, 'PLANNED'],
    );

    for (final alloc in allocations) {
      final allocId = alloc['id'] as String;
      final commitmentId = alloc['commitmentId'] as String;

      final comms = await ctx.txn.query(
        'planning_commitments',
        where: 'id = ?',
        whereArgs: [commitmentId],
      );
      if (comms.isEmpty) continue;
      final comm = comms.first;

      final taskId = 'task_${ctx.now.millisecondsSinceEpoch}_${allocId.hashCode}';
      await ctx.txn.insert('simple_tasks', {
        'id': taskId,
        'title': comm['title'],
        'isDone': 0,
        'dueDate': dayKey,
        'dueTime': alloc['exactTime'] ?? '09:00',
        'origin': 'PLANNING_MATERIALIZED',
        'createdAt': ctx.now.millisecondsSinceEpoch,
        'updatedAt': ctx.now.millisecondsSinceEpoch,
      });

      await ctx.txn.update(
        'planning_allocations',
        {
          'materializedEntityType': 'TASK',
          'materializedEntityId': taskId,
          'updatedAt': ctx.now.millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [allocId],
      );
    }

    return CommandResult.ok(commandId: id, outputData: {'count': allocations.length});
  }

  @override
  Future<CommandResult?> undo(AgentCommandContext ctx, Map<String, dynamic> inverseData) async {
    return CommandResult.ok(commandId: id);
  }
}
