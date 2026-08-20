import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/observability/ritmo_logger.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/util/ritmo_number.dart';
import 'package:ritmo/features/cycle/logic/cycle_clock.dart';
import 'package:ritmo/features/cycle/logic/cycle_lock_service.dart';
import 'package:ritmo/features/cycle/logic/pregnancy_settings.dart';
import 'package:ritmo/features/cycle/models/pregnancy_models.dart';
import 'package:ritmo/features/cycle/presentation/onboarding/pregnancy_onboarding_controller.dart';
import 'package:ritmo/features/cycle/presentation/onboarding/pregnancy_steps/preg_step_1_tone.dart';
import 'package:ritmo/features/cycle/presentation/onboarding/pregnancy_steps/preg_step_2_dates.dart';
import 'package:ritmo/features/cycle/presentation/onboarding/pregnancy_steps/preg_step_3_context.dart';
import 'package:ritmo/features/cycle/presentation/onboarding/pregnancy_steps/preg_step_4_privacy.dart';
import 'package:ritmo/features/cycle/presentation/onboarding/pregnancy_steps/preg_step_5_confirm.dart';
import 'package:ritmo/features/cycle/presentation/widgets/cycle_passcode_sheet.dart';

class PregnancyOnboardingShell extends StatefulWidget {
  const PregnancyOnboardingShell({
    super.key,
    required this.onCompleted,
    this.onCancel,
    this.isEditMode = false,
  });

  final VoidCallback onCompleted;
  final VoidCallback? onCancel;
  final bool isEditMode;

  static Future<void> show(
    BuildContext context, {
    required VoidCallback onCompleted,
    VoidCallback? onCancel,
    bool isEditMode = false,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PregnancyOnboardingShell(
        onCompleted: onCompleted,
        onCancel: onCancel ?? () => Navigator.of(ctx).pop(),
        isEditMode: isEditMode,
      ),
    );
  }

  @override
  State<PregnancyOnboardingShell> createState() => _PregnancyOnboardingShellState();
}

