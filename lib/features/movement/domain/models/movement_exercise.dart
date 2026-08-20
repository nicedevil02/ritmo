/// مدل تمرین ورزشی از جدول movement_exercises
class MovementExercise {
  const MovementExercise({
    required this.id,
    required this.nameFa,
    this.nameEn,
    this.aliases = const [],
    this.muscleGroup,
    this.equipment,
    this.category,
    this.isCustom = false,
    required this.createdAt,
  });

  final String id;
  final String nameFa;
  final String? nameEn;
  final List<String> aliases;
  final String? muscleGroup;
  final String? equipment;
  final String? category;
  final bool isCustom;
  final DateTime createdAt;

  factory MovementExercise.fromMap(Map<String, dynamic> map) {
    return MovementExercise(
      id: map['id'] as String,
      nameFa: map['nameFa'] as String,
      nameEn: map['nameEn'] as String?,
      muscleGroup: map['muscleGroup'] as String?,
      equipment: map['equipment'] as String?,
      category: map['category'] as String?,
      isCustom: (map['isCustom'] as int? ?? 0) == 1,
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nameFa': nameFa,
      'nameEn': nameEn,
      'muscleGroup': muscleGroup,
      'equipment': equipment,
      'category': category,
      'isCustom': isCustom ? 1 : 0,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
