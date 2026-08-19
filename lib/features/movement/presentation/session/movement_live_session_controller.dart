import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:ritmo/features/movement/application/movement_analytics_service.dart';
import 'package:ritmo/features/movement/application/movement_session_service.dart';
import 'package:ritmo/features/movement/domain/models/movement_activity_kind.dart';
import 'package:ritmo/features/movement/domain/models/movement_live_session.dart';
import 'package:ritmo/features/movement/domain/models/movement_session_event.dart';
import 'package:ritmo/features/movement/domain/models/movement_workout_log.dart';
import 'package:ritmo/features/movement/presentation/session/sheets/pain_report_sheet.dart';
import 'package:ritmo/features/movement/presentation/session/widgets/lap_button.dart';

/// کنترلر و ماشین حالت ۸ حالتهٔ جلسهٔ زندهٔ ورزشی
class MovementLiveSessionController extends ChangeNotifier {
  MovementLiveSessionController({
    required this.sessionService,
    required this.activityKind,
    this.occurrenceId,
    String? initialMode,
    Map<String, dynamic>? targetSnapshot,
    MovementLiveSession? existingSession,
  }) {
    _mode = initialMode ?? _deriveDefaultMode(activityKind);
    _targetSnapshot = targetSnapshot;
    _session = existingSession;
  }

  final MovementSessionService sessionService;
  final MovementActivityKind activityKind;
  final String? occurrenceId;
  Map<String, dynamic>? _targetSnapshot;

  MovementLiveSession? _session;
  MovementLiveSession? get session => _session;
  String get sessionId => _session?.id ?? '';

  late String _mode;
  String get mode => _mode;

  MovementLiveSessionStatus _status = MovementLiveSessionStatus.preparing;
  MovementLiveSessionStatus get status => _status;

  Timer? _ticker;
  int _elapsedSeconds = 0;
  int get elapsedSeconds => _elapsedSeconds;

  bool get isPaused => _status == MovementLiveSessionStatus.paused;
  bool get isActive => _status == MovementLiveSessionStatus.active;

  // وضعیت‌های اختصاصی مدها
  double _distanceKm = 0.0;
  double get distanceKm => _distanceKm;

  final List<SessionLapItem> _laps = [];
  List<SessionLapItem> get laps => List.unmodifiable(_laps);

  int _currentCount = 0;
  int get currentCount => _currentCount;

  int _currentSet = 1;
  int get currentSet => _currentSet;

  int? _totalSets;
  int? get totalSets => _totalSets;

  int? _targetCount;
  int? get targetCount => _targetCount;

  int _selectedIntensity = 3;
  int get selectedIntensity => _selectedIntensity;

  String _sessionNote = '';
  String get sessionNote => _sessionNote;

  final List<PainReportData> _painReports = [];
  List<PainReportData> get painReports => List.unmodifiable(_painReports);

  // صف رویدادهای در انتظار ذخیره (Pending Saves)
  final List<MovementSessionEvent> _pendingEvents = [];
  int get pendingEventsCount => _pendingEvents.length;

  MovementWorkoutLog? _completedLog;
  MovementWorkoutLog? get completedLog => _completedLog;

  double get progressRatio {
    if (_targetSnapshot == null) return 1.0;
    final targetValue = (_targetSnapshot!['value'] as num?)?.toDouble() ?? 0.0;
    if (targetValue <= 0) return 1.0;

    switch (_mode) {
      case 'time':
        return (_elapsedSeconds / (targetValue * 60)).clamp(0.0, 1.0);
      case 'distance':
        return (_distanceKm / targetValue).clamp(0.0, 1.0);
      case 'count':
        return (_currentCount / targetValue).clamp(0.0, 1.0);
      case 'lap':
        return (_laps.length / targetValue).clamp(0.0, 1.0);
      default:
        return 1.0;
    }
  }

  static String _deriveDefaultMode(MovementActivityKind kind) {
    switch (kind.primaryMetric) {
      case 'distance':
        return 'distance';
      case 'count':
      case 'reps':
        return 'count';
      case 'strength':
        return 'strength';
      case 'lap':
        return 'lap';
      case 'free':
        return 'free';
      default:
        if (kind.id == 'kind_strength' || kind.family == 'strength') {
          return 'strength';
        }
        return 'time';
    }
  }

  /// مقداردهی اولیه یا بازیابی جلسه
  Future<void> initialize() async {
    if (_session != null) {
      _mode = _session!.mode;
      _status = _session!.status;
      _recalculateElapsed();
      if (_status == MovementLiveSessionStatus.active) {
        _startTicker();
      }
      await _hydrateStateFromEvents();
    } else {
      // ایجاد جلسهٔ جدید
      try {
        _session = await sessionService.startSession(
          occurrenceId: occurrenceId,
          activityKindId: activityKind.id,
          mode: _mode,
          targetSnapshot: _targetSnapshot,
        );
        _status = MovementLiveSessionStatus.active;
        _startTicker();

        MovementAnalyticsService.instance.logSessionStarted(
          mode: _mode,
          startSource: occurrenceId != null ? 'occurrence' : 'quick_start',
          hasOccurrence: occurrenceId != null,
        );
      } catch (e) {
        _status = MovementLiveSessionStatus.errorRecoverable;
      }
    }
    notifyListeners();
  }

