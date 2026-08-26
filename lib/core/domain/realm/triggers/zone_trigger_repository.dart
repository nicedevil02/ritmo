import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/domain/realm/triggers/zone_trigger.dart';
import 'package:sqflite/sqflite.dart';

/// Authoritative repository for realm automation triggers (F-08, F-10).
class ZoneTriggerRepository {
  ZoneTriggerRepository({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  final DatabaseHelper _dbHelper;

  /// Loads triggers with optional filtering by zoneId, kind, and enabled status.
  Future<List<ZoneTrigger>> loadTriggers({
    String? zoneId,
    TriggerKind? kind,
    bool onlyEnabled = false,
    DatabaseExecutor? executor,
  }) async {
    final db = executor ?? await _dbHelper.database;

    final conditions = <String>[];
    final args = <Object?>[];

    if (zoneId != null) {
      conditions.add('zoneId = ?');
      args.add(zoneId);
    }
    if (kind != null) {
      conditions.add('kind = ?');
      args.add(kind.toRaw());
    }
    if (onlyEnabled) {
      conditions.add('isEnabled = 1');
    }

    final whereClause = conditions.isNotEmpty ? conditions.join(' AND ') : null;

    final rows = await db.query(
      'zone_triggers',
      where: whereClause,
      whereArgs: args.isNotEmpty ? args : null,
      orderBy: 'priority DESC, createdAt ASC',
    );

    return rows.map(ZoneTrigger.fromMap).toList();
  }

  /// Inserts or replaces a trigger.
  Future<void> saveTrigger(
    ZoneTrigger trigger, {
    DatabaseExecutor? executor,
  }) async {
    final db = executor ?? await _dbHelper.database;
    await db.insert(
      'zone_triggers',
      trigger.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Deletes a trigger by id.
  Future<void> deleteTrigger(
    String triggerId, {
    DatabaseExecutor? executor,
  }) async {
    final db = executor ?? await _dbHelper.database;
    await db.delete(
      'zone_triggers',
      where: 'id = ?',
      whereArgs: [triggerId],
    );
  }

  /// Toggles trigger enabled state.
  Future<void> toggleTrigger(
    String triggerId,
    bool isEnabled, {
    DatabaseExecutor? executor,
  }) async {
    final db = executor ?? await _dbHelper.database;
    await db.update(
      'zone_triggers',
      {
        'isEnabled': isEnabled ? 1 : 0,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [triggerId],
    );
  }
}
