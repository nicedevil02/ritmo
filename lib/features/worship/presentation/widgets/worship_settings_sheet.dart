// lib/features/worship/presentation/widgets/worship_settings_sheet.dart

import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/domain/engines/ritmo_event_bus.dart';
import 'package:ritmo/core/services/prayer_time_provider.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/ux/ritmo_sheet_scaffold.dart';
import 'package:ritmo/core/ux/ritmo_snackbar.dart';
import 'package:ritmo/features/worship/logic/hijri_calendar.dart';
import 'package:ritmo/features/worship/logic/prayer_reminder_scheduler.dart';
import 'package:ritmo/features/worship/logic/worship_engine.dart';
import 'package:ritmo/features/worship/presentation/widgets/prayer_city_picker.dart';
import 'package:sqflite/sqflite.dart';

/// Comprehensive and elegant modal bottom sheet for all Worship settings.
class WorshipSettingsSheet extends StatefulWidget {
  const WorshipSettingsSheet({
    super.key,
    required this.onChanged,
  });

  final VoidCallback onChanged;

  static Future<void> present(
    BuildContext context, {
    required VoidCallback onChanged,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => WorshipSettingsSheet(onChanged: onChanged),
    );
  }

  @override
  State<WorshipSettingsSheet> createState() => _WorshipSettingsSheetState();
}