  Future<void> _hydrateStateFromEvents() async {
    if (_session == null) return;
    try {
      final events = await sessionService.getEvents(_session!.id);
      for (final evt in events) {
        final payload = evt.payloadMap;
        if (payload == null) continue;

        switch (evt.type) {
          case MovementSessionEventType.lap:
            _laps.add(
              SessionLapItem(
                lapNumber: payload['lapNumber'] as int? ?? (_laps.length + 1),
                durationSec: payload['durationSec'] as int? ?? 0,
                splitTimeSec: payload['splitTimeSec'] as int? ?? 0,
              ),
            );
            break;
          case MovementSessionEventType.count:
            _currentCount = payload['count'] as int? ?? _currentCount;
            _currentSet = payload['set'] as int? ?? _currentSet;
            break;
          case MovementSessionEventType.distance:
            _distanceKm =
                (payload['distanceKm'] as num?)?.toDouble() ?? _distanceKm;
            break;
          case MovementSessionEventType.intensity:
            _selectedIntensity = payload['level'] as int? ?? _selectedIntensity;
            break;
          case MovementSessionEventType.note:
            _sessionNote = payload['note'] as String? ?? _sessionNote;
            break;
          default:
            break;
        }
      }
    } catch (_) {}
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_status == MovementLiveSessionStatus.active) {
        _recalculateElapsed();
        notifyListeners();
      }
    });
  }

  void _recalculateElapsed() {
    if (_session != null) {
      _elapsedSeconds = _session!.elapsedSeconds;
    }
  }

  // ---------------------------------------------------------------------------
  // کنترل وضعیت و اعمال کاربر
  // ---------------------------------------------------------------------------

  /// تغییر وضعیت Pause / Resume
  Future<void> togglePause() async {
    if (_session == null) return;

    if (_status == MovementLiveSessionStatus.active) {
      _status = MovementLiveSessionStatus.paused;
      _ticker?.cancel();
      notifyListeners();
      await _safeRecordEvent(MovementSessionEventType.pause);
      try {
        await sessionService.pauseSession(_session!.id);
      } catch (_) {
        _status = MovementLiveSessionStatus.errorRecoverable;
        notifyListeners();
      }
    } else if (_status == MovementLiveSessionStatus.paused) {
      _status = MovementLiveSessionStatus.active;
      _startTicker();
      notifyListeners();
      await _safeRecordEvent(MovementSessionEventType.resume);
      MovementAnalyticsService.instance.logSessionResumed(
        mode: _mode,
        pauseDurationSec: 0,
      );
      try {
        await sessionService.resumeSession(_session!.id);
        _session = await sessionService.getSessionById(_session!.id);
      } catch (_) {
        _status = MovementLiveSessionStatus.errorRecoverable;
        notifyListeners();
      }
    }
  }

  /// تغییر مد جلسه بدون از دست رفتن داده‌های دیگر
  void setMode(String newMode) {
    if (_mode == newMode) return;
    _mode = newMode;
    notifyListeners();
    _safeRecordEvent(
      MovementSessionEventType.goalChange,
      payload: {'newMode': newMode},
    );
  }

  /// ثبت دور جدید در مد Lap
  void recordLap(SessionLapItem lap) {
    _laps.add(lap);
    notifyListeners();
    _safeRecordEvent(
      MovementSessionEventType.lap,
      payload: {
        'lapNumber': lap.lapNumber,
        'durationSec': lap.durationSec,
        'splitTimeSec': lap.splitTimeSec,
      },
    );
  }

  /// حذف آخرین دور در مد Lap
  void undoLap() {
    if (_laps.isNotEmpty) {
      final removed = _laps.removeLast();
      notifyListeners();
      _safeRecordEvent(
        MovementSessionEventType.lap,
        payload: {'action': 'undo', 'lapNumber': removed.lapNumber},
      );
    }
  }

  /// به‌روزرسانی شمارش تکرار در مد Count
  void updateCount(int count) {
    _currentCount = count;
    notifyListeners();
    _safeRecordEvent(
      MovementSessionEventType.count,
      payload: {'count': count, 'set': _currentSet},
    );
  }

  /// به‌روزرسانی مسافت در مد Distance
  void updateDistance(double km) {
    _distanceKm = km;
    notifyListeners();
    _safeRecordEvent(
      MovementSessionEventType.distance,
      payload: {'distanceKm': km},
    );
  }

  /// به‌روزرسانی شدت تمرین
  void updateIntensity(int intensity) {
    _selectedIntensity = intensity;
    notifyListeners();
    _safeRecordEvent(
      MovementSessionEventType.intensity,
      payload: {'level': intensity},
    );
  }

  /// به‌روزرسانی یادداشت تمرین
  void updateNote(String note) {
    _sessionNote = note;
    notifyListeners();
    _safeRecordEvent(MovementSessionEventType.note, payload: {'note': note});
  }

  /// ثبت گزارش درد
  void reportPain(PainReportData pain) {
    _painReports.add(pain);
    notifyListeners();
    _safeRecordEvent(
      MovementSessionEventType.note,
      payload: {
        'painReport': true,
        'severity': pain.severity,
        'location': pain.location,
        'stopped': pain.shouldStopSession,
      },
    );

    if (pain.shouldStopSession) {
      finish();
    }
  }

  /// پایان کامل جلسه و ذخیرهٔ لاگ
  Future<MovementWorkoutLog?> finish({
    String? feeling,
    String? finalNote,
  }) async {
    if (_session == null) return null;

    _status = MovementLiveSessionStatus.finishing;
    _ticker?.cancel();
    notifyListeners();

    final metrics = <String, dynamic>{
      'mode': _mode,
      'elapsedSec': _elapsedSeconds,
    };

    if (_distanceKm > 0) metrics['distanceKm'] = _distanceKm;
    if (_laps.isNotEmpty) metrics['lapsCount'] = _laps.length;
    if (_currentCount > 0) metrics['count'] = _currentCount;
    if (_painReports.isNotEmpty) {
      metrics['hasPainReport'] = true;
      metrics['painSeverityMax'] = _painReports
          .map((p) => p.severity)
          .reduce((a, b) => a > b ? a : b);
    }

    try {
      final log = await sessionService.finishSession(
        _session!.id,
        feeling: feeling,
        note: finalNote ?? (_sessionNote.isNotEmpty ? _sessionNote : null),
        finalMetrics: metrics,
      );

      _completedLog = log;
      _status = MovementLiveSessionStatus.completed;

      final goalAchieved = _targetSnapshot != null
          ? progressRatio >= 1.0
          : true;
      MovementAnalyticsService.instance.logSessionCompleted(
        mode: _mode,
        durationSec: _elapsedSeconds,
        goalAchieved: goalAchieved,
      );

      notifyListeners();
      return log;
    } catch (e) {
      _status = MovementLiveSessionStatus.errorRecoverable;
      notifyListeners();
      return null;
    }
  }

  /// ثبت جلسهٔ نیمه‌تمام (Partial Session)
  Future<MovementWorkoutLog?> finishPartial({
    String? reason,
    String? feeling,
  }) async {
    final log = await finish(feeling: feeling);
    if (log != null) {
      MovementAnalyticsService.instance.logSessionPartial(
        mode: _mode,
        progressPct: (progressRatio * 100).clamp(0.0, 100.0),
        reason: reason,
      );
    }
    return log;
  }

  /// رهاسازی جلسه
  Future<void> abandon() async {
    if (_session == null) return;
    _status = MovementLiveSessionStatus.abandoned;
    _ticker?.cancel();
    notifyListeners();
    try {
      await sessionService.abandonSession(_session!.id);
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // رویدادمحور و صف خطای ذخیره‌سازی
  // ---------------------------------------------------------------------------

  Future<void> _safeRecordEvent(
    MovementSessionEventType type, {
    Map<String, dynamic>? payload,
  }) async {
    if (_session == null) return;

    final now = DateTime.now().toUtc();
    final event = MovementSessionEvent(
      id: 'evt_${now.millisecondsSinceEpoch}_${type.name}',
      sessionId: _session!.id,
      type: type,
      payloadJson: payload != null ? jsonEncode(payload) : null,
      at: now,
    );

    try {
      await sessionService.recordEvent(
        sessionId: _session!.id,
        type: type,
        payload: payload,
        at: now,
      );
    } catch (e) {
      _pendingEvents.add(event);
      _status = MovementLiveSessionStatus.errorRecoverable;
      notifyListeners();
    }
  }

  /// تلاش دوباره برای ذخیرهٔ رویدادهای معلق
  Future<void> retryPendingSaves() async {
    if (_session == null || _pendingEvents.isEmpty) return;

    final toRetry = [..._pendingEvents];
    _pendingEvents.clear();

    for (final evt in toRetry) {
      try {
        await sessionService.recordEvent(
          sessionId: evt.sessionId,
          type: evt.type,
          payload: evt.payloadMap,
          at: evt.at,
        );
      } catch (_) {
        _pendingEvents.add(evt);
      }
    }

    if (_pendingEvents.isEmpty &&
        _status == MovementLiveSessionStatus.errorRecoverable) {
      _status = isPaused
          ? MovementLiveSessionStatus.paused
          : MovementLiveSessionStatus.active;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
