import 'dart:math' as math;

import 'package:ritmo/core/utils/persian_digits.dart';

/// از کجا عددی که به کاربر نشان میدهیم آمده است.
///
/// این تفکیک عمدی است: نمایش یک عدد «مطمئن» که در واقع مقدار پیشفرض بوده،
/// بدترین حالت ممکن است. کاربر باید بداند دارد تخمین میبیند یا ثبت خودش را.
enum EnergySource {
  /// ثبت دستی تازه و داخل بازهٔ اعتبار.
  logged,

  /// ثبت دستی رو به کهنهشدن؛ با مدل ترکیب شده است.
  decaying,

  /// هیچ ثبت معتبری نیست؛ مدل از ساعت زیستی، خواب و رفتار امروز تخمین زده.
  estimated,

  /// آنقدر داده نداریم که حرفی بزنیم.
  unknown,
}

/// یک خط از پاسخ «چرا این عدد؟».
class EnergyFactor {
  const EnergyFactor({required this.label, this.delta = 0});

  final String label;

  /// اثر تقریبی این عامل بر درصد نهایی. صفر یعنی توضیحی است، نه اثری.
  final double delta;

  String get line {
    final rounded = delta.abs().round();
    if (rounded == 0) return label;
    final sign = delta > 0 ? '+' : '-';
    return '$label: ${toPersianDigits('$rounded')}٪$sign';
  }
}

/// خروجی مدل انرژی برای «همین حالا».
class EnergyEstimate {
  const EnergyEstimate({
    required this.percent,
    required this.label,
    required this.description,
    required this.recommendation,
    required this.source,
    required this.confidence,
    required this.factors,
    required this.sourceLine,
    this.minutesSinceLog,
  });

  /// ۱۰ تا ۱۰۰.
  final double percent;

  /// «بالا» / «متوسط» / «پایین».
  final String label;

  /// این سطح به درد چه کاری میخورد.
  final String description;

  /// همین حالا چه کاری منطقیتر است.
  final String recommendation;

  final EnergySource source;

  /// ۰ تا ۱ — چقدر شواهد پشت این عدد است.
  final double confidence;

  final List<EnergyFactor> factors;

  /// خط منبع، مثل «ثبت شده ۲۰ دقیقه پیش».
  final String sourceLine;

  final int? minutesSinceLog;

  bool get isEstimated => source != EnergySource.logged;

  /// زیر این آستانه هیچ عددی نشان نمیدهیم و حالت «ثبتنشده» میماند.
  bool get isTrustworthy => confidence >= 0.2;

  List<String> get explanationLines => <String>[
        for (final f in factors) f.line,
        sourceLine,
      ];
}

/// مدل انرژی ریتمو — کاملاً خالص و بدون وابستگی به دیتابیس یا شبکه.
///
/// همهٔ ورودیها از بیرون تزریق میشوند تا هم تست کردنش ساده باشد و هم
/// کوئریها کراندار بمانند.
class EnergyModel {
  EnergyModel._();

  /// مبنای خنثی وقتی هیچ سیگنالی نداریم.
  static const double neutralBase = 60;

  static const Map<int, String> _weekdayNames = <int, String>{
    1: 'دوشنبه',
    2: 'سه‌شنبه',
    3: 'چهارشنبه',
    4: 'پنج‌شنبه',
    5: 'جمعه',
    6: 'شنبه',
    7: 'یک‌شنبه',
  };

  static double levelToPercent(String? level) {
    switch ((level ?? 'MEDIUM').toUpperCase()) {
      case 'HIGH':
        return 88;
      case 'LOW':
        return 34;
      default:
        return 62;
    }
  }

  static String levelLabel(String? level) {
    switch ((level ?? 'MEDIUM').toUpperCase()) {
      case 'HIGH':
        return 'بالا';
      case 'LOW':
        return 'پایین';
      default:
        return 'متوسط';
    }
  }

