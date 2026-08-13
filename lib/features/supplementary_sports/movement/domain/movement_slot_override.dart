// lib/features/supplementary_sports/movement/domain/movement_slot_override.dart

library;

/// This-week exception for a movement routine occurrence.
enum MovementSlotAction {
  skip,
  move,
  retime,
  light;

  String get code => name.toUpperCase();

  static MovementSlotAction fromCode(String? raw) {
    final code = (raw ?? '').toUpperCase();
    return MovementSlotAction.values.firstWhere(
      (a) => a.code == code,
      orElse: () => MovementSlotAction.skip,
    );
  }
}

class MovementSlotOverride {
  const MovementSlotOverride({
    required this.id,
    required this.routineId,
    required this.dateIso,
    required this.action,
    this.newDateIso,
    this.newTime,
    required this.createdAt,
  });

  final String id;
  final String routineId;

  /// Original template date (yyyy-MM-dd).
  final String dateIso;
  final MovementSlotAction action;

  /// Destination date for [MovementSlotAction.move].
  final String? newDateIso;

  /// New clock time `HH:mm` for RETIME / MOVE.
  final String? newTime;
  final int createdAt;

  factory MovementSlotOverride.fromMap(Map<String, Object?> map) {
    return MovementSlotOverride(
      id: map['id']?.toString() ?? '',
      routineId: map['routineId']?.toString() ?? '',
      dateIso: map['dateIso']?.toString() ?? '',
      action: MovementSlotAction.fromCode(map['action']?.toString()),
      newDateIso: map['newDateIso']?.toString(),
      newTime: map['newTime']?.toString(),
      createdAt: (map['createdAt'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'id': id,
      'routineId': routineId,
      'dateIso': dateIso,
      'action': action.code,
      'newDateIso': newDateIso,
      'newTime': newTime,
      'createdAt': createdAt,
    };
  }
}
