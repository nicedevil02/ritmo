import '../models/models.dart';

/// Immutable snapshot of acute and chronic training load (Section 4.3 & S4-T6).
class MvLoadSnapshot {
  final int acuteLoad;
  final double chronicWeeklyLoad;
  final double? ratio; // null when insufficient data
  final String? bandKey; // One of 4 keys from Section 4.3
  final int daysOfHistory;
  final int completedSessions;

  const MvLoadSnapshot({
    required this.acuteLoad,
    required this.chronicWeeklyLoad,
    this.ratio,
    this.bandKey,
    required this.daysOfHistory,
    required this.completedSessions,
  });

  bool get hasEnoughData => ratio != null && bandKey != null;

  @override
  String toString() =>
      'MvLoadSnapshot(acute: $acuteLoad, chronicWeekly: $chronicWeeklyLoad, ratio: $ratio, bandKey: $bandKey, days: $daysOfHistory, sessions: $completedSessions)';
}

/// Pure Dart Engine computing Acute-to-Chronic Workload Ratio (ACWR / sRPE) (§4.3).
class LoadEngine {
  const LoadEngine();

  /// Computes load snapshot from a list of completed sessions.
  MvLoadSnapshot computeLoadSnapshot({
    required List<MvSession> completedSessions,
    required int daysOfHistory,
    DateTime? referenceDate,
  }) {
    final now = referenceDate ?? DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));
    final twentyEightDaysAgo = now.subtract(const Duration(days: 28));

    // Filter valid completed sessions
    final validSessions = completedSessions
        .where((s) => s.status == MvSessionStatus.completed)
        .toList();

    int acuteSum = 0;
    int chronicSum = 0;

    for (final s in validSessions) {
      final sDate = DateTime.fromMillisecondsSinceEpoch(s.startedAt);
      final load = s.sessionLoad ?? ((s.rpe1To10 ?? 5) * s.elapsedMinutes);

      if (sDate.isAfter(sevenDaysAgo) || sDate.isAtSameMomentAs(sevenDaysAgo)) {
        acuteSum += load;
      }
      if (sDate.isAfter(twentyEightDaysAgo) ||
          sDate.isAtSameMomentAs(twentyEightDaysAgo)) {
        chronicSum += load;
      }
    }

    final double chronicWeekly = chronicSum / 4.0;
    final int sessionCount = validSessions.length;

    // Guard: daysOfHistory < 14 || sessionCount < 6 || chronicWeekly <= 0
    if (daysOfHistory < 14 || sessionCount < 6 || chronicWeekly <= 0) {
      return MvLoadSnapshot(
        acuteLoad: acuteSum,
        chronicWeeklyLoad: chronicWeekly,
        ratio: null,
        bandKey: null,
        daysOfHistory: daysOfHistory,
        completedSessions: sessionCount,
      );
    }

    final double ratio = acuteSum / chronicWeekly;
    final String bandKey = resolveBandKey(ratio);

    return MvLoadSnapshot(
      acuteLoad: acuteSum,
      chronicWeeklyLoad: chronicWeekly,
      ratio: ratio,
      bandKey: bandKey,
      daysOfHistory: daysOfHistory,
      completedSessions: sessionCount,
    );
  }

  /// Computes snapshot directly from explicit acute/chronic load numbers and history constraints.
  MvLoadSnapshot computeFromLoads({
    required int acuteLoad,
    required double chronicWeeklyLoad,
    required int daysOfHistory,
    required int completedSessions,
  }) {
    if (daysOfHistory < 14 || completedSessions < 6 || chronicWeeklyLoad <= 0) {
      return MvLoadSnapshot(
        acuteLoad: acuteLoad,
        chronicWeeklyLoad: chronicWeeklyLoad,
        ratio: null,
        bandKey: null,
        daysOfHistory: daysOfHistory,
        completedSessions: completedSessions,
      );
    }

    final double ratio = acuteLoad / chronicWeeklyLoad;
    final String bandKey = resolveBandKey(ratio);

    return MvLoadSnapshot(
      acuteLoad: acuteLoad,
      chronicWeeklyLoad: chronicWeeklyLoad,
      ratio: ratio,
      bandKey: bandKey,
      daysOfHistory: daysOfHistory,
      completedSessions: completedSessions,
    );
  }

  /// Resolves the 4 deterministic band keys defined in Section 4.3 table.
  static String resolveBandKey(double ratio) {
    if (ratio < 0.8) {
      return 'mv_load_band_low';
    } else if (ratio <= 1.3) {
      return 'mv_load_band_optimal';
    } else if (ratio <= 1.5) {
      return 'mv_load_band_watch';
    } else {
      return 'mv_load_band_spike';
    }
  }
}
