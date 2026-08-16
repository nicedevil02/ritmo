import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/movement/application/movement_session_service.dart';
import 'package:ritmo/features/movement/domain/models/movement_activity_kind.dart';
import 'package:ritmo/features/movement/domain/models/movement_live_session.dart';
import 'package:ritmo/features/movement/presentation/common/movement_screen_shell.dart';
import 'package:ritmo/features/movement/presentation/common/movement_strings.dart';
import 'package:ritmo/features/movement/presentation/movement_routes.dart';
import 'package:ritmo/features/movement/presentation/session/modes/count_session_view.dart';
import 'package:ritmo/features/movement/presentation/session/modes/distance_session_view.dart';
import 'package:ritmo/features/movement/presentation/session/modes/free_session_view.dart';
import 'package:ritmo/features/movement/presentation/session/modes/lap_session_view.dart';
import 'package:ritmo/features/movement/presentation/session/modes/time_session_view.dart';
import 'package:ritmo/features/movement/presentation/session/movement_live_session_controller.dart';
import 'package:ritmo/features/movement/presentation/session/session_shell.dart';
import 'package:ritmo/features/movement/presentation/session/sheets/pain_report_sheet.dart';
import 'package:ritmo/features/movement/presentation/session/sheets/pause_exit_sheet.dart';
import 'package:ritmo/features/movement/presentation/session/sheets/session_actions_sheet.dart';
import 'package:ritmo/features/movement/presentation/session/widgets/secondary_actions_row.dart';
import 'package:ritmo/features/movement/presentation/session/widgets/session_app_bar.dart';
import 'package:ritmo/features/movement/presentation/session/widgets/session_primary_cta.dart';
import 'package:ritmo/features/movement/presentation/session/widgets/session_status_strip.dart';

/// صفحهٔ کامل جلسهٔ زنده با پوستهٔ SessionShell و ۵ مد غیرقدرتی
class MovementLiveSessionScreen extends StatefulWidget {
  const MovementLiveSessionScreen({
    super.key,
    required this.activityKind,
    this.occurrenceId,
    this.mode,
    this.targetSnapshot,
    this.existingSession,
    this.sessionService,
    this.onCompleted,
  });

  final MovementActivityKind activityKind;
  final String? occurrenceId;
  final String? mode;
  final Map<String, dynamic>? targetSnapshot;
  final MovementLiveSession? existingSession;
  final MovementSessionService? sessionService;
  final ValueChanged<String>? onCompleted;

  @override
  State<MovementLiveSessionScreen> createState() => _MovementLiveSessionScreenState();
}

class _MovementLiveSessionScreenState extends State<MovementLiveSessionScreen> {
  late final MovementLiveSessionController _controller;
  final _freeNoteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final service = widget.sessionService ?? MovementSessionService();
    _controller = MovementLiveSessionController(
      sessionService: service,
      activityKind: widget.activityKind,
      occurrenceId: widget.occurrenceId,
      initialMode: widget.mode,
      targetSnapshot: widget.targetSnapshot,
      existingSession: widget.existingSession,
    );

