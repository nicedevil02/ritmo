import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/util/ritmo_number.dart';
import 'package:ritmo/features/courses/logic/course_date_contract.dart';
import 'package:ritmo/features/courses/models/course_models.dart';
import 'package:shamsi_date/shamsi_date.dart';

class JalaliWeeklyHeatmap extends StatelessWidget {
  const JalaliWeeklyHeatmap({
    super.key,
    required this.sessions,
    required this.today,
  });

  final List<CourseSession> sessions;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final satOfWeek = CourseDate.startOfFarsiWeek(today);

    final dayLabels = ['ش', 'ی', 'د', 'س', 'چ', 'پ', 'ج'];
    final dayMinutes = List<int>.filled(7, 0);

    for (var i = 0; i < 7; i++) {
      final dt = CourseDate.addDays(satOfWeek, i);
      final dtStr = CourseDate.toDayKey(dt);

      for (final s in sessions) {
        if (s.isCompleted && s.plannedDate == dtStr) {
          dayMinutes[i] += s.actualDurationMinutes ?? 30;
        }
      }
    }

    final maxMin = dayMinutes.fold<int>(1, (max, v) => v > max ? v : max);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'الگوی مطالعه این هفته (هجری شمسی)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: colors.textPrimary,
                ),
              ),
              Text(
                'مجموع: ${RitmoNumber.toFa(dayMinutes.reduce((a, b) => a + b))} دقیقه',
                style: TextStyle(fontSize: 11, color: colors.primary, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(7, (idx) {
              final mins = dayMinutes[idx];
              final intensity = mins > 0 ? (mins / maxMin).clamp(0.2, 1.0) : 0.05;
              final dt = CourseDate.addDays(satOfWeek, idx);
              final jDate = Jalali.fromDateTime(dt);
              final isToday = CourseDate.isSameDay(dt, today);

              return Column(
                children: [
                  Text(
                    dayLabels[idx],
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                      color: isToday ? colors.primary : colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: 32,
                    height: 48,
                    decoration: BoxDecoration(
                      color: mins > 0
                          ? colors.primary.withValues(alpha: intensity)
                          : colors.border.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: isToday ? Border.all(color: colors.primary, width: 1.5) : null,
                    ),
                    alignment: Alignment.center,
                    child: mins > 0
                        ? Text(
                            RitmoNumber.toFa(mins),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: intensity > 0.6 ? Colors.white : colors.textPrimary,
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    RitmoNumber.toFa(jDate.day),
                    style: TextStyle(fontSize: 9, color: colors.textSecondary),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }
}
