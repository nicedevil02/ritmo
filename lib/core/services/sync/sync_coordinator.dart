import 'package:flutter/foundation.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/services/sync/agenda_widget_snapshot_service.dart';
import 'package:ritmo/core/services/sync/home_widget_snapshot_service.dart';
import 'package:ritmo/core/services/sync/occurrence_sync_service.dart';
import 'package:ritmo/core/services/sync/reminder_snapshot_service.dart';
import 'package:ritmo/core/services/sync/rhythm_snapshot_service.dart';
import 'package:ritmo/core/services/sync/today_snapshot_context_builder.dart';

/// Runs every "keep derived data fresh" step in one place.
///
/// This is by far the heaviest thing a cold dashboard load does: rhythm
/// backfill, occurrence generation, four snapshot writes and a full agenda
/// build. It is also reachable from many places (dashboard load, snapshot
/// sync, module changes, alarm scheduling, onboarding hand-off), and every
/// `RitmoEvents.notifyRoutineChanged()` makes Home reload, which calls it
/// again.
///
/// Without protection a burst of notifications - exactly what happens in the
/// first second after onboarding finishes - multiplies this work N times over,
/// which is how the app managed to exhaust the Dart heap ("evacuation failed" /
/// "Exhausted heap space") instead of merely being slow. `syncAll()` is
/// therefore single-flight: overlapping callers share the pass that is already
/// running.
class SyncCoordinator {
  const SyncCoordinator();

  static Future<void>? _inFlight;
  static int _runCount = 0;
  static int _joinCount = 0;

  /// Real sync passes since app start (diagnostics only).
  static int get runCount => _runCount;

  /// Callers that joined an already-running pass (diagnostics only).
  static int get joinCount => _joinCount;

  Future<void> syncAll() async {
    final inFlight = _inFlight;
    if (inFlight != null) {
      _joinCount++;
      debugPrint(
        '[SyncCoordinator] joined in-flight syncAll '
        '(joins=$_joinCount runs=$_runCount)',
      );
      return inFlight;
    }

    final run = _runSyncAll();
    _inFlight = run;
    try {
      await run;
    } finally {
      _inFlight = null;
    }
  }

  Future<void> _runSyncAll() async {
    _runCount++;
    final runId = _runCount;
    final startedAtMs = DateTime.now().millisecondsSinceEpoch;
    debugPrint('[SyncCoordinator] syncAll #$runId start');

    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now();
    final todayStr = now.toIso8601String().substring(0, 10);

    final settingsResult = await db.query('app_settings');
    final settingsMap = {
      for (final s in settingsResult)
        s['key']! as String: s['value']! as String,
    };

    await const RhythmSnapshotService().backfillRhythmLogs(
      db: db,
      settingsMap: settingsMap,
    );

    await const RhythmSnapshotService().syncDailyRhythmForDate(
      db: db,
      dateStr: todayStr,
      settingsMap: settingsMap,
    );

    await const OccurrenceSyncService().backfillAndGenerateAll(db);

    final state = await const TodaySnapshotContextBuilder().build(
      db: db,
      now: now,
      settingsMap: settingsMap,
    );

    await const HomeWidgetSnapshotService().sync(db: db, state: state);

    await const AgendaWidgetSnapshotService().sync(now: now);

    await const ReminderSnapshotService().sync(
      db: db,
      settingsMap: settingsMap,
    );

    final elapsedMs = DateTime.now().millisecondsSinceEpoch - startedAtMs;
    debugPrint('[SyncCoordinator] syncAll #$runId done in ${elapsedMs}ms');
  }
}
