import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/ux/ritmo_snackbar.dart';
import 'package:ritmo/features/worship/domain/prayer_target.dart';
import 'package:ritmo/features/worship/logic/mafatih_weekly_acts.dart';
import 'package:ritmo/features/worship/logic/worship_calendar_logic.dart';
import 'package:ritmo/features/worship/logic/worship_completion_repository.dart';
import 'package:ritmo/features/worship/logic/worship_engine.dart';
import 'package:ritmo/features/worship/logic/worship_occasions_data.dart';
import 'package:ritmo/features/worship/models/worship_models.dart';
import 'package:ritmo/features/worship/presentation/widgets/fullscreen_tasbih_sheet.dart';
import 'package:ritmo/features/worship/presentation/widgets/prayer_sheet.dart';

class GroupStateResult {
  final bool isDone;
  final bool isSkipped;
  final bool isPartial;
  final bool isOverdue;
  final String statusText;
  final Color bgBadge;
  final Color textBadgeColor;
  final Color? borderColor;
  final IconData badgeIcon;

  const GroupStateResult({
    required this.isDone,
    required this.isSkipped,
    required this.isPartial,
    this.isOverdue = false,
    required this.statusText,
    required this.bgBadge,
    required this.textBadgeColor,
    this.borderColor,
    required this.badgeIcon,
  });
}

class WorshipDayDetailPanel extends StatefulWidget {
  const WorshipDayDetailPanel({
    super.key,
    required this.selectedDay,
    this.qamariNightText,
    this.onOpenTasbih,
    this.onChanged,
  });

  final WorshipCalendarDay selectedDay;

  /// Optional text for Qamari Night if local time is past Maghrib (e.g. "امشب: شب ۲۲ صفر")
  final String? qamariNightText;

  final VoidCallback? onOpenTasbih;
  final VoidCallback? onChanged;

  @override
  State<WorshipDayDetailPanel> createState() => _WorshipDayDetailPanelState();
}

class _WorshipDayDetailPanelState extends State<WorshipDayDetailPanel> {
  WorshipDay? _worshipDay;
  bool _isLoadingDay = true;
  List<WorshipPractice> _activeMustahabs = [];
  Map<String, WorshipDayStatus> _mustahabStatuses = {};

  static const List<String> weekdayNamesFa = [
    'دوشنبه',   // 1
    'سه‌شنبه',  // 2
    'چهارشنبه', // 3
    'پنج‌شنبه',  // 4
    'جمعه',     // 5
    'شنبه',     // 6
    'یکشنبه',   // 7
  ];

  @override
  void initState() {
    super.initState();
    _loadDayData();
  }

