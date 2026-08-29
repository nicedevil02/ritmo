import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/domain/engines/ritmo_event_bus.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/ux/ritmo_snackbar.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_card.dart';
import 'package:ritmo/features/worship/models/worship_models.dart';
import 'package:ritmo/features/worship/logic/worship_completion_repository.dart';
import 'package:ritmo/features/worship/logic/worship_engine.dart';
import 'package:ritmo/features/worship/presentation/widgets/worship_reminder_settings_sheet.dart';
import 'package:sqflite/sqflite.dart';

class MustahabSection extends StatefulWidget {

  const MustahabSection({
    super.key,
    required this.onChanged,
    this.date,
  });
  final VoidCallback onChanged;
  final DateTime? date;

  @override
  State<MustahabSection> createState() => _MustahabSectionState();
}

class _MustahabSectionState extends State<MustahabSection> {
  bool _isLoading = true;
  List<WorshipPractice> _activeMustahabs = [];
  Map<String, WorshipDayStatus> _statuses = {};
  StreamSubscription<RitmoEvent>? _eventSub;

  String get _targetDateStr =>
      (widget.date ?? DateTime.now()).toIso8601String().substring(0, 10);

  DateTime get _targetDate =>
      widget.date != null ? DateTime(widget.date!.year, widget.date!.month, widget.date!.day) : DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadMustahabs();
    _eventSub = RitmoEventBus().onEvents.listen((event) {
      if (event.type == 'WorshipUpdated' ||
          event.type == 'WorshipPracticeChanged' ||
          event.type == RitmoEventType.completionRecorded.code) {
        if (mounted) {
          _loadMustahabs();
        }
      }
    });
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(MustahabSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.date != widget.date) {
      _loadMustahabs();
    }
  }

  Future<void> _loadMustahabs() async {
    try {
      final list = await WorshipEngine.instance.loadActiveMustahabs(_targetDate);
      final statuses = await WorshipCompletionRepository.instance.statusForDate(_targetDateStr);
      if (mounted) {
        setState(() {
          _activeMustahabs = list;
          _statuses = statuses;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading mustahab practices: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _toggleDone(WorshipPractice practice, bool isDone) async {
    unawaited(HapticFeedback.selectionClick());
    try {
      final targetDate = _targetDate;
      WorshipLogResult result;
      if (isDone) {
        result = await WorshipEngine.instance.logDone(practiceId: practice.id, date: targetDate);
      } else {
        result = await WorshipEngine.instance.clearLog(practiceId: practice.id, date: targetDate);
      }

      if (result is WorshipLogBlocked && mounted) {
        RitmoSnackbar.warning(context, result.userMessage);
      } else if (result is WorshipLogFailed && mounted) {
        RitmoSnackbar.warning(context, 'خطا در ثبت: ${result.error}');
      }

      await _loadMustahabs();
      widget.onChanged();
    } catch (e) {
      debugPrint('Error updating mustahab: $e');
    }
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


  void _showManageSheet() {
    ManageMustahabSheet.present(
      context,
      onSaved: () {
        _loadMustahabs();
        widget.onChanged();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return SizedBox(
        height: 100,
        child: Center(child: CircularProgressIndicator(color: colors.primary)),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: RitmoCard.neumorphic(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Integrated Header Inside the Card
            Row(
                  children: [
                    // right side: icon + title + subtitle
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: isDark
                                    ? [
                                        colors.primaryContainer,
                                        colors.surface,
                                      ]
                                    : [
                                        colors.surface,
                                        colors.surfaceSunken,
                                      ],
                              ),
                              border: Border.all(
                                color: isDark
                                    ? colors.primary
                                    : colors.primaryContainer,
                              ),
                            ),
                            child: Icon(
                              CupertinoIcons.sparkles,
                              size: 20,
                              color: colors.accent,
                            ),
                          ),
                          const SizedBox(width: 11),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'مستحبات و ادعیه',
                                  style: TextStyle(
                                    fontSize: 16.5,
                                    fontWeight: FontWeight.w800,
                                    color: colors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'اعمال، زیارات و نوافل روزانه',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: colors.textSecondary
                                        .withValues(alpha: 0.62),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 10),

                    // Add / Manage Button
                    InkWell(
                      onTap: _showManageSheet,
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 13,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: colors.surfaceSunken,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: colors.primary.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              CupertinoIcons.slider_horizontal_3,
                              size: 15,
                              color: colors.primary,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'مدیریت و افزودن',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: colors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Card Content (Empty state or Practices List)
                if (_activeMustahabs.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
                    child: Center(
                      child: Column(
                        children: [
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    colors: [
                                      colors.primary.withValues(alpha: 0.15),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: colors.surface,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: colors.primary.withValues(alpha: 0.1),
                                      blurRadius: 20,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Icon(CupertinoIcons.heart_fill, color: colors.primary, size: 28),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'هنوز مستحبی انتخاب نشده است',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: colors.textPrimary,
                              ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'با انتخاب مستحبات، اعمال و ادعیه روزانه خود را در این بخش پیگیری کنید.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: colors.textSecondary.withValues(alpha: 0.7),
                              height: 1.55,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 24),
                          InkWell(
                            onTap: _showManageSheet,
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
                              decoration: BoxDecoration(
                                color: colors.primary,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: colors.primary.withValues(alpha: 0.28),
                                    blurRadius: 16,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(CupertinoIcons.add, size: 17, color: colors.onPrimary),
                                  const SizedBox(width: 8),
                                  Text(
                                    'انتخاب از فهرست مستحبات',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: colors.onPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _activeMustahabs.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final practice = _activeMustahabs[index];
                final status = _statuses[practice.id];
                final isDone = status?.isDone == true;

                final visual = _getMustahabVisuals(practice.title, colors);
                final iconColor = visual.color;
                final iconBg = visual.bg;
                final vectorIcon = visual.icon;

                return GestureDetector(
                  onTap: () => _toggleDone(practice, !isDone),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                    decoration: BoxDecoration(
                      color: isDark ? colors.surface : colors.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isDark ? colors.border : colors.border,
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isDone
                              ? iconColor.withValues(alpha: 0.15)
                              : (isDark ? colors.shadow.withValues(alpha: 0.25) : colors.shadow.withValues(alpha: 0.08)),
                          blurRadius: isDone ? 24 : 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        // Vector Icon Badge (Modernized)
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: isDone ? iconColor : iconBg,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: iconColor.withValues(alpha: isDone ? 0.4 : 0.0),
                                blurRadius: isDone ? 12 : 0,
                                offset: isDone ? const Offset(0, 4) : Offset.zero,
                              ),
                            ],
                          ),
                          child: Icon(vectorIcon, color: isDone ? colors.onPrimary : iconColor, size: 22),
                        ),
                        const SizedBox(width: 16),

                        // Title and Notes
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    practice.title,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: isDone ? iconColor : colors.textPrimary,
                                      decoration: isDone ? TextDecoration.lineThrough : null,
                                      decorationColor: iconColor,
                                      decorationThickness: 2,
                                    ),
                                  ),
                                  if (practice.reminderEnabled) ...[
                                    const SizedBox(width: 10),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: colors.accent.withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(CupertinoIcons.bell_fill, size: 10, color: colors.accent),
                                          const SizedBox(width: 4),
                                          Text(
                                            practice.reminderTime != null ? toPersianDigits(practice.reminderTime!) : 'یادآور',
                                            style: TextStyle(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.bold,
                                              color: colors.accent,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              if (practice.notes != null && practice.notes!.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  practice.notes!,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: colors.textSecondary.withValues(alpha: 0.6),
                                    height: 1.4,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),

                        // 2026 Fluid Toggle Checkbox
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOutCubic,
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: isDone ? iconColor : (isDark ? colors.surfaceSunken : colors.surfaceSunken),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDone ? iconColor : (isDark ? colors.border : colors.border),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: iconColor.withValues(alpha: isDone ? 0.3 : 0.0),
                                blurRadius: isDone ? 8 : 0,
                                offset: isDone ? const Offset(0, 2) : Offset.zero,
                              ),
                            ],
                          ),
                          child: isDone
                              ? Center(
                                  child: Icon(
                                    CupertinoIcons.checkmark,
                                    size: 16,
                                    color: colors.onPrimary,
                                  ),
                                )
                              : null,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class ManageMustahabSheet extends StatefulWidget {
  const ManageMustahabSheet({
    super.key,
    required this.onSaved,
  });
  final VoidCallback onSaved;

  static Future<void> present(BuildContext context, {required VoidCallback onSaved}) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => ManageMustahabSheet(onSaved: onSaved),
    );
  }

  @override
  State<ManageMustahabSheet> createState() => _ManageMustahabSheetState();
}

class _ManageMustahabSheetState extends State<ManageMustahabSheet> {
  List<Map<String, dynamic>> _presets = [];
  List<WorshipPractice> _customPractices = [];
  bool _isLoadingPresets = true;

  final List<Map<String, dynamic>> _defaultPresets = [
    {'id': 'preset_night_prayer', 'subType': 'NIGHT_PRAYER', 'title': 'نماز شب', 'notes': 'هر شب قبل از خواب یا نیمه‌شب'},
    {'id': 'preset_nafilah_fajr', 'subType': 'NAFILAH', 'title': 'نافله صبح', 'notes': 'قبل از نماز صبح'},
    {'id': 'preset_nafilah_dhuhr', 'subType': 'NAFILAH', 'title': 'نافله ظهر', 'notes': 'قبل از نماز ظهر'},
    {'id': 'preset_nafilah_asr', 'subType': 'NAFILAH', 'title': 'نافله عصر', 'notes': 'قبل از نماز عصر'},
    {'id': 'preset_nafilah_maghrib', 'subType': 'NAFILAH', 'title': 'نافله مغرب', 'notes': 'بعد از نماز مغرب'},
    {'id': 'preset_nafilah_isha', 'subType': 'NAFILAH', 'title': 'نافله عشا', 'notes': 'بعد از نماز عشا'},
    {'id': 'preset_ziarat_ashura', 'subType': 'ZIARAT', 'title': 'زیارت عاشورا', 'notes': 'زیارت امام حسین (ع)'},
    {'id': 'preset_dua_ahd', 'subType': 'DUA', 'title': 'دعای عهد', 'notes': 'تجدید عهد با امام زمان (عج)'},
    {'id': 'preset_dua_kumayl', 'subType': 'DUA', 'title': 'دعای کمیل', 'notes': 'پنجشنبه شب‌ها'},
    {'id': 'preset_dua_nudbah', 'subType': 'DUA', 'title': 'دعای ندبه', 'notes': 'صبح‌های جمعه'},
    {'id': 'preset_jafar_tayyar', 'subType': 'PRAYER', 'title': 'نماز جعفر طیار', 'notes': 'توصیه شده در روز جمعه'},
  ];

  @override
  void initState() {
    super.initState();
    _loadPresets();
  }

  Future<void> _loadPresets() async {
    try {
      final db = await DatabaseHelper.instance.database;

      // Read active status for all presets
      final finalPresets = <Map<String, dynamic>>[];
      for (final def in _defaultPresets) {
        final existing = await db.query(
          'worship_practices',
          where: 'id = ?',
          whereArgs: [def['id']],
          limit: 1,
        );

        var isActive = false;
        if (existing.isNotEmpty) {
          isActive = (existing.first['isActive'] as int? ?? 0) == 1;
        }

        finalPresets.add({
          ...def,
          'isActive': isActive,
        });
      }

      // Read all custom mustahabs
      final customResults = await db.query(
        'worship_practices',
        where: "practiceType = 'MUSTAHAB' AND subType = 'CUSTOM'",
        orderBy: 'createdAt DESC',
      );
      final customs = customResults.map(WorshipPractice.fromMap).toList();

      if (mounted) {
        setState(() {
          _presets = finalPresets;
          _customPractices = customs;
        });
      }
    } catch (e) {
      debugPrint('Error loading presets: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingPresets = false;
        });
      }
    }
  }

  Future<void> _toggleCustomActive(WorshipPractice practice, bool enable) async {
    unawaited(HapticFeedback.lightImpact());
    try {
      await WorshipEngine.instance.setPracticeEnabled(practice.id, enable);
      await _loadPresets();
      widget.onSaved();
    } catch (e) {
      debugPrint('Error toggling custom active: $e');
    }
  }

  Future<void> _deleteCustom(WorshipPractice practice) async {
    unawaited(HapticFeedback.vibrate());

    // 1. Soft delete immediately using WorshipEngine
    await WorshipEngine.instance.setPracticeEnabled(practice.id, false);
    await _loadPresets();
    widget.onSaved();

    if (!mounted) return;

    // 2. Show SnackBar with Undo action
    final colors = context.colors;
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: colors.border.withValues(alpha: 0.1), width: 0.8),
        ),
        backgroundColor: colors.card.withValues(alpha: 0.95),
        duration: const Duration(seconds: 5),
        content: Directionality(
          textDirection: TextDirection.rtl,
          child: Row(
            children: [
              const Icon(CupertinoIcons.trash, color: Colors.redAccent, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'مستحب سفارشی غیرفعال شد',
                  style: TextStyle(
                    fontSize: 13.5,
                    color: colors.textPrimary,
                  ),
                ),
              ),
              TextButton(
                onPressed: () async {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  await WorshipEngine.instance.setPracticeEnabled(practice.id, true);
                  await _loadPresets();
                  widget.onSaved();
                },
                child: Text(
                  'بازگرداندن (Undo)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: colors.accent,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Map<String, dynamic> _getDefaultReminder(String id) {
    final defaults = <String, Map<String, dynamic>>{
      'preset_night_prayer': {'time': '22:30', 'freq': 'DAILY', 'day': ''},
      'preset_nafilah_fajr': {'time': '05:00', 'freq': 'DAILY', 'day': ''},
      'preset_nafilah_dhuhr': {'time': '12:00', 'freq': 'DAILY', 'day': ''},
      'preset_nafilah_asr': {'time': '15:30', 'freq': 'DAILY', 'day': ''},
      'preset_nafilah_maghrib': {'time': '19:30', 'freq': 'DAILY', 'day': ''},
      'preset_nafilah_isha': {'time': '20:30', 'freq': 'DAILY', 'day': ''},
      'preset_ziarat_ashura': {'time': '08:00', 'freq': 'DAILY', 'day': ''},
      'preset_dua_ahd': {'time': '07:00', 'freq': 'DAILY', 'day': ''},
      'preset_dua_kumayl': {'time': '20:00', 'freq': 'WEEKLY', 'day': '4'},
      'preset_dua_nudbah': {'time': '07:30', 'freq': 'WEEKLY', 'day': '5'},
      'preset_jafar_tayyar': {'time': '10:00', 'freq': 'WEEKLY', 'day': '5'},
    };
    return defaults[id] ?? {'time': '21:00', 'freq': 'DAILY', 'day': ''};
  }

  String _describeReminder(Map<String, dynamic> reminder) {
    final freq = reminder['freq'] == 'DAILY' ? 'هر روز' : 'هفتگی';
    final time = toPersianDigits(reminder['time'] as String);
    final dayRaw = reminder['day'] as String? ?? '';
    String day = '';
    if (dayRaw == 'Thursday' || dayRaw == '4') {
      day = 'پنجشنبه‌ها';
    } else if (dayRaw == 'Friday' || dayRaw == '5') {
      day = 'جمعه‌ها';
    }
    if (day.isNotEmpty) {
      return '$freq ($day) ساعت $time';
    }
    return '$freq ساعت $time';
  }

  void _showPresetReminderDialog(Map<String, dynamic> preset) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final reminder = _getDefaultReminder(preset['id'] as String);

    showDialog(
      context: context,
      builder: (dialogContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 24),
            child: RitmoTheme.glassCardLight(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isDark ? colors.accent.withValues(alpha: 0.15) : colors.border,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(CupertinoIcons.alarm_fill, color: colors.accent, size: 24),
                        const SizedBox(width: 10),
                        Text(
                          'تنظیم یادآور مستحب',
                          style: TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.bold,
                            color: colors.textPrimary,
                            ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'یادآور پیش‌فرض برای «${preset['title']}» به صورت زیر تنظیم شده است:',
                      style: TextStyle(
                        fontSize: 14,
                        color: colors.textPrimary.withValues(alpha: 0.9),
                        ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colors.accent.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _describeReminder(reminder),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: colors.primary,
                          ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.primary,
                        foregroundColor: colors.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      onPressed: () {
                        Navigator.pop(dialogContext);
                        _togglePresetWithReminder(preset, true, true);
                      },
                      child: Text(
                        'تایید و ثبت با یادآور پیش‌فرض',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: colors.onPrimary),
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colors.textPrimary,
                        side: BorderSide(color: colors.textSecondary.withValues(alpha: 0.2)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        Navigator.pop(dialogContext);
                        final todayStr = DateTime.now().toIso8601String().substring(0, 10);
                        final tempPractice = WorshipPractice(
                          id: preset['id'] as String,
                          practiceType: 'MUSTAHAB',
                          subType: preset['subType'] as String,
                          title: preset['title'] as String,
                          reminderEnabled: true,
                          reminderTime: reminder['time'] as String,
                          reminderFrequency: reminder['freq'] as String,
                          reminderDaysOfWeek: reminder['day'] as String,
                          notes: preset['notes'] as String?,
                          dailyDoneDate: todayStr,
                          createdAt: DateTime.now().millisecondsSinceEpoch,
                          updatedAt: DateTime.now().millisecondsSinceEpoch,
                        );
                        showModalBottomSheet(
                          context: context,
                          backgroundColor: Colors.transparent,
                          isScrollControlled: true,
                          builder: (sheetCtx) {
                            return WorshipReminderSettingsSheet(
                              practice: tempPractice,
                              onSaved: (updated) async {
                                await _togglePresetWithReminder(
                                  preset,
                                  true,
                                  updated.reminderEnabled == true,
                                  customTime: updated.reminderTime,
                                  customFreq: updated.reminderFrequency,
                                  customDay: updated.reminderDaysOfWeek,
                                );
                              },
                            );
                          },
                        );
                      },
                      child: const Text(
                        'ویرایش یادآور',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: colors.textSecondary,
                      ),
                      onPressed: () {
                        Navigator.pop(dialogContext);
                        _togglePresetWithReminder(preset, true, false);
                      },
                      child: const Text(
                        'ثبت بدون یادآور',
                        style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
                      ),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: colors.textSecondary.withValues(alpha: 0.7),
                      ),
                      onPressed: () {
                        Navigator.pop(dialogContext);
                      },
                      child: const Text(
                        'انصراف',
                        style: TextStyle(fontSize: 13),
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

  Future<void> _togglePreset(Map<String, dynamic> preset, bool enable) async {
    await _togglePresetWithReminder(preset, enable, false);
  }

  Future<void> _togglePresetWithReminder(
    Map<String, dynamic> preset,
    bool enable,
    bool enableReminder, {
    String? customTime,
    String? customFreq,
    String? customDay,
  }) async {
    unawaited(HapticFeedback.lightImpact());
    try {
      final db = await DatabaseHelper.instance.database;
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final todayStr = DateTime.now().toIso8601String().substring(0, 10);
      final rDefaults = _getDefaultReminder(preset['id'] as String);

      final existing = await db.query(
        'worship_practices',
        where: 'id = ?',
        whereArgs: [preset['id']],
        limit: 1,
      );

      if (existing.isNotEmpty) {
        await db.update(
          'worship_practices',
          {
            'isActive': enable ? 1 : 0,
            'userDisabledAt': enable ? null : DateTime.now().toIso8601String(),
            'reminderEnabled': enableReminder ? 1 : 0,
            'reminderTime': ?customTime,
            'reminderFrequency': ?customFreq,
            'reminderDaysOfWeek': ?customDay,
            'updatedAt': nowMs,
          },
          where: 'id = ?',
          whereArgs: [preset['id']],
        );
      } else if (enable) {
        await db.insert(
          'worship_practices',
          {
            'id': preset['id'],
            'practiceType': 'MUSTAHAB',
            'subType': preset['subType'],
            'title': preset['title'],
            'dailyTarget': 1,
            'dailyDone': 0,
            'reminderEnabled': enableReminder ? 1 : 0,
            'reminderTime': customTime ?? rDefaults['time'],
            'reminderFrequency': customFreq ?? rDefaults['freq'],
            'reminderDaysOfWeek': customDay ?? rDefaults['day'],
            'isActive': 1,
            'notes': preset['notes'],
            'dailyDoneDate': todayStr,
            'createdAt': nowMs,
            'updatedAt': nowMs,
          },
        );
      }

      await _loadPresets();
      widget.onSaved();
    } catch (e) {
      debugPrint('Error toggling preset: $e');
    }
  }

  Future<void> _editPractice({WorshipPractice? practice, Map<String, dynamic>? preset}) async {
    WorshipPractice practiceToEdit;
    if (practice != null) {
      practiceToEdit = practice;
    } else {
      final db = await DatabaseHelper.instance.database;
      final existing = await db.query(
        'worship_practices',
        where: 'id = ?',
        whereArgs: [preset!['id']],
        limit: 1,
      );

      if (existing.isNotEmpty) {
        practiceToEdit = WorshipPractice.fromMap(existing.first);
      } else {
        final reminder = _getDefaultReminder(preset['id'] as String);
        final todayStr = DateTime.now().toIso8601String().substring(0, 10);
        final nowMs = DateTime.now().millisecondsSinceEpoch;
        practiceToEdit = WorshipPractice(
          id: preset['id'] as String,
          practiceType: 'MUSTAHAB',
          subType: preset['subType'] as String,
          title: preset['title'] as String,
          reminderTime: reminder['time'] as String,
          reminderFrequency: reminder['freq'] as String,
          reminderDaysOfWeek: reminder['day'] as String,
          isActive: false,
          notes: preset['notes'] as String?,
          dailyDoneDate: todayStr,
          createdAt: nowMs,
          updatedAt: nowMs,
        );
      }
    }

    if (!mounted) return;

    unawaited(showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) {
        return AddCustomMustahabSheet(
          practice: practiceToEdit,
          onDelete: practice != null ? () => _deleteCustom(practice) : null,
          onSaved: () {
            _loadPresets();
            widget.onSaved();
          },
        );
      },
    ));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: RitmoTheme.glassCardLight(
        borderRadius: 28,
        child: Container(
          constraints: BoxConstraints(
            maxHeight: RitmoBreakpoints.sheetMaxHeight(context, factor: 0.85),
          ),
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'مدیریت مستحبات و ادعیه',
                    style: TextStyle(
                      fontSize: 17.5,
                      fontWeight: FontWeight.bold,
                      color: colors.textPrimary,
                      ),
                  ),
                  IconButton(
                    icon: Icon(CupertinoIcons.xmark, color: colors.textSecondary, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Expanded(
                child: _buildPresetsTab(colors),
              ),
            ],
          ),
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

  Widget _buildPresetsTab(RitmoColors colors) {
    if (_isLoadingPresets) {
      return Center(child: CircularProgressIndicator(color: colors.textPrimary));
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView(
      physics: const BouncingScrollPhysics(),
      children: [
        if (_customPractices.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Text(
              'مستحبات سفارشی شما',
              style: TextStyle(
                color: isDark ? colors.accent : colors.primary,
                fontSize: 14,
                fontWeight: FontWeight.bold,
                ),
            ),
          ),
          ..._customPractices.map((practice) {
            final isActive = practice.isActive == true;
            final visual = _getMustahabVisuals(practice.title, colors);
            return Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? colors.accent.withValues(alpha: 0.15) : colors.border,
                ),
              ),
              child: Material(
                color: isDark ? colors.surface : colors.card,
                borderRadius: BorderRadius.circular(14),
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  dense: true,
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: visual.bg,
                    ),
                    child: Center(
                      child: Icon(
                        visual.icon,
                        size: 18,
                        color: visual.color,
                      ),
                    ),
                  ),
                  title: Text(
                    practice.title,
                    style: TextStyle(color: colors.textPrimary, fontSize: 14.5, fontWeight: FontWeight.bold),
                  ),
                  subtitle: practice.notes != null && practice.notes!.isNotEmpty
                      ? Text(
                          practice.notes!,
                          style: TextStyle(color: colors.textSecondary, fontSize: 12.5),
                        )
                      : null,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(CupertinoIcons.settings, color: colors.textSecondary, size: 18),
                        onPressed: () => _editPractice(practice: practice),
                      ),
                      const SizedBox(width: 4),
                      CupertinoSwitch(
                        value: isActive,
                        activeTrackColor: colors.primary,
                        onChanged: (val) => _toggleCustomActive(practice, val),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 12),
          Divider(color: colors.border.withValues(alpha: 0.5)),
        ],

        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Text(
            'مستحبات پیش‌فرض',
            style: TextStyle(
              color: isDark ? colors.accent : colors.primary,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ..._presets.map((preset) {
          final isActive = preset['isActive'] as bool;
          final title = preset['title'] as String;
          final visual = _getMustahabVisuals(title, colors);
          return Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? colors.accent.withValues(alpha: 0.15) : colors.border,
              ),
            ),
            child: Material(
              color: isDark ? colors.surface : colors.card,
              borderRadius: BorderRadius.circular(14),
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                dense: true,
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: visual.bg,
                  ),
                  child: Center(
                    child: Icon(
                      visual.icon,
                      size: 18,
                      color: visual.color,
                    ),
                  ),
                ),
                title: Text(
                  title,
                  style: TextStyle(color: colors.textPrimary, fontSize: 14.5, fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  preset['notes'] as String,
                  style: TextStyle(color: colors.textSecondary, fontSize: 12.5),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(CupertinoIcons.settings, color: colors.textSecondary, size: 18),
                      onPressed: () => _editPractice(preset: preset),
                    ),
                    const SizedBox(width: 4),
                    CupertinoSwitch(
                      value: isActive,
                      activeTrackColor: colors.primary,
                      onChanged: (val) {
                        if (val) {
                          _showPresetReminderDialog(preset);
                        } else {
                          _togglePreset(preset, false);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: 20),
        GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            showModalBottomSheet(
              context: context,
              backgroundColor: Colors.transparent,
              isScrollControlled: true,
              builder: (context) {
                return AddCustomMustahabSheet(
                  onSaved: () {
                    _loadPresets();
                    widget.onSaved();
                  },
                );
              },
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: isDark ? colors.surface : colors.textSecondary.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? colors.accent.withValues(alpha: 0.15) : colors.textSecondary.withValues(alpha: 0.1),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  CupertinoIcons.plus_circle_fill,
                  size: 18,
                  color: isDark ? colors.accent : colors.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'اضافه کردن مستحبات سفارشی',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.bold,
                    color: isDark ? colors.accent : colors.textPrimary,
                    ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class AddCustomMustahabSheet extends StatefulWidget {

  const AddCustomMustahabSheet({super.key, 
    required this.onSaved,
    this.practice,
    this.onDelete,
  });
  final VoidCallback onSaved;
  final WorshipPractice? practice;
  final VoidCallback? onDelete;

  @override
  State<AddCustomMustahabSheet> createState() => _AddCustomMustahabSheetState();
}

class _AddCustomMustahabSheetState extends State<AddCustomMustahabSheet> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  WorshipPractice? _tempPractice;

  @override
  void initState() {
    super.initState();
    if (widget.practice != null) {
      _titleController.text = widget.practice!.title;
      _notesController.text = widget.practice!.notes ?? '';
      _tempPractice = widget.practice;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveCustom() async {
    unawaited(HapticFeedback.mediumImpact());
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      RitmoSnackbar.warning(context, 'لطفاً عنوان مستحب را وارد کنید');
      return;
    }

    final isEdit = widget.practice != null;
    final notes = _notesController.text.trim().isEmpty 
        ? (isEdit && widget.practice!.subType == 'PRESET' ? '' : 'مستحب سفارشی') 
        : _notesController.text.trim();

    try {
      final db = await DatabaseHelper.instance.database;
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final todayStr = DateTime.now().toIso8601String().substring(0, 10);
      final id = isEdit ? widget.practice!.id : 'wp_custom_${nowMs}_${DateTime.now().microsecondsSinceEpoch}';

      final practice = _tempPractice ?? widget.practice ?? WorshipPractice(
        id: id,
        practiceType: 'MUSTAHAB',
        subType: 'CUSTOM',
        title: title,
        reminderTime: '21:00',
        dailyDoneDate: todayStr,
        createdAt: nowMs,
        updatedAt: nowMs,
      );

      final p = practice.copyWith(
        id: id,
        title: title,
        notes: notes,
        dailyTarget: 1,
        createdAt: practice.createdAt == 0 ? nowMs : practice.createdAt,
        updatedAt: nowMs,
        isActive: true,
      );

      await db.insert(
        'worship_practices',
        p.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      widget.onSaved();

      if (mounted) {
        Navigator.pop(context);
        RitmoSnackbar.success(
          context,
          isEdit ? 'تغییرات با موفقیت ذخیره شد ✨' : 'مستحب سفارشی با موفقیت اضافه شد ✨',
        );
      }
    } catch (e) {
      debugPrint('Error saving mustahab: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: RitmoTheme.glassCardLight(
        borderRadius: 28,
        child: Container(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.practice != null ? 'ویرایش مستحب سفارشی' : 'افزودن مستحب سفارشی',
                    style: TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.bold,
                      color: colors.textPrimary,
                      ),
                  ),
                  IconButton(
                    icon: Icon(CupertinoIcons.xmark, color: colors.textSecondary, size: 18),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Title field
              Text(
                'عنوان مستحب:',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: colors.textPrimary),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _titleController,
                style: TextStyle(color: colors.textPrimary, fontSize: 14.5, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  hintText: 'مثلا: زیارت آل یاسین، دعای سمات...',
                  hintStyle: TextStyle(color: colors.textSecondary.withValues(alpha: 0.4), fontSize: 13),
                  fillColor: colors.surfaceSunken,
                  filled: true,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: colors.border.withValues(alpha: 0.5)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: colors.primary, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Description/Notes field
              Text(
                'توضیحات کوتاه:',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: colors.textPrimary),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _notesController,
                style: TextStyle(color: colors.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'مثلا: سه شنبه شب ها، هدیه به اموات...',
                  hintStyle: TextStyle(color: colors.textSecondary.withValues(alpha: 0.4), fontSize: 13),
                  fillColor: colors.surfaceSunken,
                  filled: true,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: colors.border.withValues(alpha: 0.5)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: colors.primary, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Add / Edit Reminder Area
              if (_tempPractice?.reminderEnabled ?? false) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: colors.primary.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(CupertinoIcons.alarm_fill, color: colors.primary, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'یادآوری فعال است ⏰',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: colors.primary,
                                ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'تناوب: ${_tempPractice!.reminderFrequency == "DAILY" ? "روزانه" : _tempPractice!.reminderFrequency == "WEEKLY" ? "هفتگی" : _tempPractice!.reminderFrequency}',
                              style: TextStyle(
                                fontSize: 12,
                                color: colors.textPrimary.withValues(alpha: 0.7),
                                ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              foregroundColor: colors.error,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              backgroundColor: colors.error.withValues(alpha: 0.08),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () async {
                              unawaited(HapticFeedback.vibrate());
                              setState(() {
                                if (_tempPractice != null) {
                                  _tempPractice = _tempPractice!.copyWith(reminderEnabled: false);
                                }
                              });
                              RitmoSnackbar.success(context, 'یادآور با موفقیت حذف شد 🗑️');
                            },
                            icon: const Icon(CupertinoIcons.trash, size: 14),
                            label: const Text(
                              'حذف',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 6),
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              foregroundColor: colors.primary,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              backgroundColor: colors.primary.withValues(alpha: 0.1),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () {
                              HapticFeedback.selectionClick();
                              showModalBottomSheet(
                                context: context,
                                backgroundColor: Colors.transparent,
                                isScrollControlled: true,
                                builder: (context) {
                                  return WorshipReminderSettingsSheet(
                                    practice: _tempPractice!,
                                    onSaved: (updated) {
                                      setState(() {
                                        _tempPractice = updated;
                                      });
                                    },
                                  );
                                },
                              );
                            },
                            icon: const Icon(CupertinoIcons.pencil, size: 14),
                            label: const Text(
                              'ویرایش',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ] else ...[
                GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    final p = _tempPractice ?? WorshipPractice(
                      id: '',
                      practiceType: 'MUSTAHAB',
                      subType: 'CUSTOM',
                      title: _titleController.text.isEmpty ? 'مستحب' : _titleController.text,
                      reminderTime: '21:00',
                      dailyDoneDate: '',
                      createdAt: 0,
                      updatedAt: 0,
                    );
                    showModalBottomSheet(
                      context: context,
                      backgroundColor: Colors.transparent,
                      isScrollControlled: true,
                      builder: (context) {
                        return WorshipReminderSettingsSheet(
                          practice: p,
                          onSaved: (updated) {
                            setState(() {
                              _tempPractice = updated;
                            });
                          },
                        );
                      },
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: colors.surfaceSunken,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: colors.border.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          CupertinoIcons.bell_fill,
                          size: 18,
                          color: colors.textSecondary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'افزودن یادآور',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.bold,
                            color: colors.textSecondary,
                            ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),

              if (widget.onDelete != null) ...[
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: colors.error,
                          side: BorderSide(color: colors.error.withValues(alpha: 0.3)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          widget.onDelete!();
                        },
                        child: const Text(
                          'حذف مستحب',
                          style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colors.primary,
                          foregroundColor: colors.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        onPressed: _saveCustom,
                        child: Text(
                          'ثبت تغییرات',
                          style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: colors.onPrimary),
                        ),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primary,
                    foregroundColor: colors.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  onPressed: _saveCustom,
                  child: Text(
                    widget.practice != null ? 'ثبت تغییرات' : 'ثبت و افزودن مستحب',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: colors.onPrimary),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}



