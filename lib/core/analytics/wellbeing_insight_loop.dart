import 'package:ritmo/core/analytics/wellbeing_insight_arbiter.dart';
import 'package:ritmo/core/util/ritmo_date.dart';
import 'package:ritmo/core/util/ritmo_number.dart';
import 'package:sqflite/sqflite.dart';

class WellbeingInsightLoopState {
  const WellbeingInsightLoopState({
    required this.kind,
    required this.date,
    required this.metric,
  });

  final WellbeingInsightKind kind;
  final String date;
  final double metric;
}

/// Stores the featured narrative of the day and later asks if it helped.
class WellbeingInsightLoop {
  const WellbeingInsightLoop();

  static const String kindKey = 'wellbeing_loop_kind';
  static const String dateKey = 'wellbeing_loop_date';
  static const String metricKey = 'wellbeing_loop_metric';
  static const int minDaysBeforeOutcome = 7;

  static Future<WellbeingInsightLoopState?> load(dynamic db) async {
    try {
      final rows = await db.query(
        'app_settings',
        where: 'key IN (?, ?, ?)',
        whereArgs: [kindKey, dateKey, metricKey],
      );
      String? kindName;
      String? date;
      double? metric;
      for (final row in rows) {
        final key = row['key'] as String?;
        final value = row['value'] as String?;
        if (key == kindKey) kindName = value;
        if (key == dateKey) date = value;
        if (key == metricKey) metric = double.tryParse(value ?? '');
      }
      if (kindName == null || date == null || metric == null) return null;
      final kind = WellbeingInsightKind.values.where((k) => k.name == kindName);
      if (kind.isEmpty) return null;
      return WellbeingInsightLoopState(kind: kind.first, date: date, metric: metric);
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveIfNewDay({
    required dynamic db,
    required DateTime now,
    required WellbeingInsight featured,
    required WellbeingInsightLoopState? previous,
    required Map<WellbeingInsightKind, double> metrics,
  }) async {
    final today = RitmoDate.dayKey(now);
    if (previous?.date == today) return;

    final kind = featured.kind == WellbeingInsightKind.loopOutcome
        ? (previous?.kind ?? featured.kind)
        : featured.kind;
    if (kind == WellbeingInsightKind.loopOutcome) return;
    final metric = metrics[kind];
    if (metric == null) return;

    final nowMs = now.millisecondsSinceEpoch;
    try {
      for (final entry in {
        kindKey: kind.name,
        dateKey: today,
        metricKey: metric.toString(),
      }.entries) {
        await db.insert(
          'app_settings',
          {
            'key': entry.key,
            'value': entry.value,
            'updatedAt': nowMs,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    } catch (_) {}
  }

  static WellbeingInsight? outcome({
    required WellbeingInsightLoopState? previous,
    required DateTime now,
    required Map<WellbeingInsightKind, double> currentMetrics,
  }) {
    if (previous == null) return null;
    if (previous.kind == WellbeingInsightKind.loopOutcome) return null;
    final prevDate = RitmoDate.tryParseDayKey(previous.date);
    if (prevDate == null) return null;
    final days = RitmoDate.startOfDay(now).difference(RitmoDate.startOfDay(prevDate)).inDays;
    if (days < minDaysBeforeOutcome) return null;
    final current = currentMetrics[previous.kind];
    if (current == null) return null;

    final delta = current - previous.metric;
    final improved = delta >= _threshold(previous.kind);
    final label = _kindLabel(previous.kind);
    if (improved) {
      return WellbeingInsight(
        kind: WellbeingInsightKind.loopOutcome,
        maturity: WellbeingInsightMaturity.ready,
        title: 'روایت هفتهٔ قبل اثر داشت',
        body: 'بعد از دیدن «$label»، شاخص مرتبط بهتر شده. همین مسیر را یک هفتهٔ دیگر ادامه بده.',
        score: 1.42,
        have: days,
        need: minDaysBeforeOutcome,
      );
    }
    return WellbeingInsight(
      kind: WellbeingInsightKind.loopOutcome,
      maturity: WellbeingInsightMaturity.ready,
      title: 'هنوز اثر واضحی دیده نشد',
      body: 'هفتهٔ پیش «$label» را دیدی. تغییر شاخص هنوز از نویز روزمره بزرگ‌تر نیست — زود است نتیجه بگیریم.',
      score: 0.74,
      have: days,
      need: minDaysBeforeOutcome,
    );
  }

  static Map<WellbeingInsightKind, double> metricsFor({
    required WellbeingInsightInput input,
  }) {
    final out = <WellbeingInsightKind, double>{};
    final balanceHours = input.sleep?.sleepBalanceHours;
    if (balanceHours != null) {
      out[WellbeingInsightKind.lastNightSleep] = balanceHours;
      out[WellbeingInsightKind.sleepBank] = balanceHours;
      out[WellbeingInsightKind.sleepNextDay] = balanceHours;
      out[WellbeingInsightKind.bestBedtime] = balanceHours;
      out[WellbeingInsightKind.tripleChain] = balanceHours;
    }
    final streak = input.reflection?.currentStreak;
    if (streak != null) {
      out[WellbeingInsightKind.reflectionStreak] = streak.toDouble();
      out[WellbeingInsightKind.reflectionLink] = streak.toDouble();
    }
    final energyAvg = input.energy?.avgLevel;
    if (energyAvg != null) {
      out[WellbeingInsightKind.goldenWindow] = energyAvg;
      out[WellbeingInsightKind.moodEnergyLink] = energyAvg;
    }
    final score = input.balance?.score;
    if (score != null) {
      out[WellbeingInsightKind.balanceTrend] = score.toDouble();
    }
    final index = input.index?.value;
    if (index != null) {
      out[WellbeingInsightKind.indexDriver] = index;
    }
    return out;
  }

  static double _threshold(WellbeingInsightKind kind) {
    switch (kind) {
      case WellbeingInsightKind.reflectionStreak:
      case WellbeingInsightKind.reflectionLink:
        return 1.0;
      case WellbeingInsightKind.balanceTrend:
      case WellbeingInsightKind.indexDriver:
        return 3.0;
      default:
        return 0.25;
    }
  }

  static String _kindLabel(WellbeingInsightKind kind) {
    switch (kind) {
      case WellbeingInsightKind.lastNightSleep:
        return 'خواب دیشب';
      case WellbeingInsightKind.reflectionStreak:
        return 'استریک بازتاب';
      case WellbeingInsightKind.goldenWindow:
        return 'پنجرهٔ طلایی';
      case WellbeingInsightKind.moodEnergyLink:
        return 'حال و انرژی';
      case WellbeingInsightKind.sleepNextDay:
        return 'خواب و روز بعد';
      case WellbeingInsightKind.reflectionLink:
        return 'بازتاب و حال';
      case WellbeingInsightKind.sleepBank:
        return 'ذخیرهٔ خواب';
      case WellbeingInsightKind.bestBedtime:
        return 'ساعت خواب بهتر';
      case WellbeingInsightKind.balanceTrend:
        return 'توزیع تلاش';
      case WellbeingInsightKind.indexDriver:
        return 'چرا این عدد';
      case WellbeingInsightKind.tripleChain:
        return 'زنجیرهٔ سه‌تایی';
      case WellbeingInsightKind.loopOutcome:
        return 'نتیجهٔ هفته';
    }
  }
}
