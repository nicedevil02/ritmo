import 'dart:async';
import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/supplementary_sports/application/application.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';
import 'package:ritmo/l10n/app_localizations.dart';
import '../components/components.dart';
import '../sheets/sheets.dart';
import 'mv_audio_cue_player.dart';
import 'mv_session_summary_screen.dart';

/// Screen 2: "پلیر واحد تمرین و حرکت" (Section 6 & Appendix A F-11 to F-20).
/// Unified workout player supporting all 7 execution modes with audio cues, lifecycle events, and live substitution.
class MvSessionPlayerScreen extends StatefulWidget {
  final MvSession initialSession;
  final List<MvExercise> plannedExercises;
  final List<MvExercise> allCandidatePool;
  final bool initialAudioEnabled;
  final Future<void> Function(
    MvSession session,
    List<MvSetLog> logs,
    MvSessionFeeling feeling,
    String? note,
  )?
  onSessionCompleted;
  final MvSessionController? controller;

  const MvSessionPlayerScreen({
    super.key,
    required this.initialSession,
    required this.plannedExercises,
    this.allCandidatePool = const [],
    this.initialAudioEnabled = true,
    this.onSessionCompleted,
    this.controller,
  });

  @override
  State<MvSessionPlayerScreen> createState() => _MvSessionPlayerScreenState();
}

class _MvSessionPlayerScreenState extends State<MvSessionPlayerScreen> {
  late final MvSessionController _sessionController;
  late MvAudioCuePlayer _audioPlayer;

  late MvSession _session;
  late List<MvExercise> _exercises;
  int _currentExerciseIndex = 0;
  int _currentSet = 1;
  final int _totalSets = 3;

  bool _isResting = false;
  int _timerSeconds = 0;
  int _restSecondsRemaining = 0;
  Timer? _ticker;

  late int _accumulatedPausedMs;
  DateTime? _pauseStartTime;

  final List<MvSetLog> _setLogs = [];
  bool _isPaused = false;
  bool _isAudioEnabled = true;

