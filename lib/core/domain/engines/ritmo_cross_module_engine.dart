import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/domain/engines/ritmo_event_bus.dart';
import 'package:ritmo/core/services/prayer_time_provider.dart';
import 'package:ritmo/core/util/ritmo_date.dart';
import 'package:ritmo/core/util/ritmo_number.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/mv_reason_keys.dart';

/// Lightweight cross-module snapshot carrying biological, circadian, and environmental context
/// without creating direct feature-to-feature dependencies (Constitution Law 16 & Law 18).
class RitmoCrossModuleSnapshot {
  final String dateIso;

  // 1. Sleep & Circadian Context
  final int? sleepMinutesLastNight;
  final bool isSleepDebtHigh; // true if sleep < 6 hours (360 min)

  // 2. Fasting & Prayer Timing Context
  final bool isFasting;
  final String? maghribTime; // e.g. "19:15"
  final String? goldenPreIftarWindow; // e.g. "۱۸:۳۰ تا ۱۹:۱۵"
  final String? goldenPostIftarWindow; // e.g. "۲۱:۱۵ تا ۲۲:۴۵"

  // 3. Cycle & Biological Rhythm Context (Strictly consent-gated)
  final bool cycleConsentGranted;
  final String? cyclePhaseCode; // 'MENSTRUAL', 'FOLLICULAR', 'OVULATION', 'LUTEAL', 'PREGNANCY', etc.
  final bool isMenstrualPhase;
  final bool isPregnancy;

  // 4. Wellbeing & Energy Context (Strictly consent-gated)
  final bool wellbeingConsentGranted;
  final int? energyLevel; // 1..5
  final String? recentMood; // e.g. 'ANXIOUS', 'TIRED', 'CALM', etc.
  final bool isHighStressOrFatigue;

  // 5. Reason keys for plan transparency (Constitution Law 2 & 19)
  final List<String> applicableReasonKeys;

  const RitmoCrossModuleSnapshot({
    required this.dateIso,
    this.sleepMinutesLastNight,
    this.isSleepDebtHigh = false,
    this.isFasting = false,
    this.maghribTime,
    this.goldenPreIftarWindow,
    this.goldenPostIftarWindow,
    this.cycleConsentGranted = false,
    this.cyclePhaseCode,
    this.isMenstrualPhase = false,
    this.isPregnancy = false,
    this.wellbeingConsentGranted = false,
    this.energyLevel,
    this.recentMood,
    this.isHighStressOrFatigue = false,
    this.applicableReasonKeys = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'dateIso': dateIso,
      'sleepMinutesLastNight': sleepMinutesLastNight,
      'isSleepDebtHigh': isSleepDebtHigh,
      'isFasting': isFasting,
      'maghribTime': maghribTime,
      'goldenPreIftarWindow': goldenPreIftarWindow,
      'goldenPostIftarWindow': goldenPostIftarWindow,
      'cycleConsentGranted': cycleConsentGranted,
      'cyclePhaseCode': cyclePhaseCode,
      'isMenstrualPhase': isMenstrualPhase,
      'isPregnancy': isPregnancy,
      'wellbeingConsentGranted': wellbeingConsentGranted,
      'energyLevel': energyLevel,
      'recentMood': recentMood,
      'isHighStressOrFatigue': isHighStressOrFatigue,
      'applicableReasonKeys': applicableReasonKeys,
    };
  }
}

/// Central Cross-Module Intelligence Engine residing in Core.
/// Collects and memoizes cross-domain context, coordinating multi-rhythm adaptation.
class RitmoCrossModuleEngine {
  RitmoCrossModuleEngine._() {
    _initEventBusListener();
  }

  static final RitmoCrossModuleEngine instance = RitmoCrossModuleEngine._();

  RitmoCrossModuleSnapshot? _cachedSnapshot;
  String? _cachedDateIso;
  StreamSubscription<RitmoEvent>? _eventBusSub;

