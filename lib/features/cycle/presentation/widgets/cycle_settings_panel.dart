import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/domain/agenda/day_agenda_service.dart';
import 'package:ritmo/core/domain/engines/ritmo_event_bus.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/cycle/logic/cycle_clock.dart';
import 'package:ritmo/features/cycle/logic/cycle_date_contract.dart';
import 'package:ritmo/features/cycle/logic/cycle_lock_service.dart';
import 'package:ritmo/features/cycle/presentation/onboarding/cycle_onboarding_shell.dart';
import 'package:ritmo/features/cycle/presentation/onboarding/pregnancy_onboarding_shell.dart';
import 'package:ritmo/features/cycle/presentation/widgets/cycle_passcode_sheet.dart';
import 'package:ritmo/features/worship/logic/worship_engine.dart';
import 'package:sqflite/sqflite.dart';

class CycleSettingsPanel extends StatefulWidget {
  const CycleSettingsPanel({
    super.key,
    required this.settings,
    required this.onDataReloadNeeded,
    required this.onOpenPasscodeSheet,
    required this.onTogglePregnancyMode,
    this.onOpenPregnancyOnboarding,
    required this.onEditBaselineParameter,
  });

  final Map<String, String> settings;
  final VoidCallback onDataReloadNeeded;
  final VoidCallback onOpenPasscodeSheet;
  final VoidCallback onTogglePregnancyMode;
  final VoidCallback? onOpenPregnancyOnboarding;
  final Future<void> Function(
    String key,
    String title,
    int min,
    int max,
    int defaultVal,
  )
  onEditBaselineParameter;

  @override
  State<CycleSettingsPanel> createState() => _CycleSettingsPanelState();
}

class _CycleSettingsPanelState extends State<CycleSettingsPanel> {
  late Map<String, String> _localSettings;
  bool _hasAppLock = false;
  bool _hasDedicatedPin = false;
  CycleLockSource _lockSource = CycleLockSource.dedicated;

  @override
  void initState() {
    super.initState();
    _localSettings = Map<String, String>.from(widget.settings);
    _loadLockMetadata();
  }

