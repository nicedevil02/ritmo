import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/utils/ritmo_date_picker.dart';
import 'package:ritmo/features/worship/models/worship_models.dart' hide toPersianDigits;
import 'package:shamsi_date/shamsi_date.dart';

/// Modal bottom sheet for configuring worship practice reminder settings.
class WorshipReminderSettingsSheet extends StatefulWidget {

  /// Constructs a [WorshipReminderSettingsSheet].
  const WorshipReminderSettingsSheet({
    required this.practice,
    required this.onSaved,
    super.key,
  });
  /// The target worship practice model.
  final WorshipPractice practice;

  /// Callback fired when reminder settings are saved.
  final void Function(WorshipPractice) onSaved;

  @override
  State<WorshipReminderSettingsSheet> createState() =>
      _WorshipReminderSettingsSheetState();
}

class _WorshipReminderSettingsSheetState
    extends State<WorshipReminderSettingsSheet>
    with SingleTickerProviderStateMixin {
  // ── State ──────────────────────────────────────────────
  bool _reminderEnabled = false;
  late TimeOfDay _reminderTime;
  String _reminderFrequency = 'DAILY';
  bool _allowQada = false;
  String _reminderAnchor = 'NONE'; // NONE | FAJR | DHUHR | … | WAKEUP | BEDTIME
  int _offsetMinutes = 0;
  List<int> _selectedDays = [];
  List<TimeOfDay> _reminderTimesList = [];
  String _onceDateStr = '';

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  // ── Data ───────────────────────────────────────────────
  static const _weekDays = [
    {'key': 6, 'label': 'ش'},
    {'key': 7, 'label': 'ی'},
    {'key': 1, 'label': 'د'},
    {'key': 2, 'label': 'س'},
    {'key': 3, 'label': 'چ'},
    {'key': 4, 'label': 'پ'},
    {'key': 5, 'label': 'ج'},
  ];

  static const _shariaAnchors = [
    {'key': 'FAJR',           'label': 'اذان صبح',       'icon': '🌅'},
    {'key': 'SUNRISE',        'label': 'طلوع آفتاب',      'icon': '☀️'},
    {'key': 'DHUHR',          'label': 'اذان ظهر',        'icon': '🕐'},
    {'key': 'ASR',            'label': 'اذان عصر',        'icon': '🌤'},
    {'key': 'MAGHRIB',        'label': 'اذان مغرب',       'icon': '🌇'},
    {'key': 'ISHA',           'label': 'اذان عشا',        'icon': '🌙'},
    {'key': 'MIDNIGHT_SHARI', 'label': 'نیمه‌شب شرعی',   'icon': '🕛'},
  ];

  static const _sleepAnchors = [
    {'key': 'WAKEUP',   'label': 'زمان بیداری',   'icon': '⏰'},
    {'key': 'BEDTIME',  'label': 'زمان خوابیدن',  'icon': '😴'},
  ];

  // ── Init ───────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));
    _fadeAnim =
        CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();

    final p = widget.practice;
    _reminderEnabled = p.reminderEnabled;
    _reminderTime    = _parseTimeStr(p.reminderTime);
    _reminderFrequency = p.reminderFrequency;
    _allowQada       = p.allowQada;
    _reminderAnchor  = p.reminderAnchor;
    _offsetMinutes   = p.reminderOffsetMinutes ?? 0;

    if (_reminderFrequency == 'DAILY') {
      _reminderFrequency = 'WEEKLY';
      _selectedDays = [6, 7, 1, 2, 3, 4, 5];
    } else if (_reminderFrequency == 'ONCE') {
      _onceDateStr = p.reminderDaysOfWeek ?? '';
      try {
        DateTime.parse(_onceDateStr);
      } catch (_) {
        _onceDateStr = DateTime.now().toIso8601String().substring(0, 10);
      }
    } else if (p.reminderDaysOfWeek != null && p.reminderDaysOfWeek!.isNotEmpty) {
      _selectedDays = p.reminderDaysOfWeek!
          .split(',')
          .map(int.tryParse)
          .whereType<int>()
          .toList();
    }
    if (_onceDateStr.isEmpty) {
      _onceDateStr = DateTime.now().toIso8601String().substring(0, 10);
    }
    if ((_reminderFrequency == 'MONTHLY' ||
            _reminderFrequency == 'LUNAR_MONTHLY') &&
        _selectedDays.isEmpty) {
      _selectedDays = [1];
    }

    if (p.reminderTimes != null && p.reminderTimes!.isNotEmpty) {
      try {
        final decoded = jsonDecode(p.reminderTimes!);
        if (decoded is List) {
          _reminderTimesList = decoded.map((e) {
            final pts = e.toString().split(':');
            return TimeOfDay(
                hour: int.parse(pts[0]), minute: int.parse(pts[1]));
          }).toList();
        }
      } catch (_) {}
    }
    if (_reminderTimesList.isEmpty) _reminderTimesList = [_reminderTime];
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  // ── Helpers ────────────────────────────────────────────
  TimeOfDay _parseTimeStr(String? s) {
    if (s == null || s.isEmpty) return const TimeOfDay(hour: 21, minute: 0);
    try {
      final p = s.split(':');
      return TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1]));
    } catch (_) {
      return const TimeOfDay(hour: 21, minute: 0);
    }
  }

  String _fmt(TimeOfDay t) => toPersianDigits(
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}');

  String _anchorLabel(String key) {
    final all = [..._shariaAnchors, ..._sleepAnchors];
    return all.firstWhere((a) => a['key'] == key,
            orElse: () => {'label': ''})['label'] ??
        '';
  }

  bool get _isFixed  => _reminderAnchor == 'NONE';
  bool get _isSharia => _shariaAnchors.any((a) => a['key'] == _reminderAnchor);
  bool get _isSleep  => _sleepAnchors.any((a) => a['key'] == _reminderAnchor);

  Future<void> _pickTime(int index) async {
    final initial = index >= 0 && index < _reminderTimesList.length
        ? _reminderTimesList[index]
        : TimeOfDay(hour: 8, minute: 0);
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (ctx, child) {
        final colors = ctx.colors;
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: isDark
                ? ColorScheme.dark(
                    primary: colors.accent,
                    surface: colors.surface,
                  )
                : ColorScheme.light(
                    primary: colors.accent,
                    surface: colors.surface,
                  ),
          ),
          child: child!,
        );
      },
    );
    if (picked == null) return;
    setState(() {
      if (index >= 0 && index < _reminderTimesList.length) {
        _reminderTimesList[index] = picked;
      } else {
        _reminderTimesList.add(picked);
      }
    });
  }

  Future<void> _save() async {
    await HapticFeedback.mediumImpact();
    try {
      final db  = await DatabaseHelper.instance.database;
      final now = DateTime.now().millisecondsSinceEpoch;

      final timeStr = _reminderTimesList.isNotEmpty
          ? '${_reminderTimesList.first.hour.toString().padLeft(2, '0')}:${_reminderTimesList.first.minute.toString().padLeft(2, '0')}'
          : '${_reminderTime.hour.toString().padLeft(2, '0')}:${_reminderTime.minute.toString().padLeft(2, '0')}';

      final timesJson = jsonEncode(_reminderTimesList
          .map((t) =>
              '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}')
          .toList());

      final daysStr = _reminderFrequency == 'ONCE' ? (_onceDateStr ?? '') : _selectedDays.join(',');

      final updated = widget.practice.copyWith(
        reminderEnabled:      _reminderEnabled,
        reminderTime:         timeStr,
        reminderFrequency:    _reminderFrequency,
        allowQada:            _allowQada,
        reminderAnchor:       _reminderAnchor,
        reminderOffsetMinutes: _offsetMinutes,
        reminderDaysOfWeek:   daysStr,
        reminderTimes:        timesJson,
        updatedAt:            now,
      );

      if (widget.practice.id.isNotEmpty) {
        await db.update(
          'worship_practices',
          {
            'reminderEnabled':      _reminderEnabled ? 1 : 0,
            'reminderTime':         timeStr,
            'reminderFrequency':    _reminderFrequency,
            'allowQada':            _allowQada ? 1 : 0,
            'reminderAnchor':       _reminderAnchor,
            'reminderOffsetMinutes': _offsetMinutes,
            'reminderDaysOfWeek':   daysStr,
            'reminderTimes':        timesJson,
            'updatedAt':            now,
          },
          where: 'id = ?',
          whereArgs: [widget.practice.id],
        );
      }

      widget.onSaved(updated);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint('Error saving reminder: $e');
    }
  }

  // ══════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final cardBg  = isDark ? colors.surface : colors.sheetBackground;
    final chipBg  = isDark ? colors.surfaceSunken : colors.card;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: FadeTransition(
        opacity: _fadeAnim,
        child: RitmoTheme.glassCardLight(
          borderRadius: 28,
          child: Container(
            constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.85),
            padding: EdgeInsets.fromLTRB(
                20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  width: 40, height: 4,
                  margin: EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: colors.textSecondary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                _buildHeader(colors),
                const SizedBox(height: 20),

                // Steps
                Flexible(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ── Step 1: Frequency ─────────────
                        _step(
                          number: '۱', title: 'تکرار',
                          colors: colors, isDark: isDark, cardBg: cardBg,
                          child: _buildFrequency(colors, isDark, chipBg),
                        ),
                        const SizedBox(height: 12),

                        // ── Step 2: Basis + conditional time/anchor ──
                        _step(
                          number: '۲', title: 'مبنای زمان',
                          colors: colors, isDark: isDark, cardBg: cardBg,
                          child: _buildBasisSection(colors, isDark, chipBg),
                        ),
                        const SizedBox(height: 12),

                        // ── Step 3: Extra ─────────────────
                        _step(
                          number: '۳', title: 'سایر تنظیمات',
                          colors: colors, isDark: isDark, cardBg: cardBg,
                          child: _buildExtra(colors),
                        ),
                        SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),

                _buildButtons(colors),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────
  Widget _buildHeader(RitmoColors colors) {
    return Row(
      children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [colors.accent, colors.accentContainer],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(CupertinoIcons.bell_fill, color: Colors.white, size: 18),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'تنظیم یادآوری',
                style: TextStyle(
                  fontSize: 17, fontWeight: FontWeight.bold,
                  color: colors.textPrimary, fontFamily: 'Vazirmatn',
                ),
              ),
              Text(
                widget.practice.title,
                style: TextStyle(
                  fontSize: 12.5, color: colors.textSecondary,
                  fontFamily: 'Vazirmatn',
                ),
                maxLines: 1, overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: colors.textSecondary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(CupertinoIcons.xmark,
                color: colors.textSecondary, size: 14),
          ),
        ),
      ],
    );
  }

  // ── Step wrapper ───────────────────────────────────────
  Widget _step({
    required String number,
    required String title,
    required RitmoColors colors,
    required bool isDark,
    required Color cardBg,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.04)
              : colors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Row(
              children: [
                Container(
                  width: 24, height: 24,
                  decoration: BoxDecoration(
                    color: colors.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      number,
                      style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.bold,
                        color: colors.accent, fontFamily: 'Vazirmatn',
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700,
                    color: colors.textPrimary, fontFamily: 'Vazirmatn',
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            child: child,
          ),
        ],
      ),
    );
  }

  // ── Step 1: Frequency ──────────────────────────────────
  Widget _buildCalendarTypeTab(String label, String value, RitmoColors colors, bool isDark) {
    final isActive = _reminderFrequency == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() {
            _reminderFrequency = value;
            if (_selectedDays.isEmpty) {
              _selectedDays = [1];
            } else if (value == 'LUNAR_MONTHLY' && _selectedDays.first > 30) {
              _selectedDays = [30];
            }
          });
        },
        child: AnimatedContainer(
          duration: Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? colors.accent.withValues(alpha: 0.18) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Vazirmatn',
              fontSize: 12,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              color: isActive ? colors.accent : colors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  // ── Step 1: Frequency ──────────────────────────────────
  Widget _buildFrequency(RitmoColors colors, bool isDark, Color chipBg) {
    final freqs = [
      {'key': 'ONCE',    'label': 'فقط یک‌بار',        'icon': CupertinoIcons.bell},
      {'key': 'WEEKLY',  'label': 'هفتگی / روزانه',  'icon': CupertinoIcons.calendar},
      {'key': 'MONTHLY', 'label': 'ماهانه',           'icon': CupertinoIcons.calendar_badge_plus},
    ];

    final isWeeklySelected = _reminderFrequency == 'WEEKLY';
    final isMonthlySelected = _reminderFrequency == 'MONTHLY' || _reminderFrequency == 'LUNAR_MONTHLY';
    final isOnceSelected = _reminderFrequency == 'ONCE';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: freqs.map((f) {
            final key = f['key']! as String;
            final selected = (key == 'WEEKLY' && isWeeklySelected) || (key == 'MONTHLY' && isMonthlySelected) || (key == 'ONCE' && isOnceSelected);
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    if (key == 'WEEKLY') {
                      if (_reminderFrequency != 'WEEKLY') {
                        _reminderFrequency = 'WEEKLY';
                        _selectedDays = [];
                      }
                    } else if (key == 'MONTHLY') {
                      if (_reminderFrequency != 'MONTHLY' && _reminderFrequency != 'LUNAR_MONTHLY') {
                        _reminderFrequency = 'MONTHLY';
                        _selectedDays = [];
                      }
                    } else {
                      if (_reminderFrequency != 'ONCE') {
                        _reminderFrequency = 'ONCE';
                        _selectedDays = [];
                        _onceDateStr = '';
                      }
                    }
                  });
                },
                child: AnimatedContainer(
                  duration: Duration(milliseconds: 200),
                  margin: EdgeInsets.symmetric(horizontal: 4),
                  padding: EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: selected ? colors.accent.withValues(alpha: 0.15) : chipBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: selected ? colors.accent.withValues(alpha: 0.4) : Colors.transparent,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(f['icon']! as IconData,
                          size: 20,
                          color: selected ? colors.accent : colors.textSecondary),
                      SizedBox(height: 6),
                      Text(
                        f['label']! as String,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                          color: selected ? colors.accent : colors.textSecondary,
                          fontFamily: 'Vazirmatn',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),

        // Weekly days
        if (isWeeklySelected) ...[
          SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: _weekDays.map((day) {
              final sel = _selectedDays.contains(day['key']);
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    if (sel) {
                      _selectedDays.remove(day['key']);
                    } else {
                      _selectedDays.add(day['key']! as int);
                    }
                  });
                },
                child: AnimatedContainer(
                  duration: Duration(milliseconds: 200),
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: sel ? colors.accent : chipBg,
                    border: Border.all(
                      color: sel ? Colors.transparent : colors.textSecondary.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      day['label']! as String,
                      style: TextStyle(
                        color: sel ? Colors.black : colors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        fontFamily: 'Vazirmatn',
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],

        // Monthly day (Solar / Lunar switcher and day picker)
        if (isMonthlySelected) ...[
          SizedBox(height: 14),
          Container(
            padding: EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: chipBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                _buildCalendarTypeTab('تقویم شمسی', 'MONTHLY', colors, isDark),
                _buildCalendarTypeTab('تقویم قمری', 'LUNAR_MONTHLY', colors, isDark),
              ],
            ),
          ),
          SizedBox(height: 12),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: chipBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: colors.textSecondary.withValues(alpha: 0.08),
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _selectedDays.isNotEmpty &&
                        _selectedDays.first >= 1 &&
                        _selectedDays.first <= 31
                    ? _selectedDays.first
                    : 1,
                dropdownColor: isDark ? colors.surface : colors.sheetBackground,
                iconEnabledColor: colors.accent,
                style: TextStyle(
                    color: colors.textPrimary,
                    fontFamily: 'Vazirmatn',
                    fontSize: 14),
                isExpanded: true,
                onChanged: (v) {
                  if (v != null) setState(() => _selectedDays = [v]);
                },
                items: List.generate(
                  _reminderFrequency == 'MONTHLY' ? 31 : 30,
                  (i) => i + 1,
                ).map((d) {
                  return DropdownMenuItem<int>(
                    value: d,
                    child: Text('روز ${toPersianDigits(d.toString())} ماه'),
                  );
                }).toList(),
              ),
            ),
          ),
        ],

        // ONCE selection date picker
        if (isOnceSelected) ...[
          const SizedBox(height: 14),
          GestureDetector(
            onTap: () async {
              unawaited(HapticFeedback.selectionClick());
              DateTime initial;
              try {
                initial = DateTime.parse(_onceDateStr);
              } catch (_) {
                initial = DateTime.now();
              }
              final picked = await RitmoDatePicker.show(
                context: context,
                initialDate: initial,
                firstDate: DateTime.now().subtract(Duration(days: 365)),
                lastDate: DateTime.now().add(Duration(days: 365 * 5)),
              );
              if (picked != null) {
                setState(() {
                  _onceDateStr = picked.toIso8601String().substring(0, 10);
                });
              }
            },
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: chipBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: colors.textSecondary.withValues(alpha: 0.12),
                ),
              ),
              child: Row(
                children: [
                  Icon(CupertinoIcons.calendar_today, size: 18, color: colors.accent),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'تاریخ یادآوری: ${() {
                        DateTime dt;
                        try {
                          dt = DateTime.parse(_onceDateStr);
                        } catch (_) {
                          dt = DateTime.now();
                        }
                        final jd = Jalali.fromDateTime(dt);
                        return toPersianDigits('${jd.year}/${jd.month.toString().padLeft(2, '0')}/${jd.day.toString().padLeft(2, '0')}');
                      }()}',
                      style: TextStyle(
                        fontSize: 13.5,
                        color: colors.textPrimary,
                        fontFamily: 'Vazirmatn',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(CupertinoIcons.chevron_down, size: 14, color: colors.textSecondary),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ── Step 2: Basis (anchor mode) + nested content ───────
  Widget _buildBasisSection(
      RitmoColors colors, bool isDark, Color chipBg) {
    final modes = [
      {'key': 'NONE',   'label': 'ساعت ثابت',    'icon': CupertinoIcons.clock},
      {'key': 'SHARIA', 'label': 'اوقات شرعی',   'icon': CupertinoIcons.moon_stars},
      {'key': 'SLEEP',  'label': 'برنامه خواب',  'icon': CupertinoIcons.bed_double},
    ];

    final activeMode = _isSharia ? 'SHARIA' : (_isSleep ? 'SLEEP' : 'NONE');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Mode pills
        Row(
          children: modes.map((m) {
            final sel = activeMode == m['key'];
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    if (m['key'] == 'NONE') {
                      _reminderAnchor = 'NONE';
                    } else if (m['key'] == 'SHARIA') {
                      _reminderAnchor = 'FAJR';
                    } else {
                      _reminderAnchor = 'WAKEUP';
                    }
                    _offsetMinutes = 0;
                  });
                },
                child: AnimatedContainer(
                  duration: Duration(milliseconds: 200),
                  margin: EdgeInsets.symmetric(horizontal: 3),
                  padding: EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: sel
                        ? colors.accent.withValues(alpha: 0.15)
                        : chipBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: sel
                          ? colors.accent.withValues(alpha: 0.4)
                          : Colors.transparent,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(m['icon']! as IconData,
                          size: 18,
                          color: sel ? colors.accent : colors.textSecondary),
                      SizedBox(height: 4),
                      Text(
                        m['label']! as String,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: sel
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: sel ? colors.accent : colors.textSecondary,
                          fontFamily: 'Vazirmatn',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),

        SizedBox(height: 16),
        // Divider
        Container(
          height: 1,
          color: colors.textSecondary.withValues(alpha: 0.07),
        ),
        const SizedBox(height: 16),

        // ── FIXED TIME: time chips ─────────────────────
        if (_isFixed) _buildTimeChips(colors, chipBg),

        // ── SHARIA: anchor chips + offset ──────────────
        if (_isSharia) ...[
          _buildAnchorChips(_shariaAnchors, colors, chipBg),
          SizedBox(height: 14),
          _buildOffsetSlider(colors),
        ],

        // ── SLEEP: anchor chips + offset ───────────────
        if (_isSleep) ...[
          _buildAnchorChips(_sleepAnchors, colors, chipBg),
          SizedBox(height: 14),
          _buildOffsetSlider(colors),
        ],
      ],
    );
  }

  // Time chips (shown only for NONE / fixed time)
  Widget _buildTimeChips(RitmoColors colors, Color chipBg) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ساعت‌های یادآوری',
          style: TextStyle(
            fontSize: 12.5,
            color: colors.textSecondary,
            fontFamily: 'Vazirmatn',
          ),
        ),
        SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ..._reminderTimesList.asMap().entries.map((entry) {
              final idx = entry.key;
              final t   = entry.value;
              return GestureDetector(
                onTap: () => _pickTime(idx),
                child: Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: colors.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: colors.accent.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(CupertinoIcons.clock,
                          size: 15, color: colors.accent),
                      SizedBox(width: 6),
                      Text(
                        _fmt(t),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: colors.accent,
                          fontFamily: 'Vazirmatn',
                        ),
                      ),
                      if (_reminderTimesList.length > 1) ...[
                        SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            setState(() =>
                                _reminderTimesList.removeAt(idx));
                          },
                          child: Icon(
                            CupertinoIcons.xmark_circle_fill,
                            size: 16,
                            color: colors.accent.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
            if (_reminderTimesList.length < 5)
              GestureDetector(
                onTap: () => _pickTime(-1),
                child: Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: chipBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: colors.textSecondary
                          .withValues(alpha: 0.1),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(CupertinoIcons.plus,
                          size: 15,
                          color: colors.textSecondary),
                      SizedBox(width: 4),
                      Text(
                        'افزودن ساعت',
                        style: TextStyle(
                          fontSize: 13,
                          color: colors.textSecondary,
                          fontFamily: 'Vazirmatn',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  // Anchor chips (sharia or sleep)
  Widget _buildAnchorChips(
      List<Map<String, String>> anchors,
      RitmoColors colors,
      Color chipBg) {
    return SizedBox(
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: BouncingScrollPhysics(),
        children: anchors.map((a) {
          final sel = _reminderAnchor == a['key'];
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _reminderAnchor = a['key']!);
            },
            child: AnimatedContainer(
              duration: Duration(milliseconds: 200),
              padding:
                  EdgeInsets.symmetric(horizontal: 14),
              margin: EdgeInsets.only(left: 6),
              decoration: BoxDecoration(
                color: sel ? colors.accent : chipBg,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(
                  color: sel
                      ? Colors.transparent
                      : colors.textSecondary
                          .withValues(alpha: 0.1),
                ),
              ),
              child: Center(
                child: Text(
                  '${a['icon']} ${a['label']}',
                  style: TextStyle(
                    color: sel
                        ? Colors.black
                        : colors.textPrimary,
                    fontWeight: sel
                        ? FontWeight.bold
                        : FontWeight.normal,
                    fontSize: 12.5,
                    fontFamily: 'Vazirmatn',
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // Offset slider
  Widget _buildOffsetSlider(RitmoColors colors) {
    final abs = _offsetMinutes.abs();
    final dir = _offsetMinutes >= 0 ? 'بعد از' : 'قبل از';
    final label = _anchorLabel(_reminderAnchor);
    final helperText = abs == 0
        ? 'همزمان با $label'
        : '${toPersianDigits(abs.toString())} دقیقه $dir $label';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            padding:
                EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: colors.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              helperText,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: colors.accent,
                fontFamily: 'Vazirmatn',
              ),
            ),
          ),
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: colors.accent,
            inactiveTrackColor:
                colors.textSecondary.withValues(alpha: 0.08),
            thumbColor: colors.accent,
            overlayColor: colors.accent.withValues(alpha: 0.15),
            trackHeight: 3,
            thumbShape:
                RoundSliderThumbShape(enabledThumbRadius: 7),
          ),
          child: Slider(
            value: _offsetMinutes.toDouble(),
            min: -120,
            max: 180,
            divisions: 60,
            onChanged: (v) =>
                setState(() => _offsetMinutes = v.round()),
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '۱۲۰ دقیقه قبل',
                style: TextStyle(
                  fontSize: 10,
                  color:
                      colors.textSecondary.withValues(alpha: 0.45),
                  fontFamily: 'Vazirmatn',
                ),
              ),
              Text(
                '۱۸۰ دقیقه بعد',
                style: TextStyle(
                  fontSize: 10,
                  color:
                      colors.textSecondary.withValues(alpha: 0.45),
                  fontFamily: 'Vazirmatn',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Step 3: Extra ──────────────────────────────────────
  Widget _buildExtra(RitmoColors colors) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'قضا شدن در صورت عدم انجام',
                style: TextStyle(
                  fontSize: 13.5,
                  color: colors.textPrimary,
                  fontFamily: 'Vazirmatn',
                ),
              ),
              SizedBox(height: 2),
              Text(
                'اگر انجام نشد، به لیست قضا اضافه می‌شود',
                style: TextStyle(
                  fontSize: 11,
                  color: colors.textSecondary,
                  fontFamily: 'Vazirmatn',
                ),
              ),
            ],
          ),
        ),
        CupertinoSwitch(
          value: _allowQada,
          activeTrackColor: colors.accent,
          onChanged: (v) => setState(() => _allowQada = v),
        ),
      ],
    );
  }

  // ── Action buttons ─────────────────────────────────────
  Widget _buildButtons(RitmoColors colors) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(top: 8),
        child: Row(
          children: [
            if (widget.practice.reminderEnabled) ...[
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.vibrate();
                    setState(() => _reminderEnabled = false);
                    _save();
                  },
                  child: Container(
                    padding:
                        EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: colors.medicalRed
                              .withValues(alpha: 0.3)),
                    ),
                    child: Center(
                      child: Text(
                        'حذف یادآوری',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: colors.medicalRed,
                          fontFamily: 'Vazirmatn',
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 10),
            ],
            Expanded(
              flex: 2,
              child: GestureDetector(
                onTap: () {
                  setState(() => _reminderEnabled = true);
                  _save();
                },
                child: Container(
                  padding:
                      EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [colors.accent, colors.accentContainer],
                      begin: Alignment.centerRight,
                      end: Alignment.centerLeft,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: colors.accent.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      'ثبت تنظیمات',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontFamily: 'Vazirmatn',
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
