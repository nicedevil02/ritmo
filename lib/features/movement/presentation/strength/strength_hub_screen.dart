import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/movement/application/strength_program_service.dart';
import 'package:ritmo/features/movement/domain/models/movement_strength_day.dart';
import 'package:ritmo/features/movement/domain/models/movement_strength_program.dart';
import 'package:ritmo/features/movement/presentation/common/movement_layout.dart';
import 'package:ritmo/features/movement/presentation/common/movement_screen_shell.dart';
import 'package:ritmo/features/movement/presentation/common/movement_strings.dart';
import 'package:ritmo/features/movement/presentation/movement_routes.dart';
import 'package:ritmo/features/movement/presentation/strength/sheets/program_manage_sheet.dart';
import 'package:ritmo/features/movement/presentation/strength/widgets/program_header.dart';
import 'package:ritmo/features/movement/presentation/strength/widgets/program_session_tile.dart';
import 'package:ritmo/features/movement/presentation/strength/widgets/program_week_strip.dart';

/// مرکز قدرت در خانه (StrengthHubScreen)
class StrengthHubScreen extends StatefulWidget {
  const StrengthHubScreen({
    super.key,
    this.strengthService,
    this.initialProgram,
    this.initialDays,
  });

  final StrengthProgramService? strengthService;
  final MovementStrengthProgram? initialProgram;
  final List<MovementStrengthDay>? initialDays;

  @override
  State<StrengthHubScreen> createState() => _StrengthHubScreenState();
}

