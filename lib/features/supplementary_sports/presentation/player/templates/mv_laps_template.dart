import 'dart:async';
import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/ux/ritmo_haptics.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';

/// قالب پلیر برای ورزش‌های دور‌محور (شنا، دو پیست، پله‌نوردی) (S4-T3)
class MvLapsTemplate extends StatefulWidget {
  final MvSession session;
  final MvMovementKind? kind;
  final void Function(int elapsedSeconds, int laps, int rpe1To10)? onFinish;

  const MvLapsTemplate({
    super.key,
    required this.session,
    this.kind,
    this.onFinish,
  });

  @override
  State<MvLapsTemplate> createState() => _MvLapsTemplateState();
}

class _MvLapsTemplateState extends State<MvLapsTemplate> {
  late int _seconds;
  bool _isPaused = false;
  Timer? _timer;
  int _laps = 0;
  int _rpe = 7;

  @override
  void initState() {
    super.initState();
    _seconds = widget.session.elapsedSeconds;
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!_isPaused && mounted) {
        setState(() => _seconds++);
      }
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
    final colors = context.ritmoColors;
    final metrics = context.metrics;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(metrics.spaceLg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                widget.kind?.titleFa ?? 'جلسه دورمحور',
                style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: metrics.spaceSm),
              // Laps display
              Text(
                toPersianDigits(_laps.toString()),
                style: textTheme.displayLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              Text(
                'دور ثبت‌شده',
                style: textTheme.titleMedium?.copyWith(color: colors.textSecondary),
              ),
              SizedBox(height: metrics.spaceXs),
              // Stopwatch
              Text(
                toPersianDigits(_formatDuration(_seconds)),
                style: textTheme.headlineSmall?.copyWith(
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: metrics.spaceLg),
              // Big +1 Lap button
              SizedBox(
                width: double.infinity,
                height: metrics.rowHeight,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primary,
                    foregroundColor: colors.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(metrics.radiusCard),
                    ),
                  ),
                  icon: Icon(Icons.add_rounded, size: metrics.iconLg),
                  label: Text(
                    '+۱ دور ثبت شد',
                    style: textTheme.titleMedium?.copyWith(
                      color: colors.onPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onPressed: () {
                    RitmoHaptics.confirm();
                    setState(() => _laps++);
                  },
                ),
              ),
              SizedBox(height: metrics.spaceXl),
              // Effort slider
              Text('میزان تلاش (RPE: ${toPersianDigits(_rpe.toString())})', style: textTheme.bodyMedium),
              Slider(
                value: _rpe.toDouble(),
                min: 1,
                max: 10,
                divisions: 9,
                label: _rpe.toString(),
                onChanged: (val) => setState(() => _rpe = val.round()),
              ),
              SizedBox(height: metrics.spaceLg),
              // Controls
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton.filledTonal(
                    iconSize: metrics.iconXl,
                    icon: Icon(
                      _isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                    ),
                    onPressed: () {
                      RitmoHaptics.tap();
                      setState(() => _isPaused = !_isPaused);
                    },
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
                    label: const Text('پایان جلسه'),
                    onPressed: () {
                      RitmoHaptics.success();
                      widget.onFinish?.call(_seconds, _laps, _rpe);
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
