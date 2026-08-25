import 'dart:async';
import 'package:flutter/material.dart';
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
  int _seconds = 0;
  bool _isPaused = false;
  Timer? _timer;
  String _currentPhase = 'تمرین اصلی';
  int _rpe = 6;

  @override
  void initState() {
    super.initState();
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
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                widget.kind?.titleFa ?? 'جلسه زمانی',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              // Stopwatch
              Text(
                toPersianDigits(_formatDuration(_seconds)),
                style: const TextStyle(
                  fontSize: 64,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 16),
              // Phase selector
              Wrap(
                spacing: 8,
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
              const SizedBox(height: 24),
              // Effort slider
              Text('میزان تلاش (RPE: ${toPersianDigits(_rpe.toString())})'),
              Slider(
                value: _rpe.toDouble(),
                min: 1,
                max: 10,
                divisions: 9,
                label: _rpe.toString(),
                onChanged: (val) => setState(() => _rpe = val.round()),
              ),
              const SizedBox(height: 24),
              // Controls
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton.filledTonal(
                    iconSize: 36,
                    icon: Icon(
                      _isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                    ),
                    onPressed: () {
                      RitmoHaptics.tap();
                      setState(() => _isPaused = !_isPaused);
                    },
                  ),
                  const SizedBox(width: 20),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 14,
                      ),
                    ),
                    icon: const Icon(Icons.check_circle_rounded),
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
