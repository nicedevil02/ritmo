/// This-Week Slot Exception / Override Model (`movement_slot_overrides`).
/// Follows F-25.
class MvSlotOverride {
  final String id;
  final String routineId;
  final String dateIso;
  final String action; // SKIP, RETIME, MOVE, LIGHT
  final String? newDateIso;
  final String? newTime;
  final int createdAt;

  const MvSlotOverride({
    required this.id,
    required this.routineId,
    required this.dateIso,
    required this.action,
    this.newDateIso,
    this.newTime,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'routineId': routineId,
      'dateIso': dateIso,
      'action': action,
      'newDateIso': newDateIso,
      'newTime': newTime,
      'createdAt': createdAt,
    };
  }

  factory MvSlotOverride.fromMap(Map<String, dynamic> map) {
    return MvSlotOverride(
      id: map['id'] as String,
      routineId: map['routineId'] as String,
      dateIso: map['dateIso'] as String,
      action: map['action'] as String,
      newDateIso: map['newDateIso'] as String?,
      newTime: map['newTime'] as String?,
      createdAt: (map['createdAt'] as num).toInt(),
    );
  }
}
