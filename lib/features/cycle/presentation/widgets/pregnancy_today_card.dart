import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/features/health/data/pregnancy_repository.dart';
import 'package:ritmo/features/health/data/pregnancy_week_data.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';

/// UX-01 Today Card dependent on Trimester, placed above the 5 main tabs.
class PregnancyTodayCard extends StatelessWidget {
  const PregnancyTodayCard({
    super.key,
    required this.gestationalAge,
    required this.hasSupplementToday,
    required this.hasKicksLogged,
    required this.onNavigateTab,
    required this.onOpenWeightLog,
    required this.onOpenLaborMode,
    required this.onOpenHospitalBag,
  });

  final GestationalAge gestationalAge;
  final bool hasSupplementToday;
  final bool hasKicksLogged;
  final ValueChanged<int> onNavigateTab;
  final VoidCallback onOpenWeightLog;
  final VoidCallback onOpenLaborMode;
  final VoidCallback onOpenHospitalBag;

  @override
  Widget build(BuildContext context) {
    final trimester = gestationalAge.trimester;
    final week = gestationalAge.weeks;
    final weekInfo = pregnancyWeekData[week];

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surfaceElevated,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: context.colors.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                CupertinoIcons.sparkles,
                color: context.colors.primary,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'کارت امروز بارداری (سه ماهه ${trimester == 1 ? "اول" : (trimester == 2 ? "دوم" : "سوم")})',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: context.colors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Trimester 1 Content
          if (trimester == 1) ...[
            _buildInfoRow(
              icon: hasSupplementToday
                  ? CupertinoIcons.checkmark_circle_fill
                  : CupertinoIcons.capsule,
              iconColor: hasSupplementToday ? Colors.green : Colors.orange,
              text: hasSupplementToday
                  ? 'مکمل‌های امروز ثبت شده است'
                  : 'مکمل امروز (فولیک اسید / آهن) را مصرف کنید',
            ),
            const SizedBox(height: 8),
            _buildInfoRow(
              icon: CupertinoIcons.time,
              iconColor: Colors.purple,
              text: 'اولین سونوگرافی: هفته‌های ۸ تا ۱۲ (غربالگری اولیه)',
            ),
            if (weekInfo?.symptomsFa != null) ...[
              const SizedBox(height: 8),
              _buildInfoRow(
                icon: CupertinoIcons.heart_fill,
                iconColor: Colors.pink,
                text: 'نکته هفته $week: ${weekInfo!.symptomsFa}',
              ),
            ],
          ]
          // Trimester 2 Content
          else if (trimester == 2) ...[
            _buildInfoRow(
              icon: CupertinoIcons.doc_checkmark_fill,
              iconColor: Colors.blue,
              text: 'پنجره غربالگری ناهنجاری‌ها: هفته‌های ۱۸ تا ۲۰',
            ),
            const SizedBox(height: 8),
            if (week >= 18 && !hasKicksLogged)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      CupertinoIcons.bolt_fill,
                      color: Colors.amber,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'اولین لگد را ثبت کنید',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () => onNavigateTab(2),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'ثبت',
                          style: TextStyle(fontSize: 11, color: Colors.black),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            InkWell(
              onTap: onOpenWeightLog,
              child: _buildInfoRow(
                icon: CupertinoIcons.add_circled,
                iconColor: Colors.teal,
                text: 'ثبت و بررسی روند وزن بارداری ↗',
              ),
            ),
          ]
          // Trimester 3 Content
          else ...[
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.pinkAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    icon: const Icon(CupertinoIcons.play_circle_fill, size: 18),
                    label: const Text(
                      'شروع لگدشماری',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: () => onNavigateTab(2),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigoAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    icon: const Icon(CupertinoIcons.timer, size: 18),
                    label: const Text(
                      'شروع انقباض‌سنج',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: onOpenLaborMode,
                  ),
                ),
              ],
            ),
            if (week >= 32) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 40),
                ),
                icon: const Icon(CupertinoIcons.bag_fill, size: 16),
                label: const Text(
                  'چک‌لیست ساک بیمارستان (هفته ۳۲+)',
                  style: TextStyle(fontSize: 12),
                ),
                onPressed: onOpenHospitalBag,
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required Color iconColor,
    required String text,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: iconColor, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: const TextStyle(fontSize: 12, height: 1.4)),
        ),
      ],
    );
  }
}