  @override
  void didUpdateWidget(CycleSettingsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.settings != oldWidget.settings) {
      setState(() {
        _localSettings = Map<String, String>.from(widget.settings);
      });
      _loadLockMetadata();
    }
  }

  Future<void> _loadLockMetadata() async {
    final hasApp = await CycleLockService.instance.hasAppLockPassword();
    final hasDedicated = await CycleLockService.instance.hasCyclePin();
    final source = await CycleLockService.instance.getLockSource();
    if (mounted) {
      setState(() {
        _hasAppLock = hasApp;
        _hasDedicatedPin = hasDedicated;
        _lockSource = source;
      });
    }
  }

  Future<void> _updateSetting(String key, String value) async {
    setState(() {
      _localSettings[key] = value;
    });
    final db = await DatabaseHelper.instance.database;
    await db.insert('app_settings', {
      'key': key,
      'value': value,
      'updatedAt': CycleClock.nowMillisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    widget.onDataReloadNeeded();
  }

  Future<void> _handleLockToggle(bool newValue) async {
    if (newValue) {
      // Turning ON - verify or setup
      bool? success;
      if (_hasDedicatedPin) {
        success = await CyclePasscodeSheet.show(
          context,
          mode: CyclePasscodeSheetMode.verifyBeforeEnable,
        );
      } else if (_hasAppLock) {
        success = await CyclePasscodeSheet.show(
          context,
          mode: CyclePasscodeSheetMode.chooseSource,
        );
      } else {
        success = await CyclePasscodeSheet.show(
          context,
          mode: CyclePasscodeSheetMode.setup,
        );
      }
      if (success == true && mounted) {
        setState(() {
          _localSettings['cycle_lock_enabled'] = 'true';
        });
        await _loadLockMetadata();
        widget.onDataReloadNeeded();
      }
    } else {
      // Turning OFF - verify first
      final success = await CyclePasscodeSheet.show(
        context,
        mode: CyclePasscodeSheetMode.verifyBeforeDisable,
      );
      if (success == true && mounted) {
        setState(() {
          _localSettings['cycle_lock_enabled'] = 'false';
        });
        await _loadLockMetadata();
        widget.onDataReloadNeeded();
      }
    }
  }

  Future<void> _handleOpenPasscodeSheet() async {
    bool? success;
    if (_hasAppLock && !_hasDedicatedPin) {
      success = await CyclePasscodeSheet.show(
        context,
        mode: CyclePasscodeSheetMode.chooseSource,
      );
    } else if (_hasDedicatedPin) {
      success = await CyclePasscodeSheet.show(
        context,
        mode: CyclePasscodeSheetMode.change,
      );
    } else {
      success = await CyclePasscodeSheet.show(
        context,
        mode: CyclePasscodeSheetMode.setup,
      );
    }
    if (success == true && mounted) {
      await _loadLockMetadata();
      widget.onDataReloadNeeded();
    }
  }

  String _getPasscodeSubtitle() {
    if (_lockSource == CycleLockSource.appLock && _hasAppLock) {
      return 'متصل به رمز قفل اصلی برنامه (تغییر)';
    } else if (_hasDedicatedPin) {
      return 'تغییر رمز عبور ۴ رقمی اختصاصی';
    } else {
      return 'تنظیم رمز عبور چرخه';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hasBiometrics = _localSettings['cycle_biometric_enabled'] == 'true';
    final isLockEnabled = _localSettings['cycle_lock_enabled'] == 'true';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                CupertinoIcons.settings_solid,
                color: colors.primary,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'تنظیمات و اتصالات حریم خصوصی',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: colors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: () {
              Navigator.pop(context);
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => CycleOnboardingShell(
                  isEditMode: true,
                  onCompleted: () {
                    Navigator.pop(context);
                    widget.onDataReloadNeeded();
                  },
                  onNavigateToPregnancy: () {
                    Navigator.pop(context);
                    widget.onDataReloadNeeded();
                  },
                ),
              );
            },
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Row(
                children: [
                  Icon(
                    CupertinoIcons.slider_horizontal_3,
                    color: colors.primary,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'ویرایش و بازبینی راه‌اندازی چرخه',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    CupertinoIcons.chevron_left,
                    color: colors.textSecondary,
                    size: 14,
                  ),
                ],
              ),
            ),
          ),
          Divider(height: 16, color: colors.border),
          _buildToggleRow(
            context,
            title: 'قفل اثر انگشت / تشخیص چهره',
            value: hasBiometrics,
            onChanged: (v) async {
              if (v) {
                final didAuth = await CycleLockService.instance
                    .authenticateBiometric(
                      localizedReason:
                          'تأیید هویت جهت فعال‌سازی قفل بیومتریک چرخه',
                    );
                if (!didAuth) return;
              }
              await _updateSetting('cycle_biometric_enabled', v.toString());
            },
          ),
          Divider(height: 16, color: colors.border),
          _buildToggleRow(
            context,
            title: 'رمز عبور حریم خصوصی چرخه',
            value: isLockEnabled,
            onChanged: _handleLockToggle,
          ),
          Divider(height: 16, color: colors.border),
          InkWell(
            onTap: _handleOpenPasscodeSheet,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Row(
                children: [
                  const Text('🔑', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _getPasscodeSubtitle(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    CupertinoIcons.chevron_left,
                    color: colors.textSecondary,
                    size: 14,
                  ),
                ],
              ),
            ),
          ),
          Divider(height: 16, color: colors.border),
          _buildToggleRow(
            context,
            title: 'تأیید تعاملی شروع موعد ریتم',
            value: _localSettings['cycle_confirm_start_enabled'] != 'false',
            onChanged: (v) =>
                _updateSetting('cycle_confirm_start_enabled', v.toString()),
          ),
          Divider(height: 16, color: colors.border),
          _buildToggleRow(
            context,
            title: 'تأیید تعاملی پایان موعد ریتم',
            value: _localSettings['cycle_confirm_end_enabled'] != 'false',
            onChanged: (v) =>
                _updateSetting('cycle_confirm_end_enabled', v.toString()),
          ),
          Divider(height: 16, color: colors.border),
          _buildToggleRow(
            context,
            title: 'ماسک‌کردن پیام‌های ریتم در صندوق اعلان‌ها',
            value: _localSettings['cycle_inbox_mask_enabled'] != 'false',
            onChanged: (v) =>
                _updateSetting('cycle_inbox_mask_enabled', v.toString()),
          ),
          Divider(height: 16, color: colors.border),
          _buildToggleRow(
            context,
            title: 'تعلیق نماز و روزه در عبادات',
            value: _localSettings['cycle_consent_worship'] == 'true',
            onChanged: (v) async {
              await _updateSetting('cycle_consent_worship', v.toString());
              WorshipEngine.instance.invalidate();
              final todayStr = CycleDateContract.toDayKey(CycleClock.now);
              DayAgendaService.instance.invalidateDate(todayStr);
              RitmoEventBus().fire(
                RitmoEvent(
                  type: 'WorshipUpdated',
                  timestamp: CycleClock.now,
                  payload: {'date': todayStr},
                ),
              );
            },
          ),
          Divider(height: 16, color: colors.border),
          _buildToggleRow(
            context,
            title: 'تعدیل فشار در روتین‌ها و انرژی',
            value: _localSettings['cycle_consent_energy'] == 'true',
            onChanged: (v) =>
                _updateSetting('cycle_consent_energy', v.toString()),
          ),
          Divider(height: 16, color: colors.border),
          _buildToggleRow(
            context,
            title: 'تعدیل فشار در کیفیت خواب',
            value: _localSettings['cycle_consent_sleep'] == 'true',
            onChanged: (v) =>
                _updateSetting('cycle_consent_sleep', v.toString()),
          ),
          Divider(height: 16, color: colors.border),
          _buildToggleRow(
            context,
            title: 'یادآوری‌های حریم خصوصی',
            value: _localSettings['cycle_consent_reminders'] == 'true',
            onChanged: (v) =>
                _updateSetting('cycle_consent_reminders', v.toString()),
          ),
          Divider(height: 16, color: colors.border),
          _buildToggleRow(
            context,
            title: 'کارت داشبورد صفحه اصلی',
            value: _localSettings['cycle_consent_dashboard'] == 'true',
            onChanged: (v) =>
                _updateSetting('cycle_consent_dashboard', v.toString()),
          ),
          Divider(height: 16, color: colors.border),
          _buildToggleRow(
            context,
            title: 'نمایش چرخه در تقویم و ریتم‌های روزانه',
            value: _localSettings['show_cycle_in_calendar'] == 'true',
            onChanged: (v) =>
                _updateSetting('show_cycle_in_calendar', v.toString()),
          ),
          Divider(height: 16, color: colors.border),
          if (_localSettings['cycle_pregnancy_mode'] == 'true') ...[
            if (_localSettings['preg_section_hidden'] == 'true') ...[
              InkWell(
                onTap: () async {
                  await _updateSetting('preg_section_hidden', 'false');
                },
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 4,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Text('👁️', style: TextStyle(fontSize: 14)),
                          const SizedBox(width: 8),
                          Text(
                            'نمایش مجدد بخش بارداری',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: colors.primary,
                            ),
                          ),
                        ],
                      ),
                      Icon(
                        CupertinoIcons.chevron_left,
                        color: colors.primary,
                        size: 14,
                      ),
                    ],
                  ),
                ),
              ),
              Divider(height: 16, color: colors.border),
            ] else ...[
              InkWell(
                onTap: () {
                  Navigator.pop(context);
                  PregnancyOnboardingShell.show(
                    context,
                    isEditMode: true,
                    onCompleted: () {
                      Navigator.pop(context);
                      widget.onDataReloadNeeded();
                    },
                  );
                },
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 4,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Text('🤰', style: TextStyle(fontSize: 14)),
                          const SizedBox(width: 8),
                          Text(
                            'ویرایش و بازبینی راه‌اندازی بارداری',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: colors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      Icon(
                        CupertinoIcons.chevron_left,
                        color: colors.textSecondary,
                        size: 14,
                      ),
                    ],
                  ),
                ),
              ),
              Divider(height: 16, color: colors.border),
            ],
            InkWell(
              onTap: widget.onTogglePregnancyMode,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Text('🔄', style: TextStyle(fontSize: 14)),
                        const SizedBox(width: 8),
                        Text(
                          'پایان دوره بارداری و بازگشت به چرخه',
                          style: TextStyle(fontSize: 14, color: colors.primary),
                        ),
                      ],
                    ),
                    Icon(
                      CupertinoIcons.chevron_left,
                      color: colors.textSecondary,
                      size: 14,
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            InkWell(
              onTap: () {
                if (widget.onOpenPregnancyOnboarding != null) {
                  widget.onOpenPregnancyOnboarding!();
                } else {
                  Navigator.pop(context);
                  PregnancyOnboardingShell.show(
                    context,
                    onCompleted: () {
                      Navigator.pop(context);
                      widget.onDataReloadNeeded();
                    },
                  );
                }
              },
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Text('🤰', style: TextStyle(fontSize: 14)),
                        const SizedBox(width: 8),
                        Text(
                          'فعالسازی حالت بارداری',
                          style: TextStyle(
                            fontSize: 14,
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    Icon(
                      CupertinoIcons.chevron_left,
                      color: colors.textSecondary,
                      size: 14,
                    ),
                  ],
                ),
              ),
            ),
          ],
          Divider(height: 24, color: colors.border),
          Text(
            'تنظیمات طول چرخه بدنی',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          _buildParameterRow(
            context,
            title: 'متوسط طول چرخه (فاصله شروع دو پریود)',
            value:
                '${PersianDigits.toFa(_localSettings['cycle_avg_length'] ?? '28')} روز',
            onTap: () => widget.onEditBaselineParameter(
              'cycle_avg_length',
              'طول کل چرخه بدنی',
              21,
              45,
              28,
            ),
          ),
          Divider(height: 16, color: colors.border),
          _buildParameterRow(
            context,
            title: 'متوسط طول دوره قاعدگی (خونریزی)',
            value:
                '${PersianDigits.toFa(_localSettings['cycle_avg_period'] ?? '6')} روز',
            onTap: () => widget.onEditBaselineParameter(
              'cycle_avg_period',
              'طول دوره قاعدگی',
              3,
              10,
              6,
            ),
          ),
          Divider(height: 16, color: colors.border),
          _buildParameterRow(
            context,
            title: 'فاصلهٔ روزهای یادآوری تا موعد',
            value:
                '${PersianDigits.toFa(_localSettings['cycle_reminder_lead_days'] ?? '2')} روز قبل',
            onTap: () => widget.onEditBaselineParameter(
              'cycle_reminder_lead_days',
              'روزهای پیش از موعد',
              1,
              5,
              2,
            ),
          ),
          Divider(height: 16, color: colors.border),
          _buildParameterRow(
            context,
            title: 'ساعت ارسال اعلان و یادآوری',
            value:
                'ساعت ${PersianDigits.toFa(_localSettings['cycle_reminder_hour'] ?? '9')}:۰۰',
            onTap: () => widget.onEditBaselineParameter(
              'cycle_reminder_hour',
              'ساعت اعلان (۰ تا ۲۳)',
              0,
              23,
              9,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParameterRow(
    BuildContext context, {
    required String title,
    required String value,
    required VoidCallback onTap,
  }) {
    final colors = context.colors;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(fontSize: 14, color: colors.textPrimary),
              ),
            ),
            Row(
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: colors.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(CupertinoIcons.pencil, color: colors.primary, size: 16),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleRow(
    BuildContext context, {
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final colors = context.colors;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: TextStyle(fontSize: 14, color: colors.textPrimary)),
        CupertinoSwitch(
          value: value,
          activeTrackColor: colors.primary,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
