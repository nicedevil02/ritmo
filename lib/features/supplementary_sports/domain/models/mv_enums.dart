/// Unified Enums for Sports & Movement Domain.
/// Follows Section 1.5, 3.4, and 7 of the comprehensive sports architecture.
library;

/// Represents the type of daily program slot.
enum MvSlotType {
  strength,
  cardio,
  mobility,
  activeRest,
  rest;

  String get code {
    switch (this) {
      case MvSlotType.strength:
        return 'STRENGTH';
      case MvSlotType.cardio:
        return 'CARDIO';
      case MvSlotType.mobility:
        return 'MOBILITY';
      case MvSlotType.activeRest:
        return 'ACTIVE_REST';
      case MvSlotType.rest:
        return 'REST';
    }
  }

  String get titleFa {
    switch (this) {
      case MvSlotType.strength:
        return 'قدرتی';
      case MvSlotType.cardio:
        return 'هوازی';
      case MvSlotType.mobility:
        return 'کشش و تحرک';
      case MvSlotType.activeRest:
        return 'بازیابی فعال';
      case MvSlotType.rest:
        return 'استراحت';
    }
  }

  static MvSlotType fromCode(String? code) {
    if (code == null) return MvSlotType.strength;
    final upper = code.toUpperCase().trim();
    switch (upper) {
      case 'STRENGTH':
      case 'WORKOUT':
        return MvSlotType.strength;
      case 'CARDIO':
        return MvSlotType.cardio;
      case 'MOBILITY':
      case 'STRETCH':
        return MvSlotType.mobility;
      case 'ACTIVE_REST':
        return MvSlotType.activeRest;
      case 'REST':
      case 'RECOVERY':
        return MvSlotType.rest;
      default:
        return MvSlotType.strength;
    }
  }
}

/// Target intensity tier with mapped RPE and MET multipliers.
enum MvIntensityTier {
  light(targetRpe: 4, metMultiplier: 3.0, titleFa: 'سبک'),
  moderate(targetRpe: 6, metMultiplier: 5.0, titleFa: 'متوسط'),
  hard(targetRpe: 8, metMultiplier: 6.5, titleFa: 'سنگین');

  final int targetRpe;
  final double metMultiplier;
  final String titleFa;

  const MvIntensityTier({
    required this.targetRpe,
    required this.metMultiplier,
    required this.titleFa,
  });

  String get code => name.toUpperCase();

  static MvIntensityTier fromCode(String? code) {
    if (code == null) return MvIntensityTier.moderate;
    final upper = code.toUpperCase().trim();
    switch (upper) {
      case 'LIGHT':
      case 'LOW':
        return MvIntensityTier.light;
      case 'HARD':
      case 'HIGH':
        return MvIntensityTier.hard;
      case 'MODERATE':
      case 'MED':
      default:
        return MvIntensityTier.moderate;
    }
  }
}

/// Status of a daily prescription/slot.
enum MvSlotStatus {
  planned,
  done,
  partial,
  skipped,
  moved;

  String get code => name.toUpperCase();

  String get titleFa {
    switch (this) {
      case MvSlotStatus.planned:
        return 'برنامه‌ریزی‌شده';
      case MvSlotStatus.done:
        return 'انجام‌شده';
      case MvSlotStatus.partial:
        return 'بخشی';
      case MvSlotStatus.skipped:
        return 'رد‌شده';
      case MvSlotStatus.moved:
        return 'جابه‌جاشده';
    }
  }

  static MvSlotStatus fromCode(String? code) {
    if (code == null) return MvSlotStatus.planned;
    final upper = code.toUpperCase().trim();
    switch (upper) {
      case 'DONE':
      case 'COMPLETED':
        return MvSlotStatus.done;
      case 'PARTIAL':
        return MvSlotStatus.partial;
      case 'SKIPPED':
      case 'CANCELED':
        return MvSlotStatus.skipped;
      case 'MOVED':
      case 'SHIFTED':
        return MvSlotStatus.moved;
      case 'PLANNED':
      default:
        return MvSlotStatus.planned;
    }
  }
}

/// 7 Session Execution Modes (Guided, Structured, Timed, Distance, Route, Laps, Match).
enum MvSessionMode {
  guided,
  structured,
  timed,
  distance,
  route,
  laps,
  match,
  quickLog;

  String get code => name;

  String get titleFa {
    switch (this) {
      case MvSessionMode.guided:
        return 'هدایت‌شده با انیمیشن';
      case MvSessionMode.structured:
        return 'ست و تکرار';
      case MvSessionMode.timed:
        return 'زمان‌دار';
      case MvSessionMode.distance:
        return 'مسافتی';
      case MvSessionMode.route:
        return 'مسیر نقشه';
      case MvSessionMode.laps:
        return 'دور شمار';
      case MvSessionMode.match:
        return 'مسابقه‌ای/بازی';
      case MvSessionMode.quickLog:
        return 'ثبت سریع';
    }
  }

  static MvSessionMode fromCode(String? code) {
    if (code == null) return MvSessionMode.guided;
    final lower = code.toLowerCase().trim();
    switch (lower) {
      case 'guided':
        return MvSessionMode.guided;
      case 'structured':
        return MvSessionMode.structured;
      case 'timed':
        return MvSessionMode.timed;
      case 'distance':
        return MvSessionMode.distance;
      case 'route':
        return MvSessionMode.route;
      case 'laps':
        return MvSessionMode.laps;
      case 'match':
        return MvSessionMode.match;
      default:
        return MvSessionMode.guided;
    }
  }
}

