import 'package:flutter/cupertino.dart';
import 'package:ritmo/core/modules/module_gate.dart';
import 'package:ritmo/core/settings/settings_registry.dart';
import 'package:ritmo/core/settings/settings_service.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_page_scaffold.dart';
import 'package:ritmo/core/widgets/ritmo_module_app_bar.dart';
import 'package:ritmo/features/settings/presentation/groups/modules_group_screen.dart';
import 'package:ritmo/features/settings/presentation/widgets/setting_field_builder.dart';
import 'package:ritmo/features/settings/presentation/widgets/settings_ready_gate.dart';
import 'package:ritmo/features/settings/presentation/widgets/settings_section.dart';

class CalendarGroupScreen extends StatelessWidget {
  final String? highlightKey;

  const CalendarGroupScreen({
    super.key,
    this.highlightKey,
  });

  @override
  Widget build(BuildContext context) {
    return SettingsReadyGate(
      child: AnimatedBuilder(
        animation: SettingsService.instance.revision,
        builder: (context, _) {
          final isSleepEnabled = ModuleGate.instance.isEnabled('module_sleep_enabled');
          final isCycleEnabled = ModuleGate.instance.isEnabled('module_cycle_enabled');
          final hasCycleConsent = SettingsService.instance.get<bool>('cycle_consent');
          final isWorshipEnabled = ModuleGate.instance.isEnabled('module_religion_enabled');

          return RitmoPageScaffold(
            padding: EdgeInsets.zero,
            appBar: RitmoModuleAppBar.fromContext(
              context: context,
              title: SettingsGroup.calendar.labelFa,
            ),
            body: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 60),
              child: Column(
                children: [
                  // ۱. نمای پیش‌فرض و نمایش تقویم
                  SettingsSection.fromKeys(
                    title: 'نمای پیش‌فرض و تقویم',
                    keys: const [
                      'calendar_default_scale',
                      'calendar_show_hijri',
                      'calendar_show_occasions',
                    ],
                    highlightKey: highlightKey,
                  ),

                  // ۲. چه چیزی در تقویم دیده شود
                  SettingsSection(
                    title: 'چه چیزی در تقویم دیده شود',
                    children: [
                      SettingField('calendar_show_tasks', highlight: highlightKey == 'calendar_show_tasks'),
                      SettingField('calendar_show_events', highlight: highlightKey == 'calendar_show_events'),
                      SettingField('calendar_show_commitments', highlight: highlightKey == 'calendar_show_commitments'),
                      SettingField('calendar_show_appointments', highlight: highlightKey == 'calendar_show_appointments'),
                      if (!isSleepEnabled)
                        _buildDisabledModuleRow(
                          context,
                          'calendar_show_sleep_band',
                          'نیاز به روشن بودن ماژول خواب',
                        )
                      else
                        SettingField('calendar_show_sleep_band', highlight: highlightKey == 'calendar_show_sleep_band'),
                      if (!isCycleEnabled)
                        _buildDisabledModuleRow(
                          context,
                          'show_cycle_in_calendar',
                          'نیاز به روشن بودن ماژول چرخه',
                        )
                      else if (!hasCycleConsent)
                        _buildDisabledModuleRow(
                          context,
                          'show_cycle_in_calendar',
                          'نیازمند فعال‌سازی رضایت صریح در بخش امنیت و حریم خصوصی',
                        )
                      else
                        SettingField('show_cycle_in_calendar', highlight: highlightKey == 'show_cycle_in_calendar'),
                    ],
                  ),

                  // ۳. عبادت در تقویم
                  SettingsSection(
                    title: 'عبادت در تقویم',
                    children: [
                      if (!isWorshipEnabled) ...[
                        _buildDisabledModuleRow(
                          context,
                          'calendar_show_worship_obligatory',
                          'نیاز به روشن بودن ماژول عبادت',
                        ),
                        _buildDisabledModuleRow(
                          context,
                          'calendar_show_worship_mustahab',
                          'نیاز به روشن بودن ماژول عبادت',
                        ),
                        _buildDisabledModuleRow(
                          context,
                          'calendar_show_worship_qada',
                          'نیاز به روشن بودن ماژول عبادت',
                        ),
                      ] else ...[
                        SettingField('calendar_show_worship_obligatory', highlight: highlightKey == 'calendar_show_worship_obligatory'),
                        SettingField('calendar_show_worship_mustahab', highlight: highlightKey == 'calendar_show_worship_mustahab'),
                        SettingField('calendar_show_worship_qada', highlight: highlightKey == 'calendar_show_worship_qada'),
                      ],
                    ],
                  ),

                  // ۴. رفتار اجندا و گزارش‌ها
                  SettingsSection.fromKeys(
                    title: 'رفتار اجندا و گزارش‌ها',
                    keys: const [
                      'calendar_overdue_lookback_days',
                      'calendar_compress_recurring',
                      'calendar_morning_brief_enabled',
                    ],
                    highlightKey: highlightKey,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDisabledModuleRow(
    BuildContext context,
    String key,
    String reason,
  ) {
    final colors = context.colors;
    final desc = SettingsRegistry.find(key);
    if (desc == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  desc.labelFa,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: colors.textSecondary.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  reason,
                  style: TextStyle(
                    fontSize: 12,
                    color: colors.medicalRed.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            color: colors.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
            onPressed: () {
              Navigator.push(
                context,
                CupertinoPageRoute(builder: (_) => const ModulesGroupScreen()),
              );
            },
            child: Text(
              'مدیریت ماژول‌ها',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: colors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