class _PregnancyOnboardingShellState extends State<PregnancyOnboardingShell> {
  late final PregnancyOnboardingController _controller;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _controller = PregnancyOnboardingController();
    final defaultLmp = CycleClock.now.subtract(const Duration(days: 56));
    _controller.setLmpDate(defaultLmp);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<bool> _confirmExit() async {
    if (_controller.currentStep == 0 && !widget.isEditMode) return true;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: context.colors.surface,
          title: const Text(
            'خروج از راه‌اندازی',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'اگر الان خارج شوی، حالت بارداری فعال نمی‌شود و اطلاعات واردشده ذخیره نمی‌شوند.',
            style: TextStyle(fontSize: 13, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('ادامه می‌دهم', style: TextStyle()),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                'خروج',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return confirm ?? false;
  }

  Future<void> _handleSave() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      final data = _controller.buildOnboardingData();
      await _controller.savePregnancyOnboarding(data, isEditMode: widget.isEditMode);

      if (mounted) {
        // 1. If lockEnabled and no passcode configured, open passcode setup sheet
        if (data.lockEnabled) {
          final hasPasscode = await CycleLockService.instance.hasAnyActivePin();
          if (!hasPasscode && mounted) {
            final setupSuccess = await CyclePasscodeSheet.show(
              context,
              mode: CyclePasscodeSheetMode.setup,
            );
            if (setupSuccess != true) {
              // If user cancelled passcode setup, disable lock without aborting pregnancy setup
              await PregnancySettings.saveSetting(
                PregnancySettings.keyLockEnabled,
                'false',
              );
            }
          }
        }

        // 2. Schedule pregnancy notifications
        // TODO: PRG-35 schedule pregnancy notifications

        // 3. Success SnackBar
        if (mounted) {
          final snackMsg = data.tone == PregnancyTone.warm
              ? 'حالت بارداری فعال شد. از همین امروز کنارت هستیم. 🌸'
              : 'حالت بارداری فعال شد.';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(snackMsg),
              backgroundColor: context.colors.primary,
              duration: const Duration(seconds: 3),
            ),
          );

          // 4. Close shell & invoke onCompleted
          widget.onCompleted();
        }
      }
    } catch (e, st) {
      RitmoLogger.error(
        '[PregnancyOnboardingShell] Error saving pregnancy profile',
        error: e,
        stack: st,
      );
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('خطا در ذخیره‌سازی اطلاعات. لطفاً دوباره تلاش کنید.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final viewInsets = MediaQuery.of(context).viewInsets;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (_controller.currentStep > 0) {
          _controller.previousStep();
        } else {
          final canExit = await _confirmExit();
          if (canExit && context.mounted) {
            (widget.onCancel ?? () => Navigator.of(context).pop())();
          }
        }
      },
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final currentData = _controller.buildOnboardingData();

          return Directionality(
            textDirection: TextDirection.rtl,
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.9,
              ),
              margin: EdgeInsets.only(bottom: viewInsets.bottom),
              decoration: BoxDecoration(
                color: colors.surfaceElevated,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header bar
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(CupertinoIcons.xmark),
                          color: colors.textSecondary,
                          onPressed: () async {
                            final canExit = await _confirmExit();
                            if (canExit && context.mounted) {
                              (widget.onCancel ?? () => Navigator.of(context).pop())();
                            }
                          },
                        ),
                        Expanded(
                          child: Column(
                            children: [
                              Text(
                                widget.isEditMode ? 'بازبینی راه‌اندازی بارداری' : 'راه‌اندازی بارداری',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: colors.textPrimary,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'گام ${RitmoNumber.fa((_controller.currentStep + 1).toString())} از ۵',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 48), // Balance for close button
                      ],
                    ),
                  ),

                  // 5-segment Progress bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    child: Row(
                      children: List.generate(5, (index) {
                        final isActive = index <= _controller.currentStep;
                        final isCurrent = index == _controller.currentStep;
                        return Expanded(
                          child: Container(
                            height: 4,
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            decoration: BoxDecoration(
                              color: isCurrent
                                  ? colors.primary
                                  : (isActive ? colors.primary.withValues(alpha: 0.5) : colors.border),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),

                  // Step Body
                  Flexible(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: _buildStepWidget(context, currentData, colors, isDark),
                    ),
                  ),

                  // Bottom action buttons for Steps 0, 1, 2, 3 (Step 4 has its own confirmation buttons)
                  if (_controller.currentStep < 4)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                      child: Row(
                        children: [
                          if (_controller.currentStep > 0) ...[
                            OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              onPressed: _controller.previousStep,
                              child: const Text('مرحله قبل'),
                            ),
                            const SizedBox(width: 12),
                          ],
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: colors.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              onPressed: _isSaving ? null : () => _controller.nextStep(),
                              child: const Text(
                                'مرحله بعد',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
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
        },
      ),
    );
  }

  Widget _buildStepWidget(
    BuildContext context,
    PregnancyOnboardingData data,
    dynamic colors,
    bool isDark,
  ) {
    switch (_controller.currentStep) {
      case 0:
        return PregStep1Tone(
          data: data,
          onDataChanged: (updated) {
            _controller.tone = updated.tone;
            _controller.notifyListeners();
          },
          onNext: _controller.nextStep,
          colors: colors,
          isDark: isDark,
        );
      case 1:
        return PregStep2Dates(
          data: data,
          onDataChanged: (updated) {
            _controller.eddSource = updated.eddSource;
            _controller.lmpDate = updated.lmpDate;
            _controller.dueDate = updated.dueDate;
            _controller.scanDate = updated.scanDate;
            _controller.scanWeeks = updated.scanWeeks;
            _controller.scanDays = updated.scanDays;
            _controller.notifyListeners();
          },
          onNext: _controller.nextStep,
          colors: colors,
          isDark: isDark,
        );
      case 2:
        return PregStep3Context(
          data: data,
          onDataChanged: (updated) {
            _controller.isMultiple = updated.isMultiple;
            _controller.isHighRisk = updated.isHighRisk;
            _controller.pauseCyclePredictions = updated.pauseCyclePredictions;
            _controller.suspendWorship = updated.suspendWorship;
            _controller.notifyListeners();
          },
          onNext: _controller.nextStep,
          colors: colors,
          isDark: isDark,
        );
      case 3:
        return PregStep4Privacy(
          data: data,
          onDataChanged: (updated) {
            _controller.lockEnabled = updated.lockEnabled;
            _controller.hideFromDashboard = updated.hideFromDashboard;
            _controller.maskNotifications = updated.maskNotifications;
            _controller.notifyListeners();
          },
          onNext: _controller.nextStep,
          colors: colors,
          isDark: isDark,
        );
      case 4:
      default:
        return PregStep5Confirm(
          data: data,
          onSave: _handleSave,
          onBack: _controller.previousStep,
          isSaving: _isSaving,
          isEditMode: widget.isEditMode,
          colors: colors,
          isDark: isDark,
        );
    }
  }
}
