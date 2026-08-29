enum PlanningHorizon { day, week, month }

enum CommitmentImportance { must, should, could }

enum CommitmentFlexibility { fixed, windowed, flexible }

enum WorkKind { deep, light, admin, social, recovery }

enum CommitmentStatus { proposed, accepted, scheduled, done, moved, dropped }

enum AllocationStatus { planned, done, moved, dropped }

enum CommitmentSourceType { goalStep, task, routine, courseSession, konkurItem, manual }

enum CycleStatus { draft, active, closed, abandoned }

extension _Db on Enum {
  String get db => name.toUpperCase();
}

CommitmentImportance importanceFromDb(String? v) => CommitmentImportance.values.firstWhere(
      (e) => e.db == (v ?? '').toUpperCase(),
      orElse: () => CommitmentImportance.should,
    );

class _Unset {
  const _Unset();
}
const Object _unset = _Unset();

class PlanningCycle {
  const PlanningCycle({
    required this.id,
    required this.horizon,
    required this.startDayKey,
    required this.endDayKey,
    required this.status,
    this.title,
    this.theme,
    this.capacityMinutes = 0,
    this.reserveMinutes = 0,
    this.version = 1,
    this.supersedesCycleId,
    required this.createdAt,
    this.activatedAt,
    this.closedAt,
  });

  final String id;
  final PlanningHorizon horizon;
  final String startDayKey;
  final String endDayKey;
  final CycleStatus status;
  final String? title;
  final String? theme;
  final int capacityMinutes;
  final int reserveMinutes;
  final int version;
  final String? supersedesCycleId;
  final int createdAt;
  final int? activatedAt;
  final int? closedAt;

