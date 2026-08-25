import 'dart:async';
import 'package:flutter/material.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/ux/ritmo_haptics.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';

/// قالب پلیر برای ورزش‌های مسیرمحور / کوهنوردی / تریل (S4-T3)
class MvRouteTemplate extends StatefulWidget {
  final MvSession session;
  final MvMovementKind? kind;
  final void Function({
    required int elapsedSeconds,
    required double distanceM,
    required double elevationGainM,
    required double packWeightKg,
    required int rpe1To10,
    int? routeId,
  })?
  onFinish;

  const MvRouteTemplate({
    super.key,
    required this.session,
    this.kind,
    this.onFinish,
  });

  @override
  State<MvRouteTemplate> createState() => _MvRouteTemplateState();
}

class _MvRouteTemplateState extends State<MvRouteTemplate> {
  int _seconds = 0;
  bool _isPaused = false;
  Timer? _timer;

  double _distanceKm = 5.0;
  double _elevationGainM = 400.0;
  double _packWeightKg = 4.0;
  int _rpe = 7;
  int? _selectedRouteId;

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
    final h = totalSec ~/ 3600;
    final m = (totalSec % 3600) ~/ 60;
    final s = totalSec % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
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
                widget.kind?.titleFa ?? 'جلسه مسیر و کوه',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
            const SizedBox(height: 8),
            // Stopwatch
            Text(
              toPersianDigits(_formatDuration(_seconds)),
              style: const TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 16),
            // Metrics grid
            Row(
              children: [
                Expanded(
                  child: _MetricCard(
                    title: 'مسافت',
                    value:
                        '${toPersianDigits(_distanceKm.toStringAsFixed(1))} ک‌م',
                    onAdd: () => setState(() => _distanceKm += 0.5),
                    onSub: () {
                      if (_distanceKm > 0.5) setState(() => _distanceKm -= 0.5);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MetricCard(
                    title: 'ارتفاع صعود',
                    value:
                        '${toPersianDigits(_elevationGainM.round().toString())} م',
                    onAdd: () => setState(() => _elevationGainM += 50),
                    onSub: () {
                      if (_elevationGainM > 50)
                        setState(() => _elevationGainM -= 50);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _MetricCard(
                    title: 'وزن کوله',
                    value:
                        '${toPersianDigits(_packWeightKg.toStringAsFixed(1))} ک‌گ',
                    onAdd: () => setState(() => _packWeightKg += 0.5),
                    onSub: () {
                      if (_packWeightKg > 0.5)
                        setState(() => _packWeightKg -= 0.5);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'مسیر',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        DropdownButton<int?>(
                          value: _selectedRouteId,
                          isExpanded: true,
                          underline: const SizedBox.shrink(),
                          items: const [
                            DropdownMenuItem(
                              value: null,
                              child: Text('مسیر آزاد'),
                            ),
                            DropdownMenuItem(
                              value: 1,
                              child: Text('توچال - شیرپلا'),
                            ),
                            DropdownMenuItem(
                              value: 2,
                              child: Text('دربند - اوسون'),
                            ),
                            DropdownMenuItem(
                              value: 3,
                              child: Text('کلکچال - پناهگاه'),
                            ),
                          ],
                          onChanged: (v) =>
                              setState(() => _selectedRouteId = v),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
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
                    widget.onFinish?.call(
                      elapsedSeconds: _seconds,
                      distanceM: _distanceKm * 1000.0,
                      elevationGainM: _elevationGainM,
                      packWeightKg: _packWeightKg,
                      rpe1To10: _rpe,
                      routeId: _selectedRouteId,
                    );
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

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final VoidCallback onAdd;
  final VoidCallback onSub;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.onAdd,
    required this.onSub,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              InkWell(
                onTap: () {
                  RitmoHaptics.tap();
                  onSub();
                },
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.remove, size: 16),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () {
                  RitmoHaptics.tap();
                  onAdd();
                },
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.add, size: 16),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
