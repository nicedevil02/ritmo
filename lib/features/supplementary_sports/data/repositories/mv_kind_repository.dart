import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';
import 'package:sqflite/sqflite.dart';

/// Single Source of Truth Repository for Activity Kinds (`movement_kinds`).
class MvKindRepository {
  final DatabaseExecutor? _customDb;

  MvKindRepository([this._customDb]);

  Future<DatabaseExecutor> get _db async {
    final custom = _customDb;
    if (custom != null) return custom;
    return DatabaseHelper.instance.database;
  }

  Future<List<MvMovementKind>> getAll({bool onlyEnabled = true}) async {
    final db = await _db;
    final rows = await db.query(
      'movement_kinds',
      where: onlyEnabled ? 'isEnabled = 1' : null,
      orderBy: 'sortOrder ASC, code ASC',
    );
    return rows.map((r) => MvMovementKind.fromMap(r)).toList();
  }

  Future<MvMovementKind?> getByCode(String code) async {
    final db = await _db;
    final rows = await db.query(
      'movement_kinds',
      where: 'code = ?',
      whereArgs: [code],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return MvMovementKind.fromMap(rows.first);
  }

  Future<Map<String, MvMovementKind>> getMapByCodes(List<String> codes) async {
    if (codes.isEmpty) return const {};
    final db = await _db;
    final placeholders = List.filled(codes.length, '?').join(',');
    final rows = await db.query(
      'movement_kinds',
      where: 'code IN ($placeholders)',
      whereArgs: codes,
    );
    final map = <String, MvMovementKind>{};
    for (final row in rows) {
      final kind = MvMovementKind.fromMap(row);
      map[kind.code] = kind;
    }
    return map;
  }

  Future<List<MvMovementKind>> getByFamily(MovementFamily family) async {
    final db = await _db;
    final rows = await db.query(
      'movement_kinds',
      where: 'family = ? AND isEnabled = 1',
      whereArgs: [family.code],
      orderBy: 'sortOrder ASC, code ASC',
    );
    return rows.map((r) => MvMovementKind.fromMap(r)).toList();
  }

  Future<List<MvMovementKind>> searchFa(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) return getAll();
    final db = await _db;
    final pattern = '%$clean%';
    final rows = await db.query(
      'movement_kinds',
      where: 'isEnabled = 1 AND (titleFa LIKE ? OR aliasesFa LIKE ?)',
      whereArgs: [pattern, pattern],
      orderBy: 'usageCount DESC, sortOrder ASC',
    );
    return rows.map((r) => MvMovementKind.fromMap(r)).toList();
  }

  Future<List<MvMovementKind>> getRecent({int limit = 6}) async {
    final db = await _db;
    final rows = await db.query(
      'movement_kinds',
      where: 'isEnabled = 1',
      orderBy: 'lastUsedAt DESC, usageCount DESC, sortOrder ASC',
      limit: limit,
    );
    return rows.map((r) => MvMovementKind.fromMap(r)).toList();
  }

  Future<void> recordUsage(String code) async {
    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.rawUpdate(
      'UPDATE movement_kinds SET usageCount = usageCount + 1, lastUsedAt = ?, updatedAt = ? WHERE code = ?',
      [now, now, code],
    );
  }

  Future<void> bumpUsage(String code) => recordUsage(code);

  Future<List<MvMovementKind>> getSeasonal(int jalaliMonth) async {
    final all = await getAll();
    return all.where((k) {
      final mask = k.seasonMask;
      if (mask == null || mask.isEmpty) return true;
      final months = mask
          .split(',')
          .map((s) => int.tryParse(s.trim()))
          .whereType<int>()
          .toSet();
      return months.contains(jalaliMonth);
    }).toList();
  }

  Future<MvMovementKind> saveCustomKind(MvMovementKind kind) async {
    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    final toSave = kind.copyWith(isCustom: true);
    final map = toSave.toMap();
    map['updatedAt'] = now;
    map['createdAt'] = map['createdAt'] ?? now;
    await db.insert(
      'movement_kinds',
      map,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return toSave;
  }

  Future<void> setEnabled(String code, bool isEnabled) async {
    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.update(
      'movement_kinds',
      {'isEnabled': isEnabled ? 1 : 0, 'updatedAt': now},
      where: 'code = ?',
      whereArgs: [code],
    );
  }
}
