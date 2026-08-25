import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/courses/logic/course_validation.dart';
import 'package:ritmo/features/courses/logic/courses_repository.dart';
import 'package:ritmo/features/courses/models/course_models.dart';
import 'package:ritmo/features/courses/presentation/widgets/course_formatters.dart';

class CompletedCoursesSection extends StatelessWidget {
  const CompletedCoursesSection({
    super.key,
    required this.completedCourses,
    this.archivedCourses = const [],
    required this.courseSessionsMap,
    required this.onRefresh,
  });

  final List<Course> completedCourses;
  final List<Course> archivedCourses;
  final Map<String, List<CourseSession>> courseSessionsMap;
  final VoidCallback onRefresh;

  Future<void> _restoreCourse(BuildContext context, Course course) async {
    final colors = context.colors;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: isDarkMode ? const Color(0xff12141C) : Colors.white,
          title: const Text(
            'بازیابی دوره',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          content: Text(
            'آیا می‌خواهید دوره "${course.title}" را از وضعیت ${course.statusLabel} به وضعیت فعال بازگردانید تا جلسات آن را پیگیری کنید؟',
            style: const TextStyle(fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('انصراف', style: TextStyle(color: colors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: colors.primary),
              child: const Text('بازیابی', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (confirm ?? false) {
      try {
        final res = await CoursesRepository.instance.restoreCourse(course.id);
        if (res.isApplied) {
          onRefresh();
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('دوره "${course.title}" دوباره بازیابی شد. 📚'),
                backgroundColor: colors.success,
              ),
            );
          }
        }
      } on CourseValidationException catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.messageFa),
              backgroundColor: colors.error,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('خطا در بازیابی دوره: $e'),
              backgroundColor: colors.error,
            ),
          );
        }
      }
    }
  }

  Widget _buildCourseCard(BuildContext context, Course course, RitmoColors colors, bool isDarkMode) {
    final sessions = courseSessionsMap[course.id] ?? [];
    final totalMinutes = sessions.fold<int>(0, (sum, s) => sum + (s.actualDurationMinutes ?? 0));

    // Badge styling based on actual course status
    Color badgeBg;
    Color badgeTextColor;
    IconData badgeIcon;
    String badgeText = course.statusLabel;

    if (course.isCompleted) {
      badgeBg = const Color(0xff10A37F).withValues(alpha: 0.12);
      badgeTextColor = const Color(0xff10A37F);
      badgeIcon = CupertinoIcons.checkmark_seal_fill;
      badgeText = 'تکمیل‌شده 🏆';
    } else if (course.isPaused) {
      badgeBg = Colors.amber.withValues(alpha: 0.15);
      badgeTextColor = Colors.amber.shade800;
      badgeIcon = CupertinoIcons.pause_circle_fill;
      badgeText = 'متوقف‌شده ⏸️';
    } else {
      badgeBg = colors.primary.withValues(alpha: 0.12);
      badgeTextColor = colors.primary;
      badgeIcon = CupertinoIcons.archivebox_fill;
      badgeText = 'بایگانی‌شده';
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: RitmoTheme.glassCardLight(
        borderRadius: 20,
        color: isDarkMode
            ? colors.card.withValues(alpha: 0.35)
            : colors.card.withValues(alpha: 0.5),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Text(
                          course.emojiResolved,
                          style: const TextStyle(fontSize: 20),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            course.title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: colors.textPrimary.withValues(alpha: 0.8),
                              decoration: course.isCompleted ? TextDecoration.lineThrough : null,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: badgeBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(badgeIcon, color: badgeTextColor, size: 12),
                        const SizedBox(width: 4),
                        Text(
                          badgeText,
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: badgeTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'تعداد کل جلسات: ${toPersianDigits(course.totalSessions)} جلسه',
                        style: TextStyle(
                          fontSize: 11,
                          color: colors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'مدت کل زمان مطالعه: ${toPersianDigits(totalMinutes)} دقیقه',
                        style: TextStyle(
                          fontSize: 11,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  TextButton.icon(
                    onPressed: () => _restoreCourse(context, course),
                    icon: const Icon(CupertinoIcons.refresh, size: 14),
                    label: const Text(
                      'بازیابی دوره',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    if (completedCourses.isEmpty && archivedCourses.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (completedCourses.isNotEmpty) ...[
          Text(
            'دوره‌های تکمیل‌شده (تالار افتخارات)',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: completedCourses.length,
            itemBuilder: (context, index) => _buildCourseCard(context, completedCourses[index], colors, isDarkMode),
          ),
        ],

        if (archivedCourses.isNotEmpty) ...[
          if (completedCourses.isNotEmpty) const SizedBox(height: 24),
          Text(
            'دوره‌های بایگانی‌شده (آرشیو)',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: archivedCourses.length,
            itemBuilder: (context, index) => _buildCourseCard(context, archivedCourses[index], colors, isDarkMode),
          ),
        ],
      ],
    );
  }
}
