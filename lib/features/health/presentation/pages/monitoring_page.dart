import 'package:flutter/cupertino.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_page_scaffold.dart';
import 'package:ritmo/core/widgets/ritmo_module_app_bar.dart';
import 'package:ritmo/features/health/presentation/widgets/blood_pressure_section.dart';
import 'package:ritmo/features/health/presentation/widgets/blood_sugar_section.dart';
import 'package:ritmo/features/health/presentation/widgets/vital_signs_section.dart';
import 'package:ritmo/l10n/app_localizations.dart';

class MonitoringPage extends StatefulWidget {
  const MonitoringPage({
    super.key,
    this.initialTab = 0,
  });
  final int initialTab;

  @override
  State<MonitoringPage> createState() => _MonitoringPageState();
}

class _MonitoringPageState extends State<MonitoringPage> {
  late int _activeTab;

  @override
  void initState() {
    super.initState();
    _activeTab = widget.initialTab;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context)!;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: RitmoPageScaffold(
        appBar: RitmoModuleAppBar.fromContext(
          context: context,
          title: l10n.healthMonitoring,
          showBackButton: true,
        ),
        body: Column(
          children: [
            // Standard Glass Segmented Control
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: RitmoGlassSegmentedControl<int>(
                selectedIndex: _activeTab,
                accentColor: colors.warning,
                onTabChanged: (index) {
                  setState(() {
                    _activeTab = index;
                  });
                },
                items: [
                  RitmoTabItem<int>(
                    title: l10n.bloodSugarTitle,
                    icon: CupertinoIcons.drop_fill,
                    value: 0,
                  ),
                  RitmoTabItem<int>(
                    title: l10n.bloodPressureTitle,
                    icon: CupertinoIcons.heart_fill,
                    value: 1,
                  ),
                  RitmoTabItem<int>(
                    title: l10n.vitalSignsTitle,
                    icon: CupertinoIcons.waveform_path,
                    value: 2,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Tabs Content
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: IndexedStack(
                  index: _activeTab,
                  children: const [
                    BloodSugarSection(),
                    BloodPressureSection(),
                    VitalSignsSection(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

