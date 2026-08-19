import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/movement/application/movement_preferences_service.dart';
import 'package:ritmo/features/movement/presentation/common/movement_screen_shell.dart';
import 'package:ritmo/features/movement/presentation/common/movement_strings.dart';
import 'package:ritmo/features/movement/presentation/settings/widgets/settings_choice_row.dart';
import 'package:ritmo/features/movement/presentation/settings/widgets/settings_danger_row.dart';
import 'package:ritmo/features/movement/presentation/settings/widgets/settings_group.dart';
import 'package:ritmo/features/movement/presentation/settings/widgets/settings_switch_row.dart';

/// صفحهٔ تنظیمات جامع حرکت (MovementSettingsScreen)
class MovementSettingsScreen extends StatefulWidget {
  const MovementSettingsScreen({super.key, this.preferencesService});

  final MovementPreferencesService? preferencesService;

  @override
  State<MovementSettingsScreen> createState() => _MovementSettingsScreenState();
}

class _MovementSettingsScreenState extends State<MovementSettingsScreen> {
  late final MovementPreferencesService _service;
  bool _isLoading = true;

  // ۱. واحدها
  String _distanceUnit = 'km';
  String _weightUnit = 'kg';

  // ۲. یادآوری‌ها
  String _defaultReminderTime = '08:00';
  bool _morningReminder = true;
  bool _preSessionReminder = true;
  bool _quietMode = false;

  // ۳. تجربهٔ جلسه
  bool _keepScreenOn = true;
  bool _soundEnabled = true;
  bool _hapticEnabled = true;
  int _countdownSeconds = 3;

  // ۴. پیشنهادهای هوشمند
  bool _smartSuggestionsEnabled = true;
  String _interventionLevel = 'medium';
  String _planBBehavior = 'auto_suggest';

  @override
  void initState() {
    super.initState();
    _service = widget.preferencesService ?? MovementPreferencesService();
    _loadAllSettings();
  }

