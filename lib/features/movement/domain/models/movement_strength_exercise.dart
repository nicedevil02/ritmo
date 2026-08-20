import 'dart:convert';

/// مدل حرکت ورزشی در یک روز تمرین قدرتی
class MovementStrengthExercise {
  const MovementStrengthExercise({
    required this.id,
    required this.dayId,
    required this.orderIndex,
    required this.nameFa,
    required this.muscleGroup,
    required this.sets,
    required this.repsMin,
    required this.repsMax,
    this.restSec = 60,
    this.formTips = const [],
    this.alternatives = const [],
    this.mediaRef,
  });

  final String id;
  final String dayId;
  final int orderIndex;
  final String nameFa;
  final String muscleGroup;
  final int sets;
  final int repsMin;
  final int repsMax;
  final int restSec;
  final List<String> formTips; // max 3 tips
  final List<String> alternatives; // min 3 alternatives
  final String? mediaRef;

  String get repsDisplay {
    if (repsMin == repsMax) return '$repsMin';
    return '$repsMin - $repsMax';
  }

  MovementStrengthExercise copyWith({
    String? id,
    String? dayId,
    int? orderIndex,
    String? nameFa,
    String? muscleGroup,
    int? sets,
    int? repsMin,
    int? repsMax,
    int? restSec,
    List<String>? formTips,
    List<String>? alternatives,
    String? mediaRef,
  }) {
    return MovementStrengthExercise(
      id: id ?? this.id,
      dayId: dayId ?? this.dayId,
      orderIndex: orderIndex ?? this.orderIndex,
      nameFa: nameFa ?? this.nameFa,
      muscleGroup: muscleGroup ?? this.muscleGroup,
      sets: sets ?? this.sets,
      repsMin: repsMin ?? this.repsMin,
      repsMax: repsMax ?? this.repsMax,
      restSec: restSec ?? this.restSec,
      formTips: formTips ?? this.formTips,
      alternatives: alternatives ?? this.alternatives,
      mediaRef: mediaRef ?? this.mediaRef,
    );
  }

  factory MovementStrengthExercise.fromMap(Map<String, dynamic> map) {
    List<String> parseStringList(dynamic raw) {
      if (raw == null) return [];
      if (raw is List) return raw.map((e) => e.toString()).toList();
      try {
        final decoded = jsonDecode(raw.toString());
        if (decoded is List) return decoded.map((e) => e.toString()).toList();
      } catch (_) {}
      return [];
    }

    return MovementStrengthExercise(
      id: map['id'] as String,
      dayId: map['dayId'] as String,
      orderIndex: (map['orderIndex'] as int?) ?? 0,
      nameFa: (map['nameFa'] as String?) ?? '',
      muscleGroup: (map['muscleGroup'] as String?) ?? 'کل بدن',
      sets: (map['sets'] as int?) ?? 3,
      repsMin: (map['repsMin'] as int?) ?? 8,
      repsMax: (map['repsMax'] as int?) ?? 12,
      restSec: (map['restSec'] as int?) ?? 60,
      formTips: parseStringList(map['formTipsJson']),
      alternatives: parseStringList(map['alternativesJson']),
      mediaRef: map['mediaRef'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'dayId': dayId,
      'orderIndex': orderIndex,
      'nameFa': nameFa,
      'muscleGroup': muscleGroup,
      'sets': sets,
      'repsMin': repsMin,
      'repsMax': repsMax,
      'restSec': restSec,
      'formTipsJson': jsonEncode(formTips),
      'alternativesJson': jsonEncode(alternatives),
      'mediaRef': mediaRef,
    };
  }
}
