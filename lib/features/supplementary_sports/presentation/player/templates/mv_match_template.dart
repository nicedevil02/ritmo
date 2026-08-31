import 'dart:async';
import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';
import 'package:ritmo/l10n/app_localizations.dart';

/// قالب پلیر برای بازی‌ها و مسابقات تیمی/راکتی (فوتبال، فوتسال، والیبال، پین‌پنگ) (S4-T3)
class MvMatchTemplate extends StatefulWidget {
  final MvSession session;
  final MvMovementKind? kind;
  final void Function(int elapsedSeconds, int rpe1To10, String? note)? onFinish;

  const MvMatchTemplate({
    super.key,
    required this.session,
    this.kind,
    this.onFinish,
  });

  @override
  State<MvMatchTemplate> createState() => _MvMatchTemplateState();
}

class _MvMatchTemplateState extends State<MvMatchTemplate> {
  late int _seconds;
  late int _accumulatedSeconds;
  DateTime? _runningStart;
  bool _isPaused = false;
  Timer? _timer;

  int _half = 1;
  int _teamScore = 0;
  int _opponentScore = 0;
  int _rpe = 8;
  final TextEditingController _noteController = TextEditingController();

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
    _noteController.dispose();
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
    final colors = context.ritmoColors;
    final metrics = context.metrics;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(metrics.spaceLg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                widget.kind?.titleFa ?? (l10n?.mv_template_match_title ?? 'Match & Game'),
                style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: metrics.spaceSm),
              // Half indicator
              Container(
                padding: EdgeInsets.symmetric(horizontal: metrics.spaceLg, vertical: metrics.spaceXs),
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(RitmoRadius.pill),
                ),
                child: Text(
                  _half == 1
                      ? (l10n?.mv_template_half_1 ?? 'First Half')
                      : (l10n?.mv_template_half_2 ?? 'Second Half'),
                  style: textTheme.labelMedium?.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SizedBox(height: metrics.spaceMd),
              // Scores and stopwatch
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _ScoreColumn(
                    label: l10n?.mv_template_team_us ?? 'Us',
                    score: _teamScore,
                    onAdd: () => setState(() => _teamScore++),
                    onSub: () {
                      if (_teamScore > 0) setState(() => _teamScore--);
                    },
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: metrics.spaceLg),
                    child: Column(
                      children: [
                        Text(
                          toPersianDigits(_formatDuration(_seconds)),
                          style: textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: metrics.spaceSm),
                        if (_half == 1)
                          OutlinedButton(
                            onPressed: () {
                              RitmoHaptics.tap();
                              setState(() => _half = 2);
                            },
                            child: Text(l10n?.mv_template_start_half_2 ?? 'Start Second Half'),
                          ),
                      ],
                    ),
                  ),
                  _ScoreColumn(
                    label: l10n?.mv_template_team_them ?? 'Them',
                    score: _opponentScore,
                    onAdd: () => setState(() => _opponentScore++),
                    onSub: () {
                      if (_opponentScore > 0) setState(() => _opponentScore--);
                    },
                  ),
                ],
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
              SizedBox(height: metrics.spaceMd),
              // Note field
              TextField(
                controller: _noteController,
                decoration: InputDecoration(
                  labelText: l10n?.mv_template_match_note_label ?? 'Match notes',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(metrics.radiusField),
                  ),
                  filled: true,
                  fillColor: colors.surfaceElevated,
                ),
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
                    label: Text(l10n?.mv_template_finish_match ?? 'Finish Match'),
                    onPressed: () {
                      RitmoHaptics.success();
                      final note = _noteController.text.trim();
                      final finalSeconds = _accumulatedSeconds +
                          (!_isPaused && _runningStart != null
                              ? DateTime.now().difference(_runningStart!).inSeconds
                              : 0);
                      widget.onFinish?.call(finalSeconds, _rpe, note.isEmpty ? null : note);
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

class _ScoreColumn extends StatelessWidget {
  final String label;
  final int score;
  final VoidCallback onAdd;
  final VoidCallback onSub;

  const _ScoreColumn({
    required this.label,
    required this.score,
    required this.onAdd,
    required this.onSub,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final metrics = context.metrics;

    return Column(
      children: [
        Text(
          label,
          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        SizedBox(height: metrics.spaceXs),
        Text(
          toPersianDigits(score.toString()),
          style: textTheme.displayMedium?.copyWith(fontWeight: FontWeight.w900),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.remove_circle_outline, size: metrics.iconMd),
              onPressed: () {
                RitmoHaptics.tap();
                onSub();
              },
            ),
            IconButton(
              icon: Icon(Icons.add_circle_outline, size: metrics.iconMd),
              onPressed: () {
                RitmoHaptics.tap();
                onAdd();
              },
            ),
          ],
        ),
      ],
    );
  }
}
