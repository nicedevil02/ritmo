// =============================================================================
//  realm_dashboard_card.dart
//  کارت قلمروی جاری — بازنویسی UI با استایل نئومورفیک (Soft-UI)
//
//  • سازنده و پارامترهای قبلی دست‌نخورده‌اند (فقط height اختیاری اضافه شده)
//  • رنگ‌ها از پالت مشترک RealmNeu در realm_24h_dial.dart خوانده می‌شود
//  • تیکر یک‌ثانیه‌ای هم شمارنده و هم نقطهٔ زندهٔ روی دایال را همزمان می‌چرخاند
// =============================================================================

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ritmo/core/domain/realm/active_realm_resolver.dart';
import 'package:ritmo/core/repositories/realm_repository.dart';
import 'package:ritmo/core/utils/ritmo_color.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/today/presentation/widgets/dashboard/realm_24h_dial.dart';
import 'package:ritmo/features/today/presentation/widgets/dashboard/realm_24h_overview_sheet.dart';

Color _parseColorSafe(String? colorStr, Color fallback) {
  return RitmoColor.fromHex(colorStr, fallback: fallback);
}

/// کارت وضعیت قلمروی جاری مطابق طرح رفرنس نئومورفیک
class RealmDashboardCard extends StatefulWidget {
  const RealmDashboardCard({
    super.key,
    required this.isDarkMode,
    required this.realmState,
    required this.activeZone,
    required this.activeZoneName,
    required this.activeZoneIcon,
    required this.activeZoneColorHex,
    required this.activeZoneRoutinesCount,
    required this.activeZoneTimeRange,
    required this.onRealmChanged,
    this.schedules = const [],
    this.realms = const [],
    this.height = 180,
  });

  final bool isDarkMode;
  final ActiveRealmState realmState;
  final Map<String, dynamic>? activeZone;
  final String? activeZoneName;
  final String? activeZoneIcon;
  final String? activeZoneColorHex;
  final int activeZoneRoutinesCount;
  final String? activeZoneTimeRange;
  final VoidCallback onRealmChanged;
  final List<RealmScheduleData> schedules;
  final List<RealmData> realms;

  /// ارتفاع کارت (پیش‌فرض ۱۸۰ برای چیدمان بهینه و جمع‌وجور)
  final double height;

  @override
  State<RealmDashboardCard> createState() => _RealmDashboardCardState();
}

class _RealmDashboardCardState extends State<RealmDashboardCard> {
  Timer? _ticker;
  final ValueNotifier<DateTime> _nowNotifier = ValueNotifier(DateTime.now());
  final RealmRepository _repository = RealmRepository();

  @override
  void initState() {
    super.initState();
    // تیکر کم‌مصرف هر ۳۰ ثانیه ایزوله شده روی ValueNotifier بدون بار پردازشی
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      _nowNotifier.value = DateTime.now();
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _nowNotifier.dispose();
    super.dispose();
  }

  String _formatRemaining(ActiveRealmState state, DateTime now) {
    if (state is ScheduledRealmState) {
      final endParts = state.schedule.endTime.split(':');
      if (endParts.length >= 2) {
        final endH = int.tryParse(endParts[0]) ?? 0;
        final endM = int.tryParse(endParts[1]) ?? 0;
        var endDt = DateTime(now.year, now.month, now.day, endH, endM);
        if (endDt.isBefore(now)) {
          endDt = endDt.add(const Duration(days: 1));
        }
        final diff = endDt.difference(now);
        if (!diff.isNegative) {
          final h = diff.inHours.toString().padLeft(2, '0');
          final m = (diff.inMinutes % 60).toString().padLeft(2, '0');
          final s = (diff.inSeconds % 60).toString().padLeft(2, '0');
          return '$h:$m:$s';
        }
      }
    } else if (state is ManualRealmState) {
      final diff = state.expireAt.difference(now);
      if (!diff.isNegative) {
        final h = diff.inHours.toString().padLeft(2, '0');
        final m = (diff.inMinutes % 60).toString().padLeft(2, '0');
        final s = (diff.inSeconds % 60).toString().padLeft(2, '0');
        return '$h:$m:$s';
      }
    }

    // شمارش معکوس زنده در وضعیت زمان آزاد تا شروع قلمروی بعدی
    final next = ActiveRealmResolver.findNextSchedule(
      now,
      widget.realms,
      widget.schedules,
    );
    if (next != null) {
      final diff = next.scheduleStartDt.difference(now);
      if (!diff.isNegative) {
        final h = diff.inHours.toString().padLeft(2, '0');
        final m = (diff.inMinutes % 60).toString().padLeft(2, '0');
        final s = (diff.inSeconds % 60).toString().padLeft(2, '0');
        return '$h:$m:$s';
      }
    }

    // فالبک: شمارش معکوس تا پایان شبانه‌روز جاری
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);
    final diff = endOfDay.difference(now);
    if (!diff.isNegative) {
      final h = diff.inHours.toString().padLeft(2, '0');
      final m = (diff.inMinutes % 60).toString().padLeft(2, '0');
      final s = (diff.inSeconds % 60).toString().padLeft(2, '0');
      return '$h:$m:$s';
    }