/// Status of an active or completed session.
enum MvSessionStatus {
  active,
  paused,
  completed,
  abandoned,
  partial;

  String get code => name.toUpperCase();

  static MvSessionStatus fromCode(String? code) {
    if (code == null) return MvSessionStatus.active;
    final upper = code.toUpperCase().trim();
    switch (upper) {
      case 'ACTIVE':
        return MvSessionStatus.active;
      case 'PAUSED':
        return MvSessionStatus.paused;
      case 'COMPLETED':
      case 'FINISHED':
        return MvSessionStatus.completed;
      case 'ABANDONED':
        return MvSessionStatus.abandoned;
      case 'PARTIAL':
        return MvSessionStatus.partial;
      default:
        return MvSessionStatus.active;
    }
  }
}

/// 4-tier Daily Readiness.
enum MvReadinessTier {
  full(multiplier: 1.0, titleFa: 'آمادگی کامل'),
  light(multiplier: 0.8, titleFa: 'جلسهٔ سبک'),
  minimal(multiplier: 0.5, titleFa: 'حداقل مؤثر'),
  rest(multiplier: 0.0, titleFa: 'ریکاوری و استراحت');

  final double multiplier;
  final String titleFa;

  const MvReadinessTier({required this.multiplier, required this.titleFa});

  String get code => name;

  static MvReadinessTier fromCode(String? code) {
    if (code == null) return MvReadinessTier.full;
    final lower = code.toLowerCase().trim();
    switch (lower) {
      case 'full':
        return MvReadinessTier.full;
      case 'light':
        return MvReadinessTier.light;
      case 'minimal':
        return MvReadinessTier.minimal;
      case 'rest':
        return MvReadinessTier.rest;
      default:
        return MvReadinessTier.full;
    }
  }
}

/// Metrics used to track movement activities.
enum MvMovementMetric {
  duration,
  distance,
  reps,
  weight,
  laps,
  score,
  heartRate;

  String get code => name;

  static MvMovementMetric fromCode(String? code) {
    if (code == null) return MvMovementMetric.duration;
    final lower = code.toLowerCase().trim();
    switch (lower) {
      case 'duration':
        return MvMovementMetric.duration;
      case 'distance':
        return MvMovementMetric.distance;
      case 'reps':
        return MvMovementMetric.reps;
      case 'weight':
        return MvMovementMetric.weight;
      case 'laps':
        return MvMovementMetric.laps;
      case 'score':
        return MvMovementMetric.score;
      case 'heartrate':
      case 'heart_rate':
        return MvMovementMetric.heartRate;
      default:
        return MvMovementMetric.duration;
    }
  }
}

/// Personal Record types.
enum MvPrType {
  maxWeight,
  maxReps,
  longestDuration,
  longestDistance,
  fastestPace;

  String get code => name;

  String get titleFa {
    switch (this) {
      case MvPrType.maxWeight:
        return 'بیشترین وزنه';
      case MvPrType.maxReps:
        return 'بیشترین تکرار';
      case MvPrType.longestDuration:
        return 'بیشترین مدت';
      case MvPrType.longestDistance:
        return 'بیشترین مسافت';
      case MvPrType.fastestPace:
        return 'سریع‌ترین رکورد';
    }
  }

  String get unitFa {
    switch (this) {
      case MvPrType.maxWeight:
        return 'کیلوگرم';
      case MvPrType.maxReps:
        return 'تکرار';
      case MvPrType.longestDuration:
        return 'دقیقه';
      case MvPrType.longestDistance:
        return 'متر';
      case MvPrType.fastestPace:
        return 'سرعت';
    }
  }

  static MvPrType fromCode(String? code) {
    if (code == null) return MvPrType.maxWeight;
    final lower = code.toLowerCase().trim();
    switch (lower) {
      case 'maxweight':
      case 'max_weight':
      case 'weight':
        return MvPrType.maxWeight;
      case 'maxreps':
      case 'max_reps':
      case 'reps':
        return MvPrType.maxReps;
      case 'longestduration':
      case 'duration':
        return MvPrType.longestDuration;
      case 'longestdistance':
      case 'distance':
        return MvPrType.longestDistance;
      case 'fastestpace':
      case 'pace':
        return MvPrType.fastestPace;
      default:
        return MvPrType.maxWeight;
    }
  }
}

/// Simple 3-option post-session feeling / difficulty rating.
enum MvSessionFeeling {
  easy(rirValue: 3, titleFa: 'آسان بود / جا داشتم'),
  good(rirValue: 2, titleFa: 'خوب و متناسب بود'),
  hard(rirValue: 0, titleFa: 'سخت بود و به چالش کشید');

  final int rirValue;
  final String titleFa;

  const MvSessionFeeling({required this.rirValue, required this.titleFa});

  String get code => name;

  static MvSessionFeeling fromRir(int? rir) {
    if (rir == null) return MvSessionFeeling.good;
    if (rir >= 3) return MvSessionFeeling.easy;
    if (rir <= 1) return MvSessionFeeling.hard;
    return MvSessionFeeling.good;
  }
}