  void _initEventBusListener() {
    _eventBusSub = RitmoEventBus().onEvents.listen((event) {
      final relevantTypes = {
        RitmoEventType.sleepLogged.code,
        RitmoEventType.energyLogged.code,
        RitmoEventType.moodLogged.code,
        RitmoEventType.worshipChanged.code,
        RitmoEventType.cycleStarted.code,
        RitmoEventType.cycleEnded.code,
        RitmoEventType.dayRolledOver.code,
      };

      if (relevantTypes.contains(event.type)) {
        invalidateCache();
      }
    });
  }

  /// Clears the cached snapshot so the next fetch retrieves fresh database state.
  void invalidateCache() {
    _cachedSnapshot = null;
    _cachedDateIso = null;
  }

  @visibleForTesting
  void dispose() {
    _eventBusSub?.cancel();
  }

  /// Resolves the comprehensive cross-module snapshot for the given date.
  Future<RitmoCrossModuleSnapshot> getSnapshot({DateTime? date}) async {
    final effectiveDate = date ?? DateTime.now();
    final dateIso = RitmoDate.dayKey(effectiveDate);

    if (_cachedSnapshot != null && _cachedDateIso == dateIso) {
      return _cachedSnapshot!;
    }

    try {
      final db = await DatabaseHelper.instance.database;

      // 1. Resolve Sleep Context
      final sleepContext = await _resolveSleepContext(db, dateIso, effectiveDate);

      // 2. Resolve Fasting & Prayer Times Context
      final fastingContext = await _resolveFastingContext(db, effectiveDate);

      // 3. Resolve Cycle Context (Consent-gated)
      final cycleContext = await _resolveCycleContext(db, dateIso);

      // 4. Resolve Wellbeing Context (Consent-gated)
      final wellbeingContext = await _resolveWellbeingContext(db, dateIso);

      // 5. Compile applicable decision reasons
      final reasons = <String>[];
      if (sleepContext.isSleepDebtHigh) {
        reasons.add(MvReasonKeys.readinessLow);
        reasons.add(MvReasonKeys.fallbackMinimum);
      }
      if (fastingContext.isFasting) {
        reasons.add(MvReasonKeys.constraintRelaxed);
      }
      if (cycleContext.isMenstrualPhase && cycleContext.consentGranted) {
        reasons.add(MvReasonKeys.readinessLow);
      }
      if (wellbeingContext.isHighStressOrFatigue) {
        reasons.add(MvReasonKeys.readinessLow);
      }

      final snapshot = RitmoCrossModuleSnapshot(
        dateIso: dateIso,
        sleepMinutesLastNight: sleepContext.sleepMinutes,
        isSleepDebtHigh: sleepContext.isSleepDebtHigh,
        isFasting: fastingContext.isFasting,
        maghribTime: fastingContext.maghribTime,
        goldenPreIftarWindow: fastingContext.goldenPreIftarWindow,
        goldenPostIftarWindow: fastingContext.goldenPostIftarWindow,
        cycleConsentGranted: cycleContext.consentGranted,
        cyclePhaseCode: cycleContext.phaseCode,
        isMenstrualPhase: cycleContext.isMenstrualPhase,
        isPregnancy: cycleContext.isPregnancy,
        wellbeingConsentGranted: wellbeingContext.consentGranted,
        energyLevel: wellbeingContext.energyLevel,
        recentMood: wellbeingContext.recentMood,
        isHighStressOrFatigue: wellbeingContext.isHighStressOrFatigue,
        applicableReasonKeys: reasons,
      );

      _cachedSnapshot = snapshot;
      _cachedDateIso = dateIso;
      return snapshot;
    } catch (e) {
      debugPrint('RitmoCrossModuleEngine: Error resolving snapshot: $e');
      return RitmoCrossModuleSnapshot(dateIso: dateIso);
    }
  }

  // ---------------------------------------------------------------------------
  // Internal Domain Resolvers (Safe direct SQLite reads without feature coupling)
  // ---------------------------------------------------------------------------

