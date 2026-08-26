import 'dart:async';
import 'package:flutter/material.dart';
import 'package:ritmo/core/domain/realm/schedule_bounds.dart';
import 'package:ritmo/core/utils/persian_digits.dart';

class RealmCountdownWidget extends StatefulWidget {
  const RealmCountdownWidget({
    super.key,
    required this.activeZone,
    required this.style,
  });

  final Map<String, dynamic> activeZone;
  final TextStyle style;

  @override
  State<RealmCountdownWidget> createState() => _RealmCountdownWidgetState();
}

class _RealmCountdownWidgetState extends State<RealmCountdownWidget>
    with WidgetsBindingObserver {
  Timer? _timer;
  late ValueNotifier<int> _remainingSeconds;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _remainingSeconds = ValueNotifier<int>(_calculateSecs());
    _scheduleNextTick();
  }

  int _calculateSecs() {
    final now = DateTime.now();

    // 1. Manual override
    if (widget.activeZone['isOverride'] == true) {
      final overrideUntilMs = widget.activeZone['overrideUntilMs'] as int? ?? 0;
      final diffMs = overrideUntilMs - now.millisecondsSinceEpoch;
      return diffMs > 0 ? (diffMs / 1000).ceil() : 0;
    }

    // 2. Schedule range — calculate using cross-midnight aware bounds (B-05)
    final startTimeStr = widget.activeZone['startTime'] as String? ?? '00:00';
    final endTimeStr = widget.activeZone['endTime'] as String?;
    if (endTimeStr == null) return 0;

    final bounds = calculateScheduleBounds(
      now: now,
      startTime: startTimeStr,
      endTime: endTimeStr,
    );

    final diff = bounds.endDt.difference(now).inSeconds;
    return diff > 0 ? diff : 0;
  }

  void _scheduleNextTick() {
    _timer?.cancel();
    final secs = _calculateSecs();
    _remainingSeconds.value = secs;

    if (secs <= 0) return;

    // B-14: Tick every 1 second when <= 60s remaining; otherwise every 60s
    if (secs <= 60) {
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        final currentSecs = _calculateSecs();
        _remainingSeconds.value = currentSecs;
        if (currentSecs <= 0) {
          _timer?.cancel();
          _timer = null;
        }
      });
    } else {
      // Align to next minute mark or at most 60s
      final nextDelaySecs = (secs % 60 == 0) ? 60 : (secs % 60);
      _timer = Timer(Duration(seconds: nextDelaySecs > 0 ? nextDelaySecs : 60), () {
        if (!mounted) return;
        _scheduleNextTick();
      });
    }
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _stopTimer();
    } else if (state == AppLifecycleState.resumed) {
      _scheduleNextTick();
    }
  }

  @override
  void didUpdateWidget(covariant RealmCountdownWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scheduleNextTick();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopTimer();
    _remainingSeconds.dispose();
    super.dispose();
  }

  String _formatDuration(int totalSeconds) {
    if (totalSeconds <= 0) return '۰۰:۰۰:۰۰';
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    final hStr = hours.toString().padLeft(2, '0');
    final mStr = minutes.toString().padLeft(2, '0');
    final sStr = seconds.toString().padLeft(2, '0');

    return toPersianDigits('$hStr:$mStr:$sStr');
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: ValueListenableBuilder<int>(
        valueListenable: _remainingSeconds,
        builder: (context, seconds, child) {
          return Text(
            'باقی‌مانده: ${_formatDuration(seconds)}',
            style: widget.style,
          );
        },
      ),
    );
  }
}
