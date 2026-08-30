// =============================================================================
//  realm_24h_overview_sheet.dart
//  پنجرهٔ پرمیوم و تعاملی نمای ۲۴ ساعته شبانه‌روز (Chronometer & Day Overview)
// =============================================================================

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/domain/realm/active_realm_resolver.dart';
import 'package:ritmo/core/repositories/realm_repository.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/ux/ritmo_sheet_scaffold.dart';
import 'package:ritmo/features/today/presentation/widgets/dashboard/realm_24h_dial.dart';
import 'package:ritmo/features/today/presentation/widgets/realm_edit_form_sheet.dart';

/// سگمنت زمانی گاه‌شمار شبانه‌روز برای نمایش در لیست و نوار توزیع
class _DayTimelineBlock {
  const _DayTimelineBlock({
    required this.startMinute,
    required this.endMinute,
    this.realm,
    this.schedule,
    this.isFreeTime = false,
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

class _Realm24hOverviewSheetState extends State<Realm24hOverviewSheet>
    with SingleTickerProviderStateMixin {
  final RealmRepository _repository = RealmRepository();
  late List<RealmData> _realms;
  late List<RealmScheduleData> _schedules;
  late ActiveRealmState _realmState;
  Map<String, int> _routineCounts = {};
  String? _suggestedBedtime;
  String? _suggestedWake;
  bool _showSleepSuggestion = false;
  bool _isSuggestionDismissed = false;

  late AnimationController _childSheetAnimController;
  Timer? _ticker;
  DateTime _now = DateTime.now();
  late int _selectedWeekday; // 1: Mon ... 7: Sun
  int? _scrubbedMinute; // اگر کاربر ساعت را لمس و بررسی کند (۰ تا ۱۴۴۰)
  bool _isDismissing = false;

  static const List<({String label, String fullLabel, int weekday})> _weekdays = [
    (label: 'ش', fullLabel: 'شنبه', weekday: 6),
    (label: 'ی', fullLabel: 'یک‌شنبه', weekday: 7),
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
    _childSheetAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
      reverseDuration: const Duration(milliseconds: 300),
    );
    _realms = List.from(widget.realms);
    _schedules = List.from(widget.schedules);
    _realmState = widget.realmState;
    _loadData();
    _ticker = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) {
        final newNow = DateTime.now();
        if (newNow.minute != _now.minute) {
          setState(() {
            _now = newNow;
          });
        }
      }
    });
  }

  Future<void> _loadData() async {
    try {
      final realms = await _repository.loadRealms();
      final schedules = await _repository.loadSchedules();
      final routineCounts = await _repository.loadRoutineCountsPerRealm();
      final activeState = await _repository.getActiveRealmState();

      final db = await DatabaseHelper.instance.database;
      final sleepSettings = await db.query(
        'app_settings',
        where: "key IN ('sleep_target_bedtime', 'sleep_target_wake')",
      );
      String? bedtime;
      String? wake;
      for (final r in sleepSettings) {
        final k = r['key'] as String?;
        final v = r['value'] as String?;
        if (k == 'sleep_target_bedtime') bedtime = v;
        if (k == 'sleep_target_wake') wake = v;
      }

      final hasSleepRealm = realms.any((r) =>
          r.name.contains('خواب') ||
          r.name.contains('استراحت') ||
          r.icon.contains('🌙') ||
          r.icon.contains('😴'));

      final showSuggestion = bedtime != null &&
          wake != null &&
          bedtime.trim().isNotEmpty &&
          wake.trim().isNotEmpty &&
          !hasSleepRealm &&
          !_isSuggestionDismissed;

      if (mounted) {
        setState(() {
          _realms = realms;
          _schedules = schedules;
          _routineCounts = routineCounts;
          _realmState = activeState;
          _suggestedBedtime = bedtime;
          _suggestedWake = wake;
          _showSleepSuggestion = showSuggestion;
        });
      }
    } catch (_) {}
  }

  void _openCreateSheet({int? defaultStartMinute, int? defaultEndMinute}) {
    HapticFeedback.selectionClick();

    List<RealmScheduleData>? initialSchedules;
    if (defaultStartMinute != null && defaultEndMinute != null) {
      final startH = (defaultStartMinute ~/ 60).toString().padLeft(2, '0');
      final startM = (defaultStartMinute % 60).toString().padLeft(2, '0');
      final endH = ((defaultEndMinute % 1440) ~/ 60).toString().padLeft(2, '0');
      final endM = ((defaultEndMinute % 1440) % 60).toString().padLeft(2, '0');

      initialSchedules = [
        RealmScheduleData(
          id: 'sched_${DateTime.now().millisecondsSinceEpoch}',
          zoneId: '',
          daysOfWeek: {_selectedWeekday},
          startTime: '$startH:$startM',
          endTime: '$endH:$endM',
          createdAt: DateTime.now().millisecondsSinceEpoch,
        ),
      ];
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      transitionAnimationController: _childSheetAnimController,
      builder: (_) => RealmEditFormSheet(
        initialSchedules: initialSchedules,
        onSave: (realm, schedules) async {
          await _repository.saveRealm(realm, schedules);
          await _loadData();
          widget.onChanged();
        },
      ),
    );
  }

  void _openEditSheet(RealmData realm) {
    HapticFeedback.selectionClick();
    final realmSchedules = _schedules.where((s) => s.zoneId == realm.id).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      transitionAnimationController: _childSheetAnimController,
      builder: (_) => RealmEditFormSheet(
        initialRealm: realm,
        initialSchedules: realmSchedules,
        onSave: (savedRealm, savedSchedules) async {
          await _repository.saveRealm(savedRealm, savedSchedules);
          await _loadData();
          widget.onChanged();
        },
      ),
    );
  }

  void _confirmDeleteRealm(RealmData realm) async {
    RitmoHaptics.tap();
    if (!mounted) return;
    final connectedCount = _routineCounts[realm.id] ?? 0;

    final confirm = await RitmoGlassDialog.show(
      context,
      title: 'حذف قلمرو «${realm.name}»',
      content: connectedCount > 0
          ? 'این قلمرو به $connectedCount روتین متصل است. با حذف آن، روتین‌ها به زمان آزاد منتقل می‌شوند. آیا مطمئنید؟'
          : 'آیا از حذف این قلمرو اطمینان دارید؟ تمام زمان‌بندی‌های آن حذف خواهند شد.',
      confirmLabel: 'حذف قلمرو',
      cancelLabel: 'انصراف',
      isDestructive: true,
      icon: CupertinoIcons.trash_fill,
    );

    if (confirm == true) {
      await _repository.deleteRealmTransactional(realm.id);
      await _loadData();
      widget.onChanged();
    }
  }

  void _showRealmActionsMenu(RealmData realm) {
    RitmoHaptics.selection();
    final colors = context.colors;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: RitmoGlassSheet(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(realm.icon, style: const TextStyle(fontSize: 22)),
                      const SizedBox(width: 8),
                      Text(
                        realm.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: colors.textPrimary,
                          fontFamily: 'Vazirmatn',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  RitmoCard.neumorphic(
                    onTap: () {
                      Navigator.pop(ctx);
                      _openEditSheet(realm);
                    },
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(
                      children: [
                        Icon(CupertinoIcons.pencil, color: colors.primary, size: 20),
                        const SizedBox(width: 12),
                        Text(
                          'ویرایش و زمان‌بندی قلمرو',
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Vazirmatn',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  RitmoCard.neumorphic(
                    onTap: () {
                      Navigator.pop(ctx);
                      _openManualActivationSheet(realm);
                    },
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(
                      children: [
                        const Icon(CupertinoIcons.timer, color: Color(0xFF10B981), size: 20),
                        const SizedBox(width: 12),
                        Text(
                          'فعال‌سازی دستی (تایمر فوری)',
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Vazirmatn',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  RitmoCard.neumorphic(
                    onTap: () {
                      Navigator.pop(ctx);
                      _confirmDeleteRealm(realm);
                    },
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: const Row(
                      children: [
                        Icon(CupertinoIcons.trash, color: Colors.redAccent, size: 20),
                        SizedBox(width: 12),
                        Text(
                          'حذف قلمرو',
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Vazirmatn',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _openManualActivationSheet(RealmData realm) {
    final colors = context.colors;
    final isDark = context.isDark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colors.surfaceElevated,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(color: isDark ? colors.border : colors.divider),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'فعال‌سازی دستی قلمرو «${realm.name}»',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'این قلمرو بدون توجه به زمان‌بندی هفتگی فعال خواهد شد:',
                  style: TextStyle(fontSize: 12, color: colors.textSecondary),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(CupertinoIcons.timer, color: Color(0xFF3B82F6)),
                  title: const Text('۲۵ دقیقه (تمرکز پومودورو)', style: TextStyle(fontSize: 14)),
                  onTap: () => _activateManualOverride(realm.id, 25),
                ),
                ListTile(
                  leading: const Icon(CupertinoIcons.timer, color: Color(0xFF8B5CF6)),
                  title: const Text('۵۰ دقیقه (یک پومودورو کامل)', style: TextStyle(fontSize: 14)),
                  onTap: () => _activateManualOverride(realm.id, 50),
                ),
                ListTile(
                  leading: const Icon(CupertinoIcons.timer, color: Color(0xFFEC4899)),
                  title: const Text('۹۰ دقیقه (جلسه عمیق)', style: TextStyle(fontSize: 14)),
                  onTap: () => _activateManualOverride(realm.id, 90),
                ),
                ListTile(
                  leading: const Icon(CupertinoIcons.moon_stars_fill, color: Color(0xFFFFD700)),
                  title: const Text('تا پایان امروز', style: TextStyle(fontSize: 14)),
                  onTap: () {
                    final now = DateTime.now();
                    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);
                    final diffMin = endOfDay.difference(now).inMinutes;
                    _activateManualOverride(realm.id, diffMin > 0 ? diffMin : 60);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _activateManualOverride(String realmId, int minutes) async {
    Navigator.pop(context);
    await _repository.setManualOverride(realmId: realmId, durationMinutes: minutes);
    await _loadData();
    widget.onChanged();
  }

  Future<void> _quickAddSleepRealm() async {
    if (_suggestedBedtime == null || _suggestedWake == null) return;
    final realmId = 'sleep_${DateTime.now().millisecondsSinceEpoch}';
    final realm = RealmData(
      id: realmId,
      name: 'خواب و ریکاوری',
      colorHex: '#6366F1',
      icon: '🌙',
      mode: RealmMode.silent,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    final schedule = RealmScheduleData(
      id: 'sched_${DateTime.now().millisecondsSinceEpoch}',
      zoneId: realmId,
      daysOfWeek: const {1, 2, 3, 4, 5, 6, 7},
      startTime: _suggestedBedtime!,
      endTime: _suggestedWake!,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    await _repository.saveRealm(realm, [schedule]);
    await _loadData();
    widget.onChanged();
  }

  Widget _buildSleepSuggestionCard(bool isDark, RitmoColors colors) {
    if (!_showSleepSuggestion || _suggestedBedtime == null || _suggestedWake == null) {
      return const SizedBox.shrink();
    }
    final bedtime = _suggestedBedtime!;
    final wake = _suggestedWake!;
    final accentColor = colors.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: accentColor.withValues(alpha: isDark ? 0.45 : 0.30),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.20),
                  shape: BoxShape.circle,
                ),
                child: const Text('🌙', style: TextStyle(fontSize: 16)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'پیشنهاد هوشمند: ساخت قلمرو خواب',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: colors.textPrimary,
                      ),
                    ),
                    Text(
                      'بر اساس برنامه خواب (${toPersianDigits(bedtime)} تا ${toPersianDigits(wake)})',
                      style: TextStyle(
                        fontSize: 11,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: () => setState(() => _isSuggestionDismissed = true),
                child: Icon(CupertinoIcons.xmark, size: 16, color: colors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => setState(() => _isSuggestionDismissed = true),
                child: Text('بعداً', style: TextStyle(fontSize: 11, color: colors.textSecondary)),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _quickAddSleepRealm,
                icon: const Icon(CupertinoIcons.check_mark, size: 13),
                label: const Text('ثبت سریع قلمرو خواب', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                style: FilledButton.styleFrom(
                  backgroundColor: accentColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _childSheetAnimController.dispose();
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

  bool _isMinuteInBlock(int minute, _DayTimelineBlock block) {
    if (block.startMinute == block.endMinute) {
      return true; // covers all 24 hours
    }
    if (block.startMinute < block.endMinute) {
      return minute >= block.startMinute && minute < block.endMinute;
    } else {
      // Crosses midnight (e.g. start: 1350, end: 330)
      return minute >= block.startMinute || minute < block.endMinute;
    }
  }

  List<_DayTimelineBlock> _buildDayBlocks() {
    final daySchedules = _schedules
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

    // 1. Build a 1440-minute grid
    final minuteGrid = List<({RealmData? realm, RealmScheduleData? schedule})?>.filled(1440, null);

    for (final s in daySchedules) {
      final realm = _realms.firstWhere(
        (r) => r.id == s.zoneId,
        orElse: () => RealmData(
          id: s.zoneId,
          name: 'قلمرو',
          colorHex: '#6366F1',
          icon: '🎯',
          mode: RealmMode.normal,
        ),
      );

      final start = _parseMinute(s.startTime);
      final end = _parseMinute(s.endTime);

      if (start < end) {
        for (var m = start; m < end; m++) {
          minuteGrid[m] = (realm: realm, schedule: s);
        }
      } else {
        for (var m = start; m < 1440; m++) {
          minuteGrid[m] = (realm: realm, schedule: s);
        }
        for (var m = 0; m < end; m++) {
          minuteGrid[m] = (realm: realm, schedule: s);
        }
      }
    }

    // 2. Check if the entire 24h is uniform
    final first = minuteGrid[0];
    var isAllSame = true;
    for (var i = 1; i < 1440; i++) {
      if (minuteGrid[i]?.schedule?.id != first?.schedule?.id) {
        isAllSame = false;
        break;
      }
    }
    if (isAllSame) {
      return [
        _DayTimelineBlock(
          startMinute: 0,
          endMinute: 1440,
          realm: first?.realm,
          schedule: first?.schedule,
          isFreeTime: first == null,
        ),
      ];
    }

    // 3. Find first transition cut point along the 1440-minute loop
    var startIdx = 0;
    for (var i = 0; i < 1440; i++) {
      final curr = minuteGrid[i];
      final prev = minuteGrid[(i - 1 + 1440) % 1440];
      if (curr?.schedule?.id != prev?.schedule?.id) {
        startIdx = i;
        break;
      }
    }

    final blocks = <_DayTimelineBlock>[];
    var segStart = startIdx;
    var currentEntity = minuteGrid[startIdx];

    for (var count = 1; count <= 1440; count++) {
      final idx = (startIdx + count) % 1440;
      final entity = count == 1440 ? null : minuteGrid[idx];

      final isSameEntity = count < 1440 && entity?.schedule?.id == currentEntity?.schedule?.id;

      if (!isSameEntity) {
        final segEnd = (startIdx + count) % 1440;
        blocks.add(_DayTimelineBlock(
          startMinute: segStart,
          endMinute: segEnd,
          realm: currentEntity?.realm,
          schedule: currentEntity?.schedule,
          isFreeTime: currentEntity == null,
        ));

        segStart = segEnd;
        currentEntity = entity;
      }
    }

    return blocks;
  }

  /// وضعیت و اطلاعات دقیق بر اساس دقیقه جاری یا کاوش‌شده
  ({String name, String icon, Color color, String mode, bool isFree, String timeStr}) _resolveMinuteStatus(int minute) {
    final blocks = _buildDayBlocks();
    final h = (minute ~/ 60).toString().padLeft(2, '0');
    final m = (minute % 60).toString().padLeft(2, '0');
    final timeStr = '$h:$m';

    for (final b in blocks) {
      if (_isMinuteInBlock(minute, b)) {
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
    final colors = context.colors;
    final isDark = context.isDark;
    final isGlass = context.isGlassEnabled;
    final activeNowMinute = _now.hour * 60 + _now.minute;
    final inspectMinute = _scrubbedMinute ?? activeNowMinute;
    final inspectStatus = _resolveMinuteStatus(inspectMinute);
    final isScrubbing = _scrubbedMinute != null;
    final blocks = _buildDayBlocks();

    const sheetRadius = BorderRadius.vertical(top: Radius.circular(32));

    final sheetContent = Column(
      children: [
        // Top Drag Handle & Title (Swipe down to dismiss)
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onVerticalDragEnd: (details) {
            if (details.primaryVelocity != null && details.primaryVelocity! > 250 && !_isDismissing) {
              _isDismissing = true;
              Navigator.of(context).pop();
            }
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
            child: Column(
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4.5,
                    decoration: BoxDecoration(
                      color: colors.textTertiary.withValues(alpha: 0.35),
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
                          'گاه‌شمار شبانه‌روز',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'نمای ۲۴ ساعته، توازن زمان و جریان قلمروها',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontFamily: 'Vazirmatn',
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(CupertinoIcons.xmark_circle_fill, size: 24),
                      color: colors.textSecondary,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        Divider(height: 1, color: colors.divider),

        // Scrollable Content with Apple HIG Pull-to-Dismiss at Top Edge
        Expanded(
          child: NotificationListener<ScrollNotification>(
            onNotification: (scrollInfo) {
              if (_isDismissing) return false;
              if (scrollInfo is ScrollEndNotification &&
                  scrollInfo.metrics.pixels < -30) {
                _isDismissing = true;
                Navigator.of(context).pop();
                return true;
              }
              if (scrollInfo is OverscrollNotification &&
                  scrollInfo.overscroll < -12 &&
                  scrollInfo.velocity < -200) {
                _isDismissing = true;
                Navigator.of(context).pop();
                return true;
              }
              return false;
            },
            child: ListView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
              children: [
                // 1. Weekday Selector
                _buildWeekdaySelector(isDark, colors, isGlass),

                const SizedBox(height: 18),

                // 2. Interactive 24h Chronometer Piece
                _buildInteractiveDialSection(
                  isDark,
                  colors,
                  isGlass,
                  inspectStatus,
                  isScrubbing,
                  inspectMinute,
                ),

                const SizedBox(height: 16),

                // 3. 24-Hour Day Balance Bar (توزیع ساعات شبانه‌روز)
                _buildDayBalanceSection(isDark, colors, isGlass, blocks),

                const SizedBox(height: 20),

                // 4. Chronological Day Timeline Stream & Realm Management
                _buildTimelineStreamHeader(isDark, colors),
                const SizedBox(height: 10),

                // Smart Sleep Suggestion Banner
                _buildSleepSuggestionCard(isDark, colors),

                ...blocks.map((block) => _buildTimelineBlockCard(isDark, colors, isGlass, block, activeNowMinute)),

                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ],
    );

    return Directionality(
      textDirection: TextDirection.rtl,
      child: AppleCardDeckHost(
        animation: _childSheetAnimController,
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.90,
          ),
          child: RitmoGlassSheet(
            borderRadius: sheetRadius,
            child: sheetContent,
          ),
        ),
      ),
    );
  }

  Widget _buildWeekdaySelector(bool isDark, RitmoColors colors, bool isGlass) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.surfaceElevated.withValues(alpha: isGlass ? 0.55 : 0.90),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? colors.border.withValues(alpha: 0.25) : colors.divider,
          width: 0.8,
        ),
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
                      ? colors.primary
                      : (isToday
                          ? colors.primary.withValues(alpha: 0.15)
                          : Colors.transparent),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: colors.primary.withValues(alpha: 0.35),
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
                                : colors.textPrimary),
                      ),
                    ),
                    if (isToday && !isSelected) ...[
                      const SizedBox(height: 2),
                      Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          color: colors.primary,
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
    RitmoColors colors,
    bool isGlass,
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
                  activeZoneId: _realmState.realmOrNull?.id,
                  activeZoneColor: inspectStatus.color,
                  activeZoneIcon: inspectStatus.icon,
                  activeZoneName: inspectStatus.name,
                  schedules: _schedules
                      .where((s) => s.daysOfWeek.contains(_selectedWeekday))
                      .toList(),
                  realms: _realms,
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
            color: colors.surfaceElevated.withValues(alpha: isGlass ? 0.70 : 0.95),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: inspectStatus.color.withValues(alpha: isDark ? 0.40 : 0.30),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: inspectStatus.color.withValues(alpha: isDark ? 0.18 : 0.08),
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
                            color: colors.textPrimary,
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
                        color: colors.textSecondary,
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
                    foregroundColor: colors.primary,
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

  Widget _buildDayBalanceSection(bool isDark, RitmoColors colors, bool isGlass, List<_DayTimelineBlock> blocks) {
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
        color: colors.surfaceElevated.withValues(alpha: isGlass ? 0.65 : 0.95),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? colors.border.withValues(alpha: 0.3) : colors.divider,
          width: 1.0,
        ),
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
                  color: colors.textPrimary,
                ),
              ),
              Text(
                '۱۰۰٪ شبانه‌روز',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: colors.textSecondary,
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
                      color: colors.textPrimary,
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

  Widget _buildTimelineStreamHeader(bool isDark, RitmoColors colors) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'گاه‌شمار و قلمروهای شبانه‌روز',
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w900,
                color: colors.textPrimary,
              ),
            ),
            if (_realms.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${toPersianDigits(_realms.length.toString())} قلمرو',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: colors.textSecondary,
                  ),
                ),
              ),
            ],
          ],
        ),
        // دکمه کپسولی + قلمرو جدید
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _openCreateSheet(),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: isDark ? 0.20 : 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: colors.primary.withValues(alpha: 0.38),
                width: 1.0,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(CupertinoIcons.plus, size: 13, color: colors.primary),
                const SizedBox(width: 4),
                Text(
                  'قلمرو جدید',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: colors.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineBlockCard(
    bool isDark,
    RitmoColors colors,
    bool isGlass,
    _DayTimelineBlock block,
    int activeNowMinute,
  ) {
    final isCurrent = _selectedWeekday == _now.weekday &&
        _isMinuteInBlock(activeNowMinute, block);

    final isFree = block.isFreeTime || block.realm == null;
    final color = isFree ? const Color(0xFF94A3B8) : block.realm!.parseColor();
    final icon = isFree ? '✨' : block.realm!.icon;
    final name = isFree ? 'زمان آزاد و شناور' : block.realm!.name;
    final mode = isFree ? 'آزاد' : block.realm!.mode.label;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark
            ? (isCurrent
                ? color.withValues(alpha: 0.20)
                : colors.surfaceElevated.withValues(alpha: isGlass ? 0.55 : 0.85))
            : (isCurrent
                ? color.withValues(alpha: 0.12)
                : colors.surfaceElevated.withValues(alpha: isGlass ? 0.70 : 0.90)),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCurrent
              ? color.withValues(alpha: 0.55)
              : (isDark ? colors.border.withValues(alpha: 0.25) : colors.divider),
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
                        color: colors.textPrimary,
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
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          // اکشن‌های تعاملی مدیریت قلمرو در کارت
          if (!isFree && block.realm != null) ...[
            // دکمه ویرایش سریع
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => _openEditSheet(block.realm!),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.black.withValues(alpha: 0.04),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  CupertinoIcons.pencil,
                  size: 15,
                  color: color,
                ),
              ),
            ),
            const SizedBox(width: 4),
            // دکمه منوی گزینه‌ها (سه‌نقطه)
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => _showRealmActionsMenu(block.realm!),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.black.withValues(alpha: 0.04),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  CupertinoIcons.ellipsis_vertical,
                  size: 15,
                  color: colors.textSecondary,
                ),
              ),
            ),
          ] else if (isFree && block.durationMinutes >= 15) ...[
            // دکمه تعریف قلمرو جدید در بازه زمان آزاد
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => _openCreateSheet(
                defaultStartMinute: block.startMinute,
                defaultEndMinute: block.endMinute,
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.black.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark ? Colors.white10 : Colors.black12,
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(CupertinoIcons.plus, size: 11, color: colors.textSecondary),
                    const SizedBox(width: 3),
                    Text(
                      'تعریف قلمرو',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