  /// کلید سطح برای ویجت هوم و نوتیفیکیشن وضعیت.
  static String bandKey(double percent) {
    if (percent >= 78) return 'high';
    if (percent >= 55) return 'medium';
    return 'low';
  }

  static String bandLabel(double percent) {
    if (percent >= 78) return 'بالا';
    if (percent >= 55) return 'متوسط';
    return 'پایین';
  }

  /// منحنی ساعت زیستی. عمداً حول نیمهشب نمیپیچد و افت بعدازظهر را دارد.
  static double circadianDelta(int hour) {
    if (hour <= 4) return -30;
    if (hour == 5) return -20;
    if (hour == 6) return -8;
    if (hour == 7) return 2;
    if (hour == 8) return 8;
    if (hour <= 11) return 14;
    if (hour == 12) return 4;
    if (hour <= 14) return -8;
    if (hour <= 17) return 6;
    if (hour <= 19) return 0;
    if (hour <= 21) return -10;
    if (hour == 22) return -18;
    return -26;
  }

  static String _circadianLabel(int hour) {
    if (hour <= 5) return 'ساعت زیستی (بازهٔ خواب شبانه)';
    if (hour <= 6) return 'ساعت زیستی (تازه بیدار)';
    if (hour <= 11) return 'ساعت زیستی (اوج صبحگاهی)';
    if (hour == 12) return 'ساعت زیستی (نزدیک ظهر)';
    if (hour <= 14) return 'ساعت زیستی (افت بعدازظهر)';
    if (hour <= 17) return 'ساعت زیستی (بهبود عصرگاهی)';
    if (hour <= 19) return 'ساعت زیستی (تثبیت غروب)';
    if (hour <= 21) return 'ساعت زیستی (شروع سرازیری شب)';
    return 'ساعت زیستی (آماده‌سازی خواب)';
  }

  /// تخمین انرژی همین لحظه.
  ///
  /// [energyLogs] و [completions] باید از قبل کراندار شده باشند (مثلاً ۳۰ روز).
  /// [recentCompletions] یعنی موارد سه ساعت گذشته و هر ردیف بهتر است کلید
  /// `category` داشته باشد تا اثر ورزش از اثر کار تفکیک شود.
  static EnergyEstimate estimate({
    required DateTime now,
    required List<Map<String, dynamic>> energyLogs,
    required List<Map<String, dynamic>> recentCompletions,
    int todayCompletionCount = 0,
    Map<String, dynamic>? lastNightSleep,
    int validityMinutes = 180,
    String defaultLevel = 'MEDIUM',
    String? peakWindow,
  }) {
    final validity = validityMinutes < 30 ? 180 : validityMinutes;
    final factors = <EnergyFactor>[];

    final circadian = circadianDelta(now.hour);
    factors.add(EnergyFactor(label: _circadianLabel(now.hour), delta: circadian));

    final sleepAdj = _sleepAdjustment(lastNightSleep, factors);
    final activityAdj = _activityAdjustment(recentCompletions, factors);

    var baseline = neutralBase + circadian + sleepAdj + activityAdj;

    // شخصیسازی: میانگین خودِ کاربر در همین ساعت روز.
    final hourStats = _sameHourStats(energyLogs, now);
    if (hourStats != null && hourStats.samples >= 3) {
      baseline = 0.5 * baseline + 0.5 * (hourStats.average + activityAdj);
      factors.add(EnergyFactor(
        label:
            'میانگین خودت در این ساعت (${toPersianDigits('${hourStats.samples}')} ثبت)',
      ));
    }

    var percent = baseline;
    var source = EnergySource.estimated;
    int? minutesSinceLog;
    String? note;

    final latest = _latestLog(energyLogs);
    if (latest != null) {
      final elapsed = now
          .difference(DateTime.fromMillisecondsSinceEpoch(latest.loggedAt))
          .inMinutes;
      if (elapsed >= 0) {
        minutesSinceLog = elapsed;
        if (elapsed <= validity) {
          final anchor =
              levelToPercent(latest.level) + activityAdj + circadian * 0.4;
          final weight = (1 - (elapsed / validity)).clamp(0.0, 1.0).toDouble();
          percent = weight * anchor + (1 - weight) * baseline;
          source =
              weight >= 0.6 ? EnergySource.logged : EnergySource.decaying;
          note = latest.note;
          factors.insert(
            0,
            EnergyFactor(
              label:
                  'ثبت خودت: ${levelLabel(latest.level)} (وزن ${toPersianDigits('${(weight * 100).round()}')}٪)',
            ),
          );
        }
      }
    }

    if (source == EnergySource.estimated && energyLogs.isEmpty) {
      // پیشفرض تنظیمات فقط وقتی معنا دارد که کاربر خودش انتخابش کرده باشد.
      final fallback = levelToPercent(defaultLevel);
      percent = 0.5 * percent + 0.5 * (fallback + circadian * 0.4);
    }

    percent = percent.clamp(10.0, 100.0).toDouble();

    var confidence = 0.0;
    if (source == EnergySource.logged) {
      confidence += 0.5;
    } else if (source == EnergySource.decaying) {
      confidence += 0.3;
    }
    if (energyLogs.isNotEmpty) confidence += 0.2;
    if (lastNightSleep != null) confidence += 0.2;
    if (todayCompletionCount >= 2) confidence += 0.15;
    if (hourStats != null && hourStats.samples >= 3) confidence += 0.2;
    confidence = confidence.clamp(0.0, 1.0).toDouble();

    if (confidence < 0.2) source = EnergySource.unknown;

    return EnergyEstimate(
      percent: percent,
      label: bandLabel(percent),
      description: _descriptionFor(percent),
      recommendation: _recommendationFor(percent, now, peakWindow),
      source: source,
      confidence: confidence,
      factors: factors,
      sourceLine: _sourceLine(source, minutesSinceLog, note),
      minutesSinceLog: minutesSinceLog,
    );
  }

