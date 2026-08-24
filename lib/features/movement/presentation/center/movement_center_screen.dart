import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/movement/application/movement_log_service.dart';
import 'package:ritmo/features/movement/application/movement_occurrence_service.dart';
import 'package:ritmo/features/movement/application/movement_readiness_service.dart';
import 'package:ritmo/features/movement/domain/models/movement_occurrence.dart';
import 'package:ritmo/features/movement/presentation/activity_picker/sheets/retro_log_form_sheet.dart';
import 'package:ritmo/features/movement/presentation/center/movement_center_controller.dart';
import 'package:ritmo/features/movement/presentation/center/sheets/move_session_sheet.dart';
import 'package:ritmo/features/movement/presentation/center/sheets/plan_b_sheet.dart';
import 'package:ritmo/features/movement/presentation/center/sheets/skip_session_sheet.dart';
import 'package:ritmo/features/movement/presentation/center/sheets/week_reshuffle_sheet.dart';
import 'package:ritmo/features/movement/presentation/center/widgets/hero_session_card.dart';
import 'package:ritmo/features/movement/presentation/center/widgets/live_session_banner.dart';
import 'package:ritmo/features/movement/presentation/center/widgets/session_card.dart';
import 'package:ritmo/features/movement/presentation/center/widgets/strength_entry_card.dart';
import 'package:ritmo/features/movement/presentation/center/widgets/week_rail.dart';
import 'package:ritmo/features/movement/presentation/center/widgets/week_summary_card.dart';
import 'package:ritmo/features/movement/presentation/common/movement_strings.dart';
import 'package:ritmo/features/movement/presentation/common/undo_toast.dart';
import 'package:ritmo/features/movement/presentation/movement_routes.dart';
import 'package:ritmo/features/movement/presentation/session/sheets/quick_log_sheet.dart';

/// صفحهٔ اصلی و مرکز کنترل ماژول حرکت (P-08 — زیر ۲۰۰ خط)
class MovementCenterScreen extends StatefulWidget {
  const MovementCenterScreen({
    super.key,
    this.controller,
    this.occurrenceService,
    this.logService,
  });

  final MovementCenterController? controller;
  final MovementOccurrenceService? occurrenceService;
  final MovementLogService? logService;

  @override
  State<MovementCenterScreen> createState() => _MovementCenterScreenState();
}

class _MovementCenterScreenState extends State<MovementCenterScreen> {
  late final MovementCenterController _controller;
  late final MovementLogService _logService;

  @override
  void initState() {
    super.initState();
    final occService = widget.occurrenceService ?? MovementOccurrenceService();
    _controller = widget.controller ??
        MovementCenterController(occurrenceService: occService);
    if (widget.controller == null) {
      _controller.loadData();
    }
    _logService = widget.logService ?? MovementLogService();
  }

  Future<void> _handleQuickLog(String occurrenceId, String activityKindId) async {
    final intensity = await QuickLogSheet.show(context);
    if (intensity == null || !mounted) return;

    final dateIso = _controller.selectedDate.toIso8601String().split('T').first;
    final log = await _logService.quickCompleteOccurrence(
      occurrenceId: occurrenceId,
      activityKindId: activityKindId,
      dateIso: dateIso,
      durationSec: 1800,
      intensityTag: intensity,
    );

    if (!mounted) return;
    MovementUndoToast.show(
      context,
      message: 'تمرین با موفقیت ثبت شد',
      onUndo: () async {
        await _logService.undoQuickComplete(
          logId: log.id,
          occurrenceId: occurrenceId,
        );
        await _controller.refresh();
      },
    );
    await _controller.refresh();
  }

  Future<void> _handlePlanB(MovementOccurrence occ) async {
    final applied = await PlanBSheet.show(
      context,
      occurrence: occ,
      onApplyPlanB: (option, newGoalValue) async {
        if (option == PlanBOption.move) {
          await _handleMoveSession(occ);
        } else if (option == PlanBOption.recovery) {
          await (widget.occurrenceService ?? MovementOccurrenceService())
              .updateOccurrenceStatus(occ.id, MovementOccurrenceStatus.restDay);
        } else {
          final updated = occ.copyWith(goalValue: newGoalValue);
          await (widget.occurrenceService ?? MovementOccurrenceService())
              .saveOccurrence(updated);
        }
      },
    );
    if (applied == true && mounted) {
      await _controller.refresh();
    }
  }

