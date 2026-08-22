import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/movement/application/movement_log_service.dart';
import 'package:ritmo/features/movement/application/movement_occurrence_service.dart';
import 'package:ritmo/features/movement/domain/models/movement_occurrence.dart';
import 'package:ritmo/features/movement/presentation/activity_picker/sheets/retro_log_form_sheet.dart';
import 'package:ritmo/features/movement/presentation/center/movement_center_controller.dart';
import 'package:ritmo/features/movement/presentation/center/sheets/move_session_sheet.dart';
import 'package:ritmo/features/movement/presentation/center/sheets/plan_b_sheet.dart';
import 'package:ritmo/features/movement/presentation/center/sheets/skip_session_sheet.dart';
import 'package:ritmo/features/movement/presentation/center/sheets/week_reshuffle_sheet.dart';
import 'package:ritmo/features/movement/presentation/center/states/movement_has_session_view.dart';
import 'package:ritmo/features/movement/presentation/center/states/movement_no_plan_view.dart';
import 'package:ritmo/features/movement/presentation/center/states/movement_rest_day_view.dart';
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
        return await _logService.quickCompleteOccurrence(
          occurrenceId: occ.id,
          activityKindId: occ.activityKindId,
          dateIso: dateIso,
          durationSec: durationSec,
          intensityTag: feeling ?? 'medium',
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

    final changes = occs.map((o) => WeekReshuffleChangeItem(
      occurrence: o,
      originalDateIso: o.dateIso,
      proposedDateIso: o.dateIso,
      originalTime: o.startTime ?? '18:00',
      proposedTime: o.startTime ?? '18:00',
      reason: 'تنظیم بر اساس ریتم بدنی',
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

          switch (ready.view) {
            case MovementCenterView.hasSession:
              return MovementHasSessionView(
                occurrence: ready.todayOccurrence!,
                weekStats: ready.weekStats,
                readiness: ready.readiness,
                tier: ready.tier,
                railDays: ready.railDays,
                onStartSession: () => _navigateToSession(
                  ready.todayOccurrence?.id,
                  ready.todayOccurrence?.activityKindId,
                ),
                onQuickLog: () => _handleQuickLog(
                  ready.todayOccurrence!.id,
                  ready.todayOccurrence!.activityKindId,
                ),
                onSelectDay: (d) => _controller.setSelectedDate(d),
                onPlanB: () => _handlePlanB(ready.todayOccurrence!),
                onMoveSession: () => _handleMoveSession(ready.todayOccurrence!),
                onSkipSession: () => _handleSkipSession(ready.todayOccurrence!),
                onRetroLog: () => _handleRetroLog(ready.todayOccurrence!),
                onReviewWeek: _handleReshuffleWeek,
              );

            case MovementCenterView.restDay:
              return MovementRestDayView(
                railDays: ready.railDays,
                onConfirmRestDay: () async {
                  if (ready.todayOccurrence != null) {
                    await widget.occurrenceService?.updateOccurrenceStatus(
                      ready.todayOccurrence!.id,
                      MovementOccurrenceStatus.restDay,
                    );
                    await _controller.refresh();
                  }
                },
                onOpenPicker: () => Navigator.of(context).pushNamed(MovementRoutes.picker),
                onSelectDay: (d) => _controller.setSelectedDate(d),
              );

            case MovementCenterView.noPlan:
              return MovementNoPlanView(
                tier: ready.tier,
                railDays: ready.railDays,
                absenceStatus: ready.absenceStatus,
                onOpenPicker: () => Navigator.of(context).pushNamed(MovementRoutes.picker),
                onOpenPlanEditor: () => Navigator.of(context).pushNamed(MovementRoutes.planEditor),
                onSelectDay: (d) => _controller.setSelectedDate(d),
              );
          }
        },
      ),
    );
  }
}
