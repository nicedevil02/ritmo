import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
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
  final ValueNotifier<double> _scrollOffset = ValueNotifier<double>(0.0);

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
    _scrollOffset.dispose();
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
    final contentTopPadding = topPadding + 130.0;

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
                child: NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    if (notification.metrics.axis == Axis.vertical) {
                      _scrollOffset.value = notification.metrics.pixels;
                    }
                    return false;
                  },
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
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

                          const SizedBox(height: 24),

                          // 5. Active Courses List (Fixes 7.1)
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
            ),

            // Layer 2: Apple Dynamic Large Title Morphing Glass Header (Unified Single Capsule)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: AnimatedBuilder(
                animation: _scrollOffset,
                builder: (context, _) {
                  return RitmoAppleMorphingGlassHeader(
                    title: 'دوره‌های آموزشی',
                    subtitle: 'یادگیری مستمر، جلسات مطالعه و مدیریت سرفصل‌ها',
                    scrollOffset: _scrollOffset.value,
                    collapseDistance: 55.0,
                    onBack: () => Navigator.maybePop(context),
                    statusBadge: _activeCourses.isNotEmpty
                        ? Container(
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
                          )
                        : null,
                    actions: [
                      RitmoVibrancyActionButton(
                        icon: CupertinoIcons.sparkles,
                        iconColor: colors.primary,
                        isAiButton: true,
                        accentColor: colors.primary,
                        tooltip: 'دستیار هوشمند دوره‌ها',
                        onTap: _openAiAssistantSheet,
                      ),
                      const SizedBox(width: 8),
                      RitmoVibrancyActionButton(
                        icon: CupertinoIcons.doc_on_clipboard_fill,
                        iconColor: const Color(0xFF8B5CF6),
                        tooltip: 'ورود سرفصل AI',
                        onTap: _openAiSyllabusSheet,
                      ),
                      const SizedBox(width: 8),
                      RitmoVibrancyActionButton(
                        icon: CupertinoIcons.plus,
                        iconColor: isDark ? Colors.white : const Color(0xFF1D2129),
                        tooltip: 'ایجاد دوره جدید',
                        onTap: _openCreateCourseSheet,
                      ),
                    ],
                  );
                },
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
}
