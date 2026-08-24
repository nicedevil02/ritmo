import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/ritmo_toast.dart';
import 'package:ritmo/core/ux/ritmo_pressable.dart';
import 'package:ritmo/features/reflection/models/reflection_models.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:sqflite/sqflite.dart';

class DailyReflectionSheet extends StatefulWidget {
  const DailyReflectionSheet({super.key, required this.onSaved, this.date});

  final VoidCallback onSaved;
  final String? date;

  /// متد استاندارد باز کردن شیت تأمل روزانه با پوسته یکپارچه شیشه‌ای ریتمو
  static Future<void> show({
    required BuildContext context,
    VoidCallback? onSaved,
    String? date,
  }) {
    RitmoHapticsPolicy.selection();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) =>
          DailyReflectionSheet(onSaved: onSaved ?? () {}, date: date),
    );
  }

  static String _formatHeaderDate(String? dateStr) {
    final targetStr =
        dateStr ?? DateTime.now().toIso8601String().substring(0, 10);
    final dt = DateTime.tryParse(targetStr);
    if (dt == null) return '';
    final jalali = Jalali.fromDateTime(dt);
    const months = [
      'فروردین',
      'اردیبهشت',
      'خرداد',
      'تیر',
      'مرداد',
      'شهریور',
      'مهر',
      'آبان',
      'آذر',
      'دی',
      'بهمن',
      'اسفند',
    ];
    const days = [
      'دوشنبه',
      'سه‌شنبه',
      'چهارشنبه',
      'پنج‌شنبه',
      'جمعه',
      'شنبه',
      'یک‌شنبه',
    ];
    final dayName = days[dt.weekday - 1];
    final monthName = months[jalali.month - 1];
    return '$dayName، ${jalali.day} $monthName';
  }

  @override
  State<DailyReflectionSheet> createState() => _DailyReflectionSheetState();
}

class _DailyReflectionSheetState extends State<DailyReflectionSheet> {
  int _moodScore = 3;
  final TextEditingController _winsController = TextEditingController();
  final TextEditingController _gratitudeController = TextEditingController();
  final TextEditingController _challengesController = TextEditingController();
  final TextEditingController _learningsController = TextEditingController();
  final TextEditingController _tomorrowFocusController =
      TextEditingController();
  final TextEditingController _reflectionController = TextEditingController();
  bool _isSaving = false;
  bool _isPrivate = false;

  final List<Map<String, dynamic>> _moodOptions = const [
    {'score': 1, 'emoji': '😫', 'label': 'خیلی بد'},
    {'score': 2, 'emoji': '🙁', 'label': 'بد'},
    {'score': 3, 'emoji': '😐', 'label': 'معمولی'},
    {'score': 4, 'emoji': '🙂', 'label': 'خوب'},
    {'score': 5, 'emoji': '🤩', 'label': 'عالی'},
  ];

  @override
  void initState() {
    super.initState();
    _loadExistingData();
  }

