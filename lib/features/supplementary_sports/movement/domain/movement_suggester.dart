import 'package:flutter/material.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/analytics/movement_load_calculator.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/supplementary_sports/movement/data/movement_repository.dart';
import 'package:ritmo/features/supplementary_sports/movement/data/unified_planner_repository.dart';
import 'package:ritmo/features/supplementary_sports/movement/domain/movement_budget.dart';
import 'package:ritmo/features/supplementary_sports/movement/domain/movement_kind.dart';
import 'package:ritmo/features/supplementary_sports/movement/domain/movement_reminder_defaults.dart';
import 'package:ritmo/features/supplementary_sports/movement/domain/week_plan_item.dart';
import 'package:ritmo/features/supplementary_sports/data/models/ss_user_profile_model.dart';

class MovementSuggestion {
  const MovementSuggestion({
    required this.kind,
    required this.suggestedMinutes,
    required this.suggestedIntensity,
    required this.reasonFa,
    required this.confidence,
    required this.alternatives,
  });

  final MovementKind kind;
  final int suggestedMinutes;
  final MovementIntensity suggestedIntensity;
  final String reasonFa;
  final double confidence;
  final List<MovementKind> alternatives;
}

class MovementWeekSuggestion {
  const MovementWeekSuggestion({
    required this.kind,
    required this.weekdaySat0,
    required this.suggestedTime,
    required this.suggestedMinutes,
    required this.suggestedIntensity,
    required this.reasonFa,
    required this.confidence,
    required this.reminderMinutes,
  });

  final MovementKind kind;
  final int weekdaySat0;
  final TimeOfDay suggestedTime;
  final int suggestedMinutes;
  final MovementIntensity suggestedIntensity;
  final String reasonFa;
  final double confidence;
  final int reminderMinutes;
}

class SuggestionCtx {
  const SuggestionCtx({
    required this.budget,
    required this.availableMinutes,
    required this.energy,
    required this.soreness,
    required this.painLevel,
    required this.limitations,
    required this.recentKindCodes14d,
    required this.jalaliMonth,
  });

  final MovementBudgetSnapshot budget;
  final int availableMinutes;
  final int energy;
  final int soreness;
  final int painLevel;
  final Set<String> limitations;
  final Set<String> recentKindCodes14d;
  final int jalaliMonth;
}

double readinessFit(MovementKind k, SuggestionCtx c) {
  final lowEnergy = c.energy <= 2;
  final highSoreness = c.soreness >= 4;
  if (lowEnergy || highSoreness) {
    // Prefer low MET and low joint impact
    var score = 1.0;
    if (k.baseMet > 5.0) score -= 0.5;
    if (k.jointImpact > 1) score -= 0.5;
    return score.clamp(0.0, 1.0);
  }
  // Energy is high, prefer slightly higher baseMet if budget gap is large
  final gap = c.budget.weeklyMetMinutesTarget - c.budget.achievedMetMinutes;
  if (gap > 200 && k.baseMet > 5.0) {
    return 1.0;
  }
  return 0.5;
}

double seasonFit(MovementKind k, int currentMonth) {
  final mask = k.seasonMask;
  if (mask == null || mask.isEmpty) return 0.5;
  try {
    final months = mask
        .split(',')
        .map((s) => int.tryParse(s.trim()))
        .whereType<int>()
        .toSet();
    return months.contains(currentMonth) ? 1.0 : 0.0;
  } catch (_) {
    return 0.5;
  }
}

double scoreMovementKind(MovementKind k, SuggestionCtx c) {
  // وتوی ایمنی — هیچ امتیازی نمی‌تواند آن را خنثی کند:
  if (c.limitations.contains('knee') && k.jointImpact >= 3)
    return double.negativeInfinity;
  if (c.painLevel >= 6 && k.jointImpact >= 2) return double.negativeInfinity;

  final gap = (c.budget.weeklyMetMinutesTarget - c.budget.achievedMetMinutes)
      .clamp(0.0, double.infinity);
  final double met = MovementLoadCalculator.metFor(
    baseMet: k.baseMet,
    metLow: k.metLow,
    metHigh: k.metHigh,
    intensity: MovementIntensity.medium,
  );
  final estMet = met * c.availableMinutes;

  var s = 0.0;
  s +=
      (gap <= 0 ? 0.5 : (estMet / gap).clamp(0.0, 1.0)) *
      3.0; // پُر کردن کسری بودجه
  s += readinessFit(k, c) * 2.5; // انرژی/کوفتگی بالا ← شدت کم
  s +=
      (k.primaryMetric == MovementMetric.duration || c.availableMinutes >= 25
          ? 1.0
          : 0.4) *
      2.0; // تناسب زمان
  s += (c.recentKindCodes14d.contains(k.code) ? 0.0 : 1.0) * 1.5; // تنوع
  s += seasonFit(k, c.jalaliMonth) * 1.0; // seasonMask (ماه شمسی)
  s -= k.jointImpact * 0.2; // ترجیح کم‌ضربه همه‌چیز برابر
  return s;
}