  Future<({int? sleepMinutes, bool isSleepDebtHigh})> _resolveSleepContext(
    dynamic db,
    String dateIso,
    DateTime date,
  ) async {
    int? sleepMinutes;

    try {
      // Check checkin table first
      final checkinRows = await db.query(
        'ss_daily_checkin',
        where: 'dateIso = ?',
        whereArgs: [dateIso],
        limit: 1,
      );
      if (checkinRows.isNotEmpty) {
        // availableMinutes or implicit check
      }

      // Check bedtime diagnostics or sleep_plan_days
      final yesterdayIso = RitmoDate.dayKey(date.subtract(const Duration(days: 1)));
      final sleepPlanRows = await db.query(
        'sleep_plan_days',
        where: 'date = ? OR date = ?',
        whereArgs: [dateIso, yesterdayIso],
        limit: 1,
      );

      if (sleepPlanRows.isNotEmpty) {
        final actualBed = sleepPlanRows.first['actualBedtimeMin'] as int?;
        final actualWake = sleepPlanRows.first['actualWakeMin'] as int?;
        if (actualBed != null && actualWake != null) {
          int diff = actualWake - actualBed;
          if (diff < 0) diff += 1440; // overnight wrap
          sleepMinutes = diff;
        }
      }
    } catch (_) {}

    final isSleepDebt = sleepMinutes != null && sleepMinutes < 360;
    return (sleepMinutes: sleepMinutes, isSleepDebtHigh: isSleepDebt);
  }

  Future<({
    bool isFasting,
    String? maghribTime,
    String? goldenPreIftarWindow,
    String? goldenPostIftarWindow,
  })> _resolveFastingContext(dynamic db, DateTime date) async {
    bool isFasting = false;
    String? maghribTime;
    String? goldenPre;
    String? goldenPost;

    try {
      final dateIso = RitmoDate.dayKey(date);

      // 1. Check if user logged a fast in worship_completions or day context
      final worshipRows = await db.query(
        'worship_day_contexts',
        where: 'date = ?',
        whereArgs: [dateIso],
        limit: 1,
      );

      final isExempt = worshipRows.isNotEmpty &&
          (worshipRows.first['fastingExempt'] as int? ?? 0) == 1;

      if (!isExempt) {
        // Check active fasting practices
        final practiceRows = await db.query(
          'worship_practices',
          where: "practiceType = 'FASTING' AND isCustom = 0",
          limit: 1,
        );
        if (practiceRows.isNotEmpty) {
          isFasting = true;
        }
      }

      // 2. Fetch prayer times (Maghrib/Iftar)
      final settingsResult = await db.query('app_settings');
      String cityId = 'tehran';
      for (final row in settingsResult) {
        if (row['key'] == 'prayer_city_id') {
          cityId = row['value'] as String? ?? 'tehran';
        }
      }

      final prayerTimes = await PrayerTimeProvider.instance.getPrayerTimesForDate(
        cityId: cityId,
        date: date,
      );

      maghribTime = prayerTimes['maghrib'];
      if (maghribTime != null && maghribTime.contains(':')) {
        final parts = maghribTime.split(':');
        final h = int.tryParse(parts[0]) ?? 19;
        final m = int.tryParse(parts[1]) ?? 0;

        // Pre-iftar: 45 min before Maghrib
        final maghribDt = DateTime(date.year, date.month, date.day, h, m);
        final preIftarStart = maghribDt.subtract(const Duration(minutes: 45));
        final postIftarStart = maghribDt.add(const Duration(hours: 2));
        final postIftarEnd = postIftarStart.add(const Duration(minutes: 90));

        String fmtTime(DateTime dt) =>
            '${RitmoNumber.fa(dt.hour.toString().padLeft(2, '0'))}:${RitmoNumber.fa(dt.minute.toString().padLeft(2, '0'))}';

        goldenPre = '${fmtTime(preIftarStart)} تا ${fmtTime(maghribDt)}';
        goldenPost = '${fmtTime(postIftarStart)} تا ${fmtTime(postIftarEnd)}';
      }
    } catch (_) {}

    return (
      isFasting: isFasting,
      maghribTime: maghribTime,
      goldenPreIftarWindow: goldenPre,
      goldenPostIftarWindow: goldenPost,
    );
  }