  static String _descriptionFor(double percent) {
    if (percent >= 78) return 'آمادهٔ سنگین‌ترین و عمیق‌ترین کار امروز';
    if (percent >= 55) return 'مناسب روتین‌ها، جلسات و کارهای معمولی';
    if (percent >= 35) return 'کار سبک، مرور و کارهای اداری؛ تصمیم سنگین نگیر';
    return 'بدنت سراغ استراحت است؛ زور زدن الان گران تمام می‌شود';
  }

  static String _recommendationFor(
    double percent,
    DateTime now,
    String? peakWindow,
  ) {
    final peakHint = _peakHint(now, peakWindow);
    if (percent >= 78) {
      return 'سخت‌ترین کار امروزت را همین حالا شروع کن.';
    }
    if (percent >= 55) {
      return peakHint == null
          ? 'کارهای معمولی و روتین‌ها الان بهترین گزینه‌اند.'
          : 'کارهای معمولی را حالا بزن و کار عمیق را برای $peakHint نگه دار.';
    }
    if (percent >= 35) {
      return peakHint == null
          ? 'کار سبک یا مرور؛ کار سنگین را به بعد موکول کن.'
          : 'کار سبک یا مرور؛ کار سنگین را ببر به $peakHint.';
    }
    return 'بیست دقیقه استراحت واقعی یا یک پیاده‌روی کوتاه، سودش از ادامه دادن بیشتر است.';
  }

  static String? _peakHint(DateTime now, String? peakWindow) {
    if (peakWindow == null || !peakWindow.contains(':')) return null;
    final startHour = int.tryParse(peakWindow.split(':').first.trim());
    if (startHour == null) return null;
    if (startHour <= now.hour) return null;
    return 'حدود ساعت ${toPersianDigits('$startHour')}';
  }

