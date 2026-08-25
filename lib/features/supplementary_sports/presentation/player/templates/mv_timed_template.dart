import 'dart:async';
import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/ux/ritmo_haptics.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';

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
  bool _isPaused = false;
  Timer? _timer;
  String _currentPhase = 'تمرین اصلی';
  int _rpe = 6;

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
                widget.kind?.titleFa ?? 'جلسه زمانی',
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
                children: ['گرم کردن', 'تمرین اصلی', 'سرد کردن'].map((phase) {
                  final isSel = _currentPhase == phase;
                  return ChoiceChip(
                    label: Text(phase),
                    selected: isSel,
                    onSelected: (v) {
                      if (v) setState(() => _currentPhase = phase);
                    },
                  );
                }).toList(),
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
                      widget.onFinish?.call(_seconds, _rpe);
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
