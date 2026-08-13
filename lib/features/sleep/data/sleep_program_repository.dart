import 'package:ritmo/core/analytics/sleep_program_engine.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/util/ritmo_date.dart';
import 'package:ritmo/features/sleep/models/sleep_models.dart';
import 'package:ritmo/features/sleep/models/sleep_plan_day.dart';
import 'package:ritmo/features/sleep/models/sleep_program.dart';
import 'package:sqflite/sqflite.dart';

/// لایهٔ دادهٔ برنامهٔ خواب — قدم ۲ و فاز A سند «مسیر خواب».
///
/// منبع حقیقت:
/// - هدف خواب ← کلیدهای `sleep_target_%` در `app_settings` (اصل ۶).
/// - لاگ واقعی خواب ← `bedtime_diagnostics` (جدول `sleep_logs` در کد
///   هیچ نویسنده‌ای ندارد و اینجا عمداً خوانده نمی‌شود).
/// - پلهٔ هر شب ← `sleep_plan_days` که یک‌بار فریز می‌شود و دیگر تکان نمی‌خورد.
class SleepProgramRepository {
  SleepProgramRepository(this._db);

  /// DatabaseExecutor تزریق‌شده تا تست‌ها بتوانند دیتابیس in-memory بدهند.
  final DatabaseExecutor _db;

  static Future<SleepProgramRepository> fromHelper() async =>
      SleepProgramRepository(await DatabaseHelper.instance.database);

  /// حداقل شب‌های ثبت‌شده برای خروج از فاز گوش دادن (سند، بخش ۲).
  static const int minNightsForAnchoring = 7;

  /// طول تاریخچهٔ خوانده‌شده برای محاسبات.
  static const int historyNights = 45;

  /// dayKey شبِ امشب: پیش از ظهر، شبِ در جریان متعلق به دیروز است
  /// (همان کنوانسیونی که `sleep_log_sheet` هنگام ذخیره به کار می‌برد).
  static String tonightDateKey(DateTime now) => now.hour < 12
      ? RitmoDate.dayKey(now.subtract(const Duration(days: 1)))
      : RitmoDate.dayKey(now);

  // ────── خواندن ──────

