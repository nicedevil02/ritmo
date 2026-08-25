/// Unified Exercise Model with full metadata from 268-exercise pool.
class MvExercise {
  final String id;
  final String name;
  final String? nameEn;
  final String category;
  final String? equipment;
  final String? instructions;
  final String? videoUrl;
  final bool isCustom;
  final bool changeSides;
  final bool noisy;
  final int impact;
  final int durationSeconds;
  final int defaultReps;
  final String? repsHint;
  final List<String> toolsRequired;
  final String? constraintNegative;
  final Map<String, dynamic> muscleIntensity;
  final int skillRequired;
  final int skillMax;
  final double strengthVsCardio;
  final String? code;
  final String? animationAsset;

  const MvExercise({
    required this.id,
    required this.name,
    this.nameEn,
    required this.category,
    this.equipment,
    this.instructions,
    this.videoUrl,
    this.isCustom = false,
    this.changeSides = false,
    this.noisy = false,
    this.impact = 0,
    this.durationSeconds = 0,
    this.defaultReps = 10,
    this.repsHint,
    this.toolsRequired = const [],
    this.constraintNegative,
    this.muscleIntensity = const {},
    this.skillRequired = 0,
    this.skillMax = 5,
    this.strengthVsCardio = 0.0,
    this.code,
    this.animationAsset,
  });

  bool get isTimeBased => durationSeconds > 0 && defaultReps <= 0;
  bool get hasAnimation => animationAsset != null && animationAsset!.isNotEmpty;
  String? get descriptionFa => instructions;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'nameEn': nameEn,
      'category': category,
      'equipment': equipment,
      'instructions': instructions,
      'videoUrl': videoUrl,
      'isCustom': isCustom ? 1 : 0,
      'changeSides': changeSides ? 1 : 0,
      'noisy': noisy ? 1 : 0,
      'impact': impact,
      'durationSeconds': durationSeconds,
      'defaultReps': defaultReps,
      'repsHint': repsHint,
      'toolsRequired': toolsRequired.join(','),
      'constraintNegative': constraintNegative,
      'skillRequired': skillRequired,
      'skill_max': skillMax,
      'strengthVsCardio': strengthVsCardio,
      'code': code,
      'animation_asset': animationAsset,
    };
  }

  factory MvExercise.fromMap(Map<String, dynamic> map) {
    List<String> parseTools(dynamic val) {
      if (val == null) return [];
      final s = val
          .toString()
          .replaceAll('[', '')
          .replaceAll(']', '')
          .replaceAll('"', '')
          .trim();
      if (s.isEmpty) return [];
      return s
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    return MvExercise(
      id: map['id'] as String,
      name: map['name'] as String,
      nameEn: map['nameEn'] as String?,
      category: (map['category'] as String?) ?? 'strength',
      equipment: map['equipment'] as String?,
      instructions: map['instructions'] as String?,
      videoUrl: map['videoUrl'] as String?,
      isCustom: (map['isCustom'] as num?)?.toInt() == 1,
      changeSides: (map['changeSides'] as num?)?.toInt() == 1,
      noisy: (map['noisy'] as num?)?.toInt() == 1,
      impact: (map['impact'] as num?)?.toInt() ?? 0,
      durationSeconds: (map['durationSeconds'] as num?)?.toInt() ?? 0,
      defaultReps: (map['defaultReps'] as num?)?.toInt() ?? 10,
      repsHint: map['repsHint'] as String?,
      toolsRequired: parseTools(map['toolsRequired']),
      constraintNegative: map['constraintNegative'] as String?,
      skillRequired: (map['skillRequired'] as num?)?.toInt() ?? 0,
      skillMax: (map['skill_max'] as num?)?.toInt() ?? 5,
      strengthVsCardio: (map['strengthVsCardio'] as num?)?.toDouble() ?? 0.0,
      code: map['code'] as String?,
      animationAsset: map['animation_asset'] as String?,
    );
  }
}

/// 12 Standard Anatomical Muscle Groups (Section 1.5, 3.2).
class MvMuscleGroup {
  final String code;
  final String titleFa;
  final String region; // UPPER, LOWER, CORE, CARDIO, MOBILITY, FULL
  final String emoji;
  final int sortOrder;

  const MvMuscleGroup({
    required this.code,
    required this.titleFa,
    required this.region,
    required this.emoji,
    required this.sortOrder,
  });

  static const List<MvMuscleGroup> all = [
    MvMuscleGroup(
      code: 'CHEST',
      titleFa: 'سینه',
      region: 'UPPER',
      emoji: '🫁',
      sortOrder: 1,
    ),
    MvMuscleGroup(
      code: 'SHOULDER',
      titleFa: 'سرشانه',
      region: 'UPPER',
      emoji: '🎯',
      sortOrder: 2,
    ),
    MvMuscleGroup(
      code: 'BICEPS',
      titleFa: 'جلوبازو',
      region: 'UPPER',
      emoji: '💪',
      sortOrder: 3,
    ),
    MvMuscleGroup(
      code: 'TRICEPS',
      titleFa: 'پشت‌بازو',
      region: 'UPPER',
      emoji: '🦾',
      sortOrder: 4,
    ),
    MvMuscleGroup(
      code: 'BACK',
      titleFa: 'زیربغل و پشت',
      region: 'UPPER',
      emoji: '🪽',
      sortOrder: 5,
    ),
    MvMuscleGroup(
      code: 'CORE',
      titleFa: 'شکم و مرکز',
      region: 'CORE',
      emoji: '🎽',
      sortOrder: 6,
    ),
    MvMuscleGroup(
      code: 'QUADS_GLUTES',
      titleFa: 'ران و باسن',
      region: 'LOWER',
      emoji: '🦵',
      sortOrder: 7,
    ),
    MvMuscleGroup(
      code: 'HAMSTRINGS',
      titleFa: 'پشت ران',
      region: 'LOWER',
      emoji: '🦿',
      sortOrder: 8,
    ),
    MvMuscleGroup(
      code: 'CALVES',
      titleFa: 'ساق پا',
      region: 'LOWER',
      emoji: '🎯',
      sortOrder: 9,
    ),
    MvMuscleGroup(
      code: 'CARDIO',
      titleFa: 'هوازی',
      region: 'CARDIO',
      emoji: '🫀',
      sortOrder: 10,
    ),
    MvMuscleGroup(
      code: 'MOBILITY',
      titleFa: 'تحرک و کشش',
      region: 'MOBILITY',
      emoji: '🧘',
      sortOrder: 11,
    ),
    MvMuscleGroup(
      code: 'FULL_BODY',
      titleFa: 'کل بدن',
      region: 'FULL',
      emoji: '🔥',
      sortOrder: 12,
    ),
  ];

  static MvMuscleGroup? findByCode(String code) {
    final upper = code.toUpperCase().trim();
    for (final m in all) {
      if (m.code == upper) return m;
    }
    return null;
  }
}
