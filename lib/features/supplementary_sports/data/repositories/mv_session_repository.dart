import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/database/upsert_helper.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';
import 'package:sqflite/sqflite.dart';

/// Single Source of Truth Repository for Live & Historical Sessions (`movement_sessions`, `ss_session_set_log`).
class MvSessionRepository {
  final DatabaseExecutor? _customDb;

  MvSessionRepository([this._customDb]);

  Future<DatabaseExecutor> get _db async {
    final custom = _customDb;
    if (custom != null) return custom;
    return DatabaseHelper.instance.database;
  }

  /// Retrieves the currently active or paused session, if any.
  Future<MvSession?> getActiveSession() async {
    final db = await _db;
    final rows = await db.query(
      'movement_sessions',
      where: "status IN ('ACTIVE', 'PAUSED')",
      orderBy: 'startedAt DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return MvSession.fromMap(rows.first);
  }

  /// Starts a new session and persists it.
  Future<void> startSession(MvSession session) async {
    final db = await _db;
    await UpsertHelper.upsert(
      db,
      'movement_sessions',
      session.toMap(),
      conflictColumns: const ['id'],
    );
  }

  /// Updates an active or paused session state.
  Future<void> updateSession(MvSession session) async {
    final db = await _db;
    await db.update(
      'movement_sessions',
      session.toMap(),
      where: 'id = ?',
      whereArgs: [session.id],
    );
  }

  /// Records a lifecycle event for crash recovery and audit.
  Future<void> recordEvent(MvSessionEvent event) async {
    final db = await _db;
    await UpsertHelper.upsert(
      db,
      'movement_session_events',
      event.toMap(),
      conflictColumns: const ['id'],
    );
  }

  /// Retrieves all recorded events for a session.
  Future<List<MvSessionEvent>> getEventsForSession(String sessionId) async {
    final db = await _db;
    final rows = await db.query(
      'movement_session_events',
      where: 'sessionId = ?',
      whereArgs: [sessionId],
      orderBy: 'at ASC',
    );
    return rows.map((r) => MvSessionEvent.fromMap(r)).toList();
  }

  /// Finishes a workout session, persists set logs, and updates prescription slot atomically.
  Future<void> finishSession(
    MvSession session, {
    List<MvSetLog> setLogs = const [],
    MvSessionFeeling? feeling,
    String? note,
  }) async {
    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    final completedSession = session.copyWith(
      status: session.status == MvSessionStatus.active
          ? MvSessionStatus.completed
          : session.status,
      endedAt: session.endedAt ?? now,
      overallFeeling: feeling?.rirValue ?? session.overallFeeling,
      note: note ?? session.note,
      updatedAt: now,
    );

    Future<void> runInternal(DatabaseExecutor executor) async {
      await UpsertHelper.upsert(
        executor,
        'movement_sessions',
        completedSession.toMap(),
        conflictColumns: const ['id'],
      );

      for (final setLog in setLogs) {
        await UpsertHelper.upsert(
          executor,
          'ss_session_set_log',
          setLog.toMap(),
          conflictColumns: const ['id'],
        );
      }

      if (session.prescriptionId != null) {
        final presStatus = session.status == MvSessionStatus.partial
            ? MvSlotStatus.partial
            : MvSlotStatus.done;
        await executor.update(
          'ss_session_prescription',
          {
            'status': presStatus.code,
            'workoutLogId': session.id,
            'updatedAt': DateTime.now().millisecondsSinceEpoch,
          },
          where: 'id = ?',
          whereArgs: [session.prescriptionId],
        );
      }
    }

    if (db is Database) {
      await db.transaction((txn) async {
        await runInternal(txn);
      });
    } else {
      await runInternal(db);
    }
  }

  /// Records a single workout set.
  Future<void> recordSetLog(MvSetLog setLog) async {
    final db = await _db;
    await UpsertHelper.upsert(
      db,
      'ss_session_set_log',
      setLog.toMap(),
      conflictColumns: const ['id'],
    );
  }

  /// Retrieves all set logs for a specific session.
  Future<List<MvSetLog>> getSetLogsForSession(String sessionId) async {
    final db = await _db;
    final rows = await db.query(
      'ss_session_set_log',
      where: 'sessionId = ?',
      whereArgs: [sessionId],
      orderBy: 'setNumber ASC',
    );
    return rows.map((r) => MvSetLog.fromMap(r)).toList();
  }

  /// Retrieves historical set logs for an exercise to power progression calculations.
  Future<List<MvSetLog>> getSetLogsForExercise(
    String exerciseId, {
    int limit = 50,
  }) async {
    final db = await _db;
    final rows = await db.query(
      'ss_session_set_log',
      where: 'exerciseId = ?',
      whereArgs: [exerciseId],
      orderBy: 'loggedAt DESC',
      limit: limit,
    );
    return rows.map((r) => MvSetLog.fromMap(r)).toList();
  }

  /// Retrieves completed sessions for history and analytics.
  Future<List<MvSession>> getSessionHistory({
    int limit = 20,
    int offset = 0,
  }) async {
    final db = await _db;
    final rows = await db.query(
      'movement_sessions',
      where: "status IN ('COMPLETED', 'PARTIAL')",
      orderBy: 'startedAt DESC',
      limit: limit,
      offset: offset,
    );
    return rows.map((r) => MvSession.fromMap(r)).toList();
  }

  /// Retrieves completed sessions between two DateTime boundaries.
  Future<List<MvSession>> getCompletedSessionsBetween(
    DateTime from,
    DateTime to,
  ) async {
    final db = await _db;
    final fromMs = from.millisecondsSinceEpoch;
    final toMs = to.millisecondsSinceEpoch;
    final rows = await db.query(
      'movement_sessions',
      where:
          "status IN ('COMPLETED', 'PARTIAL') AND startedAt >= ? AND startedAt <= ?",
      whereArgs: [fromMs, toMs],
      orderBy: 'startedAt DESC',
    );
    return rows.map((r) => MvSession.fromMap(r)).toList();
  }

  /// Alias for getSessionHistory.
  Future<List<MvSession>> getRecentSessions({int limit = 20}) =>
      getSessionHistory(limit: limit);

  /// Retrieves the most recent completed session for quick re-log / favorites (N-12).
  Future<MvSession?> getLastCompletedSession() async {
    final db = await _db;
    final rows = await db.query(
      'movement_sessions',
      where: "status IN ('COMPLETED', 'PARTIAL')",
      orderBy: 'startedAt DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return MvSession.fromMap(rows.first);
  }

  /// Deletes a session by ID.
  Future<void> deleteSession(String id) async {
    final db = await _db;
    await db.delete('movement_sessions', where: 'id = ?', whereArgs: [id]);
  }
}
