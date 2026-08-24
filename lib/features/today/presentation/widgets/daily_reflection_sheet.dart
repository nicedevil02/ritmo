import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/ritmo_toast.dart';
import 'package:ritmo/core/ux/ritmo_pressable.dart';
import 'package:ritmo/core/widgets/ritmo_sheet_scaffold.dart';
import 'package:ritmo/features/reflection/models/reflection_models.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:sqflite/sqflite.dart';

class DailyReflectionSheet extends StatefulWidget {
  const DailyReflectionSheet({super.key, required this.onSaved, this.date});

  final VoidCallback onSaved;
  final String? date;

  /// متد استاندارد باز کردن شیت تأمل روزانه با پوسته یکپارچه ریتمو
  static Future<void> show({
    required BuildContext context,
    VoidCallback? onSaved,
    String? date,
  }) {
    final subtitle = _formatHeaderDate(date);
    return RitmoSheetScaffold.present(
      context: context,
      title: 'تأمل و ارزیابی روزانه 🌙',
      subtitle: subtitle,
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
    return '$dayName، ${jalali.day} $monthName ${jalali.year}';
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
    {'score': 1, 'emoji': '😫', 'label': 'خیلی بد', 'color': Color(0xFFEF4444)},
    {'score': 2, 'emoji': '🙁', 'label': 'بد', 'color': Color(0xFFF97316)},
    {'score': 3, 'emoji': '😐', 'label': 'معمولی', 'color': Color(0xFF3B82F6)},
    {'score': 4, 'emoji': '🙂', 'label': 'خوب', 'color': Color(0xFF10B981)},
    {'score': 5, 'emoji': '🤩', 'label': 'عالی', 'color': Color(0xFFF59E0B)},
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

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          RitmoSpacing.lg,
          RitmoSpacing.xs,
          RitmoSpacing.lg,
          MediaQuery.of(context).viewInsets.bottom + RitmoSpacing.xl,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Mood Selector Section
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: colors.border.withValues(alpha: isDark ? 0.4 : 0.7),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.sentiment_satisfied_alt_rounded,
                          size: 18,
                          color: colors.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'حالت روحی و حس کلی امروز',
                          style: TextStyle(
                            fontFamily: 'Vazirmatn',
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: colors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: _moodOptions.map((opt) {
                        final score = opt['score'] as int;
                        final isSelected = _moodScore == score;
                        final optColor = opt['color'] as Color;

                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            child: RitmoPressable(
                              onTap: () {
                                RitmoHapticsPolicy.selection();
                                setState(() => _moodScore = score);
                              },
                              semanticLabel: opt['label'] as String,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? optColor.withValues(
                                          alpha: isDark ? 0.25 : 0.16,
                                        )
                                      : colors.surfaceSunken.withValues(
                                          alpha: 0.6,
                                        ),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected
                                        ? optColor
                                        : colors.border.withValues(alpha: 0.5),
                                    width: isSelected ? 1.6 : 1.0,
                                  ),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      opt['emoji'] as String,
                                      style: TextStyle(
                                        fontSize: isSelected ? 22 : 19,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      opt['label'] as String,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontFamily: 'Vazirmatn',
                                        fontSize: 10,
                                        fontWeight: isSelected
                                            ? FontWeight.w800
                                            : FontWeight.w500,
                                        color: isSelected
                                            ? (isDark ? Colors.white : optColor)
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
              const SizedBox(height: RitmoSpacing.md),

              // 1. Wins & Achievements
              _buildReflectionCard(
                controller: _winsController,
                title: 'بردها و دستاوردهای امروز',
                subtitle: 'چه کارهایی خوب پیش رفت یا به ثمر نشست؟',
                hint: 'مثال: اتمام کار مهم، تمرکز عالی، ورزش، حس مفید بودن...',
                icon: Icons.emoji_events_rounded,
                accentColor: const Color(0xFFF59E0B),
                colors: colors,
                isDark: isDark,
              ),
              const SizedBox(height: RitmoSpacing.sm),

              // 2. Gratitude
              _buildReflectionCard(
                controller: _gratitudeController,
                title: 'شکرگزاری امروز',
                subtitle: 'بابت چه نعمت‌ها یا رویدادهایی سپاس‌گزارید؟',
                hint: 'مثال: مکالمه با دوست قدیمی، هوای عالی، سلامتی، آرامش...',
                icon: Icons.favorite_rounded,
                accentColor: const Color(0xFFEC4899),
                colors: colors,
                isDark: isDark,
              ),
              const SizedBox(height: RitmoSpacing.sm),

              // 3. Challenges
              _buildReflectionCard(
                controller: _challengesController,
                title: 'چالش‌ها و دشواری‌ها',
                subtitle: 'چه مسائلی انرژی شما را گرفت یا سخت گذشت؟',
                hint: 'مثال: حواس‌پرتی، کمبود خواب، خستگی، بحث یا استرس...',
                icon: Icons.bolt_rounded,
                accentColor: const Color(0xFFF97316),
                colors: colors,
                isDark: isDark,
              ),
              const SizedBox(height: RitmoSpacing.sm),

              // 4. Learnings
              _buildReflectionCard(
                controller: _learningsController,
                title: 'درس‌های آموخته‌شده',
                subtitle: 'امروز چه تجربه، مهارت یا درسی یاد گرفتید؟',
                hint:
                    'مثال: برنامه‌ریزی واقع‌بینانه‌تر، نیاز به استراحت منظم...',
                icon: Icons.menu_book_rounded,
                accentColor: const Color(0xFF6366F1),
                colors: colors,
                isDark: isDark,
              ),
              const SizedBox(height: RitmoSpacing.sm),

              // 5. Tomorrow Focus
              _buildReflectionCard(
                controller: _tomorrowFocusController,
                title: 'تمرکز اصلی فردا',
                subtitle: 'مهم‌ترین سنگ بزرگ یا اولویت برای فردا چیست؟',
                hint:
                    'مثال: آغاز پروژه اصلی، خواب به‌موقع، پیگیری کار عقب‌مانده...',
                icon: Icons.track_changes_rounded,
                accentColor: const Color(0xFF10B981),
                colors: colors,
                isDark: isDark,
              ),
              const SizedBox(height: RitmoSpacing.sm),

              // 6. Free Reflection Note
              _buildReflectionCard(
                controller: _reflectionController,
                title: 'یادداشت و جریان ذهن آزاد',
                subtitle: 'هر احساس، تحلیل یا نوشته‌ای که دوست دارید ثبت کنید',
                hint: 'امروز به‌طور کلی چطور گذشت...',
                icon: Icons.edit_note_rounded,
                accentColor: const Color(0xFF8B5CF6),
                colors: colors,
                isDark: isDark,
                maxLines: 3,
              ),
              const SizedBox(height: RitmoSpacing.md),

              // Privacy Card
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: colors.border.withValues(alpha: isDark ? 0.3 : 0.6),
                  ),
                ),
                child: SwitchListTile(
                  title: Row(
                    children: [
                      Icon(
                        _isPrivate
                            ? Icons.lock_rounded
                            : Icons.lock_open_rounded,
                        size: 16,
                        color: _isPrivate
                            ? colors.primary
                            : colors.textSecondary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'یادداشت محرمانه (عدم تحلیل توسط هوش مصنوعی)',
                        style: TextStyle(
                          fontFamily: 'Vazirmatn',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  subtitle: Text(
                    'با فعال کردن این گزینه، اطلاعات این بازتاب صرفاً به‌صورت محلی روی دستگاه باقی می‌ماند.',
                    style: TextStyle(
                      fontFamily: 'Vazirmatn',
                      fontSize: 10.5,
                      color: colors.textSecondary,
                    ),
                  ),
                  value: _isPrivate,
                  onChanged: (val) {
                    RitmoHapticsPolicy.selection();
                    setState(() => _isPrivate = val);
                  },
                  activeThumbColor: colors.primary,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const SizedBox(height: RitmoSpacing.lg),

              // Submit Button
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: colors.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: _isSaving ? null : _saveReflection,
                icon: _isSaving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.check_circle_rounded, size: 20),
                label: Text(
                  _isSaving
                      ? 'در حال ذخیره‌سازی...'
                      : 'ثبت و ذخیرهٔ تأمل روزانه',
                  style: const TextStyle(
                    fontFamily: 'Vazirmatn',
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReflectionCard({
    required TextEditingController controller,
    required String title,
    required String subtitle,
    required String hint,
    required IconData icon,
    required Color accentColor,
    required RitmoColors colors,
    required bool isDark,
    int maxLines = 2,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colors.border.withValues(alpha: isDark ? 0.35 : 0.6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: isDark ? 0.2 : 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: accentColor, size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: 'Vazirmatn',
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontFamily: 'Vazirmatn',
                        fontSize: 10,
                        fontWeight: FontWeight.w400,
                        color: colors.textSecondary.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            style: TextStyle(
              fontFamily: 'Vazirmatn',
              color: colors.textPrimary,
              fontSize: 12.5,
            ),
            maxLines: maxLines,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                fontFamily: 'Vazirmatn',
                color: colors.textTertiary.withValues(alpha: 0.65),
                fontSize: 11,
              ),
              fillColor: colors.surfaceSunken.withValues(alpha: 0.5),
              filled: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: colors.border.withValues(alpha: isDark ? 0.25 : 0.45),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: accentColor, width: 1.4),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
