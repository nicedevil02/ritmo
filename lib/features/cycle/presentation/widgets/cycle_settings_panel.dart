import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/domain/agenda/day_agenda_service.dart';
import 'package:ritmo/core/domain/engines/ritmo_event_bus.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/cycle/logic/cycle_clock.dart';
import 'package:ritmo/features/cycle/logic/cycle_date_contract.dart';
import 'package:ritmo/features/cycle/presentation/onboarding/cycle_onboarding_shell.dart';
import 'package:ritmo/features/worship/logic/worship_engine.dart';
import 'package:sqflite/sqflite.dart';

class CycleSettingsPanel extends StatelessWidget {
  const CycleSettingsPanel({
    super.key,
    required this.settings,
    required this.onDataReloadNeeded,
    required this.onOpenPasscodeSheet,
    required this.onTogglePregnancyMode,
    required this.onEditBaselineParameter,
  });

  final Map<String, String> settings;
  final VoidCallback onDataReloadNeeded;
  final VoidCallback onOpenPasscodeSheet;
  final VoidCallback onTogglePregnancyMode;
  final Future<void> Function(
    String key,
    String title,
    int min,
    int max,
    int defaultVal,
  )
  onEditBaselineParameter;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hasBiometrics = settings['cycle_biometric_enabled'] == 'true';

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
                    onDataReloadNeeded();
                  },
                  onNavigateToPregnancy: () {
                    Navigator.pop(context);
                    onDataReloadNeeded();
                  },
                ),
              );
            },
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        CupertinoIcons.slider_horizontal_3,
                        color: colors.primary,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'ویرایش و بازبینی راه‌اندازی چرخه',
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
          _buildToggleRow(
            context,
            title: 'قفل اثر انگشت / تشخیص چهره',
            value: hasBiometrics,
            onChanged: (v) async {
              final db = await DatabaseHelper.instance.database;
              await db.insert('app_settings', {
                'key': 'cycle_biometric_enabled',
                'value': v.toString(),
                'updatedAt': CycleClock.nowMillisecondsSinceEpoch,
              }, conflictAlgorithm: ConflictAlgorithm.replace);
              onDataReloadNeeded();
            },
          ),
          Divider(height: 16, color: colors.border),
          _buildToggleRow(
            context,
            title: 'رمز عبور حریم خصوصی چرخه',
            value: settings['cycle_lock_enabled'] != 'false',
            onChanged: (v) async {
              final db = await DatabaseHelper.instance.database;
              await db.insert('app_settings', {
                'key': 'cycle_lock_enabled',
                'value': v.toString(),
                'updatedAt': CycleClock.nowMillisecondsSinceEpoch,
              }, conflictAlgorithm: ConflictAlgorithm.replace);
              onDataReloadNeeded();
            },
          ),
          Divider(height: 16, color: colors.border),
          InkWell(
            onTap: () {
              Navigator.pop(context);
              onOpenPasscodeSheet();
            },
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Text('🔑', style: TextStyle(fontSize: 14)),
                      const SizedBox(width: 8),
                      Text(
                        settings['app_lock_password'] != null &&
                                settings['app_lock_password']!.isNotEmpty
                            ? 'تغییر رمز عبور چرخه'
                            : 'تنظیم رمز عبور چرخه',
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
          Divider(height: 16, color: colors.border),
          _buildToggleRow(
            context,
            title: 'تعلیق نماز و روزه در عبادات',
            value: settings['cycle_consent_worship'] == 'true',
            onChanged: (v) async {
              final db = await DatabaseHelper.instance.database;
              await db.insert('app_settings', {
                'key': 'cycle_consent_worship',
                'value': v.toString(),
                'updatedAt': CycleClock.nowMillisecondsSinceEpoch,
              }, conflictAlgorithm: ConflictAlgorithm.replace);
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
              onDataReloadNeeded();
            },
          ),
          Divider(height: 16, color: colors.border),
          _buildToggleRow(
            context,
            title: 'تعدیل فشار در روتین‌ها و انرژی',
            value: settings['cycle_consent_energy'] == 'true',
            onChanged: (v) async {
              final db = await DatabaseHelper.instance.database;
              await db.insert('app_settings', {
                'key': 'cycle_consent_energy',
                'value': v.toString(),
                'updatedAt': CycleClock.nowMillisecondsSinceEpoch,
              }, conflictAlgorithm: ConflictAlgorithm.replace);
              onDataReloadNeeded();
            },
          ),
          Divider(height: 16, color: colors.border),
          _buildToggleRow(
            context,
            title: 'تعدیل فشار در کیفیت خواب',
            value: settings['cycle_consent_sleep'] == 'true',
            onChanged: (v) async {
              final db = await DatabaseHelper.instance.database;
              await db.insert('app_settings', {
                'key': 'cycle_consent_sleep',
                'value': v.toString(),
                'updatedAt': CycleClock.nowMillisecondsSinceEpoch,
              }, conflictAlgorithm: ConflictAlgorithm.replace);
              onDataReloadNeeded();
            },
          ),
          Divider(height: 16, color: colors.border),
          _buildToggleRow(
            context,
            title: 'یادآوری‌های حریم خصوصی',
            value: settings['cycle_consent_reminders'] == 'true',
            onChanged: (v) async {
              final db = await DatabaseHelper.instance.database;
              await db.insert('app_settings', {
                'key': 'cycle_consent_reminders',
                'value': v.toString(),
                'updatedAt': CycleClock.nowMillisecondsSinceEpoch,
              }, conflictAlgorithm: ConflictAlgorithm.replace);
              onDataReloadNeeded();
            },
          ),
          Divider(height: 16, color: colors.border),
          _buildToggleRow(
            context,
            title: 'کارت داشبورد صفحه اصلی',
            value: settings['cycle_consent_dashboard'] == 'true',
            onChanged: (v) async {
              final db = await DatabaseHelper.instance.database;
              await db.insert('app_settings', {
                'key': 'cycle_consent_dashboard',
                'value': v.toString(),
                'updatedAt': CycleClock.nowMillisecondsSinceEpoch,
              }, conflictAlgorithm: ConflictAlgorithm.replace);
              onDataReloadNeeded();
            },
          ),
          Divider(height: 16, color: colors.border),
          _buildToggleRow(
            context,
            title: 'نمایش چرخه در تقویم و ریتم‌های روزانه',
            value: settings['show_cycle_in_calendar'] == 'true',
            onChanged: (v) async {
              final db = await DatabaseHelper.instance.database;
              await db.insert('app_settings', {
                'key': 'show_cycle_in_calendar',
                'value': v.toString(),
                'updatedAt': CycleClock.nowMillisecondsSinceEpoch,
              }, conflictAlgorithm: ConflictAlgorithm.replace);
              onDataReloadNeeded();
            },
          ),
          Divider(height: 16, color: colors.border),
          InkWell(
            onTap: onTogglePregnancyMode,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        settings['cycle_pregnancy_mode'] == 'true'
                            ? '🔄'
                            : '🤰',
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        settings['cycle_pregnancy_mode'] == 'true'
                            ? 'بازگشت به حالت عادی چرخه قاعدگی'
                            : 'فعالسازی حالت بارداری',
                        style: TextStyle(
                          fontSize: 14,
                          color: settings['cycle_pregnancy_mode'] == 'true'
                              ? colors.primary
                              : colors.textSecondary,
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
                '${PersianDigits.toFa(settings['cycle_avg_length'] ?? '28')} روز',
            onTap: () => onEditBaselineParameter(
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
                '${PersianDigits.toFa(settings['cycle_avg_period'] ?? '6')} روز',
            onTap: () => onEditBaselineParameter(
              'cycle_avg_period',
              'طول دوره قاعدگی',
              3,
              10,
              6,
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
