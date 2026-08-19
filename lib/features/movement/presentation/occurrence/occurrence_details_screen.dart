import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/movement/application/movement_log_service.dart';
import 'package:ritmo/features/movement/application/movement_occurrence_service.dart';
import 'package:ritmo/features/movement/application/movement_planning_service.dart';
import 'package:ritmo/features/movement/domain/models/movement_change_scope.dart';
import 'package:ritmo/features/movement/domain/models/movement_occurrence.dart';
import 'package:ritmo/features/movement/domain/models/movement_workout_log.dart';
import 'package:ritmo/features/movement/presentation/center/sheets/move_session_sheet.dart';
import 'package:ritmo/features/movement/presentation/center/sheets/plan_b_sheet.dart';
import 'package:ritmo/features/movement/presentation/center/sheets/quick_complete_sheet.dart';
import 'package:ritmo/features/movement/presentation/center/sheets/skip_session_sheet.dart';
import 'package:ritmo/features/movement/presentation/common/error_block.dart';
import 'package:ritmo/features/movement/presentation/common/metric_stat.dart';
import 'package:ritmo/features/movement/presentation/common/movement_screen_shell.dart';
import 'package:ritmo/features/movement/presentation/common/movement_strings.dart';
import 'package:ritmo/features/movement/presentation/common/skeletons.dart';
import 'package:ritmo/features/movement/presentation/common/undo_toast.dart';
import 'package:ritmo/features/movement/presentation/movement_routes.dart';
import 'package:ritmo/features/movement/presentation/occurrence/widgets/occurrence_actions.dart';
import 'package:ritmo/features/movement/presentation/occurrence/widgets/occurrence_header.dart';
import 'package:ritmo/features/movement/presentation/planner/sheets/scope_picker_sheet.dart';

/// صفحهٔ جامع نمایش جزئیات جلسه و مدیریت اکشن‌های آن (ActivityOccurrenceDetailsScreen)
class ActivityOccurrenceDetailsScreen extends StatefulWidget {
  const ActivityOccurrenceDetailsScreen({
    super.key,
    required this.occurrenceId,
    this.occurrenceService,
    this.planningService,
    this.logService,
  });

  final String occurrenceId;
  final MovementOccurrenceService? occurrenceService;
  final MovementPlanningService? planningService;
  final MovementLogService? logService;

  @override
  State<ActivityOccurrenceDetailsScreen> createState() =>
      _ActivityOccurrenceDetailsScreenState();
}

