import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:persian_datetime_picker/persian_datetime_picker.dart';
import 'package:ritmo/core/analytics/assistant_engine.dart';
import 'package:ritmo/core/analytics/konkur_engine.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/domain/models/energy_context.dart';
import 'package:ritmo/core/domain/personas/persona_registry.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/cycle_privacy_guard.dart';
import 'package:ritmo/core/utils/ritmo_date_picker.dart';
import 'package:ritmo/core/utils/ritmo_toast.dart';
import 'package:ritmo/core/ux/ritmo_directional_icon.dart';
import 'package:ritmo/core/ux/ritmo_empty_state.dart';
import 'package:ritmo/core/ux/ritmo_skeleton.dart';
import 'package:ritmo/features/assistant/presentation/widgets/unified_assistant_sheet.dart';
import 'package:ritmo/features/konkur/logic/konkur_planner.dart';
import 'package:ritmo/features/konkur/logic/konkur_repository.dart';
import 'package:ritmo/features/konkur/models/konkur_models.dart';
import 'package:ritmo/features/konkur/presentation/widgets/konkur_budget_section.dart';
import 'package:ritmo/features/konkur/presentation/widgets/konkur_exams_section.dart';
import 'package:ritmo/features/konkur/presentation/widgets/konkur_field_picker_sheet.dart';
import 'package:ritmo/features/konkur/presentation/widgets/konkur_formatters.dart';
import 'package:ritmo/features/konkur/presentation/widgets/konkur_hero.dart';
import 'package:ritmo/features/konkur/presentation/widgets/konkur_setup_flow.dart';
import 'package:ritmo/features/konkur/presentation/widgets/konkur_stats_section.dart';
import 'package:ritmo/features/konkur/presentation/widgets/konkur_today_section.dart';
import 'package:ritmo/features/study/data/study_settings_repository.dart';
import 'package:ritmo/features/study/study_module_entry.dart';

class KonkurScreen extends StatefulWidget {
  const KonkurScreen({super.key, this.onSwitchToStudyMode});

  final VoidCallback? onSwitchToStudyMode;

  @override
  State<KonkurScreen> createState() => _KonkurScreenState();
}

