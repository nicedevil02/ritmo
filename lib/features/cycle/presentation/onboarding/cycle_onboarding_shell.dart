import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:ritmo/core/observability/ritmo_logger.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/util/ritmo_number.dart';
import 'package:ritmo/features/cycle/logic/cycle_onboarding_controller.dart';
import 'package:ritmo/features/cycle/presentation/onboarding/steps/step_1_privacy_lock.dart';
import 'package:ritmo/features/cycle/presentation/onboarding/steps/step_2_cycle_status.dart';
import 'package:ritmo/features/cycle/presentation/onboarding/steps/step_3_rhythm_params.dart';
import 'package:ritmo/features/cycle/presentation/onboarding/steps/step_4_consents.dart';
import 'package:ritmo/features/cycle/presentation/onboarding/steps/step_5_confirmation.dart';

class CycleOnboardingShell extends StatefulWidget {
  const CycleOnboardingShell({
    super.key,
    required this.onCompleted,
    required this.onNavigateToPregnancy,
    this.isEditMode = false,
  });

  final VoidCallback onCompleted;
  final VoidCallback onNavigateToPregnancy;
  final bool isEditMode;

  @override
  State<CycleOnboardingShell> createState() => _CycleOnboardingShellState();
}

class _CycleOnboardingShellState extends State<CycleOnboardingShell> {
  int _currentStep = 1;
  bool _isLoadingInitial = true;
  bool _isSaving = false;
  String? _errorMessage;

  late CycleOnboardingData _data;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    setState(() {
      _isLoadingInitial = true;
      _errorMessage = null;
    });

