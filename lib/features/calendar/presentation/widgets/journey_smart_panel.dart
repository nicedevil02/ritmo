import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/agenda/analysis/agenda_conflict_detector.dart';
import 'package:ritmo/core/domain/agenda/analysis/agenda_gap_calculator.dart';
import 'package:ritmo/core/domain/agenda/models/day_agenda_snapshot.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/calendar/presentation/widgets/journey_free_gaps_section.dart';
import 'package:ritmo/features/calendar/presentation/widgets/journey_suggestions_section.dart';
import 'package:ritmo/features/calendar/presentation/widgets/journey_summary_section.dart';

class JourneySmartPanel extends StatefulWidget {
  const JourneySmartPanel({
    super.key,
    required this.snapshot,
    this.onSelectActivity,
    this.onSelectFreeGap,
    this.onSelectConflict,
    this.onDropItemOnGap,
  });

  final DayAgendaSnapshot snapshot;
  final ValueChanged<AgendaItem>? onSelectActivity;
  final ValueChanged<TimeGap>? onSelectFreeGap;
  final ValueChanged<AgendaConflict>? onSelectConflict;
  final void Function(AgendaItem item, TimeGap gap)? onDropItemOnGap;

  static Future<void> showAsBottomSheet(
    BuildContext context, {
    required DayAgendaSnapshot snapshot,
    ValueChanged<AgendaItem>? onSelectActivity,
    ValueChanged<TimeGap>? onSelectFreeGap,
    ValueChanged<AgendaConflict>? onSelectConflict,
    void Function(AgendaItem item, TimeGap gap)? onDropItemOnGap,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => JourneySmartPanel(
        snapshot: snapshot,
        onSelectActivity: onSelectActivity,
        onSelectFreeGap: onSelectFreeGap,
        onSelectConflict: onSelectConflict,
        onDropItemOnGap: onDropItemOnGap,
      ),
    );
  }

  @override
  State<JourneySmartPanel> createState() => _JourneySmartPanelState();
}

class _JourneySmartPanelState extends State<JourneySmartPanel>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: RitmoBreakpoints.sheetMaxHeight(context, factor: 0.75),
          ),
          decoration: BoxDecoration(
            color: colors.surfaceElevated,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(RitmoRadius.sheet),
            ),
            boxShadow: [
              BoxShadow(
                color: colors.overlay.withValues(alpha: 0.12),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            children: [
              const SizedBox(height: RitmoSpacing.md),
              // Top Drag Handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.borderSubtle,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: RitmoSpacing.md),

              // Segmented Tab Header Container
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: RitmoSpacing.xl,
                ),
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.all(RitmoSpacing.xs),
                  decoration: BoxDecoration(
                    color: colors.surfaceSubtle,
                    borderRadius: BorderRadius.circular(RitmoRadius.field),
                    border: Border.all(color: colors.borderSubtle),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      color: colors.surfaceElevated,
                      borderRadius: BorderRadius.circular(
                        RitmoRadius.iconButton,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: colors.overlay.withValues(alpha: 0.08),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    labelColor: colors.primary,
                    unselectedLabelColor: colors.textSecondary,
                    labelStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    tabs: [
                      const Tab(text: 'خلاصه'),
                      Tab(
                        text:
                            'پیشنهادها (${toPersianDigits(widget.snapshot.suggestions.length.toString())})',
                      ),
                      Tab(
                        text:
                            'زمان آزاد (${toPersianDigits(widget.snapshot.freeGaps.length.toString())})',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: RitmoSpacing.sm),

              // Tab Views
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    SingleChildScrollView(
                      padding: const EdgeInsets.all(RitmoSpacing.xl),
                      child: JourneySummarySection(
                        snapshot: widget.snapshot,
                        onSelectActivity: (item) {
                          Navigator.maybePop(context);
                          widget.onSelectActivity?.call(item);
                        },
                      ),
                    ),
                    SingleChildScrollView(
                      padding: const EdgeInsets.all(RitmoSpacing.xl),
                      child: JourneySuggestionsSection(
                        snapshot: widget.snapshot,
                        onSelectConflict: (conflict) {
                          Navigator.maybePop(context);
                          widget.onSelectConflict?.call(conflict);
                        },
                      ),
                    ),
                    SingleChildScrollView(
                      padding: const EdgeInsets.all(RitmoSpacing.xl),
                      child: JourneyFreeGapsSection(
                        snapshot: widget.snapshot,
                        onSelectFreeGap: (gap) {
                          Navigator.maybePop(context);
                          widget.onSelectFreeGap?.call(gap);
                        },
                        onDropItemOnGap: (item, gap) {
                          Navigator.maybePop(context);
                          widget.onDropItemOnGap?.call(item, gap);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
