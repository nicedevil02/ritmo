import 'package:flutter/cupertino.dart';
import 'package:ritmo/core/modules/module_gate.dart';
import 'package:ritmo/core/settings/settings_registry.dart';
import 'package:ritmo/core/settings/settings_service.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_page_scaffold.dart';
import 'package:ritmo/core/widgets/ritmo_module_app_bar.dart';
import 'package:ritmo/features/settings/presentation/groups/modules_group_screen.dart';
import 'package:ritmo/features/settings/presentation/widgets/setting_field_builder.dart';
import 'package:ritmo/features/settings/presentation/widgets/settings_section.dart';

class CalendarGroupScreen extends StatelessWidget {
  const CalendarGroupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: SettingsService.instance.revision,
      builder: (context, _) {
        final isSleepEnabled = ModuleGate.instance.isEnabled('module_sleep_enabled');
        final isCycleEnabled = ModuleGate.instance.isEnabled('module_cycle_enabled');
        final hasCycleConsent = SettingsService.instance.get<bool>('cycle_consent');
        final isWorshipEnabled = ModuleGate.instance.isEnabled('module_religion_enabled');

        return RitmoPageScaffold(
          appBar: RitmoModuleAppBar(title: SettingsGroup.calendar.labelFa),
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 60),
            child: Column(
              children: [
                // ۱. نمای پیش‌فرض و نمایش تقویم
                const SettingsSection(
                  title: 'نمای پیش‌فرض و تقویم',
                  children: [
                    SettingField('calendar_default_scale'),
                    SettingField('calendar_show_hijri'),
                    SettingField('calendar_show_occasions'),
                  ],
                ),

                // ۲. چه چیزی در تقویم دیده شود
                SettingsSection(
                  title: 'چه چیزی در تقویم دیده شود',
                  children: [
                    const SettingField('calendar_show_tasks'),
                    const SettingField('calendar_show_events'),
                    const SettingField('calendar_show_commitments'),
                    const SettingField('calendar_show_appointments'),
                    if (!isSleepEnabled)
                      _buildDisabledModuleRow(
                        context,
                        'calendar_show_sleep_band',
                        'نیاز به روشن بودن ماژول خواب',
                      )
                    else
                      const SettingField('calendar_show_sleep_band'),
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
                      const SettingField('show_cycle_in_calendar'),
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
                      const SettingField('calendar_show_worship_obligatory'),
                      const SettingField('calendar_show_worship_mustahab'),
                      const SettingField('calendar_show_worship_qada'),
                    ],
                  ],
                ),

                // ۴. رفتار اجندا و گزارش‌ها
                const SettingsSection(
                  title: 'رفتار اجندا و گزارش‌ها',
                  children: [
                    SettingField('calendar_overdue_lookback_days'),
                    SettingField('calendar_compress_recurring'),
                    SettingField('calendar_morning_brief_enabled'),
                  ],
                ),
              ],
            ),
          ),
        );
      },
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
