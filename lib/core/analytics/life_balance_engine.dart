import 'package:ritmo/core/domain/engines/ritmo_engine_bus.dart';
import 'package:ritmo/core/util/safe_map.dart';

class LifeBalanceEngineInput {
  LifeBalanceEngineInput({
    required this.now,
    required this.routines,
    required this.routineCompletions,
  });
  final DateTime now;
  final List<Map<String, dynamic>> routines;
  final List<Map<String, dynamic>> routineCompletions;
}

class LifeBalanceEngineOutput {
  LifeBalanceEngineOutput({
    required this.score,
    required this.distribution,
    required this.trend,
    this.domainMinutes = const {},
    this.skippedRows = 0,
  });
  final int? score;
  final Map<String, double> distribution;
  final Map<int, int?> trend;
  final Map<String, int> domainMinutes;
  final int skippedRows;
}

class LifeBalanceEngine implements CachedEngine<LifeBalanceEngineInput, LifeBalanceEngineOutput> {
  static const int minCompletionsForBalance = 10;
  static const int minMinutesForBalance = 30;

  @override
  Future<LifeBalanceEngineOutput> calculate(LifeBalanceEngineInput input) async {
    final score = calculateLifeBalanceScore(
      routines: input.routines,
      routineCompletions: input.routineCompletions,
    );
    final distribution = calculateCategoryDistribution(
      routines: input.routines,
      routineCompletions: input.routineCompletions,
    );
    final domainMinutes = calculateDomainMinutes(
      routines: input.routines,
      routineCompletions: input.routineCompletions,
    );
    final trend = calculateBalanceTrend(
      now: input.now,
      routines: input.routines,
      routineCompletions: input.routineCompletions,
    );
    return LifeBalanceEngineOutput(
      score: score,
      distribution: distribution,
      trend: trend,
      domainMinutes: domainMinutes,
    );
  }

  @override
  Duration get ttl => const Duration(minutes: 5);

  @override
  String fingerprint(LifeBalanceEngineInput input) {
    final dayStamp = input.now.toIso8601String().substring(0, 10);
    return '$dayStamp|${input.routines.length}|${input.routineCompletions.length}';
  }

  @override
  void invalidate() {}

  @override
  bool canRun(LifeBalanceEngineInput input) => true;

  @override
  List<Type> dependencies() => [];

  /// Maps a routine category database string to analytical domains.
  static String mapCategoryToDomain(String dbCategory) {
    final clean = dbCategory.toLowerCase().trim();
    if (clean == 'religious' || clean == 'worship' || clean == 'prayer') return 'RELIGION';
    if (clean == 'medical' || clean == 'fitness' || clean == 'health' || clean == 'sport' || clean == 'sports') {
      return 'HEALTH';
    }
    if (clean == 'learning' || clean == 'konkur' || clean == 'study' || clean == 'course') return 'LEARNING';
    if (clean == 'work' || clean == 'career' || clean == 'job') return 'WORK';
    if (clean == 'personal' || clean == 'family' || clean == 'social') return 'PERSONAL';
    if (clean == 'free' || clean == 'leisure' || clean == 'hobby') return 'FREE';
    return 'CUSTOM';
  }

  /// Resolves the actual or estimated duration in minutes for a routine completion.
  static double resolveCompletionDurationMinutes({
    required Map<String, dynamic>? routine,
    required Map<String, dynamic> completion,
    required String domain,
  }) {
    final actual = completion.readInt('actual_duration_minutes') ?? completion.readInt('durationMinutes');
    double baseMinutes;

    if (actual != null && actual > 0) {
      baseMinutes = actual.toDouble();
    } else if (routine != null) {
      final resultType = completion.readString('resultType') ?? 'FULL';
      if (resultType == 'LIGHT') {
        baseMinutes = (routine.readInt('lightDurationMinutes') ??
                routine.readInt('targetDurationMinutes') ??
                routine.readInt('durationMinutes') ??
                _defaultDurationForDomain(domain))
            .toDouble();
      } else if (resultType == 'MINIMAL') {
        baseMinutes = (routine.readInt('minimalDurationMinutes') ??
                routine.readInt('targetDurationMinutes') ??
                routine.readInt('durationMinutes') ??
                _defaultDurationForDomain(domain))
            .toDouble();
      } else {
        baseMinutes = (routine.readInt('targetDurationMinutes') ??
                routine.readInt('durationMinutes') ??
                _defaultDurationForDomain(domain))
            .toDouble();
      }
    } else {
      baseMinutes = _defaultDurationForDomain(domain).toDouble();
    }

    final resultType = completion.readString('resultType') ?? 'FULL';
    if (resultType == 'PARTIAL') {
      final ratio = completion.readDouble('partialRatio') ?? 0.5;
      baseMinutes *= ratio.clamp(0.1, 0.9);
    }

    return baseMinutes.clamp(1.0, 1440.0);
  }

  static int _defaultDurationForDomain(String domain) {
    switch (domain) {
      case 'RELIGION':
        return 15;
      case 'HEALTH':
        return 30;
      case 'LEARNING':
        return 45;
      case 'WORK':
        return 45;
      case 'PERSONAL':
        return 20;
      case 'FREE':
        return 30;
      case 'CUSTOM':
      default:
        return 20;
    }
  }

