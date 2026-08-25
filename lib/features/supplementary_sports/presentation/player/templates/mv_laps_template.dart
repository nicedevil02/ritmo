import 'dart:async';
import 'package:flutter/material.dart';
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
  int _seconds = 0;
  bool _isPaused = false;
  Timer? _timer;
  int _laps = 0;
  int _rpe = 7;

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
                widget.kind?.titleFa ?? 'جلسه دورمحور',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              // Laps display
              Text(
                toPersianDigits(_laps.toString()),
                style: const TextStyle(fontSize: 72, fontWeight: FontWeight.w900),
              ),
              const Text(
                'دور ثبت‌شده',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 4),
              // Stopwatch
              Text(
                toPersianDigits(_formatDuration(_seconds)),
                style: const TextStyle(
                  fontSize: 22,
                  color: Colors.grey,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              // Big +1 Lap button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 28),
                  label: const Text(
                    '+۱ دور ثبت شد',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () {
                    RitmoHaptics.confirm();
                    setState(() => _laps++);
                  },
                ),
              ),
              const SizedBox(height: 20),
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
              const SizedBox(height: 16),
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