  Future<SleepProgram?> currentProgram() async {
    final settings = await _db.query(
      'app_settings',
      where: 'key = ?',
      whereArgs: ['sleep_program_id'],
      limit: 1,
    );
    if (settings.isEmpty) return null;
    final id = settings.first['value'] as String? ?? '';
    if (id.isEmpty) return null;
    final rows = await _db.query(
      'sleep_programs',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return SleepProgram.fromMap(rows.first);
  }

  /// اگر برنامه‌ای نیست، یکی در فاز listening می‌سازد و id را در app_settings می‌نویسد.
  Future<SleepProgram> ensureProgram() async {
    final existing = await currentProgram();
    if (existing != null) return existing;

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final program = SleepProgram(
      id: 'sp_$nowMs',
      status: SleepProgramStatus.listening,
      createdAt: nowMs,
      updatedAt: nowMs,
    );
    await _db.insert('sleep_programs', program.toMap());
    await _db.insert(
      'app_settings',
      {'key': 'sleep_program_id', 'value': program.id, 'updatedAt': nowMs},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return program;
  }

  /// هدف خواب از app_settings (با همان پیش‌فرض‌های بقیهٔ اپ).
  Future<SleepTarget> loadTarget() async {
    final rows = await _db.query(
      'app_settings',
      where: "key LIKE 'sleep_target_%'",
    );
    var bedtime = '23:30';
    var wake = '07:00';
    var duration = 450;
    for (final r in rows) {
      final k = r['key'] as String?;
      final v = r['value'] as String?;
      if (v == null || v.isEmpty) continue;
      if (k == 'sleep_target_bedtime') bedtime = v;
      if (k == 'sleep_target_wake') wake = v;
      if (k == 'sleep_target_duration_minutes') {
        duration = int.tryParse(v) ?? duration;
      }
    }
    return SleepTarget(bedtime: bedtime, wake: wake, durationMinutes: duration);
  }

  /// لاگ واقعی خواب از `bedtime_diagnostics`.
  Future<List<SleepLog>> loadSleepLogs({int nights = historyNights}) async {
    final rows = await _db.query(
      'bedtime_diagnostics',
      orderBy: 'date DESC',
      limit: nights,
    );
    return rows.map(SleepLog.fromMap).toList();
  }

  Future<List<SleepPlanDay>> loadPlanDays(
    String programId, {
    int days = historyNights,
  }) async {
    final rows = await _db.query(
      'sleep_plan_days',
      where: 'programId = ?',
      whereArgs: [programId],
      orderBy: 'date DESC',
      limit: days,
    );
    return rows.map(SleepPlanDay.fromMap).toList();
  }

  // ────── چرخهٔ شب ──────

  /// وضعیت کامل برنامه: تسویهٔ شب‌های گذشته، محاسبهٔ پلهٔ امشب و فریز کردن آن.
  Future<SleepProgramState> refreshAndLoadState({DateTime? now}) async {
    final at = now ?? DateTime.now();
    final program = await ensureProgram();
    final target = await loadTarget();
    final logs = await loadSleepLogs();
    final plans = await loadPlanDays(program.id);

    final settled = await settlePendingNights(
      program: program,
      plans: plans,
      logs: logs,
      tonightDate: tonightDateKey(at),
    );

    final state = await const SleepProgramEngine().calculate(SleepProgramInput(
      program: program,
      planDays: settled,
      sleepLogs: logs,
      target: target,
      now: at,
    ));

    // پیشرفت فاز فقط رو به جلو و فقط توسط داده — paused/completed دستِ کاربر است.
    if (state.status != program.status &&
        (state.status == SleepProgramStatus.anchoring ||
            state.status == SleepProgramStatus.active)) {
      await updateStatus(program, state.status);
    }

    await freezeTonight(program: program, state: state, plans: settled);
    return state;
  }

  /// شب‌های گذشتهٔ pending را دقیقاً یک‌بار می‌بندد.
  ///
  /// ترتیب تصمیم: شب آزاد ← بی‌داده ← زدن/نزدنِ پله (نه هدف نهایی).
  Future<List<SleepPlanDay>> settlePendingNights({
    required SleepProgram program,
    required List<SleepPlanDay> plans,
    required List<SleepLog> logs,
    required String tonightDate,
  }) async {
    final logsByDate = <String, SleepLog>{for (final l in logs) l.date: l};
    final settled = <SleepPlanDay>[];

    for (final plan in plans) {
      final isPast = plan.date.compareTo(tonightDate) < 0;
      if (!isPast || plan.outcome != SleepPlanOutcome.pending) {
        settled.add(plan);
        continue;
      }

      int? actualBedtimeMin;
      int? actualWakeMin;
      final log = logsByDate[plan.date];
      if (log?.bedtimeAt != null) {
        final bt = DateTime.fromMillisecondsSinceEpoch(log!.bedtimeAt!);
        actualBedtimeMin = bt.hour * 60 + bt.minute;
      }
      if (log?.wakeAt != null) {
        final wt = DateTime.fromMillisecondsSinceEpoch(log!.wakeAt!);
        actualWakeMin = wt.hour * 60 + wt.minute;
      }

      final weekday = RitmoDate.tryParseDayKey(plan.date)?.weekday;
      final SleepPlanOutcome outcome;
      if (program.freeNightWeekday != null &&
          weekday == program.freeNightWeekday) {
        outcome = SleepPlanOutcome.freeNight;
      } else if (actualBedtimeMin == null) {
        outcome = SleepPlanOutcome.noData;
      } else {
        outcome =
            SleepProgramEngine.planHit(actualBedtimeMin, plan.plannedBedtimeMin)
                ? SleepPlanOutcome.hit
                : SleepPlanOutcome.miss;
      }

      await _db.update(
        'sleep_plan_days',
        {
          'actualBedtimeMin': actualBedtimeMin,
          'actualWakeMin': actualWakeMin,
          'outcome': outcome.name,
        },
        where: 'programId = ? AND date = ?',
        whereArgs: [plan.programId, plan.date],
      );

      settled.add(plan.copyWith(
        actualBedtimeMin: actualBedtimeMin,
        actualWakeMin: actualWakeMin,
        outcome: outcome,
      ));
    }

    return settled;
  }

  /// پلهٔ امشب را یک‌بار می‌نویسد؛ اگر قبلاً فریز شده دست نمی‌زند
  /// (وعدهٔ «پله وسط عصر جابجا نمی‌شود»).
  Future<SleepPlanDay?> freezeTonight({
    required SleepProgram program,
    required SleepProgramState state,
    required List<SleepPlanDay> plans,
  }) async {
    if (state.status != SleepProgramStatus.anchoring &&
        state.status != SleepProgramStatus.active) {
      return null;
    }
    if (plans.any((p) => p.date == state.tonightDate)) return null;

    final row = SleepPlanDay(
      programId: program.id,
      date: state.tonightDate,
      plannedBedtimeMin: state.tonightBedtimeMin,
      plannedWakeMin: state.tonightWakeMin,
      outcome: state.freeNightTonight
          ? SleepPlanOutcome.freeNight
          : SleepPlanOutcome.pending,
    );
    await _db.insert(
      'sleep_plan_days',
      row.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    return row;
  }

  /// «امشب آزادم» — شب از پایبندی خارج می‌شود، بدون هیچ جریمه‌ای.
  Future<void> markTonightFreeNight({DateTime? now}) async {
    final at = now ?? DateTime.now();
    final program = await ensureProgram();
    await _db.update(
      'sleep_plan_days',
      {'outcome': SleepPlanOutcome.freeNight.name},
      where: 'programId = ? AND date = ?',
      whereArgs: [program.id, tonightDateKey(at)],
    );
  }

  // ────── تنظیمات برنامه ──────

  /// روز هفتهٔ شب آزاد (ISO: ۱=دوشنبه … ۷=یکشنبه) یا null برای حذف.
  Future<SleepProgram> setFreeNightWeekday(int? weekday) async {
    final program = await ensureProgram();
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    await _db.update(
      'sleep_programs',
      {'freeNightWeekday': weekday, 'updatedAt': nowMs},
      where: 'id = ?',
      whereArgs: [program.id],
    );
    return SleepProgram(
      id: program.id,
      status: program.status,
      stepMinutes: program.stepMinutes,
      minNightsPerStep: program.minNightsPerStep,
      freeNightWeekday: weekday,
      cycleSyncEnabled: program.cycleSyncEnabled,
      createdAt: program.createdAt,
      updatedAt: nowMs,
    );
  }

  Future<SleepProgram> setStepMinutes(int minutes) async {
    final program = await ensureProgram();
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    await _db.update(
      'sleep_programs',
      {'stepMinutes': minutes, 'updatedAt': nowMs},
      where: 'id = ?',
      whereArgs: [program.id],
    );
    return program.copyWith(stepMinutes: minutes, updatedAt: nowMs);
  }

  /// انتقال listening → anchoring وقتی حداقل ۷ شب ثبت‌شده وجود دارد.
  Future<SleepProgram> refreshPhase() async {
    final program = await ensureProgram();
    if (program.status != SleepProgramStatus.listening) return program;

    final nights = Sqflite.firstIntValue(await _db.rawQuery(
          'SELECT COUNT(DISTINCT date) FROM bedtime_diagnostics',
        )) ??
        0;
    if (nights < minNightsForAnchoring) return program;

    return updateStatus(program, SleepProgramStatus.anchoring);
  }

  Future<SleepProgram> updateStatus(
      SleepProgram program, SleepProgramStatus status) async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    await _db.update(
      'sleep_programs',
      {'status': status.name, 'updatedAt': nowMs},
      where: 'id = ?',
      whereArgs: [program.id],
    );
    return program.copyWith(status: status, updatedAt: nowMs);
  }
}