  static String _sourceLine(
    EnergySource source,
    int? minutesSinceLog,
    String? note,
  ) {
    final suffix = (note != null && note.trim().isNotEmpty) ? ' ($note)' : '';
    switch (source) {
      case EnergySource.logged:
        return 'ثبت خودت، ${_ago(minutesSinceLog)}$suffix';
      case EnergySource.decaying:
        return 'بر پایهٔ ثبت ${_ago(minutesSinceLog)}؛ در حال به‌روزرسانی با مدل$suffix';
      case EnergySource.estimated:
        return 'تخمین مدل بر پایهٔ ساعت زیستی، خواب و رفتار امروز';
      case EnergySource.unknown:
        return 'هنوز داده‌ای برای تخمین نداریم';
    }
  }

  static String _ago(int? minutes) {
    if (minutes == null) return 'چند لحظه پیش';
    if (minutes < 1) return 'همین الان';
    if (minutes < 60) return '${toPersianDigits('$minutes')} دقیقه پیش';
    final hours = minutes ~/ 60;
    if (hours < 24) return '${toPersianDigits('$hours')} ساعت پیش';
    final days = hours ~/ 24;
    return '${toPersianDigits('$days')} روز پیش';
  }

  static double _sleepAdjustment(
    Map<String, dynamic>? sleep,
    List<EnergyFactor> out,
  ) {
    if (sleep == null) return 0;
    final duration = (sleep['durationMinutes'] as num?)?.toInt();
    if (duration == null || duration <= 0) return 0;

    double adj;
    if (duration < 300) {
      adj = -18;
    } else if (duration < 360) {
      adj = -12;
    } else if (duration < 420) {
      adj = -5;
    } else if (duration >= 510) {
      adj = 6;
    } else {
      adj = 3;
    }

    final efficiency = (sleep['sleepEfficiency'] as num?)?.toDouble();
    if (efficiency != null && efficiency > 0 && efficiency < 70) adj -= 6;

    adj = adj.clamp(-22.0, 8.0).toDouble();

    final hours = duration ~/ 60;
    final minutes = duration % 60;
    out.add(EnergyFactor(
      label:
          'خواب دیشب (${toPersianDigits('$hours')}:${toPersianDigits(minutes.toString().padLeft(2, '0'))})',
      delta: adj,
    ));
    return adj;
  }

  /// اثر رفتار سه ساعت گذشته.
  ///
  /// باگ قدیمی اینجا بود: هر ردیف تکمیل، حتی «نتوانستم» و «تعویق»، انرژی را
  /// بالا میبرد. حالا نوع نتیجه خوانده میشود.
  static double _activityAdjustment(
    List<Map<String, dynamic>> completions,
    List<EnergyFactor> out,
  ) {
    var fitness = 0.0;
    var cognitive = 0.0;
    var missed = 0.0;
    var other = 0.0;

    for (final c in completions) {
      final type = (c['resultType'] as String? ?? 'FULL').toUpperCase();
      final category = (c['category'] as String? ?? '').toLowerCase();

      if (type == 'CANNOT_NOW' || type == 'SNOOZED' || type == 'SKIPPED') {
        missed -= 2;
        continue;
      }
      if (category == 'fitness') {
        fitness += 4;
      } else if (category == 'work' ||
          category == 'learning' ||
          category == 'konkur') {
        cognitive -= 3;
      } else {
        other += 1;
      }
    }

    fitness = math.min(fitness, 12);
    cognitive = math.max(cognitive, -12);
    missed = math.max(missed, -8);
    other = math.min(other, 4);

    if (fitness > 0) {
      out.add(EnergyFactor(label: 'ورزش اخیر', delta: fitness));
    }
    if (cognitive < 0) {
      out.add(EnergyFactor(label: 'خستگی کار/مطالعهٔ اخیر', delta: cognitive));
    }
    if (missed < 0) {
      out.add(EnergyFactor(label: 'کارهای تعویق‌شده یا انجام‌نشده', delta: missed));
    }
    if (other > 0) {
      out.add(EnergyFactor(label: 'کارهای انجام‌شدهٔ اخیر', delta: other));
    }

    return fitness + cognitive + missed + other;
  }