class _KonkurScreenState extends State<KonkurScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ValueNotifier<double> _scrollOffset = ValueNotifier<double>(0.0);
  final ValueNotifier<bool> _isTabsExpanded = ValueNotifier<bool>(true);
  double _accumulatedUpScroll = 0.0;

  // DB Data
  bool _isLoading = true;
  bool _setupDone = false;
  bool _startSetup = false;

  List<KonkurSubject> _subjects = [];
  List<KonkurTopic> _topics = [];
  List<KonkurStudySession> _sessions = [];
  List<KonkurMockExam> _mockExams = [];
  List<KonkurMockResult> _mockResults = [];
  List<KonkurPlanItem> _planItems = [];
  List<KonkurPlanItem> _carryOverItems = [];
  Map<String, String> _settings = {};

  KonkurEngineOutput? _engineOutput;
  EnergyContext? _energyContext;
  bool _isEnergyBannerDismissed = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollOffset.dispose();
    _isTabsExpanded.dispose();
    super.dispose();
  }

  Future<void> _seedAndReload(KonkurField field) async {
    setState(() => _isLoading = true);
    await KonkurRepository.instance.seedCurriculum(field);
    await _loadAllData();
  }

  Future<void> _showFieldPicker() async {
    final selectedField = await KonkurFieldPickerSheet.show(context);
    if (selectedField != null) {
      await _seedAndReload(selectedField);
    }
  }

  Color _colorForField(KonkurField field) => switch (field) {
    KonkurField.riyazi  => const Color(0xFF3B82F6),
    KonkurField.tajrobi => const Color(0xFF10B981),
    KonkurField.ensani  => const Color(0xFFF59E0B),
    KonkurField.honar   => const Color(0xFFEC4899),
    KonkurField.zaban   => const Color(0xFF8B5CF6),
  };

  String _labelForField(KonkurField field) => switch (field) {
    KonkurField.riyazi  => '📐 رشته ریاضی',
    KonkurField.tajrobi => '🧬 رشته تجربی',
    KonkurField.ensani  => '📚 رشته انسانی',
    KonkurField.honar   => '🎨 رشته هنر',
    KonkurField.zaban   => '🗣️ رشته زبان',
  };

  Widget _buildEmptyCurriculumState(BuildContext context, RitmoColors colors) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🎓', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            Text(
              'رشته خودت رو انتخاب کن',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'سرفصل‌های کامل کنکور به صورت خودکار اضافه میشه',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: 32),
            ...KonkurField.values.map((field) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _seedAndReload(field),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _colorForField(field),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(
                    _labelForField(field),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildEnergyBanner(RitmoColors colors) {
    if (_isEnergyBannerDismissed || _energyContext == null || _energyContext!.farsiNote.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.amber.shade700.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade600.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.bolt_outlined, color: Colors.amber.shade800, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _energyContext!.farsiNote,
              style: TextStyle(
                fontSize: 12,
                color: colors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, size: 16, color: colors.textSecondary),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () {
              setState(() {
                _isEnergyBannerDismissed = true;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCarryOverBanner() {
    if (_carryOverItems.isEmpty) return const SizedBox.shrink();

    final colors = context.colors;
    final countStr = toPersianDigits(_carryOverItems.length.toString());

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.warning.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(Icons.history, color: colors.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$countStr آیتم مطالعاتی از روزهای قبل باقی مانده — به امروز منتقل شود؟',
              style: TextStyle(fontSize: 12, color: colors.textPrimary),
            ),
          ),
          TextButton(
            onPressed: () => _applyCarryForward(_carryOverItems),
            child: Text('انتقال', style: TextStyle(fontWeight: FontWeight.bold, color: colors.primary)),
          ),
        ],
      ),
    );
  }

  Future<void> _applyCarryForward(List<KonkurPlanItem> overdue) async {
    final repo = KonkurRepository.instance;
    final todayAllocated = await repo.getTodayPlannedMinutes();
    final dailyTargetStr = _settings['konkur_daily_target_minutes'] ?? '180';
    final dailyTargetMinutes = int.tryParse(dailyTargetStr) ?? 180;

    final carried = KonkurPlanner.carryForward(
      overdueItems: overdue,
      today: DateTime.now(),
      dailyTargetMinutes: dailyTargetMinutes,
      alreadyAllocatedMinutes: todayAllocated,
    );

    if (carried.isEmpty) {
      if (mounted) {
        RitmoToast.show(context, 'ظرفیت امروز پر است', icon: Icons.warning_amber_rounded, iconColor: context.colors.warning);
      }
      return;
    }

    for (final item in carried) {
      await repo.insertPlanItem(item);
    }
    // Mark originals as SKIPPED
    for (final item in overdue) {
      await repo.updatePlanItemStatus(item.id, 'SKIPPED');
    }

    if (mounted) {
      RitmoToast.show(context, '${toPersianDigits(carried.length.toString())} آیتم با موفقیت به امروز منتقل شدند', icon: Icons.check_circle_outline, iconColor: context.colors.success);
      setState(() {
        _carryOverItems = [];
      });
      await _loadAllData();
    }
  }

  Future<void> _loadAllData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final repo = KonkurRepository.instance;
      
      // 1. Load settings and check setup status
      _settings = await repo.getAppSettings();
      _setupDone = _settings['konkur_setup_done'] == 'true';

      if (_setupDone) {
        // 2. Load all records
        _subjects = await repo.getSubjects();
        _topics = await repo.getTopics();
        _sessions = await repo.getStudySessions();
        _mockExams = await repo.getMockExams();
        _mockResults = await repo.getMockResults();
        _planItems = await repo.getPlanItems();
        _carryOverItems = await repo.getPendingCarryOverItems();

        // Auto-seed if field set but no subjects present
        final fieldStr = _settings['konkur_field'] ?? 'RIYAZI';
        if (_subjects.isEmpty && fieldStr != 'UNSET') {
          final field = KonkurField.fromString(fieldStr);
          await repo.seedCurriculum(field);
          _subjects = await repo.getSubjects();
          _topics = await repo.getTopics();
        }

        // 3. Run KonkurEngine locally
        final engine = KonkurEngine();
        _engineOutput = await engine.calculate(
          KonkurEngineInput(
            subjects: _subjects,
            topics: _topics,
            sessions: _sessions,
            mockExams: _mockExams,
            mockResults: _mockResults,
            examDateIso: _settings['konkur_exam_date'],
            today: DateTime.now(),
            planItems: _planItems,
          ),
        );

        // 4. Calculate AssistantEngine output for EnergyContext
        final db = await DatabaseHelper.instance.database;
        final energyLogs = await db.query('energy_logs', orderBy: 'loggedAt DESC', limit: 10);
        final sleepLogs = await db.query('bedtime_diagnostics', orderBy: 'date DESC', limit: 10);
        final isFemale = CyclePrivacyGuard.isVisible(_settings);
        final cycleConsent = _settings['cycle_consent_dashboard'] == 'true';
        final isEnergyTuned = _settings['cycle_setup_done'] == 'true';

        final assistantOutput = await AssistantEngine().calculate(
          AssistantEngineInput(
            routines: const [],
            routineCompletions: const [],
            sleepLogs: sleepLogs,
            energyLogs: energyLogs,
            moodLogs: const [],
            goals: const [],
            goalSteps: const [],
            konkurStudySessions: const [],
            today: DateTime.now(),
            isUserFemale: isFemale,
            cycleConsent: cycleConsent,
            isEnergyTuned: isEnergyTuned,
          ),
        );
        _energyContext = assistantOutput.todayEnergyContext;
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // SETTINGS BOTTOM SHEET
  void _showSettingsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return _KonkurSettingsSheet(
          initialExamDateIso: _settings['konkur_exam_date'] ?? '',
          initialDailyTargetMinutes: int.tryParse(_settings['konkur_daily_target_minutes'] ?? '180') ?? 180,
          initialShowInDashboard: _settings['konkur_show_in_dashboard'] == 'true',
          onSaved: _loadAllData,
          onOpenCurriculumPicker: _showFieldPicker,
          onSwitchToStudyMode: _switchToStudyMode,
          onReset: () async {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('ریست کامل اطلاعات کنکور؟', style: TextStyle(color: Colors.red)),
                content: const Text(
                  'آیا مطمئن هستید؟ این عمل تمام دروس، سرفصل‌ها، آزمون‌ها، اهداف روزانه و تنظیمات ماژول کنکور شما را پاک خواهد کرد. این عمل غیرقابل بازگشت است.',
                  style: TextStyle(),
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('انصراف', style: TextStyle())),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('بله، ریست کن', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            );

            if (confirm ?? false) {
              await KonkurRepository.instance.resetKonkurModule();
              if (!context.mounted) return;
              Navigator.pop(context); // Close settings sheet
              await _loadAllData(); // Refresh page (will show setup flow)
            }
          },
        );
      },
    );
  }

  // AI ASSISTANT SHEET
  void _showAiAssistantSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return AssistantSheet(persona: PersonaRegistry.instance.getPersona('konkur')!);
      },
    );
  }

  Future<void> _switchToStudyMode() async {
    if (widget.onSwitchToStudyMode != null) {
      widget.onSwitchToStudyMode!();
      return;
    }
    if (!mounted) return;
    await StudyModuleEntry.switchMode(context, konkur: false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    if (_isLoading && !_setupDone) {
      return Scaffold(
        backgroundColor: colors.bg,
        body: Center(
          child: CircularProgressIndicator(color: colors.primary),
        ),
      );
    }

    if (!_setupDone) {
      return Scaffold(
        backgroundColor: colors.bg,
        appBar: AppBar(
          title: const Text('کنکور', style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: RitmoIcons.back(context, color: colors.textPrimary),
            onPressed: () {
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              } else {
                _switchToStudyMode();
              }
            },
          ),
          actions: [
            TextButton.icon(
              onPressed: _switchToStudyMode,
              icon: const Icon(Icons.menu_book_outlined, size: 18),
              label: const Text(
                'حالت مطالعه',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        body: Directionality(
          textDirection: TextDirection.rtl,
          child: _startSetup
              ? KonkurSetupFlow(
                  onSetupCompleted: _loadAllData,
                  onCancel: () => setState(() => _startSetup = false),
                  onSwitchToStudyMode: _switchToStudyMode,
                )
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Expanded(
                        child: RitmoEmptyState(
                          icon: Icons.school_outlined,
                          title: 'ماژول کنکور فعال نشده است',
                          description:
                              'برای دسترسی به زمان‌بندی هوشمند مطالعه، تحلیل کارنامه‌های آزمون آزمایشی و بودجه‌بندی دروس کنکور، مشخصات خود را وارد کنید.',
                          ctaLabel: 'تنظیم و فعال‌سازی کنکور',
                          onCta: () => setState(() => _startSetup = true),
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _switchToStudyMode,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          foregroundColor: colors.textPrimary,
                          side: BorderSide(color: colors.primary.withValues(alpha: 0.5)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(Icons.arrow_back_rounded, size: 18),
                        label: const Text(
                          'بازگشت به حالت مطالعه عادی',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
        ),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topPadding = MediaQuery.paddingOf(context).top;
    final contentTopPadding = topPadding + 190.0;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: colors.bg,
        body: Stack(
          children: [
            // Layer 1: Body Content (NotificationListener for Instant Quick-Return Header)
            Positioned.fill(
              child: _isLoading
                  ? Padding(
                      padding: EdgeInsets.fromLTRB(16, contentTopPadding, 16, 80),
                      child: const Column(
                        children: [
                          RitmoSkeletonCard(height: 180),
                          SizedBox(height: 24),
                          RitmoSkeletonList(itemCount: 3, itemHeight: 70),
                        ],
                      ),
                    )
                  : _subjects.isEmpty
                      ? Padding(
                          padding: EdgeInsets.only(top: contentTopPadding),
                          child: _buildEmptyCurriculumState(context, colors),
                        )
                      : _engineOutput == null
                          ? Center(
                              child: Padding(
                                padding: EdgeInsets.only(top: contentTopPadding),
                                child: const Text('خطا در بارگذاری خروجی موتور کنکور'),
                              ),
                            )
                          : NotificationListener<ScrollNotification>(
                              onNotification: (notification) {
                                if (notification.metrics.axis == Axis.vertical) {
                                  final pixels = notification.metrics.pixels;
                                  _scrollOffset.value = pixels;

                                  if (pixels <= 20) {
                                    _accumulatedUpScroll = 0.0;
                                    if (!_isTabsExpanded.value) _isTabsExpanded.value = true;
                                  } else if (notification is ScrollUpdateNotification) {
                                    final delta = notification.scrollDelta ?? 0.0;
                                    if (delta > 1.0) {
                                      // اسکرول پیوسته و بدون وقفه به سمت پایین
                                      _accumulatedUpScroll = 0.0;
                                      if (pixels > 75 && _isTabsExpanded.value) {
                                        _isTabsExpanded.value = false;
                                      }
                                    } else if (delta < -1.0) {
                                      // اسکرول رو به بالا با آستانه هوشمند برای حذف لرزش دست
                                      _accumulatedUpScroll += -delta;
                                      if (_accumulatedUpScroll > 28.0 && !_isTabsExpanded.value) {
                                        _isTabsExpanded.value = true;
                                      }
                                    }
                                  } else if (notification is ScrollEndNotification) {
                                    _accumulatedUpScroll = 0.0;
                                  }
                                }
                                return false;
                              },
                              child: TabBarView(
                                controller: _tabController,
                                physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                                children: [
                                  // 1. TODAY / PLAN SECTION
                                  SingleChildScrollView(
                                    physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                                    padding: EdgeInsets.fromLTRB(16, contentTopPadding, 16, 100),
                                    child: Column(
                                      children: [
                                        _buildEnergyBanner(colors),
                                        KonkurHero(
                                          data: _engineOutput!,
                                          onSetDateTap: _showSettingsSheet,
                                        ),
                                        const SizedBox(height: 12),
                                        _buildCarryOverBanner(),
                                        KonkurTodaySection(
                                          subjects: _subjects,
                                          topics: _topics,
                                          todayPlanItems: _engineOutput!.todayPlanItems,
                                          onRefresh: _loadAllData,
                                          energyContext: _energyContext,
                                        ),
                                      ],
                                    ),
                                  ),

                                  // 2. BUDGET / TOPICS SECTION
                                  SingleChildScrollView(
                                    physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                                    padding: EdgeInsets.fromLTRB(16, contentTopPadding, 16, 100),
                                    child: KonkurBudgetSection(
                                      subjects: _subjects,
                                      topics: _topics,
                                      budgetCoverage: _engineOutput!.budgetCoverage,
                                      perSubjectReadiness: _engineOutput!.perSubjectReadiness,
                                      onRefresh: _loadAllData,
                                    ),
                                  ),

                                  // 3. EXAMS SECTION
                                  SingleChildScrollView(
                                    physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                                    padding: EdgeInsets.fromLTRB(16, contentTopPadding, 16, 100),
                                    child: KonkurExamsSection(
                                      subjects: _subjects,
                                      mockExams: _mockExams,
                                      mockResults: _mockResults,
                                      perSubjectTrend: _engineOutput!.perSubjectTrend,
                                      onRefresh: _loadAllData,
                                    ),
                                  ),

                                  // 4. STATS SECTION
                                  SingleChildScrollView(
                                    physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                                    padding: EdgeInsets.fromLTRB(16, contentTopPadding, 16, 100),
                                    child: KonkurStatsSection(
                                      subjects: _subjects,
                                      data: _engineOutput!,
                                    ),
                                  ),
                                ],
                              ),
                            ),
            ),

            // Layer 2: Apple Dynamic Large Title Morphing Glass Header (Unified Single Capsule)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: AnimatedBuilder(
                animation: Listenable.merge([_scrollOffset, _isTabsExpanded]),
                builder: (context, _) {
                  final fieldStr = _settings['konkur_field'] ?? 'RIYAZI';
                  final field = KonkurField.fromString(fieldStr);
                  final fieldColor = _colorForField(field);
                  final days = _engineOutput?.daysUntilExam ?? -1;

                  return RitmoAppleMorphingGlassHeader(
                    title: 'کنکور و مطالعه',
                    subtitle: _engineOutput != null && days >= 0
                        ? '${_labelForField(field)} • $days روز تا کنکور'
                        : 'مدیریت جامع آزمون‌ها، بودجه‌بندی و هوش تحلیلی',
                    scrollOffset: _scrollOffset.value,
                    isTabsExpanded: _isTabsExpanded.value,
                    collapseDistance: 55.0,
                    onBack: () {
                      if (Navigator.canPop(context)) {
                        Navigator.pop(context);
                      } else {
                        _switchToStudyMode();
                      }
                    },
                    actions: [
                      RitmoVibrancyActionButton(
                        icon: CupertinoIcons.sparkles,
                        iconColor: colors.primary,
                        isAiButton: true,
                        accentColor: colors.primary,
                        tooltip: 'دستیار هوش مصنوعی کنکور',
                        onTap: _showAiAssistantSheet,
                      ),
                      const SizedBox(width: 8),
                      RitmoVibrancyActionButton(
                        icon: CupertinoIcons.square_grid_2x2_fill,
                        iconColor: fieldColor,
                        tooltip: 'سرفصل‌ها و رشته کنکور',
                        onTap: _showFieldPicker,
                      ),
                      const SizedBox(width: 8),
                      RitmoVibrancyActionButton(
                        icon: CupertinoIcons.book_fill,
                        iconColor: isDark ? const Color(0xFF9096A2) : const Color(0xFF6B7280),
                        tooltip: 'حالت مطالعه عادی',
                        onTap: _switchToStudyMode,
                      ),
                      const SizedBox(width: 8),
                      RitmoVibrancyActionButton(
                        icon: CupertinoIcons.gear_alt_fill,
                        iconColor: isDark ? const Color(0xFF9096A2) : const Color(0xFF6B7280),
                        tooltip: 'تنظیمات کنکور',
                        onTap: _showSettingsSheet,
                      ),
                    ],
                    tabs: RitmoGlassSegmentedControl<int>(
                      items: const [
                        RitmoTabItem(
                          title: 'امروز',
                          icon: CupertinoIcons.today_fill,
                          value: 0,
                        ),
                        RitmoTabItem(
                          title: 'بودجه‌بندی',
                          icon: CupertinoIcons.chart_pie_fill,
                          value: 1,
                        ),
                        RitmoTabItem(
                          title: 'کارنامه',
                          icon: CupertinoIcons.doc_checkmark_fill,
                          value: 2,
                        ),
                        RitmoTabItem(
                          title: 'آمار',
                          icon: CupertinoIcons.chart_bar_square_fill,
                          value: 3,
                        ),
                      ],
                      selectedIndex: _tabController.index.clamp(0, 3),
                      onTabChanged: (index) {
                        _tabController.animateTo(index);
                        setState(() {});
                      },
                      accentColor: colors.primary,
                      height: 46.0,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// SETTINGS SHEET
class _KonkurSettingsSheet extends StatefulWidget {

  const _KonkurSettingsSheet({
    required this.initialExamDateIso,
    required this.initialDailyTargetMinutes,
    required this.initialShowInDashboard,
    required this.onSaved,
    required this.onReset,
    this.onOpenCurriculumPicker,
    this.onSwitchToStudyMode,
  });
  final String initialExamDateIso;
  final int initialDailyTargetMinutes;
  final bool initialShowInDashboard;
  final VoidCallback onSaved;
  final VoidCallback onReset;
  final VoidCallback? onOpenCurriculumPicker;
  final VoidCallback? onSwitchToStudyMode;

  @override
  State<_KonkurSettingsSheet> createState() => _KonkurSettingsSheetState();
}

class _KonkurSettingsSheetState extends State<_KonkurSettingsSheet> {
  DateTime? _selectedDate;
  int _dailyTargetMinutes = 180;
  bool _showInDashboard = true;

  @override
  void initState() {
    super.initState();
    if (widget.initialExamDateIso.isNotEmpty) {
      _selectedDate = DateTime.tryParse(widget.initialExamDateIso);
    }
    _dailyTargetMinutes = widget.initialDailyTargetMinutes;
    _showInDashboard = widget.initialShowInDashboard;
  }

  Future<void> _selectDate() async {
    final now = DateTime.now();
    final picked = await RitmoDatePicker.showJalali(
      context: context,
      initialDate: Jalali.fromDateTime(_selectedDate ?? now.add(const Duration(days: 300))),
      firstDate: Jalali.fromDateTime(now),
      lastDate: Jalali.fromDateTime(now.add(const Duration(days: 1000))),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked.toDateTime();
      });
    }
  }

  Future<void> _saveSettings() async {
    final repo = KonkurRepository.instance;
    if (_selectedDate != null) {
      final dateStr = _selectedDate!.toIso8601String().substring(0, 10);
      await repo.updateAppSetting('konkur_exam_date', dateStr);
    }
    await repo.updateAppSetting('konkur_daily_target_minutes', _dailyTargetMinutes.toString());
    await repo.updateAppSetting('konkur_show_in_dashboard', _showInDashboard ? 'true' : 'false');
    
    widget.onSaved();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    var dateStr = 'انتخاب نشده';
    if (_selectedDate != null) {
      final jalali = Jalali.fromDateTime(_selectedDate!);
      dateStr = '${toPersianDigits(jalali.day)} ${jalali.formatter.mN} ${toPersianDigits(jalali.year)}';
    }

    return Padding(
      padding: EdgeInsets.only(
        left: 14,
        right: 14,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        top: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('⚙ تنظیمات ماژول کنکور', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ],
          ),
          const SizedBox(height: 16),
          ListTile(
            title: Text('تغییر به حالت عمومی درس و مطالعه', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: colors.primary)),
            subtitle: Text('خروج از حالت اختصاصی کنکور و خروج به محیط عمومی مطالعه.', style: TextStyle(fontSize: 10, color: colors.textSecondary)),
            trailing: Icon(Icons.swap_horiz_rounded, color: colors.primary),
            onTap: () async {
              await StudySettingsRepository.instance.setKonkurMode(false);
              if (context.mounted) Navigator.pop(context);
              widget.onSwitchToStudyMode?.call();
            },
          ),
          const Divider(),
          // Curriculum Picker Button
          ListTile(
            title: const Text('بارگذاری سرفصل‌های کنکور', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            subtitle: Text('افزودن دروس و مباحث استاندارد کنکور بر اساس رشته تحصیلی.', style: TextStyle(fontSize: 10, color: colors.textSecondary)),
            trailing: Icon(Icons.school, color: colors.primary),
            onTap: () {
              Navigator.pop(context);
              widget.onOpenCurriculumPicker?.call();
            },
          ),
          const Divider(),
          // Exam Date Row
          ListTile(
            title: const Text('تاریخ برگزاری کنکور', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            subtitle: Text(dateStr, style: TextStyle(fontSize: 11, color: colors.textSecondary)),
            trailing: TextButton.icon(
              onPressed: _selectDate,
              icon: Icon(Icons.edit, size: 16, color: colors.primary),
              label: Text('تغییر تاریخ', style: TextStyle(color: colors.primary, fontSize: 12)),
            ),
          ),
          const Divider(),
          // Daily Target Slider
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('هدف زمان مطالعه روزانه', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    Text(formatDuration(_dailyTargetMinutes), style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: colors.primary)),
                  ],
                ),
                Slider(
                  value: _dailyTargetMinutes.toDouble(),
                  min: 60,
                  max: 720,
                  divisions: 22,
                  activeColor: colors.primary,
                  onChanged: (val) {
                    setState(() {
                      _dailyTargetMinutes = val.toInt();
                    });
                  },
                ),
              ],
            ),
          ),
          const Divider(),
          // Show in Dashboard Switch
          SwitchListTile(
            title: const Text('نمایش برنامه‌ریزی امروز در داشبورد اصلی', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            value: _showInDashboard,
            onChanged: (val) {
              setState(() {
                _showInDashboard = val;
              });
            },
          ),

          const Divider(),
          // Reset Button
          ListTile(
            title: Text('ریست کل اطلاعات کنکور', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: colors.error)),
            subtitle: Text('پاک کردن تمام دروس، مباحث و تاریخچه‌ها جهت شروع مجدد.', style: TextStyle(fontSize: 10, color: colors.textSecondary)),
            trailing: Icon(Icons.warning, color: colors.error),
            onTap: widget.onReset,
          ),
          const SizedBox(height: 24),
          // Save Button
          ElevatedButton(
            onPressed: _saveSettings,
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.primary,
              foregroundColor: colors.onPrimary,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('✓ ذخیره تغییرات تنظیمات', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