  @override
  void dispose() {
    _winsController.dispose();
    _gratitudeController.dispose();
    _challengesController.dispose();
    _learningsController.dispose();
    _tomorrowFocusController.dispose();
    _reflectionController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingData() async {
    final targetDate =
        widget.date ?? DateTime.now().toIso8601String().substring(0, 10);
    try {
      final db = await DatabaseHelper.instance.database;
      final maps = await db.query(
        'daily_reflections',
        where: 'date = ?',
        whereArgs: [targetDate],
      );
      if (maps.isNotEmpty && mounted) {
        final entry = ReflectionEntry.fromMap(maps.first);
        setState(() {
          _moodScore = entry.moodScore;
          _winsController.text = entry.wins ?? '';
          _gratitudeController.text = entry.gratitude ?? '';
          _challengesController.text = entry.challenges ?? '';
          _learningsController.text = entry.learnings ?? '';
          _tomorrowFocusController.text = entry.tomorrowFocus ?? '';
          _reflectionController.text = entry.reflectionText ?? '';
          _isPrivate = entry.isPrivate == 1;
        });
      }
    } catch (e) {
      debugPrint('Error loading existing reflection: $e');
    }
  }

  Future<void> _saveReflection() async {
    setState(() => _isSaving = true);

    try {
      final db = await DatabaseHelper.instance.database;
      final todayStr =
          widget.date ?? DateTime.now().toIso8601String().substring(0, 10);
      final nowMs = DateTime.now().millisecondsSinceEpoch;

      final entry = ReflectionEntry(
        date: todayStr,
        moodScore: _moodScore,
        reflectionText: _reflectionController.text.trim().isNotEmpty
            ? _reflectionController.text.trim()
            : null,
        learnings: _learningsController.text.trim().isNotEmpty
            ? _learningsController.text.trim()
            : null,
        gratitude: _gratitudeController.text.trim().isNotEmpty
            ? _gratitudeController.text.trim()
            : null,
        wins: _winsController.text.trim().isNotEmpty
            ? _winsController.text.trim()
            : null,
        challenges: _challengesController.text.trim().isNotEmpty
            ? _challengesController.text.trim()
            : null,
        tomorrowFocus: _tomorrowFocusController.text.trim().isNotEmpty
            ? _tomorrowFocusController.text.trim()
            : null,
        isPrivate: _isPrivate ? 1 : 0,
        createdAt: nowMs,
      );

      await db.insert(
        'daily_reflections',
        entry.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      RitmoHapticsPolicy.success();
      widget.onSaved();
      if (mounted) {
        Navigator.pop(context);
        RitmoToast.show(
          context,
          'تأمل روزانه شما با موفقیت ثبت شد ✨',
          icon: CupertinoIcons.checkmark_circle_fill,
        );
      }
    } catch (e) {
      debugPrint('Error saving daily reflection: $e');
      if (mounted) {
        RitmoToast.show(
          context,
          'خطا در ثبت تأمل روزانه',
          icon: CupertinoIcons.exclamationmark_circle,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Color _getMoodColor(int score, RitmoColors colors) {
    switch (score) {
      case 1:
        return colors.error;
      case 2:
        return colors.warning;
      case 3:
        return colors.primary;
      case 4:
        return colors.success;
      case 5:
        return colors.accent;
      default:
        return colors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dateStr = DailyReflectionSheet._formatHeaderDate(widget.date);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.88,
              ),
              decoration: BoxDecoration(
                color: isDark
                    ? colors.surfaceElevated.withValues(alpha: 0.86)
                    : colors.surface.withValues(alpha: 0.92),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                border: Border.all(
                  color: colors.border.withValues(alpha: isDark ? 0.35 : 0.55),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: colors.shadow.withValues(alpha: isDark ? 0.35 : 0.1),
                    blurRadius: 28,
                    offset: const Offset(0, -6),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Minimal Grabber Bar
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 8, bottom: 4),
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: colors.textTertiary.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Compact, Low-Profile Header
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: colors.primary.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.nightlight_round,
                            size: 16,
                            color: colors.primary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Row(
                            children: [
                              Text(
                                'تأمل و ارزیابی روزانه',
                                style: TextStyle(
                                  fontFamily: 'Vazirmatn',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: colors.textPrimary,
                                ),
                              ),
                              if (dateStr.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colors.surfaceSunken.withValues(
                                      alpha: 0.7,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: colors.border.withValues(
                                        alpha: 0.4,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    dateStr,
                                    style: TextStyle(
                                      fontFamily: 'Vazirmatn',
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w500,
                                      color: colors.textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: Icon(
                            Icons.close,
                            size: 18,
                            color: colors.textSecondary,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                          tooltip: 'بستن',
                        ),
                      ],
                    ),
                  ),
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: colors.border.withValues(alpha: 0.35),
                  ),

                  // Scrollable Body (Edge-to-Edge with 14px padding)
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 1. Mood Selector (Compact 5-Column Row)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: colors.surfaceSunken.withValues(
                                alpha: isDark ? 0.35 : 0.55,
                              ),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: colors.border.withValues(
                                  alpha: isDark ? 0.3 : 0.5,
                                ),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(
                                    right: 4,
                                    bottom: 8,
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.sentiment_satisfied_alt_rounded,
                                        size: 15,
                                        color: colors.primary,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'حس و حال کلی امروز:',
                                        style: TextStyle(
                                          fontFamily: 'Vazirmatn',
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                          color: colors.textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Row(
                                  children: _moodOptions.map((opt) {
                                    final score = opt['score'] as int;
                                    final isSelected = _moodScore == score;
                                    final moodColor = _getMoodColor(
                                      score,
                                      colors,
                                    );

                                    return Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 2.5,
                                        ),
                                        child: RitmoPressable(
                                          onTap: () {
                                            RitmoHapticsPolicy.selection();
                                            setState(() => _moodScore = score);
                                          },
                                          semanticLabel: opt['label'] as String,
                                          child: AnimatedContainer(
                                            duration: const Duration(
                                              milliseconds: 160,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: isSelected
                                                  ? moodColor.withValues(
                                                      alpha: isDark
                                                          ? 0.25
                                                          : 0.16,
                                                    )
                                                  : colors.surface.withValues(
                                                      alpha: 0.5,
                                                    ),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              border: Border.all(
                                                color: isSelected
                                                    ? moodColor
                                                    : colors.border.withValues(
                                                        alpha: 0.4,
                                                      ),
                                                width: isSelected ? 1.5 : 0.9,
                                              ),
                                            ),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  opt['emoji'] as String,
                                                  style: TextStyle(
                                                    fontSize: isSelected
                                                        ? 20
                                                        : 17,
                                                  ),
                                                ),
                                                const SizedBox(height: 3),
                                                Text(
                                                  opt['label'] as String,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
                                                    fontFamily: 'Vazirmatn',
                                                    fontSize: 9.5,
                                                    fontWeight: isSelected
                                                        ? FontWeight.w800
                                                        : FontWeight.w500,
                                                    color: isSelected
                                                        ? (isDark
                                                              ? Colors.white
                                                              : moodColor)
                                                        : colors.textSecondary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),

                          // 2. Wins & Achievements
                          _buildFieldTile(
                            controller: _winsController,
                            title: 'بردها و دستاوردهای امروز',
                            hint:
                                'چه کارهایی خوب پیش رفت؟ (اتمام کار مهم، ورزش، تمرکز...)',
                            icon: Icons.emoji_events_rounded,
                            accentColor: colors.warning,
                            colors: colors,
                            isDark: isDark,
                          ),
                          const SizedBox(height: 8),

                          // 3. Gratitude
                          _buildFieldTile(
                            controller: _gratitudeController,
                            title: 'شکرگزاری امروز',
                            hint:
                                'بابت چه چیزهایی سپاس‌گزارید؟ (مکالمه خوب، سلامتی، آرامش...)',
                            icon: Icons.favorite_rounded,
                            accentColor: colors.error,
                            colors: colors,
                            isDark: isDark,
                          ),
                          const SizedBox(height: 8),

                          // 4. Challenges
                          _buildFieldTile(
                            controller: _challengesController,
                            title: 'چالش‌ها و موانع',
                            hint:
                                'چه چیزهایی سخت بود یا انرژی گرفت؟ (خستگی، حواس‌پرتی...)',
                            icon: Icons.bolt_rounded,
                            accentColor: colors.warning,
                            colors: colors,
                            isDark: isDark,
                          ),
                          const SizedBox(height: 8),

                          // 5. Learnings
                          _buildFieldTile(
                            controller: _learningsController,
                            title: 'درس‌های آموخته‌شده',
                            hint:
                                'امروز چه درسی گرفتید؟ (نیاز به استراحت، برنامه‌ریزی بهتر...)',
                            icon: Icons.menu_book_rounded,
                            accentColor: colors.primary,
                            colors: colors,
                            isDark: isDark,
                          ),
                          const SizedBox(height: 8),

                          // 6. Tomorrow Focus
                          _buildFieldTile(
                            controller: _tomorrowFocusController,
                            title: 'تمرکز اصلی فردا',
                            hint:
                                'مهم‌ترین اولویت فردا چیست؟ (پروژه اصلی، خواب به‌موقع...)',
                            icon: Icons.track_changes_rounded,
                            accentColor: colors.success,
                            colors: colors,
                            isDark: isDark,
                          ),
                          const SizedBox(height: 8),

                          // 7. Free Reflection
                          _buildFieldTile(
                            controller: _reflectionController,
                            title: 'یادداشت و تحلیل آزاد',
                            hint: 'هر نکته، دلنوشته یا جریانی از افکار روز...',
                            icon: Icons.edit_note_rounded,
                            accentColor: colors.primary,
                            colors: colors,
                            isDark: isDark,
                            maxLines: 3,
                          ),
                          const SizedBox(height: 10),

                          // Privacy Switch
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: colors.surfaceSunken.withValues(
                                alpha: isDark ? 0.35 : 0.55,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: colors.border.withValues(
                                  alpha: isDark ? 0.3 : 0.45,
                                ),
                              ),
                            ),
                            child: SwitchListTile(
                              title: Row(
                                children: [
                                  Icon(
                                    _isPrivate
                                        ? Icons.lock_rounded
                                        : Icons.lock_open_rounded,
                                    size: 15,
                                    color: _isPrivate
                                        ? colors.primary
                                        : colors.textSecondary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'یادداشت محرمانه (عدم تحلیل توسط AI)',
                                    style: TextStyle(
                                      fontFamily: 'Vazirmatn',
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: colors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Text(
                                'صرفاً روی حافظهٔ دستگاه شما باقی می‌ماند.',
                                style: TextStyle(
                                  fontFamily: 'Vazirmatn',
                                  fontSize: 10,
                                  color: colors.textSecondary,
                                ),
                              ),
                              value: _isPrivate,
                              onChanged: (val) {
                                RitmoHapticsPolicy.selection();
                                setState(() => _isPrivate = val);
                              },
                              activeTrackColor: colors.primary,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Submit Button
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colors.primary,
                              foregroundColor: colors.onPrimary,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: _isSaving ? null : _saveReflection,
                            icon: _isSaving
                                ? SizedBox(
                                    height: 16,
                                    width: 16,
                                    child: CircularProgressIndicator(
                                      color: colors.onPrimary,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(
                                    Icons.check_circle_rounded,
                                    size: 18,
                                  ),
                            label: Text(
                              _isSaving
                                  ? 'در حال ذخیره‌سازی...'
                                  : 'ثبت و ذخیرهٔ تأمل روزانه',
                              style: const TextStyle(
                                fontFamily: 'Vazirmatn',
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFieldTile({
    required TextEditingController controller,
    required String title,
    required String hint,
    required IconData icon,
    required Color accentColor,
    required RitmoColors colors,
    required bool isDark,
    int maxLines = 2,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: colors.surfaceSunken.withValues(alpha: isDark ? 0.35 : 0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colors.border.withValues(alpha: isDark ? 0.28 : 0.45),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accentColor, size: 15),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontFamily: 'Vazirmatn',
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            style: TextStyle(
              fontFamily: 'Vazirmatn',
              color: colors.textPrimary,
              fontSize: 12,
            ),
            maxLines: maxLines,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                fontFamily: 'Vazirmatn',
                color: colors.textTertiary.withValues(alpha: 0.6),
                fontSize: 10.5,
              ),
              fillColor: colors.surface.withValues(alpha: isDark ? 0.5 : 0.8),
              filled: true,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 8,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: colors.border.withValues(alpha: isDark ? 0.25 : 0.4),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: accentColor, width: 1.3),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
