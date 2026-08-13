import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/analytics/sleep_engine.dart';
import 'package:ritmo/features/sleep/models/sleep_models.dart';

void main() {
  final target = SleepTarget(
    bedtime: '23:00',
    wake: '07:00',
    durationMinutes: 480,
  );

  test('consistency requires five logs', () async {
    final engine = SleepEngine();
    final logs4 = List.generate(
      4,
      (i) => SleepLog(
        date: '2026-01-0${i + 1}',
        reason: '',
        createdAt: 0,
        bedtimeAt: DateTime(2026, 1, i + 1, 23, 0).millisecondsSinceEpoch,
        wakeAt: DateTime(2026, 1, i + 2, 7, 0).millisecondsSinceEpoch,
        durationMinutes: 480,
        quality: SleepQuality.good,
      ),
    );

    final out4 = await engine.calculate(SleepEngineInput(
      sleepLogs: logs4,
      target: target,
      energyLogs: [],
      moodLogs: [],
      today: DateTime(2026, 1, 10),
    ));
    expect(out4.consistencyScore, isNull);

    final logs5 = List.generate(
      5,
      (i) => SleepLog(
        date: '2026-01-0${i + 1}',
        reason: '',
        createdAt: 0,
        bedtimeAt: DateTime(2026, 1, i + 1, 23, 0).millisecondsSinceEpoch,
        wakeAt: DateTime(2026, 1, i + 2, 7, 0).millisecondsSinceEpoch,
        durationMinutes: 480,
        quality: SleepQuality.good,
      ),
    );

    final out5 = await engine.calculate(SleepEngineInput(
      sleepLogs: logs5,
      target: target,
      energyLogs: [],
      moodLogs: [],
      today: DateTime(2026, 1, 10),
    ));
    expect(out5.consistencyScore, isNotNull);
  });

  test('sleep balance is two sided', () {
    final logs = [
      SleepLog(
        date: '2026-01-14',
        reason: '',
        createdAt: 0,
        durationMinutes: 600, // 10h (+2.5h surplus)
        quality: SleepQuality.good,
      ),
    ];
    final balance = SleepEngine.calculateSleepBalanceHours(
      logs: logs,
      targetHours: 7.5,
      now: DateTime(2026, 1, 15),
    );
    expect(balance, greaterThan(0));
  });

  test('old sleep debt decays', () {
    final oldLog = [
      SleepLog(
        date: '2026-01-01',
        reason: '',
        createdAt: 0,
        durationMinutes: 300, // 5h (deficit)
        quality: SleepQuality.poor,
      ),
    ];
    final recentLog = [
      SleepLog(
        date: '2026-01-14',
        reason: '',
        createdAt: 0,
        durationMinutes: 300, // 5h (deficit)
        quality: SleepQuality.poor,
      ),
    ];

    final now = DateTime(2026, 1, 15);
    final oldBalance = SleepEngine.calculateSleepBalanceHours(logs: oldLog, targetHours: 7.5, now: now);
    final recentBalance = SleepEngine.calculateSleepBalanceHours(logs: recentLog, targetHours: 7.5, now: now);

    expect(oldBalance.abs(), lessThan(recentBalance.abs()));
  });

  test('correlation requires thirty points', () async {
    final engine = SleepEngine();
    final logs29 = List.generate(
      29,
      (i) => SleepLog(
        date: '2026-01-${(i + 1).toString().padLeft(2, '0')}',
        reason: '',
        createdAt: 0,
        durationMinutes: 480,
        quality: SleepQuality.good,
      ),
    );
    final out29 = await engine.calculate(SleepEngineInput(
      sleepLogs: logs29,
      target: target,
      energyLogs: [],
      moodLogs: [],
      today: DateTime(2026, 2, 1),
    ));
    expect(out29.sleepEnergyCorrelation, isNull);
  });

  test('pearson rejects unequal series', () {
    final engine = SleepEngine();
    expect(
      () => engine.calculate(SleepEngineInput(
        sleepLogs: [],
        target: target,
        energyLogs: [],
        moodLogs: [],
        today: DateTime.now(),
      )),
      returnsNormally,
    );
  });

  test('best bedtime window needs four samples', () async {
    final engine = SleepEngine();
    final logs3 = List.generate(
      3,
      (i) => SleepLog(
        date: '2026-01-0${i + 1}',
        reason: '',
        createdAt: 0,
        bedtimeAt: DateTime(2026, 1, i + 1, 23, 0).millisecondsSinceEpoch,
        wakeAt: DateTime(2026, 1, i + 2, 7, 0).millisecondsSinceEpoch,
        durationMinutes: 480,
        quality: SleepQuality.good,
      ),
    );
    final out = await engine.calculate(SleepEngineInput(
      sleepLogs: logs3,
      target: target,
      energyLogs: [
        {'loggedAt': DateTime(2026, 1, 2, 10).millisecondsSinceEpoch, 'energyLevel': 'HIGH'},
      ],
      moodLogs: [],
      today: DateTime(2026, 1, 5),
    ));
    expect(out.bestBedtimeWindow, isNull);
  });
}
