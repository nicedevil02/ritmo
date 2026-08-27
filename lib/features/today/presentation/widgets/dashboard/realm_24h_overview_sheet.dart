// =============================================================================
//  realm_24h_overview_sheet.dart
//  پنجرهٔ پرمیوم و تعاملی نمای ۲۴ ساعته شبانه‌روز (Chronometer & Day Overview)
// =============================================================================

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ritmo/core/domain/realm/active_realm_resolver.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/today/presentation/widgets/dashboard/realm_24h_dial.dart';
import 'package:ritmo/features/today/presentation/widgets/realm_management_sheet.dart';

/// سگمنت زمانی گاه‌شمار شبانه‌روز برای نمایش در لیست و نوار توزیع
class _DayTimelineBlock {
  const _DayTimelineBlock({
    required this.startMinute,
    required this.endMinute,
    required this.realm,
    required this.schedule,
    required this.isFreeTime,
  });

  final int startMinute;
  final int endMinute;
  final RealmData? realm;
  final RealmScheduleData? schedule;
  final bool isFreeTime;

  int get durationMinutes {
    var dur = endMinute - startMinute;
    if (dur <= 0) dur += 1440;
    return dur;
  }

  String get durationLabel {
    final h = durationMinutes ~/ 60;
    final m = durationMinutes % 60;
    if (h > 0 && m > 0) {
      return '$h ساعت و $m دقیقه';
    } else if (h > 0) {
      return '$h ساعت';
    } else {
      return '$m دقیقه';
    }
  }

  String get timeRangeLabel {
    final startH = (startMinute ~/ 60).toString().padLeft(2, '0');
    final startM = (startMinute % 60).toString().padLeft(2, '0');
    final endH = ((endMinute % 1440) ~/ 60).toString().padLeft(2, '0');
    final endM = ((endMinute % 1440) % 60).toString().padLeft(2, '0');
    return '$startH:$startM تا $endH:$endM';
  }
}

class Realm24hOverviewSheet extends StatefulWidget {
  const Realm24hOverviewSheet({
    super.key,
    required this.isDarkMode,
    required this.realmState,
    required this.activeZoneColor,
    required this.activeZoneName,
    required this.activeZoneIcon,
    required this.schedules,
    required this.realms,
    required this.onChanged,
  });

  final bool isDarkMode;
  final ActiveRealmState realmState;
  final Color activeZoneColor;
  final String activeZoneName;
  final String? activeZoneIcon;
  final List<RealmScheduleData> schedules;
  final List<RealmData> realms;
  final VoidCallback onChanged;

  @override
  State<Realm24hOverviewSheet> createState() => _Realm24hOverviewSheetState();
}

class _Realm24hOverviewSheetState extends State<Realm24hOverviewSheet> {
  Timer? _ticker;
  DateTime _now = DateTime.now();
  late int _selectedWeekday; // 1: Mon ... 7: Sun
  int? _scrubbedMinute; // اگر کاربر ساعت را لمس و بررسی کند (۰ تا ۱۴۴۰)

  static const List<({String label, String fullLabel, int weekday})> _weekdays = [
    (label: 'ش', fullLabel: 'شنبه', weekday: 6),
    (label: 'ی', fullLabel: 'یکشنبه', weekday: 7),
    (label: 'د', fullLabel: 'دوشنبه', weekday: 1),
    (label: 'س', fullLabel: 'سه‌شنبه', weekday: 2),
    (label: 'چ', fullLabel: 'چهارشنبه', weekday: 3),
    (label: 'پ', fullLabel: 'پنج‌شنبه', weekday: 4),
    (label: 'ج', fullLabel: 'جمعه', weekday: 5),
  ];

