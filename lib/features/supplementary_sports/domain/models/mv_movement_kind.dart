import 'mv_enums.dart';

/// Canonical uppercase movement kind codes for strong typing.
abstract final class MvKindCodes {
  static const walking = 'WALKING';
  static const running = 'RUNNING';
  static const cycling = 'CYCLING';
  static const swimming = 'SWIMMING';
  static const football = 'FOOTBALL';
  static const futsal = 'FUTSAL';
  static const basketball = 'BASKETBALL';
  static const volleyball = 'VOLLEYBALL';
  static const tennis = 'TENNIS';
  static const padel = 'PADEL';
  static const hiking = 'HIKING';
  static const yoga = 'YOGA';
  static const pilates = 'PILATES';
  static const bodyweight = 'BODYWEIGHT';
  static const stretching = 'STRETCHING';
}

enum MovementFamily {
  endurance('ENDURANCE', 'هوازی و استقامتی', '🏃'),
  sport('SPORT', 'ورزش و بازی‌های توپی', '⚽'),
  mindBody('MIND_BODY', 'ذهن و بدن', '🧘'),
  outdoor('OUTDOOR', 'طبیعت و فضای باز', '🏔'),
  martialSkill('MARTIAL_SKILL', 'رزمی و مهارت بدنی', '🥋'),
  daily('DAILY', 'فعالیت‌های روزمره', '🚶'),
  strength('STRENGTH', 'قدرتی و بدنسازی', '🏋️');

  const MovementFamily(this.code, this.titleFa, this.emoji);
  final String code;
  final String titleFa;
  final String emoji;

  static MovementFamily fromCode(String code) {
    return MovementFamily.values.firstWhere(
      (f) => f.code.toUpperCase() == code.toUpperCase(),
      orElse: () => MovementFamily.endurance,
    );
  }
}

enum MovementMetric {
  duration('DURATION', 'دقیقه'),
  distance('DISTANCE', 'کیلومتر'),
  laps('LAPS', 'دور/طول'),
  elevation('ELEVATION', 'متر ارتفاع'),
  steps('STEPS', 'گام'),
  sets('SETS', 'ست'),
  none('NONE', '');

  const MovementMetric(this.code, this.unitFa);
  final String code;
  final String unitFa;

  static MovementMetric fromCode(String code) {
    return MovementMetric.values.firstWhere(
      (m) => m.code.toUpperCase() == code.toUpperCase(),
      orElse: () => MovementMetric.duration,
    );
  }
}

enum MovementIntensity {
  low('LOW', 'سبک', 0.8),
  medium('MEDIUM', 'متوسط', 1.0),
  high('HIGH', 'شدید', 1.25);

  const MovementIntensity(this.code, this.titleFa, this.metMultiplier);
  final String code;
  final String titleFa;
  final double metMultiplier;

  static MovementIntensity fromCode(String code) {
    return MovementIntensity.values.firstWhere(
      (i) => i.code.toUpperCase() == code.toUpperCase(),
      orElse: () => MovementIntensity.medium,
    );
  }
}

typedef MvFamily = MovementFamily;
typedef MvMetric = MovementMetric;
typedef MvIntensity = MovementIntensity;
typedef MovementKind = MvMovementKind;

/// Single Source of Truth Model for Movement Activity Kinds (`movement_kinds`).
class MvMovementKind {
  final String code; // UPPER_SNAKE_CASE
  final String titleFa;
  final String emoji;
  final MovementFamily family;
  final double baseMet;
  final double metLow;
  final double metHigh;
  final MovementMetric primaryMetric;
  final MovementMetric? secondaryMetric;
  final bool isOutdoor;
  final bool isSocial;
  final bool needsVenue;
  final String? seasonMask; // "1,2,3,7,8,9"
  final int jointImpact; // 0..3
  final String? aliasesFa; // جداشده با کاما
  final bool isCustom;
  final bool isEnabled;
  final int usageCount;
  final DateTime? lastUsedAt;
  final int sortOrder;
  final MvSessionMode? sessionModeOverride;

  const MvMovementKind({
    required this.code,
    required this.titleFa,
    required this.emoji,
    required this.family,
    required this.baseMet,
    required this.metLow,
    required this.metHigh,
    required this.primaryMetric,
    this.secondaryMetric,
    required this.isOutdoor,
    required this.isSocial,
    required this.needsVenue,
    this.seasonMask,
    required this.jointImpact,
    this.aliasesFa,
    required this.isCustom,
    required this.isEnabled,
    required this.usageCount,
    this.lastUsedAt,
    required this.sortOrder,
    this.sessionModeOverride,
  });