class _StrengthHubScreenState extends State<StrengthHubScreen> {
  late final StrengthProgramService _service;
  MovementStrengthProgram? _program;
  List<MovementStrengthDay> _allDays = [];
  int _selectedWeek = 1;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _service = widget.strengthService ?? StrengthProgramService();
    if (widget.initialProgram != null) {
      _program = widget.initialProgram;
      _allDays = widget.initialDays ?? [];
      _selectedWeek = widget.initialProgram!.currentWeek;
      _isLoading = false;
    } else {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final program = await _service.getCurrentProgram();
      List<MovementStrengthDay> days = [];
      if (program != null && !program.isInactive) {
        days = await _service.getProgramDays(program.id);
        _selectedWeek = program.currentWeek;
      }

      if (mounted) {
        setState(() {
          _program = program;
          _allDays = days;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _program = null;
          _allDays = [];
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handlePauseToggle() async {
    if (_program == null) return;
    if (_program!.isPaused) {
      await _service.resumeProgram(_program!.id);
    } else {
      await _service.pauseProgram(_program!.id);
    }
    await _loadData();
  }

  Future<void> _handleFinishProgram() async {
    if (_program == null) return;
    await _service.finishProgram(_program!.id);
    await _loadData();
  }

  void _handleStartNewCycle() {
    Navigator.of(context).pushNamed(MovementRoutes.strengthOnboarding);
  }

  Future<void> _handleUpdateSettings({
    required int newDays,
    required int newDuration,
  }) async {
    if (_program == null) return;
    final planMap = _service.generateProgramPlan(
      goal: _program!.goal ?? 'muscle',
      level: _program!.level ?? 'intermediate',
      sensitiveAreas: _program!.sensitiveAreas,
      equipment: _program!.equipment,
      daysPerWeek: newDays,
      sessionMinutes: newDuration,
      preferredDays: _program!.preferredDays,
      preferredTime: _program!.preferredTime,
    );

    final updatedProgram = planMap['program'] as MovementStrengthProgram;
    final updatedDays = planMap['days'] as List<MovementStrengthDay>;

    await _service.activateProgram(program: updatedProgram, days: updatedDays);
    await _loadData();
  }

  void _openManageSheet() {
    if (_program == null) return;
    ProgramManageSheet.show(
      context,
      program: _program!,
      onPauseToggle: _handlePauseToggle,
      onFinishProgram: _handleFinishProgram,
      onStartNewCycle: _handleStartNewCycle,
      onUpdateSettings: _handleUpdateSettings,
    );
  }

  Widget _buildInactiveState() {
    final colors = context.colors;
    final sportsColor = context.modules.sports;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: RitmoSpacing.lg,
        vertical: RitmoSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // کارت معرفی
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(RitmoSpacing.lg),
            decoration: BoxDecoration(
              color: sportsColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(RitmoRadius.card),
              border: Border.all(color: sportsColor.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.fitness_center_rounded,
                      color: sportsColor,
                      size: 28,
                    ),
                    const SizedBox(width: RitmoSpacing.sm),
                    Text(
                      MovementStrings.strengthHubTitle,
                      style: RitmoTextStyles.sectionHeadline(sportsColor),
                    ),
                  ],
                ),
                const SizedBox(height: RitmoSpacing.sm),
                Text(
                  'برنامهٔ علمی و تدریجی تمرینات قدرتی متناسب با تجهیزات و زمان شما در خانه.',
                  style: RitmoTextStyles.body(colors.textPrimary),
                ),
              ],
            ),
          ),
          const SizedBox(height: RitmoSpacing.lg),

          // ۳ مزیت کلیدی
          Text(
            'مزایای سیستم قدرت در خانه:',
            style: RitmoTextStyles.cardTitle(colors.textPrimary),
          ),
          const SizedBox(height: RitmoSpacing.sm),
          _buildBenefitRow(
            'تطبیق کامل با وسایل موجود در خانه بدون نیاز به باشگاه',
          ),
          _buildBenefitRow(
            'پیشرفت تدریجی با استراحت هوشمند و هفتهٔ ریکاوری (دِلود)',
          ),
          _buildBenefitRow('حفظ مفاصل حساس با جایگزینی خودکار حرکات پرخطر'),
          const SizedBox(height: RitmoSpacing.lg),

          // پاسخ به ۲ تردید رایج
          Text(
            'پاسخ به تردیدهای رایج:',
            style: RitmoTextStyles.cardTitle(colors.textPrimary),
          ),
          const SizedBox(height: RitmoSpacing.sm),
          _buildFaqCard(
            question: 'آیا بدون دمبل یا تجهیزات هم نتیجه می‌گیرم؟',
            answer:
                'بله؛ حرکات بر پایهٔ وزن بدن با اهرم‌های مختلف به گونه‌ای طراحی شده‌اند که مقاومت کافی برای تقویت عضلات را ایجاد کنند.',
          ),
          const SizedBox(height: RitmoSpacing.sm),
          _buildFaqCard(
            question: 'چقدر زمان در روز نیاز دارم؟',
            answer:
                'شما می‌توانید جلسات ۲۰ تا ۳۰ دقیقه‌ای را انتخاب کنید که به راحتی در برنامهٔ روزمره‌تان جای می‌گیرد.',
          ),
          const SizedBox(height: RitmoSpacing.xl),

          // CTA ساخت برنامه
          ElevatedButton(
            onPressed: () => Navigator.of(
              context,
            ).pushNamed(MovementRoutes.strengthOnboarding),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(
                double.infinity,
                MovementLayout.kPrimaryButtonHeight,
              ),
              backgroundColor: sportsColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(RitmoRadius.field),
              ),
            ),
            child: Text(
              MovementStrings.strengthHubCreatePlan,
              style: RitmoTextStyles.label(Colors.white),
            ),
          ),
          const SizedBox(height: RitmoSpacing.lg),
        ],
      ),
    );
  }

  Widget _buildBenefitRow(String text) {
    final colors = context.colors;
    final sportsColor = context.modules.sports;
    return Padding(
      padding: const EdgeInsets.only(bottom: RitmoSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.check_circle_outline_rounded,
            color: sportsColor,
            size: 20,
          ),
          const SizedBox(width: RitmoSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: RitmoTextStyles.body(colors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFaqCard({required String question, required String answer}) {
    final colors = context.colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(RitmoSpacing.md),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(RitmoRadius.card),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(question, style: RitmoTextStyles.label(colors.textPrimary)),
          const SizedBox(height: 4),
          Text(answer, style: RitmoTextStyles.caption(colors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildActiveState() {
    final colors = context.colors;
    final program = _program!;
    final weekDays = _allDays
        .where((d) => d.weekIndex == _selectedWeek)
        .toList();
    final nextSession = weekDays.isNotEmpty ? weekDays.first : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: RitmoSpacing.lg,
        vertical: RitmoSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ۱. سربرگ برنامه
          ProgramHeader(program: program, onManagePressed: _openManageSheet),
          const SizedBox(height: RitmoSpacing.md),

          // ۲. نوار انتخاب هفته‌های دوره
          ProgramWeekStrip(
            totalWeeks: program.totalWeeks,
            currentProgramWeek: program.currentWeek,
            selectedWeek: _selectedWeek,
            deloadWeekIndex: program.deloadWeekIndex,
            onWeekSelected: (w) => setState(() => _selectedWeek = w),
          ),
          const SizedBox(height: RitmoSpacing.lg),

          // ۳. کارت جلسهٔ بعدی با دکمهٔ شروع
          if (nextSession != null && !program.isPaused) ...[
            Text(
              'جلسهٔ بعدی:',
              style: RitmoTextStyles.sectionHeadline(colors.textPrimary),
            ),
            const SizedBox(height: RitmoSpacing.sm),
            ProgramSessionTile(
              day: nextSession,
              onTap: () {},
              onStart: () {
                Navigator.of(context).pushNamed(
                  MovementRoutes.liveSession,
                  arguments: {
                    'occurrenceId': 'occ_${nextSession.id}',
                    'activityKindId': 'kind_strength',
                    'sessionMode': 'strength',
                    'strengthDayId': nextSession.id,
                  },
                );
              },
            ),
            const SizedBox(height: RitmoSpacing.lg),
          ],

          // ۴. فهرست تمام جلسات این هفته
          Text(
            'جلسات هفتهٔ ${toPersianDigits(_selectedWeek)}:',
            style: RitmoTextStyles.sectionHeadline(colors.textPrimary),
          ),
          const SizedBox(height: RitmoSpacing.sm),
          ...weekDays.map((day) {
            return ProgramSessionTile(
              day: day,
              onTap: () {
                Navigator.of(context).pushNamed(
                  MovementRoutes.liveSession,
                  arguments: {
                    'occurrenceId': 'occ_${day.id}',
                    'activityKindId': 'kind_strength',
                    'sessionMode': 'strength',
                    'strengthDayId': day.id,
                  },
                );
              },
            );
          }),
          const SizedBox(height: RitmoSpacing.lg),

          // ۵. ردیف مدیریت برنامه
          Center(
            child: TextButton.icon(
              onPressed: _openManageSheet,
              icon: const Icon(Icons.settings_outlined, size: 18),
              label: const Text(MovementStrings.strengthManageTitle),
            ),
          ),
          const SizedBox(height: RitmoSpacing.lg),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const MovementScreenShell(
        title: MovementStrings.strengthHubTitle,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final hasActiveProgram = _program != null && !_program!.isInactive;

    return MovementScreenShell(
      title: MovementStrings.strengthHubTitle,
      body: SafeArea(
        child: hasActiveProgram ? _buildActiveState() : _buildInactiveState(),
      ),
    );
  }
}
