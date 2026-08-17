// Cycle Domain Models (C-41: Code/enum-based contracts)

class SymptomStat {
  SymptomStat({
    required this.key,
    required this.count,
    required this.typicalCycleDay,
  });
  final String key;
  final int count;
  final int typicalCycleDay;
}

class CycleTrendPoint {
  CycleTrendPoint({
    required this.index,
    required this.lengthDays,
    required this.periodDays,
    this.isInProgress = false,
  });
  final int index;
  final int lengthDays;
  final int periodDays;
  final bool isInProgress;
}

enum CycleFlowLevel {
  none,
  light,
  medium,
  heavy;

  static CycleFlowLevel fromDb(String? value) {
    if (value == null) return CycleFlowLevel.none;
    final normalized = value.trim().toUpperCase();
    switch (normalized) {
      case 'LIGHT':
      case 'SPOTTING':
        return CycleFlowLevel.light;
      case 'MEDIUM':
        return CycleFlowLevel.medium;
      case 'HEAVY':
        return CycleFlowLevel.heavy;
      case 'NONE':
      default:
        return CycleFlowLevel.none;
    }
  }

  String toDb() => switch (this) {
        CycleFlowLevel.none => 'NONE',
        CycleFlowLevel.light => 'LIGHT',
        CycleFlowLevel.medium => 'MEDIUM',
        CycleFlowLevel.heavy => 'HEAVY',
      };

  double get score => switch (this) {
        CycleFlowLevel.none => 0.0,
        CycleFlowLevel.light => 1.0,
        CycleFlowLevel.medium => 2.0,
        CycleFlowLevel.heavy => 3.0,
      };

  String get labelFa => name;
}

class CycleCorrelation {
  CycleCorrelation({
    required this.metric,
    this.coefficient,
    this.pValue,
    this.sampleSize = 0,
    this.isSignificant = false,
    required this.insight,
  });
  final String metric;
  final double? coefficient;
  final double? pValue;
  final int sampleSize;
  final bool isSignificant;
  final String insight;
}

class FastingDebt {
  FastingDebt({
    required this.id,
    required this.dateIso,
    required this.daysOwed,
    this.reason,
    required this.isResolved,
  });

  factory FastingDebt.fromMap(Map<String, dynamic> map) {
    return FastingDebt(
      id: map['id'] as String,
      dateIso: map['dateIso'] as String,
      daysOwed: map['daysOwed'] as int? ?? 1,
      reason: map['reason'] as String?,
      isResolved: (map['isResolved'] as int? ?? 0) == 1,
    );
  }
  final String id;
  final String dateIso;
  final int daysOwed;
  final String? reason;
  final bool isResolved;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'dateIso': dateIso,
      'daysOwed': daysOwed,
      'reason': reason,
      'isResolved': isResolved ? 1 : 0,
    };
  }
}

class BodyRhythmInfluence {
  BodyRhythmInfluence({
    required this.energyDelta,
    required this.indirectMessage,
  });
  final double energyDelta;
  final String indirectMessage;
}
