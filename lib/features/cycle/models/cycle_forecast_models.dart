// F-01 & F-02: Cycle Multi-Cycle Forecast Models & Calendar Day Marks
import 'package:ritmo/features/cycle/models/cycle_intelligence_models.dart';

enum ForecastBasis {
  measured, // sd از >= 3 چرخهٔ کامل واقعی
  partiallyMeasured, // 1..2 چرخهٔ کامل؛ sd قابل اتکا نیست
  defaultAssumption, // هیچ چرخهٔ کاملی نیست؛ فقط تنظیمات
}

class PredictedCycle {
  const PredictedCycle({
    required this.index,
    required this.predictedStart,
    required this.predictedEnd,
    required this.windowStart,
    required this.windowEnd,
    required this.sigmaDays,
    required this.periodDays,
    required this.confidence,
    required this.confidenceLevel,
    required this.basis,
    this.ovulationDay,
    this.fertileStart,
    this.fertileEnd,
    this.pmsStart,
    this.pmsEnd,
  });

  final int index; // 1 = نزدیک‌ترین چرخهٔ آینده
  final DateTime predictedStart;
  final DateTime predictedEnd; // predictedStart + periodDays - 1
  final DateTime windowStart; // predictedStart - round(sigmaDays)
  final DateTime windowEnd; // predictedStart + round(sigmaDays)
  final double sigmaDays;
  final int periodDays;
  final double confidence; // 0..1
  final PredictionConfidenceLevel confidenceLevel;
  final ForecastBasis basis;
  final DateTime? ovulationDay;
  final DateTime? fertileStart;
  final DateTime? fertileEnd;
  final DateTime? pmsStart;
  final DateTime? pmsEnd;
}

enum CycleDayKind {
  recordedPeriod,
  predictedPeriod,
  predictionWindow,
  ovulation,
  fertileWindow,
  pms,
  normal,
}

class CycleDayMark {
  const CycleDayMark({
    required this.kind,
    this.cycleIndex,
    this.confidence,
    this.confidenceLevel,
    this.hasLog = false,
    this.predictedCycle,
  });

  final CycleDayKind kind;
  final int? cycleIndex;
  final double? confidence;
  final PredictionConfidenceLevel? confidenceLevel;
  final bool hasLog;
  final PredictedCycle? predictedCycle;
}
