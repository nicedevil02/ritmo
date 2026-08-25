import 'dart:async';
import 'dart:math' as math;
import 'package:ritmo/core/util/ritmo_date.dart';
import 'package:ritmo/features/study/data/study_active_session_dao.dart';
import 'package:ritmo/features/study/data/study_repository.dart';
import 'package:ritmo/features/study/domain/study_models.dart';
import 'package:uuid/uuid.dart';

class StudyTimerService {
  StudyTimerService({StudyActiveSessionDao? dao, StudyRepository? repo})
      : _dao = dao ?? StudyActiveSessionDao.instance,
        _repo = repo ?? StudyRepository.instance;

  static final StudyTimerService instance = StudyTimerService();

  final StudyActiveSessionDao _dao;
  final StudyRepository _repo;

  ActiveStudySessionState? _currentSession;
  Timer? _ticker;
  bool _isSaving = false;

  ActiveStudySessionState? get currentSession => _currentSession;
  bool get isRunning => _currentSession != null && !_currentSession!.isPaused;
  bool get hasActiveSession => _currentSession != null;

  final _controller = StreamController<ActiveStudySessionState?>.broadcast();
  Stream<ActiveStudySessionState?> get stream => _controller.stream;

  Future<void> init() async {
    _currentSession = await _dao.getActiveSession();
    if (_currentSession != null && !_currentSession!.isPaused) {
      _startTicker();
    }
    _controller.add(_currentSession);
  }

  Future<void> startSession({
    required String subjectId,
    String? topicId,
    StudyMode mode = StudyMode.learn,
    int? plannedMinutes,
    String pomodoroPhase = 'FOCUS',
    int pomodoroCycle = 1,
    int targetSeconds = 1500,
  }) async {
    if (subjectId.trim().isEmpty) return;

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final state = ActiveStudySessionState(
      id: 'singleton',
      subjectId: subjectId.trim(),
      topicId: topicId?.trim().isEmpty ?? true ? null : topicId?.trim(),
      mode: mode,
      startedAtMs: nowMs,
      accumulatedSeconds: 0,
      isPaused: false,
      plannedMinutes: plannedMinutes,
      pomodoroPhase: pomodoroPhase,
      pomodoroCycle: pomodoroCycle,
      targetSeconds: targetSeconds,
      createdAtMs: nowMs,
    );

    await _dao.saveActiveSession(state);
    _currentSession = state;
    _startTicker();
    _controller.add(_currentSession);
  }

  Future<void> switchPomodoroPhase({
    required String phase,
    int? nextCycle,
    int? targetSeconds,
  }) async {
    if (_currentSession == null) return;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final currentElapsed = _currentSession!.elapsedSeconds(nowMs);

    final updated = _currentSession!.copyWith(
      startedAtMs: nowMs,
      accumulatedSeconds: currentElapsed,
      pomodoroPhase: phase,
      pomodoroCycle: nextCycle ?? _currentSession!.pomodoroCycle,
      targetSeconds: targetSeconds ?? _currentSession!.targetSeconds,
      isPaused: false,
    );

    await _dao.saveActiveSession(updated);
    _currentSession = updated;
    _startTicker();
    _controller.add(_currentSession);
  }

  Future<void> pauseSession() async {
    if (_currentSession == null || _currentSession!.isPaused) return;

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final elapsedSec = _currentSession!.elapsedSeconds(nowMs);

    final updated = _currentSession!.copyWith(
      startedAtMs: nowMs,
      accumulatedSeconds: elapsedSec,
      isPaused: true,
    );

    await _dao.saveActiveSession(updated);
    _currentSession = updated;
    _ticker?.cancel();
    _controller.add(_currentSession);
  }

  Future<void> resumeSession() async {
    if (_currentSession == null || !_currentSession!.isPaused) return;

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final updated = _currentSession!.copyWith(
      startedAtMs: nowMs,
      isPaused: false,
    );

    await _dao.saveActiveSession(updated);
    _currentSession = updated;
    _startTicker();
    _controller.add(_currentSession);
  }

  Future<void> stopAndSaveSession({
    int? overrideDurationMinutes,
    int? quality,
    String? note,
    StudyMastery? newMastery,
    String? nextReviewDateIso,
    int? newReviewCount,
    int testsTotal = 0,
    int testsCorrect = 0,
    int testsWrong = 0,
    int testsEmpty = 0,
  }) async {
    if (_currentSession == null || _isSaving) return;
    _isSaving = true;

    try {
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final totalSec = _currentSession!.elapsedSeconds(nowMs);
      final rawMinutes = (totalSec / 60).round();
      final durationMinutes = overrideDurationMinutes ?? math.max(0, rawMinutes);

      final subjectId = _currentSession!.subjectId ?? '';
      if (subjectId.isNotEmpty) {
        final now = DateTime.now();
        final dateIso = RitmoDate.dayKey(now);
        final id = const Uuid().v4();

        final session = StudySession(
          id: id,
          subjectId: subjectId,
          topicId: _currentSession!.topicId,
          durationMinutes: durationMinutes,
          dateIso: dateIso,
          mode: _currentSession!.mode,
          source: 'TIMER',
          startedAtMs: _currentSession!.createdAtMs,
          endedAtMs: nowMs,
          quality: quality,
          note: note,
          testsTotal: testsTotal,
          testsCorrect: testsCorrect,
          testsWrong: testsWrong,
          testsEmpty: testsEmpty,
          createdAtMs: nowMs,
        );

        await _repo.recordSession(
          session,
          newMastery: newMastery,
          nextReviewDateIso: nextReviewDateIso,
          newReviewCount: newReviewCount,
        );
      }

      await cancelSession();
    } finally {
      _isSaving = false;
    }
  }

  Future<void> cancelSession() async {
    await _dao.clearActiveSession();
    _currentSession = null;
    _ticker?.cancel();
    _controller.add(null);
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_currentSession != null) {
        _controller.add(_currentSession!.copyWith());
      }
    });
  }

  void reset() {
    _ticker?.cancel();
    _currentSession = null;
    _controller.add(null);
  }

  void dispose() {
    _ticker?.cancel();
  }
}
