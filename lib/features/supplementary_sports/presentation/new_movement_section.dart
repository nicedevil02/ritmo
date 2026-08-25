// lib/features/supplementary_sports/presentation/new_movement_section.dart

import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/supplementary_sports/movement/presentation/planner/unified_week_planner_screen.dart';

/// تب‌های بخش جدید حرکت. تب هفته همان تختهٔ ریتم است.
class NewMovementSection extends StatefulWidget {
  const NewMovementSection({super.key, this.sportsTab});

  /// محتوای تب ورزش‌ها — از داشبورد پاس داده می‌شود تا import دوری نباشد.
  final Widget? sportsTab;

  @override
  State<NewMovementSection> createState() => _NewMovementSectionState();
}

class _NewMovementSectionState extends State<NewMovementSection>
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
    final accent = context.modules.sports;

    return Column(
      children: [
        Material(
          color: colors.surface,
          child: TabBar(
            controller: _tabController,
            labelColor: accent,
            unselectedLabelColor: colors.textSecondary,
            indicatorColor: accent,
            indicatorWeight: 2.5,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
            unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
            tabs: const [
              Tab(text: 'هفته'),
              Tab(text: 'ورزش‌ها'),
              Tab(text: 'تب ۳'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              const UnifiedWeekPlannerView(),
              widget.sportsTab ??
                  const Center(
                    child: Text('ورزش‌ها', style: TextStyle(fontSize: 14)),
                  ),
              const Center(
                child: Text('محتوای تب ۳', style: TextStyle(fontSize: 14)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
