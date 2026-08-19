import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/movement/application/movement_log_service.dart';
import 'package:ritmo/features/movement/domain/models/movement_activity_kind.dart';
import 'package:ritmo/features/movement/domain/models/movement_workout_log.dart';
import 'package:ritmo/features/movement/presentation/common/movement_layout.dart';
import 'package:ritmo/features/movement/presentation/common/movement_screen_shell.dart';
import 'package:ritmo/features/movement/presentation/common/movement_strings.dart';
import 'package:ritmo/features/movement/presentation/movement_routes.dart';
import 'package:ritmo/features/movement/presentation/summary/widgets/summary_feeling_picker.dart';
import 'package:ritmo/features/movement/presentation/summary/widgets/summary_metric_block.dart';
import 'package:ritmo/features/movement/presentation/summary/widgets/summary_pr_block.dart';

/// صفحهٔ جامع خلاصهٔ جلسهٔ ورزشی (SessionSummaryScreen)
class SessionSummaryScreen extends StatefulWidget {
  const SessionSummaryScreen({
    super.key,
    required this.workoutLog,
    this.activityKind,
    this.previousLog,
    this.isPr = false,
    this.prTitle,
    this.prValue,
    this.isQuickStart = false,
    this.isPartial = false,
    this.logService,
    this.onDone,
    this.onLogAnother,
  });

  final MovementWorkoutLog workoutLog;
  final MovementActivityKind? activityKind;
  final MovementWorkoutLog? previousLog;
  final bool isPr;
  final String? prTitle;
  final String? prValue;
  final bool isQuickStart;
  final bool isPartial;
  final MovementLogService? logService;
  final VoidCallback? onDone;
  final VoidCallback? onLogAnother;

  @override
  State<SessionSummaryScreen> createState() => _SessionSummaryScreenState();
}

class _SessionSummaryScreenState extends State<SessionSummaryScreen> {
  late final TextEditingController _noteController;
  String? _selectedFeeling;
  late final MovementLogService _logService;

