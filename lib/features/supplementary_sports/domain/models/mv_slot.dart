import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'mv_enums.dart';

/// Unified Daily Prescription / Slot Model ("برنامهٔ روز").
///
/// Serves as the Single Source of Truth for daily prescribed movement & workouts.
/// Harmonizes `SessionPrescription`, `WeekPlanItem`, and `PlannedSlot`.
class MvSlot {
  final String id;
  final String dateIso;
  final int cycleWeek;
  final MvSlotType slotType;
  final String? kindCode;
  final String? routineId;
  final String? occurrenceId;
  final String? plannedTime;
  final List<String> focusCodes;
  final int targetMinutes;
  final MvIntensityTier intensityTier;
  final int? targetRpe;
  final int? actualRpe;
  final String headlineFa;
  final String? coachNoteFa;
  final String source;
  final String? sourceRef;
  final bool isLocked;
  final MvSlotStatus status;
  final String? movedToDateIso;
  final String? legacyPlanId;
  final String? workoutPlanId;
  final String? workoutLogId;
  final String? reasonKey;
  final Map<String, String>? reasonParams;
  final int createdAt;
  final int updatedAt;

  const MvSlot({
    required this.id,
    required this.dateIso,
    this.cycleWeek = 1,
    this.slotType = MvSlotType.strength,
    this.kindCode,
    this.routineId,
    this.occurrenceId,
    this.plannedTime,
    this.focusCodes = const [],
    this.targetMinutes = 30,
    this.intensityTier = MvIntensityTier.moderate,
    this.targetRpe,
    this.actualRpe,
    required this.headlineFa,
    this.coachNoteFa,
    this.source = 'GENERATED',
    this.sourceRef,
    this.isLocked = false,
    this.status = MvSlotStatus.planned,
    this.movedToDateIso,
    this.legacyPlanId,
    this.workoutPlanId,
    this.workoutLogId,
    this.reasonKey,
    this.reasonParams,
    required this.createdAt,
    required this.updatedAt,
  }) : assert(
         (slotType != MvSlotType.sport &&
                 slotType != MvSlotType.outdoor &&
                 slotType != MvSlotType.cardio) ||
             kindCode != null,
         'kindCode is required when slotType is sport, outdoor, or cardio',
       );

  bool get isRest => slotType == MvSlotType.rest;
  bool get isCompleted => status == MvSlotStatus.done;
  bool get isSkipped => status == MvSlotStatus.skipped;
  bool get isPartial => status == MvSlotStatus.partial;
  bool get isMoved => status == MvSlotStatus.moved;

  MvSlot copyWith({
    String? id,
    String? dateIso,
    int? cycleWeek,
    MvSlotType? slotType,
    String? kindCode,
    String? routineId,
    String? occurrenceId,
    String? plannedTime,
    List<String>? focusCodes,
    int? targetMinutes,
    MvIntensityTier? intensityTier,
    int? targetRpe,
    int? actualRpe,
    String? headlineFa,
    String? coachNoteFa,
    String? source,
    String? sourceRef,
    bool? isLocked,
    MvSlotStatus? status,
    String? movedToDateIso,
    String? legacyPlanId,
    String? workoutPlanId,
    String? workoutLogId,
    String? reasonKey,
    Map<String, String>? reasonParams,
    int? createdAt,
    int? updatedAt,
  }) {
    return MvSlot(
      id: id ?? this.id,
      dateIso: dateIso ?? this.dateIso,
      cycleWeek: cycleWeek ?? this.cycleWeek,
      slotType: slotType ?? this.slotType,
      kindCode: kindCode ?? this.kindCode,
      routineId: routineId ?? this.routineId,
      occurrenceId: occurrenceId ?? this.occurrenceId,
      plannedTime: plannedTime ?? this.plannedTime,
      focusCodes: focusCodes ?? this.focusCodes,
      targetMinutes: targetMinutes ?? this.targetMinutes,
      intensityTier: intensityTier ?? this.intensityTier,
      targetRpe: targetRpe ?? this.targetRpe,
      actualRpe: actualRpe ?? this.actualRpe,
      headlineFa: headlineFa ?? this.headlineFa,
      coachNoteFa: coachNoteFa ?? this.coachNoteFa,
      source: source ?? this.source,
      sourceRef: sourceRef ?? this.sourceRef,
      isLocked: isLocked ?? this.isLocked,
      status: status ?? this.status,
      movedToDateIso: movedToDateIso ?? this.movedToDateIso,
      legacyPlanId: legacyPlanId ?? this.legacyPlanId,
      workoutPlanId: workoutPlanId ?? this.workoutPlanId,
      workoutLogId: workoutLogId ?? this.workoutLogId,
      reasonKey: reasonKey ?? this.reasonKey,
      reasonParams: reasonParams ?? this.reasonParams,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'dateIso': dateIso,
      'cycleWeek': cycleWeek,
      'slotType': slotType.code,
      'kindCode': kindCode,
      'routineId': routineId,
      'plannedTime': plannedTime,
      'focusCodes': focusCodes.join(','),
      'targetMinutes': targetMinutes,
      'intensityTier': intensityTier.code,
      'targetRpe': targetRpe,
      'actualRpe': actualRpe,
      'headlineFa': headlineFa,
      'coachNoteFa': coachNoteFa,
      'source': source,
      'sourceRef': sourceRef,
      'isLocked': isLocked ? 1 : 0,
      'status': status.code,
      'movedToDateIso': movedToDateIso,
      'legacyPlanId': legacyPlanId,
      'workoutPlanId': workoutPlanId,
      'workoutLogId': workoutLogId,
      'reasonKey': reasonKey,
      'reasonParams': reasonParams != null ? jsonEncode(reasonParams) : null,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  static Map<String, String>? _parseReasonParams(dynamic raw) {
    if (raw == null) return null;
    if (raw is Map) {
      return raw.map((k, v) => MapEntry(k.toString(), v.toString()));
    }
    if (raw is String && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          return decoded.map((k, v) => MapEntry(k.toString(), v.toString()));
        }
      } catch (_) {}
    }
    return null;
  }

