import 'dart:async';
import 'package:flutter/material.dart';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/models.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/calendar/presentation/utils/calendar_defaults.dart';
import 'package:ritmo/features/calendar/presentation/utils/domain_palette.dart';

class FocusBlockSheet extends StatefulWidget {
  const FocusBlockSheet({
    super.key,
    required this.item,
    required this.onComplete,
  });

  final AgendaItem item;
  final Future<void> Function({
    required String resultType,
    required int actualDurationMinutes,
  })
  onComplete;

  static Future<void> show({
    required BuildContext context,
    required AgendaItem item,
    required Future<void> Function({
      required String resultType,
      required int actualDurationMinutes,
    })
    onComplete,
  }) {
    RitmoHapticsPolicy.selection();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.60,
        minChildSize: 0.40,
        maxChildSize: 0.95,
        snap: true,
        snapSizes: const [0.60, 0.95],
        expand: false,
        builder: (context, scrollController) =>
            FocusBlockSheet(item: item, onComplete: onComplete),
      ),
    ).then((_) {
      RitmoHapticsPolicy.selection();
    });
  }

  @override
  State<FocusBlockSheet> createState() => _FocusBlockSheetState();
}

class _FocusBlockSheetState extends State<FocusBlockSheet> {
  late int _totalSeconds;
  late int _remainingSeconds;
  DateTime? _targetEndTime;
  Timer? _timer;
  bool _isRunning = false;

  @override
  void initState() {
    super.initState();
    final durMinutes =
        widget.item.durationMinutes ?? CalendarDefaults.fallbackDurationMinutes;
    _totalSeconds = durMinutes * 60;
    _remainingSeconds = _totalSeconds;
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _isRunning = true;
    _targetEndTime = DateTime.now().add(Duration(seconds: _remainingSeconds));
    RitmoHapticsPolicy.selection();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_targetEndTime != null) {
        final left = _targetEndTime!.difference(DateTime.now()).inSeconds;
        if (left > 0) {
          setState(() {
            _remainingSeconds = left.clamp(0, _totalSeconds);
          });
        } else {
          _timer?.cancel();
          _isRunning = false;
          _remainingSeconds = 0;
          RitmoHapticsPolicy.success();
          setState(() {});
        }
      }
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
    if (_targetEndTime != null) {
      _remainingSeconds = _targetEndTime!.difference(DateTime.now()).inSeconds.clamp(0, _totalSeconds);
    }
    _targetEndTime = null;
    _isRunning = false;
    RitmoHapticsPolicy.selection();
    setState(() {});
  }

  Future<void> _handleFullComplete() async {
    _timer?.cancel();
    RitmoHapticsPolicy.success();
    final elapsedMinutes = ((_totalSeconds - _remainingSeconds) / 60).ceil();
    final actual = elapsedMinutes > 0
        ? elapsedMinutes
        : (widget.item.durationMinutes ??
              CalendarDefaults.fallbackDurationMinutes);
    Navigator.of(context).pop();
    await widget.onComplete(
      resultType: OccurrenceResultType.full,
      actualDurationMinutes: actual,
    );
  }

  Future<void> _handlePartialComplete() async {
    _timer?.cancel();
    RitmoHapticsPolicy.selection();
    final elapsedMinutes = ((_totalSeconds - _remainingSeconds) / 60)
        .floor()
        .clamp(1, 1440);
    Navigator.of(context).pop();
    await widget.onComplete(
      resultType: OccurrenceResultType.partial,
      actualDurationMinutes: elapsedMinutes,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final accent = domainColor(context, widget.item.domain);

    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;
    final timeStr =
        '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    final persianTimeStr = toPersianDigits(timeStr);

    final progress = _totalSeconds > 0
        ? (1.0 - (_remainingSeconds / _totalSeconds)).clamp(0.0, 1.0)
        : 0.0;
    final isFinished = _remainingSeconds == 0;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(RitmoRadius.sheet),
          ),
        ),
        padding: const EdgeInsets.all(RitmoSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag Handle
            Center(
              child: Container(
                width: 38,
                height: 4.5,
                decoration: BoxDecoration(
                  color: colors.textPrimary.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.18 : 0.22),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: RitmoSpacing.md),

            // Header: Cancel + Item Title & Domain
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'انصراف',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: colors.textSecondary,
                    ),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: RitmoSpacing.sm),
                    Text(
                      widget.item.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: colors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 48), // Balancing spacer
              ],
            ),
            const SizedBox(height: RitmoSpacing.xxl),

            // Countdown Timer Dial
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 180,
                  height: 180,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 8,
                    backgroundColor: colors.borderSubtle.withValues(alpha: 0.3),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isFinished ? colors.success : accent,
                    ),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      persianTimeStr,
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isFinished
                          ? 'زمان تمرکز به پایان رسید!'
                          : (_isRunning ? 'در حال تمرکز...' : 'متوقف‌شده'),
                      style: TextStyle(
                        fontSize: 12,
                        color: isFinished
                            ? colors.success
                            : colors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: RitmoSpacing.xxl),

            // Play / Pause Control
            if (!isFinished)
              IconButton.filledTonal(
                iconSize: 32,
                icon: Icon(
                  _isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
                ),
                onPressed: _isRunning ? _pauseTimer : _startTimer,
                style: IconButton.styleFrom(
                  backgroundColor: accent.withValues(alpha: 0.15),
                  foregroundColor: accent,
                  padding: const EdgeInsets.all(14),
                ),
              ),
            const SizedBox(height: RitmoSpacing.xl),

            // Action Buttons
            Row(
              children: [
                // Partial complete if timer ran for at least 1 minute
                if (_remainingSeconds < _totalSeconds && !isFinished) ...[
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(color: colors.warning),
                        foregroundColor: colors.warning,
                      ),
                      onPressed: _handlePartialComplete,
                      child: const Text('ثبت انجام جزئی'),
                    ),
                  ),
                  const SizedBox(width: RitmoSpacing.md),
                ],

                // Full complete
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: isFinished
                          ? colors.success
                          : colors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: _handleFullComplete,
                    child: const Text('ثبت انجام کامل'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: RitmoSpacing.sm),

            // Cancel button
            TextButton(
              onPressed: () {
                _timer?.cancel();
                Navigator.of(context).pop();
              },
              child: Text(
                'انصراف و بستن',
                style: TextStyle(color: colors.textTertiary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