String buildReason(MovementKind k, SuggestionCtx c, double estMet) {
  if (c.limitations.contains('knee') && k.jointImpact == 0) {
    return 'بدون فشار به زانو؛ حدود ${estMet.round()} MET-min به بودجهٔ هفته اضافه می‌کند 🏊';
  }
  if (c.soreness >= 4 || c.energy <= 2) {
    return 'بدنت امروز به آرامش نیاز دارد؛ ${k.titleFa} سبک و بازیابی‌محور است 🌿';
  }
  final gap = c.budget.weeklyMetMinutesTarget - c.budget.achievedMetMinutes;
  if (gap > 200)
    return '${k.titleFa} حدود ${estMet.round()} MET-min از کسری ${gap.round()} تای این هفته را جبران می‌کند 🔥';
  return '${c.availableMinutes} دقیقه ${k.titleFa} برای حفظ ریتم امروز کافی است 🚶';
}

class MovementSuggester {
  static Future<MovementSuggestion?> suggestToday({
    MovementBudgetSnapshot? budget,
  }) async {
    final db = await DatabaseHelper.instance.database;

    // 1. Gather all context parameters
    final budgetSnapshot =
        budget ?? await MovementBudgetService.instance.getCurrentWeekSnapshot();

    // Physical limitations from profile
    final limitations = <String>{};
    try {
      final pRows = await db.query('ss_user_profile', limit: 1);
      if (pRows.isNotEmpty) {
        final profile = SsUserProfile.fromMap(pRows.first);
        if (profile.physicalLimitations.contains(Limitation.kneeProblems)) {
          limitations.add('knee');
        }
        if (profile.physicalLimitations.contains(Limitation.backProblems)) {
          limitations.add('back');
        }
        if (profile.physicalLimitations.contains(Limitation.shoulderProblems)) {
          limitations.add('shoulder');
        }
      }
    } catch (e) {
      debugPrint('[ss] movement_suggester.dart: $e');
    }

    // Daily checkin parameters for today
    int availableMinutes = 30;
    int energy = 3;
    int soreness = 1;
    int painLevel = 0;
    try {
      final todayStr = DateTime.now().toIso8601String().substring(0, 10);
      final cRows = await db.query(
        'ss_daily_checkin',
        where: 'dateIso = ?',
        whereArgs: [todayStr],
        limit: 1,
      );
      if (cRows.isNotEmpty) {
        final r = cRows.first;
        availableMinutes = (r['availableMinutes'] as num? ?? 30).toInt().clamp(
          10,
          120,
        );
        energy = (r['energy'] as num? ?? 3).toInt().clamp(1, 5);
        soreness = (r['soreness'] as num? ?? 1).toInt().clamp(1, 5);
        painLevel = (r['painLevel'] as num? ?? 0).toInt().clamp(0, 10);
      }
    } catch (e) {
      debugPrint('[ss] movement_suggester.dart: $e');
    }

    // Recent kinds codes logged in last 14 days
    final recentKindCodes14d = <String>{};
    try {
      final fourteenDaysAgo = DateTime.now()
          .subtract(const Duration(days: 14))
          .millisecondsSinceEpoch;
      final rows = await db.query(
        'workout_logs',
        columns: ['kindCode'],
        where: 'loggedAt >= ?',
        whereArgs: [fourteenDaysAgo],
      );
      for (final r in rows) {
        final code = r['kindCode'] as String?;
        if (code != null) recentKindCodes14d.add(code);
      }
    } catch (e) {
      debugPrint('[ss] movement_suggester.dart: $e');
    }

    final jalaliMonth = Jalali.now().month;

    final ctx = SuggestionCtx(
      budget: budgetSnapshot,
      availableMinutes: availableMinutes,
      energy: energy,
      soreness: soreness,
      painLevel: painLevel,
      limitations: limitations,
      recentKindCodes14d: recentKindCodes14d,
      jalaliMonth: jalaliMonth,
    );

    // 2. Score all enabled kinds
    final allKinds = await MovementRepository.instance.getKinds();
    if (allKinds.isEmpty) return null;

    final scoredKinds = <MapEntry<MovementKind, double>>[];
    for (final k in allKinds) {
      if (!k.isEnabled) continue;
      final s = scoreMovementKind(k, ctx);
      if (s.isFinite) {
        scoredKinds.add(MapEntry(k, s));
      }
    }

    if (scoredKinds.isEmpty) return null;

    // Sort by score descending
    scoredKinds.sort((a, b) => b.value.compareTo(a.value));

    final top1Entry = scoredKinds.first;
    final top1Kind = top1Entry.key;
    final top1Score = top1Entry.value;

    double confidence = 0.5;
    var reason = '';
    final alternatives = <MovementKind>[];

    final double met = MovementLoadCalculator.metFor(
      baseMet: top1Kind.baseMet,
      metLow: top1Kind.metLow,
      metHigh: top1Kind.metHigh,
      intensity: MovementIntensity.medium,
    );
    final estMet = met * availableMinutes;

    if (scoredKinds.length > 1) {
      final top2Entry = scoredKinds[1];
      final top2Kind = top2Entry.key;
      final top2Score = top2Entry.value;

      // Confidence from score gap
      confidence = ((top1Score - top2Score) / (top1Score.abs() + 1.0)).clamp(
        0.3,
        0.9,
      );

      // If gap is less than 0.5, show dual suggestions
      if ((top1Score - top2Score) < 0.5) {
        reason =
            'دو پیشنهاد برای امروز دارم: ${top1Kind.titleFa} یا ${top2Kind.titleFa}.\n${buildReason(top1Kind, ctx, estMet)}';
      } else {
        reason = buildReason(top1Kind, ctx, estMet);
      }

      // Populate alternatives
      alternatives.add(top2Kind);
      if (scoredKinds.length > 2) {
        alternatives.add(scoredKinds[2].key);
      }
    } else {
      reason = buildReason(top1Kind, ctx, estMet);
    }

    return MovementSuggestion(
      kind: top1Kind,
      suggestedMinutes: availableMinutes,
      suggestedIntensity: MovementIntensity.medium,
      reasonFa: reason,
      confidence: confidence,
      alternatives: alternatives,
    );
  }