  /// Calculates the Life Balance Score (0 - 100) using time-weighted normalized variance.
  /// Returns null if data is insufficient.
  static int? calculateLifeBalanceScore({
    required List<Map<String, dynamic>> routines,
    required List<Map<String, dynamic>> routineCompletions,
  }) {
    // 1. Identify active domains
    final activeRoutines = routines.where((r) => (r.readInt('isArchived') ?? 0) == 0).toList();
    if (activeRoutines.isEmpty) return null;

    final routineMap = <String, Map<String, dynamic>>{};
    final routineToDomain = <String, String>{};
    for (final r in activeRoutines) {
      final id = r.readString('id');
      if (id != null) {
        routineMap[id] = r;
        routineToDomain[id] = mapCategoryToDomain(r.readString('category') ?? 'CUSTOM');
      }
    }

    final activeDomains = routineToDomain.values.toSet();
    final n = activeDomains.length;
    if (n <= 1) return null;

    // 2. Aggregate duration per active domain
    final domainDurations = <String, double>{for (final d in activeDomains) d: 0.0};
    var totalCompletions = 0;
    var totalDurationMinutes = 0.0;

    for (final comp in routineCompletions) {
      final rId = comp.readString('routineId');
      if (rId == null) continue;
      final domain = routineToDomain[rId];
      if (domain != null && activeDomains.contains(domain)) {
        final type = comp.readString('resultType') ?? 'FULL';
        if (type != 'CANNOT_NOW' && type != 'SNOOZED' && type != 'SKIPPED') {
          final minutes = resolveCompletionDurationMinutes(
            routine: routineMap[rId],
            completion: comp,
            domain: domain,
          );
          domainDurations[domain] = (domainDurations[domain] ?? 0.0) + minutes;
          totalDurationMinutes += minutes;
          totalCompletions++;
        }
      }
    }

    if (totalCompletions < minCompletionsForBalance || totalDurationMinutes < minMinutesForBalance) {
      return null;
    }

    // 3. Compute time-weighted normalized variance
    final mu = 1.0 / n;
    var sumSquaredDiffs = 0.0;

    for (final domain in activeDomains) {
      final p = totalDurationMinutes > 0 ? ((domainDurations[domain] ?? 0.0) / totalDurationMinutes) : 0.0;
      sumSquaredDiffs += (p - mu) * (p - mu);
    }

    final variance = sumSquaredDiffs / n;
    final maxVariance = (n - 1) / (n * n);

    final normalizedVariance = maxVariance > 0 ? (variance / maxVariance) : 0.0;
    final score = 100 * (1.0 - normalizedVariance);

    return score.round().clamp(0, 100);
  }

  /// Calculates the total duration in minutes spent on each domain.
  static Map<String, int> calculateDomainMinutes({
    required List<Map<String, dynamic>> routines,
    required List<Map<String, dynamic>> routineCompletions,
  }) {
    final routineMap = <String, Map<String, dynamic>>{};
    final routineToDomain = <String, String>{};
    for (final r in routines) {
      final id = r.readString('id');
      if (id != null) {
        routineMap[id] = r;
        routineToDomain[id] = mapCategoryToDomain(r.readString('category') ?? 'CUSTOM');
      }
    }

    final domainDurations = <String, double>{
      'RELIGION': 0.0,
      'HEALTH': 0.0,
      'LEARNING': 0.0,
      'WORK': 0.0,
      'PERSONAL': 0.0,
      'FREE': 0.0,
      'CUSTOM': 0.0,
    };

    for (final comp in routineCompletions) {
      final rId = comp.readString('routineId');
      if (rId == null) continue;
      final domain = routineToDomain[rId];
      if (domain != null) {
        final type = comp.readString('resultType') ?? 'FULL';
        if (type != 'CANNOT_NOW' && type != 'SNOOZED' && type != 'SKIPPED') {
          final minutes = resolveCompletionDurationMinutes(
            routine: routineMap[rId],
            completion: comp,
            domain: domain,
          );
          domainDurations[domain] = (domainDurations[domain] ?? 0.0) + minutes;
        }
      }
    }

    return domainDurations.map((key, val) => MapEntry(key, val.round()));
  }

  /// Calculates the distribution percentages for each domain based on logged duration.
  static Map<String, double> calculateCategoryDistribution({
    required List<Map<String, dynamic>> routines,
    required List<Map<String, dynamic>> routineCompletions,
  }) {
    final domainMinutes = calculateDomainMinutes(
      routines: routines,
      routineCompletions: routineCompletions,
    );
    final total = domainMinutes.values.fold<int>(0, (a, b) => a + b);

    final distribution = <String, double>{};
    domainMinutes.forEach((domain, minutes) {
      distribution[domain] = total > 0 ? (minutes / total) * 100.0 : 0.0;
    });

    return distribution;
  }

  /// Calculates the balance trend scores historically.
  static Map<int, int?> calculateBalanceTrend({
    required DateTime now,
    required List<Map<String, dynamic>> routines,
    required List<Map<String, dynamic>> routineCompletions,
  }) {
    final trends = <int, int?>{};

    for (var w = 0; w < 4; w++) {
      final start = now.subtract(Duration(days: (w + 1) * 7));
      final end = now.subtract(Duration(days: w * 7));

      final wCompletions = routineCompletions.where((comp) {
        final millis = comp.readInt('completionTime');
        if (millis == null) return false;
        final time = DateTime.fromMillisecondsSinceEpoch(millis);
        return time.isAfter(start) && time.isBefore(end);
      }).toList();

      final score = calculateLifeBalanceScore(
        routines: routines,
        routineCompletions: wCompletions,
      );

      trends[w + 1] = score;
    }

    return trends;
  }
}
