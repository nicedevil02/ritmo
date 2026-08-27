import 'dart:async';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ritmo/core/domain/personas/persona_registry.dart';
import 'package:ritmo/core/logging/ritmo_logger.dart';
import 'package:ritmo/core/modules/module_gate.dart';
import 'package:ritmo/core/analytics/courses_engine.dart';
import 'package:ritmo/core/services/feature_limits.dart';
import 'package:ritmo/core/services/module_management_service.dart';
import 'package:ritmo/core/utils/ritmo_toast.dart';
import 'package:ritmo/features/assistant/presentation/widgets/unified_assistant_sheet.dart';
import 'package:ritmo/features/premium/presentation/premium_upgrade_sheet.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/ux/ritmo_empty_state.dart';
import 'package:ritmo/core/ux/ritmo_skeleton.dart';
import 'package:ritmo/features/courses/logic/course_date_contract.dart';
import 'package:ritmo/features/courses/logic/courses_repository.dart';
import 'package:ritmo/features/courses/models/course_models.dart';
import 'package:ritmo/features/courses/presentation/course_detail_screen.dart';
import 'package:ritmo/features/courses/presentation/widgets/course_formatters.dart';
import 'package:ritmo/features/courses/presentation/widgets/active_courses_section.dart';
import 'package:ritmo/features/courses/presentation/widgets/ai_syllabus_sheet.dart';
import 'package:ritmo/features/courses/presentation/widgets/completed_courses_section.dart';
import 'package:ritmo/features/courses/presentation/widgets/courses_weekly_hero.dart';
import 'package:ritmo/features/courses/presentation/widgets/create_course_sheet.dart';
import 'package:ritmo/features/courses/presentation/widgets/floating_timer_bar.dart';
import 'package:ritmo/features/courses/presentation/widgets/jalali_weekly_heatmap.dart';
import 'package:ritmo/features/courses/presentation/widgets/today_sessions_section.dart';
import 'package:ritmo/features/courses/presentation/widgets/what_to_read_now_card.dart';

class CoursesScreen extends StatefulWidget {
  const CoursesScreen({super.key});

