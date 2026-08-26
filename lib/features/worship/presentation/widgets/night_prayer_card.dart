import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/worship/logic/worship_engine.dart';

class NightPrayerCard extends StatefulWidget {
  const NightPrayerCard({
    super.key,
    required this.day,
    required this.onComplete,
  });

  final WorshipDay day;
  final VoidCallback onComplete;

  @override
  State<NightPrayerCard> createState() => _NightPrayerCardState();
}

class _NightPrayerCardState extends State<NightPrayerCard> {
  int _currentRakah = 0;
  Timer? _tickerTimer;

  @override
  void initState() {
    super.initState();
    _tickerTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tickerTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final midnight = widget.day.times.midnightShari;
    final fajr = widget.day.times.fajr;

    // Is it night time (after midnight or before fajr)?
    final isNightTime = now.isAfter(midnight) || now.isBefore(fajr);

    if (!isNightTime) {
      return const SizedBox.shrink(); // Hide during day
    }

    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final progress = (_currentRakah / 11.0).clamp(0.0, 1.0);
    final isCompleted = _currentRakah >= 11;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: colors.border,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: isDark ? 0.28 : 0.08),
            blurRadius: 28,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    CupertinoIcons.moon_stars_fill,
                    size: 20,
                    color: colors.accent,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'آیین نماز شب (نافله شب)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: colors.textPrimary,
                      ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: colors.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: colors.accent.withValues(alpha: 0.3),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  '${PersianDigits.convert('11')} رکعت',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: colors.accent,
                    ),
                ),
              ),
            ],
          ),

          Text(
            'وَمِنَ اللَّيْلِ فَتَهَجَّدْ بِهِ نَافِلَةً لَكَ عَسَىٰ أَنْ يَبْعَثَكَ رَبُّكَ مَقَامًا مَحْمُودًا',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colors.textPrimary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '«و پاسی از شب را برای خواندن نافله (نماز شب) بیدار باش؛ امید است پروردگارت تو را به مقامی ستوده برانگیزد.» (اسراء - ۷۹)',
            style: TextStyle(
              fontSize: 11,
              color: colors.textSecondary,
              height: 1.45,
            ),
          ),


          // Stepper Counter Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _rakahStageText(_currentRakah),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                      ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${PersianDigits.convert(_currentRakah.toString())} از ${PersianDigits.convert('11')} رکعت خوانده شده',
                    style: TextStyle(
                      fontSize: 11,
                      color: colors.textTertiary,
                      ),
                  ),
                ],
              ),

              // Action Buttons
              Row(
                children: [
                  if (_currentRakah > 0)
                    IconButton(
                      icon: Icon(CupertinoIcons.minus_circle, color: colors.textSecondary),
                      onPressed: () {
                        unawaited(HapticFeedback.lightImpact());
                        setState(() {
                          _currentRakah--;
                        });
                      },
                    ),

                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isCompleted ? colors.success : colors.accent,
                      foregroundColor: isCompleted ? Colors.white : Colors.black87,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      elevation: 0,
                    ),
                    onPressed: () {
                      unawaited(HapticFeedback.mediumImpact());
                      if (_currentRakah < 11) {
                        setState(() {
                          _currentRakah += 2;
                          if (_currentRakah > 11) _currentRakah = 11;
                        });
                        if (_currentRakah >= 11) {
                          widget.onComplete();
                        }
                      }
                    },
                    child: Text(
                      isCompleted ? 'تکمیل شد 🎉' : '+ ۲ رکعت',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              backgroundColor: colors.surfaceSunken,
              valueColor: AlwaysStoppedAnimation<Color>(colors.accent),
            ),
          ),
        ],
      ),
    );
  }

  String _rakahStageText(int count) {
    if (count < 8) return '۸ رکعت نافله شب (۴ نماز ۲ رکعتی)';
    if (count < 10) return '۲ رکعت نماز شفع';
    if (count == 10) return '۱ رکعت نماز وتر';
    return 'پایان نماز شب — قبول باشد 🤲';
  }
}