  factory MvSlot.fromMap(Map<String, dynamic> map) {
    final rawFocus = map['focusCodes'] as String? ?? '';
    final focusList = rawFocus.isEmpty
        ? <String>[]
        : rawFocus
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList();

    return MvSlot(
      id: map['id'] as String,
      dateIso: map['dateIso'] as String,
      cycleWeek: (map['cycleWeek'] as num?)?.toInt() ?? 1,
      slotType: MvSlotType.fromCode(map['slotType'] as String?),
      kindCode: map['kindCode'] as String?,
      routineId: map['routineId'] as String?,
      occurrenceId: map['occurrenceId'] as String?,
      plannedTime: map['plannedTime'] as String?,
      focusCodes: focusList,
      targetMinutes: (map['targetMinutes'] as num?)?.toInt() ?? 30,
      intensityTier: MvIntensityTier.fromCode(map['intensityTier'] as String?),
      targetRpe: (map['targetRpe'] as num?)?.toInt(),
      actualRpe: (map['actualRpe'] as num?)?.toInt(),
      headlineFa: (map['headlineFa'] as String?) ?? 'برنامهٔ امروز',
      coachNoteFa: map['coachNoteFa'] as String?,
      source: (map['source'] as String?) ?? 'GENERATED',
      sourceRef: map['sourceRef'] as String?,
      isLocked: (map['isLocked'] as num?)?.toInt() == 1,
      status: MvSlotStatus.fromCode(map['status'] as String?),
      movedToDateIso: map['movedToDateIso'] as String?,
      legacyPlanId: map['legacyPlanId'] as String?,
      workoutPlanId: map['workoutPlanId'] as String?,
      workoutLogId: map['workoutLogId'] as String?,
      reasonKey: map['reasonKey'] as String?,
      reasonParams: _parseReasonParams(map['reasonParams']),
      createdAt:
          (map['createdAt'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch,
      updatedAt:
          (map['updatedAt'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MvSlot &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          dateIso == other.dateIso &&
          cycleWeek == other.cycleWeek &&
          slotType == other.slotType &&
          kindCode == other.kindCode &&
          routineId == other.routineId &&
          occurrenceId == other.occurrenceId &&
          plannedTime == other.plannedTime &&
          listEquals(focusCodes, other.focusCodes) &&
          targetMinutes == other.targetMinutes &&
          intensityTier == other.intensityTier &&
          targetRpe == other.targetRpe &&
          actualRpe == other.actualRpe &&
          headlineFa == other.headlineFa &&
          coachNoteFa == other.coachNoteFa &&
          source == other.source &&
          sourceRef == other.sourceRef &&
          isLocked == other.isLocked &&
          status == other.status &&
          movedToDateIso == other.movedToDateIso &&
          legacyPlanId == other.legacyPlanId &&
          workoutPlanId == other.workoutPlanId &&
          workoutLogId == other.workoutLogId &&
          reasonKey == other.reasonKey &&
          mapEquals(reasonParams, other.reasonParams) &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode =>
      id.hashCode ^
      dateIso.hashCode ^
      cycleWeek.hashCode ^
      slotType.hashCode ^
      kindCode.hashCode ^
      routineId.hashCode ^
      occurrenceId.hashCode ^
      plannedTime.hashCode ^
      Object.hashAll(focusCodes) ^
      targetMinutes.hashCode ^
      intensityTier.hashCode ^
      targetRpe.hashCode ^
      actualRpe.hashCode ^
      headlineFa.hashCode ^
      coachNoteFa.hashCode ^
      source.hashCode ^
      sourceRef.hashCode ^
      isLocked.hashCode ^
      status.hashCode ^
      movedToDateIso.hashCode ^
      legacyPlanId.hashCode ^
      workoutPlanId.hashCode ^
      workoutLogId.hashCode ^
      reasonKey.hashCode ^
      (reasonParams != null ? Object.hashAll(reasonParams!.entries) : 0) ^
      createdAt.hashCode ^
      updatedAt.hashCode;
}
