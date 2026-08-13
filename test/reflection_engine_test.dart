import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/analytics/reflection_engine.dart';

void main() {
  group('ReflectionEngine Analytics Engine Tests', () {
    final engine = ReflectionEngine();

    test('calculate streak correctly - continuous', () async {
      final today = DateTime(2026, 6, 26);

      final input = ReflectionEngineInput(
        dailyReflections: [
          {'date': '2026-06-26', 'mood_score': 5},
          {'date': '2026-06-25', 'mood_score': 4},
          {'date': '2026-06-24', 'mood_score': 3},
        ],
        dailyCheckins: [],
        energyLogs: [],
        moodLogs: [],
        today: today,
      );

      final output = await engine.calculate(input);
      expect(output.currentStreak, 3);
      expect(output.longestStreak, 3);
      expect(output.forgivenThisWeek, isFalse);
      expect(output.forgivenessAvailable, isTrue);
      expect(output.entryCount, 3);
      expect(output.completionRate, closeTo(3 / 14, 0.01));
    });

    test('one missed day in the last week is forgiven and does not increment', () async {
      final today = DateTime(2026, 6, 26);

      final input = ReflectionEngineInput(
        dailyReflections: [
          {'date': '2026-06-26', 'mood_score': 5},
          {'date': '2026-06-25', 'mood_score': 4},
          // Missing 24th — forgiven, not counted
          {'date': '2026-06-23', 'mood_score': 3},
          {'date': '2026-06-22', 'mood_score': 4},
          {'date': '2026-06-21', 'mood_score': 4},
        ],
        dailyCheckins: [],
        energyLogs: [],
        moodLogs: [],
        today: today,
      );

      final output = await engine.calculate(input);
      expect(output.currentStreak, 5); // 26, 25, skip 24, 23, 22, 21
      expect(output.longestStreak, 3); // raw historical max stays honest
      expect(output.forgivenThisWeek, isTrue);
      expect(output.forgivenessAvailable, isFalse);
    });

    test('two consecutive missed days still break the current streak', () async {
      final today = DateTime(2026, 6, 26);
      final walk = ReflectionEngine.walkCurrentStreak(
        dates: {'2026-06-23', '2026-06-22'},
        today: today,
      );
      expect(walk.currentStreak, 0);
      expect(walk.forgivenThisWeek, isFalse);
    });

    test('Pearson correlation - fewer than 30 pairs stays null', () async {
      final today = DateTime(2026, 6, 26);

      final reflections = [
        {'date': '2026-06-26', 'mood_score': 5},
        {'date': '2026-06-25', 'mood_score': 4},
        {'date': '2026-06-24', 'mood_score': 2},
      ];

      final m26 = DateTime(2026, 6, 26, 12).millisecondsSinceEpoch;
      final m25 = DateTime(2026, 6, 25, 12).millisecondsSinceEpoch;
      final m24 = DateTime(2026, 6, 24, 12).millisecondsSinceEpoch;

      final moodLogs = [
        {'loggedAt': m26, 'valence': 5},
        {'loggedAt': m25, 'valence': 4},
        {'loggedAt': m24, 'valence': 2},
      ];

      final input = ReflectionEngineInput(
        dailyReflections: reflections,
        dailyCheckins: [],
        energyLogs: [],
        moodLogs: moodLogs,
        today: today,
      );

      final output = await engine.calculate(input);
      expect(output.reflectionMoodCorrelation, isNull);
      expect(output.correlationInsight, contains('در حال تحلیل'));
    });

    test('Pearson correlation - positive correlation at 30 pairs', () async {
      final today = DateTime(2026, 6, 26);
      final reflections = <Map<String, dynamic>>[];
      final moodLogs = <Map<String, dynamic>>[];

      for (var i = 0; i < 30; i++) {
        final day = today.subtract(Duration(days: i));
        final y = day.year.toString().padLeft(4, '0');
        final m = day.month.toString().padLeft(2, '0');
        final d = day.day.toString().padLeft(2, '0');
        final date = '$y-$m-$d';
        final score = (i % 2 == 0) ? 5.0 : 2.0;
        reflections.add({'date': date, 'mood_score': score});
        moodLogs.add({
          'loggedAt': DateTime(day.year, day.month, day.day, 12).millisecondsSinceEpoch,
          'valence': score,
        });
      }

      final input = ReflectionEngineInput(
        dailyReflections: reflections,
        dailyCheckins: [],
        energyLogs: [],
        moodLogs: moodLogs,
        today: today,
        horizonDays: 30,
      );

      final output = await engine.calculate(input);
      expect(output.reflectionMoodCorrelation, isNotNull);
      expect(output.reflectionMoodCorrelation, greaterThan(0.9));
      expect(output.correlationInsight, contains('روحیه بالاتری'));
    });

    test('missing mood_score is not treated as a neutral 3.0', () async {
      final today = DateTime(2026, 6, 26);

      final input = ReflectionEngineInput(
        dailyReflections: [
          {'date': '2026-06-26', 'goodThing': 'فقط متن، بدون نمره'},
          {'date': '2026-06-25', 'goodThing': 'باز هم بدون نمره'},
          {'date': '2026-06-24', 'mood_score': 5},
        ],
        dailyCheckins: [],
        energyLogs: [],
        moodLogs: [],
        today: today,
      );

      final output = await engine.calculate(input);
      expect(output.avgMoodScore, 5);
      expect(output.moodTrend, [5]);
      expect(output.entryCount, 3);
    });

    test('fingerprint includes checkin/energy/mood/theme inputs', () {
      final today = DateTime(2026, 6, 26);
      final a = ReflectionEngineInput(
        dailyReflections: [
          {'date': '2026-06-26'},
        ],
        dailyCheckins: [],
        energyLogs: [],
        moodLogs: [],
        today: today,
      );
      final b = ReflectionEngineInput(
        dailyReflections: [
          {'date': '2026-06-26'},
        ],
        dailyCheckins: [],
        energyLogs: [
          {'loggedAt': today.millisecondsSinceEpoch, 'energyLevel': 'HIGH'},
        ],
        moodLogs: [],
        today: today,
      );
      expect(engine.fingerprint(a), isNot(engine.fingerprint(b)));
    });
  });
}
