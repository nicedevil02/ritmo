import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_card.dart';
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
  bool _isNightTime = false;

  @override
  void initState() {
    super.initState();
    _checkNightTime();
    _tickerTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) {
        _checkNightTime();
      }
    });
  }

  void _checkNightTime() {
    final now = DateTime.now();
    final midnight = widget.day.times.midnightShari;
    final fajr = widget.day.times.fajr;
    final isNight = now.isAfter(midnight) || now.isBefore(fajr);
    if (_isNightTime != isNight) {
      setState(() {
        _isNightTime = isNight;
      });
    }
  }

  @override
  void dispose() {
    _tickerTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isNightTime) {
      return const SizedBox.shrink(); // Hide during day
    }

    final colors = context.colors;
    final progress = (_currentRakah / 11.0).clamp(0.0, 1.0);
    final isCompleted = _currentRakah >= 11;

    return RitmoCard.neumorphic(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header
          RitmoCardHeader(
            title: 'آیین نماز شب (نافله شب)',
            icon: CupertinoIcons.moon_stars_fill,
            iconColor: colors.accent,
            trailing: RitmoCardBadge(
              label: '${PersianDigits.convert('11')} رکعت',
              color: colors.accent,
            ),
          ),
          const SizedBox(height: 12),

          // 2. Quranic Ayah in Sunken Well
          RitmoCard.neumorphicSunken(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'وَمِنَ اللَّيْلِ فَتَهَجَّدْ بِهِ نَافِلَةً لَكَ عَسَىٰ أَنْ يَبْعَثَكَ رَبُّكَ مَقَامًا مَحْمُودًا',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
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
              ],
            ),
          ),

          const SizedBox(height: 12),
          const RitmoCardDivider(),
          const SizedBox(height: 12),

          // 3. Stepper & Action Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _rakahStageText(_currentRakah),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
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
              ),

              // Action Buttons
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_currentRakah > 0)
                    RitmoNeuButton(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      onTap: () {
                        setState(() {
                          _currentRakah--;
                        });
                      },
                      child: Icon(
                        CupertinoIcons.minus,
                        size: 16,
                        color: colors.textSecondary,
                      ),
                    ),
                  if (_currentRakah > 0) const SizedBox(width: 8),
                  RitmoNeuButton(
                    color: isCompleted ? colors.success : colors.accent,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    onTap: () {
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
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),

          // 4. Progress Bar
          RitmoNeuProgressBar(
            progress: progress,
            height: 6.0,
            color: colors.accent,
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
