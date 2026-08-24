import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/settings/settings_service.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/widgets/ritmo_module_app_bar.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_page_scaffold.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_segmented_control.dart';
import 'package:ritmo/features/profile/presentation/ai_connection_screen.dart';
import 'package:ritmo/features/profile/presentation/ai_memory_management_screen.dart';
import 'package:ritmo/features/profile/presentation/widgets/psych_layer_settings_sheet.dart';
import 'package:ritmo/features/settings/presentation/widgets/ai_write_history_sheet.dart';
import 'package:ritmo/features/settings/presentation/widgets/privacy_summary_card.dart';
import 'package:ritmo/features/settings/presentation/widgets/settings_section.dart';
import 'package:ritmo/features/settings/presentation/widgets/settings_tile.dart';

class AssistantPrivacyGroupScreen extends StatefulWidget {
  final String? highlightKey;

  const AssistantPrivacyGroupScreen({
    super.key,
    this.highlightKey,
  });

  @override
  State<AssistantPrivacyGroupScreen> createState() => _AssistantPrivacyGroupScreenState();
}

class _AssistantPrivacyGroupScreenState extends State<AssistantPrivacyGroupScreen> {
  bool _cloudConsent = true;
  bool _assistantCanModify = true;
  String _gentleness = 'medium';
  int _dailyCapacity = 480;
  String _wakeTime = '06:30';
  String _sleepTime = '23:00';
  bool _showAdvanced = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() {
    setState(() {
      _cloudConsent = SettingsService.instance.get<bool>('assistant_cloud_consent');
      _assistantCanModify = SettingsService.instance.get<bool>('assistant_can_modify_settings');
      _gentleness = SettingsService.instance.get<String>('gentleness_level');
      _dailyCapacity = SettingsService.instance.get<int>('daily_capacity_minutes');
      _wakeTime = SettingsService.instance.get<String>('sleep_target_wake');
      _sleepTime = SettingsService.instance.get<String>('sleep_target_bedtime');
      _showAdvanced = SettingsService.instance.get<bool>('show_advanced_settings');
    });
  }

  Future<void> _update(String key, Object val) async {
    await SettingsService.instance.set(key, val);
    _loadSettings();
  }

