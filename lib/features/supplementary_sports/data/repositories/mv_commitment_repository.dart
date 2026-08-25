import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';
import 'package:sqflite/sqflite.dart';

/// مخزن تعهدهای ورزشی ثابت (mv_commitments)
abstract class MvCommitmentRepository {
  Future<List<MvCommitment>> getAll({bool onlyActive = true});
  Future<List<MvCommitment>> getActive();
  Future<List<MvCommitment>> getForDay(int dayOfWeekSat0, {bool onlyActive = true});
  Future<MvCommitment?> getById(int id);
  Future<int> insert(MvCommitment commitment);
  Future<void> update(MvCommitment commitment);
  Future<MvCommitment> upsert(MvCommitment commitment);
  Future<void> delete(int id);
  Future<void> toggleActive(int id, bool isActive);
  Future<void> deactivate(int id);
}

class MvCommitmentRepositoryImpl implements MvCommitmentRepository {
  final DatabaseExecutor? _customDb;

  MvCommitmentRepositoryImpl([this._customDb]);

  Future<DatabaseExecutor> get _db async {
    final custom = _customDb;
    if (custom != null) return custom;
    return DatabaseHelper.instance.database;
  }

  @override
  Future<List<MvCommitment>> getAll({bool onlyActive = true}) async {
    final db = await _db;
    final rows = await db.query(
      'mv_commitments',
      where: onlyActive ? 'isActive = 1' : null,
      orderBy: 'dayOfWeekSat0 ASC, startTime ASC',
    );
    return rows.map((r) => MvCommitment.fromMap(r)).toList();
  }

  @override
  Future<List<MvCommitment>> getActive() => getAll(onlyActive: true);

  @override
  Future<List<MvCommitment>> getForDay(
    int dayOfWeekSat0, {
    bool onlyActive = true,
  }) async {
    final db = await _db;
    final rows = await db.query(
      'mv_commitments',
      where: onlyActive
          ? 'dayOfWeekSat0 = ? AND isActive = 1'
          : 'dayOfWeekSat0 = ?',
      whereArgs: [dayOfWeekSat0],
      orderBy: 'startTime ASC',
    );
    return rows.map((r) => MvCommitment.fromMap(r)).toList();
  }

  @override
  Future<MvCommitment?> getById(int id) async {
    final db = await _db;
    final rows = await db.query(
      'mv_commitments',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return MvCommitment.fromMap(rows.first);
  }

  @override
  Future<int> insert(MvCommitment commitment) async {
    final db = await _db;
    final now = DateTime.now().toIso8601String();
    final map = commitment.toMap();
    map['createdAt'] = commitment.createdAt;
    map['updatedAt'] = now;
    return await db.insert('mv_commitments', map);
  }

  @override
  Future<void> update(MvCommitment commitment) async {
    if (commitment.id == null) {
      throw ArgumentError('Cannot update MvCommitment without an id');
    }
    final db = await _db;
    final now = DateTime.now().toIso8601String();
    final map = commitment.toMap();
    map['updatedAt'] = now;
    await db.update(
      'mv_commitments',
      map,
      where: 'id = ?',
      whereArgs: [commitment.id],
    );
  }

  @override
  Future<MvCommitment> upsert(MvCommitment commitment) async {
    if (commitment.id != null) {
      await update(commitment);
      return (await getById(commitment.id!)) ?? commitment;
    } else {
      final newId = await insert(commitment);
      return commitment.copyWith(id: newId);
    }
  }

  @override
  Future<void> delete(int id) async {
    final db = await _db;
    await db.delete(
      'mv_commitments',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> toggleActive(int id, bool isActive) async {
    final db = await _db;
    final now = DateTime.now().toIso8601String();
    await db.update(
      'mv_commitments',
      {
        'isActive': isActive ? 1 : 0,
        'updatedAt': now,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> deactivate(int id) => toggleActive(id, false);
}
