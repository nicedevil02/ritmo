// C-43, C-44: CycleSegmentedTabs (Apple Liquid Glass Segmented Control)
import 'package:flutter/cupertino.dart';
import 'package:ritmo/core/modules/module_gate.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';

class CycleSegmentedTabs extends StatelessWidget {
  const CycleSegmentedTabs({
    super.key,
    required this.activeTab,
    required this.onTabChanged,
    required this.settings,
    required this.activeThemeColor,
  });

  final int activeTab;
  final ValueChanged<int> onTabChanged;
  final Map<String, String> settings;
  final Color activeThemeColor;

  @override
  Widget build(BuildContext context) {
    final showWorship = ModuleGate.instance.isEnabledFrom(
      settings,
      'module_religion_enabled',
    );

    final tabs = <RitmoTabItem<int>>[
      const RitmoTabItem(
        title: 'داشبورد',
        icon: CupertinoIcons.square_grid_2x2_fill,
        value: 0,
      ),
      const RitmoTabItem(
        title: 'داده‌ها',
        icon: CupertinoIcons.chart_bar_alt_fill,
        value: 1,
      ),
      const RitmoTabItem(
        title: 'همبستگی‌ها',
        icon: CupertinoIcons.sparkles,
        value: 2,
      ),
      if (showWorship)
        const RitmoTabItem(
          title: 'روزه قضا',
          icon: CupertinoIcons.bookmark_fill,
          value: 3,
        ),
    ];

    return RitmoGlassSegmentedControl<int>(
      items: tabs,
      selectedIndex: activeTab.clamp(0, tabs.length - 1),
      onTabChanged: onTabChanged,
      accentColor: activeThemeColor,
      height: 46.0,
    );
  }
}
