import 'package:flutter/foundation.dart';

/// مدل چک‌این آمادگی روزانه حرکت (Gate 5)
/// تمام ۵ فیلد مقیاس ۱ تا ۵ اختیاری هستند.
@immutable
class MovementReadinessCheckin {
  const MovementReadinessCheckin({
    required this.id,
    required this.dateIso,
    this.sleep,
    this.energy,
    this.soreness,
    this.stress,
    this.availableMinutes,
    required this.createdAt,
  });

  final String id;
  final String dateIso;
  final int? sleep; // ۱ تا ۵
  final int? energy; // ۱ تا ۵
  final int? soreness; // ۱ تا ۵
  final int? stress; // ۱ تا ۵
  final int? availableMinutes;
  final DateTime createdAt;

  int get filledFieldsCount {
    int count = 0;
    if (sleep != null) count++;
    if (energy != null) count++;
    if (soreness != null) count++;
    if (stress != null) count++;
    if (availableMinutes != null) count++;
    return count;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'dateIso': dateIso,
      'sleep': sleep,
      'energy': energy,
      'soreness': soreness,
      'stress': stress,
      'availableMinutes': availableMinutes,
      'createdAt': createdAt.toUtc().toIso8601String(),
    };
  }

  factory MovementReadinessCheckin.fromMap(Map<String, dynamic> map) {
    return MovementReadinessCheckin(
      id: map['id'] as String,
      dateIso: map['dateIso'] as String,
      sleep: map['sleep'] as int?,
      energy: map['energy'] as int?,
      soreness: map['soreness'] as int?,
      stress: map['stress'] as int?,
      availableMinutes: map['availableMinutes'] as int?,
      createdAt: DateTime.parse(map['createdAt'] as String).toLocal(),
    );
  }

  MovementReadinessCheckin copyWith({
    String? id,
    String? dateIso,
    int? sleep,
    int? energy,
    int? soreness,
    int? stress,
    int? availableMinutes,
    DateTime? createdAt,
  }) {
    return MovementReadinessCheckin(
      id: id ?? this.id,
      dateIso: dateIso ?? this.dateIso,
      sleep: sleep ?? this.sleep,
      energy: energy ?? this.energy,
      soreness: soreness ?? this.soreness,
      stress: stress ?? this.stress,
      availableMinutes: availableMinutes ?? this.availableMinutes,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
