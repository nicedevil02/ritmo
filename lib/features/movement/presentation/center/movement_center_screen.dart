import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/movement/domain/models/movement_plan_schedule.dart';
import 'package:ritmo/features/movement/presentation/movement_routes.dart';
import 'package:ritmo/features/movement/application/movement_log_service.dart';
import 'package:ritmo/features/movement/application/movement_occurrence_service.dart';
import 'package:ritmo/features/movement/application/movement_planning_service.dart';
import 'package:ritmo/features/movement/application/movement_session_service.dart';
import 'package:ritmo/features/movement/application/strength_program_service.dart';
import 'package:ritmo/features/movement/domain/models/movement_activity_kind.dart';
import 'package:ritmo/features/movement/domain/models/movement_change_scope.dart';
import 'package:ritmo/features/movement/domain/models/movement_occurrence.dart';
import 'package:ritmo/features/movement/presentation/activity_picker/activity_picker_screen.dart';
import 'package:ritmo/features/movement/presentation/activity_picker/sheets/retro_log_form_sheet.dart';
import 'package:ritmo/features/movement/presentation/center/movement_center_controller.dart';
import 'package:ritmo/features/movement/presentation/center/sheets/add_command_sheet.dart';
import 'package:ritmo/features/movement/presentation/center/sheets/move_session_sheet.dart';
import 'package:ritmo/features/movement/presentation/center/sheets/plan_b_sheet.dart';
import 'package:ritmo/features/movement/presentation/center/sheets/quick_complete_sheet.dart';
import 'package:ritmo/features/movement/presentation/center/sheets/skip_session_sheet.dart';
import 'package:ritmo/features/movement/presentation/center/sheets/smart_fill_sheet.dart';
import 'package:ritmo/features/movement/presentation/center/widgets/add_activity_dock.dart';
import 'package:ritmo/features/movement/presentation/session/movement_live_session_screen.dart';
import 'package:ritmo/features/movement/presentation/center/widgets/hero_session_card.dart';
import 'package:ritmo/features/movement/presentation/center/widgets/live_session_banner.dart';
import 'package:ritmo/features/movement/presentation/center/widgets/recovery_day_card.dart';
import 'package:ritmo/features/movement/presentation/center/widgets/session_card.dart';
import 'package:ritmo/features/movement/presentation/center/widgets/strength_entry_card.dart';
import 'package:ritmo/features/movement/presentation/center/widgets/week_navigator_bar.dart';
import 'package:ritmo/features/movement/presentation/center/widgets/week_rail.dart';
import 'package:ritmo/features/movement/presentation/center/widgets/week_summary_card.dart';
import 'package:ritmo/features/movement/presentation/common/confirm_dialog.dart';
import 'package:ritmo/features/movement/presentation/common/empty_state_block.dart';
import 'package:ritmo/features/movement/presentation/common/error_block.dart';
import 'package:ritmo/features/movement/presentation/common/movement_layout.dart';
import 'package:ritmo/features/movement/presentation/common/movement_screen_shell.dart';
import 'package:ritmo/features/movement/presentation/common/movement_strings.dart';
import 'package:ritmo/features/movement/presentation/common/skeletons.dart';
import 'package:ritmo/features/movement/presentation/common/undo_toast.dart';
import 'package:ritmo/features/movement/presentation/occurrence/occurrence_details_screen.dart';
import 'package:ritmo/features/movement/presentation/planner/activity_plan_editor_screen.dart';
import 'package:ritmo/features/movement/presentation/planner/sheets/scope_picker_sheet.dart';

/// صفحهٔ مرکز حرکت (Gate 1 & Gate 2) — ساخته‌شده بر پایهٔ [MovementScreenShell]
class MovementCenterScreen extends StatefulWidget {
  const MovementCenterScreen({
    super.key,
    this.controller,
    this.initialDate,
    this.onNavigateToRoute,
    this.onOpenAddActivity,
  });

  final MovementCenterController? controller;
  final DateTime? initialDate;
  final void Function(String route, {Map<String, dynamic>? arguments})? onNavigateToRoute;
  final VoidCallback? onOpenAddActivity;

