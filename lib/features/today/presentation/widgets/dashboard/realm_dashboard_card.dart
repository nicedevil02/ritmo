// =============================================================================
//  realm_dashboard_card.dart
//  کارت قلمروی جاری — بازنویسی UI با استایل نئومورفیک (Soft-UI)
//
//  • سازنده و پارامترهای قبلی دست‌نخورده‌اند (فقط height اختیاری اضافه شده)
//  • رنگ‌ها از پالت مشترک RealmNeu در realm_24h_dial.dart خوانده می‌شود
//  • تیکر یک‌ثانیه‌ای هم شمارنده و هم نقطهٔ زندهٔ روی دایال را همزمان می‌چرخاند
// =============================================================================

import 'dart:async';
import 'dart:math' as math;

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
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    // تیکر زنده هر ثانیه برای آپدیت ثانیه‌شمار باقی‌مانده و نقطهٔ زمان
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _now = DateTime.now();
        });
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String _formatRemaining(ActiveRealmState state) {
    if (state is ScheduledRealmState) {
      final now = _now;
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
      final diff = state.expireAt.difference(_now);
      if (!diff.isNegative) {
        final h = diff.inHours.toString().padLeft(2, '0');
        final m = (diff.inMinutes % 60).toString().padLeft(2, '0');
        final s = (diff.inSeconds % 60).toString().padLeft(2, '0');
        return '$h:$m:$s';
      }
    }

    // شمارش معکوس زنده در وضعیت زمان آزاد تا شروع قلمروی بعدی
    final next = ActiveRealmResolver.findNextSchedule(
      _now,
      widget.realms,
      widget.schedules,
    );
    if (next != null) {
      final diff = next.scheduleStartDt.difference(_now);
      if (!diff.isNegative) {
        final h = diff.inHours.toString().padLeft(2, '0');
        final m = (diff.inMinutes % 60).toString().padLeft(2, '0');
        final s = (diff.inSeconds % 60).toString().padLeft(2, '0');
        return '$h:$m:$s';
      }
    }

    // فالبک: شمارش معکوس تا پایان شبانه‌روز جاری
    final endOfDay = DateTime(_now.year, _now.month, _now.day, 23, 59, 59);
    final diff = endOfDay.difference(_now);
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

    final range = _resolveTimeRange();
    final remainingStr = _formatRemaining(widget.realmState);
    final subtitle = _getRealmSubtitle(realmName);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxW =
              constraints.maxWidth.isFinite ? constraints.maxWidth : 360.0;
          final dialSize =
              math.min(maxW * 0.40, widget.height - 62).clamp(88.0, 118.0);

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _openManagementSheet,
            child: Container(
              width: double.infinity,
              height: widget.height,
              padding: const EdgeInsets.fromLTRB(10, 8, 14, 8),
              decoration: BoxDecoration(
                color: colors.surfaceElevated,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF94A3B8).withValues(alpha: 0.14)
                      : colors.border,
                  width: 0.9,
                ),
                boxShadow: isDark
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.45),
                          offset: const Offset(0, 4),
                          blurRadius: 16,
                          spreadRadius: -2,
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.30),
                          offset: const Offset(0, 2),
                          blurRadius: 6,
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: const Color(0xFF64748B).withValues(alpha: 0.10),
                          offset: const Offset(0, 4),
                          blurRadius: 16,
                        ),
                        BoxShadow(
                          color: const Color(0xFF64748B).withValues(alpha: 0.06),
                          offset: const Offset(0, 2),
                          blurRadius: 6,
                        ),
                      ],
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              isDark
                                  ? const Color(0xFF94A3B8).withValues(alpha: 0.08)
                                  : Colors.white.withValues(alpha: 0.35),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.35],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildInfoColumn(
                          isDark: isDark,
                          realmName: realmName,
                          chipName: chipName,
                          subtitle: subtitle,
                          range: range,
                          remainingStr: remainingStr,
                          activeColor: activeColor,
                        ),
                      ),
                      const SizedBox(width: 10),
                      _buildDialAndActionColumn(
                        isDark: isDark,
                        dialSize: dialSize,
                        chipName: chipName,
                        activeColor: activeColor,
                        isOutOfZone: isOutOfZone,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
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

  void _openCountdownControlSheet(String realmName, Color activeColor) {
    RitmoHapticsPolicy.selection();
    final isDark = widget.isDarkMode;
    final colors = context.colors;
    final repo = RealmRepository();

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: RitmoGlassSheet(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: colors.textTertiary.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: activeColor.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: activeColor.withValues(alpha: 0.30),
                              width: 1.0,
                            ),
                          ),
                          child: Icon(CupertinoIcons.hourglass, color: activeColor, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'مدیریت زمان: $realmName',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: colors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'تمدید یا تغییر مدت زمان این قلمرو',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: colors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: Icon(
                            CupertinoIcons.xmark_circle_fill,
                            size: 22,
                            color: colors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'تمدید سریع مدت زمان قلمرو:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _buildQuickExtensionButton(
                          label: '+۱۵ دقیقه',
                          colors: colors,
                          isDark: isDark,
                          onTap: () async {
                            Navigator.pop(context);
                            final realmId = widget.realmState.realmOrNull?.id ??
                                widget.activeZone?['id'] as String? ??
                                'temp';
                            await repo.setManualOverride(realmId: realmId, durationMinutes: 15);
                            widget.onRealmChanged();
                          },
                        ),
                        const SizedBox(width: 8),
                        _buildQuickExtensionButton(
                          label: '+۳۰ دقیقه',
                          colors: colors,
                          isDark: isDark,
                          onTap: () async {
                            Navigator.pop(context);
                            final realmId = widget.realmState.realmOrNull?.id ??
                                widget.activeZone?['id'] as String? ??
                                'temp';
                            await repo.setManualOverride(realmId: realmId, durationMinutes: 30);
                            widget.onRealmChanged();
                          },
                        ),
                        const SizedBox(width: 8),
                        _buildQuickExtensionButton(
                          label: '+۱ ساعت',
                          colors: colors,
                          isDark: isDark,
                          onTap: () async {
                            Navigator.pop(context);
                            final realmId = widget.realmState.realmOrNull?.id ??
                                widget.activeZone?['id'] as String? ??
                                'temp';
                            await repo.setManualOverride(realmId: realmId, durationMinutes: 60);
                            widget.onRealmChanged();
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () async {
                            RitmoHapticsPolicy.selection();
                            Navigator.pop(context);
                            await repo.clearManualOverride();
                            widget.onRealmChanged();
                          },
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: colors.error.withValues(alpha: isDark ? 0.12 : 0.08),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: colors.error.withValues(alpha: isDark ? 0.35 : 0.45),
                                width: 1.2,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(CupertinoIcons.stop_circle, size: 18, color: colors.error),
                                const SizedBox(width: 8),
                                Text(
                                  'پایان زودهنگام و ورود به زمان آزاد',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                    color: colors.error,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuickExtensionButton({
    required String label,
    required RitmoColors colors,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            RitmoHapticsPolicy.selection();
            onTap();
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.textPrimary.withValues(alpha: isDark ? 0.06 : 0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? colors.border : colors.divider,
                width: 1.0,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: colors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openWhyThisRealmSheet({
    required String realmName,
    required Color activeColor,
    required _RealmTimeRange range,
  }) {
    RitmoHapticsPolicy.selection();
    final isDark = widget.isDarkMode;
    final colors = context.colors;
    final state = widget.realmState;

    final String reasonText;
    final String modeLabel;

    if (state is ScheduledRealmState) {
      reasonText = 'این قلمرو طبق جدول زمان‌بندی روزانه شما از ساعت ${range.start ?? ''} تا ${range.end ?? ''} فعال شده است.';
      modeLabel = state.realm.mode.label;
    } else if (state is ManualRealmState) {
      reasonText = 'این قلمرو به صورت دستی توسط شما فعال شده و تا پایان زمان تعیین‌شده ادامه خواهد داشت.';
      modeLabel = state.realm.mode.label;
    } else {
      reasonText = 'در حال حاضر هیچ قلمرویی زمان‌بندی نشده و در حالت زمان آزاد و شناور هستید.';
      modeLabel = 'آزاد';
    }

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: RitmoGlassSheet(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: colors.textTertiary.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: activeColor.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                            border: Border.all(color: activeColor.withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            widget.realmState.realmOrNull?.icon ?? widget.activeZoneIcon ?? '✨',
                            style: const TextStyle(fontSize: 22),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    realmName,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: colors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                    decoration: BoxDecoration(
                                      color: activeColor,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      modeLabel,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'وضعیت و قوانین قلمروی فعال',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: colors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: Icon(
                            CupertinoIcons.xmark_circle_fill,
                            size: 22,
                            color: colors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: colors.textPrimary.withValues(alpha: isDark ? 0.05 : 0.04),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? colors.border : colors.divider,
                          width: 1.0,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(CupertinoIcons.info_circle_fill, color: activeColor, size: 16),
                              const SizedBox(width: 6),
                              Text(
                                'چرا این قلمرو فعال است؟',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                  color: colors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            reasonText,
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.5,
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _openManagementSheet();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: activeColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text(
                          'مدیریت و ویرایش قلمروها',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDialAndActionColumn({
    required bool isDark,
    required double dialSize,
    required String chipName,
    required Color activeColor,
    required bool isOutOfZone,
  }) {
    final resolvedIcon = isOutOfZone
        ? '✨'
        : (widget.realmState.realmOrNull?.icon ?? widget.activeZoneIcon ?? '✨');

    return SizedBox(
      width: dialSize,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _NeuSpringBounceWrapper(
            onTap: () => _openEnlargedDialSheet(
              activeColor: activeColor,
              chipName: chipName,
              isOutOfZone: isOutOfZone,
            ),
            child: Realm24hDial(
              size: dialSize,
              now: _now,
              showHourLabels: false,
              activeZoneId: widget.realmState.realmOrNull?.id ??
                  widget.activeZone?['id'] as String?,
              activeZoneColor: activeColor,
              activeZoneIcon: resolvedIcon,
              activeZoneName: chipName,
              schedules: widget.schedules,
              realms: widget.realms,
              isDarkMode: isDark,
            ),
          ),
          const SizedBox(height: 4),
          _buildManageButton(isDark),
        ],
      ),
    );
  }

  Widget _buildInfoColumn({
    required bool isDark,
    required String realmName,
    required String chipName,
    required String subtitle,
    required _RealmTimeRange range,
    required String remainingStr,
    required Color activeColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _NeuSpringBounceWrapper(
          onTap: () => _openWhyThisRealmSheet(
            realmName: realmName,
            activeColor: activeColor,
            range: range,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: _NeuSurface(
                  isDark: isDark,
                  sunken: true,
                  radius: 14,
                  blur: 6,
                  distance: 2,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Text(
                    'قلمرو فعال',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: RealmNeu.muted(isDark),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: _ActiveRealmChip(
                  isDark: isDark,
                  label: chipName,
                  color: activeColor,
                  icon:
                      Realm24hDial.iconForRealm(chipName, widget.activeZoneIcon),
                ),
              ),
            ],
          ),
        ),
        Text(
          realmName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.3,
            height: 1.1,
            color: RealmNeu.title(isDark),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: RealmNeu.muted(isDark),
                ),
              ),
            ),
            if (widget.activeZoneRoutinesCount > 0) ...[
              const SizedBox(width: 4),
              _CountChip(isDark: isDark, count: widget.activeZoneRoutinesCount),
            ],
          ],
        ),
        _buildTimePill(isDark, range),
        _buildRemainingPill(isDark, remainingStr, activeColor, realmName),
      ],
    );
  }

  Widget _buildTimePill(bool isDark, _RealmTimeRange range) {
    final timeStyle = TextStyle(
      fontSize: 11.5,
      fontWeight: FontWeight.w800,
      color: RealmNeu.body(isDark),
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    final start = range.start;
    final end = range.end;
    final Widget content = (start != null && end != null)
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(toPersianDigits(start), style: timeStyle),
              const SizedBox(width: 5),
              _LtrIcon(
                CupertinoIcons.arrow_left,
                size: 11,
                color: RealmNeu.muted(isDark),
              ),
              const SizedBox(width: 5),
              Text(toPersianDigits(end), style: timeStyle),
            ],
          )
        : Text(
            toPersianDigits(range.label ?? '—'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: timeStyle.copyWith(fontSize: 11),
          );

    return _NeuSpringBounceWrapper(
      onTap: () {
        HapticFeedback.selectionClick();
      },
      child: _NeuSurface(
        isDark: isDark,
        height: 31,
        radius: 16,
        blur: 8,
        distance: 2.5,
        padding: const EdgeInsets.symmetric(horizontal: 4.5),
        child: Row(
          children: [
            _CircleBadge(isDark: isDark, icon: CupertinoIcons.time, size: 22),
            const SizedBox(width: 6),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: content,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRemainingPill(
    bool isDark,
    String remainingStr,
    Color activeColor,
    String realmName,
  ) {
    return _NeuSpringBounceWrapper(
      onTap: () => _openCountdownControlSheet(realmName, activeColor),
      child: _NeuSurface(
        isDark: isDark,
        height: 31,
        radius: 16,
        blur: 8,
        distance: 2.5,
        tint: RealmNeu.accentSoft(isDark),
        glowColor: activeColor,
        padding: const EdgeInsets.symmetric(horizontal: 4.5),
        child: Row(
          children: [
            _CircleBadge(
              isDark: isDark,
              icon: CupertinoIcons.hourglass,
              accent: true,
              size: 22,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'باقی‌مانده:',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: RealmNeu.accentText(isDark),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      toPersianDigits(remainingStr),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.3,
                        color: RealmNeu.accentText(isDark),
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManageButton(bool isDark) {
    return _NeuTapButton(
      isDark: isDark,
      height: 30,
      radius: 15,
      onTap: _openManagementSheet,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                'مدیریت قلمرو',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.88)
                      : const Color(0xFF475569),
                ),
              ),
            ),
            const SizedBox(width: 4),
            _LtrIcon(
              CupertinoIcons.chevron_left,
              size: 11,
              color: RealmNeu.muted(isDark),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
//  اجزای کوچک نئومورفیک
// =============================================================================

/// سطح نئومورفیک (برجسته / فرورفته / رنگی با هاله)
class _NeuSurface extends StatelessWidget {
  const _NeuSurface({
    required this.isDark,
    required this.child,
    this.height,
    this.radius = 16,
    this.padding = EdgeInsets.zero,
    this.tint,
    this.glowColor,
    this.sunken = false,
    this.blur = 10,
    this.distance = 3.5,
  });

  final bool isDark;
  final Widget child;
  final double? height;
  final double radius;
  final EdgeInsetsGeometry padding;
  final Color? tint;
  final Color? glowColor;
  final bool sunken;
  final double blur;
  final double distance;

  @override
  Widget build(BuildContext context) {
    final tintColor = tint;
    final glow = glowColor;

    return Container(
      height: height,
      padding: padding,
      alignment: height != null ? Alignment.center : null,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: tintColor == null
            ? RealmNeu.surfaceGradient(isDark)
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.lerp(tintColor, Colors.white, isDark ? 0.05 : 0.40)!,
                  tintColor,
                ],
              ),
        boxShadow: glow != null
            ? [
                BoxShadow(
                  color: glow.withValues(alpha: isDark ? 0.30 : 0.22),
                  blurRadius: blur + 4,
                  offset: Offset(0, distance),
                ),
                BoxShadow(
                  color: RealmNeu.shadowLight(isDark),
                  blurRadius: blur,
                  offset: Offset(-distance, -distance),
                ),
              ]
            : (sunken
                ? RealmNeu.sunken(isDark, blur: blur, distance: distance)
                : RealmNeu.raised(isDark, blur: blur, distance: distance)),
      ),
      child: child,
    );
  }
}

/// دکمهٔ نئومورفیک با انیمیشن فشردن (برجسته ← فرورفته)
class _NeuTapButton extends StatefulWidget {
  const _NeuTapButton({
    required this.isDark,
    required this.child,
    required this.onTap,
    this.height = 38,
    this.radius = 19,
  });

  final bool isDark;
  final Widget child;
  final VoidCallback onTap;
  final double height;
  final double radius;

  @override
  State<_NeuTapButton> createState() => _NeuTapButtonState();
}

class _NeuTapButtonState extends State<_NeuTapButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        curve: Curves.easeOut,
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.radius),
          gradient: _pressed
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [RealmNeu.base(isDark), RealmNeu.high(isDark)],
                )
              : RealmNeu.surfaceGradient(isDark),
          boxShadow: _pressed
              ? RealmNeu.sunken(isDark, blur: 7, distance: 2.5)
              : RealmNeu.raised(isDark, blur: 11, distance: 3.5),
        ),
        child: widget.child,
      ),
    );
  }
}

/// بج دایره‌ای کوچک برای آیکون داخل پیل‌ها
class _CircleBadge extends StatelessWidget {
  const _CircleBadge({
    required this.isDark,
    required this.icon,
    this.accent = false,
    this.size = 24,
  });

  final bool isDark;
  final IconData icon;
  final bool accent;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: accent
              ? const [RealmNeu.accentBright, RealmNeu.accentDeep]
              : [RealmNeu.high(isDark), RealmNeu.base(isDark)],
        ),
        boxShadow: [
          BoxShadow(
            color: accent
                ? RealmNeu.accent.withValues(alpha: 0.38)
                : RealmNeu.shadowDark(isDark),
            blurRadius: 6,
            offset: const Offset(1.5, 2),
          ),
          BoxShadow(
            color: RealmNeu.shadowLight(isDark),
            blurRadius: 5,
            offset: const Offset(-1.5, -1.5),
          ),
        ],
      ),
      child: _LtrIcon(
        icon,
        size: size * 0.54,
        color: accent ? Colors.white : RealmNeu.muted(isDark),
      ),
    );
  }
}

/// چیپ قلمروی فعال (پیل بنفش با آیکون دایره‌ای)
class _ActiveRealmChip extends StatelessWidget {
  const _ActiveRealmChip({
    required this.isDark,
    required this.label,
    required this.color,
    required this.icon,
  });

  final bool isDark;
  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(4, 4, 10, 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(
              RealmNeu.accentSoft(isDark),
              Colors.white,
              isDark ? 0.04 : 0.45,
            )!,
            RealmNeu.accentSoft(isDark),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: isDark ? 0.32 : 0.24),
            blurRadius: 9,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color.lerp(color, Colors.white, 0.30)!, color],
              ),
            ),
            child: _LtrIcon(icon, size: 11, color: Colors.white),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: RealmNeu.accentText(isDark),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// چیپ ریز تعداد روتین‌های قلمرو
class _CountChip extends StatelessWidget {
  const _CountChip({required this.isDark, required this.count});

  final bool isDark;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: RealmNeu.accentSoft(isDark),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        toPersianDigits('$count روتین'),
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          color: RealmNeu.accentText(isDark),
        ),
      ),
    );
  }
}

/// آیکونی که در چیدمان RTL آینه‌ای نمی‌شود
class _LtrIcon extends StatelessWidget {
  const _LtrIcon(this.icon, {required this.size, required this.color});

  final IconData icon;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Icon(icon, size: size, color: color),
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

/// ویجت انیمیشن فنری نئومورفیک (فشردن و جهش برگشتی با فیدبک لمسی)
class _NeuSpringBounceWrapper extends StatefulWidget {
  const _NeuSpringBounceWrapper({
    required this.child,
    this.onTap,
  });

  final Widget child;
  final VoidCallback? onTap;

  @override
  State<_NeuSpringBounceWrapper> createState() => _NeuSpringBounceWrapperState();
}

class _NeuSpringBounceWrapperState extends State<_NeuSpringBounceWrapper>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 220),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.94).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.elasticOut,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails _) {
    _controller.forward();
  }

  void _handleTapUp(TapUpDetails _) {
    _controller.reverse();
    widget.onTap?.call();
  }

  void _handleTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}
