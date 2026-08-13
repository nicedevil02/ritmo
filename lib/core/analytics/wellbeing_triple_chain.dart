import 'package:ritmo/core/util/ritmo_date.dart';
import 'package:ritmo/features/energy/models/energy_mood_models.dart';
import 'package:ritmo/features/sleep/models/sleep_models.dart';

class WellbeingTripleChainHit {
  const WellbeingTripleChainHit({
    required this.weekday,
    required this.weekdayFa,
    required this.opportunities,
    required this.hits,
  });

  final int weekday;
  final String weekdayFa;
  final int opportunities;
  final int hits;

  double get rate => opportunities == 0 ? 0.0 : hits / opportunities;
}

/// Looks for: short/poor sleep on day D → low energy next morning → low mood later.
class WellbeingTripleChain {
  const WellbeingTripleChain();

  static const int minOpportunities = 4;
  static const double minHitRate = 0.6;
  static const double sleepSlackHours = 0.75;

  static const Map<int, String> weekdayFa = {
    DateTime.saturday: 'شنبه‌',
    DateTime.sunday: 'یکشنبه‌',
    DateTime.monday: 'دوشنبه‌',
    DateTime.tuesday: 'سه‌شنبه‌',
    DateTime.wednesday: 'چهارشنبه‌',
    DateTime.thursday: 'پنج‌شنبه‌',
    DateTime.friday: 'جمعه‌',
  };

  WellbeingTripleChainHit? detect({
    required List<SleepLog> sleepLogs,
    required List<EnergyLog> energyLogs,
    required List<MoodLog> moodLogs,
    required double targetSleepHours,
  }) {
    final energyByDate = <String, List<EnergyLog>>{};
    for (final e in energyLogs) {
      if (e.loggedAt <= 0) continue;
      final key = RitmoDate.dayKeyFromMillis(e.loggedAt);
      energyByDate.putIfAbsent(key, () => []).add(e);
    }
    final moodByDate = <String, List<MoodLog>>{};
    for (final m in moodLogs) {
      if (m.loggedAt <= 0) continue;
      final key = RitmoDate.dayKeyFromMillis(m.loggedAt);
      moodByDate.putIfAbsent(key, () => []).add(m);
    }

    final oppByWeekday = <int, int>{};
    final hitByWeekday = <int, int>{};

    for (final sleep in sleepLogs) {
      final sleepDate = RitmoDate.tryParseDayKey(sleep.date);
      if (sleepDate == null) continue;
      final next = RitmoDate.startOfDay(sleepDate).add(const Duration(days: 1));
      final nextKey = RitmoDate.dayKey(next);
      final morningEnergy = energyByDate[nextKey]
              ?.where((e) {
                final hour = DateTime.fromMillisecondsSinceEpoch(e.loggedAt).hour;
                return hour >= 5 && hour < 12;
              })
              .toList() ??
          const <EnergyLog>[];
      final laterMood = moodByDate[nextKey]
              ?.where((m) {
                final hour = DateTime.fromMillisecondsSinceEpoch(m.loggedAt).hour;
                return hour >= 14;
              })
              .toList() ??
          const <MoodLog>[];
      if (morningEnergy.isEmpty || laterMood.isEmpty) continue;

      final weekday = next.weekday;
      oppByWeekday[weekday] = (oppByWeekday[weekday] ?? 0) + 1;

      final shortSleep =
          sleep.durationHours < (targetSleepHours - sleepSlackHours) ||
              sleep.quality.score <= 2;
      final energyAvg = morningEnergy
              .map(_energyScore)
              .reduce((a, b) => a + b) /
          morningEnergy.length;
      final moodAvg =
          laterMood.map((m) => m.valence.toDouble()).reduce((a, b) => a + b) /
              laterMood.length;
      if (shortSleep && energyAvg <= 1.5 && moodAvg <= 2.5) {
        hitByWeekday[weekday] = (hitByWeekday[weekday] ?? 0) + 1;
      }
    }

    WellbeingTripleChainHit? best;
    for (final weekday in oppByWeekday.keys) {
      final opps = oppByWeekday[weekday] ?? 0;
      final hits = hitByWeekday[weekday] ?? 0;
      if (opps < minOpportunities) continue;
      final candidate = WellbeingTripleChainHit(
        weekday: weekday,
        weekdayFa: weekdayFa[weekday] ?? '',
        opportunities: opps,
        hits: hits,
      );
      if (candidate.rate < minHitRate) continue;
      if (best == null ||
          candidate.hits > best.hits ||
          (candidate.hits == best.hits && candidate.rate > best.rate)) {
        best = candidate;
      }
    }
    return best;
  }

  double _energyScore(EnergyLog log) {
    switch (log.energyLevel) {
      case EnergyLevel.high:
        return 3.0;
      case EnergyLevel.medium:
        return 2.0;
      case EnergyLevel.low:
        return 1.0;
    }
  }
}
