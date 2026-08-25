import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';
import 'package:sqflite/sqflite.dart';

/// مخزن پروفایل‌های فیزیولوژیک انواع ورزش (S3-T2)
abstract class MvKindProfileRepository {
  Future<MvKindProfile?> getByCode(String kindCode);
  Future<Map<String, MvKindProfile>> getMapByCodes(List<String> codes);
  Future<List<MvKindProfile>> getAll();
  Future<void> upsert(MvKindProfile profile);
}

class MvKindProfileRepositoryImpl implements MvKindProfileRepository {
  final DatabaseExecutor? _customDb;

  MvKindProfileRepositoryImpl([this._customDb]);

  Future<DatabaseExecutor> get _db async =>
      _customDb ?? await DatabaseHelper.instance.database;

  @override
  Future<MvKindProfile?> getByCode(String kindCode) async {
    final db = await _db;
    final rows = await db.query(
      'mv_kind_profile',
      where: 'kindCode = ?',
      whereArgs: [kindCode],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return MvKindProfile.fromMap(rows.first);
  }

  @override
  Future<Map<String, MvKindProfile>> getMapByCodes(List<String> codes) async {
    if (codes.isEmpty) return {};
    final db = await _db;
    final placeholders = List.filled(codes.length, '?').join(',');
    final rows = await db.query(
      'mv_kind_profile',
      where: 'kindCode IN ($placeholders)',
      whereArgs: codes,
    );
    return {
      for (final r in rows) (r['kindCode'] as String): MvKindProfile.fromMap(r),
    };
  }

  @override
  Future<List<MvKindProfile>> getAll() async {
    final db = await _db;
    final rows = await db.query('mv_kind_profile', orderBy: 'kindCode ASC');
    return rows.map(MvKindProfile.fromMap).toList();
  }

  @override
  Future<void> upsert(MvKindProfile profile) async {
    final db = await _db;
    await db.insert(
      'mv_kind_profile',
      profile.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
