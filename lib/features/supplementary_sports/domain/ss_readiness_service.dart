import 'package:flutter/foundation.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/features/supplementary_sports/data/models/ss_daily_checkin_model.dart';
import 'package:sqflite/sqflite.dart';

enum SSReadinessTier { full, light, minimal, rest }

class SSReadinessVerdict {
  const SSReadinessVerdict({
    required this.tier,
    required this.reasonFa,
    required this.emoji,
    required this.score,
    this.sleepMinutes,
    required this.recoveryLoad,
    this.isMenstrualPhase = false,
    this.hasData = true,
  });

  final SSReadinessTier tier;
  final String reasonFa;
  final String emoji;
  final int score; // 0..100 (0 means insufficient data)
  final int? sleepMinutes;
  final int recoveryLoad; // soreness + fatigue (0..10)
  final bool isMenstrualPhase;
  final bool hasData;
}

class SSReadinessService {
  SSReadinessService._();
  static final instance = SSReadinessService._();

  Future<void> saveDailyCheckin(SsDailyCheckin checkin) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert(
      'ss_daily_checkin',
      checkin.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<SsDailyCheckin?> getDailyCheckin(String dateIso) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      'ss_daily_checkin',
      where: 'dateIso = ?',
      whereArgs: [dateIso],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return SsDailyCheckin.fromMap(rows.first);
  }