  @override
  void initState() {
    super.initState();
    _selectedWeekday = _now.weekday;
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

  int _parseMinute(String timeStr) {
    final parts = timeStr.split(':');
    if (parts.length < 2) return 0;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    return (h * 60 + m) % 1440;
  }

  List<_DayTimelineBlock> _buildDayBlocks() {
    final daySchedules = widget.schedules
        .where((s) => s.isEnabled && s.daysOfWeek.contains(_selectedWeekday))
        .toList();

    if (daySchedules.isEmpty) {
      return [
        const _DayTimelineBlock(
          startMinute: 0,
          endMinute: 1440,
          realm: null,
          schedule: null,
          isFreeTime: true,
        ),
      ];
    }

    final rawSpans = <({int start, int end, RealmScheduleData schedule, RealmData realm})>[];

    for (final s in daySchedules) {
      final realm = widget.realms.firstWhere(
        (r) => r.id == s.zoneId,
        orElse: () => RealmData(
          id: s.zoneId,
          name: 'قلمرو',
          colorHex: '#6366F1',
          icon: '🎯',
          mode: RealmMode.normal,
        ),
      );

      final startMin = _parseMinute(s.startTime);
      var endMin = _parseMinute(s.endTime);
      if (endMin <= startMin) {
        endMin += 1440;
      }
      rawSpans.add((start: startMin, end: endMin, schedule: s, realm: realm));
    }

    rawSpans.sort((a, b) => a.start.compareTo(b.start));

    final result = <_DayTimelineBlock>[];
    var currentMin = 0;

    for (final span in rawSpans) {
      if (span.start > currentMin) {
        result.add(_DayTimelineBlock(
          startMinute: currentMin,
          endMinute: span.start,
          realm: null,
          schedule: null,
          isFreeTime: true,
        ));
      }
      result.add(_DayTimelineBlock(
        startMinute: span.start % 1440,
        endMinute: span.end % 1440 == 0 && span.end > 0 ? 1440 : span.end % 1440,
        realm: span.realm,
        schedule: span.schedule,
        isFreeTime: false,
      ));
      currentMin = span.end % 1440;
    }

    if (currentMin < 1440 && currentMin > 0) {
      result.add(_DayTimelineBlock(
        startMinute: currentMin,
        endMinute: 1440,
        realm: null,
        schedule: null,
        isFreeTime: true,
      ));
    }

    return result;
  }

  /// وضعیت و اطلاعات دقیق بر اساس دقیقه جاری یا کاوش‌شده
  ({String name, String icon, Color color, String mode, bool isFree, String timeStr}) _resolveMinuteStatus(int minute) {
    final blocks = _buildDayBlocks();
    final h = (minute ~/ 60).toString().padLeft(2, '0');
    final m = (minute % 60).toString().padLeft(2, '0');
    final timeStr = '$h:$m';

    for (final b in blocks) {
      final inBlock = b.endMinute > b.startMinute
          ? (minute >= b.startMinute && minute < b.endMinute)
          : (minute >= b.startMinute || minute < b.endMinute);

      if (inBlock) {
        if (b.isFreeTime || b.realm == null) {
          return (
            name: 'زمان آزاد و شناور',
            icon: '✨',
            color: const Color(0xFF94A3B8),
            mode: 'آزاد',
            isFree: true,
            timeStr: timeStr,
          );
        } else {
          return (
            name: b.realm!.name,
            icon: b.realm!.icon,
            color: b.realm!.parseColor(),
            mode: b.realm!.mode.label,
            isFree: false,
            timeStr: timeStr,
          );
        }
      }
    }

    return (
      name: 'زمان آزاد',
      icon: '✨',
      color: const Color(0xFF94A3B8),
      mode: 'آزاد',
      isFree: true,
      timeStr: timeStr,
    );
  }

  void _handleDialTouch(Offset localPos, Size dialSize) {
    final center = Offset(dialSize.width / 2, dialSize.height / 2);
    final dx = localPos.dx - center.dx;
    final dy = localPos.dy - center.dy;

    // Angle relative to 12 o'clock (minus pi/2)
    var angle = math.atan2(dy, dx) + (math.pi / 2);
    if (angle < 0) angle += 2 * math.pi;

    final minute = ((angle / (2 * math.pi)) * 1440).round() % 1440;
    if (_scrubbedMinute != minute) {
      setState(() {
        _scrubbedMinute = minute;
      });
      HapticFeedback.selectionClick();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final colors = context.colors;
    final activeNowMinute = _now.hour * 60 + _now.minute;
    final inspectMinute = _scrubbedMinute ?? activeNowMinute;
    final inspectStatus = _resolveMinuteStatus(inspectMinute);
    final isScrubbing = _scrubbedMinute != null;
    final blocks = _buildDayBlocks();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.90,
        ),
        decoration: BoxDecoration(
          gradient: RealmNeu.surfaceGradient(isDark),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.70 : 0.25),
              blurRadius: 30,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        child: Column(
          children: [
            // Top Drag Handle & Title
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
              child: Column(
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4.5,
                      decoration: BoxDecoration(
                        color: RealmNeu.muted(isDark).withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ساعت ۲۴ ساعته شبانه‌روز',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: RealmNeu.title(isDark),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'گاه‌شمار هوشمند، توازن زمان و قلمروها',
                            style: TextStyle(
                              fontSize: 11,
                              color: RealmNeu.muted(isDark),
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(CupertinoIcons.xmark_circle_fill, size: 24),
                        color: RealmNeu.muted(isDark),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            Divider(height: 1, color: colors.textPrimary.withValues(alpha: 0.08)),

            // Scrollable Content
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                children: [
                  // 1. Weekday Selector
                  _buildWeekdaySelector(isDark),

                  const SizedBox(height: 18),

                  // 2. Interactive 24h Chronometer Piece
                  _buildInteractiveDialSection(isDark, inspectStatus, isScrubbing, inspectMinute),

                  const SizedBox(height: 16),

                  // 3. 24-Hour Day Balance Bar (توزیع ساعات شبانه‌روز)
                  _buildDayBalanceSection(isDark, blocks),

                  const SizedBox(height: 20),

                  // 4. Chronological Day Timeline Stream
                  _buildTimelineStreamHeader(isDark),
                  const SizedBox(height: 10),
                  ...blocks.map((block) => _buildTimelineBlockCard(isDark, block, activeNowMinute)),

                  const SizedBox(height: 16),

                  // 5. Quick Management Button
                  _buildFooterActions(isDark),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeekdaySelector(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF141921).withValues(alpha: 0.6)
            : const Color(0xFFE2E8F0).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: _weekdays.map((item) {
          final isSelected = item.weekday == _selectedWeekday;
          final isToday = item.weekday == _now.weekday;

          return Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() {
                  _selectedWeekday = item.weekday;
                  _scrubbedMinute = null;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? RealmNeu.accent
                      : (isToday
                          ? RealmNeu.accent.withValues(alpha: 0.15)
                          : Colors.transparent),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: RealmNeu.accent.withValues(alpha: 0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  children: [
                    Text(
                      item.label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected || isToday ? FontWeight.w900 : FontWeight.w600,
                        color: isSelected
                            ? Colors.white
                            : (item.weekday == 5
                                ? const Color(0xFFEF4444)
                                : RealmNeu.title(isDark)),
                      ),
                    ),
                    if (isToday && !isSelected) ...[
                      const SizedBox(height: 2),
                      Container(
                        width: 4,
                        height: 4,
                        decoration: const BoxDecoration(
                          color: RealmNeu.accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildInteractiveDialSection(
    bool isDark,
    ({String name, String icon, Color color, String mode, bool isFree, String timeStr}) inspectStatus,
    bool isScrubbing,
    int inspectMinute,
  ) {
    const dialSize = 224.0;

    return Column(
      children: [
        // Interactive Touch Scrubber Dial
        Center(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (details) => _handleDialTouch(details.localPosition, const Size(dialSize, dialSize)),
            onPanUpdate: (details) => _handleDialTouch(details.localPosition, const Size(dialSize, dialSize)),
            onPanEnd: (_) {},
            onTapDown: (details) => _handleDialTouch(details.localPosition, const Size(dialSize, dialSize)),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Realm24hDial(
                  size: dialSize,
                  now: isScrubbing
                      ? DateTime(_now.year, _now.month, _now.day, inspectMinute ~/ 60, inspectMinute % 60)
                      : _now,
                  showHourLabels: true,
                  usePersianDigits: true,
                  activeZoneId: widget.realmState.realmOrNull?.id,
                  activeZoneColor: inspectStatus.color,
                  activeZoneIcon: inspectStatus.icon,
                  activeZoneName: inspectStatus.name,
                  schedules: widget.schedules
                      .where((s) => s.daysOfWeek.contains(_selectedWeekday))
                      .toList(),
                  realms: widget.realms,
                  isDarkMode: isDark,
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 14),

        // Live / Scrubber Status Pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF141921).withValues(alpha: 0.8)
                : Colors.white.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: inspectStatus.color.withValues(alpha: isDark ? 0.40 : 0.30),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: inspectStatus.color.withValues(alpha: isDark ? 0.20 : 0.10),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: inspectStatus.color.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Text(inspectStatus.icon, style: const TextStyle(fontSize: 18)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          isScrubbing ? 'کاوش ساعت: ${toPersianDigits(inspectStatus.timeStr)}' : 'اکنون (${toPersianDigits(inspectStatus.timeStr)})',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: RealmNeu.title(isDark),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: inspectStatus.color.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            inspectStatus.mode,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: inspectStatus.color,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      inspectStatus.name,
                      style: TextStyle(
                        fontSize: 11,
                        color: RealmNeu.muted(isDark),
                      ),
                    ),
                  ],
                ),
              ),
              if (isScrubbing) ...[
                TextButton.icon(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    setState(() => _scrubbedMinute = null);
                  },
                  icon: const Icon(CupertinoIcons.arrow_counterclockwise, size: 14),
                  label: const Text('اکنون', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  style: TextButton.styleFrom(
                    foregroundColor: RealmNeu.accent,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDayBalanceSection(bool isDark, List<_DayTimelineBlock> blocks) {
    // Calculate total minutes per realm
    final durationByRealm = <String, ({String name, Color color, String icon, int minutes})>{};

    for (final b in blocks) {
      final key = b.isFreeTime || b.realm == null ? 'free' : b.realm!.id;
      final name = b.isFreeTime || b.realm == null ? 'زمان آزاد' : b.realm!.name;
      final color = b.isFreeTime || b.realm == null ? const Color(0xFF94A3B8) : b.realm!.parseColor();
      final icon = b.isFreeTime || b.realm == null ? '✨' : b.realm!.icon;

      if (durationByRealm.containsKey(key)) {
        final prev = durationByRealm[key]!;
        durationByRealm[key] = (name: name, color: color, icon: icon, minutes: prev.minutes + b.durationMinutes);
      } else {
        durationByRealm[key] = (name: name, color: color, icon: icon, minutes: b.durationMinutes);
      }
    }

    final entries = durationByRealm.values.toList();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF141921).withValues(alpha: 0.5)
            : Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: RealmNeu.muted(isDark).withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'توازن و تقسیم ۲۴ ساعت شبانه‌روز',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: RealmNeu.title(isDark),
                ),
              ),
              Text(
                '۱۰۰٪ شبانه‌روز',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: RealmNeu.muted(isDark),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Multi-color distribution bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 14,
              child: Row(
                children: entries.map((e) {
                  final flex = math.max(1, e.minutes);
                  return Expanded(
                    flex: flex,
                    child: Container(
                      color: e.color,
                      margin: const EdgeInsets.symmetric(horizontal: 0.5),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          const SizedBox(height: 10),

          // Chips breakdown
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: entries.map((e) {
              final pct = ((e.minutes / 1440) * 100).round();
              final hours = (e.minutes / 60).toStringAsFixed(1);
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: e.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${e.name}: ${toPersianDigits('$pct٪')} (${toPersianDigits(hours)} ساعت)',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: RealmNeu.body(isDark),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineStreamHeader(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'گاه‌شمار شبانه‌روز (ترتیب زمانی)',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: RealmNeu.title(isDark),
          ),
        ),
        Text(
          '۲۴ ساعته',
          style: TextStyle(
            fontSize: 11,
            color: RealmNeu.muted(isDark),
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineBlockCard(bool isDark, _DayTimelineBlock block, int activeNowMinute) {
    final isCurrent = _selectedWeekday == _now.weekday &&
        (block.endMinute > block.startMinute
            ? (activeNowMinute >= block.startMinute && activeNowMinute < block.endMinute)
            : (activeNowMinute >= block.startMinute || activeNowMinute < block.endMinute));

    final isFree = block.isFreeTime || block.realm == null;
    final color = isFree ? const Color(0xFF94A3B8) : block.realm!.parseColor();
    final icon = isFree ? '✨' : block.realm!.icon;
    final name = isFree ? 'زمان آزاد و شناور' : block.realm!.name;
    final mode = isFree ? 'آزاد' : block.realm!.mode.label;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? (isCurrent
                ? color.withValues(alpha: 0.15)
                : const Color(0xFF141921).withValues(alpha: 0.4))
            : (isCurrent
                ? color.withValues(alpha: 0.10)
                : Colors.white.withValues(alpha: 0.7)),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCurrent
              ? color.withValues(alpha: 0.5)
              : RealmNeu.muted(isDark).withValues(alpha: 0.12),
          width: isCurrent ? 1.4 : 1.0,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: Text(icon, style: const TextStyle(fontSize: 18)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: RealmNeu.title(isDark),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        mode,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                    ),
                    if (isCurrent) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'در حال اجرا',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '${toPersianDigits(block.timeRangeLabel)} • (${toPersianDigits(block.durationLabel)})',
                  style: TextStyle(
                    fontSize: 11,
                    color: RealmNeu.muted(isDark),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterActions(bool isDark) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              showModalBottomSheet(
                context: context,
                backgroundColor: Colors.transparent,
                isScrollControlled: true,
                builder: (context) => RealmManagementSheet(
                  isDarkMode: isDark,
                  onChanged: widget.onChanged,
                ),
              );
            },
            icon: const Icon(CupertinoIcons.slider_horizontal_3, size: 16, color: Colors.white),
            label: const Text(
              'مدیریت و ویرایش قلمروها',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: RealmNeu.accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
          ),
        ),
      ],
    );
  }
}
