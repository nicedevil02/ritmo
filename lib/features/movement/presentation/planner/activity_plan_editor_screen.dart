import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/movement/domain/models/movement_activity_kind.dart';
import 'package:ritmo/features/movement/domain/models/movement_change_scope.dart';
import 'package:ritmo/features/movement/presentation/activity_picker/activity_picker_screen.dart';
import 'package:ritmo/features/movement/presentation/common/error_block.dart';
import 'package:ritmo/features/movement/presentation/common/movement_icons.dart';
import 'package:ritmo/features/movement/presentation/common/movement_screen_shell.dart';
import 'package:ritmo/features/movement/presentation/common/movement_strings.dart';
import 'package:ritmo/features/movement/presentation/common/skeletons.dart';
import 'package:ritmo/features/movement/presentation/common/undo_toast.dart';
import 'package:ritmo/features/movement/presentation/planner/activity_plan_editor_controller.dart';
import 'package:ritmo/features/movement/presentation/planner/sheets/scope_picker_sheet.dart';
import 'package:ritmo/features/movement/presentation/planner/widgets/conflict_panel.dart';
import 'package:ritmo/features/movement/presentation/planner/widgets/goal_field_group.dart';
import 'package:ritmo/features/movement/presentation/planner/widgets/plan_preview_card.dart';
import 'package:ritmo/features/movement/presentation/planner/widgets/weekday_chips.dart';

/// صفحهٔ جامع برنامه‌ریزی ۸مرحله‌ای تک‌صفحه‌ای حرکت (ActivityPlanEditorScreen)
class ActivityPlanEditorScreen extends StatefulWidget {
  const ActivityPlanEditorScreen({
    super.key,
    this.controller,
    this.activityKindId,
    this.existingTemplateId,
    this.initialDate,
  });

  final ActivityPlanEditorController? controller;
  final String? activityKindId;
  final String? existingTemplateId;
  final DateTime? initialDate;

  @override
  State<ActivityPlanEditorScreen> createState() => _ActivityPlanEditorScreenState();
}

class _ActivityPlanEditorScreenState extends State<ActivityPlanEditorScreen> {
  late final ActivityPlanEditorController _controller;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ??
        ActivityPlanEditorController(
          initialActivityKindId: widget.activityKindId,
          existingTemplateId: widget.existingTemplateId,
          initialDate: widget.initialDate,
        );

