import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/settings/settings_service.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_page_scaffold.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_segmented_control.dart';
import 'package:ritmo/core/widgets/ritmo_module_app_bar.dart';
import 'package:ritmo/features/settings/presentation/widgets/settings_section.dart';
import 'package:ritmo/features/settings/presentation/widgets/settings_tile.dart';

class CalendarGroupScreen extends StatefulWidget {
  const CalendarGroupScreen({super.key});

  @override
  State<CalendarGroupScreen> createState() => _CalendarGroupScreenState();
}

class _CalendarGroupScreenState extends State<CalendarGroupScreen> {
  late String _defaultScale;
  late bool _showTasks;
  late bool _showOccasions;
  late bool _showHijri;
  late bool _morningBriefEnabled;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() {
    _defaultScale = SettingsService.instance.get<String>('calendar_default_scale');
    if (_defaultScale.isEmpty) _defaultScale = 'agenda';
    _showTasks = SettingsService.instance.get<bool>('calendar_show_tasks');
    _showOccasions = SettingsService.instance.get<bool>('calendar_show_occasions');
    _showHijri = SettingsService.instance.get<bool>('calendar_show_hijri');
    _morningBriefEnabled = SettingsService.instance.get<bool>('calendar_morning_brief_enabled');
  }

  Future<void> _update<T>(String key, T val, VoidCallback updateState) async {
    updateState();
    await SettingsService.instance.set(key, val as Object);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return RitmoPageScaffold(
      appBar: const RitmoModuleAppBar(title: 'تنظیمات تقویم و برنامه‌ریزی'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 60),
        child: Column(
          children: [
            SettingsSection(
              title: 'نمای پیش‌فرض تقویم',
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'نمای اولیه هنگام باز کردن تقویم',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary,
                          ),
                      ),
                      const SizedBox(height: 12),
                      RitmoSegmentedControl<String>(
                        selected: _defaultScale,
                        segments: const {
                          'agenda': 'برنامه',
                          'day': 'روز',
                          'week': 'هفته',
                          'month': 'ماه',
                          'year': 'سال',
                        },
                        onSelected: (val) {
                          _update('calendar_default_scale', val, () {
                            setState(() => _defaultScale = val);
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SettingsSection(
              title: 'نمایش محتوا در تقویم',
              children: [
                SettingsTile(
                  title: 'نمایش کارها و گام‌های اهداف',
                  subtitle: 'ادغام کارهای روزانه و گام‌های اهداف فعال در خط زمان و نمای برنامه',
                  leading: Icon(CupertinoIcons.checkmark_square, color: colors.primary),
                  trailing: CupertinoSwitch(
                    value: _showTasks,
                    onChanged: (val) {
                      _update('calendar_show_tasks', val, () {
                        setState(() => _showTasks = val);
                      });
                    },
                  ),
                ),
                SettingsTile(
                  title: 'نمایش مناسبت‌ها و تعطیلات',
                  subtitle: 'نمایش مناسبت‌های رسمی شمسی/قمری و روزهای تعطیل در تقویم',
                  leading: Icon(CupertinoIcons.calendar, color: colors.primary),
                  trailing: CupertinoSwitch(
                    value: _showOccasions,
                    onChanged: (val) {
                      _update('calendar_show_occasions', val, () {
                        setState(() => _showOccasions = val);
                      });
                    },
                  ),
                ),
                SettingsTile(
                  title: 'نمایش تاریخ هجری قمری',
                  subtitle: 'نمایش تاریخ قمری در کنار تاریخ شمسی در هدر روزها',
                  leading: Icon(CupertinoIcons.moon_stars, color: colors.primary),
                  trailing: CupertinoSwitch(
                    value: _showHijri,
                    onChanged: (val) {
                      _update('calendar_show_hijri', val, () {
                        setState(() => _showHijri = val);
                      });
                    },
                  ),
                ),
              ],
            ),
            SettingsSection(
              title: 'هوشمندی و گزارش‌ها',
              children: [
                SettingsTile(
                  title: 'گزارش صبحگاهی روز',
                  subtitle: 'تولید خودکار خلاصه وضعیت و توصیه‌های روزانه هنگام شروع روز',
                  leading: Icon(CupertinoIcons.sun_max, color: colors.primary),
                  trailing: CupertinoSwitch(
                    value: _morningBriefEnabled,
                    onChanged: (val) {
                      _update('calendar_morning_brief_enabled', val, () {
                        setState(() => _morningBriefEnabled = val);
                      });
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
