import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/logging/ritmo_logger.dart';
import 'package:ritmo/core/notifications/notification_channel.dart';
import 'package:ritmo/core/services/alarm_scheduler_service.dart';
import 'package:ritmo/core/settings/settings_service.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/widgets/ritmo_module_app_bar.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_page_scaffold.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_segmented_control.dart';
import 'package:ritmo/features/settings/presentation/groups/notification_privacy_screen.dart';
import 'package:ritmo/features/settings/presentation/widgets/day_timeline_preview.dart';
import 'package:ritmo/features/settings/presentation/widgets/notification_channels_section.dart';
import 'package:ritmo/features/settings/presentation/widgets/settings_section.dart';
import 'package:ritmo/features/settings/presentation/widgets/settings_tile.dart';
import 'package:sqflite/sqflite.dart';

class NotificationsGroupScreen extends StatefulWidget {
  final String? highlightKey;

  const NotificationsGroupScreen({
    super.key,
    this.highlightKey,
  });

  @override
  State<NotificationsGroupScreen> createState() => _NotificationsGroupScreenState();
}

class _NotificationsGroupScreenState extends State<NotificationsGroupScreen> {
  bool _masterEnabled = true;
  bool _quietEnabled = false;
  String _quietStart = '23:00';
  String _quietEnd = '07:00';
  bool _persistentEnabled = true;
  String _digestMode = 'standard';
  int _maxNonEssential = 3;
  int _snoozeMinutes = 10;
  int _snoozeMaxDefer = 3;
  bool _showAdvanced = false;