    return '00:00:00';
  }

  String _getRealmSubtitle(String name) {
    if (name.contains('خواب') || name.contains('استراحت')) {
      return 'ذهنی آرام‌تر، فردایی بهتر';
    } else if (name.contains('کار') || name.contains('تمرکز')) {
      return 'بهره‌وری حداکثری و آرامش فکری';
    } else if (name.contains('ورزش') || name.contains('سلامت')) {
      return 'تندرستی و انرژی تجدیدپذیر';
    } else if (name.contains('مطالعه') || name.contains('درس')) {
      return 'یادگیری عمیق بدون حواس‌پرتی';
    }
    return 'هماهنگ با ریتم طبیعی شبانه‌روز';
  }

  /// بازهٔ زمانی قلمرو: اول از روی state، وگرنه از رشتهٔ activeZoneTimeRange
  _RealmTimeRange _resolveTimeRange() {
    final fromState = switch (widget.realmState) {
      ScheduledRealmState(:final schedule) => _RealmTimeRange(
          start: schedule.startTime,
          end: schedule.endTime,
        ),
      ManualRealmState(:final remaining) => _RealmTimeRange(
          label: 'دستی (${remaining.inMinutes} دقیقه)',
        ),
      TriggeredRealmState(:final explanation) =>
        _RealmTimeRange(label: explanation),
      FreeRealmState() => const _RealmTimeRange(label: 'زمان آزاد و شناور'),
      RealmErrorState() =>
        const _RealmTimeRange(label: 'بدون زمان‌بندی فعال'),
    };

    if (fromState.hasBounds) return fromState;

    final fallback = widget.activeZoneTimeRange;
    if (fallback != null && fallback.trim().isNotEmpty) {
      final matches = RegExp(r'\d{1,2}:\d{2}').allMatches(fallback).toList();
      if (matches.length >= 2) {
        return _RealmTimeRange(
          start: matches[0].group(0),
          end: matches[1].group(0),
        );
      }
      return _RealmTimeRange(label: fallback.trim());
    }

    return fromState;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final colors = context.colors;

    final isOutOfZone = switch (widget.realmState) {
      FreeRealmState() => true,
      ScheduledRealmState(:final isDefaultFallback, :final realm) =>
        isDefaultFallback && realm.id.isEmpty,
      ManualRealmState() => false,
      TriggeredRealmState() => false,
      RealmErrorState() => true,
    };

    final realmName = isOutOfZone
        ? 'زمان آزاد'
        : (widget.realmState.realmOrNull?.name ??
            widget.activeZoneName ??
            'خواب و ریکاوری');

    final chipName = isOutOfZone
        ? 'آزاد'
        : (widget.realmState.realmOrNull?.name ??
            widget.activeZoneName ??
            'خواب');

    final activeColor = _parseColorSafe(
      widget.activeZoneColorHex,
      RealmNeu.accent,
    );

    final currentMode = widget.realmState.realmOrNull?.mode ?? RealmMode.normal;
    final modeLabel = isOutOfZone ? 'شناور' : currentMode.label;

    final range = _resolveTimeRange();
    final subtitle = _getRealmSubtitle(realmName);

    final String iconStr = widget.activeZoneIcon ?? '🌙';
    final IconData icon = (iconStr.contains('کار') || iconStr.contains('💼'))
        ? CupertinoIcons.briefcase_fill
        : (iconStr.contains('ورزش') || iconStr.contains('🏃'))
            ? CupertinoIcons.sportscourt_fill
            : (iconStr.contains('درس') || iconStr.contains('📚'))
                ? CupertinoIcons.book_fill
                : (iconStr.contains('آزاد') || iconStr.contains('✨'))
                    ? CupertinoIcons.sparkles
                    : CupertinoIcons.moon_fill;

    final timeRangeStr = range.hasBounds
        ? '${toPersianDigits(range.start ?? '')}   ➔   ${toPersianDigits(range.end ?? '')}'
        : (range.label ?? 'زمان آزاد');

    final zoneId = widget.realmState.realmOrNull?.id ?? widget.activeZone?['id'] as String? ?? 'sleep';

    return ValueListenableBuilder<DateTime>(
      valueListenable: _nowNotifier,
      builder: (context, currentNow, _) {
        final remainingStr = _formatRemaining(widget.realmState, currentNow);
        return RitmoNeuMasterCard(
          title: realmName,
          subtitle: subtitle,
          modeLabel: modeLabel,
          onModeTap: isOutOfZone ? null : _openModeSelectionSheet,
          activeChipLabel: chipName,
          activeChipIcon: icon,
          activeChipEmoji: iconStr,
          statusLabel: isOutOfZone ? 'زمان آزاد' : 'قلمرو فعال',
          timeRange: timeRangeStr,
          remainingTime: toPersianDigits(remainingStr),
          activeColor: activeColor,
          gaugeWidget: Realm24hDial(
            size: 116,
            activeZoneId: zoneId,
            activeZoneColor: activeColor,
            activeZoneName: chipName,
            activeZoneIcon: widget.activeZoneIcon,
            schedules: widget.schedules,
            realms: widget.realms,
            isDarkMode: isDark,
            now: currentNow,
            surfaceColor: colors.surfaceElevated,
            surfaceSunkenColor: colors.surfaceSunken,
            textColor: colors.textPrimary,
            showHourLabels: false,
          ),
          actionButtonText: 'مدیریت قلمرو',
          onActionTap: _openManagementSheet,
          onTap: _openManagementSheet,
          height: widget.height,
        );
      },
    );
  }

  void _openManagementSheet() {
    final isOutOfZone = widget.realmState is FreeRealmState;
    final chipName = isOutOfZone
        ? 'آزاد'
        : (widget.realmState.realmOrNull?.name ??
            widget.activeZoneName ??
            'خواب');
    final activeColor = _parseColorSafe(
      widget.activeZoneColorHex,
      RealmNeu.accent,
    );
    _openEnlargedDialSheet(
      activeColor: activeColor,
      chipName: chipName,
      isOutOfZone: isOutOfZone,
    );
  }

  void _openModeSelectionSheet() {
    final realm = widget.realmState.realmOrNull;
    if (realm == null) return;

    HapticFeedback.mediumImpact();
    final colors = context.colors;
    final isDark = widget.isDarkMode;
    final activeColor = _parseColorSafe(widget.activeZoneColorHex, RealmNeu.accent);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: RitmoGlassSheet(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            padding: EdgeInsets.zero,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // دستگیره کشیدن شیت (Apple Style Handle Bar)
                    Center(
                      child: Container(
                        width: 38,
                        height: 4.5,
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: colors.textSecondary.withValues(alpha: isDark ? 0.30 : 0.22),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),

                    // ردیف هدر شیت با آیکون قلمرو و دکمه بستن
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: activeColor.withValues(alpha: isDark ? 0.20 : 0.12),
                            border: Border.all(
                              color: activeColor.withValues(alpha: isDark ? 0.35 : 0.20),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            widget.activeZoneIcon ?? realm.icon,
                            style: const TextStyle(fontSize: 20),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'حالت قلمرو «${realm.name}»',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  fontFamily: 'Vazirmatn',
                                  color: colors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'نحوه رفتار روتین‌ها و دریافت اعلان‌ها را تنظیم کنید',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontFamily: 'Vazirmatn',
                                  color: colors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => Navigator.of(sheetContext).pop(),
                          child: Container(
                            width: 32,
                            height: 32,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : Colors.black.withValues(alpha: 0.05),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              CupertinoIcons.xmark,
                              size: 15,
                              color: colors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // ۳ گزینه حالت مطابق استانداردهای مرجع اپل و ریتمو
                    _buildModeOptionItem(
                      context: sheetContext,
                      title: 'حالت عادی',
                      subtitle: 'همه روتین‌ها بدون محدودیت اجرا می‌شوند',
                      mode: RealmMode.normal,
                      isSelected: realm.mode == RealmMode.normal,
                      icon: CupertinoIcons.sparkles,
                      color: activeColor,
                      onSelect: () => _handleSelectMode(sheetContext, realm.id, RealmMode.normal),
                    ),
                    const SizedBox(height: 10),
                    _buildModeOptionItem(
                      context: sheetContext,
                      title: 'حالت تمرکز',
                      subtitle: 'فقط روتین‌های ضروری و حیاتی نمایش داده می‌شوند',
                      mode: RealmMode.focus,
                      isSelected: realm.mode == RealmMode.focus,
                      icon: CupertinoIcons.flame_fill,
                      color: activeColor,
                      onSelect: () => _handleSelectMode(sheetContext, realm.id, RealmMode.focus),
                    ),
                    const SizedBox(height: 10),
                    _buildModeOptionItem(
                      context: sheetContext,
                      title: 'حالت بی‌صدا',
                      subtitle: 'اعلان‌ها مسدود شده و محیط کاملاً آرام می‌شود',
                      mode: RealmMode.silent,
                      isSelected: realm.mode == RealmMode.silent,
                      icon: CupertinoIcons.bell_slash_fill,
                      color: activeColor,
                      onSelect: () => _handleSelectMode(sheetContext, realm.id, RealmMode.silent),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleSelectMode(BuildContext sheetContext, String realmId, RealmMode mode) async {
    Navigator.of(sheetContext).pop();
    await HapticFeedback.selectionClick();
    await _repository.updateRealmMode(realmId, mode);
    if (mounted) {
      widget.onRealmChanged();
    }
  }

  Widget _buildModeOptionItem({
    required BuildContext context,
    required String title,
    required String subtitle,
    required RealmMode mode,
    required bool isSelected,
    required IconData icon,
    required Color color,
    required VoidCallback onSelect,
  }) {
    final colors = context.colors;
    final isDark = widget.isDarkMode;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onSelect,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withValues(alpha: isDark ? 0.18 : 0.10)
                : (isDark ? colors.surfaceElevated.withValues(alpha: 0.60) : colors.surfaceElevated),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isSelected
                  ? color.withValues(alpha: isDark ? 0.65 : 0.45)
                  : (isDark ? colors.border.withValues(alpha: 0.22) : colors.divider),
              width: isSelected ? 1.4 : 1.0,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: isDark ? 0.25 : 0.12),
                      blurRadius: 12,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              // آیکون وضعیت در سمت راست (Leading در RTL)
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: isSelected
                      ? color.withValues(alpha: isDark ? 0.25 : 0.18)
                      : (isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : Colors.black.withValues(alpha: 0.04)),
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: isSelected ? color : colors.textSecondary,
                ),
              ),
              const SizedBox(width: 12),

              // متن عنوان و توضیح در مرکز
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                        fontFamily: 'Vazirmatn',
                        color: isSelected
                            ? (isDark ? Color.lerp(color, Colors.white, 0.75)! : Color.lerp(color, Colors.black, 0.30)!)
                            : colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        fontFamily: 'Vazirmatn',
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              // نشانگر انتخاب در سمت چپ (Trailing در RTL)
              if (isSelected)
                Icon(
                  CupertinoIcons.checkmark_alt_circle_fill,
                  size: 20,
                  color: color,
                )
              else
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: colors.textSecondary.withValues(alpha: 0.30),
                      width: 1.5,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _openEnlargedDialSheet({
    required Color activeColor,
    required String chipName,
    required bool isOutOfZone,
  }) {
    HapticFeedback.lightImpact();
    final isDark = widget.isDarkMode;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Realm24hOverviewSheet(
        isDarkMode: isDark,
        realmState: widget.realmState,
        activeZoneColor: activeColor,
        activeZoneName: chipName,
        activeZoneIcon: widget.realmState.realmOrNull?.icon ?? widget.activeZoneIcon,
        schedules: widget.schedules,
        realms: widget.realms,
        onChanged: widget.onRealmChanged,
      ),
    );
  }
}

/// بازهٔ زمانی قلمرو (یا متن جایگزین وقتی زمان‌بندی مشخص نیست)
class _RealmTimeRange {
  const _RealmTimeRange({this.start, this.end, this.label});

  final String? start;
  final String? end;
  final String? label;

  bool get hasBounds => start != null && end != null;
}
