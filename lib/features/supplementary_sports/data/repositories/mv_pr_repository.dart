import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';
import 'package:sqflite/sqflite.dart';

/// Single Source of Truth Repository for Personal Records (`movement_pr`).
class MvPrRepository {
  final DatabaseExecutor? _customDb;

  MvPrRepository([this._customDb]);

  Future<DatabaseExecutor> get _db async {
    final custom = _customDb;
    if (custom != null) return custom;
    return DatabaseHelper.instance.database;
  }

  /// Retrieves all recorded PRs.
  Future<List<MvPersonalRecord>> getAllPrs() async {
    final db = await _db;
    final rows = await db.query('movement_pr', orderBy: 'achievedAt DESC');
    return rows.map((r) => MvPersonalRecord.fromMap(r)).toList();
  }

  /// Retrieves current best PR for a specific kind/exercise and PR type.
  Future<MvPersonalRecord?> getPrForKind(String kind, MvPrType type) async {
    final db = await _db;
    final rows = await db.query(
      'movement_pr',
      where: 'kind = ? AND prType = ?',
      whereArgs: [kind, type.code],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return MvPersonalRecord.fromMap(rows.first);
  }

  /// Retrieves all recorded PRs for a specific sport/kind code.
  Future<List<MvPersonalRecord>> getPrsForKind(String kind) async {
    final db = await _db;
    final rows = await db.query(
      'movement_pr',
      where: 'kind = ?',
      whereArgs: [kind],
      orderBy: 'achievedAt DESC',
    );
    return rows.map((r) => MvPersonalRecord.fromMap(r)).toList();
  }

  /// Saves or updates a personal record.
  Future<void> recordPr(MvPersonalRecord pr) async {
    final db = await _db;
    await db.insert(
      'movement_pr',
      pr.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
