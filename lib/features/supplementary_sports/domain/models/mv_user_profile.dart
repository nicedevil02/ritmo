import 'mv_enums.dart';

/// Unified Sports Profile for User (Single Source of Truth: ss_user_profile).
/// Preserves 100% of F-01 configuration capabilities.
class MvUserProfile {
  final String id;
  final String goal;
  final String experienceLevel;
  final String trainingLocation;
  final List<String> availableEquipment;
  final int daysPerWeek;
  final List<String> focusAreas;
  final List<String> physicalLimitations;
  final String? limitationNote;
  final String sessionDuration;
  final String? gender;
  final bool onboardingCompleted;
  final bool neighborFriendly;
  final String? programStartDate;
  final int deloadEveryNWeeks;
  final List<int> trainingDays; // Sat0 indexes (0=Sat .. 6=Fri)
  final String splitPattern;
  final MvIntensityTier defaultIntensity;
  final bool usesExternalApp;
  final bool voiceCuesEnabled;
  final bool cycleConsentGranted;
  final int createdAt;
  final int updatedAt;

  const MvUserProfile({
    this.id = 'default',
    this.goal = 'generalFitness',
    this.experienceLevel = 'beginner',
    this.trainingLocation = 'home',
    this.availableEquipment = const ['none'],
    this.daysPerWeek = 3,
    this.focusAreas = const [],
    this.physicalLimitations = const [],
    this.limitationNote,
    this.sessionDuration = 'medium',
    this.gender,
    this.onboardingCompleted = false,
    this.neighborFriendly = false,
    this.programStartDate,
    this.deloadEveryNWeeks = 4,
    this.trainingDays = const [0, 2, 4], // Sat, Mon, Wed
    this.splitPattern = 'AUTO',
    this.defaultIntensity = MvIntensityTier.moderate,
    this.usesExternalApp = false,
    this.voiceCuesEnabled = true,
    this.cycleConsentGranted = false,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Factory for empty/fresh profile.
  factory MvUserProfile.empty() {
    final now = DateTime.now().millisecondsSinceEpoch;
    return MvUserProfile(
      createdAt: now,
      updatedAt: now,
    );
  }

  MvUserProfile copyWith({
    String? id,
    String? goal,
    String? experienceLevel,
    String? trainingLocation,
    List<String>? availableEquipment,
    int? daysPerWeek,
    List<String>? focusAreas,
    List<String>? physicalLimitations,
    String? limitationNote,
    String? sessionDuration,
    String? gender,
    bool? onboardingCompleted,
    bool? neighborFriendly,
    String? programStartDate,
    int? deloadEveryNWeeks,
    List<int>? trainingDays,
    String? splitPattern,
    MvIntensityTier? defaultIntensity,
    bool? usesExternalApp,
    bool? voiceCuesEnabled,
    bool? cycleConsentGranted,
    int? createdAt,
    int? updatedAt,
  }) {
    return MvUserProfile(
      id: id ?? this.id,
      goal: goal ?? this.goal,
      experienceLevel: experienceLevel ?? this.experienceLevel,
      trainingLocation: trainingLocation ?? this.trainingLocation,
      availableEquipment: availableEquipment ?? this.availableEquipment,
      daysPerWeek: daysPerWeek ?? this.daysPerWeek,
      focusAreas: focusAreas ?? this.focusAreas,
      physicalLimitations: physicalLimitations ?? this.physicalLimitations,
      limitationNote: limitationNote ?? this.limitationNote,
      sessionDuration: sessionDuration ?? this.sessionDuration,
      gender: gender ?? this.gender,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      neighborFriendly: neighborFriendly ?? this.neighborFriendly,
      programStartDate: programStartDate ?? this.programStartDate,
      deloadEveryNWeeks: deloadEveryNWeeks ?? this.deloadEveryNWeeks,
      trainingDays: trainingDays ?? this.trainingDays,
      splitPattern: splitPattern ?? this.splitPattern,
      defaultIntensity: defaultIntensity ?? this.defaultIntensity,
      usesExternalApp: usesExternalApp ?? this.usesExternalApp,
      voiceCuesEnabled: voiceCuesEnabled ?? this.voiceCuesEnabled,
      cycleConsentGranted: cycleConsentGranted ?? this.cycleConsentGranted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'goal': goal,
      'experienceLevel': experienceLevel,
      'trainingLocation': trainingLocation,
      'availableEquipment': availableEquipment.join(','),
      'daysPerWeek': daysPerWeek,
      'focusAreas': focusAreas.join(','),
      'physicalLimitations': physicalLimitations.join(','),
      'limitationNote': limitationNote,
      'sessionDuration': sessionDuration,
      'gender': gender,
      'onboardingCompleted': onboardingCompleted ? 1 : 0,
      'neighborFriendly': neighborFriendly ? 1 : 0,
      'programStartDate': programStartDate,
      'deloadEveryNWeeks': deloadEveryNWeeks,
      'trainingDays': trainingDays.join(','),
      'splitPattern': splitPattern,
      'defaultIntensity': defaultIntensity.code,
      'usesExternalApp': usesExternalApp ? 1 : 0,
      'voiceCuesEnabled': voiceCuesEnabled ? 1 : 0,
      'cycleConsentGranted': cycleConsentGranted ? 1 : 0,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  factory MvUserProfile.fromMap(Map<String, dynamic> map) {
    List<String> parseList(dynamic val) {
      if (val == null) return [];
      final s = val.toString().trim();
      if (s.isEmpty) return [];
      return s.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    }

    List<int> parseDays(dynamic val) {
      if (val == null) return [0, 2, 4];
      final list = parseList(val);
      final res = list.map((e) => int.tryParse(e)).whereType<int>().toList();
      return res.isEmpty ? [0, 2, 4] : res;
    }

    return MvUserProfile(
      id: (map['id'] as String?) ?? 'default',
      goal: (map['goal'] as String?) ?? 'generalFitness',
      experienceLevel: (map['experienceLevel'] as String?) ?? 'beginner',
      trainingLocation: (map['trainingLocation'] as String?) ?? 'home',
      availableEquipment: parseList(map['availableEquipment']),
      daysPerWeek: (map['daysPerWeek'] as num?)?.toInt() ?? 3,
      focusAreas: parseList(map['focusAreas']),
      physicalLimitations: parseList(map['physicalLimitations']),
      limitationNote: map['limitationNote'] as String?,
      sessionDuration: (map['sessionDuration'] as String?) ?? 'medium',
      gender: map['gender'] as String?,
      onboardingCompleted: (map['onboardingCompleted'] as num?)?.toInt() == 1,
      neighborFriendly: (map['neighborFriendly'] as num?)?.toInt() == 1,
      programStartDate: map['programStartDate'] as String?,
      deloadEveryNWeeks: (map['deloadEveryNWeeks'] as num?)?.toInt() ?? 4,
      trainingDays: parseDays(map['trainingDays']),
      splitPattern: (map['splitPattern'] as String?) ?? 'AUTO',
      defaultIntensity: MvIntensityTier.fromCode(map['defaultIntensity'] as String?),
      usesExternalApp: (map['usesExternalApp'] as num?)?.toInt() == 1,
      voiceCuesEnabled: map['voiceCuesEnabled'] != null ? (map['voiceCuesEnabled'] as num).toInt() == 1 : true,
      cycleConsentGranted: (map['cycleConsentGranted'] as num?)?.toInt() == 1,
      createdAt: (map['createdAt'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
      updatedAt: (map['updatedAt'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
    );
  }
}
