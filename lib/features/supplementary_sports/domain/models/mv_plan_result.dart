import 'package:flutter/foundation.dart';
import 'mv_decision.dart';
import 'mv_movement_kind.dart';
import 'mv_slot.dart';

/// نتیجهٔ تولید برنامهٔ هفتگی در PlanEngine v2 (S3-T4).
@immutable
class MvPlanResult {
  final List<MvSlot> slots;
  final List<MvDecision> stageDecisions;
  final List<String> notes;
  final bool hasConflict;
  final String? conflictNote;
  final Map<String, MvMovementKind> allowedKinds;

  const MvPlanResult({
    required this.slots,
    this.stageDecisions = const [],
    this.notes = const [],
    this.hasConflict = false,
    this.conflictNote,
    this.allowedKinds = const {},
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MvPlanResult &&
          runtimeType == other.runtimeType &&
          listEquals(slots, other.slots) &&
          listEquals(stageDecisions, other.stageDecisions) &&
          listEquals(notes, other.notes) &&
          hasConflict == other.hasConflict &&
          conflictNote == other.conflictNote &&
          mapEquals(allowedKinds, other.allowedKinds);

  @override
  int get hashCode =>
      Object.hashAll(slots) ^
      Object.hashAll(stageDecisions) ^
      Object.hashAll(notes) ^
      hasConflict.hashCode ^
      conflictNote.hashCode;
}