  static ({double average, int samples})? _sameHourStats(
    List<Map<String, dynamic>> logs,
    DateTime now,
  ) {
    var sum = 0.0;
    var count = 0;
    for (final log in logs) {
      final loggedAt = log['loggedAt'] as int?;
      if (loggedAt == null) continue;
      final at = DateTime.fromMillisecondsSinceEpoch(loggedAt);
      if (at.year == now.year && at.month == now.month && at.day == now.day) {
        continue; // ثبتهای امروز جداگانه لنگر میشوند.
      }
      final diff = (at.hour - now.hour).abs();
      if (diff > 1 && diff < 23) continue;
      sum += levelToPercent(log['energyLevel'] as String?);
      count++;
    }
    if (count == 0) return null;
    return (average: sum / count, samples: count);
  }

  static _LatestLog? _latestLog(List<Map<String, dynamic>> logs) {
    int? bestAt;
    Map<String, dynamic>? best;
    for (final log in logs) {
      final loggedAt = log['loggedAt'] as int?;
      if (loggedAt == null) continue;
      if (bestAt == null || loggedAt > bestAt) {
        bestAt = loggedAt;
        best = log;
      }
    }
    if (best == null || bestAt == null) return null;
    return _LatestLog(
      loggedAt: bestAt,
      level: best['energyLevel'] as String? ?? 'MEDIUM',
      note: best['note'] as String?,
    );
  }

  static double _successWeight(String? resultType) {
    switch ((resultType ?? 'FULL').toUpperCase()) {
      case 'FULL':
        return 1;
      case 'LIGHT':
        return 0.7;
      case 'PARTIAL':
        return 0.5;
      case 'MINIMAL':
        return 0.4;
      default:
        return 0;
    }
  }

  static String _hh(int hour) => hour.toString().padLeft(2, '0');

  /// بازهٔ اوج عملکرد — فقط داخل ساعات بیداری و فقط با شواهد واقعی.
  static String? peakWindow({
    required List<Map<String, dynamic>> energyLogs,
    required List<Map<String, dynamic>> completions,
    int minCompletions = 8,
    int dayStartHour = 6,
    int dayEndHour = 23,
  }) {
    final successes = completions
        .where((c) => _successWeight(c['resultType'] as String?) > 0)
        .toList();
    if (successes.length < minCompletions) return null;

    final doneByHour = List<double>.filled(24, 0);
    for (final c in successes) {
      final at = c['completionTime'] as int?;
      if (at == null) continue;
      final hour = DateTime.fromMillisecondsSinceEpoch(at).hour;
      doneByHour[hour] += _successWeight(c['resultType'] as String?);
    }

    final energySum = List<double>.filled(24, 0);
    final energyCount = List<int>.filled(24, 0);
    for (final log in energyLogs) {
      final at = log['loggedAt'] as int?;
      if (at == null) continue;
      final hour = DateTime.fromMillisecondsSinceEpoch(at).hour;
      energySum[hour] += levelToPercent(log['energyLevel'] as String?);
      energyCount[hour]++;
    }

    final maxDone = doneByHour.reduce(math.max);
    if (maxDone <= 0) return null;

    double scoreFor(int hour) {
      final activity = (doneByHour[hour] / maxDone) * 100;
      if (energyCount[hour] == 0) return activity;
      final energy = energySum[hour] / energyCount[hour];
      return 0.5 * activity + 0.5 * energy;
    }

    var bestStart = -1;
    var bestScore = -1.0;
    for (var start = dayStartHour; start + 3 <= dayEndHour; start++) {
      var windowDone = 0.0;
      var score = 0.0;
      for (var k = 0; k < 3; k++) {
        windowDone += doneByHour[start + k];
        score += scoreFor(start + k);
      }
      // بدون شاهد واقعی داخل خودِ بازه، پیشنهاد ندهیم.
      if (windowDone < 3) continue;
      if (score > bestScore) {
        bestScore = score;
        bestStart = start;
      }
    }

    if (bestStart < 0) return null;
    return '${_hh(bestStart)}:00 - ${_hh(bestStart + 3)}:00';
  }