  /// پیشنهاد هوشمند برای روزهای خالی هفتهٔ جاری (حداکثر ۳ پیشنهاد، منطبق بر بودجه و ایمنی).
  static Future<List<MovementWeekSuggestion>> suggestWeek({
    MovementBudgetSnapshot? budget,
  }) async {
    final db = await DatabaseHelper.instance.database;

    // 1. Budget snapshot & gap check
    final budgetSnapshot =
        budget ?? await MovementBudgetService.instance.getCurrentWeekSnapshot();
    final double gap =
        budgetSnapshot.weeklyMetMinutesTarget -
        budgetSnapshot.achievedMetMinutes;
    if (gap <= 0) return const <MovementWeekSuggestion>[];

    // 2. Physical limitations
    final limitations = <String>{};
    try {
      final pRows = await db.query('ss_user_profile', limit: 1);
      if (pRows.isNotEmpty) {
        final profile = SsUserProfile.fromMap(pRows.first);
        if (profile.physicalLimitations.contains(Limitation.kneeProblems))
          limitations.add('knee');
        if (profile.physicalLimitations.contains(Limitation.backProblems))
          limitations.add('back');
        if (profile.physicalLimitations.contains(Limitation.shoulderProblems))
          limitations.add('shoulder');
      }
    } catch (e) {
      debugPrint('[ss] movement_suggester.dart: $e');
    }

    // 3. 14-day history & currently planned kinds this week
    final recentKindCodes = <String>{};
    try {
      final fourteenDaysAgo = DateTime.now()
          .subtract(const Duration(days: 14))
          .millisecondsSinceEpoch;
      final rows = await db.query(
        'workout_logs',
        columns: ['kindCode'],
        where: 'loggedAt >= ?',
        whereArgs: [fourteenDaysAgo],
      );
      for (final r in rows) {
        final code = r['kindCode'] as String?;
        if (code != null) recentKindCodes.add(code);
      }
    } catch (e) {
      debugPrint('[ss] movement_suggester.dart: $e');
    }

    final weekPlan = await UnifiedPlannerRepository.instance.loadWeek();
    for (final day in weekPlan.byDay) {
      for (final item in day) {
        final code = item.routineRaw?['movementKind']?.toString();
        if (code != null) recentKindCodes.add(code);
      }
    }

    // 3.5. Read today's check-in (energy, soreness, painLevel, availableMinutes)
    int todayAvailableMinutes = 30;
    int todayEnergy = 3;
    int todaySoreness = 1;
    int todayPainLevel = 0;
    try {
      final todayStr = DateTime.now().toIso8601String().substring(0, 10);
      final cRows = await db.query(
        'ss_daily_checkin',
        where: 'dateIso = ?',
        whereArgs: [todayStr],
        limit: 1,
      );
      if (cRows.isNotEmpty) {
        final r = cRows.first;
        todayAvailableMinutes = (r['availableMinutes'] as num? ?? 30)
            .toInt()
            .clamp(10, 120);
        todayEnergy = (r['energy'] as num? ?? 3).toInt().clamp(1, 5);
        todaySoreness = (r['soreness'] as num? ?? 1).toInt().clamp(1, 5);
        todayPainLevel = (r['painLevel'] as num? ?? 0).toInt().clamp(0, 10);
      }
    } catch (e) {
      debugPrint('[ss] movement_suggester.dart: $e');
    }

    // 4. Identify empty days (prioritizing today onwards)
    final now = DateTime.now();
    final todaySat0 = dartWeekdayToSat0(now.weekday);
    final emptySat0Days = <int>[];

    for (int i = todaySat0; i < 7; i++) {
      if (weekPlan.byDay[i].isEmpty) emptySat0Days.add(i);
    }
    for (int i = 0; i < todaySat0; i++) {
      if (weekPlan.byDay[i].isEmpty) emptySat0Days.add(i);
    }

    if (emptySat0Days.isEmpty) return const <MovementWeekSuggestion>[];

    // 5. Load kinds and rank candidates for empty days
    final allKinds = await MovementRepository.instance.getKinds();
    final enabledKinds = allKinds.where((k) => k.isEnabled).toList();
    if (enabledKinds.isEmpty) return const <MovementWeekSuggestion>[];

    final jalaliMonth = Jalali.now().month;
    final suggestions = <MovementWeekSuggestion>[];
    double accumulatedEstMet = 0.0;
    final maxAllowedMet = gap * 1.15;

    for (final daySat0 in emptySat0Days) {
      if (suggestions.length >= 3) break;

      final isToday = daySat0 == todaySat0;
      final int effectiveEnergy = isToday ? todayEnergy : 3;
      final int effectiveSoreness = isToday ? todaySoreness : 1;
      final int effectivePain = isToday ? todayPainLevel : 0;
      final int effectiveMinutes = isToday ? todayAvailableMinutes : 30;

      final ctx = SuggestionCtx(
        budget: budgetSnapshot,
        availableMinutes: effectiveMinutes,
        energy: effectiveEnergy,
        soreness: effectiveSoreness,
        painLevel: effectivePain,
        limitations: limitations,
        recentKindCodes14d: recentKindCodes,
        jalaliMonth: jalaliMonth,
      );

      final scored = <MapEntry<MovementKind, double>>[];
      for (final k in enabledKinds) {
        final s = scoreMovementKind(k, ctx);
        if (s.isFinite) {
          scored.add(MapEntry(k, s));
        }
      }

      if (scored.isEmpty) continue;
      scored.sort((a, b) => b.value.compareTo(a.value));

      final topEntry = scored.first;
      final selectedKind = topEntry.key;

      final double met = MovementLoadCalculator.metFor(
        baseMet: selectedKind.baseMet,
        metLow: selectedKind.metLow,
        metHigh: selectedKind.metHigh,
        intensity: MovementIntensity.medium,
      );
      final double estMet = met * effectiveMinutes;

      if (accumulatedEstMet + estMet > maxAllowedMet &&
          suggestions.isNotEmpty) {
        break;
      }

      accumulatedEstMet += estMet;
      recentKindCodes.add(selectedKind.code); // Diversify next picked day

      final TimeOfDay suggestedTime;
      if (selectedKind.isOutdoor) {
        suggestedTime = const TimeOfDay(hour: 7, minute: 0);
      } else if (selectedKind.isSocial) {
        suggestedTime = const TimeOfDay(hour: 20, minute: 0);
      } else {
        suggestedTime = const TimeOfDay(hour: 18, minute: 30);
      }

      final reminderMinutes = MovementReminderDefaults.minutesFor(selectedKind);
      final dayName = kPersianWeekdayNames[daySat0];
      final reason = isToday && (effectiveEnergy <= 2 || effectiveSoreness >= 4)
          ? '$dayName — با توجه به احساس خستگی امروز، $effectiveMinutes دقیقه ${selectedKind.titleFa} سبک و بازیابی‌محور پیشنهاد می‌شود 🌿'
          : '$dayName خلوته — $effectiveMinutes دقیقه ${selectedKind.titleFa} حدود ${toPersianDigits(estMet.round().toString())} MET-min از کسری هفته رو جبران می‌کنه ${selectedKind.emoji}';

      suggestions.add(
        MovementWeekSuggestion(
          kind: selectedKind,
          weekdaySat0: daySat0,
          suggestedTime: suggestedTime,
          suggestedMinutes: effectiveMinutes,
          suggestedIntensity: MovementIntensity.medium,
          reasonFa: reason,
          confidence: 0.85,
          reminderMinutes: reminderMinutes,
        ),
      );
    }

    // Sort suggestions by weekday order (Sat0)
    suggestions.sort((a, b) => a.weekdaySat0.compareTo(b.weekdaySat0));
    return suggestions;
  }
}
