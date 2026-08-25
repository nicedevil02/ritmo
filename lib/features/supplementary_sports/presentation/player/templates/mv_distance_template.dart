import 'dart:async';
import 'package:flutter/material.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/ux/ritmo_haptics.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';

/// قالب پلیر برای ورزش‌های مسافت‌محور (دویدن، دوچرخه، پیاده‌روی تند) (S4-T3)
class MvDistanceTemplate extends StatefulWidget {
  final MvSession session;
  final MvMovementKind? kind;
  final void Function(int elapsedSeconds, double distanceM, int rpe1To10)?
  onFinish;

  const MvDistanceTemplate({
    super.key,
    required this.session,
    this.kind,
    this.onFinish,
  });

  @override
  State<MvDistanceTemplate> createState() => _MvDistanceTemplateState();
}

class _MvDistanceTemplateState extends State<MvDistanceTemplate> {
  int _seconds = 0;
  bool _isPaused = false;
  Timer? _timer;
  double _distanceKm = 3.0; // in km
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
                widget.kind?.titleFa ?? 'جلسه مسافتی',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              // Distance hero display
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    toPersianDigits(_distanceKm.toStringAsFixed(2)),
                    style: const TextStyle(
                      fontSize: 56,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'کیلومتر',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
              // Stopwatch
              Text(
                toPersianDigits(_formatDuration(_seconds)),
                style: const TextStyle(
                  fontSize: 24,
                  color: Colors.grey,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              // Distance adjuster (+ / -)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton.outlined(
                    icon: const Icon(Icons.remove),
                    onPressed: () {
                      if (_distanceKm > 0.5) {
                        RitmoHaptics.tap();
                        setState(() => _distanceKm = (_distanceKm - 0.5));
                      }
                    },
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    'تنظیم مسافت',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 16),
                  IconButton.outlined(
                    icon: const Icon(Icons.add),
                    onPressed: () {
                      RitmoHaptics.tap();
                      setState(() => _distanceKm = (_distanceKm + 0.5));
                    },
                  ),
                ],
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
              const SizedBox(height: 20),
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
                      final distanceMeters = _distanceKm * 1000.0;
                      widget.onFinish?.call(_seconds, distanceMeters, _rpe);
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