  Future<void> _pickTime(String key, String currentVal, String title) async {
    final parts = currentVal.split(':');
    final initialH = int.tryParse(parts[0]) ?? 0;
    final initialM = int.tryParse(parts[1]) ?? 0;
    TimeOfDay selectedTime = TimeOfDay(hour: initialH, minute: initialM);

    await showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) {
        return Container(
          height: 260,
          color: context.colors.card,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      child: Text('انصراف', style: TextStyle(color: context.colors.textSecondary)),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                    Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: context.colors.textPrimary)),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      child: Text('تأیید', style: TextStyle(color: context.colors.primary, fontWeight: FontWeight.bold)),
                      onPressed: () async {
                        final formatted = '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}';
                        await _update(key, formatted);
                        if (key == 'sleep_target_wake' || key == 'sleep_target_bedtime') {
                          final curWake = key == 'sleep_target_wake' ? formatted : _wakeTime;
                          final curBed = key == 'sleep_target_bedtime' ? formatted : _sleepTime;
                          final btParts = curBed.split(':');
                          final wtParts = curWake.split(':');
                          final btMin = (int.tryParse(btParts[0]) ?? 23) * 60 + (int.tryParse(btParts.length > 1 ? btParts[1] : '0') ?? 0);
                          final wtMin = (int.tryParse(wtParts[0]) ?? 7) * 60 + (int.tryParse(wtParts.length > 1 ? wtParts[1] : '0') ?? 0);
                          var diff = wtMin - btMin;
                          if (diff <= 0) diff += 1440;
                          await SettingsService.instance.set('sleep_target_duration_minutes', diff);
                        }
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.time,
                  use24hFormat: true,
                  initialDateTime: DateTime(2026, 1, 1, selectedTime.hour, selectedTime.minute),
                  onDateTimeChanged: (dt) {
                    selectedTime = TimeOfDay(hour: dt.hour, minute: dt.minute);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return RitmoPageScaffold(
      padding: EdgeInsets.zero,
      appBar: const RitmoModuleAppBar(title: 'دستیار و حریم خصوصی'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 60),
        child: Column(
          children: [
            const PrivacySummaryCard(),
            SettingsSection(
              title: 'پیکربندی هوش مصنوعی',
              children: [
                if (_showAdvanced)
                  SettingsTile(
                    title: 'اتصال و سرور هوش مصنوعی',
                    subtitle: 'پیش‌تنظیم ژیپو، کلودفلر، اوپن‌روتر، کلیدهای اختصاصی و پینگ زنده',
                    leading: Icon(CupertinoIcons.sparkles, color: colors.primary),
                    onTap: () {
                      Navigator.push(
                        context,
                        CupertinoPageRoute(builder: (_) => const AiConnectionScreen()),
                      );
                    },
                  ),
                SettingsTile(
                  title: 'حافظه و یادگیری شناختی',
                  subtitle: 'فکت‌ها، ترجیحات و استخراج خودکار الگوهای رفتاری',
                  leading: Icon(CupertinoIcons.circle_grid_hex_fill, color: colors.primary),
                  onTap: () {
                    Navigator.push(
                      context,
                      CupertinoPageRoute(builder: (_) => const AiMemoryManagementScreen()),
                    );
                  },
                ),
                SettingsTile(
                  title: 'تنظیمات روان‌شناختی رفتاری',
                  subtitle: 'پالایش انگیزشی، اثر شروع تازه و مهار شکست',
                  leading: Icon(CupertinoIcons.heart_fill, color: colors.primary),
                  onTap: () {
                    PsychLayerSettingsSheet.show(context);
                  },
                ),
              ],
            ),
            if (_showAdvanced)
              SettingsSection(
                title: 'حریم خصوصی و پردازش ابری',
                footer: 'در صورت غیرفعال بودن، اطلاعات متن روز به سرویس‌دهنده‌های هوش مصنوعی ارسال نخواهد شد.',
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'رضایت‌نامه پردازش ابری',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: colors.textPrimary),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'مجوز تحلیل داده‌های متنی روتین‌ها',
                              style: TextStyle(fontSize: 12, color: colors.textSecondary),
                            ),
                          ],
                        ),
                        CupertinoSwitch(
                          value: _cloudConsent,
                          activeTrackColor: colors.primary,
                          onChanged: (val) => _update('assistant_cloud_consent', val),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            if (_showAdvanced)
              SettingsSection(
                title: 'اختیارات و تغییرات خودکار دستیار',
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'تغییر خودکار تنظیمات توسط دستیار',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: colors.textPrimary),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'هماهنگی هوشمند ساعات خواب، آلارم‌ها و ظرفیت',
                              style: TextStyle(fontSize: 12, color: colors.textSecondary),
                            ),
                          ],
                        ),
                        CupertinoSwitch(
                          key: const ValueKey('assistant_modify_switch'),
                          value: _assistantCanModify,
                          activeTrackColor: colors.primary,
                          onChanged: (val) => _update('assistant_can_modify_settings', val),
                        ),
                      ],
                    ),
                  ),
                  SettingsTile(
                    key: const ValueKey('ai_write_history_tile'),
                    title: 'تاریخچه تغییرات دستیار هوشمند',
                    subtitle: 'مشاهده گزارش ویرایش‌های خودکار و امکان بازگردانی',
                    leading: Icon(CupertinoIcons.clock_fill, color: colors.primary),
                    onTap: () => AiWriteHistorySheet.show(context),
                  ),
                ],
              ),
            SettingsSection(
              title: 'رفتار و پارامترهای دستیار',
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'لحن و نرمی دستیار',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colors.textPrimary),
                      ),
                      const SizedBox(height: 10),
                      RitmoSegmentedControl<String>(
                        selected: _gentleness,
                        segments: const {
                          'gentle': 'ملایم و منعطف',
                          'medium': 'متعادل',
                          'strict': 'قاطع و جدی',
                        },
                        onSelected: (val) => _update('gentleness_level', val),
                      ),
                    ],
                  ),
                ),
                if (_showAdvanced)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('ظرفیت کار روزانه', style: TextStyle(fontSize: 14, color: colors.textPrimary)),
                            Text('${toPersianDigits(_dailyCapacity ~/ 60)} ساعت و ${toPersianDigits(_dailyCapacity % 60)} دقیقه',
                                style: TextStyle(fontWeight: FontWeight.bold, color: colors.primary)),
                          ],
                        ),
                        CupertinoSlider(
                          value: _dailyCapacity.toDouble(),
                          min: 60,
                          max: 1440,
                          divisions: 23,
                          activeColor: colors.primary,
                          onChanged: (val) => _update('daily_capacity_minutes', val.round()),
                        ),
                      ],
                    ),
                  ),
                SettingsTile(
                  title: 'زمان معمول بیداری',
                  subtitle: toPersianDigits(_wakeTime),
                  onTap: () => _pickTime('sleep_target_wake', _wakeTime, 'زمان بیداری'),
                ),
                SettingsTile(
                  title: 'زمان معمول خواب',
                  subtitle: toPersianDigits(_sleepTime),
                  onTap: () => _pickTime('sleep_target_bedtime', _sleepTime, 'زمان خواب'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
