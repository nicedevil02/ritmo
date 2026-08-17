// C-05, C-06, C-07, C-42: CycleRemindersScreen
// Null-safe settings, integrated with CycleLockGate, secure lock management, and localized Jalali display.
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/analytics/data_maturity_engine.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/domain/engines/hormonal_intelligence_engine.dart';
import 'package:ritmo/core/observability/ritmo_logger.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/ux/ritmo_directional_icon.dart';
import 'package:ritmo/features/cycle/logic/cycle_date_contract.dart';
import 'package:ritmo/features/cycle/logic/cycle_settings.dart';
import 'package:ritmo/features/cycle/presentation/widgets/cycle_lock_gate.dart';
import 'package:shamsi_date/shamsi_date.dart';

class CycleRemindersScreen extends StatefulWidget {
  const CycleRemindersScreen({super.key});

  @override
  State<CycleRemindersScreen> createState() => _CycleRemindersScreenState();
}

class _CycleRemindersScreenState extends State<CycleRemindersScreen> {
  bool _isLoading = true;
  HormonalEngineOutput? _output;
  List<Map<String, dynamic>> _cycleLogs = [];
  Map<String, String> _settings = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  String _formatJalali(DateTime dt) {
    final j = Jalali.fromDateTime(dt);
    return '${j.year}/${j.month.toString().padLeft(2, '0')}/${j.day.toString().padLeft(2, '0')}'.toPersianDigits();
  }

  Future<void> _loadData() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final settingsList = await db.query('app_settings');
      _settings = {
        for (final s in settingsList)
          if (s['key'] != null)
            s['key'].toString(): s['value']?.toString() ?? '',
      };

      _output = await HormonalIntelligenceEngine.evaluate(
        db: db,
        appSettings: _settings,
        now: DateTime.now(),
      );

      _cycleLogs = await DatabaseHelper.instance.getCycleLogs();
    } catch (e, st) {
      RitmoLogger.error(
        '[CycleRemindersScreen] failed to load data',
        error: e,
        stack: st,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: context.colors.background,
        body: Center(
          child: CircularProgressIndicator(color: context.colors.primary),
        ),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.background,
      body: CycleLockGate(
        child: Stack(
          children: [
            // Background Gradient (Theme-Aware)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [colors.background, colors.surface],
                  ),
                ),
              ),
            ),

            Positioned.fill(
              child: SafeArea(
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: Column(
                    children: [
                      // AppBar
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              icon: RitmoIcons.back(
                                context,
                                color: colors.textPrimary,
                              ),
                              onPressed: () => Navigator.pop(context),
                            ),
                            Text(
                              'یادآوری‌های چرخه بدن',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: colors.textPrimary,
                              ),
                            ),
                            Icon(
                              CupertinoIcons.lock_shield_fill,
                              color: colors.primary,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Private Unlocked Dashboard
                      Expanded(
                        child: _buildPrivateContentScreen(colors, isDark),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrivateContentScreen(RitmoColors colors, bool isDark) {
    final output = _output;
    final nextCycleDate = output?.nextCycleStartDate ?? DateTime.now();
    final jalali = Jalali.fromDateTime(nextCycleDate);
    final monthName = jalali.formatter.mN;
    final weekdayLabel = jalali.formatter.wN;
    final dateStr =
        '$weekdayLabel ${PersianDigits.toFa(jalali.day.toString())} $monthName';
    final daysToNext = nextCycleDate.difference(DateTime.now()).inDays;

    final hasEnoughData = DataMaturityEngine.hasEnoughDataForCyclePrediction(
      _cycleLogs.length,
    );

    final avgCycleLength = CycleSettings.getCycleLength(_settings);
    final avgPeriodDuration = CycleSettings.getPeriodDuration(_settings);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Next cycle prediction card
          RitmoTheme.glassCardLight(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    height: 52,
                    width: 52,
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      CupertinoIcons.calendar,
                      color: colors.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'پیش‌بینی زمان شروع دوره بعدی',
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          hasEnoughData ? dateStr : 'در حال شناخت ریتم شما',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          hasEnoughData
                              ? 'تقریباً در ${PersianDigits.toFa(daysToNext.toString())} روز آینده'
                              : 'نیاز به ثبت چرخه‌های بیشتر برای پیش‌بینی',
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Private Reminders List
          if (output != null && output.privateReminderQueue.isNotEmpty) ...[
            Text(
              'یادآوری‌های محرمانه',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            RitmoTheme.glassCardLight(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: output.privateReminderQueue.map((rem) {
                    final isT0 = rem.level == 'T0';
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isT0
                                  ? colors.primary
                                  : colors.textPrimary.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              rem.level,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isT0 ? Colors.white : colors.textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              rem.message,
                              style: TextStyle(
                                fontSize: 13,
                                color: colors.textPrimary,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Cycle trend history
          Text(
            'تحلیل الگوی چرخه بدنی',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          RitmoTheme.glassCardLight(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'میانگین طول چرخه: ${PersianDigits.toFa(avgCycleLength.toString())} روز',
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'طول دوره: ${PersianDigits.toFa(avgPeriodDuration.toString())} روز',
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  Text(
                    'تاریخچه‌ی دوره‌های ثبت شده:',
                    style: TextStyle(fontSize: 12, color: colors.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  if (_cycleLogs.isEmpty)
                    Text(
                      'تاکنون هیچ دوره‌ای ثبت نشده است. اطلاعات چرخه به مرور زمان و با ورود دوره‌ها در اینجا نمایش داده می‌شود.',
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.textSecondary,
                        height: 1.5,
                      ),
                    )
                  else
                    Column(
                      children: _cycleLogs.take(10).map((log) {
                        final rawStart =
                            (log['cycleStartDate'] ?? log['startDate'])
                                ?.toString();
                        final rawEnd =
                            (log['cycleEndDate'] ?? log['endDate'])?.toString();

                        final parsedStart =
                            CycleDateContract.parseDayKey(rawStart);
                        final parsedEnd = CycleDateContract.parseDayKey(rawEnd);

                        final startStr = parsedStart != null
                            ? _formatJalali(parsedStart)
                            : (rawStart ?? '-');
                        final endStr = parsedEnd != null
                            ? _formatJalali(parsedEnd)
                            : 'درحال انجام';

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'شروع: ${PersianDigits.toFa(startStr)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colors.textPrimary,
                                ),
                              ),
                              Text(
                                'پایان: ${PersianDigits.toFa(endStr)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Privacy Card
          RitmoTheme.glassCardLight(
            color: colors.success.withValues(alpha: isDark ? 0.08 : 0.04),
            border: Border.all(
              color: colors.success.withValues(alpha: 0.18),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        CupertinoIcons.checkmark_seal_fill,
                        color: colors.success,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'حریم خصوصی شما برای ما مهم است',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: colors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildPrivacyPoint(
                    'اطلاعات فقط روی دستگاه شما ذخیره می‌شود و کاملاً محلی است.',
                    colors,
                  ),
                  _buildPrivacyPoint(
                    'برای هیچ سرور یا سرویس خارجی ارسال نمی‌گردد.',
                    colors,
                  ),
                  _buildPrivacyPoint(
                    'صرفاً جهت بهبود و انطباق تجربه شخصی شما در ریتمو استفاده می‌شود.',
                    colors,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyPoint(String text, RitmoColors colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(CupertinoIcons.check_mark, color: colors.success, size: 14),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: colors.textPrimary.withValues(alpha: 0.8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
