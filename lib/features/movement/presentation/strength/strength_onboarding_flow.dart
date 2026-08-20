import 'dart:async';
import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/movement/application/movement_analytics_service.dart';
import 'package:ritmo/features/movement/application/strength_program_service.dart';
import 'package:ritmo/features/movement/domain/models/movement_strength_day.dart';
import 'package:ritmo/features/movement/domain/models/movement_strength_program.dart';
import 'package:ritmo/features/movement/presentation/common/movement_layout.dart';
import 'package:ritmo/features/movement/presentation/common/movement_screen_shell.dart';
import 'package:ritmo/features/movement/presentation/common/movement_strings.dart';
import 'package:ritmo/features/movement/presentation/strength/onboarding/step_equipment.dart';
import 'package:ritmo/features/movement/presentation/strength/onboarding/step_goal.dart';
import 'package:ritmo/features/movement/presentation/strength/onboarding/step_level_safety.dart';
import 'package:ritmo/features/movement/presentation/strength/onboarding/step_preferences.dart';
import 'package:ritmo/features/movement/presentation/strength/onboarding/step_schedule.dart';
import 'package:ritmo/features/movement/presentation/strength/strength_program_preview_screen.dart';

/// جریان ۵ گامهٔ آنبوردینگ قدرت در خانه (StrengthOnboardingFlow)
class StrengthOnboardingFlow extends StatefulWidget {
  const StrengthOnboardingFlow({
    super.key,
    this.strengthService,
    this.initialDraft,
  });

  final StrengthProgramService? strengthService;
  final MovementStrengthProgram? initialDraft;

  @override
  State<StrengthOnboardingFlow> createState() => _StrengthOnboardingFlowState();
}

class _StrengthOnboardingFlowState extends State<StrengthOnboardingFlow> {
  late final StrengthProgramService _service;
  int _currentStep = 1; // 1 to 5
  String _programId = 'sp_${DateTime.now().millisecondsSinceEpoch}';

