import 'dart:async';
import 'dart:convert';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/database/schema/tables/movement_tables.dart';
import 'package:ritmo/features/movement/domain/models/movement_activity_kind.dart';
import 'package:ritmo/features/movement/domain/models/movement_live_session.dart';
import 'package:ritmo/features/movement/domain/models/movement_occurrence.dart';
import 'package:ritmo/features/movement/domain/models/movement_session_event.dart';
import 'package:ritmo/features/movement/domain/models/movement_workout_log.dart';
import 'package:sqflite/sqflite.dart';

/// سرویس مدیریت و ثبت بلادرنگ جلسات زندهٔ ورزشی در لایهٔ Application
class MovementSessionService {
  MovementSessionService({this.db});

  final Database? db;
  static int _eventSeq = 0;

  Future<Database> get _database async =>
      db ?? await DatabaseHelper.instance.database;

  // ---------------------------------------------------------------------------
  // ۱. خواندن و بازیابی جلسه
  // ---------------------------------------------------------------------------

  /// بازیابی جلسهٔ در حال اجرا یا متوقف‌شدهٔ جاری
  Future<MovementLiveSession?> getActiveOrPausedSession() async {
    final dbExec = await _database;
    final rows = await dbExec.query(
      MovementTables.tableLiveSessions,
      where: 'status = ? OR status = ?',
      whereArgs: [
        MovementLiveSessionStatus.active.name,
        MovementLiveSessionStatus.paused.name,
      ],
      orderBy: 'createdAt DESC',
      limit: 1,
    );

    if (rows.isEmpty) return null;
    return _hydrateSession(dbExec, rows.first);
  }

  /// بازیابی جلسه با شناسه
  Future<MovementLiveSession?> getSessionById(String sessionId) async {
    final dbExec = await _database;
    final rows = await dbExec.query(
      MovementTables.tableLiveSessions,
      where: 'id = ?',
      whereArgs: [sessionId],
      limit: 1,
    );

    if (rows.isEmpty) return null;
    return _hydrateSession(dbExec, rows.first);
  }

  Future<MovementLiveSession> _hydrateSession(
    Database dbExec,
    Map<String, dynamic> row,
  ) async {
    final kindId = row['activityKindId'] as String;
    final kindRows = await dbExec.query(
      MovementTables.tableActivityKinds,
      where: 'id = ?',
      whereArgs: [kindId],
      limit: 1,
    );
    final kind = kindRows.isNotEmpty
        ? MovementActivityKind.fromMap(kindRows.first)
        : null;

    return MovementLiveSession.fromMap(row, activityKind: kind);
  }

  // ---------------------------------------------------------------------------
  // ۲. شروع و ساخت جلسه
  // ---------------------------------------------------------------------------