  Future<void> _handleMoveSession(MovementOccurrence occ) async {
    final moved = await MoveSessionSheet.show(
      context,
      occurrence: occ,
      onMoveConfirm: (newDateIso, newTime, scope) async {
        await (widget.occurrenceService ?? MovementOccurrenceService())
            .moveOccurrence(occ.id, newDateIso);
      },
    );
    if (moved == true && mounted) {
      await _controller.refresh();
    }
  }

  Future<void> _handleSkipSession(MovementOccurrence occ) async {
    final choice = await SkipSessionSheet.show(context);
    if (choice == null || !mounted) return;

    switch (choice) {
      case SkipActionChoice.skipTodayOnly:
        await (widget.occurrenceService ?? MovementOccurrenceService())
            .updateOccurrenceStatus(occ.id, MovementOccurrenceStatus.skipped);
        await _controller.refresh();
        break;
      case SkipActionChoice.moveToOtherDay:
        await _handleMoveSession(occ);
        break;
      case SkipActionChoice.shortVersion:
        await _handlePlanB(occ);
        break;
      case SkipActionChoice.editTemplate:
        await Navigator.of(context).pushNamed(MovementRoutes.planEditor);
        break;
    }
  }

  Future<void> _handleRetroLog(MovementOccurrence occ) async {
    final kind = occ.activityKind ?? await (widget.occurrenceService ?? MovementOccurrenceService()).getActivityKind(occ.activityKindId);
    if (kind == null || !mounted) return;

    final log = await RetroLogFormSheet.show(
      context,
      activityKind: kind,
      matchingOccurrenceId: occ.id,
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
          activityKindId: occ.activityKindId,
          dateIso: dateIso,
          startTime: startTime,
          durationSec: durationSec,
          metrics: metrics,
          feeling: feeling,
          note: note,
          matchedOccurrenceId: occ.id,
        );
      },
    );
    if (log != null && mounted) {
      await _controller.refresh();
    }
  }

  Future<void> _handleReshuffleWeek() async {
    final startIso = _controller.selectedDate.toIso8601String().split('T').first;
    final endIso = _controller.selectedDate.add(const Duration(days: 7)).toIso8601String().split('T').first;

    final occs = await (widget.occurrenceService ?? MovementOccurrenceService())
        .getOccurrencesForRange(startIso, endIso);

    final plannedOccs = occs.where((o) => !o.isCompleted && !o.isRestDay).toList();
    if (plannedOccs.isEmpty) {
      if (mounted) {
        MovementUndoToast.show(context, message: 'تمام جلسات هفته تکمیل یا تنظیم شده‌اند');
      }
      return;
    }

    final changes = plannedOccs.map((o) => WeekReshuffleChangeItem(
      occurrence: o,
      originalDateIso: o.dateIso,
      proposedDateIso: o.dateIso,
      originalTime: o.startTime ?? '18:00',
      proposedTime: o.startTime ?? '18:00',
      reason: 'تنظیم بر اساس ریتم بدنی و ریکاوری',
    )).toList();

    if (changes.isNotEmpty && mounted) {
      await WeekReshuffleSheet.show(
        context,
        changes: changes,
        onApplyChanges: (selected) async {
          for (final c in selected) {
            await (widget.occurrenceService ?? MovementOccurrenceService())
                .moveOccurrence(c.occurrence.id, c.proposedDateIso);
          }
          await _controller.refresh();
        },
      );
    }
  }

  void _navigateToSession(String? occurrenceId, String? kindId) {
    Navigator.of(context).pushNamed(
      MovementRoutes.liveSession,
      arguments: {
        'occurrenceId': occurrenceId,
        'activityKindId': kindId ?? 'kind_walking',
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(
          'حرکت',
          style: RitmoTextStyles.cardTitle(colors.textPrimary),
        ),
        backgroundColor: colors.background,
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: MovementStrings.settingsTitle,
            onPressed: () => Navigator.of(context).pushNamed(MovementRoutes.settings),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final state = _controller.state;

          if (state is MovementCenterLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is MovementCenterError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'خطا در بارگذاری اطلاعات: ${state.message}',
                    style: RitmoTextStyles.body(colors.error),
                  ),
                  const SizedBox(height: RitmoSpacing.md),
                  ElevatedButton(
                    onPressed: _controller.refresh,
                    child: const Text('تلاش مجدد'),
                  ),
                ],
              ),
            );
          }

          final ready = state as MovementCenterReady;
          final primaryOcc = ready.todayOccurrence;
          final dayOccs = ready.dayOccurrences;

          // نگاشت وضعیت ورودی به وریانت کارت هیرو
          final HeroCardVariant heroVariant;
          switch (_controller.entryState) {
            case MovementCenterEntryState.brandNewUser:
            case MovementCenterEntryState.firstLaunchAfterCutover:
              heroVariant = HeroCardVariant.emptyPlan;
              break;
            case MovementCenterEntryState.recoveryDay:
              heroVariant = HeroCardVariant.restDay;
              break;
            case MovementCenterEntryState.todaySessionCompleted:
              heroVariant = HeroCardVariant.allDone;
              break;
            case MovementCenterEntryState.pastPlannedTime:
              heroVariant = HeroCardVariant.late;
              break;
            case MovementCenterEntryState.multiSessionsToday:
              heroVariant = HeroCardVariant.multiToday;
              break;
            case MovementCenterEntryState.hasPlanTodaySession:
            case MovementCenterEntryState.inProgressLiveSession:
              heroVariant = HeroCardVariant.ready;
              break;
          }

          final secondaryOccurrences =
              dayOccs.where((o) => primaryOcc == null || o.id != primaryOcc.id).toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // بنر اعلام بعد از مهاجرت/کاتاُوور (State 8)
              if (_controller.isFirstLaunchAfterCutover)
                Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: RitmoSpacing.lg,
                    vertical: RitmoSpacing.xs,
                  ),
                  padding: const EdgeInsets.all(RitmoSpacing.md),
                  decoration: BoxDecoration(
                    color: colors.surfaceElevated,
                    borderRadius: BorderRadius.circular(RitmoRadius.card),
                    border: Border.all(color: colors.primary.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded, color: colors.primary),
                      const SizedBox(width: RitmoSpacing.sm),
                      Expanded(
                        child: Text(
                          MovementStrings.cutoverCalloutDesc,
                          style: RitmoTextStyles.body(colors.textPrimary),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: _controller.dismissCutoverCallout,
                      ),
                    ],
                  ),
                ),

              // ریل هفتگی
              WeekRail(
                days: ready.railDays,
                onDaySelected: _controller.selectDay,
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: RitmoSpacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // بنر تمرین زنده در صورت وجود
                      if (ready.activeLiveSession != null) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: RitmoSpacing.lg),
                          child: LiveSessionBanner(
                            session: ready.activeLiveSession!,
                            onResume: () => _navigateToSession(
                              ready.activeLiveSession?.occurrenceId,
                              ready.activeLiveSession?.activityKindId,
                            ),
                            onFinishAndSave: () async {
                              if (ready.activeLiveSession != null) {
                                await _controller.sessionService.finishSession(ready.activeLiveSession!.id);
                                await _controller.refresh();
                              }
                            },
                            onDiscard: () async {
                              if (ready.activeLiveSession != null) {
                                await _controller.sessionService.abandonSession(ready.activeLiveSession!.id);
                                await _controller.refresh();
                              }
                            },
                          ),
                        ),
                        const SizedBox(height: RitmoSpacing.sm),
                      ],

                      // کارت شاخص هیرو
                      HeroSessionCard(
                        variant: heroVariant,
                        primaryOccurrence: primaryOcc,
                        totalTodaySessions: dayOccs.isEmpty ? 1 : dayOccs.length,
                        currentSessionIndex: 1,
                        onPrimaryAction: () {
                          if (primaryOcc != null) {
                            _navigateToSession(primaryOcc.id, primaryOcc.activityKindId);
                          } else {
                            Navigator.of(context).pushNamed(MovementRoutes.picker);
                          }
                        },
                        onSecondaryAction: () {
                          if (heroVariant == HeroCardVariant.restDay) {
                            Navigator.of(context).pushNamed(MovementRoutes.picker);
                          } else {
                            Navigator.of(context).pushNamed(MovementRoutes.planEditor);
                          }
                        },
                        onMoveAction: primaryOcc != null ? () => _handleMoveSession(primaryOcc) : null,
                        onShortVersionAction: primaryOcc != null ? () => _handlePlanB(primaryOcc) : null,
                        onSkipAction: primaryOcc != null ? () => _handleSkipSession(primaryOcc) : null,
                        onLogManualAction: primaryOcc != null ? () => _handleRetroLog(primaryOcc) : null,
                        onReviewWeekAction: _handleReshuffleWeek,
                      ),

                      // سایر جلسات روز در صورت وجود بیش از ۱ جلسه
                      if (secondaryOccurrences.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: RitmoSpacing.xl,
                            vertical: RitmoSpacing.xs,
                          ),
                          child: Text(
                            'سایر جلسات امروز',
                            style: RitmoTextStyles.cardTitle(colors.textPrimary),
                          ),
                        ),
                        for (final secOcc in secondaryOccurrences) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: RitmoSpacing.lg,
                              vertical: RitmoSpacing.xs,
                            ),
                            child: SessionCard(
                              occurrence: secOcc,
                              onTap: () => _navigateToSession(secOcc.id, secOcc.activityKindId),
                              onStart: () => _navigateToSession(secOcc.id, secOcc.activityKindId),
                              onQuickComplete: () => _handleQuickLog(secOcc.id, secOcc.activityKindId),
                              onMove: () => _handleMoveSession(secOcc),
                              onShortVersion: () => _handlePlanB(secOcc),
                              onSkip: () => _handleSkipSession(secOcc),
                              onManualLog: () => _handleRetroLog(secOcc),
                            ),
                          ),
                        ],
                      ],

                      // کارت ورودی برنامه تمرین قدرتی (Tier 3)
                      StrengthEntryCard(
                        program: _controller.strengthProgram,
                        onBuildProgram: () => Navigator.of(context).pushNamed(MovementRoutes.strengthOnboarding),
                        onViewProgram: () => Navigator.of(context).pushNamed(MovementRoutes.strengthHub),
                        onResumeSession: () => _navigateToSession(null, 'kind_strength'),
                        onStartNextCycle: () => Navigator.of(context).pushNamed(MovementRoutes.strengthPreview),
                      ),

                      // کارت خلاصه ۳ متریکی هفته
                      WeekSummaryCard(
                        summary: _controller.summary,
                        onTap: () => Navigator.of(context).pushNamed(MovementRoutes.summary),
                      ),

                      // کارت پیشنهاد آمادگی بدنی
                      if (ready.readiness is ReadinessReady) ...[
                        Container(
                          margin: const EdgeInsets.symmetric(
                            horizontal: RitmoSpacing.lg,
                            vertical: RitmoSpacing.sm,
                          ),
                          padding: const EdgeInsets.all(RitmoSpacing.md),
                          decoration: BoxDecoration(
                            color: colors.surfaceElevated,
                            borderRadius: BorderRadius.circular(RitmoRadius.card),
                            border: Border.all(color: colors.borderSubtle),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline_rounded, size: 20, color: colors.textSecondary),
                              const SizedBox(width: RitmoSpacing.sm),
                              Expanded(
                                child: Text(
                                  (ready.readiness as ReadinessReady).suggestionFa,
                                  style: RitmoTextStyles.body(colors.textSecondary),
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
            ],
          );
        },
      ),
    );
  }
}