  @override
  void initState() {
    super.initState();
    _logService = widget.logService ?? MovementLogService();
    _selectedFeeling = widget.workoutLog.feeling;
    _noteController = TextEditingController(text: widget.workoutLog.note ?? '');
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _persistFeedback() async {
    final note = _noteController.text.trim();
    if (_selectedFeeling != widget.workoutLog.feeling ||
        note != (widget.workoutLog.note ?? '')) {
      final updated = widget.workoutLog.copyWith(
        feeling: _selectedFeeling,
        note: note.isNotEmpty ? note : null,
      );
      try {
        await _logService.saveWorkoutLog(updated);
      } catch (_) {}
    }
  }

  Future<void> _handleDone() async {
    await _persistFeedback();
    if (widget.onDone != null) {
      widget.onDone!();
    } else {
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }

  Future<void> _handleLogAnother() async {
    await _persistFeedback();
    if (widget.onLogAnother != null) {
      widget.onLogAnother!();
    } else {
      if (mounted) {
        await Navigator.of(context).pushReplacementNamed(MovementRoutes.picker);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final sportsColor = context.modules.sports;

    final durationMins = (widget.workoutLog.durationSec / 60).round();

    return MovementScreenShell(
      title: MovementStrings.summaryTitle,
      actions: [
        IconButton(
          icon: const Icon(Icons.close_rounded),
          tooltip: 'بستن',
          onPressed: _handleDone,
        ),
      ],
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: RitmoSpacing.lg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: RitmoSpacing.sm),

                    // ناحیهٔ ۱: پیام تأیید متناسب با وضعیت کامل/نیمه‌تمام
                    Center(
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: sportsColor.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              widget.isPartial
                                  ? Icons.timelapse_rounded
                                  : Icons.check_circle_rounded,
                              color: sportsColor,
                              size: 36,
                            ),
                          ),
                          const SizedBox(height: RitmoSpacing.sm),
                          Text(
                            widget.isPartial
                                ? MovementStrings.summarySubtitlePartial
                                : MovementStrings.summarySubtitleCompleted,
                            style: RitmoTextStyles.sectionHeadline(
                              colors.textPrimary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          if (widget.activityKind != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              widget.activityKind!.nameFa,
                              style: RitmoTextStyles.caption(
                                colors.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: RitmoSpacing.lg),

                    // ناحیهٔ ۲: متریک‌های واقعی جلسه
                    SummaryMetricBlock(workoutLog: widget.workoutLog),
                    const SizedBox(height: RitmoSpacing.md),

                    // ناحیهٔ ۳: مقایسه با جلسهٔ قبل (فقط در صورت وجود دادهٔ معتبر قبلی)
                    if (widget.previousLog != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(RitmoSpacing.md),
                        decoration: BoxDecoration(
                          color: colors.surfaceSunken,
                          borderRadius: BorderRadius.circular(RitmoRadius.card),
                          border: Border.all(color: colors.border),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.compare_arrows_rounded,
                              color: sportsColor,
                              size: 20,
                            ),
                            const SizedBox(width: RitmoSpacing.sm),
                            Expanded(
                              child: Text(
                                'جلسهٔ قبل: ${toPersianDigits((widget.previousLog!.durationSec / 60).round())} دقیقه',
                                style: RitmoTextStyles.body(
                                  colors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: RitmoSpacing.md),
                    ],

                    // ناحیهٔ ۴: رکورد شخصی (PR) شرطی
                    if (widget.isPr &&
                        widget.prTitle != null &&
                        widget.prValue != null) ...[
                      SummaryPrBlock(
                        prTitle: widget.prTitle!,
                        prValue: widget.prValue!,
                      ),
                      const SizedBox(height: RitmoSpacing.md),
                    ],

                    // ناحیهٔ ۵: حس بعد از تمرین و یادداشت
                    SummaryFeelingPicker(
                      selectedFeeling: _selectedFeeling,
                      onFeelingChanged: (feel) =>
                          setState(() => _selectedFeeling = feel),
                      noteController: _noteController,
                    ),
                    const SizedBox(height: RitmoSpacing.md),

                    // ناحیهٔ ۶: اثر روی هدف هفته
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(RitmoSpacing.md),
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(RitmoRadius.card),
                        border: Border.all(color: colors.border),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.auto_graph_rounded,
                            color: sportsColor,
                            size: 20,
                          ),
                          const SizedBox(width: RitmoSpacing.sm),
                          Expanded(
                            child: Text(
                              '+${toPersianDigits(durationMins)} دقیقه به دقایق تمرین این هفته اضافه شد.',
                              style: RitmoTextStyles.body(colors.textPrimary),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // پیشنهاد QuickStart برای اضافه کردن به برنامهٔ هفتگی
                    if (widget.isQuickStart) ...[
                      const SizedBox(height: RitmoSpacing.md),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(RitmoSpacing.md),
                        decoration: BoxDecoration(
                          color: sportsColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(RitmoRadius.card),
                          border: Border.all(
                            color: sportsColor.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              MovementStrings.summaryAddToPlanPrompt,
                              style: RitmoTextStyles.label(colors.textPrimary),
                            ),
                            const SizedBox(height: RitmoSpacing.sm),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.of(context).pushNamed(
                                  MovementRoutes.planEditor,
                                  arguments: {
                                    'activityKind': widget.activityKind,
                                  },
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: sportsColor,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    RitmoRadius.field,
                                  ),
                                ),
                              ),
                              child: Text(
                                MovementStrings.summaryAddToPlanButton,
                                style: RitmoTextStyles.label(Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: RitmoSpacing.xl),
                  ],
                ),
              ),
            ),

            // ناحیهٔ ۷: دو اکشن «تمام» و «ثبت یک جلسهٔ دیگر»
            Padding(
              padding: const EdgeInsets.all(RitmoSpacing.lg),
              child: Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: OutlinedButton(
                      onPressed: _handleLogAnother,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(
                          48,
                          MovementLayout.kFieldMinHeight,
                        ),
                        side: BorderSide(color: colors.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            RitmoRadius.field,
                          ),
                        ),
                      ),
                      child: Text(
                        MovementStrings.summaryLogAnother,
                        style: RitmoTextStyles.label(colors.textPrimary),
                      ),
                    ),
                  ),
                  const SizedBox(width: RitmoSpacing.md),
                  Expanded(
                    flex: 1,
                    child: ElevatedButton(
                      onPressed: _handleDone,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(
                          48,
                          MovementLayout.kFieldMinHeight,
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
                        MovementStrings.summaryDone,
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
