import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/movement/presentation/common/movement_layout.dart';

/// نوار تایمر استراحت بین ست‌ها با ارتفاع استاندارد kRestTimerBarHeight
class RestTimerBar extends StatefulWidget {
  const RestTimerBar({
    super.key,
    required this.initialSeconds,
    required this.onFinish,
    required this.onSkip,
  });

  final int initialSeconds;
  final VoidCallback onFinish;
  final VoidCallback onSkip;

  @override
  State<RestTimerBar> createState() => _RestTimerBarState();
}

class _RestTimerBarState extends State<RestTimerBar> {
  late int _remainingSeconds;
  late int _totalSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.initialSeconds;
    _totalSeconds = widget.initialSeconds;
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_remainingSeconds > 1) {
        if (mounted) {
          setState(() => _remainingSeconds--);
        }
      } else {
        _timer?.cancel();
        _onTimerCompleted();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _onTimerCompleted() {
    // دو ضربهٔ کوتاه هپتیک در پایان استراحت
    unawaited(HapticFeedback.mediumImpact());
    Future.delayed(const Duration(milliseconds: 150), () {
      unawaited(HapticFeedback.mediumImpact());
    });
    widget.onFinish();
  }

  void _addFifteenSeconds() {
    setState(() {
      _remainingSeconds += 15;
      _totalSeconds += 15;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final sportsColor = context.modules.sports;

    final progress = _totalSeconds > 0
        ? (_remainingSeconds / _totalSeconds).clamp(0.0, 1.0)
        : 0.0;
    final mins = _remainingSeconds ~/ 60;
    final secs = _remainingSeconds % 60;
    final timeStr =
        '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';

    return Container(
      height: MovementLayout.kRestTimerBarHeight,
      margin: const EdgeInsets.symmetric(
        horizontal: RitmoSpacing.md,
        vertical: RitmoSpacing.xs,
      ),
      padding: const EdgeInsets.symmetric(horizontal: RitmoSpacing.md),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(RitmoRadius.card),
        border: Border.all(
          color: sportsColor.withValues(alpha: 0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: sportsColor.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // آیکون استراحت و پیشرفت
          SizedBox(
            width: 28,
            height: 28,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 3,
                  backgroundColor: colors.surfaceSunken,
                  valueColor: AlwaysStoppedAnimation<Color>(sportsColor),
                ),
                Icon(Icons.timer_outlined, size: 14, color: sportsColor),
              ],
            ),
          ),
          const SizedBox(width: RitmoSpacing.sm),

          // متن زمان باقی‌مانده
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'استراحت',
                style: RitmoTextStyles.caption(colors.textSecondary),
              ),
              Text(
                toPersianDigits(timeStr),
                style: RitmoTextStyles.label(sportsColor).copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          const Spacer(),

          // دکمه افزودن ۱۵ ثانیه
          TextButton(
            onPressed: _addFifteenSeconds,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(48, 36),
            ),
            child: Text(
              '+۱۵ ثانیه',
              style: RitmoTextStyles.caption(
                sportsColor,
              ).copyWith(fontWeight: FontWeight.bold),
            ),
          ),

          // دکمه رد کردن
          TextButton(
            onPressed: () {
              _timer?.cancel();
              widget.onSkip();
            },
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(48, 36),
            ),
            child: Text(
              'رد کردن',
              style: RitmoTextStyles.caption(colors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
