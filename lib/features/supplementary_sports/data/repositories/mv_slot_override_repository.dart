import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/mv_slot_override.dart';
import 'package:sqflite/sqflite.dart';

abstract class MvSlotOverrideRepository {
  Future<void> insert(MvSlotOverride override);
  Future<List<MvSlotOverride>> getForDateRange(String startIso, String endIso);
  Future<List<MvSlotOverride>> getForRoutine(String routineId);
  Future<int> countCancellationsInPeriod(
    String routineId,
    String startIso,
    String endIso,
  );
}

class MvSlotOverrideRepositoryImpl implements MvSlotOverrideRepository {
  final DatabaseExecutor? _customDb;

  MvSlotOverrideRepositoryImpl([this._customDb]);

  Future<DatabaseExecutor> get _db async =>
      _customDb ?? await DatabaseHelper.instance.database;

  @override
  Future<void> insert(MvSlotOverride override) async {
    final db = await _db;
    await db.insert(
      'movement_slot_overrides',
      override.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<List<MvSlotOverride>> getForDateRange(
    String startIso,
    String endIso,
  ) async {
    final db = await _db;
    final rows = await db.query(
      'movement_slot_overrides',
      where:
          '(dateIso >= ? AND dateIso <= ?) OR (newDateIso >= ? AND newDateIso <= ?)',
      whereArgs: [startIso, endIso, startIso, endIso],
      orderBy: 'createdAt ASC',
    );
    return rows.map(MvSlotOverride.fromMap).toList();
  }

  @override
  Future<List<MvSlotOverride>> getForRoutine(String routineId) async {
    final db = await _db;
    final rows = await db.query(
      'movement_slot_overrides',
      where: 'routineId = ?',
      whereArgs: [routineId],
      orderBy: 'createdAt DESC',
    );
    return rows.map(MvSlotOverride.fromMap).toList();
  }

  @override
  Future<int> countCancellationsInPeriod(
    String routineId,
    String startIso,
    String endIso,
  ) async {
    final db = await _db;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM movement_slot_overrides WHERE routineId = ? AND dateIso >= ? AND dateIso <= ?',
      [routineId, startIso, endIso],
    );
    if (result.isEmpty) return 0;
    return (result.first['count'] as num?)?.toInt() ?? 0;
  }
}
