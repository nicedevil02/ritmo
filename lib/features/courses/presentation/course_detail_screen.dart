import 'dart:async';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:persian_datetime_picker/persian_datetime_picker.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/ritmo_date_picker.dart';
import 'package:ritmo/core/ux/ritmo_directional_icon.dart';
import 'package:ritmo/features/courses/logic/courses_repository.dart';
import 'package:ritmo/features/courses/models/course_models.dart';
import 'package:ritmo/features/courses/presentation/widgets/course_formatters.dart';
import 'package:ritmo/features/courses/presentation/widgets/create_course_sheet.dart';
import 'package:ritmo/features/courses/presentation/widgets/segmented_visual_journey_track.dart';
import 'package:ritmo/features/courses/presentation/widgets/study_timer_sheet.dart';
import 'package:ritmo/features/notes/presentation/widgets/module_note_history.dart';


class CourseDetailScreen extends StatefulWidget {

  const CourseDetailScreen({
    super.key,
    required this.course,
  });
  final Course course;

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen> {
  late Course _course;
  List<CourseSession> _sessions = [];
  bool _isLoading = true;

  Map<String, dynamic>? _linkedGoal;
  double _linkedGoalProgress = 0;
  final Set<String> _resolvedQuestionIds = {};


  @override
  void initState() {
    super.initState();
    _course = widget.course;
    _loadCourseData();
  }

  Future<void> _loadCourseData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 1. Fetch latest course details
      final updated = await CoursesRepository.instance.getCourseById(_course.id);
      if (updated != null) {
        _course = updated;
      }

      // 2. Fetch sessions
      _sessions = await CoursesRepository.instance.getSessionsForCourse(_course.id);

      // 3. Fetch linked goal title + real progress if exists (fixes always-zero progress)
      if (_course.linkedGoalId != null) {
        final goalInfo = await CoursesRepository.instance.getLinkedGoalInfo(_course.linkedGoalId!);
        if (goalInfo != null) {
          _linkedGoal = {'title': goalInfo['title']};
          _linkedGoalProgress = (goalInfo['progressCache'] as num?)?.toDouble() ?? 0.0;
        } else {
          _linkedGoal = null;
          _linkedGoalProgress = 0;
        }
      } else {
        _linkedGoal = null;
        _linkedGoalProgress = 0;
      }

      // 4. Restore persisted resolved-question state (was screen-local and reset on reload)
      _resolvedQuestionIds
        ..clear()
        ..addAll(_sessions.where((s) => s.questionResolved).map((s) => s.id));
    } catch (e) {
      debugPrint('Error loading course details: $e');
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _togglePauseStatus() async {
    final newStatus = _course.status == CourseStatus.paused ? CourseStatus.active : CourseStatus.paused;
    await CoursesRepository.instance.updateCourseStatus(_course.id, newStatus);
    await _loadCourseData();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(newStatus == CourseStatus.paused ? 'دوره موقتاً متوقف شد.' : 'دوره مجدداً فعال شد. 📚'),
          backgroundColor: context.colors.primary,
        ),
      );
    }
  }

  Future<void> _editCourse() async {
    unawaited(
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (context) => CreateCourseSheet(
          editingCourse: _course,
          onCourseCreated: _loadCourseData,
        ),
      ).then((_) => _loadCourseData()),
    );
  }

  Future<void> _deleteCourse() async {
    final colors = context.colors;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: RitmoTheme.glassCardLight(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'حذف دوره آموزشی',
                    textAlign: TextAlign.right,
                    style: TextStyle(fontFamily: 'Vazirmatn', fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'آیا از حذف کامل این دوره و تمام جلسات مطالعاتی و یادآورهای مربوط به آن اطمینان دارید؟ این عمل غیرقابل بازگشت است.',
                    textAlign: TextAlign.right,
                    style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 13, color: Colors.white70, height: 1.5),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text('انصراف', style: TextStyle(fontFamily: 'Vazirmatn', color: colors.textSecondary)),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colors.warning,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('بله، حذف کن', style: TextStyle(fontFamily: 'Vazirmatn', color: Colors.white)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (confirm ?? false) {
      await CoursesRepository.instance.deleteCourse(_course.id);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('دوره "${_course.title}" حذف شد.'),
            backgroundColor: colors.warning,
          ),
        );
      }
    }
  }

  Future<void> _rescheduleSessionDate(CourseSession session) async {
    final currentPlanned = session.plannedDate != null ? DateTime.tryParse(session.plannedDate!) : null;
    final colors = context.colors;

    final picked = await RitmoDatePicker.showJalali(
      context: context,
      initialDate: Jalali.fromDateTime(currentPlanned ?? DateTime.now()),
      firstDate: Jalali.fromDateTime(DateTime.now().subtract(const Duration(days: 30))),
      lastDate: Jalali.fromDateTime(DateTime.now().add(const Duration(days: 365))),
      builder: (context, child) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Theme(
              data: Theme.of(context).copyWith(
                colorScheme: ColorScheme.dark(
                  primary: colors.primary,
                  onPrimary: Colors.white,
                  surface: Colors.transparent,
                ), dialogTheme: DialogThemeData(backgroundColor: Colors.black.withValues(alpha: 0.7)),
              ),
              child: child!,
            ),
          ),
        );
      },
    );

    if (picked != null) {
      final pickedDateTime = picked.toDateTime();
      final formatted = '${pickedDateTime.year}-${pickedDateTime.month.toString().padLeft(2, '0')}-${pickedDateTime.day.toString().padLeft(2, '0')}';
      await CoursesRepository.instance.rescheduleSession(session.id, formatted);
      await _loadCourseData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('زمان جلسه به ${toPersianDigits(formatted)} تغییر یافت.'),
            backgroundColor: colors.success,
          ),
        );
      }
    }
  }

  void _startSessionTimer(CourseSession session) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StudyTimerSheet(
        course: _course,
        session: session,
        onTimerFinished: _loadCourseData,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: colors.bg,
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final completedCount = _sessions.where((s) => s.isCompleted).length;
    final progress = _course.totalSessions > 0
        ? (completedCount / _course.totalSessions).clamp(0.0, 1.0)
        : 0.0;
    final progressPercent = (progress * 100).round();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: colors.bg,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: RitmoIcons.back(context, color: colors.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            _course.title,
            style: TextStyle(
              fontFamily: 'Vazirmatn',
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: colors.textPrimary,
            ),
          ),
          actions: [
            IconButton(
              icon: Icon(
                _course.status == CourseStatus.paused ? CupertinoIcons.play_fill : CupertinoIcons.pause_fill,
                color: colors.textPrimary,
              ),
              onPressed: _togglePauseStatus,
            ),
            IconButton(
              icon: Icon(CupertinoIcons.pencil, color: colors.textPrimary),
              onPressed: _editCourse,
            ),
            IconButton(
              icon: Icon(CupertinoIcons.trash, color: colors.textSecondary),
              onPressed: _deleteCourse,
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Progress Header Card
              RitmoTheme.glassCardLight(
                color: isDarkMode ? colors.card.withValues(alpha: 0.55) : colors.card.withValues(alpha: 0.8),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Text(
                                _course.emojiResolved,
                                style: const TextStyle(fontSize: 22),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                _course.courseType.label,
                                style: TextStyle(
                                  fontFamily: 'Vazirmatn',
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: colors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: (_course.status == CourseStatus.active
                                      ? colors.success
                                      : colors.textSecondary)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _course.status == CourseStatus.active
                                  ? 'در حال یادگیری'
                                  : 'متوقف‌شده',
                              style: TextStyle(
                                fontFamily: 'Vazirmatn',
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: _course.status == CourseStatus.active
                                    ? colors.success
                                    : colors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'پیشرفت کلی دوره: ${toPersianDigits(completedCount)} از ${toPersianDigits(_course.totalSessions)} ${_course.unitLabelResolved}',
                            style: TextStyle(
                              fontFamily: 'Vazirmatn',
                              fontSize: 12,
                              color: colors.textSecondary,
                            ),
                          ),
                          Text(
                            '${toPersianDigits(progressPercent)}٪',
                            style: TextStyle(
                              fontFamily: 'Vazirmatn',
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: colors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 6,
                          backgroundColor: colors.border.withValues(alpha: 0.5),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _course.resolvedColor(colors.primary),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SegmentedVisualJourneyTrack(sessions: _sessions),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 2. Linked Goal Card (One-way read-only display)
              if (_linkedGoal != null) ...[
                RitmoTheme.glassCardLight(
                  borderRadius: 20,
                  color: colors.primary.withValues(alpha: 0.05),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: colors.primary.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(CupertinoIcons.flag_fill, color: colors.primary, size: 18),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'هدف متصل',
                                style: TextStyle(
                                  fontFamily: 'Vazirmatn',
                                  fontSize: 10,
                                  color: colors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _linkedGoal!['title'] as String,
                                style: TextStyle(
                                  fontFamily: 'Vazirmatn',
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: colors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'پیشرفت کل هدف',
                              style: TextStyle(
                                fontFamily: 'Vazirmatn',
                                fontSize: 9,
                                color: colors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${toPersianDigits((_linkedGoalProgress * 100).round())}٪',
                              style: TextStyle(
                                fontFamily: 'Vazirmatn',
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: colors.primary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // 3. Weekly study configuration summary
              Text(
                'برنامه زمانی مطالعاتی',
                style: TextStyle(
                  fontFamily: 'Vazirmatn',
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colors.card.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colors.border.withValues(alpha: 0.5)),
                ),
                child: Column(
                  children: [
                    _buildConfigItem('هدف هفتگی مطالعه', '${toPersianDigits(_course.weeklyTargetSessions)} جلسه در هفته', colors),
                    const Divider(height: 20),
                    _buildConfigItem(
                      'روزهای ترجیحی',
                      _course.preferredDays.isEmpty
                          ? 'تنظیم نشده (پیش‌فرض زوج)'
                          : _course.preferredDays.map((d) {
                              switch (d) {
                                case 6: return 'شنبه';
                                case 0: return 'یکشنبه';
                                case 1: return 'دوشنبه';
                                case 2: return 'سه‌شنبه';
                                case 3: return 'چهارشنبه';
                                case 4: return 'پنجشنبه';
                                case 5: return 'جمعه';
                                default: return '';
                              }
                            }).join('، '),
                      colors,
                    ),
                    const Divider(height: 20),
                    _buildConfigItem(
                      'یادآور مطالعه',
                      _course.reminderEnabled && _course.preferredTime != null
                          ? 'فعال در ساعت ${toPersianDigits(_course.preferredTime)}'
                          : 'غیرفعال',
                      colors,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 4. Session list
              Text(
                'سرفصل‌ها و جلسات دوره',
                style: TextStyle(
                  fontFamily: 'Vazirmatn',
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _sessions.length,
                itemBuilder: (context, index) {
                  final session = _sessions[index];
                  final isCompleted = session.isCompleted;

                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? colors.success.withValues(alpha: 0.04)
                          : colors.card.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isCompleted
                            ? colors.success.withValues(alpha: 0.2)
                            : colors.border.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Row(
                        children: [
                          // Status checkmark
                          Icon(
                            isCompleted ? CupertinoIcons.check_mark_circled_solid : CupertinoIcons.circle,
                            color: isCompleted ? colors.success : colors.textSecondary,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  session.sessionTitle ?? '${_course.unitLabelResolved} ${session.sessionNumber}',
                                  style: TextStyle(
                                    fontFamily: 'Vazirmatn',
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: isCompleted ? colors.textSecondary : colors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    GestureDetector(
                                      onTap: isCompleted ? null : () => _rescheduleSessionDate(session),
                                      child: Text(
                                        session.plannedDate != null
                                            ? 'برنامه‌ریزی: ${toPersianDigits(session.plannedDate)} 📅'
                                            : 'بدون تاریخ زمان‌بندی',
                                        style: TextStyle(
                                          fontFamily: 'Vazirmatn',
                                          fontSize: 10.5,
                                          color: isCompleted ? colors.textSecondary : colors.primary,
                                          decoration: isCompleted ? null : TextDecoration.underline,
                                        ),
                                      ),
                                    ),
                                    if (isCompleted && session.actualDurationMinutes != null) ...[
                                      const SizedBox(width: 8),
                                      Text(
                                        '• مدت مطالعه: ${toPersianDigits(session.actualDurationMinutes)} دقیقه',
                                        style: TextStyle(
                                          fontFamily: 'Vazirmatn',
                                          fontSize: 10.5,
                                          color: colors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (!isCompleted)
                            IconButton(
                              icon: const Icon(CupertinoIcons.play_arrow_solid, size: 16),
                              color: colors.primary,
                              onPressed: () => _startSessionTimer(session),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
              _buildDebriefsSection(colors),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDebriefsSection(RitmoColors colors) {
    final takeaways = _sessions.where((s) => s.keyTakeaway != null && s.keyTakeaway!.trim().isNotEmpty).toList();
    final questions = _sessions.where((s) => s.openQuestion != null && s.openQuestion!.trim().isNotEmpty).toList();
    final freeNotes = _sessions.where((s) => s.note != null && s.note!.trim().isNotEmpty).toList();

    if (takeaways.isEmpty && questions.isEmpty && freeNotes.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.card.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border.withValues(alpha: 0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '💡 برداشت‌های من از دوره',
              style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 14, fontWeight: FontWeight.bold, color: colors.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              'هنوز برداشتی ثبت نکرده‌ای. پس از هر جلسه، نکته‌های کلیدی و سوالات باز خود را ثبت کن.',
              style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 12, color: colors.textSecondary),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.card.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '💡 برداشت‌های من از این دوره',
            style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 14, fontWeight: FontWeight.bold, color: colors.textPrimary),
          ),
          const SizedBox(height: 12),

          // 1. Key takeaways
          if (takeaways.isNotEmpty) ...[
            Text(
              '💡 نکته‌های کلیدی (${toPersianDigits(takeaways.length)})',
              style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 12, fontWeight: FontWeight.bold, color: colors.primary),
            ),
            const SizedBox(height: 6),
            ...takeaways.map((s) => Padding(
              padding: const EdgeInsets.only(bottom: 6, right: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('• ', style: TextStyle(color: colors.primary, fontWeight: FontWeight.bold)),
                  Expanded(
                    child: Text(
                      '${s.keyTakeaway!} (جلسه ${toPersianDigits(s.sessionNumber)})',
                      textDirection: TextDirection.rtl,
                      style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 12, color: colors.textPrimary),
                    ),
                  ),
                ],
              ),
            )),
            const SizedBox(height: 12),
          ],

          // 2. Open questions (with resolved checkbox, persisted via setSessionQuestionResolved)
          if (questions.isNotEmpty) ...[
            Text(
              '❓ سؤال‌های باز (${toPersianDigits(questions.length)})',
              style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 12, fontWeight: FontWeight.bold, color: colors.warning),
            ),
            const SizedBox(height: 6),
            ...questions.map((s) {
              final isResolved = _resolvedQuestionIds.contains(s.id);
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isResolved ? colors.success.withValues(alpha: 0.1) : colors.warning.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Checkbox(
                      value: isResolved,
                      activeColor: colors.success,
                      onChanged: (val) {
                        final resolved = val == true;
                        setState(() {
                          if (resolved) {
                            _resolvedQuestionIds.add(s.id);
                          } else {
                            _resolvedQuestionIds.remove(s.id);
                          }
                        });
                        CoursesRepository.instance.setSessionQuestionResolved(s.id, resolved);
                      },
                    ),
                    Expanded(
                      child: Text(
                        '${s.openQuestion!} (جلسه ${toPersianDigits(s.sessionNumber)})',
                        textDirection: TextDirection.rtl,
                        style: TextStyle(
                          fontFamily: 'Vazirmatn',
                          fontSize: 12,
                          color: isResolved ? colors.textSecondary : colors.textPrimary,
                          decoration: isResolved ? TextDecoration.lineThrough : null,
                        ),
                      ),
                    ),
                    if (isResolved)
                      Text(
                        'حل شد ✓',
                        style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 10, color: colors.success, fontWeight: FontWeight.bold),
                      ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 12),
          ],

          // 3. Free study notes
          if (freeNotes.isNotEmpty) ...[
            Text(
              '📝 یادداشت‌های آزاد (${toPersianDigits(freeNotes.length)})',
              style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 12, fontWeight: FontWeight.bold, color: colors.textSecondary),
            ),
            const SizedBox(height: 6),
            ...freeNotes.map((s) => Padding(
              padding: const EdgeInsets.only(bottom: 6, right: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('📝 ', style: TextStyle(fontSize: 11)),
                  Expanded(
                    child: Text(
                      '${s.note!} (جلسه ${toPersianDigits(s.sessionNumber)})',
                      textDirection: TextDirection.rtl,
                      style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 12, color: colors.textPrimary),
                    ),
                  ),
                ],
              ),
            )),
          ],

          const SizedBox(height: 8),
          ModuleNoteHistorySection(module: 'courses', entityId: _course.id),
        ],
      ),
    );
  }


  Widget _buildConfigItem(String title, String value, RitmoColors colors) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 12, color: colors.textSecondary),
        ),
        Text(
          value,
          style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 12, fontWeight: FontWeight.bold, color: colors.textPrimary),
        ),
      ],
    );
  }
}
