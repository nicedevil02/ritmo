import 'package:ritmo/core/domain/engines/ritmo_engine_bus.dart';

enum OverdoseResult { safe, warningUnderInterval, warningMaxLimitExceeded }

class MedicalEngine {
  /// Pure function to evaluate medication overdose risk.
  ///
  /// [now] is the current timestamp in epoch milliseconds.
  /// [prnLogs24h] holds timestamps of doses taken in the last 24 hours.
  /// [minIntervalHours] is the minimum hours that must pass between doses.
  /// [maxDosesPerDay] is the maximum number of doses allowed per day.
  static OverdoseResult checkOverdoseStatus({
    required int now,
    required List<int> prnLogs24h,
    required int minIntervalHours,
    required int maxDosesPerDay,
  }) {
    if (prnLogs24h.isEmpty) return OverdoseResult.safe;

    // Find the latest dose taken
    final lastTaken = prnLogs24h.fold<int>(
      0,
      (max, val) => val > max ? val : max,
    );

    final diffHours = (now - lastTaken).toDouble() / (1000 * 60 * 60);

    if (minIntervalHours > 0 && diffHours < minIntervalHours) {
      return OverdoseResult.warningUnderInterval;
    }

    if (maxDosesPerDay > 0 && prnLogs24h.length >= maxDosesPerDay) {
      return OverdoseResult.warningMaxLimitExceeded;
    }

    return OverdoseResult.safe;
  }

  /// Pure function to evaluate whether medication refill is needed.
  ///
  /// MED-14: the previous implementation required `stockCount >= 1`, which made
  /// the refill banner disappear at exactly the moment the medication ran out.
  /// Zero stock is the strongest possible refill signal, so it must be included.
  ///
  /// A [warningThreshold] of zero or less means the user never enabled stock
  /// tracking for this medication, so no refill warning is produced.
  static bool isRefillNeeded({
    required int stockCount,
    required int warningThreshold,
  }) {
    if (warningThreshold <= 0) return false;
    return stockCount <= warningThreshold;
  }

  /// True when there is nothing left to take.
  ///
  /// Callers should render this as a distinct, stronger state than
  /// [isRefillNeeded] ("تمام شده" versus "رو به اتمام").
  static bool isOutOfStock({required int stockCount}) => stockCount <= 0;
}

class MedicineEngineInput {
  MedicineEngineInput({
    required this.now,
    required this.prnLogs24h,
    required this.minIntervalHours,
    required this.maxDosesPerDay,
    required this.stockCount,
    required this.warningThreshold,
  });
  final int now;
  final List<int> prnLogs24h;
  final int minIntervalHours;
  final int maxDosesPerDay;
  final int stockCount;
  final int warningThreshold;
}

class MedicineEngineOutput {
  MedicineEngineOutput({
    required this.overdoseResult,
    required this.refillNeeded,
    this.outOfStock = false,
  });
  final OverdoseResult overdoseResult;
  final bool refillNeeded;
  final bool outOfStock;
}

class MedicineEngine
    implements CachedEngine<MedicineEngineInput, MedicineEngineOutput> {
  @override
  Future<MedicineEngineOutput> calculate(MedicineEngineInput input) async {
    final overdose = MedicalEngine.checkOverdoseStatus(
      now: input.now,
      prnLogs24h: input.prnLogs24h,
      minIntervalHours: input.minIntervalHours,
      maxDosesPerDay: input.maxDosesPerDay,
    );
    final refill = MedicalEngine.isRefillNeeded(
      stockCount: input.stockCount,
      warningThreshold: input.warningThreshold,
    );
    return MedicineEngineOutput(
      overdoseResult: overdose,
      refillNeeded: refill,
      outOfStock: MedicalEngine.isOutOfStock(stockCount: input.stockCount),
    );
  }

  @override
  Duration get ttl => Duration.zero;

  @override
  String fingerprint(MedicineEngineInput input) =>
      '${input.now}|${input.stockCount}|${input.prnLogs24h.length}';

  @override
  void invalidate() {}

  @override
  bool canRun(MedicineEngineInput input) => true;

  @override
  List<Type> dependencies() => [];
}