  /// Computed alias list from comma-separated [aliasesFa].
  List<String> get aliasList {
    if (aliasesFa == null || aliasesFa!.trim().isEmpty) return const [];
    return aliasesFa!
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  /// مقدار پیش‌فرض هدف متناسب با متریک اصلی حرکت (کیلومتر، دور، ارتفاع، گام، دقیقه).
  double defaultTargetValue({int? durationMinutes}) {
    switch (primaryMetric) {
      case MovementMetric.distance:
        if (code == 'CYCLING') return 10.0;
        if (code == 'RUNNING') return 5.0;
        return 3.0;
      case MovementMetric.laps:
        return 10.0;
      case MovementMetric.elevation:
        return 100.0;
      case MovementMetric.steps:
        return 4000.0;
      case MovementMetric.duration:
      case MovementMetric.sets:
      case MovementMetric.none:
        return (durationMinutes ?? 30).toDouble();
    }
  }

  MvMovementKind copyWith({
    String? code,
    String? titleFa,
    String? emoji,
    MovementFamily? family,
    double? baseMet,
    double? metLow,
    double? metHigh,
    MovementMetric? primaryMetric,
    MovementMetric? secondaryMetric,
    bool? isOutdoor,
    bool? isSocial,
    bool? needsVenue,
    String? seasonMask,
    int? jointImpact,
    String? aliasesFa,
    bool? isCustom,
    bool? isEnabled,
    int? usageCount,
    DateTime? lastUsedAt,
    int? sortOrder,
    MvSessionMode? sessionModeOverride,
  }) {
    return MvMovementKind(
      code: code ?? this.code,
      titleFa: titleFa ?? this.titleFa,
      emoji: emoji ?? this.emoji,
      family: family ?? this.family,
      baseMet: baseMet ?? this.baseMet,
      metLow: metLow ?? this.metLow,
      metHigh: metHigh ?? this.metHigh,
      primaryMetric: primaryMetric ?? this.primaryMetric,
      secondaryMetric: secondaryMetric ?? this.secondaryMetric,
      isOutdoor: isOutdoor ?? this.isOutdoor,
      isSocial: isSocial ?? this.isSocial,
      needsVenue: needsVenue ?? this.needsVenue,
      seasonMask: seasonMask ?? this.seasonMask,
      jointImpact: jointImpact ?? this.jointImpact,
      aliasesFa: aliasesFa ?? this.aliasesFa,
      isCustom: isCustom ?? this.isCustom,
      isEnabled: isEnabled ?? this.isEnabled,
      usageCount: usageCount ?? this.usageCount,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
      sortOrder: sortOrder ?? this.sortOrder,
      sessionModeOverride: sessionModeOverride ?? this.sessionModeOverride,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'code': code,
      'titleFa': titleFa,
      'emoji': emoji,
      'family': family.code,
      'baseMet': baseMet,
      'metLow': metLow,
      'metHigh': metHigh,
      'primaryMetric': primaryMetric.code,
      'secondaryMetric': secondaryMetric?.code,
      'isOutdoor': isOutdoor ? 1 : 0,
      'isSocial': isSocial ? 1 : 0,
      'needsVenue': needsVenue ? 1 : 0,
      'seasonMask': seasonMask,
      'jointImpact': jointImpact,
      'aliasesFa': aliasesFa,
      'isCustom': isCustom ? 1 : 0,
      'isEnabled': isEnabled ? 1 : 0,
      'usageCount': usageCount,
      'lastUsedAt': lastUsedAt?.millisecondsSinceEpoch,
      'sortOrder': sortOrder,
      'sessionModeOverride': sessionModeOverride?.code,
    };
  }

  factory MvMovementKind.fromMap(Map<String, dynamic> map) {
    return MvMovementKind(
      code: map['code'] as String,
      titleFa: map['titleFa'] as String? ?? '',
      emoji: map['emoji'] as String? ?? '🏃',
      family: MovementFamily.fromCode(map['family'] as String? ?? 'ENDURANCE'),
      baseMet: (map['baseMet'] as num? ?? 4.0).toDouble(),
      metLow: (map['metLow'] as num? ?? 3.0).toDouble(),
      metHigh: (map['metHigh'] as num? ?? 6.0).toDouble(),
      primaryMetric: MovementMetric.fromCode(
        map['primaryMetric'] as String? ?? 'DURATION',
      ),
      secondaryMetric: map['secondaryMetric'] != null
          ? MovementMetric.fromCode(map['secondaryMetric'] as String)
          : null,
      isOutdoor: (map['isOutdoor'] as int? ?? 0) == 1,
      isSocial: (map['isSocial'] as int? ?? 0) == 1,
      needsVenue: (map['needsVenue'] as int? ?? 0) == 1,
      seasonMask: map['seasonMask'] as String?,
      jointImpact: (map['jointImpact'] as int? ?? 1),
      aliasesFa: map['aliasesFa'] as String?,
      isCustom: (map['isCustom'] as int? ?? 0) == 1,
      isEnabled: (map['isEnabled'] as int? ?? 1) == 1,
      usageCount: (map['usageCount'] as int? ?? 0),
      lastUsedAt: map['lastUsedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['lastUsedAt'] as int)
          : null,
      sortOrder: (map['sortOrder'] as int? ?? 0),
      sessionModeOverride: map['sessionModeOverride'] != null
          ? MvSessionMode.fromCode(map['sessionModeOverride'] as String)
          : null,
    );
  }
}
