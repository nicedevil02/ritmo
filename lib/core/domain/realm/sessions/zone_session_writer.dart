import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/domain/realm/realm_state.dart';
import 'package:ritmo/core/domain/realm/sessions/zone_session.dart';
import 'package:ritmo/core/domain/realm/sessions/zone_session_repository.dart';
import 'package:ritmo/core/utils/ritmo_id_factory.dart';
import 'package:sqflite/sqflite.dart';

/// Single authoritative, idempotent writer for zone presence sessions (F-02, F-03).
class ZoneSessionWriter {
  ZoneSessionWriter({
    DatabaseHelper? dbHelper,
    ZoneSessionRepository? repository,
  })  : _dbHelper = dbHelper ?? DatabaseHelper.instance,
        _repository = repository ?? ZoneSessionRepository(dbHelper: dbHelper);

  final DatabaseHelper _dbHelper;
  final ZoneSessionRepository _repository;

  Future<Database> get _db => _dbHelper.database;

  /// Reconciles the active realm session with the latest [ActiveRealmState].
  ///
  /// Strictly idempotent:
  /// - If the current open session matches the active realm, updates plannedEndAt if changed and returns.
  /// - If the active realm changed, closes the open session and opens a new session.
  /// - If the user entered free time (no active realm), closes any open session.
  Future<void> reconcile(
    ActiveRealmState state, {
    required ZoneSource source,
    DateTime? now,
    DatabaseExecutor? executor,
  }) async {
    final effectiveNow = now ?? DateTime.now();
    final nowMs = effectiveNow.millisecondsSinceEpoch;
    final activeRealm = state.realmOrNull;
    final targetZoneId = (activeRealm != null && activeRealm.id.isNotEmpty)
        ? activeRealm.id
        : null;
    final plannedEndMs = _calculatePlannedEndMs(state);

    final db = executor ?? await _db;

    if (db is Database) {
      await db.transaction((txn) async {
        await _executeReconcile(
          txn: txn,
          targetZoneId: targetZoneId,
          plannedEndMs: plannedEndMs,
          source: source,
          nowMs: nowMs,
        );
      });
    } else {
      await _executeReconcile(
        txn: db,
        targetZoneId: targetZoneId,
        plannedEndMs: plannedEndMs,
        source: source,
        nowMs: nowMs,
      );
    }
  }

  Future<void> _executeReconcile({
    required DatabaseExecutor txn,
    required String? targetZoneId,
    required int? plannedEndMs,
    required ZoneSource source,
    required int nowMs,
  }) async {
    final openSession = await _repository.getOpenSession(executor: txn);

    // Case 1: Target realm is identical to current open session
    if (targetZoneId != null && openSession != null && openSession.zoneId == targetZoneId) {
      if (openSession.plannedEndAt != plannedEndMs) {
        await txn.update(
          'zone_sessions',
          {'plannedEndAt': plannedEndMs},
          where: 'id = ?',
          whereArgs: [openSession.id],
        );
      }
      return; // Idempotent no-op
    }

    // Case 2: There is an open session that must be closed
    if (openSession != null) {
      final endReason = (targetZoneId != null)
          ? (source == ZoneSource.manual ? ZoneEndReason.overridden : ZoneEndReason.completed)
          : ZoneEndReason.completed;

      await txn.update(
        'zone_sessions',
        {
          'endedAt': nowMs,
          'endReason': endReason.toRaw(),
        },
        where: 'id = ?',
        whereArgs: [openSession.id],
      );
    }

    // Case 3: We have an active target realm to open a session for
    if (targetZoneId != null && targetZoneId.isNotEmpty) {
      final newSession = ZoneSession(
        id: RitmoIdFactory.zoneSession(),
        zoneId: targetZoneId,
        startedAt: nowMs,
        endedAt: null,
        plannedEndAt: plannedEndMs,
        source: source,
        endReason: null,
        createdAt: nowMs,
      );

      await txn.insert(
        'zone_sessions',
        newSession.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  int? _calculatePlannedEndMs(ActiveRealmState state) {
    return switch (state) {
      ManualRealmState(:final expireAt) => expireAt.millisecondsSinceEpoch,
      ScheduledRealmState(:final endsAt) => endsAt.millisecondsSinceEpoch,
      FreeRealmState() => null,
      RealmErrorState() => null,
    };
  }

  /// Recovers abandoned open sessions at app startup (F-03).
  ///
  /// If the app was killed while a session was open, any session whose plannedEndAt
  /// (or startedAt + 8h default) is in the past will be closed with endReason = 'ABANDONED'.
  Future<int> recoverAbandonedSessions({
    DateTime? now,
    DatabaseExecutor? executor,
  }) async {
    final effectiveNow = now ?? DateTime.now();
    final nowMs = effectiveNow.millisecondsSinceEpoch;
    final db = executor ?? await _db;

    // F-03: Close abandoned sessions older than plannedEndAt (or 8h timeout)
    return await db.rawUpdate('''
      UPDATE zone_sessions
         SET endedAt = COALESCE(plannedEndAt, startedAt + 8 * 3600 * 1000),
             endReason = 'ABANDONED'
       WHERE endedAt IS NULL
         AND COALESCE(plannedEndAt, startedAt + 8 * 3600 * 1000) < ?;
    ''', [nowMs]);
  }

  /// Manually closes the currently open session (if any).
  Future<void> closeActiveSession({
    ZoneEndReason reason = ZoneEndReason.userEnded,
    DateTime? now,
    DatabaseExecutor? executor,
  }) async {
    final effectiveNow = now ?? DateTime.now();
    final nowMs = effectiveNow.millisecondsSinceEpoch;
    final db = executor ?? await _db;

    await db.update(
      'zone_sessions',
      {
        'endedAt': nowMs,
        'endReason': reason.toRaw(),
      },
      where: 'endedAt IS NULL',
    );
  }
}