    _controller.addListener(_onControllerUpdate);
    _controller.initialize();
  }

  void _onControllerUpdate() {
    if (_controller.status == MovementLiveSessionStatus.completed && mounted) {
      final log = _controller.completedLog;
      if (log != null) {
        if (widget.onCompleted != null) {
          widget.onCompleted!(log.id);
        } else {
          Navigator.of(context).pushReplacementNamed(
            MovementRoutes.summary,
            arguments: {
              'sessionId': _controller.session?.id,
              'log': log,
            },
          );
        }
      }
    } else if (_controller.status == MovementLiveSessionStatus.abandoned && mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerUpdate);
    _controller.dispose();
    _freeNoteController.dispose();
    super.dispose();
  }

  Future<void> _handleBackPressed() async {
    final action = await PauseExitSheet.show(context);
    if (!mounted || action == null) return;

    switch (action) {
      case PauseExitAction.pauseAndBack:
        if (_controller.isActive) {
          await _controller.togglePause();
        }
        if (mounted) Navigator.of(context).pop();
        break;
      case PauseExitAction.finish:
        await _controller.finish();
        break;
      case PauseExitAction.continueSession:
        if (_controller.isPaused) {
          await _controller.togglePause();
        }
        break;
    }
  }

  void _showMoreActions() {
    SessionActionsSheet.show(
      context,
      onEaseUp: () {
        // تغییر شدت به سبک‌تر
        if (_controller.selectedIntensity > 1) {
          _controller.updateIntensity(_controller.selectedIntensity - 1);
        }
      },
      onSwapMovement: () {
        // تغییر مد ورزشی
        final nextMode = _controller.mode == 'time' ? 'distance' : 'time';
        _controller.setMode(nextMode);
      },
      onPainReport: () async {
        final report = await PainReportSheet.show(context);
        if (report != null && mounted) {
          _controller.reportPain(report);
        }
      },
      onSkipStep: () {
        if (_controller.mode == 'lap') {
          _controller.undoLap();
        }
      },
      onStopSession: () {
        _controller.abandon();
      },
    );
  }

  Widget _buildModeContent() {
    switch (_controller.mode) {
      case 'distance':
        final targetDist = widget.targetSnapshot?['value'] is num
            ? (widget.targetSnapshot!['value'] as num).toDouble()
            : null;
        return DistanceSessionView(
          distanceKm: _controller.distanceKm,
          elapsedSeconds: _controller.elapsedSeconds,
          isPaused: _controller.isPaused,
          targetDistanceKm: targetDist,
          onDistanceChanged: _controller.updateDistance,
        );

      case 'lap':
        return LapSessionView(
          elapsedSeconds: _controller.elapsedSeconds,
          isPaused: _controller.isPaused,
          laps: _controller.laps,
          onLapRecorded: _controller.recordLap,
          onUndoLap: _controller.undoLap,
        );

      case 'count':
        final targetReps = widget.targetSnapshot?['reps'] as int? ??
            (widget.targetSnapshot?['value'] as num?)?.toInt();
        return CountSessionView(
          elapsedSeconds: _controller.elapsedSeconds,
          isPaused: _controller.isPaused,
          currentCount: _controller.currentCount,
          targetCount: targetReps,
          currentSet: _controller.currentSet,
          totalSets: _controller.totalSets,
          onCountChanged: _controller.updateCount,
        );

      case 'free':
        return FreeSessionView(
          elapsedSeconds: _controller.elapsedSeconds,
          isPaused: _controller.isPaused,
          selectedIntensity: _controller.selectedIntensity,
          onIntensityChanged: _controller.updateIntensity,
          noteController: _freeNoteController,
        );

      case 'time':
      default:
        final targetMin = widget.targetSnapshot?['durationMinutes'] as int? ??
            (widget.targetSnapshot?['value'] as num?)?.toInt();
        return TimeSessionView(
          elapsedSeconds: _controller.elapsedSeconds,
          isPaused: _controller.isPaused,
          targetDurationMinutes: targetMin,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final isFinishing = _controller.status == MovementLiveSessionStatus.finishing;

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            _handleBackPressed();
          },
          child: MovementScreenShell(
            title: widget.activityKind.nameFa,
            body: SessionShell(
              appBar: SessionAppBar(
                activityKind: widget.activityKind,
                elapsedSeconds: _controller.elapsedSeconds,
                isPaused: _controller.isPaused,
                onPauseToggle: _controller.togglePause,
                onMorePressed: _showMoreActions,
                onBackPressed: _handleBackPressed,
              ),
              status: SessionStatusStrip(
                status: _controller.status,
                pendingSavesCount: _controller.pendingEventsCount,
                onRetryPendingSaves: _controller.retryPendingSaves,
              ),
              content: _buildModeContent(),
              secondary: SecondaryActionsRow(
                leftAction: TextButton.icon(
                  onPressed: () async {
                    final report = await PainReportSheet.show(context);
                    if (report != null && mounted) {
                      _controller.reportPain(report);
                    }
                  },
                  icon: const Icon(Icons.healing_rounded, size: 18),
                  label: const Text(MovementStrings.sessionPainTitle),
                  style: TextButton.styleFrom(
                    foregroundColor: context.colors.warning,
                  ),
                ),
                rightAction: TextButton.icon(
                  onPressed: _showMoreActions,
                  icon: const Icon(Icons.tune_rounded, size: 18),
                  label: const Text('گزینه‌ها'),
                  style: TextButton.styleFrom(
                    foregroundColor: context.colors.textSecondary,
                  ),
                ),
              ),
              primary: SessionPrimaryCta(
                label: _controller.isPaused
                    ? MovementStrings.sessionResume
                    : MovementStrings.sessionFinish,
                icon: _controller.isPaused
                    ? Icons.play_arrow_rounded
                    : Icons.check_circle_outline_rounded,
                isLoading: isFinishing,
                onPressed: () {
                  if (_controller.isPaused) {
                    _controller.togglePause();
                  } else {
                    if (_controller.mode == 'free' && _freeNoteController.text.isNotEmpty) {
                      _controller.updateNote(_freeNoteController.text);
                    }
                    _controller.finish();
                  }
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
