import 'dart:convert';
import 'package:ritmo/features/movement/domain/models/movement_strength_exercise.dart';

/// مدل روز تمرینی در برنامهٔ قدرتی
class MovementStrengthDay {
  const MovementStrengthDay({
    required this.id,
    required this.programId,
    required this.weekIndex,
    required this.weekday,
    required this.name,
    this.targetMuscles = const [],
    required this.estimatedMinutes,
    required this.orderIndex,
    this.exercises = const [],
  });

  final String id;
  final String programId;
  final int weekIndex;
  final int weekday; // 1 to 7 (Saturday=1)
  final String name;
  final List<String> targetMuscles;
  final int estimatedMinutes;
  final int orderIndex;
  final List<MovementStrengthExercise> exercises;

  MovementStrengthDay copyWith({
    String? id,
    String? programId,
    int? weekIndex,
    int? weekday,
    String? name,
    List<String>? targetMuscles,
    int? estimatedMinutes,
    int? orderIndex,
    List<MovementStrengthExercise>? exercises,
  }) {
    return MovementStrengthDay(
      id: id ?? this.id,
      programId: programId ?? this.programId,
      weekIndex: weekIndex ?? this.weekIndex,
      weekday: weekday ?? this.weekday,
      name: name ?? this.name,
      targetMuscles: targetMuscles ?? this.targetMuscles,
      estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
      orderIndex: orderIndex ?? this.orderIndex,
      exercises: exercises ?? this.exercises,
    );
  }

  factory MovementStrengthDay.fromMap(
    Map<String, dynamic> map, {
    List<MovementStrengthExercise> exercises = const [],
  }) {
    List<String> parseStringList(dynamic raw) {
      if (raw == null) return [];
      if (raw is List) return raw.map((e) => e.toString()).toList();
      try {
        final decoded = jsonDecode(raw.toString());
        if (decoded is List) return decoded.map((e) => e.toString()).toList();
      } catch (_) {}
      return [];
    }

    return MovementStrengthDay(
      id: map['id'] as String,
      programId: map['programId'] as String,
      weekIndex: (map['weekIndex'] as int?) ?? 1,
      weekday: (map['weekday'] as int?) ?? 1,
      name: (map['name'] as String?) ?? 'جلسهٔ قدرتی',
      targetMuscles: parseStringList(map['targetMusclesJson']),
      estimatedMinutes: (map['estimatedMinutes'] as int?) ?? 30,
      orderIndex: (map['orderIndex'] as int?) ?? 0,
      exercises: exercises,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'programId': programId,
      'weekIndex': weekIndex,
      'weekday': weekday,
      'name': name,
      'targetMusclesJson': jsonEncode(targetMuscles),
      'estimatedMinutes': estimatedMinutes,
      'orderIndex': orderIndex,
    };
  }
}
