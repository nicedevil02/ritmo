import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/movement/presentation/common/movement_strings.dart';

/// مدل دورهای ثبت‌شده در مد Lap
class SessionLapItem {
  const SessionLapItem({
    required this.lapNumber,
    required this.durationSec,
    required this.splitTimeSec,
  });

  final int lapNumber;
  final int durationSec;
  final int splitTimeSec;
}

/// دکمهٔ ثبت دور با ارتفاع $\ge 72$، ضد تپ دوگانه (Debounce ۴۰۰ms)، هپتیک و فهرست دورها
class LapButton extends StatefulWidget {
  const LapButton({
    super.key,
    required this.laps,
    required this.onLapRecorded,
    required this.onUndoLap,
    required this.currentElapsedSec,
  });

  final List<SessionLapItem> laps;
  final ValueChanged<SessionLapItem> onLapRecorded;
  final VoidCallback onUndoLap;
  final int currentElapsedSec;

  @override
  State<LapButton> createState() => _LapButtonState();
}

class _LapButtonState extends State<LapButton> {
  int _lastTapTimeMs = 0;
  static const int _debounceMs = 400;

  void _handleLapTap() {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastTapTimeMs < _debounceMs) {
      return; // جلوگیری از تپ مضاعف در محدودهٔ ۴۰۰ میلی‌ثانیه
    }
    _lastTapTimeMs = now;

    HapticFeedback.lightImpact();

    final lastLapSplit = widget.laps.isNotEmpty ? widget.laps.last.splitTimeSec : 0;
    final lapDuration = widget.currentElapsedSec - lastLapSplit;
    final newLap = SessionLapItem(
      lapNumber: widget.laps.length + 1,
      durationSec: lapDuration > 0 ? lapDuration : 1,
      splitTimeSec: widget.currentElapsedSec,
    );

    widget.onLapRecorded(newLap);
  }

  String _formatSec(int sec) {
    final m = sec ~/ 60;
    final s = sec % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final sportsColor = context.modules.sports;

    final lapCount = widget.laps.length;
    SessionLapItem? bestLap;
    double avgSec = 0;

    if (lapCount >= 2) {
      bestLap = widget.laps.reduce((a, b) => a.durationSec < b.durationSec ? a : b);
      final totalSec = widget.laps.fold<int>(0, (sum, l) => sum + l.durationSec);
      avgSec = totalSec / lapCount;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // دکمهٔ بزرگ ثبت دور با حداقل ارتفاع ۷۲
        SizedBox(
          width: double.infinity,
          height: 76,
          child: ElevatedButton(
            onPressed: _handleLapTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: sportsColor.withValues(alpha: 0.15),
              foregroundColor: sportsColor,
              elevation: 0,
              side: BorderSide(color: sportsColor, width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(RitmoRadius.card),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.flag_rounded, size: 28, color: sportsColor),
                const SizedBox(width: RitmoSpacing.md),
                Text(
                  MovementStrings.sessionLapDone,
                  style: RitmoTextStyles.sectionHeadline(sportsColor).copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: RitmoSpacing.md),

        // آمار دورها (بهترین، میانگین و تعداد کل)
        if (lapCount > 0) ...[
          Container(
            padding: const EdgeInsets.all(RitmoSpacing.md),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(RitmoRadius.card),
              border: Border.all(color: colors.border),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${MovementStrings.lapCountLabel}: ${toPersianDigits(lapCount)}',
                      style: RitmoTextStyles.label(colors.textPrimary),
                    ),
                    if (lapCount > 0)
                      TextButton.icon(
                        onPressed: widget.onUndoLap,
                        icon: const Icon(Icons.undo_rounded, size: 16),
                        label: const Text(MovementStrings.commonUndo),
                        style: TextButton.styleFrom(
                          foregroundColor: colors.warning,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                  ],
                ),
                if (lapCount >= 2 && bestLap != null) ...[
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          Text(
                            MovementStrings.lapBestLabel,
                            style: RitmoTextStyles.caption(colors.textSecondary),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'دور ${toPersianDigits(bestLap.lapNumber)} (${toPersianDigits(_formatSec(bestLap.durationSec))})',
                            style: RitmoTextStyles.body(colors.success).copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        children: [
                          Text(
                            MovementStrings.lapAvgLabel,
                            style: RitmoTextStyles.caption(colors.textSecondary),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            toPersianDigits(_formatSec(avgSec.round())),
                            style: RitmoTextStyles.body(colors.textPrimary).copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}