  /// شروع یا ایجاد یک جلسهٔ زنده جدید
  Future<MovementLiveSession> startSession({
    String? occurrenceId,
    required String activityKindId,
    String mode = 'time',
    Map<String, dynamic>? targetSnapshot,
  }) async {
    final dbExec = await _database;
    final now = DateTime.now().toUtc();
    final sessionId =
        'live_${now.millisecondsSinceEpoch}_${activityKindId.hashCode.abs()}';

    final session = MovementLiveSession(
      id: sessionId,
      occurrenceId: occurrenceId,
      activityKindId: activityKindId,
      mode: mode,
      status: MovementLiveSessionStatus.active,
      startedAt: now,
      accumulatedPauseMs: 0,
      targetSnapshotJson: targetSnapshot != null
          ? jsonEncode(targetSnapshot)
          : null,
      createdAt: now,
      updatedAt: now,
    );

    await dbExec.transaction((txn) async {
      await txn.insert(
        MovementTables.tableLiveSessions,
        session.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // ثبت رویداد start بلافاصله
      final startEvent = MovementSessionEvent(
        id: 'evt_${now.millisecondsSinceEpoch}_start',
        sessionId: sessionId,
        type: MovementSessionEventType.start,
        payloadJson: targetSnapshot != null ? jsonEncode(targetSnapshot) : null,
        at: now,
      );
      await txn.insert(
        MovementTables.tableSessionEvents,
        startEvent.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // اگر از روی occurrence اجرا شده، وضعیت occurrence را به inProgress تغییر می‌دهیم
      if (occurrenceId != null) {
        await txn.update(
          MovementTables.tableOccurrences,
          {
            'status': MovementOccurrenceStatus.inProgress.name,
            'updatedAt': now.toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [occurrenceId],
        );
      }
    });

    final hydrated = await getSessionById(sessionId);
    return hydrated ?? session;
  }

  // ---------------------------------------------------------------------------
  // ۳. ثبت رویدادها (Event-Driven Persistence)
  // ---------------------------------------------------------------------------

  /// ثبت بلادرنگ یک رویداد در جدول movement_session_events
  Future<MovementSessionEvent> recordEvent({
    required String sessionId,
    required MovementSessionEventType type,
    Map<String, dynamic>? payload,
    DateTime? at,
  }) async {
    final dbExec = await _database;
    final now = (at ?? DateTime.now()).toUtc();
    final eventId = 'evt_${now.microsecondsSinceEpoch}_${_eventSeq++}_${type.name}';

    final event = MovementSessionEvent(
      id: eventId,
      sessionId: sessionId,
      type: type,
      payloadJson: payload != null ? jsonEncode(payload) : null,
      at: now,
    );

    await dbExec.insert(
      MovementTables.tableSessionEvents,
      event.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    return event;
  }

  /// دریافت تمام رویدادهای ثبت‌شدهٔ یک جلسه
  Future<List<MovementSessionEvent>> getEvents(String sessionId) async {
    final dbExec = await _database;
    final rows = await dbExec.query(
      MovementTables.tableSessionEvents,
      where: 'sessionId = ?',
      whereArgs: [sessionId],
      orderBy: 'at ASC',
    );

    return rows.map((r) => MovementSessionEvent.fromMap(r)).toList();
  }

  // ---------------------------------------------------------------------------
  // ۴. کنترل وضعیت تایمر و جلسه
  // ---------------------------------------------------------------------------

  /// توقف موقت جلسه (Pause)
  Future<void> pauseSession(String sessionId) async {
    final dbExec = await _database;
    final now = DateTime.now().toUtc();

    await dbExec.transaction((txn) async {
      await txn.update(
        MovementTables.tableLiveSessions,
        {
          'status': MovementLiveSessionStatus.paused.name,
          'updatedAt': now.toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [sessionId],
      );

      final event = MovementSessionEvent(
        id: 'evt_${now.millisecondsSinceEpoch}_pause',
        sessionId: sessionId,
        type: MovementSessionEventType.pause,
        at: now,
      );
      await txn.insert(MovementTables.tableSessionEvents, event.toMap());
    });
  }

  /// ادامه دادن جلسه (Resume)
  Future<void> resumeSession(String sessionId) async {
    final dbExec = await _database;
    final now = DateTime.now().toUtc();

    // یافتن آخرین رویداد Pause برای محاسبهٔ وقفه
    final events = await getEvents(sessionId);
    int addedPauseMs = 0;
    final lastPauseIndex = events.lastIndexWhere(
      (e) => e.type == MovementSessionEventType.pause,
    );
    if (lastPauseIndex != -1) {
      final pauseAt = events[lastPauseIndex].at;
      addedPauseMs = now.difference(pauseAt).inMilliseconds;
      if (addedPauseMs < 0) addedPauseMs = 0;
    }

    final currentSession = await getSessionById(sessionId);
    final newPauseMs = (currentSession?.accumulatedPauseMs ?? 0) + addedPauseMs;

    await dbExec.transaction((txn) async {
      await txn.update(
        MovementTables.tableLiveSessions,
        {
          'status': MovementLiveSessionStatus.active.name,
          'accumulatedPauseMs': newPauseMs,
          'updatedAt': now.toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [sessionId],
      );

      final event = MovementSessionEvent(
        id: 'evt_${now.millisecondsSinceEpoch}_resume',
        sessionId: sessionId,
        type: MovementSessionEventType.resume,
        payloadJson: jsonEncode({'pauseDurationMs': addedPauseMs}),
        at: now,
      );
      await txn.insert(MovementTables.tableSessionEvents, event.toMap());
    });
  }

  /// تغییر هدف در حین جلسه
  Future<void> changeGoal(String sessionId, Map<String, dynamic> target) async {
    final dbExec = await _database;
    final now = DateTime.now().toUtc();

    await dbExec.transaction((txn) async {
      await txn.update(
        MovementTables.tableLiveSessions,
        {
          'targetSnapshotJson': jsonEncode(target),
          'updatedAt': now.toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [sessionId],
      );

      await recordEvent(
        sessionId: sessionId,
        type: MovementSessionEventType.goalChange,
        payload: target,
      );
    });
  }

  // ---------------------------------------------------------------------------
  // ۵. پایان و رهاسازی جلسه
  // ---------------------------------------------------------------------------

  /// پایان موفق یا نیمه‌تمام جلسه و ساخت WorkoutLog
  Future<MovementWorkoutLog> finishSession(
    String sessionId, {
    String? feeling,
    String? note,
    Map<String, dynamic>? finalMetrics,
  }) async {
    final dbExec = await _database;
    final now = DateTime.now().toUtc();

    final session = await getSessionById(sessionId);
    if (session == null) {
      throw StateError('Live session not found: $sessionId');
    }

    final elapsedSec = session.elapsedSeconds;
    final logId =
        'log_${now.millisecondsSinceEpoch}_${session.activityKindId.hashCode.abs()}';
    final dateIso =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final startTimeStr = session.startedAt != null
        ? '${session.startedAt!.hour.toString().padLeft(2, '0')}:${session.startedAt!.minute.toString().padLeft(2, '0')}'
        : null;

    final workoutLog = MovementWorkoutLog(
      id: logId,
      occurrenceId: session.occurrenceId,
      activityKindId: session.activityKindId,
      dateIso: dateIso,
      startTime: startTimeStr,
      durationSec: elapsedSec > 0 ? elapsedSec : 1,
      metricJson: finalMetrics != null ? jsonEncode(finalMetrics) : null,
      feeling: feeling,
      note: note,
      source: 'live',
      createdAt: now,
      updatedAt: now,
    );

    await dbExec.transaction((txn) async {
      // ۱. به‌روزرسانی جلسهٔ زنده به وضعیت completed
      await txn.update(
        MovementTables.tableLiveSessions,
        {
          'status': MovementLiveSessionStatus.completed.name,
          'updatedAt': now.toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [sessionId],
      );

      // ۲. ثبت رویداد finish
      final finishEvent = MovementSessionEvent(
        id: 'evt_${now.millisecondsSinceEpoch}_finish',
        sessionId: sessionId,
        type: MovementSessionEventType.finish,
        payloadJson: finalMetrics != null ? jsonEncode(finalMetrics) : null,
        at: now,
      );
      await txn.insert(
        MovementTables.tableSessionEvents,
        finishEvent.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // ۳. ثبت WorkoutLog
      await txn.insert(
        MovementTables.tableWorkoutLogs,
        workoutLog.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // ۴. به‌روزرسانی Occurrence در صورت وجود
      if (session.occurrenceId != null) {
        await txn.update(
          MovementTables.tableOccurrences,
          {
            'status': MovementOccurrenceStatus.completed.name,
            'updatedAt': now.toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [session.occurrenceId],
        );
      }
    });

    return workoutLog;
  }

  /// رهاسازی (Abandon) جلسه
  Future<void> abandonSession(String sessionId) async {
    final dbExec = await _database;
    final now = DateTime.now().toUtc();

    final session = await getSessionById(sessionId);

    await dbExec.transaction((txn) async {
      await txn.update(
        MovementTables.tableLiveSessions,
        {
          'status': MovementLiveSessionStatus.abandoned.name,
          'updatedAt': now.toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [sessionId],
      );

      final event = MovementSessionEvent(
        id: 'evt_${now.millisecondsSinceEpoch}_abandon',
        sessionId: sessionId,
        type: MovementSessionEventType.abandon,
        at: now,
      );
      await txn.insert(
        MovementTables.tableSessionEvents,
        event.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // برگرداندن وضعیت occurrence در صورت وجود به planned
      if (session?.occurrenceId != null) {
        await txn.update(
          MovementTables.tableOccurrences,
          {
            'status': MovementOccurrenceStatus.planned.name,
            'updatedAt': now.toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [session!.occurrenceId],
        );
      }
    });
  }

  /// حذف فیزیکی ردیف جلسهٔ زنده (برای پاکسازی نهایی پس از نمایش خلاصه)
  Future<void> deleteLiveSession(String sessionId) async {
    final dbExec = await _database;
    await dbExec.delete(
      MovementTables.tableLiveSessions,
      where: 'id = ?',
      whereArgs: [sessionId],
    );
  }
}
