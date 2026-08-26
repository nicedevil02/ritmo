import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/domain/realm/sessions/zone_session.dart';
import 'package:sqflite/sqflite.dart';

/// Repository responsible for querying historical and active realm sessions (F-01).
class ZoneSessionRepository {
  ZoneSessionRepository({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  final DatabaseHelper _dbHelper;

  Future<Database> get _db => _dbHelper.database;

  /// Returns the currently active/open session if any (endedAt IS NULL).
  Future<ZoneSession?> getOpenSession({DatabaseExecutor? executor}) async {
    final db = executor ?? await _db;
    final rows = await db.query(
      'zone_sessions',
      where: 'endedAt IS NULL',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return ZoneSession.fromMap(rows.first);
  }

  /// Returns a session by ID.
  Future<ZoneSession?> getSessionById(
    String id, {
    DatabaseExecutor? executor,
  }) async {
    final db = executor ?? await _db;
    final rows = await db.query(
      'zone_sessions',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return ZoneSession.fromMap(rows.first);
  }

  /// Queries all sessions within a timestamp range (inclusive).
  Future<List<ZoneSession>> getSessionsForRange({
    required DateTime start,
    required DateTime end,
    String? zoneId,
    DatabaseExecutor? executor,
  }) async {
    final db = executor ?? await _db;
    final startMs = start.millisecondsSinceEpoch;
    final endMs = end.millisecondsSinceEpoch;

    final whereClauses = <String>['startedAt <= ? AND (endedAt IS NULL OR endedAt >= ?)'];
    final whereArgs = <dynamic>[endMs, startMs];

    if (zoneId != null) {
      whereClauses.add('zoneId = ?');
      whereArgs.add(zoneId);
    }

    final rows = await db.query(
      'zone_sessions',
      where: whereClauses.join(' AND '),
      whereArgs: whereArgs,
      orderBy: 'startedAt ASC',
    );

    return rows.map(ZoneSession.fromMap).toList();
  }

  /// Returns all sessions that occurred today.
  Future<List<ZoneSession>> getTodaySessions({DatabaseExecutor? executor}) async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
    return getSessionsForRange(
      start: startOfDay,
      end: endOfDay,
      executor: executor,
    );
  }

  /// Deletes a session by ID.
  Future<int> deleteSession(String id, {DatabaseExecutor? executor}) async {
    final db = executor ?? await _db;
    return db.delete(
      'zone_sessions',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