class _WorshipSettingsSheetState extends State<WorshipSettingsSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _childSheetAnimController;
  bool _isLoading = true;
  bool _isSaving = false;

  // ── Location & Calculation ──────────────────────────────
  String _currentCityId = 'TEHRAN_TEHRAN';
  String _cityName = 'تهران';
  String _selectedMethod = 'TEHRAN_GEOPHYSICS';
  bool _showAsrIsha = false;

  // ── Hijri Calendar Offset ───────────────────────────────
  int _hijriOffset = 0;

  // ── Azaan & Audio Alerts ────────────────────────────────
  bool _adhanEnabled = true;
  bool _adhanFajr = true;
  bool _adhanDhuhr = true;
  bool _adhanMaghrib = true;
  int _preReminderMinutes = 0; // 0 (off), 5, 10, 15
  bool _nightPrayerReminder = false;

  // ── Qada Debts ──────────────────────────────────────────
  bool _autoDebtSweep = true;

  // ── Calendar Display Integration ────────────────────────
  bool _showObligatoryInCalendar = true;
  bool _showMustahabInCalendar = true;
  bool _showQadaInCalendar = true;

  static const List<Map<String, String>> _calculationMethods = [
    {'key': 'TEHRAN_GEOPHYSICS', 'label': 'مؤسسه ژئوفیزیک دانشگاه تهران'},
    {'key': 'MWL', 'label': 'اتحادیه جهان اسلام (MWL)'},
    {'key': 'ISNA', 'label': 'جامعه اسلامی آمریکای شمالی (ISNA)'},
    {'key': 'MAKKAH', 'label': 'ام‌القری مکه'},
  ];

  static const List<int> _preReminderOptions = [0, 5, 10, 15];

  @override
  void initState() {
    super.initState();
    _childSheetAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
      reverseDuration: const Duration(milliseconds: 300),
    );
    _loadAllSettings();
  }

  @override
  void dispose() {
    _childSheetAnimController.dispose();
    super.dispose();
  }

  Future<void> _loadAllSettings() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final rows = await db.query('app_settings');
      final settings = {
        for (final r in rows) r['key']! as String: r['value']! as String,
      };

      _currentCityId = settings['prayer_city_id'] ?? 'TEHRAN_TEHRAN';
      _selectedMethod =
          settings['prayer_calculation_method'] ?? 'TEHRAN_GEOPHYSICS';
      _showAsrIsha = settings['show_asr_isha_prayers'] == 'true';
      _hijriOffset = int.tryParse(settings['hijri_offset'] ?? '0') ?? 0;

      // Audio & Adhan
      _adhanEnabled = settings['worship_adhan_enabled'] != 'false';
      _adhanFajr = settings['worship_adhan_fajr'] != 'false';
      _adhanDhuhr = settings['worship_adhan_dhuhr'] != 'false';
      _adhanMaghrib = settings['worship_adhan_maghrib'] != 'false';
      _preReminderMinutes =
          int.tryParse(settings['worship_pre_reminder_minutes'] ?? '0') ?? 0;
      _nightPrayerReminder =
          settings['worship_night_prayer_reminder'] == 'true';

      // Qada
      _autoDebtSweep = settings['worship_auto_debt_sweep'] != 'false';

      // Calendar
      _showObligatoryInCalendar =
          settings['calendar_show_worship_obligatory'] != 'false';
      _showMustahabInCalendar =
          settings['calendar_show_worship_mustahab'] != 'false';
      _showQadaInCalendar =
          settings['calendar_show_worship_qada'] != 'false';

      // City Name resolution
      String name = 'تهران';
      if (_currentCityId.startsWith('CUSTOM_') ||
          _currentCityId.startsWith('INTL_')) {
        name = settings['prayer_custom_city_name'] ?? 'موقعیت سفارشی';
      } else {
        final cityRows = await db.query(
          'iran_cities',
          columns: ['city'],
          where: 'id = ?',
          whereArgs: [_currentCityId],
          limit: 1,
        );
        if (cityRows.isNotEmpty) {
          name = cityRows.first['city'] as String? ?? 'تهران';
        }
      }
      _cityName = name;

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading worship settings: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveSetting(String key, String value) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      await db.insert(
        'app_settings',
        {
          'key': key,
          'value': value,
          'updatedAt': nowMs,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      WorshipEngine.instance.invalidate();
      RitmoEventBus().fire(RitmoEvent(type: 'WorshipUpdated'));
      widget.onChanged();
    } catch (e) {
      debugPrint('Error saving setting $key: $e');
    }
  }

  Future<void> _refreshPrayerTimesOnline() async {
    unawaited(HapticFeedback.mediumImpact());
    setState(() => _isSaving = true);
    try {
      final db = await DatabaseHelper.instance.database;
      await db.delete('prayer_times_cache');
      WorshipEngine.instance.invalidate();

      await PrayerTimeProvider.instance.cacheRange(
        cityId: _currentCityId,
        from: DateTime.now(),
        days: 30,
        forceOnline: true,
        calculationMethod: _selectedMethod,
      );

      RitmoEventBus().fire(RitmoEvent(type: 'WorshipUpdated'));
      widget.onChanged();
      if (mounted) {
        RitmoSnackbar.success(
          context,
          'اوقات شرعی با موفقیت از سرور آنلاین دریافت شد 🕌',
        );
      }
    } catch (e) {
      if (mounted) {
        RitmoSnackbar.error(
          context,
          'بروزرسانی از اینترنت ناموفق بود؛ محاسبات دقیق آفلاین فعال است.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _openCitySelector() {
    RitmoHapticsPolicy.tap();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      transitionAnimationController: _childSheetAnimController,
      builder: (context) {
        return PrayerCityPicker(
          initialTab: 0,
          isNested: true,
          onChanged: () {
            _loadAllSettings();
            widget.onChanged();
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Live preview of today's Hijri date based on current offset
    final now = DateTime.now();
    final previewHijri = HijriCalendarCalculator.hijriFromGregorian(
      now,
      offsetDays: _hijriOffset,
    );

    return Directionality(
      textDirection: TextDirection.rtl,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: RitmoBreakpoints.sheetMaxHeight(context, factor: 0.94),
        ),
        child: AppleCardDeckHost(
          animation: _childSheetAnimController,
          foregroundExtent: 0.94,
          topCornerRadius: 28.0,
          child: RitmoGlassSheet(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  decoration: BoxDecoration(
                    color: colors.border.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Canonical Symmetrical Header Row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Leading (Right in RTL): Circular Tactile Close (X) Button
                    GestureDetector(
                      onTap: () {
                        RitmoHapticsPolicy.tap();
                        Navigator.pop(context);
                      },
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: isDark
                              ? colors.surfaceElevated.withValues(alpha: 0.85)
                              : colors.textPrimary.withValues(alpha: 0.07),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark
                                ? colors.border.withValues(alpha: 0.35)
                                : colors.border.withValues(alpha: 0.15),
                            width: 0.85,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          CupertinoIcons.xmark,
                          size: 15,
                          color: colors.textSecondary,
                        ),
                      ),
                    ),

                    // Center: Title
                    Expanded(
                      child: Text(
                        'تنظیمات عبادت و معنویت',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: colors.textPrimary,
                        ),
                      ),
                    ),

                    // Trailing (Left in RTL): Symmetrical Spacer
                    const SizedBox(width: 34, height: 34),
                  ],
                ),
              ),
              const Divider(height: 1),
              const SizedBox(height: 8),

              // ── Scrollable Body ───────────────────────────────
              Expanded(
                child: _isLoading
                    ? Center(
                        child: CupertinoActivityIndicator(
                          color: colors.primary,
                        ),
                      )
                    : SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.viewInsetsOf(context).bottom + 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // 1. LOCATION & CALCULATION CARD
                            _buildSectionHeader(
                              icon: CupertinoIcons.location_solid,
                              title: 'موقعیت مکانی و روش محاسبه',
                              colors: colors,
                            ),
                            const SizedBox(height: 8),
                            _buildCardContainer(
                              colors: colors,
                              isDark: isDark,
                              children: [
                                // Current City Tile
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: colors.primary.withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      CupertinoIcons.map_pin_ellipse,
                                      color: colors.primary,
                                      size: 18,
                                    ),
                                  ),
                                  title: const Text(
                                    'شهر / موقعیت مکانی',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Text(
                                    _cityName,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: colors.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  trailing: TextButton.icon(
                                    style: TextButton.styleFrom(
                                      backgroundColor: colors.surfaceSunken,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    icon: Icon(
                                      CupertinoIcons.arrow_right_arrow_left,
                                      size: 13,
                                      color: colors.primary,
                                    ),
                                    label: Text(
                                      'تغییر شهر',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: colors.primary,
                                      ),
                                    ),
                                    onPressed: _openCitySelector,
                                  ),
                                ),
                                const Divider(height: 16),

                                // Calculation Method Selector
                                const Text(
                                  'روش محاسبه اوقات شرعی:',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: colors.surfaceSunken,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: colors.border.withValues(alpha: 0.5),
                                    ),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: _selectedMethod,
                                      isExpanded: true,
                                      icon: Icon(
                                        CupertinoIcons.chevron_down,
                                        size: 16,
                                        color: colors.primary,
                                      ),
                                      dropdownColor: isDark
                                          ? colors.surface
                                          : colors.surface,
                                      borderRadius: BorderRadius.circular(12),
                                      items: _calculationMethods.map((m) {
                                        return DropdownMenuItem<String>(
                                          value: m['key'],
                                          child: Text(
                                            m['label']!,
                                            style: TextStyle(
                                              fontSize: 13.5,
                                              color: colors.textPrimary,
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: (newMethod) async {
                                        if (newMethod == null) return;
                                        unawaited(HapticFeedback.selectionClick());
                                        setState(() => _selectedMethod = newMethod);
                                        await _saveSetting(
                                          'prayer_calculation_method',
                                          newMethod,
                                        );
                                        final db =
                                            await DatabaseHelper.instance.database;
                                        await db.delete('prayer_times_cache');
                                        await PrayerTimeProvider.instance.cacheRange(
                                          cityId: _currentCityId,
                                          from: DateTime.now(),
                                          days: 40,
                                          calculationMethod: newMethod,
                                        );
                                        widget.onChanged();
                                      },
                                    ),
                                  ),
                                ),
                                const Divider(height: 20),

                                // Show Asr and Isha Switch
                                _buildSwitchTile(
                                  title: 'نمایش زمان‌های عصر و عشا',
                                  subtitle:
                                      'نمایش زمان شروع فضیلت نمازهای عصر و عشا در کارت‌ها',
                                  value: _showAsrIsha,
                                  colors: colors,
                                  onChanged: (val) {
                                    setState(() => _showAsrIsha = val);
                                    _saveSetting(
                                      'show_asr_isha_prayers',
                                      val.toString(),
                                    );
                                  },
                                ),
                                const Divider(height: 16),

                                // Online API Refresh Action
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: colors.primary,
                                    side: BorderSide(
                                      color: colors.primary.withValues(alpha: 0.35),
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: const EdgeInsets.symmetric(vertical: 11),
                                  ),
                                  icon: _isSaving
                                      ? SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CupertinoActivityIndicator(
                                            color: colors.primary,
                                          ),
                                        )
                                      : Icon(
                                          CupertinoIcons.cloud_download,
                                          size: 17,
                                          color: colors.primary,
                                        ),
                                  label: Text(
                                    'به‌روزرسانی آنلاین اوقات شرعی از API',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: colors.primary,
                                    ),
                                  ),
                                  onPressed: _isSaving
                                      ? null
                                      : _refreshPrayerTimesOnline,
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),

                            // 2. HIJRI CALENDAR ADJUSTMENT CARD
                            _buildSectionHeader(
                              icon: CupertinoIcons.moon_stars_fill,
                              title: 'تقویم قمری و تصحیح هلال ماه',
                              colors: colors,
                            ),
                            const SizedBox(height: 8),
                            _buildCardContainer(
                              colors: colors,
                              isDark: isDark,
                              children: [
                                // Live Preview Banner
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: colors.primary.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: colors.primary.withValues(alpha: 0.25),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        CupertinoIcons.calendar,
                                        color: colors.primary,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'پیش‌نمایش تاریخ قمری امروز:',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              previewHijri.formatted,
                                              style: TextStyle(
                                                fontSize: 14.5,
                                                fontWeight: FontWeight.bold,
                                                color: colors.primary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: colors.surface,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          _hijriOffset == 0
                                              ? 'پیش‌فرض'
                                              : toPersianDigits(
                                                  '${_hijriOffset > 0 ? "+" : ""}$_hijriOffset روز',
                                                ),
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: colors.primary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),

                                // Slider
                                SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    activeTrackColor: colors.primary,
                                    inactiveTrackColor: colors.surfaceSunken,
                                    thumbColor: colors.primary,
                                    overlayColor:
                                        colors.primary.withValues(alpha: 0.2),
                                    valueIndicatorColor: colors.primary,
                                    valueIndicatorTextStyle: TextStyle(
                                      color: colors.onPrimary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  child: Slider(
                                    value: _hijriOffset.toDouble(),
                                    min: -2,
                                    max: 2,
                                    divisions: 4,
                                    label: toPersianDigits(
                                      '${_hijriOffset > 0 ? "+" : ""}$_hijriOffset',
                                    ),
                                    onChanged: (val) {
                                      setState(() {
                                        _hijriOffset = val.round();
                                      });
                                    },
                                    onChangeEnd: (val) {
                                      unawaited(HapticFeedback.selectionClick());
                                      unawaited(
                                        _saveSetting(
                                          'hijri_offset',
                                          val.round().toString(),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '۲- روز (عقب)',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: colors.textSecondary,
                                      ),
                                    ),
                                    Text(
                                      'عادی (۰)',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: colors.textSecondary,
                                      ),
                                    ),
                                    Text(
                                      '۲+ روز (جلو)',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: colors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),

                            // 3. PRAYER NOTIFICATIONS & REMINDERS CARD
                            _buildSectionHeader(
                              icon: CupertinoIcons.bell_fill,
                              title: 'اعلان و یادآوری نمازها',
                              colors: colors,
                            ),
                            const SizedBox(height: 8),
                            _buildCardContainer(
                              colors: colors,
                              isDark: isDark,
                              children: [
                                // Master Prayer Notification Toggle
                                _buildSwitchTile(
                                  title: 'اعلان و یادآوری موعد نماز',
                                  subtitle:
                                      'ارسال اعلان در سر موعد شرعی اذان',
                                  value: _adhanEnabled,
                                  colors: colors,
                                  onChanged: (val) {
                                    setState(() => _adhanEnabled = val);
                                    _saveSetting(
                                      'worship_adhan_enabled',
                                      val.toString(),
                                    );
                                    PrayerReminderScheduler.instance
                                        .schedulePrayerReminders();
                                  },
                                ),


                                if (_adhanEnabled) ...[
                                  const Divider(height: 16),
                                  const Text(
                                    'نوبت‌های فعال یادآوری:',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildChoiceChip(
                                          label: 'نماز صبح',
                                          isSelected: _adhanFajr,
                                          colors: colors,
                                          onTap: () {
                                            setState(() => _adhanFajr = !_adhanFajr);
                                            _saveSetting(
                                              'worship_adhan_fajr',
                                              _adhanFajr.toString(),
                                            );
                                            PrayerReminderScheduler.instance
                                                .schedulePrayerReminders();
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: _buildChoiceChip(
                                          label: 'نماز ظهر',
                                          isSelected: _adhanDhuhr,
                                          colors: colors,
                                          onTap: () {
                                            setState(() => _adhanDhuhr = !_adhanDhuhr);
                                            _saveSetting(
                                              'worship_adhan_dhuhr',
                                              _adhanDhuhr.toString(),
                                            );
                                            PrayerReminderScheduler.instance
                                                .schedulePrayerReminders();
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: _buildChoiceChip(
                                          label: 'نماز مغرب',
                                          isSelected: _adhanMaghrib,
                                          colors: colors,
                                          onTap: () {
                                            setState(() => _adhanMaghrib = !_adhanMaghrib);
                                            _saveSetting(
                                              'worship_adhan_maghrib',
                                              _adhanMaghrib.toString(),
                                            );
                                            PrayerReminderScheduler.instance
                                                .schedulePrayerReminders();
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Divider(height: 20),

                                  // Pre-Adhan Reminder Options
                                  const Text(
                                    'یادآور پیش‌واز (آمادگی برای نماز):',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: _preReminderOptions.map((mins) {
                                      final isSelected = _preReminderMinutes == mins;
                                      final label = mins == 0
                                          ? 'غیرفعال'
                                          : '${toPersianDigits(mins.toString())} دقیقه';
                                      return Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 3,
                                          ),
                                          child: _buildChoiceChip(
                                            label: label,
                                            isSelected: isSelected,
                                            colors: colors,
                                            fontSize: 11.5,
                                            onTap: () {
                                              setState(
                                                () => _preReminderMinutes = mins,
                                              );
                                              _saveSetting(
                                                'worship_pre_reminder_minutes',
                                                mins.toString(),
                                              );
                                              PrayerReminderScheduler.instance
                                                  .schedulePrayerReminders();
                                            },
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ],
                                const Divider(height: 20),

                                // 3. Night Prayer Ritual Toggle
                                _buildSwitchTile(
                                  title: 'کارت و آیین نماز شب',
                                  subtitle:
                                      'نمایش کارت و راهنمای ۱۱ رکعت نماز شب در ساعات نیمه‌شب شرعی تا اذان صبح',
                                  value: _nightPrayerReminder,
                                  colors: colors,
                                  onChanged: (val) {
                                    setState(() => _nightPrayerReminder = val);
                                    _saveSetting(
                                      'worship_night_prayer_reminder',
                                      val.toString(),
                                    );
                                  },
                                ),
                              ],
                            ),

                            const SizedBox(height: 20),

                            // 4. QADA & SETTLEMENT RULES CARD
                            _buildSectionHeader(
                              icon: CupertinoIcons.arrow_counterclockwise_circle_fill,
                              title: 'قضا و ثبت معوقات',
                              colors: colors,
                            ),
                            const SizedBox(height: 8),
                            _buildCardContainer(
                              colors: colors,
                              isDark: isDark,
                              children: [
                                _buildSwitchTile(
                                  title: 'ثبت خودکار نمازهای نخوانده در قضا',
                                  subtitle:
                                      'در پایان هر روز، نمازهای به جا نیاورده شده خودکار به لیست قضای عبادات افزوده شوند',
                                  value: _autoDebtSweep,
                                  colors: colors,
                                  onChanged: (val) {
                                    setState(() => _autoDebtSweep = val);
                                    _saveSetting(
                                      'worship_auto_debt_sweep',
                                      val.toString(),
                                    );
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),

                            // 5. CALENDAR INTEGRATION CARD
                            _buildSectionHeader(
                              icon: CupertinoIcons.calendar_badge_plus,
                              title: 'نمایش در تقویم ریتمو',
                              colors: colors,
                            ),
                            const SizedBox(height: 8),
                            _buildCardContainer(
                              colors: colors,
                              isDark: isDark,
                              children: [
                                _buildSwitchTile(
                                  title: 'نمایش نمازهای واجب در تقویم',
                                  subtitle:
                                      'رندر باکس نمازهای واجب در تایم‌لاین تقویم روزانه',
                                  value: _showObligatoryInCalendar,
                                  colors: colors,
                                  onChanged: (val) {
                                    setState(
                                      () => _showObligatoryInCalendar = val,
                                    );
                                    _saveSetting(
                                      'calendar_show_worship_obligatory',
                                      val.toString(),
                                    );
                                  },
                                ),
                                const Divider(height: 16),
                                _buildSwitchTile(
                                  title: 'نمایش مستحبات و مناسبت‌ها در تقویم',
                                  subtitle:
                                      'نمایش ادعیه و اعمال مناسبتی در تقویم ریتمو',
                                  value: _showMustahabInCalendar,
                                  colors: colors,
                                  onChanged: (val) {
                                    setState(() => _showMustahabInCalendar = val);
                                    _saveSetting(
                                      'calendar_show_worship_mustahab',
                                      val.toString(),
                                    );
                                  },
                                ),
                                const Divider(height: 16),
                                _buildSwitchTile(
                                  title: 'نمایش بدهی‌های قضا در تقویم',
                                  subtitle:
                                      'نمایش برنامهٔ روزانه برای ادای نمازها و روزه‌های قضا',
                                  value: _showQadaInCalendar,
                                  colors: colors,
                                  onChanged: (val) {
                                    setState(() => _showQadaInCalendar = val);
                                    _saveSetting(
                                      'calendar_show_worship_qada',
                                      val.toString(),
                                    );
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required RitmoColors colors,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: colors.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: colors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildCardContainer({
    required RitmoColors colors,
    required bool isDark,
    required List<Widget> children,
  }) {
    return RitmoCard.neumorphic(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required RitmoColors colors,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11.5,
                  color: colors.textSecondary,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Switch.adaptive(
          value: value,
          activeThumbColor: colors.primary,
          activeTrackColor: colors.primary.withValues(alpha: 0.35),
          onChanged: (val) {
            unawaited(HapticFeedback.selectionClick());
            onChanged(val);
          },
        ),
      ],
    );
  }

  Widget _buildChoiceChip({
    required String label,
    required bool isSelected,
    required RitmoColors colors,
    required VoidCallback onTap,
    double fontSize = 12.5,
  }) {
    return GestureDetector(
      onTap: () {
        unawaited(HapticFeedback.selectionClick());
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? colors.primary.withValues(alpha: 0.15)
              : colors.surfaceSunken,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? colors.primary
                : colors.border.withValues(alpha: 0.5),
            width: isSelected ? 1.2 : 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? colors.primary : colors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
