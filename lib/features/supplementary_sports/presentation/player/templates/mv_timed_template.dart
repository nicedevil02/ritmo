import 'dart:async';
import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/ux/ritmo_haptics.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';
import 'package:ritmo/l10n/app_localizations.dart';

/// قالب پلیر برای ورزش‌های زمان‌محور (یوگا، پیلاتس، کشش، تنفس) (S4-T3)
class MvTimedTemplate extends StatefulWidget {
  final MvSession session;
  final MvMovementKind? kind;
  final void Function(int elapsedSeconds, int rpe1To10)? onFinish;

  const MvTimedTemplate({
    super.key,
    required this.session,
    this.kind,
    this.onFinish,
  });

  @override
  State<MvTimedTemplate> createState() => _MvTimedTemplateState();
}

class _MvTimedTemplateState extends State<MvTimedTemplate> {
  late int _seconds;
  late int _accumulatedSeconds;
  DateTime? _runningStart;
  bool _isPaused = false;
  Timer? _timer;
  int _currentPhaseIndex = 1; // 0: warmup, 1: main, 2: cooldown
  int _rpe = 6;

  @override
  void initState() {
    super.initState();
    _accumulatedSeconds = widget.session.elapsedSeconds;
    _seconds = _accumulatedSeconds;
    _runningStart = DateTime.now();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!_isPaused && _runningStart != null && mounted) {
        final elapsed = _accumulatedSeconds +
            DateTime.now().difference(_runningStart!).inSeconds;
        if (elapsed != _seconds) {
          setState(() => _seconds = elapsed);
        }
      }
    });
  }

  void _togglePause() {
    RitmoHaptics.tap();
    setState(() {
      if (!_isPaused) {
        // Pausing
        if (_runningStart != null) {
          _accumulatedSeconds +=
              DateTime.now().difference(_runningStart!).inSeconds;
          _runningStart = null;
        }
        _isPaused = true;
      } else {
        // Resuming
        _runningStart = DateTime.now();
        _isPaused = false;
      }
      _seconds = _accumulatedSeconds;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatDuration(int totalSec) {
    final m = totalSec ~/ 60;
    final s = totalSec % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final metrics = context.metrics;
    final l10n = AppLocalizations.of(context);

    final phases = [
      l10n?.mv_template_phase_warmup ?? 'Warm-up',
      l10n?.mv_template_phase_main ?? 'Main Workout',
      l10n?.mv_template_phase_cooldown ?? 'Cool-down',
    ];

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(metrics.spaceLg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                widget.kind?.titleFa ?? (l10n?.mv_template_timed_title ?? 'Timed Session'),
                style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: metrics.spaceMd),
              // Stopwatch
              Text(
                toPersianDigits(_formatDuration(_seconds)),
                style: textTheme.displayLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
              SizedBox(height: metrics.spaceLg),
              // Phase selector
              Wrap(
                spacing: metrics.spaceSm,
                children: List.generate(phases.length, (idx) {
                  final isSel = _currentPhaseIndex == idx;
                  return ChoiceChip(
                    label: Text(phases[idx]),
                    selected: isSel,
                    onSelected: (v) {
                      if (v) setState(() => _currentPhaseIndex = idx);
                    },
                  );
                }),
              ),
              SizedBox(height: metrics.spaceXl),
              // Effort slider
              Text(
                l10n?.mv_template_rpe_label(toPersianDigits(_rpe.toString())) ?? 'Effort (RPE: $_rpe)',
                style: textTheme.bodyMedium,
              ),
              Slider(
                value: _rpe.toDouble(),
                min: 1,
                max: 10,
                divisions: 9,
                label: _rpe.toString(),
                onChanged: (val) => setState(() => _rpe = val.round()),
              ),
              SizedBox(height: metrics.spaceXl),
              // Controls
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton.filledTonal(
                    iconSize: metrics.iconXl,
                    icon: Icon(
                      _isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                    ),
                    onPressed: _togglePause,
                  ),
                  SizedBox(width: metrics.spaceXl),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                        horizontal: metrics.spaceXl,
                        vertical: metrics.spaceMd,
                      ),
                    ),
                    icon: Icon(Icons.check_circle_rounded, size: metrics.iconMd),
                    label: Text(l10n?.mv_template_finish ?? 'Finish Session'),
                    onPressed: () {
                      RitmoHaptics.success();
                      final finalSeconds = _accumulatedSeconds +
                          (!_isPaused && _runningStart != null
                              ? DateTime.now().difference(_runningStart!).inSeconds
                              : 0);
                      widget.onFinish?.call(finalSeconds, _rpe);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