  // مقادیر با پیش‌فرض‌های هوشمند
  String _goal = 'muscle';
  String _level = 'intermediate';
  List<String> _sensitiveAreas = [];
  List<String> _equipment = ['bodyweight'];
  int _daysPerWeek = 3;
  List<int> _preferredDays = [1, 3, 5];
  int _sessionMinutes = 30;
  String _preferredTime = '08:00';
  bool _quietMode = false;
  bool _smallSpace = false;
  bool _bodyweightFocus = false;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _service = widget.strengthService ?? StrengthProgramService();
    if (widget.initialDraft != null) {
      _applyDraft(widget.initialDraft!);
      _isLoading = false;
    } else {
      _loadOrInitializeDraft();
    }
  }

  void _applyDraft(MovementStrengthProgram draft) {
    _programId = draft.id;
    _currentStep = draft.draftStep.clamp(1, 5);
    _goal = draft.goal ?? _goal;
    _level = draft.level ?? _level;
    _sensitiveAreas = draft.sensitiveAreas;
    _equipment = draft.equipment.isNotEmpty ? draft.equipment : _equipment;
    _daysPerWeek = draft.daysPerWeek;
    _preferredDays = draft.preferredDays.isNotEmpty
        ? draft.preferredDays
        : _preferredDays;
    _sessionMinutes = draft.sessionMinutes;
    _preferredTime = draft.preferredTime ?? _preferredTime;

    final extra = draft.draftData;
    if (extra != null) {
      _quietMode = extra['quietMode'] as bool? ?? false;
      _smallSpace = extra['smallSpace'] as bool? ?? false;
      _bodyweightFocus = extra['bodyweightFocus'] as bool? ?? false;
    }
  }

  Future<void> _loadOrInitializeDraft() async {
    try {
      final draft = await _service.getDraftProgram();
      if (draft != null) {
        _applyDraft(draft);
      }
    } catch (_) {}

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveCurrentDraft() async {
    try {
      await _service.saveDraft(
        programId: _programId,
        draftStep: _currentStep,
        goal: _goal,
        level: _level,
        sensitiveAreas: _sensitiveAreas,
        equipment: _equipment,
        daysPerWeek: _daysPerWeek,
        sessionMinutes: _sessionMinutes,
        preferredDays: _preferredDays,
        preferredTime: _preferredTime,
        extraDraftData: {
          'quietMode': _quietMode,
          'smallSpace': _smallSpace,
          'bodyweightFocus': _bodyweightFocus,
        },
      );
    } catch (_) {}
  }

  Future<void> _handleNext() async {
    if (_currentStep < 5) {
      setState(() => _currentStep++);
      unawaited(_saveCurrentDraft());
    } else {
      // پایان گام ۵: تولید برنامه و انتقال به پیش‌نمایش
      unawaited(_saveCurrentDraft());

      try {
        final planMap = _service.generateProgramPlan(
          goal: _goal,
          level: _level,
          sensitiveAreas: _sensitiveAreas,
          equipment: _equipment,
          daysPerWeek: _daysPerWeek,
          sessionMinutes: _sessionMinutes,
          preferredDays: _preferredDays,
          preferredTime: _preferredTime,
        );

        final program = planMap['program'] as MovementStrengthProgram;
        final days = planMap['days'] as List<MovementStrengthDay>;

        MovementAnalyticsService.instance.logStrengthOnboardingCompleted(
          goal: _goal,
          daysPerWeek: _daysPerWeek,
          equipmentCount: _equipment.length,
        );

        if (mounted) {
          unawaited(
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => StrengthProgramPreviewScreen(
                  program: program,
                  days: days,
                  strengthService: _service,
                ),
              ),
            ),
          );
        }
      } catch (e, st) {
        debugPrint('ERROR in generateProgramPlan: $e\n$st');
      }
    }
  }

  Future<void> _handleBack() async {
    if (_currentStep > 1) {
      setState(() => _currentStep--);
      unawaited(_saveCurrentDraft());
    } else {
      Navigator.of(context).pop();
    }
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 1:
        return StepGoal(
          selectedGoal: _goal,
          onGoalSelected: (g) => setState(() => _goal = g),
        );
      case 2:
        return StepLevelSafety(
          selectedLevel: _level,
          onLevelChanged: (lvl) => setState(() => _level = lvl),
          sensitiveAreas: _sensitiveAreas,
          onSensitiveAreasChanged: (areas) =>
              setState(() => _sensitiveAreas = areas),
        );
      case 3:
        return StepEquipment(
          selectedEquipment: _equipment,
          onEquipmentChanged: (eq) => setState(() => _equipment = eq),
        );
      case 4:
        return StepSchedule(
          daysPerWeek: _daysPerWeek,
          onDaysPerWeekChanged: (d) => setState(() => _daysPerWeek = d),
          preferredDays: _preferredDays,
          onPreferredDaysChanged: (p) => setState(() => _preferredDays = p),
          sessionMinutes: _sessionMinutes,
          onSessionMinutesChanged: (m) => setState(() => _sessionMinutes = m),
          preferredTime: _preferredTime,
          onPreferredTimeChanged: (t) => setState(() => _preferredTime = t),
        );
      case 5:
      default:
        return StepPreferences(
          quietMode: _quietMode,
          onQuietModeChanged: (q) => setState(() => _quietMode = q),
          smallSpace: _smallSpace,
          onSmallSpaceChanged: (s) => setState(() => _smallSpace = s),
          bodyweightFocus: _bodyweightFocus,
          onBodyweightFocusChanged: (b) => setState(() => _bodyweightFocus = b),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final sportsColor = context.modules.sports;

    if (_isLoading) {
      return const MovementScreenShell(
        title: MovementStrings.strengthOnboardingTitle,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final stepProgress = _currentStep / 5.0;

    return MovementScreenShell(
      title: MovementStrings.strengthOnboardingTitle,
      body: SafeArea(
        child: Column(
          children: [
            // نوار پیشرفت گام‌ها
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: RitmoSpacing.lg,
                vertical: RitmoSpacing.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        MovementStrings.strengthStepOf(_currentStep),
                        style: RitmoTextStyles.caption(
                          sportsColor,
                        ).copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${(_currentStep * 20)}٪',
                        style: RitmoTextStyles.caption(colors.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: RitmoSpacing.xs),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(RitmoRadius.pill),
                    child: LinearProgressIndicator(
                      value: stepProgress,
                      minHeight: 4,
                      backgroundColor: colors.surfaceSunken,
                      valueColor: AlwaysStoppedAnimation<Color>(sportsColor),
                    ),
                  ),
                ],
              ),
            ),

            // محتوای گام جاری
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: RitmoSpacing.lg,
                  vertical: RitmoSpacing.md,
                ),
                child: _buildStepContent(),
              ),
            ),

            // دکمه‌های ناوبری پایین صفحه
            Padding(
              padding: const EdgeInsets.all(RitmoSpacing.lg),
              child: Row(
                children: [
                  if (_currentStep > 1) ...[
                    OutlinedButton(
                      onPressed: _handleBack,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(
                          48,
                          MovementLayout.kPrimaryButtonHeight,
                        ),
                        side: BorderSide(color: colors.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            RitmoRadius.field,
                          ),
                        ),
                      ),
                      child: const Icon(Icons.arrow_forward_rounded, size: 20),
                    ),
                    const SizedBox(width: RitmoSpacing.md),
                  ],
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _handleNext,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(
                          48,
                          MovementLayout.kPrimaryButtonHeight,
                        ),
                        backgroundColor: sportsColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            RitmoRadius.field,
                          ),
                        ),
                      ),
                      child: Text(
                        _currentStep == 5 ? 'مشاهدهٔ برنامه' : 'گام بعدی',
                        style: RitmoTextStyles.label(Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