  Future<void> deleteDailyCheckin(String dateIso) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete(
      'ss_daily_checkin',
      where: 'dateIso = ?',
      whereArgs: [dateIso],
    );
  }

  Future<SSReadinessVerdict> evaluateToday() async {
    final db = await DatabaseHelper.instance.database;
    final today = DateTime.now();
    final dateKey = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final nowMs = today.millisecondsSinceEpoch;
    final twentyFourHoursAgo = nowMs - (24 * 60 * 60 * 1000);

    int? sleepMinutes;
    int soreness = 1;
    int fatigue = 1;
    int energy = 3;
    int painLevel = 0;
    bool hasData = false;
    bool hasSubjectiveData = false;

    // 1. Check ss_daily_checkin first
    try {
      final checkin = await getDailyCheckin(dateKey);
      if (checkin != null) {
        energy = checkin.energy;
        soreness = checkin.soreness;
        fatigue = checkin.fatigue;
        painLevel = checkin.painLevel;
        hasData = true;
        hasSubjectiveData = true;
      }
    } catch (e) {
      debugPrint('[SSReadinessService] checkin query error: $e');
    }

    // 1.5 Fallback to energy_logs if checkin not present
    if (!hasSubjectiveData) {
      try {
        final elRows = await db.query(
          'energy_logs',
          where: 'loggedAt >= ?',
          whereArgs: [twentyFourHoursAgo],
          orderBy: 'loggedAt DESC',
          limit: 1,
        );
        if (elRows.isNotEmpty) {
          final levelStr = elRows.first['energyLevel'] as String?;
          if (levelStr != null) {
            // Map text (LOW/MEDIUM/HIGH) to 1-5 scale of ss_daily_checkin
            if (levelStr.toUpperCase() == 'LOW') {
              energy = 1;
            } else if (levelStr.toUpperCase() == 'HIGH') {
              energy = 5;
            } else {
              energy = 3; // Default for MEDIUM or unknown
            }
          }
        }
      } catch (e) {
        debugPrint('[SSReadinessService] energy_logs query error: $e');
      }
    }

    // 2. Load recovery log if checkin not present
    if (!hasData) {
      try {
        final recRows = await db.query(
          'workout_recovery_logs',
          where: 'date = ?',
          whereArgs: [dateKey],
          orderBy: 'loggedAt DESC',
          limit: 1,
        );
        if (recRows.isNotEmpty) {
          soreness = (recRows.first['soreness'] as num?)?.toInt() ?? 1;
          fatigue = (recRows.first['fatigue'] as num?)?.toInt() ?? 1;
          hasData = true;
          hasSubjectiveData = true;
        }
      } catch (e) {
        debugPrint('[SSReadinessService] recovery logs query error: $e');
      }
    }

    // 3. Load fresh sleep data (logged within last 24h only)
    try {
      final diagRows = await db.query(
        'bedtime_diagnostics',
        where: 'createdAt >= ?',
        whereArgs: [twentyFourHoursAgo],
        orderBy: 'createdAt DESC',
        limit: 1,
      );
      if (diagRows.isNotEmpty) {
        sleepMinutes = (diagRows.first['durationMinutes'] as num?)?.toInt();
        hasData = true;
      }
    } catch (e) {
      debugPrint('[SSReadinessService] bedtime query error: $e');
    }

    if (sleepMinutes == null) {
      try {
        final sleepRows = await db.query(
          'vital_signs_logs',
          where: "vitalType = 'SLEEP' AND loggedAt >= ?",
          whereArgs: [twentyFourHoursAgo],
          orderBy: 'loggedAt DESC',
          limit: 1,
        );
        if (sleepRows.isNotEmpty) {
          sleepMinutes = (sleepRows.first['value'] as num?)?.toInt();
          hasData = true;
        }
      } catch (e) {
        debugPrint('[SSReadinessService] vital signs query error: $e');
      }
    }

    // 4. Check menstrual cycle phase with consent guard
    bool isMenstrualPhase = false;
    try {
      final cycleConsent = await db.query(
        'app_settings',
        where: "key = 'cycle_consent_sports'",
        limit: 1,
      );
      final hasConsent = cycleConsent.isNotEmpty && cycleConsent.first['value'] == 'true';

      if (hasConsent) {
        final todayIso = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
        final cycleRows = await db.query(
          'cycle_periods',
          where: 'startDate <= ? AND (endDate IS NULL OR endDate >= ?)',
          whereArgs: [todayIso, todayIso],
          orderBy: 'startDate DESC',
          limit: 1,
        );
        if (cycleRows.isNotEmpty) {
          isMenstrualPhase = true;
        }
      }
    } catch (e) {
      debugPrint('[SSReadinessService] cycle consent error: $e');
    }

    final recoveryLoad = soreness + fatigue;

    String appendSubjective(String reason) {
      if (!hasSubjectiveData && hasData) {
        return '$reason (بر اساس داده‌ی خواب — چک‌این امروز ثبت نشده)';
      }
      return reason;
    }

    // If no sleep log and no checkin exist, report insufficient data honestly
    if (!hasData && sleepMinutes == null) {
      return SSReadinessVerdict(
        tier: SSReadinessTier.full,
        reasonFa: 'اطلاعات کافی نیست — وضعیت امروزت را ثبت کن 📊',
        emoji: '📊',
        score: 0,
        sleepMinutes: null,
        recoveryLoad: recoveryLoad,
        isMenstrualPhase: isMenstrualPhase,
        hasData: false,
      );
    }

    if (painLevel >= 5) {
      return SSReadinessVerdict(
        tier: SSReadinessTier.rest,
        reasonFa: appendSubjective('به دلیل درد ثبت‌شده، استراحت یا تمرین بسیار سبک توصیه می‌شود 🛑'),
        emoji: '🛑',
        score: 30,
        sleepMinutes: sleepMinutes,
        recoveryLoad: recoveryLoad,
        isMenstrualPhase: isMenstrualPhase,
      );
    }

    if (isMenstrualPhase) {
      return SSReadinessVerdict(
        tier: SSReadinessTier.light,
        reasonFa: appendSubjective('فاز قاعدگی — تمرینات ملایم و کششی پیشنهاد می‌شود 🌸'),
        emoji: '🌸',
        score: 50,
        sleepMinutes: sleepMinutes,
        recoveryLoad: recoveryLoad,
        isMenstrualPhase: true,
      );
    }

    if (energy <= 1 || (sleepMinutes != null && sleepMinutes < 300)) {
      final hours = sleepMinutes != null ? (sleepMinutes / 60.0).toStringAsFixed(1) : null;
      final msg = hours != null
          ? 'دیشب کم خوابیدی ($hours ساعت) — نسخهٔ حداقلی تا زنجیره نشکنه ⚡'
          : 'انرژی پایینه — نسخهٔ حداقلی تا زنجیره نشکنه ⚡';
      return SSReadinessVerdict(
        tier: SSReadinessTier.minimal,
        reasonFa: appendSubjective(msg),
        emoji: '⚡',
        score: 40,
        sleepMinutes: sleepMinutes,
        recoveryLoad: recoveryLoad,
      );
    }

    if (energy == 2 || (sleepMinutes != null && sleepMinutes < 360) || recoveryLoad >= 6) {
      final hours = sleepMinutes != null ? (sleepMinutes / 60.0).toStringAsFixed(1) : null;
      final msg = hours != null
          ? 'خواب یا ریکاوری متوسط ($hours ساعت) — نسخهٔ سبک پیشنهاد می‌شه 🔋'
          : 'بدنت هنوز خسته/کوفته‌ست — نسخهٔ سبک 🔋';
      return SSReadinessVerdict(
        tier: SSReadinessTier.light,
        reasonFa: appendSubjective(msg),
        emoji: '🔋',
        score: 60,
        sleepMinutes: sleepMinutes,
        recoveryLoad: recoveryLoad,
      );
    }

    if (recoveryLoad >= 4 || energy == 3) {
      return SSReadinessVerdict(
        tier: SSReadinessTier.full,
        reasonFa: appendSubjective('آمادگی مناسبه — تمرین متعادل و منظم 🟡'),
        emoji: '🟡',
        score: 80,
        sleepMinutes: sleepMinutes,
        recoveryLoad: recoveryLoad,
      );
    }

    return SSReadinessVerdict(
      tier: SSReadinessTier.full,
      reasonFa: appendSubjective('انرژی و ریکاوری عالیه — با قدرت شروع کن 🔥'),
      emoji: '🔥',
      score: 95,
      sleepMinutes: sleepMinutes,
      recoveryLoad: recoveryLoad,
    );
  }
}