  /// بازهٔ افت — انرژی پایین ثبتشده و کارهای زمینمانده.
  static String? fatigueWindow({
    required List<Map<String, dynamic>> energyLogs,
    required List<Map<String, dynamic>> completions,
    int dayStartHour = 6,
    int dayEndHour = 23,
  }) {
    final fatigue = List<double>.filled(24, 0);

    for (final log in energyLogs) {
      if ((log['energyLevel'] as String? ?? '').toUpperCase() != 'LOW') continue;
      final at = log['loggedAt'] as int?;
      if (at == null) continue;
      fatigue[DateTime.fromMillisecondsSinceEpoch(at).hour] += 1;
    }

    for (final c in completions) {
      final type = (c['resultType'] as String? ?? '').toUpperCase();
      if (type != 'CANNOT_NOW' && type != 'SNOOZED' && type != 'SKIPPED') {
        continue;
      }
      final at = c['completionTime'] as int?;
      if (at == null) continue;
      fatigue[DateTime.fromMillisecondsSinceEpoch(at).hour] += 1;
    }

    var bestStart = -1;
    var best = 0.0;
    for (var start = dayStartHour; start + 3 <= dayEndHour; start++) {
      final total = fatigue[start] + fatigue[start + 1] + fatigue[start + 2];
      if (total > best) {
        best = total;
        bestStart = start;
      }
    }

    if (bestStart < 0 || best < 3) return null;
    return '${_hh(bestStart)}:00 - ${_hh(bestStart + 3)}:00';
  }

  /// پربازدهترین روز هفته.
  ///
  /// نسخهٔ قبلی فقط وقتی جواب میداد که هر هفت روز هفته دستکم چهار تاریخ
  /// داشته باشند؛ یعنی عملاً هیچوقت. حالا با دادهٔ ناقص هم کار میکند و اگر
  /// برنده اختلاف معناداری نداشته باشد ساکت میماند.
  static String? productiveWeekday({
    required List<Map<String, dynamic>> completions,
    int minDatesPerWeekday = 2,
    int minWeekdays = 3,
  }) {
    final datesByWeekday = <int, Set<String>>{};
    final scoreByWeekday = <int, double>{};

    for (final c in completions) {
      final at = c['completionTime'] as int?;
      if (at == null) continue;
      final dt = DateTime.fromMillisecondsSinceEpoch(at);
      final date = (c['completionDate'] as String?) ??
          dt.toIso8601String().substring(0, 10);
      (datesByWeekday[dt.weekday] ??= <String>{}).add(date);
      scoreByWeekday[dt.weekday] = (scoreByWeekday[dt.weekday] ?? 0) +
          _successWeight(c['resultType'] as String?);
    }

    final eligible = datesByWeekday.entries
        .where((e) => e.value.length >= minDatesPerWeekday)
        .map((e) => e.key)
        .toList();
    if (eligible.length < minWeekdays) return null;

    var bestWeekday = -1;
    var bestAverage = -1.0;
    var runnerUp = 0.0;
    for (final weekday in eligible) {
      final average =
          (scoreByWeekday[weekday] ?? 0) / datesByWeekday[weekday]!.length;
      if (average > bestAverage) {
        runnerUp = bestAverage;
        bestAverage = average;
        bestWeekday = weekday;
      } else if (average > runnerUp) {
        runnerUp = average;
      }
    }

    if (bestWeekday < 0 || bestAverage <= 0) return null;
    if (runnerUp > 0 && bestAverage < runnerUp * 1.1) return null;
    return _weekdayNames[bestWeekday];
  }
}

class _LatestLog {
  const _LatestLog({
    required this.loggedAt,
    required this.level,
    this.note,
  });

  final int loggedAt;
  final String level;
  final String? note;
}
