import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/movement/application/movement_log_service.dart';
import 'package:ritmo/features/movement/application/movement_occurrence_service.dart';
import 'package:ritmo/features/movement/domain/models/movement_occurrence.dart';
import 'package:ritmo/features/movement/presentation/center/movement_center_controller.dart';
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
    await _logService.quickCompleteOccurrence(
      occurrenceId: occurrenceId,
      activityKindId: activityKindId,
      dateIso: dateIso,
      durationSec: 1800,
    );

    if (!mounted) return;
    MovementUndoToast.show(
      context,
      message: 'تمرین با موفقیت ثبت شد',
      onUndo: () async {
        await _controller.refresh();
      },
    );
    await _controller.refresh();
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