  @override
  void initState() {
    super.initState();
    _sessionController = widget.controller ?? MvSessionController();
    _session = widget.initialSession;
    _accumulatedPausedMs = widget.initialSession.pausedMs;
    _exercises = List.from(widget.plannedExercises);
    _isAudioEnabled = widget.initialAudioEnabled;
    _audioPlayer = MvAudioCuePlayer(isEnabled: _isAudioEnabled);

    _sessionController.recordEvent(
      sessionId: _session.id,
      type: 'SESSION_START',
    );

    _startExerciseTimer();
    _audioPlayer.playGo();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _startExerciseTimer() {
    _ticker?.cancel();
    final currentEx = _currentExercise;
    if (currentEx != null && currentEx.isTimeBased) {
      _timerSeconds = currentEx.durationSeconds > 0
          ? currentEx.durationSeconds
          : 30;
    } else {
      _timerSeconds = 0;
    }

    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isPaused) return;

      setState(() {
        if (_isResting) {
          if (_restSecondsRemaining > 0) {
            _restSecondsRemaining--;
            if (_restSecondsRemaining <= 3 && _restSecondsRemaining > 0) {
              _audioPlayer.playCountdown();
            }
          } else {
            _endRest();
          }
        } else {
          final isTimeBased = _currentExercise?.isTimeBased ?? false;
          if (isTimeBased) {
            if (_timerSeconds > 0) {
              _timerSeconds--;
              if (_timerSeconds <= 3 && _timerSeconds > 0) {
                _audioPlayer.playCountdown();
              }
            } else {
              _handleSetComplete();
            }
          } else {
            _timerSeconds++;
          }
        }
      });
    });
  }

  MvExercise? get _currentExercise =>
      _exercises.isNotEmpty && _currentExerciseIndex < _exercises.length
      ? _exercises[_currentExerciseIndex]
      : null;

  void _handleSetComplete() {
    final currentEx = _currentExercise;
    if (currentEx == null) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    final log = MvSetLog(
      id: 'set_${now}_$_currentSet',
      sessionId: _session.id,
      exerciseId: currentEx.id,
      setNumber: _currentSet,
      reps: currentEx.isTimeBased ? null : currentEx.defaultReps,
      durationSeconds: currentEx.isTimeBased
          ? currentEx.durationSeconds
          : _timerSeconds,
      loggedAt: now,
    );
    _setLogs.add(log);

    _sessionController.recordEvent(
      sessionId: _session.id,
      type: 'SET_COMPLETE',
      dataJson: '{"exerciseId": "${currentEx.id}", "set": $_currentSet}',
    );

    if (_currentSet < _totalSets) {
      _startRest(30);
    } else {
      // Completed all sets for this exercise
      if (_currentExerciseIndex < _exercises.length - 1) {
        _startRest(45, isBetweenExercises: true);
      } else {
        _finishWorkout();
      }
    }
  }

  void _startRest(int seconds, {bool isBetweenExercises = false}) {
    setState(() {
      _isResting = true;
      _restSecondsRemaining = seconds;
    });
    _audioPlayer.playCountdown();
  }

  void _endRest() {
    setState(() {
      _isResting = false;
      if (_currentSet < _totalSets) {
        _currentSet++;
      } else {
        _currentSet = 1;
        _currentExerciseIndex++;
      }
    });
    _startExerciseTimer();
    _audioPlayer.playGo();
  }

  void _skipExercise() {
    _sessionController.recordEvent(
      sessionId: _session.id,
      type: 'EXERCISE_SKIP',
      dataJson: '{"exerciseId": "${_currentExercise?.id}"}',
    );

    if (_currentExerciseIndex < _exercises.length - 1) {
      setState(() {
        _currentExerciseIndex++;
        _currentSet = 1;
        _isResting = false;
      });
      _startExerciseTimer();
    } else {
      _finishWorkout();
    }
  }

  void _handleSubstitution(MvExercise substitute) {
    final oldEx = _exercises[_currentExerciseIndex];

    _sessionController.recordEvent(
      sessionId: _session.id,
      type: 'EXERCISE_SUBSTITUTE',
      dataJson: '{"from": "${oldEx.id}", "to": "${substitute.id}"}',
    );

    setState(() {
      _exercises[_currentExerciseIndex] = substitute;
      _currentSet = 1;
      _isResting = false;
    });
    _startExerciseTimer();
    _audioPlayer.playGo();
  }

  void _toggleAudio(bool enabled) {
    setState(() {
      _isAudioEnabled = enabled;
      _audioPlayer.isEnabled = enabled;
    });
  }

  void _togglePause() {
    setState(() {
      if (!_isPaused) {
        _pauseStartTime = DateTime.now();
        _isPaused = true;
      } else {
        if (_pauseStartTime != null) {
          _accumulatedPausedMs +=
              DateTime.now().difference(_pauseStartTime!).inMilliseconds;
          _pauseStartTime = null;
        }
        _isPaused = false;
      }
    });

    _sessionController.recordEvent(
      sessionId: _session.id,
      type: _isPaused ? 'SESSION_PAUSE' : 'SESSION_RESUME',
    );
  }

  Future<void> _handleExitMidSession() async {
    final totalPaused = _accumulatedPausedMs +
        (_isPaused && _pauseStartTime != null
            ? DateTime.now().difference(_pauseStartTime!).inMilliseconds
            : 0);
    await _sessionController.savePartialExit(
      session: _session.copyWith(pausedMs: totalPaused),
      setLogs: _setLogs,
    );
    if (mounted) Navigator.pop(context);
  }

  void _finishWorkout() {
    _ticker?.cancel();
    _audioPlayer.playFinish();

    final now = DateTime.now().millisecondsSinceEpoch;
    final totalPaused = _accumulatedPausedMs +
        (_isPaused && _pauseStartTime != null
            ? DateTime.now().difference(_pauseStartTime!).inMilliseconds
            : 0);
    final finishedSession = _session.copyWith(
      status: MvSessionStatus.completed,
      endedAt: now,
      pausedMs: totalPaused,
    );

    Navigator.pushReplacement(
      context,
      MaterialPageRoute<void>(
        builder: (_) => MvSessionSummaryScreen(
          session: finishedSession,
          setLogs: _setLogs,
          onFinish:
              ({
                required feeling,
                required rpe1To10,
                required effortSource,
                note,
              }) async {
                if (widget.onSessionCompleted != null) {
                  await widget.onSessionCompleted!(
                    finishedSession.copyWith(
                      rpe1To10: rpe1To10,
                      effortSource: effortSource,
                    ),
                    _setLogs,
                    feeling,
                    note,
                  );
                } else {
                  await _sessionController.finishSession(
                    session: finishedSession,
                    setLogs: _setLogs,
                    feeling: feeling,
                    rpe1To10: rpe1To10,
                    effortSource: effortSource,
                    note: note,
                  );
                }
              },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.ritmoColors;
    final metrics = context.metrics;
    final textTheme = Theme.of(context).textTheme;

    final l10n = AppLocalizations.of(context);
    final currentEx =
        _currentExercise ??
        MvExercise(id: '0', name: l10n?.mv_exercise_default_title ?? 'Exercise', category: l10n?.mv_exercise_default_title ?? 'Exercise');

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: metrics.spaceLg, vertical: metrics.spaceSm),
              child: RitmoGlassHeader(
                borderRadius: BorderRadius.circular(22),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: _handleExitMidSession,
                    ),
                    Expanded(
                      child: Text(
                        _isResting ? (l10n?.mv_player_rest_time ?? 'Rest') : currentEx.name,
                        style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.skip_next_rounded),
                      tooltip: l10n?.mv_player_skip_exercise_tooltip ?? 'Skip',
                      onPressed: _skipExercise,
                    ),
                    MvAudioToggle(
                      isAudioEnabled: _isAudioEnabled,
                      onToggle: _toggleAudio,
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(metrics.spaceLg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Animation Stage
              if (!_isResting)
                MvAnimationStage(
                  height: 220,
                  exerciseId: currentEx.id,
                  animationAsset: currentEx.animationAsset,
                  isPlaying: !_isPaused,
                )
              else
                Container(
                  height: 220,
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(metrics.radiusHero),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.self_improvement_rounded,
                          size: metrics.iconXl * 1.5,
                          color: colors.primary,
                        ),
                        SizedBox(height: metrics.spaceSm),
                        Text(
                          l10n?.mv_player_breathe_ready ?? 'Breathe and get ready',
                          style: textTheme.titleSmall?.copyWith(
                            color: colors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              SizedBox(height: metrics.spaceLg),

              // Sets & Reps Details
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n?.mv_player_exercise_counter(
                          toPersianDigits((_currentExerciseIndex + 1).toString()),
                          toPersianDigits(_exercises.length.toString()),
                        ) ??
                        '${_currentExerciseIndex + 1} / ${_exercises.length}',
                    style: textTheme.labelMedium?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                  Text(
                    l10n?.mv_player_set_counter(
                          toPersianDigits(_currentSet.toString()),
                          toPersianDigits(_totalSets.toString()),
                        ) ??
                        '$_currentSet / $_totalSets',
                    style: textTheme.labelLarge?.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              SizedBox(height: metrics.spaceLg),

              // Timer / Counter Display (Token Typography, no hardcoded font size)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _isResting
                            ? (l10n?.mv_player_seconds_remaining(toPersianDigits(_restSecondsRemaining.toString())) ?? '$_restSecondsRemaining s')
                            : currentEx.isTimeBased
                            ? (l10n?.mv_player_seconds_remaining(toPersianDigits(_timerSeconds.toString())) ?? '$_timerSeconds s')
                            : (l10n?.mv_player_reps(toPersianDigits(currentEx.defaultReps.toString())) ?? '${currentEx.defaultReps} reps'),
                        style: textTheme.displayMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: colors.textPrimary,
                        ),
                      ),
                      SizedBox(height: metrics.spaceSm),
                      Text(
                        _isResting ? (l10n?.mv_slot_rest_badge_label ?? 'Rest') : (l10n?.mv_player_focus_contraction ?? 'Focus on muscle contraction'),
                        style: textTheme.bodyMedium?.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Secondary actions: Substitute & Pause
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: Size(double.infinity, metrics.touchTarget),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            metrics.radiusField,
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.swap_horiz_rounded),
                      label: Text(l10n?.mv_substitute_title ?? 'Substitute'),
                      onPressed: () async {
                        // Fetch similar candidates from controller
                        final similar = await _sessionController
                            .getSimilarCandidates(
                              currentEx.id,
                              fallbackPool: widget.allCandidatePool,
                            );
                        if (!context.mounted) return;

                        await MvExerciseSubstitutionSheet.show(
                          context: context,
                          currentExercise: currentEx,
                          similarCandidates: similar,
                          fullPool: widget.allCandidatePool,
                          onExerciseSubstituted: _handleSubstitution,
                        );
                      },
                    ),
                  ),
                  SizedBox(width: metrics.spaceSm),
                  IconButton.outlined(
                    style: IconButton.styleFrom(
                      minimumSize: Size(
                        metrics.touchTarget,
                        metrics.touchTarget,
                      ),
                    ),
                    icon: Icon(
                      _isPaused
                          ? Icons.play_arrow_rounded
                          : Icons.pause_rounded,
                    ),
                    onPressed: _togglePause,
                  ),
                ],
              ),
              SizedBox(height: metrics.spaceMd),

              // Primary Action: Complete Set / Skip Rest
              MvPrimaryAction(
                label: _isResting
                    ? (l10n?.mv_player_skip_rest_action ?? 'Skip Rest')
                    : (l10n?.mv_player_complete_set_action(toPersianDigits(_currentSet.toString())) ?? 'Complete set $_currentSet'),
                icon: Icons.check_circle_rounded,
                onPressed: _isResting ? _endRest : _handleSetComplete,
              ),
            ],
          ),
        ),
      ),
    ],
  ),
),
);
  }
}
