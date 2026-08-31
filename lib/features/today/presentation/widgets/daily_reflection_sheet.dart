import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/ritmo_toast.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_button.dart';
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
    final isDark = context.isDark;
    final dateStr = DailyReflectionSheet._formatHeaderDate(widget.date);
    const sheetRadius = BorderRadius.vertical(top: Radius.circular(28));

    final sheetContent = ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: RitmoBreakpoints.sheetMaxHeight(context, factor: 0.94),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: colors.border.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Symmetrical Glass Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                RitmoNeuButton(
                  onTap: () => Navigator.pop(context),
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    CupertinoIcons.xmark,
                    size: 16,
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        CupertinoIcons.moon_stars_fill,
                        size: 17,
                        color: colors.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'تأمل و ارزیابی روزانه',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: colors.textPrimary,
                        ),
                      ),
                      if (dateStr.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: colors.surfaceSunken,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: colors.border.withValues(alpha: 0.5),
                            ),
                          ),
                          child: Text(
                            dateStr,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: colors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 36), // Symmetrical balancing
              ],
            ),
          ),
          Divider(
            height: 1,
            thickness: 1,
            color: colors.divider,
          ),

          // Scrollable Body
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Mood Selector
                  RitmoCard.neumorphic(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 2, bottom: 8),
                          child: Row(
                            children: [
                              Icon(
                                CupertinoIcons.heart_fill,
                                size: 16,
                                color: colors.reflectionAccent,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'حس و حال کلی امروز:',
                                style: TextStyle(
                                  fontSize: 12,
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
                            final moodColor = _getMoodColor(score, colors);

                            return Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 2.5),
                                child: RitmoCard.neumorphic(
                                  isSelected: isSelected,
                                  onTap: () {
                                    RitmoHapticsPolicy.selection();
                                    setState(() => _moodScore = score);
                                  },
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        opt['emoji'] as String,
                                        style: TextStyle(
                                          fontSize: isSelected ? 20 : 17,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        opt['label'] as String,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: isSelected
                                              ? FontWeight.w800
                                              : FontWeight.w500,
                                          color: isSelected
                                              ? moodColor
                                              : colors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 2. Day highlights (Wins)
                  _buildFieldTile(
                    controller: _winsController,
                    title: 'دستاوردهای امروز (حتی کوچک)',
                    hint: 'امروز چه کاری رو خوب انجام دادی؟',
                    icon: CupertinoIcons.sparkles,
                    accentColor: const Color(0xFFF59E0B),
                    colors: colors,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 10),

                  // 3. Difficulties & Friction
                  _buildFieldTile(
                    controller: _challengesController,
                    title: 'چالش‌ها یا اصطکاک‌های امروز',
                    hint: 'کجا حس کردی انرژی یا تمرکزت افت کرد؟',
                    icon: CupertinoIcons.flame_fill,
                    accentColor: colors.error,
                    colors: colors,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 10),

                  // 4. Learnings & Notes
                  _buildFieldTile(
                    controller: _learningsController,
                    title: 'یادگیری‌ها یا یادداشت آزاد',
                    hint: 'نکته‌ای که برای روزهای آینده به دردت می‌خوره...',
                    icon: CupertinoIcons.lightbulb_fill,
                    accentColor: colors.primary,
                    colors: colors,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 10),

                  // 5. Tomorrow's main intention
                  _buildFieldTile(
                    controller: _tomorrowFocusController,
                    title: 'تمرکز اصلی فردا',
                    hint: 'یک کاری که فردا اولویت اصلیته چیه؟',
                    icon: CupertinoIcons.arrow_right_circle_fill,
                    accentColor: colors.secondary,
                    colors: colors,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 12),

                  // 6. Privacy toggle
                  RitmoCard.neumorphic(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: SwitchListTile(
                      title: Text(
                        'ثبت خصوصی (محرمانه)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary,
                        ),
                      ),
                      subtitle: Text(
                        'صرفاً روی حافظهٔ دستگاه شما باقی می‌ماند.',
                        style: TextStyle(
                          fontSize: 10.5,
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
                  const SizedBox(height: 16),

                  // Submit Button
                  RitmoPrimaryButton(
                    label: 'ثبت و ذخیرهٔ تأمل روزانه',
                    isLoading: _isSaving,
                    onPressed: _isSaving ? null : _saveReflection,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: RitmoGlassSheet(
          borderRadius: sheetRadius,
          child: sheetContent,
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
    return RitmoCard.neumorphicSunken(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accentColor, size: 16),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
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
              color: colors.textPrimary,
              fontSize: 12.5,
            ),
            maxLines: maxLines,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: colors.textTertiary.withValues(alpha: 0.7),
                fontSize: 11,
              ),
              border: InputBorder.none,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