  PlanningCycle copyWith({
    Object? title = _unset,
    Object? theme = _unset,
    Object? status = _unset,
    Object? capacityMinutes = _unset,
    Object? reserveMinutes = _unset,
    Object? version = _unset,
    Object? supersedesCycleId = _unset,
    Object? activatedAt = _unset,
    Object? closedAt = _unset,
  }) {
    return PlanningCycle(
      id: id,
      horizon: horizon,
      startDayKey: startDayKey,
      endDayKey: endDayKey,
      status: identical(status, _unset) ? this.status : status as CycleStatus,
      title: identical(title, _unset) ? this.title : title as String?,
      theme: identical(theme, _unset) ? this.theme : theme as String?,
      capacityMinutes: identical(capacityMinutes, _unset) ? this.capacityMinutes : capacityMinutes as int,
      reserveMinutes: identical(reserveMinutes, _unset) ? this.reserveMinutes : reserveMinutes as int,
      version: identical(version, _unset) ? this.version : version as int,
      supersedesCycleId: identical(supersedesCycleId, _unset) ? this.supersedesCycleId : supersedesCycleId as String?,
      createdAt: createdAt,
      activatedAt: identical(activatedAt, _unset) ? this.activatedAt : activatedAt as int?,
      closedAt: identical(closedAt, _unset) ? this.closedAt : closedAt as int?,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'horizon': horizon.db,
        'startDayKey': startDayKey,
        'endDayKey': endDayKey,
        'status': status.db,
        'title': title,
        'theme': theme,
        'capacityMinutes': capacityMinutes,
        'reserveMinutes': reserveMinutes,
        'version': version,
        'supersedesCycleId': supersedesCycleId,
        'createdAt': createdAt,
        'activatedAt': activatedAt,
        'closedAt': closedAt,
      };

  factory PlanningCycle.fromMap(Map<String, Object?> m) => PlanningCycle(
        id: m['id'] as String,
        horizon: PlanningHorizon.values.firstWhere(
          (e) => e.db == (m['horizon'] as String).toUpperCase(),
          orElse: () => PlanningHorizon.week,
        ),
        startDayKey: m['startDayKey'] as String,
        endDayKey: m['endDayKey'] as String,
        status: CycleStatus.values.firstWhere(
          (e) => e.db == (m['status'] as String? ?? 'DRAFT').toUpperCase(),
          orElse: () => CycleStatus.draft,
        ),
        title: m['title'] as String?,
        theme: m['theme'] as String?,
        capacityMinutes: (m['capacityMinutes'] as num?)?.toInt() ?? 0,
        reserveMinutes: (m['reserveMinutes'] as num?)?.toInt() ?? 0,
        version: (m['version'] as num?)?.toInt() ?? 1,
        supersedesCycleId: m['supersedesCycleId'] as String?,
        createdAt: (m['createdAt'] as num).toInt(),
        activatedAt: (m['activatedAt'] as num?)?.toInt(),
        closedAt: (m['closedAt'] as num?)?.toInt(),
      );
}

class PlanningCommitment {
  const PlanningCommitment({
    required this.id,
    required this.cycleId,
    required this.title,
    this.sourceType = CommitmentSourceType.manual,
    this.sourceId,
    this.goalId,
    this.importance = CommitmentImportance.should,
    this.flexibility = CommitmentFlexibility.flexible,
    this.effortMinutes = 30,
    this.workKind = WorkKind.light,
    this.earliestDayKey,
    this.latestDayKey,
    this.preferredDayPartsJson,
    this.status = CommitmentStatus.proposed,
    this.isUserLocked = false,
    this.origin = 'USER',
    this.planningReason,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String cycleId;
  final String title;
  final CommitmentSourceType sourceType;
  final String? sourceId;
  final String? goalId;
  final CommitmentImportance importance;
  final CommitmentFlexibility flexibility;
  final int effortMinutes;
  final WorkKind workKind;
  final String? earliestDayKey;
  final String? latestDayKey;
  final String? preferredDayPartsJson;
  final CommitmentStatus status;
  final bool isUserLocked;
  final String origin;
  final String? planningReason;
  final int createdAt;
  final int updatedAt;

  PlanningCommitment copyWith({
    Object? cycleId = _unset,
    Object? title = _unset,
    Object? importance = _unset,
    Object? flexibility = _unset,
    Object? effortMinutes = _unset,
    Object? workKind = _unset,
    Object? status = _unset,
    Object? isUserLocked = _unset,
    Object? planningReason = _unset,
    Object? updatedAt = _unset,
  }) {
    return PlanningCommitment(
      id: id,
      cycleId: identical(cycleId, _unset) ? this.cycleId : cycleId as String,
      title: identical(title, _unset) ? this.title : title as String,
      sourceType: sourceType,
      sourceId: sourceId,
      goalId: goalId,
      importance: identical(importance, _unset)
          ? this.importance
          : importance as CommitmentImportance,
      flexibility: identical(flexibility, _unset)
          ? this.flexibility
          : flexibility as CommitmentFlexibility,
      effortMinutes:
          identical(effortMinutes, _unset) ? this.effortMinutes : effortMinutes as int,
      workKind: identical(workKind, _unset) ? this.workKind : workKind as WorkKind,
      earliestDayKey: earliestDayKey,
      latestDayKey: latestDayKey,
      preferredDayPartsJson: preferredDayPartsJson,
      status: identical(status, _unset) ? this.status : status as CommitmentStatus,
      isUserLocked:
          identical(isUserLocked, _unset) ? this.isUserLocked : isUserLocked as bool,
      origin: origin,
      planningReason: identical(planningReason, _unset)
          ? this.planningReason
          : planningReason as String?,
      createdAt: createdAt,
      updatedAt: identical(updatedAt, _unset) ? this.updatedAt : updatedAt as int,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'cycleId': cycleId,
        'title': title,
        'sourceType': sourceType.db,
        'sourceId': sourceId,
        'goalId': goalId,
        'importance': importance.db,
        'flexibility': flexibility.db,
        'effortMinutes': effortMinutes,
        'workKind': workKind.db,
        'earliestDayKey': earliestDayKey,
        'latestDayKey': latestDayKey,
        'preferredDayPartsJson': preferredDayPartsJson,
        'status': status.db,
        'isUserLocked': isUserLocked ? 1 : 0,
        'origin': origin,
        'planningReason': planningReason,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  factory PlanningCommitment.fromMap(Map<String, Object?> m) => PlanningCommitment(
        id: m['id'] as String,
        cycleId: m['cycleId'] as String,
        title: m['title'] as String,
        sourceType: CommitmentSourceType.values.firstWhere(
          (e) => e.db == (m['sourceType'] as String? ?? 'MANUAL').toUpperCase(),
          orElse: () => CommitmentSourceType.manual,
        ),
        sourceId: m['sourceId'] as String?,
        goalId: m['goalId'] as String?,
        importance: importanceFromDb(m['importance'] as String?),
        flexibility: CommitmentFlexibility.values.firstWhere(
          (e) => e.db == (m['flexibility'] as String? ?? 'FLEXIBLE').toUpperCase(),
          orElse: () => CommitmentFlexibility.flexible,
        ),
        effortMinutes: (m['effortMinutes'] as num?)?.toInt() ?? 30,
        workKind: WorkKind.values.firstWhere(
          (e) => e.db == (m['workKind'] as String? ?? 'LIGHT').toUpperCase(),
          orElse: () => WorkKind.light,
        ),
        earliestDayKey: m['earliestDayKey'] as String?,
        latestDayKey: m['latestDayKey'] as String?,
        preferredDayPartsJson: m['preferredDayPartsJson'] as String?,
        status: CommitmentStatus.values.firstWhere(
          (e) => e.db == (m['status'] as String? ?? 'PROPOSED').toUpperCase(),
          orElse: () => CommitmentStatus.proposed,
        ),
        isUserLocked: (m['isUserLocked'] as num?)?.toInt() == 1,
        origin: m['origin'] as String? ?? 'USER',
        planningReason: m['planningReason'] as String?,
        createdAt: (m['createdAt'] as num).toInt(),
        updatedAt: (m['updatedAt'] as num).toInt(),
      );
}

class PlanningAllocation {
  const PlanningAllocation({
    required this.id,
    required this.commitmentId,
    required this.dayKey,
    required this.plannedMinutes,
    this.timeWindowStart,
    this.timeWindowEnd,
    this.exactTime,
    this.status = AllocationStatus.planned,
    this.materializedEntityType,
    this.materializedEntityId,
    required this.idempotencyKey,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String commitmentId;
  final String dayKey;
  final int plannedMinutes;
  final String? timeWindowStart;
  final String? timeWindowEnd;
  final String? exactTime;
  final AllocationStatus status;
  final String? materializedEntityType;
  final String? materializedEntityId;
  final String idempotencyKey;
  final int createdAt;
  final int updatedAt;

  PlanningAllocation copyWith({
    String? id,
    String? commitmentId,
    String? dayKey,
    int? plannedMinutes,
    Object? timeWindowStart = _unset,
    Object? timeWindowEnd = _unset,
    Object? exactTime = _unset,
    AllocationStatus? status,
    Object? materializedEntityType = _unset,
    Object? materializedEntityId = _unset,
    String? idempotencyKey,
    int? createdAt,
    int? updatedAt,
  }) =>
      PlanningAllocation(
        id: id ?? this.id,
        commitmentId: commitmentId ?? this.commitmentId,
        dayKey: dayKey ?? this.dayKey,
        plannedMinutes: plannedMinutes ?? this.plannedMinutes,
        timeWindowStart: identical(timeWindowStart, _unset)
            ? this.timeWindowStart
            : timeWindowStart as String?,
        timeWindowEnd: identical(timeWindowEnd, _unset)
            ? this.timeWindowEnd
            : timeWindowEnd as String?,
        exactTime: identical(exactTime, _unset)
            ? this.exactTime
            : exactTime as String?,
        status: status ?? this.status,
        materializedEntityType: identical(materializedEntityType, _unset)
            ? this.materializedEntityType
            : materializedEntityType as String?,
        materializedEntityId: identical(materializedEntityId, _unset)
            ? this.materializedEntityId
            : materializedEntityId as String?,
        idempotencyKey: idempotencyKey ?? this.idempotencyKey,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'commitmentId': commitmentId,
        'dayKey': dayKey,
        'plannedMinutes': plannedMinutes,
        'timeWindowStart': timeWindowStart,
        'timeWindowEnd': timeWindowEnd,
        'exactTime': exactTime,
        'status': status.db,
        'materializedEntityType': materializedEntityType,
        'materializedEntityId': materializedEntityId,
        'idempotencyKey': idempotencyKey,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  factory PlanningAllocation.fromMap(Map<String, Object?> m) => PlanningAllocation(
        id: m['id'] as String,
        commitmentId: m['commitmentId'] as String,
        dayKey: m['dayKey'] as String,
        plannedMinutes: (m['plannedMinutes'] as num).toInt(),
        timeWindowStart: m['timeWindowStart'] as String?,
        timeWindowEnd: m['timeWindowEnd'] as String?,
        exactTime: m['exactTime'] as String?,
        status: AllocationStatus.values.firstWhere(
          (e) => e.db == (m['status'] as String? ?? 'PLANNED').toUpperCase(),
          orElse: () => AllocationStatus.planned,
        ),
        materializedEntityType: m['materializedEntityType'] as String?,
        materializedEntityId: m['materializedEntityId'] as String?,
        idempotencyKey: m['idempotencyKey'] as String,
        createdAt: (m['createdAt'] as num).toInt(),
        updatedAt: (m['updatedAt'] as num).toInt(),
      );
}

enum UnplacedReason {
  noFreeSlot,
  capacityExceeded,
  outsideAwakeWindow,
  conflictsWithFixed,
  dependencyUnmet,
  tooLongForAnyGap,
  userExcluded,
}
