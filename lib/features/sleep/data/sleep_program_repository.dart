import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/features/sleep/models/sleep_program.dart';
import 'package:sqflite/sqflite.dart';

/// قدم ۲ — کمترین منطق برنامهٔ خواب: ساخت برنامه در فاز «گوش دادن» و انتقال
/// به فاز «لنگر» بعد از ۷ شب داده. موتور کامل (پله، adherence، ETA) در فاز A.
///
/// توجه: منبع واقعی لاگ خواب در کد فعلی `bedtime_diagnostics` است، نه
/// `sleep_logs` (که نویسنده‌ای ندارد).
class SleepProgramRepository {
  SleepProgramRepository(this._db);

  /// DatabaseExecutor تزریق‌شده تا تست‌ها بتوانند دیتابیس in-memory بدهند.
  final DatabaseExecutor _db;

  static Future<SleepProgramRepository> fromHelper() async =>
      SleepProgramRepository(await DatabaseHelper.instance.database);

  /// حداقل شب‌های ثبت‌شده برای خروج از فاز گوش دادن (سند، بخش ۲).
  static const int minNightsForAnchoring = 7;

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