  Map<String, bool> _channelEnabled = {
    for (final ch in NotificationChannelId.values) ch.nativeId: true,
  };
  bool _loadingChannels = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadChannelPrefs();
  }

  void _loadSettings() {
    setState(() {
      _masterEnabled = SettingsService.instance.get<bool>('notif_master_enabled');
      _quietEnabled = SettingsService.instance.get<bool>('notif_quiet_enabled');
      _quietStart = SettingsService.instance.get<String>('notif_quiet_start');
      _quietEnd = SettingsService.instance.get<String>('notif_quiet_end');
      _persistentEnabled = SettingsService.instance.get<bool>('persistent_status_notification_enabled');
      _digestMode = SettingsService.instance.get<String>('digest_mode');
      _maxNonEssential = SettingsService.instance.get<int>('max_non_essential_per_hour');
      _snoozeMinutes = SettingsService.instance.get<int>('snooze_minutes');
      _snoozeMaxDefer = SettingsService.instance.get<int>('snooze_max_defer_count');
      _showAdvanced = SettingsService.instance.get<bool>('show_advanced_settings');
    });
  }

  Future<void> _loadChannelPrefs() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final rows = await db.query('notification_channel_prefs');
      final map = <String, bool>{};
      for (final r in rows) {
        map[r['channel_id'] as String] = (r['enabled'] as int) == 1;
      }
      if (mounted) {
        setState(() {
          _channelEnabled = map;
          _loadingChannels = false;
        });
      }
    } catch (e, st) {
      RitmoLog.error('Settings', 'Failed to load notification channel preferences', e, st);
      if (mounted) {
        setState(() => _loadingChannels = false);
      }
    }
  }

  Future<void> _updateSetting(String key, Object val) async {
    await SettingsService.instance.set(key, val);
    await AlarmSchedulerService.scheduleNextAlarms();
    _loadSettings();
  }

  Future<void> _toggleChannel(NotificationChannelId channel, bool enabled) async {
    setState(() {
      _channelEnabled[channel.nativeId] = enabled;
    });

    try {
      final db = await DatabaseHelper.instance.database;
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      await db.insert(
        'notification_channel_prefs',
        {
          'channel_id': channel.nativeId,
          'enabled': enabled ? 1 : 0,
          'sound_mode': 'default',
          'vibration_enabled': 1,
          'bypass_dnd': channel.bypassesQuietHours ? 1 : 0,
          'updated_at': nowMs,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await AlarmSchedulerService.scheduleNextAlarms();
    } catch (e, st) {
      RitmoLog.error('Settings', 'Failed to update channel prefs for ${channel.nativeId}', e, st);
    }
  }

  Future<void> _pickTime(String key, String currentVal, String title) async {
    final parts = currentVal.split(':');
    final initialH = int.tryParse(parts[0]) ?? 0;
    final initialM = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
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
                        await _updateSetting(key, formatted);
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

    return Directionality(
      textDirection: TextDirection.rtl,
      child: RitmoPageScaffold(
        padding: EdgeInsets.zero,
        appBar: RitmoModuleAppBar.fromContext(
          context: context,
          title: 'مرکز کنترل اعلان‌ها',
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 60),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 0. 24h Timeline Preview
              const DayTimelinePreview(),
              const SizedBox(height: 12),

              // 1. Master Control Section
              _buildMasterSection(colors),
              const SizedBox(height: 12),

              // 2. Privacy Center Banner Button
              _buildPrivacyCenterTile(colors),
              const SizedBox(height: 12),

              // If Master disabled, show disabled warning banner
              if (!_masterEnabled)
                _buildDisabledBanner(colors)
              else ...[
                // 3. Quiet Hours Section
                _buildQuietHoursSection(colors),

                // 4. Rate Limiting & Digest (Advanced Mode only)
                if (_showAdvanced) _buildThrottlingSection(colors),

                // 5. Snooze Settings
                _buildSnoozeSection(colors),

                // 6. Canonical Channels Section
                NotificationChannelsSection(
                  loadingChannels: _loadingChannels,
                  channelEnabled: _channelEnabled,
                  onToggleChannel: _toggleChannel,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMasterSection(dynamic colors) {
    return SettingsSection(
      title: 'کنترل سراسری اعلان‌ها',
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'کلید اصلی اعلان‌ها (Master)',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'فعال بودن تمام زمان‌بندی‌ها، یادآوری‌ها و هشدارهای ریتمو',
                      style: TextStyle(fontSize: 12, color: colors.textSecondary),
                    ),
                  ],
                ),
              ),
              CupertinoSwitch(
                value: _masterEnabled,
                activeTrackColor: colors.primary,
                onChanged: (val) => _updateSetting('notif_master_enabled', val),
              ),
            ],
          ),
        ),
        if (_showAdvanced)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'اعلان دائمی وضعیت (Live Status)',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'نمایش نوار وضعیت و وظیفه جاری در پنل نوتیفیکیشن‌ها',
                        style: TextStyle(fontSize: 12, color: colors.textSecondary),
                      ),
                    ],
                  ),
                ),
                CupertinoSwitch(
                  value: _persistentEnabled,
                  activeTrackColor: colors.primary,
                  onChanged: (val) => _updateSetting('persistent_status_notification_enabled', val),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildPrivacyCenterTile(dynamic colors) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            CupertinoPageRoute<void>(builder: (_) => const NotificationPrivacyScreen()),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.primary.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(CupertinoIcons.shield_lefthalf_fill, color: colors.primary, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'مرکز حریم خصوصی و اعلان‌های مبدل',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'تنظیم متن جایگزین روی صفحه قفل و قفل اثرانگشت',
                      style: TextStyle(fontSize: 12, color: colors.textSecondary),
                    ),
                  ],
                ),
              ),
              Icon(CupertinoIcons.chevron_back, size: 18, color: colors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDisabledBanner(dynamic colors) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(CupertinoIcons.exclamationmark_triangle_fill, color: Color(0xFFF59E0B), size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'تمام اعلان‌ها و آلارم‌های ریتمو به صورت سراسری غیرفعال هستند. برای دریافت یادآوری‌ها، کلید اصلی را روشن کنید.',
              style: TextStyle(fontSize: 13, color: colors.textPrimary, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuietHoursSection(dynamic colors) {
    return SettingsSection(
      title: 'ساعات سکوت و استراحت (Quiet Hours)',
      footer: 'اعلان‌های حیاتی پزشکی و دارویی حتی در ساعات سکوت نیز با اولویت بالا ارسال می‌شوند.',
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'فعال‌سازی ساعات سکوت',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: colors.textPrimary),
              ),
              CupertinoSwitch(
                value: _quietEnabled,
                activeTrackColor: colors.primary,
                onChanged: (val) => _updateSetting('notif_quiet_enabled', val),
              ),
            ],
          ),
        ),
        if (_quietEnabled) ...[
          SettingsTile(
            title: 'زمان آغاز سکوت',
            subtitle: toPersianDigits(_quietStart),
            onTap: () => _pickTime('notif_quiet_start', _quietStart, 'زمان آغاز سکوت'),
          ),
          SettingsTile(
            title: 'زمان پایان سکوت',
            subtitle: toPersianDigits(_quietEnd),
            onTap: () => _pickTime('notif_quiet_end', _quietEnd, 'زمان پایان سکوت'),
          ),
        ],
      ],
    );
  }

  Widget _buildThrottlingSection(dynamic colors) {
    return SettingsSection(
      title: 'تجمیع و محدودیت نرخ (Throttling)',
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'حالت خلاصه‌سازی اعلان‌ها',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colors.textPrimary),
              ),
              const SizedBox(height: 10),
              RitmoSegmentedControl<String>(
                selected: _digestMode,
                segments: const {
                  'standard': 'استاندارد',
                  'concise': 'فشرده',
                  'grouped': 'دسته‌ای',
                },
                onSelected: (val) => _updateSetting('digest_mode', val),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('سقف اعلان‌های غیرضروری در ساعت', style: TextStyle(fontSize: 14, color: colors.textPrimary)),
                  Text('${toPersianDigits(_maxNonEssential)} پیام', style: TextStyle(fontWeight: FontWeight.bold, color: colors.primary)),
                ],
              ),
              CupertinoSlider(
                value: _maxNonEssential.toDouble(),
                min: 1,
                max: 10,
                divisions: 9,
                activeColor: colors.primary,
                onChanged: (val) => _updateSetting('max_non_essential_per_hour', val.round()),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSnoozeSection(dynamic colors) {
    return SettingsSection(
      title: 'تنظیمات به تعویق انداختن (Snooze)',
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('مدت زمان هر بار تعویق', style: TextStyle(fontSize: 14, color: colors.textPrimary)),
                  Text('${toPersianDigits(_snoozeMinutes)} دقیقه', style: TextStyle(fontWeight: FontWeight.bold, color: colors.primary)),
                ],
              ),
              CupertinoSlider(
                value: _snoozeMinutes.toDouble(),
                min: 5,
                max: 60,
                divisions: 11,
                activeColor: colors.primary,
                onChanged: (val) => _updateSetting('snooze_minutes', val.round()),
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
                    Text('سقف دفعات تعویق در روز', style: TextStyle(fontSize: 14, color: colors.textPrimary)),
                    Text('${toPersianDigits(_snoozeMaxDefer)} بار', style: TextStyle(fontWeight: FontWeight.bold, color: colors.primary)),
                  ],
                ),
                CupertinoSlider(
                  value: _snoozeMaxDefer.toDouble(),
                  min: 1,
                  max: 10,
                  divisions: 9,
                  activeColor: colors.primary,
                  onChanged: (val) => _updateSetting('snooze_max_defer_count', val.round()),
                ),
              ],
            ),
          ),
      ],
    );
  }


}
