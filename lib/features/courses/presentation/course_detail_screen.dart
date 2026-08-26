import 'dart:async';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:persian_datetime_picker/persian_datetime_picker.dart';
import 'package:ritmo/core/logging/ritmo_logger.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/util/ritmo_number.dart';
import 'package:ritmo/core/utils/ritmo_date_picker.dart';
import 'package:ritmo/core/utils/ritmo_toast.dart';
import 'package:ritmo/core/ux/ritmo_directional_icon.dart';
import 'package:ritmo/features/courses/logic/course_adaptive_engine.dart';
import 'package:ritmo/features/courses/logic/course_date_contract.dart';
import 'package:ritmo/features/courses/logic/course_scheduler.dart';
import 'package:ritmo/features/courses/logic/courses_repository.dart';
import 'package:ritmo/features/courses/models/course_models.dart';
import 'package:ritmo/features/courses/presentation/widgets/course_formatters.dart';
import 'package:ritmo/features/courses/presentation/widgets/create_course_sheet.dart';
import 'package:ritmo/features/courses/presentation/widgets/floating_timer_bar.dart';
import 'package:ritmo/features/courses/presentation/widgets/recovery_mode_sheet.dart';
import 'package:ritmo/features/courses/presentation/widgets/segmented_visual_journey_track.dart';
import 'package:ritmo/features/courses/presentation/widgets/session_debrief_sheet.dart';
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
  bool _isReordering = false;
  bool _isProposalDismissed = false;

  Map<String, dynamic>? _linkedGoal;
  double _linkedGoalProgress = 0;
  final Set<String> _resolvedQuestionIds = {};
  StreamSubscription<dynamic>? _eventSub;

  @override
  void initState() {
    super.initState();
    _course = widget.course;
    _loadCourseData();
    _eventSub = CoursesRepository.instance.events.listen((event) {
      final cId = event.payload['courseId'];
      if (cId == null || cId == _course.id) {
        _loadCourseData();
      }
    });
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    super.dispose();
  }

  Future<void> _loadCourseData() async {
    try {
      final updated = await CoursesRepository.instance.getCourseById(_course.id);
      if (updated != null) {
        _course = updated;
      }

      _sessions = await CoursesRepository.instance.getSessionsForCourse(_course.id);

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

      _resolvedQuestionIds
        ..clear()
        ..addAll(_sessions.where((s) => s.questionResolved).map((s) => s.id));
    } catch (e, st) {
      RitmoLog.error('COURSES', 'Error loading course details', e, st);
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
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'آیا از حذف کامل این دوره و تمام جلسات مطالعاتی و یادآورهای مربوط به آن اطمینان دارید؟ این عمل غیرقابل بازگشت است.',
                    textAlign: TextAlign.right,
                    style: TextStyle(fontSize: 13, color: Colors.white70, height: 1.5),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text('انصراف', style: TextStyle(color: colors.textSecondary)),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colors.warning,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('بله، حذف کن', style: TextStyle(color: Colors.white)),
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
                ),
                dialogTheme: DialogThemeData(backgroundColor: Colors.black.withValues(alpha: 0.7)),
              ),
              child: child!,
            ),
          ),
        );
      },
    );

    if (picked != null) {
      final pickedDateTime = picked.toDateTime();
      final formatted = CourseDate.toDayKey(pickedDateTime);
      await CoursesRepository.instance.rescheduleSession(session.id, formatted);
      await _loadCourseData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('زمان جلسه به ${CourseDate.dayKeyToJalaliDisplay(formatted)} تغییر یافت.'),
            backgroundColor: colors.success,
          ),
        );
      }
    }
  }

  Future<void> _rescheduleUnscheduledSessions() async {
    try {
      await CoursesRepository.instance.rescheduleCoursePendingSessions(_course.id);
      await _loadCourseData();
      if (mounted) {
        RitmoToast.show(
          context,
          'جلسات بدون تاریخ با موفقیت زمان‌بندی شدند.',
          iconColor: const Color(0xff10B981),
        );
      }
    } catch (e, st) {
      RitmoLog.error('COURSES', 'Error rescheduling pending sessions', e, st);
      if (mounted) {
        RitmoToast.show(
          context,
          'خطا در زمان‌بندی جلسات.',
          iconColor: Colors.red,
        );
      }
    }
  }

  Future<void> _applyAdaptiveProposal(AdaptiveAdjustmentResult proposal) async {
    try {
      await CourseAdaptiveEngine.applyAdjustment(_course, proposal);
      await _loadCourseData();
      if (mounted) {
        RitmoToast.show(
          context,
          'ریتم مطالعه دوره به ${RitmoNumber.toFa(proposal.newWeeklyTarget)} جلسه در هفته به‌روزرسانی شد.',
          iconColor: const Color(0xff10B981),
        );
      }
    } catch (e, st) {
      RitmoLog.error('COURSES', 'Error applying adaptive proposal', e, st);
    }
  }

  Future<void> _rollbackAdaptive() async {
    final colors = context.colors;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: colors.surface,
          title: const Text('بازگردانی ریتم قبلی'),
          content: const Text('آیا می‌خواهید تنظیم هوشمند ریتم مطالعه را لغو کرده و به وضعیت قبل از تنظیم خودکار بازگردید؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('انصراف', style: TextStyle(color: colors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: colors.primary),
              child: const Text('تأیید بازگردانی', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (confirm != true) return;

    try {
      final result = await CoursesRepository.instance.rollbackAdaptiveAdjustment(_course.id);
      if (result.isApplied) {
        await _loadCourseData();
        if (mounted) {
          RitmoToast.show(
            context,
            'ریتم مطالعه قبلی با موفقیت بازگردانی شد.',
            iconColor: const Color(0xff10B981),
          );
        }
      }
    } catch (e, st) {
      RitmoLog.error('COURSES', 'Error rolling back adaptive adjustment', e, st);
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

  Future<void> _openSessionActionMenu(CourseSession session) async {
    final colors = context.colors;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                session.sessionTitle ?? '${_course.unitLabelResolved} ${RitmoNumber.toFa(session.sessionNumber)}',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: colors.textPrimary),
              ),
              const SizedBox(height: 16),
              if (!session.isCompleted) ...[
                ListTile(
                  leading: Icon(CupertinoIcons.play_circle_fill, color: colors.primary),
                  title: const Text('شروع تایمر مطالعه'),
                  onTap: () {
                    Navigator.pop(context);
                    _startSessionTimer(session);
                  },
                ),
                ListTile(
                  leading: Icon(CupertinoIcons.checkmark_circle_fill, color: colors.success),
                  title: const Text('ثبت تکمیل جلسه و ارزیابی تسلط'),
                  onTap: () {
                    Navigator.pop(context);
                    SessionDebriefSheet.show(
                      context,
                      session: session,
                      actualDurationMinutes: session.estimatedDurationMinutes ?? _course.sessionDurationMinutes,
                      onCompleted: _loadCourseData,
                    );
                  },
                ),
                ListTile(
                  leading: Icon(CupertinoIcons.calendar, color: colors.primary),
                  title: const Text('تغییر تاریخ زمان‌بندی'),
                  onTap: () {
                    Navigator.pop(context);
                    _rescheduleSessionDate(session);
                  },
                ),
                ListTile(
                  leading: Icon(CupertinoIcons.arrow_left_to_line_alt, color: colors.warning),
                  title: const Text('عبور / رد کردن جلسه'),
                  onTap: () async {
                    Navigator.pop(context);
                    await _skipSessionWithDialog(session);
                  },
                ),
              ] else ...[
                ListTile(
                  leading: Icon(CupertinoIcons.arrow_counterclockwise, color: colors.warning),
                  title: const Text('لغو وضعیت تکمیل (بازگشت به معوقه)'),
                  onTap: () async {
                    Navigator.pop(context);
                    await _uncompleteSessionWithDialog(session);
                  },
                ),
                ListTile(
                  leading: Icon(CupertinoIcons.pencil, color: colors.primary),
                  title: const Text('ویرایش یادداشت و ارزیابی'),
                  onTap: () {
                    Navigator.pop(context);
                    SessionDebriefSheet.show(
                      context,
                      session: session,
                      actualDurationMinutes: session.actualDurationMinutes ?? _course.sessionDurationMinutes,
                      onCompleted: _loadCourseData,
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _skipSessionWithDialog(CourseSession session) async {
    final colors = context.colors;
    final controller = TextEditingController();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: colors.surface,
          title: const Text('عبور از جلسه'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('آیا می‌خواهید از ${session.sessionTitle ?? "این جلسه"} عبور کنید؟', style: TextStyle(color: colors.textSecondary, fontSize: 13)),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  labelText: 'دلیل عبور (اختیاری)',
                  hintText: 'مثلاً: قبلاً مسلط بودم / از منبع دیگر خواندم',
                  labelStyle: TextStyle(color: colors.textSecondary, fontSize: 12),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text('انصراف', style: TextStyle(color: colors.textSecondary))),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: colors.warning),
              child: const Text('عبور از جلسه', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (confirm ?? false) {
      await CoursesRepository.instance.skipSession(session.id, reason: controller.text.trim().isEmpty ? null : controller.text.trim());
      await _loadCourseData();
    }
  }

  Future<void> _uncompleteSessionWithDialog(CourseSession session) async {
    final colors = context.colors;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: colors.surface,
          title: const Text('لغو تکمیل جلسه'),
          content: const Text('آیا می‌خواهید این جلسه را از حالت تکمیل‌شده خارج کرده و به وضعیت در انتظار بازگردانید؟'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text('انصراف', style: TextStyle(color: colors.textSecondary))),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: colors.primary),
              child: const Text('تأیید بازگشت', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (confirm ?? false) {
      await CoursesRepository.instance.uncompleteSession(session.id);
      await _loadCourseData();
    }
  }

  Future<void> _handleReorder(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    setState(() {
      final item = _sessions.removeAt(oldIndex);
      _sessions.insert(newIndex, item);
    });

    final newOrderIds = _sessions.map((s) => s.id).toList();
    final res = await CoursesRepository.instance.reorderSessions(_course.id, newOrderIds);
    if (!res.isApplied && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('خطا در ذخیره ترتیب جدید جلسات'), backgroundColor: context.colors.error),
      );
      await _loadCourseData();
    }
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
    final overdueCount = CourseScheduler.daysBehind(sessions: _sessions, today: DateTime.now());
    final unscheduledCount = _sessions.where((s) => !s.isCompleted && !s.isSkipped && s.plannedDate == null).length;
    final adaptiveProposal = !_isProposalDismissed
        ? CourseAdaptiveEngine.proposeAdjustment(course: _course, sessions: _sessions, today: DateTime.now())
        : null;
    final hasRecentAdaptive = _course.adaptiveLastAppliedAt != null &&
        (DateTime.now().millisecondsSinceEpoch - _course.adaptiveLastAppliedAt!) < (24 * 60 * 60 * 1000);

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
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: colors.textPrimary,
            ),
          ),
          actions: [
            IconButton(
              icon: Icon(
                _isReordering ? CupertinoIcons.checkmark_circle_fill : CupertinoIcons.arrow_up_arrow_down,
                color: _isReordering ? colors.primary : colors.textPrimary,
              ),
              tooltip: _isReordering ? 'اتمام جابجایی' : 'تغییر ترتیب جلسات',
              onPressed: () => setState(() => _isReordering = !_isReordering),
            ),
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
        bottomNavigationBar: const FloatingTimerBar(),
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
                              fontSize: 12,
                              color: colors.textSecondary,
                            ),
                          ),
                          Text(
                            '${toPersianDigits(progressPercent)}٪',
                            style: TextStyle(
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

              // 2. Unscheduled sessions banner (Fixes N2)
              if (unscheduledCount > 0) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(CupertinoIcons.calendar_badge_minus, color: Colors.amber, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${RitmoNumber.toFa(unscheduledCount)} جلسه بدون تاریخ زمان‌بندی',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: colors.textPrimary),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'جلسات را بر اساس روزهای ترجیحی خود به صورت هوشمند زمان‌بندی کنید.',
                              style: TextStyle(fontSize: 11, color: colors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: _rescheduleUnscheduledSessions,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('زمان‌بندی خودکار 📅', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // 3. Adaptive Proposal Banner (Fixes H3 UI)
              if (adaptiveProposal != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: colors.primary.withValues(alpha: 0.4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(CupertinoIcons.sparkles, color: colors.primary, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'پیشنهاد هوشمند تنظیم ریتم مطالعه',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: colors.textPrimary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        adaptiveProposal.reasonFa,
                        style: TextStyle(fontSize: 11.5, color: colors.textSecondary),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => setState(() => _isProposalDismissed = true),
                            child: Text('رد پیشنهاد', style: TextStyle(fontSize: 11.5, color: colors.textSecondary)),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () => _applyAdaptiveProposal(adaptiveProposal),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: Text(
                              'اعمال (${RitmoNumber.toFa(adaptiveProposal.newWeeklyTarget)} جلسه/هفته)',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // 4. 24h Undo Banner for Adaptive Adjustment (Fixes H3 Rollback UI)
              if (hasRecentAdaptive) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.card.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: colors.border.withValues(alpha: 0.6)),
                  ),
                  child: Row(
                    children: [
                      Icon(CupertinoIcons.info_circle, color: colors.primary, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'ریتم این دوره اخیراً به صورت هوشمند تنظیم شده است.',
                          style: TextStyle(fontSize: 11, color: colors.textSecondary),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _rollbackAdaptive,
                        icon: const Icon(CupertinoIcons.arrow_counterclockwise, size: 13),
                        label: const Text('بازگردانی (Undo)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        style: TextButton.styleFrom(foregroundColor: colors.primary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // 5. Overdue / Catchup Banner
              if (overdueCount > 0) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: colors.warning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: colors.warning.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      Icon(CupertinoIcons.exclamationmark_triangle_fill, color: colors.warning, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${RitmoNumber.toFa(overdueCount)} جلسه از برنامه عقب هستید',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: colors.textPrimary),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'برای جلوگیری از فشار انباشتگی، برنامه جبرانی را فعال کنید.',
                              style: TextStyle(fontSize: 11, color: colors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () => RecoveryModeSheet.show(
                          context,
                          course: _course,
                          sessions: _sessions,
                          onApplied: _loadCourseData,
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colors.warning,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('برنامه جبرانی ⚡', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // 3. Linked Goal Card
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
                                  fontSize: 10,
                                  color: colors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _linkedGoal!['title'] as String,
                                style: TextStyle(
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
                                fontSize: 9,
                                color: colors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${toPersianDigits((_linkedGoalProgress * 100).round())}٪',
                              style: TextStyle(
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

              // 4. Weekly study configuration summary
              Text(
                'برنامه زمانی مطالعاتی',
                style: TextStyle(
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
                    _buildConfigItem('هدف هفتگی مطالعه', '${RitmoNumber.toFa(_course.weeklyTargetSessions)} جلسه در هفته', colors),
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
                          ? 'فعال در ساعت ${RitmoNumber.toFa(_course.preferredTime ?? "")}'
                          : 'غیرفعال',
                      colors,
                    ),
                    const Divider(height: 20),
                    _buildConfigItem(
                      'مرور فاصله‌دار (SM-2)',
                      _course.reviewEnabled ? 'فعال 🔄' : 'غیرفعال',
                      colors,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 5. Session list
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'سرفصل‌ها و جلسات دوره (${RitmoNumber.toFa(_sessions.length)})',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: colors.textPrimary,
                    ),
                  ),
                  if (_isReordering)
                    Text(
                      'جلسات را با لمس و کشیدن جابجا کنید',
                      style: TextStyle(fontSize: 11, color: colors.primary),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              if (_sessions.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: colors.card.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text('جلسه‌ای برای این دوره ثبت نشده است.', style: TextStyle(color: colors.textSecondary, fontSize: 13)),
                  ),
                )
              else if (_isReordering)
                ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _sessions.length,
                  // ignore: deprecated_member_use
                  onReorder: _handleReorder,
                  itemBuilder: (context, index) {
                    final session = _sessions[index];
                    return _buildSessionCard(session, colors, key: ValueKey(session.id), isDragMode: true);
                  },
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _sessions.length,
                  itemBuilder: (context, index) {
                    final session = _sessions[index];
                    return _buildSessionCard(session, colors, key: ValueKey(session.id), isDragMode: false);
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

  Widget _buildSessionCard(CourseSession session, RitmoColors colors, {required Key key, required bool isDragMode}) {
    final isCompleted = session.isCompleted;
    final isSkipped = session.isSkipped;
    final isReview = session.activityKind == CourseActivityKind.review || session.needsReview;

    return Container(
      key: key,
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: isCompleted
            ? colors.success.withValues(alpha: 0.04)
            : (isSkipped ? colors.textSecondary.withValues(alpha: 0.05) : colors.card.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCompleted
              ? colors.success.withValues(alpha: 0.2)
              : (isSkipped ? colors.textSecondary.withValues(alpha: 0.2) : colors.border.withValues(alpha: 0.5)),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: isDragMode ? null : () => _openSessionActionMenu(session),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                if (isDragMode) ...[
                  Icon(CupertinoIcons.bars, color: colors.textSecondary, size: 20),
                  const SizedBox(width: 10),
                ],
                // Status icon
                Icon(
                  isCompleted
                      ? CupertinoIcons.check_mark_circled_solid
                      : (isSkipped ? CupertinoIcons.slash_circle_fill : CupertinoIcons.circle),
                  color: isCompleted ? colors.success : (isSkipped ? colors.textSecondary : colors.textSecondary),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              session.sessionTitle ?? '${_course.unitLabelResolved} ${RitmoNumber.toFa(session.sessionNumber)}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isCompleted || isSkipped ? colors.textSecondary : colors.textPrimary,
                                decoration: isSkipped ? TextDecoration.lineThrough : null,
                              ),
                            ),
                          ),
                          if (isReview)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: colors.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text('مرور فاصله‌دار 🔄', style: TextStyle(fontSize: 9.5, color: colors.primary, fontWeight: FontWeight.bold)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            session.plannedDate != null
                                ? 'برنامه‌ریزی: ${CourseDate.dayKeyToJalaliDisplay(session.plannedDate!)} 📅'
                                : 'بدون تاریخ زمان‌بندی',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: isCompleted || isSkipped ? colors.textSecondary : colors.primary,
                            ),
                          ),
                          if (isCompleted && session.actualDurationMinutes != null) ...[
                            const SizedBox(width: 8),
                            Text(
                              '• مدت مطالعه: ${RitmoNumber.toFa(session.actualDurationMinutes ?? 0)} دقیقه',
                              style: TextStyle(
                                fontSize: 10.5,
                                color: colors.textSecondary,
                              ),
                            ),
                          ],
                          if (isSkipped && session.skipReason != null) ...[
                            const SizedBox(width: 8),
                            Text(
                              '• عبور داده شد: ${session.skipReason!}',
                              style: TextStyle(fontSize: 10.5, color: colors.textSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                if (!isCompleted && !isSkipped && !isDragMode)
                  IconButton(
                    icon: const Icon(CupertinoIcons.play_arrow_solid, size: 16),
                    color: colors.primary,
                    onPressed: () => _startSessionTimer(session),
                  ),
              ],
            ),
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
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: colors.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              'هنوز برداشتی ثبت نکرده‌ای. پس از هر جلسه، نکته‌های کلیدی و سوالات باز خود را ثبت کن.',
              style: TextStyle(fontSize: 12, color: colors.textSecondary),
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
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: colors.textPrimary),
          ),
          const SizedBox(height: 12),

          // 1. Key takeaways
          if (takeaways.isNotEmpty) ...[
            Text(
              '💡 نکته‌های کلیدی (${RitmoNumber.toFa(takeaways.length)})',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colors.primary),
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
                      '${s.keyTakeaway!} (جلسه ${RitmoNumber.toFa(s.sessionNumber)})',
                      textDirection: TextDirection.rtl,
                      style: TextStyle(fontSize: 12, color: colors.textPrimary),
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
              '❓ سؤال‌های باز (${RitmoNumber.toFa(questions.length)})',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colors.warning),
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
                        '${s.openQuestion!} (جلسه ${RitmoNumber.toFa(s.sessionNumber)})',
                        textDirection: TextDirection.rtl,
                        style: TextStyle(
                          fontSize: 12,
                          color: isResolved ? colors.textSecondary : colors.textPrimary,
                          decoration: isResolved ? TextDecoration.lineThrough : null,
                        ),
                      ),
                    ),
                    if (isResolved)
                      Text(
                        'حل شد ✓',
                        style: TextStyle(fontSize: 10, color: colors.success, fontWeight: FontWeight.bold),
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
              '📝 یادداشت‌های آزاد (${RitmoNumber.toFa(freeNotes.length)})',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colors.textSecondary),
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
                      '${s.note!} (جلسه ${RitmoNumber.toFa(s.sessionNumber)})',
                      textDirection: TextDirection.rtl,
                      style: TextStyle(fontSize: 12, color: colors.textPrimary),
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
          style: TextStyle(fontSize: 12, color: colors.textSecondary),
        ),
        Text(
          value,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colors.textPrimary),
        ),
      ],
    );
  }
}