    if (_controller.isLoading) {
      _controller.init();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  Future<bool> _onWillPop() async {
    if (!_controller.isDirty) return true;

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final colors = ctx.colors;
        final sportsColor = ctx.modules.sports;

        return AlertDialog(
          backgroundColor: colors.surfaceElevated,
          title: Text(
            MovementStrings.plannerDiscardTitle,
            style: RitmoTextStyles.sectionHeadline(colors.textPrimary),
          ),
          content: Text(
            MovementStrings.plannerDiscardMessage,
            style: RitmoTextStyles.body(colors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop('discard'),
              child: Text(
                MovementStrings.plannerActionDiscard,
                style: RitmoTextStyles.label(colors.error),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop('continue'),
              child: Text(
                MovementStrings.plannerActionContinue,
                style: RitmoTextStyles.label(colors.textPrimary),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop('save'),
              style: ElevatedButton.styleFrom(
                backgroundColor: sportsColor,
                foregroundColor: Colors.white,
              ),
              child: Text(
                MovementStrings.plannerActionSaveAndExit,
                style: RitmoTextStyles.label(Colors.white),
              ),
            ),
          ],
        );
      },
    );

    if (result == 'discard') return true;
    if (result == 'save') {
      await _handleSave();
      return true;
    }
    return false;
  }

  Future<void> _handleSave() async {
    MovementChangeScope scope = MovementChangeScope.wholePlan;
    if (_controller.existingTemplateId != null) {
      final pickedScope = await ScopePickerSheet.show(context);
      if (pickedScope == null) return;
      scope = pickedScope;
    }

    final createdCount = await _controller.savePlan(scope: scope);
    if (!mounted) return;

    if (createdCount > 0) {
      MovementUndoToast.show(
        context,
        message: MovementStrings.planSavedToast(createdCount),
      );
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final sportsColor = context.modules.sports;

    return PopScope(
      canPop: !_controller.isDirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          return MovementScreenShell(
            title: MovementStrings.plannerTitle,
            subtitle: _controller.activityKind?.nameFa ?? 'برنامه‌ریزی جدید',
            body: _controller.isLoading
                ? const Padding(
                    padding: EdgeInsets.all(RitmoSpacing.lg),
                    child: Column(
                      children: [
                        CardSkeleton(height: 120),
                        SizedBox(height: RitmoSpacing.md),
                        CardSkeleton(height: 160),
                        SizedBox(height: RitmoSpacing.md),
                        CardSkeleton(height: 180),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: RitmoSpacing.lg,
                      vertical: RitmoSpacing.md,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // پیام خطا در صورت شکست
                        if (_controller.errorMessage != null) ...[
                          ErrorBlock(
                            title: 'خطا در بارگذاری برنامه',
                            message: _controller.errorMessage!,
                            onRetry: _controller.init,
                            isBannerMode: true,
                          ),
                          const SizedBox(height: RitmoSpacing.md),
                        ],

                        // مرحله ۱: انتخاب فعالیت
                        _buildStepHeader(context, 1, MovementStrings.plannerStepActivity),
                        _buildActivitySelectionCard(context, colors, sportsColor),
                        const SizedBox(height: RitmoSpacing.xl),

                        // مرحله ۲: نوع جلسه
                        _buildStepHeader(context, 2, MovementStrings.plannerStepSessionType),
                        _buildSessionTypeChips(context, colors, sportsColor),
                        const SizedBox(height: RitmoSpacing.xl),

                        // مرحله ۳: هدف
                        _buildStepHeader(context, 3, MovementStrings.plannerStepGoal),
                        if (_controller.activityKind != null)
                          GoalFieldGroup(
                            family: _controller.activityKind!.family,
                            primaryMetric: _controller.activityKind!.primaryMetric,
                            initialGoalType: _controller.goalType,
                            initialGoalValue: _controller.goalValue,
                            initialGoalUnit: _controller.goalUnit,
                            onGoalChanged: (type, val, unit) {
                              _controller.setGoal(type, val, unit);
                            },
                          ),
                        const SizedBox(height: RitmoSpacing.xl),

                        // مرحله ۴: زمان‌بندی
                        _buildStepHeader(context, 4, MovementStrings.plannerStepSchedule),
                        WeekdayChips(
                          initialSchedules: _controller.schedules,
                          onSchedulesChanged: (schs) {
                            _controller.setSchedules(schs);
                          },
                        ),
                        const SizedBox(height: RitmoSpacing.xl),

                        // مرحله ۵: یادآوری
                        _buildStepHeader(context, 5, MovementStrings.plannerStepReminder),
                        _buildReminderChips(context, colors, sportsColor),
                        const SizedBox(height: RitmoSpacing.xl),

                        // مرحله ۶: محدودیت‌ها و تداخل
                        _buildStepHeader(context, 6, MovementStrings.plannerStepConstraints),
                        ConflictPanel(
                          conflicts: _controller.conflicts,
                          onSuggestionPickOtherTime: () {},
                          onSuggestionShorten: () {
                            _controller.setGoal(_controller.goalType, 15.0, _controller.goalUnit);
                          },
                          onSuggestionMoveToFreeDay: () {},
                          onSuggestionKeepBoth: () {},
                        ),
                        const SizedBox(height: RitmoSpacing.xl),

                        // مرحله ۷ و ۸: پیش‌نمایش و تأیید و ذخیره
                        _buildStepHeader(context, 7, MovementStrings.plannerStepPreview),
                        if (_controller.activityKind != null)
                          PlanPreviewCard(
                            activityKind: _controller.activityKind!,
                            schedules: _controller.schedules,
                            goalType: _controller.goalType,
                            goalValue: _controller.goalValue,
                            goalUnit: _controller.goalUnit,
                            reminderType: _controller.reminderType,
                            isSaving: _controller.state == PlanEditorState.saving,
                            disabledReason: _controller.disabledReason,
                            onConfirm: _controller.isValid ? _handleSave : null,
                            onEdit: () {
                              _scrollController.animateTo(
                                0,
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeOut,
                              );
                            },
                          ),
                        const SizedBox(height: RitmoSpacing.xxxl),
                      ],
                    ),
                  ),
          );
        },
      ),
    );
  }