class _ActivityOccurrenceDetailsScreenState
    extends State<ActivityOccurrenceDetailsScreen> {
  late final MovementOccurrenceService _occurrenceService;
  late final MovementPlanningService _planningService;
  late final MovementLogService _logService;

  bool _isLoading = true;
  String? _errorMessage;
  MovementOccurrence? _occurrence;
  List<MovementWorkoutLog> _logs = [];

  @override
  void initState() {
    super.initState();
    _occurrenceService =
        widget.occurrenceService ?? MovementOccurrenceService();
    _planningService = widget.planningService ?? MovementPlanningService();
    _logService = widget.logService ?? MovementLogService();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final occ = await _occurrenceService.getOccurrenceById(
        widget.occurrenceId,
      );
      final logs = await _occurrenceService.getOccurrenceLogs(
        widget.occurrenceId,
      );
      if (mounted) {
        setState(() {
          _occurrence = occ;
          _logs = logs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  String _getOriginText(MovementOccurrence occ) {
    if (occ.templateId != null) return MovementStrings.occurrenceOriginTemplate;
    if (occ.origin == MovementOrigin.strength)
      return MovementStrings.occurrenceOriginStrength;
    if (occ.origin == MovementOrigin.quickStart)
      return MovementStrings.occurrenceOriginManual;
    return MovementStrings.occurrenceOriginOnce;
  }

  Future<void> _startSession() async {
    if (_occurrence == null) return;
    await Navigator.of(context).pushNamed(
      MovementRoutes.liveSession,
      arguments: {
        'activityKindId': _occurrence!.activityKindId,
        'occurrenceId': _occurrence!.id,
      },
    );
  }

  Future<void> _quickComplete() async {
    if (_occurrence == null) return;
    final done = await QuickCompleteSheet.show(
      context,
      occurrence: _occurrence!,
      onQuickComplete: (dur, metric, feel, note) async {
        await _logService.quickCompleteOccurrence(
          occurrenceId: _occurrence!.id,
          activityKindId: _occurrence!.activityKindId,
          dateIso: _occurrence!.dateIso,
          startTime: _occurrence!.startTime,
          durationSec: dur,
          feeling: feel,
          note: note,
        );
      },
    );

    if (done == true && mounted) {
      MovementUndoToast.show(
        context,
        message: 'جلسه با موفقیت به عنوان انجام‌شده ثبت شد',
      );
      await _loadData();
    }
  }

  Future<void> _moveSession() async {
    if (_occurrence == null) return;
    final done = await MoveSessionSheet.show(
      context,
      occurrence: _occurrence!,
      onMoveConfirm: (newDate, newTime, scope) async {
        await _planningService.moveOccurrence(
          occurrenceId: _occurrence!.id,
          newDateIso: newDate,
          newStartTime: newTime,
          scope: scope,
        );
      },
    );

    if (done == true && mounted) {
      MovementUndoToast.show(
        context,
        message: MovementStrings.undoMovedTodayOnly,
      );
      await _loadData();
    }
  }

  Future<void> _applyPlanB() async {
    if (_occurrence == null) return;
    final done = await PlanBSheet.show(
      context,
      occurrence: _occurrence!,
      onApplyPlanB: (option, newGoalValue) async {
        if (option == PlanBOption.recovery) {
          await _occurrenceService.updateOccurrenceStatus(
            _occurrence!.id,
            MovementOccurrenceStatus.restDay,
          );
        } else {
          await _planningService.shortenOccurrence(
            occurrenceId: _occurrence!.id,
            newGoalValue: newGoalValue,
          );
        }
      },
    );

    if (done == true && mounted) {
      MovementUndoToast.show(
        context,
        message: 'نسخهٔ Plan B با موفقیت اعمال شد',
      );
      await _loadData();
    }
  }

  Future<void> _skipSession() async {
    if (_occurrence == null) return;
    final choice = await SkipSessionSheet.show(context);
    if (choice == null || !mounted) return;

    switch (choice) {
      case SkipActionChoice.skipTodayOnly:
        await _planningService.skipOccurrence(occurrenceId: _occurrence!.id);
        if (mounted) {
          MovementUndoToast.show(
            context,
            message: MovementStrings.undoSkippedToday,
          );
          await _loadData();
        }
        break;
      case SkipActionChoice.moveToOtherDay:
        await _moveSession();
        break;
      case SkipActionChoice.shortVersion:
        await _applyPlanB();
        break;
      case SkipActionChoice.editTemplate:
        await _editPlan();
        break;
    }
  }

  Future<void> _editPlan() async {
    if (_occurrence == null) return;
    if (_occurrence!.templateId != null) {
      final scope = await ScopePickerSheet.show(context);
      if (scope == null || !mounted) return;

      final updated = await Navigator.of(context).pushNamed(
        MovementRoutes.planEditor,
        arguments: {
          'existingTemplateId': _occurrence!.templateId,
          'activityKindId': _occurrence!.activityKindId,
        },
      );
      if (updated == true && mounted) {
        await _loadData();
      }
    } else {
      final updated = await Navigator.of(context).pushNamed(
        MovementRoutes.planEditor,
        arguments: {'activityKindId': _occurrence!.activityKindId},
      );
      if (updated == true && mounted) {
        await _loadData();
      }
    }
  }

  Future<void> _deleteSession() async {
    if (_occurrence == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final colors = ctx.colors;
        return AlertDialog(
          backgroundColor: colors.surfaceElevated,
          title: Text(
            MovementStrings.occurrenceDeleteConfirmTitle,
            style: RitmoTextStyles.sectionHeadline(colors.textPrimary),
          ),
          content: Text(
            MovementStrings.occurrenceDeleteConfirmDesc,
            style: RitmoTextStyles.body(colors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text(MovementStrings.commonCancel),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: colors.error),
              child: const Text(
                MovementStrings.commonDelete,
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      await _planningService.deleteWithScope(
        occurrenceId: _occurrence!.id,
        focalDateIso: _occurrence!.dateIso,
        templateId: _occurrence!.templateId,
        scope: MovementChangeScope.onlyThis,
      );

      if (mounted) {
        MovementUndoToast.show(
          context,
          message: MovementStrings.undoSessionDeleted,
        );
        Navigator.of(context).pop(true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return MovementScreenShell(
      title: MovementStrings.occurrenceDetailsTitle,
      subtitle: _occurrence?.displayName,
      body: _isLoading
          ? const Padding(
              padding: EdgeInsets.all(RitmoSpacing.lg),
              child: Column(
                children: [
                  CardSkeleton(height: 100),
                  SizedBox(height: RitmoSpacing.md),
                  CardSkeleton(height: 120),
                  SizedBox(height: RitmoSpacing.md),
                  CardSkeleton(height: 140),
                ],
              ),
            )
          : _occurrence == null
          ? Center(
              child: Text(
                'جلسه یافت نشد.',
                style: RitmoTextStyles.body(colors.textSecondary),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: RitmoSpacing.lg,
                vertical: RitmoSpacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_errorMessage != null) ...[
                    ErrorBlock(
                      title: 'خطا در بارگذاری جزئیات جلسه',
                      message: _errorMessage!,
                      onRetry: _loadData,
                      isBannerMode: true,
                    ),
                    const SizedBox(height: RitmoSpacing.md),
                  ],

                  // ۱. سربرگ جلسه
                  OccurrenceHeader(occurrence: _occurrence!),
                  const SizedBox(height: RitmoSpacing.lg),

                  // ۲. هدف جلسه
                  if (_occurrence!.goalValue != null) ...[
                    _buildSectionCard(
                      context,
                      title: MovementStrings.occurrenceGoal,
                      content: Row(
                        children: [
                          MetricStat(
                            label: 'هدف تعیین‌شده',
                            value: _occurrence!.goalValue!.toInt().toString(),
                            unit: _occurrence!.goalUnit,
                          ),
                        ],
                      ),
                      colors: colors,
                    ),
                    const SizedBox(height: RitmoSpacing.md),
                  ],

                  // ۳. منشأ جلسه و یادآور
                  _buildSectionCard(
                    context,
                    title: MovementStrings.occurrenceOrigin,
                    content: Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          color: colors.textSecondary,
                          size: 20,
                        ),
                        const SizedBox(width: RitmoSpacing.sm),
                        Text(
                          _getOriginText(_occurrence!),
                          style: RitmoTextStyles.body(colors.textPrimary),
                        ),
                      ],
                    ),
                    colors: colors,
                  ),
                  const SizedBox(height: RitmoSpacing.md),

                  // ۴. تاریخچهٔ ثبت تمرین (Log)
                  _buildSectionCard(
                    context,
                    title: MovementStrings.occurrenceHistory,
                    content: _logs.isEmpty
                        ? Text(
                            MovementStrings.occurrenceNoHistory,
                            style: RitmoTextStyles.caption(
                              colors.textSecondary,
                            ),
                          )
                        : Column(
                            children: _logs.map((log) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.check_circle_rounded,
                                      color: colors.success,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${toPersianDigits(log.durationSec ~/ 60)} دقیقه ثبت‌شده (${log.source})',
                                      style: RitmoTextStyles.body(
                                        colors.textPrimary,
                                      ).copyWith(fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                    colors: colors,
                  ),
                  const SizedBox(height: RitmoSpacing.xl),

                  // ۵. فهرست کامل اکشن‌ها
                  Text(
                    'عملیات جلسه',
                    style: RitmoTextStyles.sectionHeadline(colors.textPrimary),
                  ),
                  const SizedBox(height: RitmoSpacing.sm),
                  OccurrenceActions(
                    occurrence: _occurrence!,
                    onStartSession: _startSession,
                    onQuickComplete: _quickComplete,
                    onMoveSession: _moveSession,
                    onPlanB: _applyPlanB,
                    onSkipSession: _skipSession,
                    onEditPlan: _editPlan,
                    onDeleteSession: _deleteSession,
                  ),
                  const SizedBox(height: RitmoSpacing.xxxl),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionCard(
    BuildContext context, {
    required String title,
    required Widget content,
    required dynamic colors,
  }) {
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
          Text(title, style: RitmoTextStyles.label(colors.textSecondary)),
          const SizedBox(height: RitmoSpacing.xs),
          content,
        ],
      ),
    );
  }
}