    try {
      _data = await CycleOnboardingController.instance.loadInitialData();
    } catch (e, st) {
      RitmoLogger.error(
        '[CycleOnboardingShell] Error loading initial data',
        error: e,
        stack: st,
      );
      _errorMessage = 'خطا در بارگذاری اولیه: $e';
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingInitial = false;
        });
      }
    }
  }

  Future<void> _handleSave() async {
    if (_isSaving) return;
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await CycleOnboardingController.instance.saveOnboarding(
        _data,
        isEditMode: widget.isEditMode,
      );
      if (mounted) {
        widget.onCompleted();
      }
    } catch (e, st) {
      RitmoLogger.error(
        '[CycleOnboardingShell] Error saving onboarding',
        error: e,
        stack: st,
      );
      // Dedicated Error State (Bug چ-۲ resolution)
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage = 'خطا در ذخیره‌سازی راه‌اندازی: $e';
        });
      }
    }
  }

  Future<bool> _confirmExit() async {
    if (_currentStep == 1 && !widget.isEditMode) return true;

    final confirm = await RitmoDialog.show(
      context,
      title: 'خروج از راه‌اندازی',
      content:
          'آیا از خروج از راه‌اندازی اطمینان دارید؟ اطلاعات واردشده تا قبل از ثبت نهایی ذخیره نخواهند شد.',
      confirmLabel: 'خروج',
      cancelLabel: 'ادامه راه‌اندازی',
      isDestructive: true,
    );

    return confirm ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoadingInitial) {
      return Center(child: CircularProgressIndicator(color: colors.primary));
    }

    // Dedicated Error State Screen (Bug چ-۲ resolution)
    if (_errorMessage != null) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: RitmoGlassSheet(
            borderRadius: BorderRadius.circular(28),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  CupertinoIcons.exclamationmark_triangle_fill,
                  color: Colors.orange,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  'خطا در ذخیره‌سازی داده‌ها',
                  style: RitmoTextStyles.cardTitle(colors.textPrimary),
                ),
                const SizedBox(height: 8),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: RitmoTextStyles.caption(colors.textSecondary).copyWith(height: 1.5),
                ),
                const SizedBox(height: 24),
                RitmoPrimaryButton(
                  label: 'تلاش مجدد',
                  icon: CupertinoIcons.refresh,
                  onPressed: _handleSave,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (_currentStep > 1) {
          setState(() {
            _currentStep--;
          });
        } else {
          final exitConfirmed = await _confirmExit();
          if (exitConfirmed && context.mounted) {
            Navigator.pop(context);
          }
        }
      },
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: RitmoBreakpoints.sheetMaxHeight(context, factor: 0.94),
          ),
          child: RitmoGlassSheet(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.border.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Wizard Progress Header (§۵ & Bug چ-۱۲)
                _buildProgressHeader(colors, isDark),
                const SizedBox(height: 12),
                // Step Body
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      switchInCurve: Curves.easeInOut,
                      switchOutCurve: Curves.easeInOut,
                      transitionBuilder: (child, animation) {
                        return SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(-0.2, 0.0),
                            end: Offset.zero,
                          ).animate(animation),
                          child: FadeTransition(opacity: animation, child: child),
                        );
                      },
                      child: _buildCurrentStepWidget(colors, isDark),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressHeader(RitmoColors colors, bool isDark) {
    final primaryColor = colors.primary;

    return Column(
      children: [
        Row(
          children: [
            RitmoNeuButton(
              padding: const EdgeInsets.all(8),
              radius: 10,
              onTap: () async {
                final confirm = await _confirmExit();
                if (confirm && mounted) {
                  Navigator.pop(context);
                }
              },
              child: Icon(
                CupertinoIcons.xmark,
                size: 16,
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.isEditMode
                    ? 'بازبینی راه‌اندازی چرخه بدن'
                    : 'راه‌اندازی چرخه بدن',
                style: RitmoTextStyles.cardTitle(colors.textPrimary),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: 8),
            RitmoCardBadge(
              label: 'گام ${RitmoNumber.faInt(_currentStep)} از ۵',
              color: primaryColor,
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Segmented Progress Bar
        Row(
          children: List.generate(5, (index) {
            final stepNum = index + 1;
            final isCompleted = stepNum < _currentStep;
            final isCurrent = stepNum == _currentStep;

            return Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                height: 4,
                margin: const EdgeInsets.symmetric(horizontal: 2.5),
                decoration: BoxDecoration(
                  color: isCurrent || isCompleted
                      ? primaryColor
                      : colors.borderSubtle,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildCurrentStepWidget(RitmoColors colors, bool isDark) {
    switch (_currentStep) {
      case 1:
        return Step1PrivacyLock(
          data: _data,
          onDataChanged: (d) => setState(() => _data = d),
          onNext: () => setState(() => _currentStep = 2),
          colors: colors,
          isDark: isDark,
        );
      case 2:
        return Step2CycleStatus(
          data: _data,
          onDataChanged: (d) => setState(() => _data = d),
          onNext: () {
            if (_data.periodStatus ==
                CyclePeriodStatusChoice.currentlyPregnant) {
              widget.onNavigateToPregnancy();
            } else {
              setState(() => _currentStep = 3);
            }
          },
          onBack: () => setState(() => _currentStep = 1),
          onNavigateToPregnancy: widget.onNavigateToPregnancy,
          colors: colors,
          isDark: isDark,
        );
      case 3:
        return Step3RhythmParams(
          data: _data,
          onDataChanged: (d) => setState(() => _data = d),
          onNext: () => setState(() => _currentStep = 4),
          onBack: () => setState(() => _currentStep = 2),
          colors: colors,
          isDark: isDark,
        );
      case 4:
        return Step4Consents(
          data: _data,
          onDataChanged: (d) => setState(() => _data = d),
          onNext: () => setState(() => _currentStep = 5),
          onBack: () => setState(() => _currentStep = 3),
          colors: colors,
          isDark: isDark,
        );
      case 5:
        return Step5Confirmation(
          data: _data,
          onSave: _handleSave,
          onBack: () => setState(() => _currentStep = 4),
          isSaving: _isSaving,
          colors: colors,
          isDark: isDark,
        );
      default:
        return Container();
    }
  }
}
