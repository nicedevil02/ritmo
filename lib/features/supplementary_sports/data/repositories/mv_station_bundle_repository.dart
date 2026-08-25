import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';
import 'package:sqflite/sqflite.dart';

/// Single Source of Truth repository for Station Bundles (`station_bundles` / S5-T5).
class MvStationBundleRepository {
  final DatabaseExecutor? _customDb;

  MvStationBundleRepository([this._customDb]);

  Future<DatabaseExecutor> get _db async {
    final custom = _customDb;
    if (custom != null) return custom;
    return DatabaseHelper.instance.database;
  }

  /// Retrieves all station bundles.
  Future<List<MvStationBundle>> getAllBundles() async {
    final db = await _db;
    final rows = await db.query('station_bundles', orderBy: 'usageCount DESC, createdAt DESC');
    return rows.map((r) => MvStationBundle.fromMap(r)).toList();
  }

  /// Retrieves a single station bundle by ID.
  Future<MvStationBundle?> getById(String id) async {
    final db = await _db;
    final rows = await db.query(
      'station_bundles',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return MvStationBundle.fromMap(rows.first);
  }

  /// Retrieves station bundles by category.
  Future<List<MvStationBundle>> getByCategory(String category) async {
    final db = await _db;
    final rows = await db.query(
      'station_bundles',
      where: 'category = ?',
      whereArgs: [category],
      orderBy: 'usageCount DESC',
    );
    return rows.map((r) => MvStationBundle.fromMap(r)).toList();
  }

  /// Inserts or replaces a station bundle.
  Future<void> upsertBundle(MvStationBundle bundle) async {
    final db = await _db;
    await db.insert(
      'station_bundles',
      bundle.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Increments usage counter.
  Future<void> bumpUsage(String id) async {
    final db = await _db;
    await db.rawUpdate(
      'UPDATE station_bundles SET usageCount = usageCount + 1, updatedAt = ? WHERE id = ?',
      [DateTime.now().millisecondsSinceEpoch, id],
    );
  }

  /// Deletes a user template bundle.
  Future<int> deleteBundle(String id) async {
    final db = await _db;
    return await db.delete(
      'station_bundles',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