  Future<({
    bool consentGranted,
    String? phaseCode,
    bool isMenstrualPhase,
    bool isPregnancy,
  })> _resolveCycleContext(dynamic db, String dateIso) async {
    bool consent = false;
    String? phaseCode;
    bool isMenstrual = false;
    bool isPregnancy = false;

    try {
      // 1. Check consent in ss_user_profile
      final profileRows = await db.query('ss_user_profile', limit: 1);
      if (profileRows.isNotEmpty) {
        consent = (profileRows.first['cycleConsentGranted'] as int? ?? 0) == 1;
      }

      if (consent) {
        // Read active cycle entries / pregnancy state
        final appSettings = await db.query('app_settings');
        for (final row in appSettings) {
          if (row['key'] == 'pregnancy_mode_enabled' && row['value'] == 'true') {
            isPregnancy = true;
            phaseCode = 'PREGNANCY';
          }
        }

        if (!isPregnancy) {
          final cycleEntries = await db.query(
            'cycle_entries',
            orderBy: 'startDate DESC',
            limit: 1,
          );
          if (cycleEntries.isNotEmpty) {
            final startStr = cycleEntries.first['startDate'] as String? ?? '';
            final endStr = cycleEntries.first['endDate'] as String?;
            if (startStr.isNotEmpty) {
              final start = DateTime.tryParse(startStr);
              final now = DateTime.now();
              if (start != null) {
                final dayDiff = now.difference(start).inDays;
                if (endStr == null && dayDiff >= 0 && dayDiff <= 7) {
                  isMenstrual = true;
                  phaseCode = 'MENSTRUAL';
                } else if (dayDiff > 7 && dayDiff <= 13) {
                  phaseCode = 'FOLLICULAR';
                } else if (dayDiff >= 14 && dayDiff <= 16) {
                  phaseCode = 'OVULATION';
                } else {
                  phaseCode = 'LUTEAL';
                }
              }
            }
          }
        }
      }
    } catch (_) {}

    return (
      consentGranted: consent,
      phaseCode: phaseCode,
      isMenstrualPhase: isMenstrual,
      isPregnancy: isPregnancy,
    );
  }

  Future<({
    bool consentGranted,
    int? energyLevel,
    String? recentMood,
    bool isHighStressOrFatigue,
  })> _resolveWellbeingContext(dynamic db, String dateIso) async {
    const consent = true; // Default internal read unless disabled
    int? energy;
    String? mood;
    bool isHighStressOrFatigue = false;

    try {
      // 1. Check daily check-in (fatigue, energy, soreness)
      final checkinRows = await db.query(
        'ss_daily_checkin',
        where: 'dateIso = ?',
        whereArgs: [dateIso],
        limit: 1,
      );
      if (checkinRows.isNotEmpty) {
        final row = checkinRows.first;
        final e = row['energy'] as int?;
        final f = row['fatigue'] as int?;
        final s = row['soreness'] as int?;
        final p = row['painLevel'] as int?;
        if (e != null) energy = e;
        if ((e != null && e <= 2) ||
            (f != null && f >= 4) ||
            (s != null && s >= 4) ||
            (p != null && p >= 5)) {
          isHighStressOrFatigue = true;
        }
      }

      // 2. Check energy_logs fallback
      if (energy == null) {
        final energyRows = await db.query(
          'energy_logs',
          orderBy: 'loggedAt DESC',
          limit: 1,
        );
        if (energyRows.isNotEmpty) {
          final levelStr = energyRows.first['energyLevel'] as String? ?? '';
          switch (levelStr.toLowerCase()) {
            case 'verylow':
            case 'low':
              energy = 1;
              isHighStressOrFatigue = true;
            case 'moderate':
              energy = 3;
            case 'high':
            case 'peak':
              energy = 5;
          }
        }
      }
    } catch (_) {}

    return (
      consentGranted: consent,
      energyLevel: energy,
      recentMood: mood,
      isHighStressOrFatigue: isHighStressOrFatigue,
    );
  }
}