  Future<void> _loadAllSettings() async {
    final settings = await _service.getAllSettings();
    if (mounted) {
      setState(() {
        _distanceUnit = settings['distanceUnit'] as String;
        _weightUnit = settings['weightUnit'] as String;
        _defaultReminderTime = settings['defaultReminderTime'] as String;
        _morningReminder = settings['morningReminder'] as bool;
        _preSessionReminder = settings['preSessionReminder'] as bool;
        _quietMode = settings['quietMode'] as bool;
        _keepScreenOn = settings['keepScreenOn'] as bool;
        _soundEnabled = settings['soundEnabled'] as bool;
        _hapticEnabled = settings['hapticEnabled'] as bool;
        _countdownSeconds = settings['countdownSeconds'] as int;
        _smartSuggestionsEnabled = settings['smartSuggestionsEnabled'] as bool;
        _interventionLevel = settings['interventionLevel'] as String;
        _planBBehavior = settings['planBBehavior'] as String;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleDistanceUnitChanged(String val) async {
    setState(() => _distanceUnit = val);
    await _service.setString(MovementPreferencesService.keyDistanceUnit, val);
  }

  Future<void> _handleWeightUnitChanged(String val) async {
    setState(() => _weightUnit = val);
    await _service.setString(MovementPreferencesService.keyWeightUnit, val);
  }

  Future<void> _handleMorningReminderChanged(bool val) async {
    setState(() => _morningReminder = val);
    await _service.setBool(MovementPreferencesService.keyMorningReminder, val);
  }

  Future<void> _handlePreSessionReminderChanged(bool val) async {
    setState(() => _preSessionReminder = val);
    await _service.setBool(
      MovementPreferencesService.keyPreSessionReminder,
      val,
    );
  }

  Future<void> _handleQuietModeChanged(bool val) async {
    setState(() => _quietMode = val);
    await _service.setBool(MovementPreferencesService.keyQuietMode, val);
  }

  Future<void> _handleKeepScreenOnChanged(bool val) async {
    setState(() => _keepScreenOn = val);
    await _service.setBool(MovementPreferencesService.keyKeepScreenOn, val);
  }

  Future<void> _handleSoundEnabledChanged(bool val) async {
    setState(() => _soundEnabled = val);
    await _service.setBool(MovementPreferencesService.keySoundEnabled, val);
  }

  Future<void> _handleHapticEnabledChanged(bool val) async {
    setState(() => _hapticEnabled = val);
    await _service.setBool(MovementPreferencesService.keyHapticEnabled, val);
  }

  Future<void> _handleCountdownSecondsChanged(int val) async {
    setState(() => _countdownSeconds = val);
    await _service.setInt(MovementPreferencesService.keyCountdownSeconds, val);
  }

  Future<void> _handleSmartSuggestionsChanged(bool val) async {
    setState(() => _smartSuggestionsEnabled = val);
    await _service.setBool(
      MovementPreferencesService.keySmartSuggestionsEnabled,
      val,
    );
  }

  Future<void> _handleInterventionLevelChanged(String val) async {
    setState(() => _interventionLevel = val);
    await _service.setString(
      MovementPreferencesService.keyInterventionLevel,
      val,
    );
  }

  Future<void> _handlePlanBBehaviorChanged(String val) async {
    setState(() => _planBBehavior = val);
    await _service.setString(MovementPreferencesService.keyPlanBBehavior, val);
  }

  Future<void> _showStoredDataStats() async {
    final counts = await _service.getStoredDataCounts();
    if (!mounted) return;
    final colors = context.colors;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(RitmoRadius.card),
        ),
        title: Text(
          'داده‌های ذخیره‌شده در دستگاه',
          style: RitmoTextStyles.cardTitle(colors.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: counts.entries.map((e) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    e.key,
                    style: RitmoTextStyles.caption(colors.textSecondary),
                  ),
                  Text(
                    toPersianDigits(e.value),
                    style: RitmoTextStyles.caption(colors.textPrimary),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('بستن'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportData() async {
    final jsonStr = await _service.exportMovementData();
    await Clipboard.setData(ClipboardData(text: jsonStr));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('داده‌های حرکت با موفقیت به کلیپ‌بورد کپی شدند.'),
        ),
      );
    }
  }

  Future<void> _handleDeleteAllData() async {
    final colors = context.colors;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(RitmoRadius.card),
        ),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: colors.accent),
            const SizedBox(width: RitmoSpacing.xs),
            Text(
              MovementStrings.settingsDeleteConfirmTitle,
              style: RitmoTextStyles.cardTitle(colors.textPrimary),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              MovementStrings.settingsDeleteImpactText,
              style: RitmoTextStyles.body(colors.textSecondary),
            ),
            const SizedBox(height: RitmoSpacing.md),
            Text(
              'موارد زیر کاملاً پاکسازی خواهند شد:',
              style: RitmoTextStyles.caption(
                colors.textPrimary,
              ).copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              '• تمام جلسات زنده و تاریخچه‌ها',
              style: RitmoTextStyles.caption(colors.textTertiary),
            ),
            Text(
              '• برنامه‌ها و روزهای تمرین قدرتی',
              style: RitmoTextStyles.caption(colors.textTertiary),
            ),
            Text(
              '• چک‌این‌های آمادگی و رکوردهای شخصی',
              style: RitmoTextStyles.caption(colors.textTertiary),
            ),
            Text(
              '• قالب‌ها و زمان‌بندی‌های حرکتی',
              style: RitmoTextStyles.caption(colors.textTertiary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('انصراف'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.accent,
              foregroundColor: Colors.white,
            ),
            child: const Text('حذف کامل داده‌ها'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _service.deleteAllMovementData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('داده‌های ماژول حرکت با موفقیت پاکسازی شدند.'),
          ),
        );
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return MovementScreenShell(
      title: MovementStrings.settingsScreenTitle,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator.adaptive())
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(
                horizontal: RitmoSpacing.lg,
                vertical: RitmoSpacing.md,
              ),
              child: Column(
                children: [
                  // ۱. گروه واحدها
                  SettingsGroup(
                    title: MovementStrings.settingsUnitsGroup,
                    icon: Icons.straighten_rounded,
                    children: [
                      SettingsChoiceRow<String>(
                        title: 'واحد مسافت',
                        explanation: 'در جلسات دویدن، پیاده‌روی و دوچرخه‌سواری',
                        selectedValue: _distanceUnit,
                        options: const {'km': 'کیلومتر', 'mi': 'مایل'},
                        onChanged: _handleDistanceUnitChanged,
                      ),
                      const Divider(height: 1),
                      SettingsChoiceRow<String>(
                        title: 'واحد وزنه',
                        explanation: 'در تمرینات قدرتی و ثبت ست‌ها',
                        selectedValue: _weightUnit,
                        options: const {'kg': 'کیلوگرم', 'lb': 'پوند'},
                        onChanged: _handleWeightUnitChanged,
                      ),
                    ],
                  ),

                  // ۲. گروه یادآوری‌ها
                  SettingsGroup(
                    title: MovementStrings.settingsRemindersGroup,
                    icon: Icons.notifications_none_rounded,
                    children: [
                      SettingsChoiceRow<String>(
                        title: 'ساعت یادآوری پیش‌فرض',
                        explanation: 'زمان پیش‌فرض برای ثبت جلسات جدید',
                        selectedValue: _defaultReminderTime,
                        options: const {
                          '07:00': '۰۷:۰۰',
                          '08:00': '۰۸:۰۰',
                          '09:00': '۰۹:۰۰',
                          '18:00': '۱۸:۰۰',
                        },
                        onChanged: (val) async {
                          setState(() => _defaultReminderTime = val);
                          await _service.setString(
                            MovementPreferencesService.keyDefaultReminderTime,
                            val,
                          );
                        },
                      ),
                      const Divider(height: 1),
                      SettingsSwitchRow(
                        title: 'یادآوری صبحگاهی',
                        explanation:
                            'نمایش خلاصهٔ برنامه‌های حرکتی روز در آغاز صبح',
                        value: _morningReminder,
                        onChanged: _handleMorningReminderChanged,
                      ),
                      const Divider(height: 1),
                      SettingsSwitchRow(
                        title: 'یادآوری پیش از جلسه',
                        explanation:
                            'اعلان ۱۵ دقیقه قبل از زمان مشخص‌شده برای تمرین',
                        value: _preSessionReminder,
                        onChanged: _handlePreSessionReminderChanged,
                      ),
                      const Divider(height: 1),
                      SettingsSwitchRow(
                        title: 'حالت بی‌صدا در تمرین',
                        explanation:
                            'عدم پخش هشدارهای صوتی و تمرکز بر بازخورد لرزشی',
                        value: _quietMode,
                        onChanged: _handleQuietModeChanged,
                      ),
                    ],
                  ),

                  // ۳. گروه تجربهٔ جلسه
                  SettingsGroup(
                    title: MovementStrings.settingsExperienceGroup,
                    icon: Icons.play_circle_outline_rounded,
                    children: [
                      SettingsSwitchRow(
                        title: 'روشن ماندن صفحه',
                        explanation:
                            'جلوگیری از خاموش شدن صفحه هنگام اجرای جلسهٔ زنده',
                        value: _keepScreenOn,
                        onChanged: _handleKeepScreenOnChanged,
                      ),
                      const Divider(height: 1),
                      SettingsSwitchRow(
                        title: 'صدای تایمر و پایان استراحت',
                        explanation:
                            'پخش بوق کوتاه در ثانیه‌های پایانی استراحت ست‌ها',
                        value: _soundEnabled,
                        onChanged: _handleSoundEnabledChanged,
                      ),
                      const Divider(height: 1),
                      SettingsSwitchRow(
                        title: 'بازخورد لرزشی (Haptic)',
                        explanation:
                            'لرزش ملایم هنگام ثبت ست یا تغییر وضعیت تایمر',
                        value: _hapticEnabled,
                        onChanged: _handleHapticEnabledChanged,
                      ),
                      const Divider(height: 1),
                      SettingsChoiceRow<int>(
                        title: 'شمارش معکوس شروع',
                        explanation:
                            'ثانیه‌های آماده‌سازی پیش از آغاز تایمر جلسه',
                        selectedValue: _countdownSeconds,
                        options: const {
                          5: '۵ ثانیه',
                          3: '۳ ثانیه',
                          0: 'بدون وقفه',
                        },
                        onChanged: _handleCountdownSecondsChanged,
                      ),
                    ],
                  ),

                  // ۴. گروه پیشنهادهای هوشمند
                  SettingsGroup(
                    title: MovementStrings.settingsSuggestionsGroup,
                    icon: Icons.auto_awesome_rounded,
                    children: [
                      SettingsSwitchRow(
                        title: 'پیشنهادهای هوشمند مربی',
                        explanation:
                            'ارائهٔ پیشنهادهای تطبیقی بر اساس وضعیت خستگی و آمادگی',
                        value: _smartSuggestionsEnabled,
                        onChanged: _handleSmartSuggestionsChanged,
                      ),
                      const Divider(height: 1),
                      SettingsChoiceRow<String>(
                        title: 'میزان مداخلهٔ هوشمند',
                        explanation:
                            'تواتر و حساسیت سیستم در پیشنهاد نسخهٔ سبک‌تر (Plan B)',
                        selectedValue: _interventionLevel,
                        options: const {
                          'low': 'کم',
                          'medium': 'متوسط',
                          'high': 'حساس',
                        },
                        onChanged: _handleInterventionLevelChanged,
                      ),
                      const Divider(height: 1),
                      SettingsChoiceRow<String>(
                        title: 'رفتار Plan B',
                        explanation: 'نحوهٔ نمایش گزینه‌های جایگزین تمرین',
                        selectedValue: _planBBehavior,
                        options: const {
                          'auto_suggest': 'پیشنهاد هوشمند',
                          'manual_only': 'صرفاً دستی',
                        },
                        onChanged: _handlePlanBBehaviorChanged,
                      ),
                    ],
                  ),

                  // ۵. گروه حریم خصوصی و داده‌ها
                  SettingsGroup(
                    title: MovementStrings.settingsPrivacyGroup,
                    icon: Icons.lock_outline_rounded,
                    children: [
                      Material(
                        color: Colors.transparent,
                        child: ListTile(
                          leading: const Icon(Icons.info_outline_rounded),
                          title: Text(
                            'مشاهدهٔ خلاصه داده‌های ذخیره‌شده',
                            style: RitmoTextStyles.body(colors.textPrimary),
                          ),
                          subtitle: Text(
                            'تعداد سوابق، ست‌ها و برنامه‌های موجود در حافظه',
                            style: RitmoTextStyles.caption(colors.textTertiary),
                          ),
                          onTap: _showStoredDataStats,
                        ),
                      ),
                      const Divider(height: 1),
                      Material(
                        color: Colors.transparent,
                        child: ListTile(
                          leading: const Icon(Icons.download_rounded),
                          title: Text(
                            'خروجی گرفتن از داده‌های حرکت (JSON)',
                            style: RitmoTextStyles.body(colors.textPrimary),
                          ),
                          subtitle: Text(
                            'کپی ساختار داده‌ها برای پشتیبان‌گیری',
                            style: RitmoTextStyles.caption(colors.textTertiary),
                          ),
                          onTap: _exportData,
                        ),
                      ),
                      const Divider(height: 1),
                      SettingsDangerRow(
                        title: MovementStrings.settingsDeleteAllData,
                        explanation:
                            'پاکسازی کامل همهٔ جلسات، برنامه‌ها، سوابق و رکوردهای حرکت از دستگاه.',
                        buttonLabel: 'حذف کامل داده‌های حرکت',
                        onTap: _handleDeleteAllData,
                      ),
                    ],
                  ),

                  // ۶. گروه درباره و سلب مسئولیت
                  SettingsGroup(
                    title: MovementStrings.settingsAboutGroup,
                    icon: Icons.verified_user_outlined,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(RitmoSpacing.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              MovementStrings.settingsMedicalDisclaimer,
                              style: RitmoTextStyles.body(
                                colors.textPrimary,
                              ).copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: RitmoSpacing.xs),
                            Text(
                              'پیشنهادها و آمارهای ارائه شده صرفاً جنبهٔ راهنمایی ورزشی داشته و به هیچ عنوان جایگزین توصیه یا تشخیص پزشک، فیزیوتراپ یا مربی تخصصی نمی‌باشند. در صورت احساس درد شدید یا بیماری، تمرین را متوقف کرده و با پزشک مشورت نمایید.',
                              style: RitmoTextStyles.caption(
                                colors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: RitmoSpacing.xxl),
                ],
              ),
            ),
    );
  }
}