  @override
  State<MovementCenterScreen> createState() => _MovementCenterScreenState();
}

class _MovementCenterScreenState extends State<MovementCenterScreen> {
  late final MovementCenterController _controller;
  bool _isInternalController = false;
  final _planningService = MovementPlanningService();
  final _logService = MovementLogService();
  final _occurrenceService = MovementOccurrenceService();

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller = widget.controller!;
    } else {
      _isInternalController = true;
      _controller = MovementCenterController(
        occurrenceService: _occurrenceService,
        sessionService: MovementSessionService(),
        strengthProgramService: StrengthProgramService(),
        initialDate: widget.initialDate,
      );
      _controller.loadData();
    }
  }

  @override
  void dispose() {
    if (_isInternalController) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _navigateTo(String route, {Map<String, dynamic>? arguments}) {
    if (widget.onNavigateToRoute != null) {
      widget.onNavigateToRoute!(route, arguments: arguments);
    } else {
      Navigator.of(context).pushNamed(route, arguments: arguments);
    }
  }

  Future<void> _openAddCommandSheet() async {
    await AddCommandSheet.show(
      context,
      hasActiveLiveSession: _controller.activeLiveSession?.isActiveOrPaused ?? false,
      hasActiveStrengthProgram: _controller.strengthProgram != null,
      onStartNow: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const ActivityPickerScreen(
              intent: ActivityPickerIntent.startNow,
            ),
          ),
        );
      },
      onAddToPlan: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const ActivityPlanEditorScreen(),
          ),
        ).then((_) => _controller.loadData());
      },
      onRetroLog: () async {
        final kind = await Navigator.of(context).push<MovementActivityKind>(
          MaterialPageRoute(
            builder: (_) => const ActivityPickerScreen(
              intent: ActivityPickerIntent.retroLog,
            ),
          ),
        );
        if (kind != null && mounted) {
          final log = await RetroLogFormSheet.show(
            context,
            activityKind: kind,
            onSubmit: ({
              required dateIso,
              startTime,
              required durationSec,
              metrics,
              feeling,
              note,
              matchedOccurrenceId,
            }) async {
              return await _logService.logRetroWorkout(
                activityKindId: kind.id,
                dateIso: dateIso,
                startTime: startTime,
                durationSec: durationSec,
                metrics: metrics,
                feeling: feeling,
                note: note,
                matchedOccurrenceId: matchedOccurrenceId,
              );
            },
          );
          if (log != null && mounted) {
            MovementUndoToast.show(context, message: MovementStrings.retroLoggedToast);
            await _controller.loadData();
          }
        }
      },
      onResumeLiveSession: () => _navigateTo(MovementRoutes.liveSession),
      onStrengthHome: () => _navigateTo(MovementRoutes.strengthOnboarding),
    );
  }

  Future<void> _openSmartFillSheet() async {
    final kinds = await _occurrenceService.getAllActivityKinds();
    if (!mounted) return;

    final applied = await SmartFillSheet.show(
      context,
      availableKinds: kinds,
      onApplySuggestions: (items) async {
        final nowIso = MovementPlanningService.formatIso(DateTime.now());
        for (final item in items) {
          await _planningService.createPlan(
            activityKindId: item.activityKind.id,
            goal: {'type': 'duration', 'value': item.durationMin, 'unit': 'دقیقه'},
            schedules: [
              MovementPlanSchedule(
                id: '',
                templateId: '',
                weekday: item.weekday,
                timeOfDay: item.timeOfDay,
                recurrence: 'weekly',
                startDateIso: nowIso,
                createdAt: DateTime.now(),
              ),
            ],
          );
        }
      },
    );

    if (applied == true && mounted) {
      MovementUndoToast.show(context, message: MovementStrings.smartFillAppliedToast);
      await _controller.loadData();
    }
  }

  Future<void> _handleOccurrenceTap(MovementOccurrence occ) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ActivityOccurrenceDetailsScreen(occurrenceId: occ.id),
      ),
    );
    if (result == true) {
      await _controller.loadData();
    }
  }

  Future<void> _handleMove(MovementOccurrence occ) async {
    final done = await MoveSessionSheet.show(
      context,
      occurrence: occ,
      onMoveConfirm: (newDate, newTime, scope) async {
        await _planningService.moveOccurrence(
          occurrenceId: occ.id,
          newDateIso: newDate,
          newStartTime: newTime,
          scope: scope,
        );
      },
    );

    if (done == true && mounted) {
      MovementUndoToast.show(context, message: MovementStrings.undoMovedTodayOnly);
      await _controller.loadData();
    }
  }

  Future<void> _handlePlanB(MovementOccurrence occ) async {
    final done = await PlanBSheet.show(
      context,
      occurrence: occ,
      onApplyPlanB: (option, newGoalValue) async {
        if (option == PlanBOption.recovery) {
          await _occurrenceService.updateOccurrenceStatus(
            occ.id,
            MovementOccurrenceStatus.restDay,
          );
        } else {
          await _planningService.shortenOccurrence(
            occurrenceId: occ.id,
            newGoalValue: newGoalValue,
          );
        }
      },
    );

    if (done == true && mounted) {
      MovementUndoToast.show(context, message: MovementStrings.planBAppliedToast);
      await _controller.loadData();
    }
  }

  Future<void> _handleSkip(MovementOccurrence occ) async {
    final choice = await SkipSessionSheet.show(context);
    if (choice == null || !mounted) return;

    switch (choice) {
      case SkipActionChoice.skipTodayOnly:
        await _planningService.skipOccurrence(occurrenceId: occ.id);
        if (mounted) {
          MovementUndoToast.show(context, message: MovementStrings.undoSkippedToday);
          await _controller.loadData();
        }
        break;
      case SkipActionChoice.moveToOtherDay:
        await _handleMove(occ);
        break;
      case SkipActionChoice.shortVersion:
        await _handlePlanB(occ);
        break;
      case SkipActionChoice.editTemplate:
        await _handleEditPlan(occ);
        break;
    }
  }

  Future<void> _handleEditPlan(MovementOccurrence occ) async {
    if (occ.templateId != null) {
      final scope = await ScopePickerSheet.show(context);
      if (scope == null || !mounted) return;

      final updated = await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ActivityPlanEditorScreen(
            existingTemplateId: occ.templateId,
            activityKindId: occ.activityKindId,
          ),
        ),
      );
      if (updated == true && mounted) {
        await _controller.loadData();
      }
    } else {
      final updated = await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ActivityPlanEditorScreen(
            activityKindId: occ.activityKindId,
          ),
        ),
      );
      if (updated == true && mounted) {
        await _controller.loadData();
      }
    }
  }

  Future<void> _handleDelete(MovementOccurrence occ) async {
    // عملیات مخرب فقط با دیالوگ استاندارد ماژول و فهرست اثرات شفاف
    final confirmed = await showMovementConfirmDialog(
      context,
      title: MovementStrings.occurrenceDeleteConfirmTitle,
      message: MovementStrings.occurrenceDeleteConfirmDesc,
      impactList: const [MovementStrings.occurrenceDeleteConfirmDesc],
      confirmLabel: MovementStrings.commonDelete,
      cancelLabel: MovementStrings.commonCancel,
      destructive: true,
    );

    if (confirmed && mounted) {
      await _planningService.deleteWithScope(
        occurrenceId: occ.id,
        focalDateIso: occ.dateIso,
        templateId: occ.templateId,
        scope: MovementChangeScope.onlyThis,
      );

      if (mounted) {
        MovementUndoToast.show(context, message: MovementStrings.undoSessionDeleted);
        await _controller.loadData();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final colors = context.colors;

        final actions = [
          IconButton(
            tooltip: MovementStrings.progressTitle,
            icon: const Icon(Icons.insights_rounded),
            onPressed: () {
              RitmoHapticsPolicy.selection();
              _navigateTo(
                MovementRoutes.progress,
                arguments: {'weekStart': _controller.weekStartDate},
              );
            },
          ),
          IconButton(
            tooltip: MovementStrings.settingsTitle,
            icon: const Icon(Icons.tune_rounded),
            onPressed: () {
              RitmoHapticsPolicy.selection();
              _navigateTo(MovementRoutes.settings);
            },
          ),
        ];

        if (_controller.isLoading && !_controller.hasCachedData) {
          return MovementScreenShell(
            title: MovementStrings.centerTitle,
            actions: actions,
            body: const SingleChildScrollView(
              physics: NeverScrollableScrollPhysics(),
              child: Column(
                children: [
                  WeekRailSkeleton(),
                  SizedBox(height: RitmoSpacing.lg),
                  HeroSkeleton(),
                  SizedBox(height: RitmoSpacing.lg),
                  SessionCardSkeleton(),
                  SizedBox(height: RitmoSpacing.sm),
                  SessionCardSkeleton(),
                ],
              ),
            ),
          );
        }

        if (_controller.errorMessage != null && !_controller.hasCachedData) {
          return MovementScreenShell(
            title: MovementStrings.centerTitle,
            actions: actions,
            body: ErrorBlock(
              title: MovementStrings.centerLoadErrorTitle,
              message: _controller.errorMessage!,
              isBannerMode: false,
              onRetry: () => _controller.loadData(),
            ),
          );
        }

        final selectedOccurrences = _controller.selectedDayOccurrences;
        final hasLiveSession = _controller.activeLiveSession != null &&
            _controller.activeLiveSession!.isActiveOrPaused;

        return MovementScreenShell(
          title: MovementStrings.centerTitle,
          actions: actions,
          bottomDock: AddActivityDock(
            onAddActivity: () {
              if (widget.onOpenAddActivity != null) {
                widget.onOpenAddActivity!();
              } else {
                _openAddCommandSheet();
              }
            },
          ),
          body: RefreshIndicator(
            onRefresh: () => _controller.refresh(),
            color: colors.primary,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                if (_controller.isBannerError && _controller.errorMessage != null)
                  SliverToBoxAdapter(
                    child: ErrorBlock(
                      title: MovementStrings.centerSyncErrorTitle,
                      message: _controller.errorMessage!,
                      isBannerMode: true,
                      onRetry: () => _controller.loadData(),
                    ),
                  ),

                if (_controller.isFirstLaunchAfterCutover)
                  SliverToBoxAdapter(
                    child: Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: RitmoSpacing.lg,
                        vertical: RitmoSpacing.xs,
                      ),
                      padding: const EdgeInsets.all(RitmoSpacing.md),
                      decoration: BoxDecoration(
                        color: colors.surfaceElevated,
                        borderRadius: BorderRadius.circular(RitmoRadius.card),
                        border: Border.all(
                          color: colors.primary.withValues(alpha: 0.5),
                          width: 1.0,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline_rounded, color: colors.primary),
                          const SizedBox(width: RitmoSpacing.sm),
                          Expanded(
                            child: Text(
                              MovementStrings.cutoverCalloutDesc,
                              style: RitmoTextStyles.caption(colors.textPrimary),
                            ),
                          ),
                          TextButton(
                            onPressed: () => _controller.dismissCutoverCallout(),
                            child: Text(
                              MovementStrings.cutoverCalloutDismiss,
                              style: RitmoTextStyles.label(colors.primary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // ۱. ناوبری هفته (WeekNavigatorBar)
                SliverToBoxAdapter(
                  child: WeekNavigatorBar(
                    rangeTitle: _controller.weekRangeLabel,
                    isCurrentWeek: _controller.isCurrentWeek,
                    onPreviousWeek: () => _controller.changeWeek(-1),
                    onNextWeek: () => _controller.changeWeek(1),
                    onCurrentWeekPressed: () => _controller.goToThisWeek(),
                  ),
                ),

                // ۲. ریل هفته (WeekRail)
                SliverToBoxAdapter(
                  child: WeekRail(
                    days: _controller.weekDays,
                    onDaySelected: (date) => _controller.selectDay(date),
                    onDayReselected: (date) {
                      if (selectedOccurrences.isNotEmpty) {
                        _handleOccurrenceTap(selectedOccurrences.first);
                      }
                    },
                  ),
                ),

                // ۳. بنر جلسهٔ زنده (شرطی)
                if (hasLiveSession)
                  SliverToBoxAdapter(
                    child: LiveSessionBanner(
                      session: _controller.activeLiveSession!,
                      onResume: () => _navigateTo(MovementRoutes.liveSession),
                      onFinishAndSave: () => _navigateTo(MovementRoutes.summary),
                      onDiscard: () async {
                        await MovementSessionService().abandonSession(
                          _controller.activeLiveSession!.id,
                        );
                        await _controller.loadData();
                      },
                    ),
                  ),

                // ۴. کارت هیرو (HeroSessionCard)
                SliverToBoxAdapter(
                  child: HeroSessionCard(
                    variant: _controller.heroVariant,
                    primaryOccurrence: selectedOccurrences.isNotEmpty
                        ? selectedOccurrences.first
                        : null,
                    totalTodaySessions: selectedOccurrences.length,
                    currentSessionIndex: 1,
                    onPrimaryAction: () {
                      if (_controller.heroVariant == HeroCardVariant.emptyPlan ||
                          _controller.heroVariant == HeroCardVariant.noPlanToday) {
                        _openAddCommandSheet();
                      } else if (selectedOccurrences.isNotEmpty) {
                        final occ = selectedOccurrences.first;
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => MovementLiveSessionScreen(
                              activityKind: occ.activityKind ?? MovementActivityKind(
                                id: occ.activityKindId,
                                nameFa: occ.displayName,
                                family: 'general',
                                icon: 'directions_run',
                                primaryMetric: 'duration',
                                createdAt: DateTime.now(),
                              ),
                              occurrenceId: occ.id,
                              targetSnapshot: occ.goalValue != null
                                  ? {
                                      'type': occ.goalType ?? 'duration',
                                      'value': occ.goalValue,
                                      'unit': occ.goalUnit ?? MovementStrings.unitMinute,
                                    }
                                  : null,
                            ),
                          ),
                        ).then((_) => _controller.loadData());
                      }
                    },
                    onSecondaryAction: () {
                      if (_controller.heroVariant == HeroCardVariant.emptyPlan) {
                        _openSmartFillSheet();
                      } else if (_controller.heroVariant == HeroCardVariant.restDay) {
                        _navigateTo(
                          MovementRoutes.picker,
                          arguments: {'lightMode': true},
                        );
                      }
                    },
                    onMoveAction: () {
                      if (selectedOccurrences.isNotEmpty) {
                        _handleMove(selectedOccurrences.first);
                      }
                    },
                    onShortVersionAction: () {
                      if (selectedOccurrences.isNotEmpty) {
                        _handlePlanB(selectedOccurrences.first);
                      }
                    },
                    onLogManualAction: () {
                      if (selectedOccurrences.isNotEmpty) {
                        QuickCompleteSheet.show(
                          context,
                          occurrence: selectedOccurrences.first,
                          onQuickComplete: (dur, metric, feel, note) async {
                            await _logService.quickCompleteOccurrence(
                              occurrenceId: selectedOccurrences.first.id,
                              activityKindId: selectedOccurrences.first.activityKindId,
                              dateIso: selectedOccurrences.first.dateIso,
                              durationSec: dur,
                              feeling: feel,
                              note: note,
                            );
                          },
                        ).then((_) => _controller.loadData());
                      }
                    },
                    onSkipAction: () {
                      if (selectedOccurrences.isNotEmpty) {
                        _handleSkip(selectedOccurrences.first);
                      }
                    },
                    onLogAnotherAction: () => _openAddCommandSheet(),
                    onReviewWeekAction: () => _navigateTo(MovementRoutes.progress),
                  ),
                ),

                // ۵. سربرگ بخش برنامهٔ روز
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: RitmoSpacing.lg,
                      vertical: RitmoSpacing.sm,
                    ),
                    child: Text(
                      MovementStrings.centerDayPlan,
                      style: RitmoTextStyles.sectionHeadline(colors.textPrimary),
                    ),
                  ),
                ),

                // ۶. لیست روز (SessionCard | RecoveryDayCard | EmptyStateBlock)
                if (selectedOccurrences.isNotEmpty)
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final occ = selectedOccurrences[index];
                        return SessionCard(
                          occurrence: occ,
                          onTap: () => _handleOccurrenceTap(occ),
                          onStart: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => MovementLiveSessionScreen(
                                  activityKind: occ.activityKind ?? MovementActivityKind(
                                    id: occ.activityKindId,
                                    nameFa: occ.displayName,
                                    family: 'general',
                                    icon: 'directions_run',
                                    primaryMetric: 'duration',
                                    createdAt: DateTime.now(),
                                  ),
                                  occurrenceId: occ.id,
                                  targetSnapshot: occ.goalValue != null
                                      ? {
                                          'type': occ.goalType ?? 'duration',
                                          'value': occ.goalValue,
                                          'unit': occ.goalUnit ?? MovementStrings.unitMinute,
                                        }
                                      : null,
                                ),
                              ),
                            ).then((_) => _controller.loadData());
                          },
                          onManualLog: () {
                            QuickCompleteSheet.show(
                              context,
                              occurrence: occ,
                              onQuickComplete: (dur, metric, feel, note) async {
                                await _logService.quickCompleteOccurrence(
                                  occurrenceId: occ.id,
                                  activityKindId: occ.activityKindId,
                                  dateIso: occ.dateIso,
                                  durationSec: dur,
                                  feeling: feel,
                                  note: note,
                                );
                              },
                            ).then((_) => _controller.loadData());
                          },
                          onMove: () => _handleMove(occ),
                          onSkip: () => _handleSkip(occ),
                          onEditPlan: () => _handleEditPlan(occ),
                          onDelete: () => _handleDelete(occ),
                          onQuickComplete: () async {
                            final ok = await _controller.optimisticCompleteOccurrence(occ.id);
                            if (!ok && context.mounted) {
                              MovementUndoToast.show(
                                context,
                                message: MovementStrings.completeErrorToast,
                              );
                            }
                          },
                        );
                      },
                      childCount: selectedOccurrences.length,
                    ),
                  )
                else if (_controller.heroVariant == HeroCardVariant.restDay)
                  SliverToBoxAdapter(
                    child: RecoveryDayCard(
                      onAddLightMovement: () {
                        _navigateTo(
                          MovementRoutes.picker,
                          arguments: {'lightMode': true},
                        );
                      },
                    ),
                  )
                else
                  SliverToBoxAdapter(
                    child: EmptyStateBlock(
                      kind: MovementEmptyKind.emptyDay,
                      actionLabel: MovementStrings.centerAddActivity,
                      onAction: () => _openAddCommandSheet(),
                    ),
                  ),

                // ۷. کارت ورودی تمرین قدرتی (StrengthEntryCard)
                SliverToBoxAdapter(
                  child: StrengthEntryCard(
                    program: _controller.strengthProgram,
                    onBuildProgram: () => _navigateTo(MovementRoutes.strengthOnboarding),
                    onViewProgram: () => _navigateTo(MovementRoutes.strengthHub),
                    onResumeSession: () => _navigateTo(MovementRoutes.liveSession),
                    onStartNextCycle: () => _navigateTo(MovementRoutes.strengthOnboarding),
                  ),
                ),

                // ۸. کارت خلاصهٔ هفته (WeekSummaryCard)
                SliverToBoxAdapter(
                  child: WeekSummaryCard(
                    summary: _controller.weekSummary,
                    onTap: () {
                      _navigateTo(
                        MovementRoutes.progress,
                        arguments: {'weekStart': _controller.weekStartDate},
                      );
                    },
                  ),
                ),

                // ۹. فاصلهٔ امن پایین صفحه
                const SliverToBoxAdapter(
                  child: SizedBox(
                    height: MovementLayout.kDockHeight + RitmoSpacing.lg,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
