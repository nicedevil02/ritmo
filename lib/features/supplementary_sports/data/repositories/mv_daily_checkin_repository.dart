import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';
import 'package:sqflite/sqflite.dart';

/// Repository for Daily Check-ins (`ss_daily_checkin`).
class MvDailyCheckinRepository {
  final DatabaseExecutor? _customDb;

  MvDailyCheckinRepository([this._customDb]);

  Future<DatabaseExecutor> get _db async {
    final custom = _customDb;
    if (custom != null) return custom;
    return DatabaseHelper.instance.database;
  }

  /// Retrieves check-in for a given ISO date.
  Future<MvDailyCheckin?> getCheckinForDate(String dateIso) async {
    final db = await _db;
    final rows = await db.query(
      'ss_daily_checkin',
      where: 'dateIso = ?',
      whereArgs: [dateIso],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return MvDailyCheckin.fromMap(rows.first);
  }

  /// Saves or updates daily check-in.
  Future<void> saveCheckin(MvDailyCheckin checkin) async {
    final db = await _db;
    await db.insert(
      'ss_daily_checkin',
      checkin.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