  @override
  State<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends State<CoursesScreen> {
  bool _isLoading = true;
  List<Course> _activeCourses = [];
  List<Course> _completedCourses = [];
  List<Course> _archivedCourses = [];
  final Map<String, List<CourseSession>> _courseSessionsMap = {};

  String _currentEnergyLevel = 'MEDIUM';
  CoursesEngineOutput? _engineOutput;
  final CoursesEngine _engine = CoursesEngine();

  bool _coursesEnabled = true;
  StreamSubscription<dynamic>? _eventSub;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _loadAllData();
    _eventSub = CoursesRepository.instance.events.listen((_) {
      _engine.invalidate();
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 300), () {
        if (mounted) {
          _loadAllData();
        }
      });
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _eventSub?.cancel();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      _coursesEnabled = ModuleGate.instance.isEnabled('module_courses_enabled');

      // 1. Fetch real dynamic energy level today (Fixes D-8)
      _currentEnergyLevel = await CoursesRepository.instance.getCurrentEnergyLevel();

      // 2. Fetch active, completed, and archived courses (Fixes N1)
      _activeCourses = await CoursesRepository.instance.getActiveCourses();
      _completedCourses = await CoursesRepository.instance.getCompletedCourses();
      _archivedCourses = await CoursesRepository.instance.getArchivedCourses();

      final allCourses = [..._activeCourses, ..._completedCourses, ..._archivedCourses];

      _courseSessionsMap.clear();
      final courseIds = allCourses.map((c) => c.id).toSet();
      final sessionsBatchMap = await CoursesRepository.instance.getSessionsForCourses(courseIds);
      _courseSessionsMap.addAll(sessionsBatchMap);
      final allSessions = sessionsBatchMap.values.expand((element) => element).toList();

      // 4. Run cached CoursesEngine (Fixes M13)
      if (allCourses.isNotEmpty) {
        _engineOutput = await _engine.calculate(
          CoursesEngineInput(
            courses: allCourses,
            sessions: allSessions,
            currentEnergyLevel: _currentEnergyLevel,
            today: DateTime.now(),
          ),
        );
      } else {
        _engineOutput = null;
      }
    } catch (e, st) {
      RitmoLog.error('COURSES', 'Error loading courses data', e, st);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _openCreateCourseSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => CreateCourseSheet(
        onCourseCreated: _loadAllData,
      ),
    );
  }

  void _openAiAssistantSheet() {
    unawaited(
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (context) => AssistantSheet(persona: PersonaRegistry.instance.getPersona('courses')!),
      ),
    );
  }

  void _openAiSyllabusSheet() {
    unawaited(
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (context) => AiSyllabusSheet(
          onImported: _loadAllData,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    // can() always returns true — no paywall

    if (!_coursesEnabled) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: colors.bg,
          appBar: AppBar(
            title: const Text('دوره‌های آموزشی'),
            elevation: 0,
            backgroundColor: Colors.transparent,
          ),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(CupertinoIcons.pause_circle_fill, size: 64, color: Colors.orange),
                  const SizedBox(height: 16),
                  Text(
                    'سیستم غیرفعال است',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colors.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'ماژول دوره‌های آموزشی در تنظیمات سیستم‌ها غیرفعال شده است.',
                    style: TextStyle(fontSize: 13, color: colors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () async {
                      final result = await ModuleManagementService.instance.setModuleEnabled('module_courses_enabled', true);
                      if (!mounted) return;
                      if (result == ModuleToggleResult.limitReached) {
                        final limit = FeatureLimits.current.maxActiveModules;
                        RitmoToast.show(
                          this.context,
                          'سقف $limit ماژول فعال همزمان پر شده. ابتدا یک ماژول دیگر را غیرفعال کنید یا به ریتمو پلاس ارتقا دهید.',
                          icon: Icons.lock_outline,
                        );
                        unawaited(PremiumUpgradeSheet.show(this.context));
                        return;
                      } else if (result == ModuleToggleResult.error) {
                        RitmoToast.show(
                          this.context,
                          'خطا در فعال‌سازی سیستم. لطفاً دوباره تلاش کنید.',
                          icon: Icons.error_outline,
                        );
                        return;
                      }
                      await _loadAllData();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('فعال‌سازی سیستم دوره‌ها'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final todayStr = CourseDate.toDayKey(DateTime.now());
    final allSessions = _courseSessionsMap.values.expand((e) => e).toList();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topPadding = MediaQuery.paddingOf(context).top;
    final contentTopPadding = topPadding + 76.0;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: colors.bg,
        body: Stack(
          children: [
            // Layer 1: Body Content
            Positioned.fill(
              child: RefreshIndicator(
                onRefresh: _loadAllData,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(16, contentTopPadding, 16, 100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Floating Timer Bar Widget (Fixes D-9 & 7.3)
                      const FloatingTimerBar(),
                      const SizedBox(height: 12),
                      if (_isLoading) ...[
                        const RitmoSkeletonCard(height: 150),
                        const SizedBox(height: 24),
                        const RitmoSkeletonList(itemCount: 3, itemHeight: 90),
                      ] else if (_activeCourses.isEmpty && _completedCourses.isEmpty && _archivedCourses.isEmpty) ...[
                        RitmoEmptyState(
                          icon: CupertinoIcons.book,
                          title: 'هنوز هیچ دوره‌ای ایجاد نکرده‌اید',
                          description: 'کتاب‌ها، مهارت‌ها و اهداف یادگیری خود را در قالب دوره ثبت کنید تا روند پیشرفت مطالعه خود را ردیابی کنید.',
                          ctaLabel: 'ایجاد اولین دوره',
                          onCta: _openCreateCourseSheet,
                        ),
                      ] else ...[
                        // 1. "What to Read Now" Single Decision Hero Card (Fixes 7.2)
                        if (_activeCourses.isNotEmpty) ...[
                          WhatToReadNowCard(
                            courses: _activeCourses,
                            sessionsMap: _courseSessionsMap,
                            currentEnergyLevel: _currentEnergyLevel,
                            todayStr: todayStr,
                            onStartSession: _loadAllData,
                          ),
                          const SizedBox(height: 16),
                        ],

                        // 2. Weekly aggregates card
                        if (_engineOutput != null)
                          CoursesWeeklyHero(
                            weeklyDoneSessions: _engineOutput!.weeklyDoneSessions,
                            weeklyTargetSessions: _engineOutput!.weeklyTargetSessions,
                            weeklyStudyMinutes: _engineOutput!.weeklyStudyMinutes,
                            studyStreakDays: _engineOutput!.studyStreakDays,
                            estimatedMinutesIncluded: _engineOutput!.estimatedMinutesIncluded,
                          ),

                        const SizedBox(height: 16),

                        // 3. Jalali Weekly Heatmap Widget (Fixes 7.5)
                        JalaliWeeklyHeatmap(
                          sessions: allSessions,
                          today: DateTime.now(),
                        ),

                        const SizedBox(height: 24),

                        // 4. Today's Sessions Section
                        if (_engineOutput != null)
                          TodaySessionsSection(
                            todaySessions: _engineOutput!.todaySessions,
                            courses: [..._activeCourses, ..._completedCourses],
                            currentEnergyLevel: _currentEnergyLevel,
                            onRefresh: _loadAllData,
                          ),

                        // 5. Active Courses List
                        ActiveCoursesSection(
                          courses: _activeCourses,
                          courseSessionsMap: _courseSessionsMap,
                          onCourseTap: (course) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => CourseDetailScreen(course: course),
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 24),

                        // 6. Completed and Archived Courses List (Fixes N1)
                        CompletedCoursesSection(
                          completedCourses: _completedCourses,
                          archivedCourses: _archivedCourses,
                          courseSessionsMap: _courseSessionsMap,
                          onRefresh: _loadAllData,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            // Layer 2: Floating Capsule Header Island
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
                  child: _buildCapsuleHeader(context, isDark, colors),
                ),
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _openCreateCourseSheet,
          backgroundColor: colors.primary,
          child: const Icon(CupertinoIcons.add, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildCapsuleHeader(
    BuildContext context,
    bool isDark,
    RitmoColors colors,
  ) {
    final capsuleBgColor = isDark
        ? const Color(0xFF1E222A).withValues(alpha: 0.86)
        : Colors.white.withValues(alpha: 0.88);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.white.withValues(alpha: 0.90);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.50)
                : const Color(0xFFCBD5E1).withValues(alpha: 0.65),
            offset: const Offset(0, 5),
            blurRadius: 14,
            spreadRadius: 0,
          ),
          BoxShadow(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.white.withValues(alpha: 0.90),
            offset: const Offset(0, -1),
            blurRadius: 3,
            spreadRadius: 0,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: capsuleBgColor,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(
                color: borderColor,
                width: 1.0,
              ),
            ),
            child: Row(
              children: [
                if (Navigator.canPop(context))
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 38,
                      minHeight: 38,
                    ),
                    icon: Icon(
                      CupertinoIcons.arrow_right,
                      color: isDark ? Colors.white : const Color(0xFF1D2129),
                      size: 20,
                    ),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      Navigator.pop(context);
                    },
                  )
                else
                  const SizedBox(width: 10),
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        'دوره‌های آموزشی',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 17.5,
                          letterSpacing: -0.4,
                          color: isDark ? Colors.white : const Color(0xFF1D2129),
                        ),
                      ),
                      if (_activeCourses.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: colors.primary.withValues(alpha: isDark ? 0.22 : 0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: colors.primary.withValues(alpha: isDark ? 0.35 : 0.25),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            '${toPersianDigits(_activeCourses.length)} فعال',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: colors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                _buildHeaderActionButton(
                  icon: CupertinoIcons.sparkles,
                  iconColor: colors.primary,
                  isAiButton: true,
                  isDark: isDark,
                  tooltip: 'دستیار هوشمند دوره‌ها',
                  onTap: _openAiAssistantSheet,
                ),
                _buildHeaderActionButton(
                  icon: CupertinoIcons.doc_on_clipboard_fill,
                  iconColor: const Color(0xFF8B5CF6),
                  isDark: isDark,
                  tooltip: 'ورود سرفصل AI',
                  onTap: _openAiSyllabusSheet,
                ),
                _buildHeaderActionButton(
                  icon: CupertinoIcons.plus,
                  iconColor: isDark ? Colors.white : const Color(0xFF1D2129),
                  isDark: isDark,
                  tooltip: 'ایجاد دوره جدید',
                  onTap: _openCreateCourseSheet,
                ),
                const SizedBox(width: 2),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderActionButton({
    required IconData icon,
    required Color iconColor,
    required bool isDark,
    required VoidCallback onTap,
    String? tooltip,
    bool isAiButton = false,
  }) {
    final button = GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: _buildHeaderActionButtonContent(
        icon: icon,
        iconColor: iconColor,
        isDark: isDark,
        isAiButton: isAiButton,
      ),
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip, child: button);
    }
    return button;
  }

  Widget _buildHeaderActionButtonContent({
    required IconData icon,
    required Color iconColor,
    required bool isDark,
    bool isAiButton = false,
  }) {
    return Container(
      width: 36,
      height: 36,
      margin: const EdgeInsets.symmetric(horizontal: 3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDark
            ? (isAiButton
                ? iconColor.withValues(alpha: 0.18)
                : const Color(0xFF22262E))
            : (isAiButton
                ? iconColor.withValues(alpha: 0.12)
                : const Color(0xFFF3F5F8)),
        border: Border.all(
          color: isDark
              ? (isAiButton
                  ? iconColor.withValues(alpha: 0.40)
                  : Colors.white.withValues(alpha: 0.08))
              : (isAiButton
                  ? iconColor.withValues(alpha: 0.30)
                  : Colors.white.withValues(alpha: 0.90)),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.white.withValues(alpha: 0.04)
                : Colors.white.withValues(alpha: 0.95),
            offset: const Offset(-2, -2),
            blurRadius: 4,
          ),
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.55)
                : const Color(0xFFB5C0CD).withValues(alpha: 0.65),
            offset: const Offset(2, 2),
            blurRadius: 4,
          ),
          if (isAiButton)
            BoxShadow(
              color: iconColor.withValues(alpha: isDark ? 0.35 : 0.22),
              blurRadius: 10,
              spreadRadius: 1.0,
            ),
        ],
      ),
      child: Center(
        child: Icon(
          icon,
          size: 18,
          color: isAiButton
              ? iconColor
              : (isDark ? const Color(0xFF9096A2) : const Color(0xFF6B7280)),
        ),
      ),
    );
  }
}