  @override
  void didUpdateWidget(WorshipDayDetailPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedDay.dateTime != widget.selectedDay.dateTime) {
      _loadDayData();
    }
  }

  Future<void> _loadDayData() async {
    try {
      final targetDate = widget.selectedDay.dateTime;
      final dayData = await WorshipEngine.instance.loadDay(targetDate);
      await _loadMustahabsData(targetDate);

      if (mounted) {
        setState(() {
          _worshipDay = dayData;
          _isLoadingDay = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingDay = false;
        });
      }
    }
  }

  Future<void> _loadMustahabsData(DateTime targetDate) async {
    try {
      final dateStr = targetDate.toIso8601String().substring(0, 10);
      final todayMustahabs = await WorshipEngine.instance.loadSpecificDayMustahabs(targetDate);

      final statuses = await WorshipCompletionRepository.instance.statusForDate(
        dateStr,
        practiceIds: todayMustahabs.map((p) => p.id).toList(),
      );

      _activeMustahabs = todayMustahabs;
      _mustahabStatuses = statuses;
    } catch (_) {}
  }

  String _getWeekdayName(int weekday) {
    return weekdayNamesFa[(weekday - 1) % 7];
  }

  DateTime? _deadlineForGroup(String pKey, PrayerTimes times) {
    switch (pKey.toUpperCase()) {
      case 'FAJR':
        return times.sunrise;
      case 'DHUHR_ASR':
      case 'DHUHR':
      case 'ASR':
        return times.sunset;
      case 'MAGHRIB_ISHA':
      case 'MAGHRIB':
      case 'ISHA':
        return times.midnightShari;
      default:
        return null;
    }
  }



  GroupStateResult _computeGroupState(
    String pKey,
    Map<String, WorshipPracticeState> practiceMap,
    bool isFuture,
    bool isToday,
    RitmoColors colors,
  ) {
    final List<WorshipPracticeState> members = [];
    if (pKey == 'DHUHR_ASR') {
      if (practiceMap.containsKey('DHUHR')) members.add(practiceMap['DHUHR']!);
      if (practiceMap.containsKey('ASR')) members.add(practiceMap['ASR']!);
    } else if (pKey == 'MAGHRIB_ISHA') {
      if (practiceMap.containsKey('MAGHRIB')) members.add(practiceMap['MAGHRIB']!);
      if (practiceMap.containsKey('ISHA')) members.add(practiceMap['ISHA']!);
    } else {
      final key = pKey == 'FAJR' ? 'FAJR' : pKey;
      if (practiceMap.containsKey(key)) members.add(practiceMap[key]!);
    }

    final now = DateTime.now();

    // Determine if the prayer deadline has passed
    bool isOverdue = false;
    if (!isFuture) {
      if (!isToday) {
        isOverdue = true;
      } else {
        final times = _worshipDay?.times;
        if (times != null) {
          final deadline = _deadlineForGroup(pKey, times);
          if (deadline != null && now.isAfter(deadline)) {
            isOverdue = true;
          }
        }
      }
    }

    final anyQada = members.any((m) => m.isQada || m.resultType == 'QADA_ADDED' || m.quality == 'QADA');
    final anyMissed = members.any((m) => m.resultType == 'MISSED');
    final allDone = members.isNotEmpty && members.every((m) => m.isDone);
    final anyDone = members.any((m) => m.isDone);
    final allSkipped = members.isNotEmpty && members.every((m) => m.isSkipped);

    // 1. Explicitly logged as Qada or Missed -> RED badge
    if (anyQada || anyMissed) {
      return GroupStateResult(
        isDone: false,
        isSkipped: false,
        isPartial: false,
        isOverdue: true,
        statusText: 'قضا شد',
        bgBadge: colors.error.withValues(alpha: 0.12),
        textBadgeColor: colors.error,
        borderColor: colors.error,
        badgeIcon: CupertinoIcons.xmark_circle_fill,
      );
    }

    // 2. Done -> Check Quality (ON_TIME => Green, IN_TIME => Yellow)
    if (allDone) {
      final isOnTime = members.any((m) =>
          m.quality == 'ON_TIME' ||
          m.quality == 'ONTIME' ||
          m.quality == 'EARLY');
      if (isOnTime) {
        return GroupStateResult(
          isDone: true,
          isSkipped: false,
          isPartial: false,
          statusText: 'اول وقت',
          bgBadge: colors.success.withValues(alpha: 0.12),
          textBadgeColor: colors.success,
          borderColor: colors.success.withValues(alpha: 0.4),
          badgeIcon: CupertinoIcons.checkmark_alt_circle_fill,
        );
      } else {
        return GroupStateResult(
          isDone: true,
          isSkipped: false,
          isPartial: false,
          statusText: 'در وقت مقرر',
          bgBadge: colors.warning.withValues(alpha: 0.12),
          textBadgeColor: colors.warning,
          borderColor: colors.warning.withValues(alpha: 0.4),
          badgeIcon: CupertinoIcons.checkmark_alt_circle_fill,
        );
      }
    } else if (anyDone && !allDone) {
      return GroupStateResult(
        isDone: false,
        isSkipped: false,
        isPartial: true,
        statusText: 'ناقص',
        bgBadge: colors.warning.withValues(alpha: 0.15),
        textBadgeColor: colors.warning,
        borderColor: colors.warning.withValues(alpha: 0.5),
        badgeIcon: CupertinoIcons.exclamationmark_circle_fill,
      );
    }

    // 3. Exemption (Period / Menstruation / Fiqh Exemption)
    final dayCtx = _worshipDay?.context;
    final isFullExempt = dayCtx?.prayerExempt == true;
    bool isGroupExempt = false;
    
    if (dayCtx != null) {
      if (isFullExempt) {
        isGroupExempt = true;
      } else {
        if (pKey == 'FAJR') {
          isGroupExempt = dayCtx.exemptPrayers.contains('FAJR');
        } else if (pKey == 'DHUHR_ASR') {
          isGroupExempt = dayCtx.exemptPrayers.contains('DHUHR') || dayCtx.exemptPrayers.contains('ASR');
        } else if (pKey == 'MAGHRIB_ISHA') {
          isGroupExempt = dayCtx.exemptPrayers.contains('MAGHRIB') || dayCtx.exemptPrayers.contains('ISHA');
        }
      }
    }

    if (isGroupExempt || allSkipped) {
      return GroupStateResult(
        isDone: false,
        isSkipped: true,
        isPartial: false,
        statusText: 'معافیت شرعی',
        bgBadge: colors.primary.withValues(alpha: 0.12),
        textBadgeColor: colors.primary,
        borderColor: colors.primary.withValues(alpha: 0.4),
        badgeIcon: CupertinoIcons.shield_lefthalf_fill,
      );
    }

    // 3. Overdue
    if (isOverdue) {
      return GroupStateResult(
        isDone: false,
        isSkipped: false,
        isPartial: false,
        isOverdue: true,
        statusText: isToday ? 'در انتظار' : 'ثبت‌نشده',
        bgBadge: colors.textPrimary.withValues(alpha: 0.05),
        textBadgeColor: colors.textSecondary,
        borderColor: colors.error,
        badgeIcon: CupertinoIcons.circle,
      );
    }

    // 4. Pending
    return GroupStateResult(
      isDone: false,
      isSkipped: false,
      isPartial: false,
      statusText: isFuture ? 'در انتظار' : 'در انتظار',
      bgBadge: colors.textPrimary.withValues(alpha: 0.05),
      textBadgeColor: isFuture ? colors.textTertiary : colors.textSecondary,
      borderColor: colors.textSecondary.withValues(alpha: 0.25),
      badgeIcon: isFuture ? CupertinoIcons.clock : CupertinoIcons.circle,
    );
  }

  int _parseZikrTargetCount(String zikrText) {
    final match = RegExp(r'\((\d+)\s*مرتبه\)').firstMatch(zikrText);
    if (match != null) {
      return int.tryParse(match.group(1)!) ?? 100;
    }
    return 100;
  }



  Future<void> _handleExplicitQada(String pKey) async {
    final colors = context.colors;
    final targetDate = widget.selectedDay.dateTime;
    final isFuture = targetDate.isAfter(DateTime.now());
    if (isFuture) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ثبت نماز قضا', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('آیا می‌خواهید این نماز به عنوان نماز قضاشده ثبت گردد؟', style: TextStyle()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('انصراف', style: TextStyle()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: colors.error),
            child: const Text('ثبت قضا', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final target = await PrayerTarget.fromGroupKey(pKey, targetDate);
      for (final id in target.practiceIds) {
        final res = await WorshipEngine.instance.logSkip(practiceId: id, date: targetDate, addToQada: true);
        if (res is WorshipLogBlocked && mounted) {
          RitmoSnackbar.warning(context, res.userMessage);
        } else if (res is WorshipLogFailed && mounted) {
          RitmoSnackbar.warning(context, res.error.toString());
        }
      }
      WorshipEngine.instance.invalidate();
      await _loadDayData();
      widget.onChanged?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final selectedDay = widget.selectedDay;
    final j = selectedDay.jalali;
    final h = selectedDay.hijri;
    final dt = selectedDay.dateTime;

    final weekdayName = _getWeekdayName(dt.weekday);
    final gMonthName = WorshipCalendarLogic.gregorianMonthNamesFa[dt.month];

    final fullDateText =
        '$weekdayName، ${toPersianDigits(j.day.toString())} ${selectedDay.jalali.formatter.mN} ${toPersianDigits(j.year.toString())}  •  ${toPersianDigits(dt.day.toString())} $gMonthName  •  ${h.formatted}';

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: Container(
        key: ValueKey('${j.year}-${j.month}-${j.day}'),
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          color: isDark
              ? colors.surface
              : colors.surface,
          border: Border.all(
            color: isDark
                ? colors.border
                : colors.border,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.28)
                  : colors.shadow.withValues(alpha: 0.08),
              blurRadius: 35,
              spreadRadius: 0,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Panel Header & Badges
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    CupertinoIcons.sparkles,
                    size: 18,
                    color: colors.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'اعمال و مناسبت‌های ${toPersianDigits(j.day.toString())} ${WorshipCalendarLogic.jalaliMonthNames[j.month - 1]}',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: colors.textPrimary,
                          ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        fullDateText,
                        style: TextStyle(
                          fontSize: 11,
                          color: colors.textSecondary,
                          ),
                      ),
                    ],
                  ),
                ),

                // Badges: Today / Qamari Night
                if (selectedDay.isToday) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: colors.primary.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      'امروز',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: colors.primary,
                        ),
                    ),
                  ),
                ],
              ],
            ),

            // Qamari Night Badge (if active for today after Maghrib)
            if (selectedDay.isToday && widget.qamariNightText != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: colors.surfaceElevated,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: colors.border.withValues(alpha: 0.5)),
                ),
                child: Row(
                  children: [
                    Icon(CupertinoIcons.moon_stars_fill, size: 14, color: colors.warning),
                    const SizedBox(width: 8),
                    Text(
                      widget.qamariNightText!,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                        ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),
            Divider(height: 1, color: colors.textPrimary.withValues(alpha: 0.08)),
            const SizedBox(height: 14),

            // 1. Occasions List (if today has occasions)
            if (selectedDay.hasOccasions) ...[
              ...selectedDay.occasions.map((occ) => _buildOccasionCard(context, colors, occ)),
              const SizedBox(height: 4),
            ],

            // 2. Obligatory Prayers Section
            _buildObligatoryPrayersCard(context, colors),

            // 3. Planned Mustahabat Rows (Rendered only if active for this day)
            if (_activeMustahabs.isNotEmpty) ...[
              const SizedBox(height: 14),
              ..._buildScheduledMustahabsRows(context, colors),
            ],

            const SizedBox(height: 14),

            // 4. Mafatih Recommendations Block (MAF-04)
            _buildMafatihRecommendationsCard(context, colors),

            const SizedBox(height: 14),

            // 5. Daily Zikr Section
            _buildDailyZikrCard(context, colors),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return '';
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return toPersianDigits('$h:$m');
  }

  Future<void> _handlePrayerTap(String pKey, GroupStateResult state) async {
    final targetDate = widget.selectedDay.dateTime;
    final isFuture = targetDate.isAfter(DateTime.now());

    if (isFuture) {
      RitmoSnackbar.warning(context, 'امکان ثبت نماز برای تاریخ‌های آینده وجود ندارد.');
      return;
    }

    if (state.statusText == 'معافیت شرعی' || state.isSkipped && state.statusText.contains('معاف')) {
      RitmoSnackbar.info(context, 'شما به دلیل چرخهٔ ماهانه (پریود) از این نماز معاف هستید.');
      return;
    }

    final target = await PrayerTarget.fromGroupKey(pKey, targetDate);

    if (state.isDone) {
      // Toggle back / clear log
      unawaited(HapticFeedback.mediumImpact());
      for (final id in target.practiceIds) {
        await WorshipEngine.instance.clearLog(practiceId: id, date: targetDate);
      }
      WorshipEngine.instance.invalidate();
      await _loadDayData();
      widget.onChanged?.call();
      return;
    }

    if (!mounted) return;
    final res = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => PrayerSheet(target: target),
    );

    if (res == true) {
      WorshipEngine.instance.invalidate();
      await _loadDayData();
      widget.onChanged?.call();
    }
  }

  Widget _buildObligatoryPrayersCard(BuildContext context, RitmoColors colors) {
    if (_worshipDay == null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.surfaceElevated.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.textPrimary.withValues(alpha: 0.06)),
        ),
        child: const Center(child: CupertinoActivityIndicator()),
      );
    }

    final day = _worshipDay!;
    final times = day.times;
    final dayCtx = day.context;
    final isExempt = dayCtx.prayerExempt;
    final now = DateTime.now();
    final isFuture = widget.selectedDay.dateTime.isAfter(now);
    final isToday = widget.selectedDay.isToday;

    // Build practice map for _computeGroupState
    final Map<String, WorshipPracticeState> practiceMap = {};
    for (final ps in day.practices) {
      final key = (ps.practice.subType ?? ps.practice.id).toUpperCase();
      practiceMap[key] = ps;
    }

    // Compute group states
    final fajrState = _computeGroupState('FAJR', practiceMap, isFuture, isToday, colors);
    final dhuhrState = _computeGroupState('DHUHR_ASR', practiceMap, isFuture, isToday, colors);
    final maghribState = _computeGroupState('MAGHRIB_ISHA', practiceMap, isFuture, isToday, colors);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceElevated.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.textPrimary.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(CupertinoIcons.checkmark_seal_fill, size: 15, color: colors.primary),
                  const SizedBox(width: 6),
                  Text(
                    'وضعیت نمازهای واجب این روز',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: colors.textPrimary,
                      ),
                  ),
                ],
              ),
              if (_isLoadingDay)
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2, color: colors.primary),
                ),
            ],
          ),

          if (isExempt) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: colors.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(CupertinoIcons.info_circle_fill, size: 13, color: colors.accent),
                  const SizedBox(width: 6),
                  Text(
                    'معافیت شرعی (پریود) اعمال شده است.',
                    style: TextStyle(fontSize: 11, color: colors.accent),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 10),

          // 3 Prayer Tiles Side By Side
          Row(
            children: [
              Expanded(
                child: _buildPrayerTile(
                  context, colors,
                  title: 'نماز صبح',
                  azanTime: _formatTime(times.fajr),
                  groupKey: 'FAJR',
                  state: fajrState,
                  isFuture: isFuture,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildPrayerTile(
                  context, colors,
                  title: 'نماز ظهر و عصر',
                  azanTime: _formatTime(times.dhuhr),
                  groupKey: 'DHUHR_ASR',
                  state: dhuhrState,
                  isFuture: isFuture,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildPrayerTile(
                  context, colors,
                  title: 'نماز مغرب و عشا',
                  azanTime: _formatTime(times.maghrib),
                  groupKey: 'MAGHRIB_ISHA',
                  state: maghribState,
                  isFuture: isFuture,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPrayerTile(
    BuildContext context,
    RitmoColors colors, {
    required String title,
    required String azanTime,
    required String groupKey,
    required GroupStateResult state,
    required bool isFuture,
  }) {
    return GestureDetector(
      onTap: () => _handlePrayerTap(groupKey, state),
      onLongPress: () {
        if (state.statusText == 'معافیت شرعی' || (state.isSkipped && state.statusText.contains('معاف'))) {
          RitmoSnackbar.info(context, 'شما به دلیل چرخهٔ ماهانه (پریود) از این نماز معاف هستید.');
          return;
        }
        _handleExplicitQada(groupKey);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: state.bgBadge,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: state.borderColor ?? colors.textSecondary.withValues(alpha: 0.15),
            width: 1.2,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: colors.textPrimary,
                decoration: state.isDone ? TextDecoration.lineThrough : null,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            // Azan Time
            Text(
              'اذان $azanTime',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 9.5,
                color: colors.textTertiary,
                ),
            ),
            const SizedBox(height: 8),
            // Status Icon
            Icon(
              state.badgeIcon,
              size: 26,
              color: state.textBadgeColor,
            ),
            const SizedBox(height: 4),
            // Status Text
            Text(
              state.statusText,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: state.textBadgeColor,
                ),
            ),
          ],
        ),
      ),
    );
  }


  ({IconData icon, Color color, Color bg}) _getMustahabVisuals(String title, RitmoColors colors) {
    if (title.contains('شب')) {
      return (
        icon: Icons.nightlight_round,
        color: colors.primary,
        bg: colors.primary.withValues(alpha: 0.12),
      );
    } else if (title.contains('نافله')) {
      if (title.contains('صبح')) {
        return (
          icon: Icons.wb_twilight_rounded,
          color: colors.warning,
          bg: colors.warning.withValues(alpha: 0.12),
        );
      } else if (title.contains('ظهر') || title.contains('عصر')) {
        return (
          icon: Icons.wb_sunny_rounded,
          color: colors.warning,
          bg: colors.warning.withValues(alpha: 0.12),
        );
      } else {
        return (
          icon: Icons.nights_stay_rounded,
          color: colors.primary,
          bg: colors.primary.withValues(alpha: 0.12),
        );
      }
    } else if (title.contains('عاشورا') || title.contains('زیارت')) {
      return (
        icon: Icons.auto_stories_rounded,
        color: colors.success,
        bg: colors.success.withValues(alpha: 0.12),
      );
    } else if (title.contains('عهد') || title.contains('دعا')) {
      return (
        icon: Icons.volunteer_activism_rounded,
        color: colors.accent,
        bg: colors.accent.withValues(alpha: 0.12),
      );
    } else if (title.contains('کمیل') || title.contains('ندبه')) {
      return (
        icon: Icons.favorite_rounded,
        color: colors.error,
        bg: colors.error.withValues(alpha: 0.12),
      );
    } else if (title.contains('جعفر')) {
      return (
        icon: Icons.mosque_rounded,
        color: colors.primary,
        bg: colors.primary.withValues(alpha: 0.12),
      );
    }
    return (
      icon: Icons.auto_awesome_rounded,
      color: colors.primary,
      bg: colors.primary.withValues(alpha: 0.12),
    );
  }

  List<Widget> _buildScheduledMustahabsRows(BuildContext context, RitmoColors colors) {
    final date = widget.selectedDay.dateTime;
    final isFuture = date.isAfter(DateTime.now());

    return _activeMustahabs.map((practice) {
      final status = _mustahabStatuses[practice.id];
      final isDone = status?.isDone == true;
      final isSkipped = status?.isSkipped == true;
      final visual = _getMustahabVisuals(practice.title, colors);

      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isDone
                ? colors.primary.withValues(alpha: 0.08)
                : colors.surfaceElevated.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDone
                  ? colors.primary.withValues(alpha: 0.25)
                  : colors.textPrimary.withValues(alpha: 0.06),
              width: isDone ? 1.2 : 1.0,
            ),
          ),
          child: Row(
            children: [
              // Icon container with spiritual visual
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDone
                      ? colors.primary.withValues(alpha: 0.18)
                      : visual.bg,
                ),
                child: Center(
                  child: Icon(
                    visual.icon,
                    size: 18,
                    color: isDone ? colors.primary : visual.color,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Title and details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      practice.title,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: isDone
                            ? colors.textSecondary.withValues(alpha: 0.7)
                            : (isSkipped
                                ? colors.textSecondary.withValues(alpha: 0.5)
                                : colors.textPrimary),
                        decoration: isDone ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    if (practice.notes != null && practice.notes!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        practice.notes!,
                        style: TextStyle(
                          fontSize: 11,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              if (practice.reminderEnabled) ...[
                Icon(Icons.alarm_rounded, size: 16, color: colors.textTertiary),
                const SizedBox(width: 8),
              ],

              // Checkbox button with accessible touch target
              InkWell(
                onTap: isFuture
                    ? null
                    : () async {
                        unawaited(HapticFeedback.selectionClick());
                        final sm = ScaffoldMessenger.of(context);
                        if (isDone) {
                          await WorshipEngine.instance.clearLog(practiceId: practice.id, date: date);
                        } else {
                          final res = await WorshipEngine.instance.logDone(practiceId: practice.id, date: date);
                          if (res is WorshipLogBlocked) {
                            sm.showSnackBar(SnackBar(content: Text(res.userMessage, style: const TextStyle())));
                          }
                        }
                        if (!mounted) return;
                        WorshipEngine.instance.invalidate();
                        await _loadDayData();
                        widget.onChanged?.call();
                      },
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDone ? colors.primary : Colors.transparent,
                      border: Border.all(
                        color: isDone ? colors.primary : colors.textSecondary.withValues(alpha: 0.4),
                        width: 1.8,
                      ),
                    ),
                    child: isDone
                        ? Icon(Icons.check_rounded, size: 16, color: colors.onPrimary)
                        : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  Widget _buildMafatihRecommendationsCard(BuildContext context, RitmoColors colors) {
    final dt = widget.selectedDay.dateTime;
    final weeklyActs = mafatihWeeklyActs[dt.weekday] ?? const <DailyAct>[];

    final seasons = _worshipDay?.seasons ?? const <WorshipSeason>[];
    final occasions = widget.selectedDay.occasions;

    final recommendations = <Map<String, String>>[];

    for (final act in weeklyActs) {
      if (act.title.startsWith('ذکر «')) continue;
      recommendations.add({
        'title': act.title,
        'note': act.note ?? 'اعمال روز هفته',
        'source': 'مفاتیح الجنان',
      });
    }

    for (final s in seasons) {
      if (s.recommendedAmal != null && s.recommendedAmal!.isNotEmpty) {
        recommendations.add({
          'title': s.title,
          'note': s.recommendedAmal!,
          'source': 'فصل عبادی',
        });
      }
    }

    for (final occ in occasions) {
      if (occ.recommendedAmal != null && occ.recommendedAmal!.isNotEmpty) {
        recommendations.add({
          'title': occ.title,
          'note': occ.recommendedAmal!,
          'source': 'مناسبت امروز',
        });
      }
    }

    if (recommendations.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.primary.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(CupertinoIcons.book_fill, size: 15, color: colors.primary),
              const SizedBox(width: 6),
              Text(
                'توصیه‌های امروز',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: colors.textPrimary,
                  ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          ...recommendations.map((rec) => Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(color: colors.primary, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            rec['title']!,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: colors.textPrimary,
                              ),
                          ),
                          Text(
                            rec['note']!,
                            style: TextStyle(
                              fontSize: 11,
                              color: colors.textSecondary,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildOccasionCard(BuildContext context, RitmoColors colors, WorshipOccasion occ) {
    IconData icon;
    Color iconColor;
    Color bgBadge;

    switch (occ.category) {
      case WorshipOccasionCategory.celebration:
        icon = CupertinoIcons.sparkles;
        iconColor = colors.success;
        bgBadge = colors.success.withValues(alpha: 0.1);
        break;
      case WorshipOccasionCategory.mourning:
        icon = CupertinoIcons.moon_fill;
        iconColor = colors.error;
        bgBadge = colors.error.withValues(alpha: 0.1);
        break;
      case WorshipOccasionCategory.fasting:
        icon = CupertinoIcons.sun_max_fill;
        iconColor = colors.warning;
        bgBadge = colors.warning.withValues(alpha: 0.1);
        break;
      case WorshipOccasionCategory.worshipDeed:
        icon = CupertinoIcons.book_fill;
        iconColor = colors.primary;
        bgBadge = colors.primary.withValues(alpha: 0.1);
        break;
      case WorshipOccasionCategory.national:
        icon = CupertinoIcons.flag_fill;
        iconColor = colors.accent;
        bgBadge = colors.accent.withValues(alpha: 0.08);
        break;
    }

    final displayTitle = occ.isHoliday ? '${occ.title} - تعطیل' : occ.title;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgBadge,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: iconColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              displayTitle,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: colors.textPrimary,
                ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildDailyZikrCard(BuildContext context, RitmoColors colors) {
    final targetCount = _parseZikrTargetCount(widget.selectedDay.dailyZikr);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colors.primary.withValues(alpha: 0.08),
            colors.primary.withValues(alpha: 0.03),
          ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(CupertinoIcons.circle_grid_hex_fill, size: 14, color: colors.primary),
                    const SizedBox(width: 6),
                    Text(
                      'ذکر روز هفته',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: colors.textPrimary,
                        ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  widget.selectedDay.dailyZikr,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colors.primary,
                    ),
                ),
              ],
            ),
          ),

          // Action Button: Start Zikr (Real Route)
          InkWell(
            onTap: () {
              FullscreenTasbihSheet.present(
                context,
                initialDhikrTitle: widget.selectedDay.dailyZikr.split('(').first.trim(),
                dhikrSubtitle: 'ذکر روز هفته',
                targetCount: targetCount,
                isFatimaTasbih: false,
              );
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: colors.primary,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: colors.primary.withValues(alpha: 0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Row(
                children: [
                  Icon(CupertinoIcons.play_arrow_solid, size: 12, color: Colors.white),
                  SizedBox(width: 4),
                  Text(
                    'شروع ذکر',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// شیت جزئیات کامل روز انتخاب‌شده از تقویم
class WorshipDayDetailSheet extends StatelessWidget {
  const WorshipDayDetailSheet({
    super.key,
    required this.selectedDay,
    this.qamariNightText,
    this.onOpenTasbih,
    this.onChanged,
  });

  final WorshipCalendarDay selectedDay;
  final String? qamariNightText;
  final VoidCallback? onOpenTasbih;
  final VoidCallback? onChanged;

  static Future<void> present(
    BuildContext context, {
    required WorshipCalendarDay selectedDay,
    String? qamariNightText,
    VoidCallback? onOpenTasbih,
    VoidCallback? onChanged,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => WorshipDayDetailSheet(
        selectedDay: selectedDay,
        qamariNightText: qamariNightText,
        onOpenTasbih: onOpenTasbih,
        onChanged: onChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          // Drag handle
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: colors.textSecondary.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 24),
              child: WorshipDayDetailPanel(
                selectedDay: selectedDay,
                qamariNightText: qamariNightText,
                onOpenTasbih: onOpenTasbih,
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
