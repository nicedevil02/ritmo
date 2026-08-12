// lib/features/supplementary_sports/movement/data/movement_session_repository.dart

import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/utils/ritmo_id_factory.dart';
import 'package:ritmo/features/supplementary_sports/movement/domain/movement_session.dart';
import 'package:ritmo/features/supplementary_sports/movement/domain/movement_kind.dart';
import 'package:ritmo/features/supplementary_sports/movement/domain/movement_event.dart';
import 'package:ritmo/features/supplementary_sports/movement/data/movement_repository.dart';
import 'package:ritmo/core/domain/engines/ritmo_event_bus.dart';

class MovementSessionRepository {
  MovementSessionRepository._();
  static final instance = MovementSessionRepository._();

  Future<Database> get _db async => DatabaseHelper.instance.database;

  /// جلسهٔ زندهٔ فعلی (در صورت وجود) — برای بازیابی هنگام باز شدن اپ.
  Future<MovementSession?> getActiveSession() async {
    final db = await _db;
    final rows = await db.query(
      'movement_sessions',
      where: "status IN ('ACTIVE','PAUSED')",
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return MovementSession.fromMap(rows.first);
  }

  /// شروع جلسه. اگر جلسهٔ زندهٔ دیگری باشد خطا می‌دهد؛ UI باید اول
  /// دیالوگ بازیابی (ادامه/پایان/حذف) را نشان دهد.
  Future<MovementSession> startSession({
    required MovementKind kind,
    required String sessionMode,
    String? routineId,
    String? occurrenceId,
    Map<String, dynamic>? target,
  }) async {
    final db = await _db;
    final existing = await getActiveSession();
    if (existing != null) {
      throw StateError('SESSION_ALREADY_ACTIVE:${existing.id}');
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final session = MovementSession(
      id: RitmoIdFactory.movementSession(),
      kindCode: kind.code,
      routineId: routineId,
      occurrenceId: occurrenceId,
      sessionMode: sessionMode,
      status: MovementSessionStatus.active,
      startedAt: now,
      pausedMs: 0,
      targetJson: target == null ? null : jsonEncode(target),
      liveJson: jsonEncode(const {}),
      createdAt: now,
      updatedAt: now,
    );

    await db.transaction((txn) async {
      await txn.insert('movement_sessions', session.toMap());
      await _appendEvent(txn, session.id, SessionEventType.start, now, null);
    });
    
    RitmoEventBus().fire(RitmoEvent(
      type: 'movement_session_started',
      timestamp: DateTime.now(),
      payload: {
        'kindCode': kind.code,
        'sessionMode': sessionMode,
      },
    ));
    
    return session;
  }

  /// مکث: زمان شروع مکث در liveJson نگه داشته می‌شود تا RESUME بتواند pausedMs را جمع کند.
  Future<void> pauseSession(String sessionId) async {
    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction((txn) async {
      final rows = await txn.query('movement_sessions',
          where: 'id = ? AND status = ?', whereArgs: [sessionId, 'ACTIVE'], limit: 1);
      if (rows.isEmpty) return; // idempotent
      final live = jsonDecode(rows.first['liveJson'] as String? ?? '{}') as Map<String, dynamic>;
      live['pauseStartedAt'] = now;
      await txn.update(
        'movement_sessions',
        {'status': 'PAUSED', 'liveJson': jsonEncode(live), 'updatedAt': now},
        where: 'id = ?',
        whereArgs: [sessionId],
      );
      await _appendEvent(txn, sessionId, SessionEventType.pause, now, null);
    });
  }

  /// ادامه: مدت مکث به pausedMs اضافه می‌شود.
  Future<void> resumeSession(String sessionId) async {
    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction((txn) async {
      final rows = await txn.query('movement_sessions',
          where: 'id = ? AND status = ?', whereArgs: [sessionId, 'PAUSED'], limit: 1);
      if (rows.isEmpty) return; // idempotent
      final row = rows.first;
      final live = jsonDecode(row['liveJson'] as String? ?? '{}') as Map<String, dynamic>;
      final pauseStartedAt = live.remove('pauseStartedAt') as int? ?? now;
      final newPausedMs = (row['pausedMs'] as int? ?? 0) + (now - pauseStartedAt);
      await txn.update(
        'movement_sessions',
        {'status': 'ACTIVE', 'pausedMs': newPausedMs, 'liveJson': jsonEncode(live), 'updatedAt': now},
        where: 'id = ?',
        whereArgs: [sessionId],
      );
      await _appendEvent(txn, sessionId, SessionEventType.resume, now, null);
    });
  }

  /// ثبت رویداد دور/اسپلیت/نقطهٔ مهم (مثل «رسیدم به قله») — فقط افزودنی.
  Future<void> logSessionEvent(String sessionId, SessionEventType type, Map<String, dynamic>? data) async {
    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction((txn) async {
      await _appendEvent(txn, sessionId, type, now, data);
      await txn.rawUpdate('UPDATE movement_sessions SET updatedAt = ? WHERE id = ?',
          [now, sessionId]);
    });
  }

  /// پایان و تولید لاگ نهایی — خودتوان (idempotent) به لطف ایندکس موجود
  /// idx_workout_logs_source_entity روی (sourceModule, sourceEntityId).
  Future<String> finishSession(String sessionId, {String? feeling, String? note}) async {
    final db = await _db;
    String logId = '';
    await db.transaction((txn) async {
      final rows = await txn.query('movement_sessions', where: 'id = ?', whereArgs: [sessionId], limit: 1);
      if (rows.isEmpty) throw StateError('SESSION_NOT_FOUND:$sessionId');
      final session = MovementSession.fromMap(rows.first);

      if (session.status == MovementSessionStatus.completed && session.workoutLogId != null) {
        logId = session.workoutLogId!; // قبلاً finalize شده — دوباره‌کاری نکن
        return;
      }

      final now = DateTime.now().millisecondsSinceEpoch;
      // اگر هنگام پایان جلسه PAUSED بود، مکث باز را هم ببند.
      var pausedMs = session.pausedMs;
      final live = jsonDecode(session.liveJson ?? '{}') as Map<String, dynamic>;
      final pauseStartedAt = live.remove('pauseStartedAt') as int?;
      if (session.status == MovementSessionStatus.paused && pauseStartedAt != null) {
        pausedMs += now - pauseStartedAt;
      }
      final elapsedMs = now - session.startedAt - pausedMs;
      final durationMinutes = (elapsedMs / 60000).round().clamp(1, 24 * 60);

      final event = MovementEvent(
        id: RitmoIdFactory.movementLog(),
        kindCode: session.kindCode,
        durationMinutes: durationMinutes,
        intensity: MovementIntensity.medium,
        note: note,
        loggedAt: session.startedAt,
        endedAt: now,
        feeling: feeling,
        // سنجه‌های حالت (مسافت/ارتفاع/دور دستی) از live خوانده می‌شوند — فاز ۴ آن‌ها را پر می‌کند:
        distanceMeters: (live['manualDistanceMeters'] as num?)?.toDouble(),
        elevationMeters: (live['manualElevationMeters'] as num?)?.toDouble(),
        laps: (live['laps'] as num?)?.toInt(),
        sourceModule: 'MOVEMENT_SESSION',
        sourceEntityId: sessionId,
      );

      // همان کانال یکتای upsert: دوبار finalize = یک رکورد.
      final res = await MovementRepository.instance.upsertEventInTransaction(txn, event);
      logId = res['id'] as String;

      await txn.update(
        'movement_sessions',
        {'status': 'COMPLETED', 'endedAt': now, 'pausedMs': pausedMs, 'liveJson': jsonEncode(live), 'workoutLogId': logId, 'updatedAt': now},
        where: 'id = ?',
        whereArgs: [sessionId],
      );
      await _appendEvent(txn, sessionId, SessionEventType.finish, now, {'workoutLogId': logId});
    });

    RitmoEventBus().fire(RitmoEvent(
      type: 'movement_session_completed',
      timestamp: DateTime.now(),
      payload: {
        'sessionId': sessionId,
      },
    ));

    return logId;
  }

  /// رهاسازی جلسه بدون تولید لاگ (مثلاً کاربر «حذف» را در دیالوگ بازیابی زد).
  Future<void> abandonSession(String sessionId) async {
    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction((txn) async {
      await txn.update(
        'movement_sessions',
        {'status': 'ABANDONED', 'endedAt': now, 'updatedAt': now},
        where: "id = ? AND status IN ('ACTIVE','PAUSED')",
        whereArgs: [sessionId],
      );
      await _appendEvent(txn, sessionId, SessionEventType.abandon, now, null);
    });

    RitmoEventBus().fire(RitmoEvent(
      type: 'movement_session_abandoned',
      timestamp: DateTime.now(),
      payload: {
        'sessionId': sessionId,
      },
    ));
  }

  /// بازیابی وضعیت با بازپخش جرنال — برای نمایش دورها/نقاط بعد از کرش.
  Future<List<Map<String, dynamic>>> getSessionEvents(String sessionId) async {
    final db = await _db;
    return db.query('movement_session_events',
        where: 'sessionId = ?', whereArgs: [sessionId], orderBy: 'at ASC');
  }

  Future<void> _appendEvent(
      DatabaseExecutor txn, String sessionId, SessionEventType type, int at, Map<String, dynamic>? data) async {
    await txn.insert('movement_session_events', {
      'id': RitmoIdFactory.movementLog(),
      'sessionId': sessionId,
      'type': type.name.toUpperCase(),
      'at': at,
      'dataJson': data == null ? null : jsonEncode(data),
    });
  }
}