  Widget _buildStepHeader(BuildContext context, int stepIndex, String title) {
    final colors = context.colors;
    final sportsColor = context.modules.sports;

    return Padding(
      padding: const EdgeInsets.only(bottom: RitmoSpacing.sm),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: sportsColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              toPersianDigits(stepIndex),
              style: RitmoTextStyles.badge(sportsColor),
            ),
          ),
          const SizedBox(width: RitmoSpacing.sm),
          Text(
            title,
            style: RitmoTextStyles.sectionHeadline(colors.textPrimary),
          ),
        ],
      ),
    );
  }

  Widget _buildActivitySelectionCard(
    BuildContext context,
    dynamic colors,
    Color sportsColor,
  ) {
    final kind = _controller.activityKind;
    if (kind == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(RitmoSpacing.md),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(RitmoRadius.card),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: sportsColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(RitmoRadius.iconButton),
            ),
            alignment: Alignment.center,
            child: Icon(
              MovementIcons.fromKey(kind.icon),
              color: sportsColor,
              size: 24,
            ),
          ),
          const SizedBox(width: RitmoSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  kind.nameFa,
                  style: RitmoTextStyles.cardTitle(colors.textPrimary),
                ),
                Text(
                  'خانوادهٔ ${kind.family}',
                  style: RitmoTextStyles.caption(colors.textSecondary),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () async {
              final newKind = await Navigator.of(context).push<dynamic>(
                MaterialPageRoute(
                  builder: (_) => ActivityPickerScreen(
                    intent: ActivityPickerIntent.addToPlan,
                    onSelected: (k) => Navigator.of(context).pop(k),
                  ),
                ),
              );
              if (newKind is MovementActivityKind) {
                _controller.setActivityKind(newKind);
              }
            },
            child: Text(
              'تغییر فعالیت',
              style: RitmoTextStyles.label(sportsColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionTypeChips(
    BuildContext context,
    dynamic colors,
    Color sportsColor,
  ) {
    final types = {
      'repeating': MovementStrings.plannerSessionRepeating,
      'simple': MovementStrings.plannerSessionSimple,
      'structured': MovementStrings.plannerSessionStructured,
      'event': MovementStrings.plannerSessionEvent,
      'retro': MovementStrings.plannerSessionRetro,
    };

    return Wrap(
      spacing: RitmoSpacing.sm,
      children: types.entries.map((e) {
        final isSelected = _controller.sessionType == e.key;
        return ChoiceChip(
          label: Text(
            e.value,
            style: RitmoTextStyles.caption(
              isSelected ? Colors.white : colors.textPrimary,
            ),
          ),
          selected: isSelected,
          selectedColor: sportsColor,
          backgroundColor: colors.surface,
          side: BorderSide(color: isSelected ? sportsColor : colors.border),
          onSelected: (sel) {
            if (sel) _controller.setSessionType(e.key);
          },
        );
      }).toList(),
    );
  }

  Widget _buildReminderChips(
    BuildContext context,
    dynamic colors,
    Color sportsColor,
  ) {
    final reminders = {
      'none': MovementStrings.plannerReminderNone,
      'preSession': MovementStrings.plannerReminderPreSession,
      'morning': MovementStrings.plannerReminderMorning,
    };

    return Wrap(
      spacing: RitmoSpacing.sm,
      children: reminders.entries.map((e) {
        final isSelected = _controller.reminderType == e.key;
        return ChoiceChip(
          label: Text(
            e.value,
            style: RitmoTextStyles.caption(
              isSelected ? Colors.white : colors.textPrimary,
            ),
          ),
          selected: isSelected,
          selectedColor: sportsColor,
          backgroundColor: colors.surface,
          side: BorderSide(color: isSelected ? sportsColor : colors.border),
          onSelected: (sel) {
            if (sel) {
              _controller.setReminder(e.key, e.key == 'preSession' ? 15 : null);
            }
          },
        );
      }).toList(),
    );
  }
}
