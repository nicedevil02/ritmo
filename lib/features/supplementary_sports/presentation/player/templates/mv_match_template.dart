import 'dart:async';
import 'package:flutter/material.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/ux/ritmo_haptics.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';

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
  int _seconds = 0;
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
    return Container(
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              widget.kind?.titleFa ?? 'مسابقه و بازی',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            // Half indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _half == 1 ? 'نیمه اول / ست اول' : 'نیمه دوم / ست دوم',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Scores and stopwatch
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _ScoreColumn(
                  label: 'ما',
                  score: _teamScore,
                  onAdd: () => setState(() => _teamScore++),
                  onSub: () {
                    if (_teamScore > 0) setState(() => _teamScore--);
                  },
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      Text(
                        toPersianDigits(_formatDuration(_seconds)),
                        style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 8),
                      if (_half == 1)
                        OutlinedButton(
                          onPressed: () {
                            RitmoHaptics.tap();
                            setState(() => _half = 2);
                          },
                          child: const Text('شروع نیمه دوم'),
                        ),
                    ],
                  ),
                ),
                _ScoreColumn(
                  label: 'حریف',
                  score: _opponentScore,
                  onAdd: () => setState(() => _opponentScore++),
                  onSub: () {
                    if (_opponentScore > 0) setState(() => _opponentScore--);
                  },
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
            const SizedBox(height: 12),
            // Free note field
            TextField(
              controller: _noteController,
              decoration: InputDecoration(
                labelText: 'یادداشت مسابقه (نتیجه، گل‌ها، حس بازی)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            // Controls
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton.filledTonal(
                  iconSize: 36,
                  icon: Icon(_isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded),
                  onPressed: () {
                    RitmoHaptics.tap();
                    setState(() => _isPaused = !_isPaused);
                  },
                ),
                const SizedBox(width: 20),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  ),
                  icon: const Icon(Icons.check_circle_rounded),
                  label: const Text('پایان مسابقه'),
                  onPressed: () {
                    RitmoHaptics.success();
                    widget.onFinish?.call(
                      _seconds,
                      _rpe,
                      _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
                    );
                  },
                ),
              ],
            ),
          ],
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
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(
          toPersianDigits(score.toString()),
          style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w900),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              onPressed: () {
                RitmoHaptics.tap();
                onSub();
              },
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
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
