import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/ritmo_toast.dart';
import 'package:ritmo/core/ux/ritmo_haptics.dart';
import 'package:ritmo/core/ux/ritmo_pressable.dart';
import 'package:ritmo/core/widgets/ritmo_sheet_scaffold.dart';
import 'package:ritmo/features/reflection/models/reflection_models.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:sqflite/sqflite.dart';

class DailyReflectionSheet extends StatefulWidget {
  const DailyReflectionSheet({
    super.key,
    required this.onSaved,
    this.date,
  });

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
      builder: (ctx) => DailyReflectionSheet(
        onSaved: onSaved ?? () {},
        date: date,
      ),
    );
  }

  static String _formatHeaderDate(String? dateStr) {
    final targetStr = dateStr ?? DateTime.now().toIso8601String().substring(0, 10);
    final dt = DateTime.tryParse(targetStr);
    if (dt == null) return '';
    final jalali = Jalali.fromDateTime(dt);
    const months = [
      'فروردین', 'اردیبهشت', 'خرداد',
      'تیر', 'مرداد', 'شهریور',
      'مهر', 'آبان', 'آذر',
      'دی', 'بهمن', 'اسفند'
    ];
    const days = [
      'دوشنبه', 'سه‌شنبه', 'چهارشنبه',
      'پنج‌شنبه', 'جمعه', 'شنبه', 'یک‌شنبه'
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
  final TextEditingController _reflectionController = TextEditingController();
  final TextEditingController _learningsController = TextEditingController();
  final TextEditingController _winsController = TextEditingController();
  final TextEditingController _gratitudeController = TextEditingController();
  final TextEditingController _challengesController = TextEditingController();
  final TextEditingController _tomorrowFocusController = TextEditingController();
  bool _isSaving = false;
  bool _isPrivate = false;

  final List<Map<String, dynamic>> _moodOptions = [
    {
      'score': 1,
      'emoji': '😫',
      'label': 'خیلی بد',
      'color': Colors.redAccent,
    },
    {
      'score': 2,
      'emoji': '🙁',
      'label': 'بد',
      'color': Colors.orangeAccent,
    },
    {
      'score': 3,
      'emoji': '😐',
      'label': 'معمولی',
      'color': Colors.blueAccent,
    },
    {
      'score': 4,
      'emoji': '🙂',
      'label': 'خوب',
      'color': Colors.lightGreen,
    },
    {
      'score': 5,
      'emoji': '🤩',
      'label': 'عالی',
      'color': Colors.amber,
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadExistingData();
  }

  @override
  void dispose() {
    _reflectionController.dispose();
    _learningsController.dispose();
    _winsController.dispose();
    _gratitudeController.dispose();
    _challengesController.dispose();
    _tomorrowFocusController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingData() async {
    final targetDate = widget.date ?? DateTime.now().toIso8601String().substring(0, 10);
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
          _reflectionController.text = entry.reflectionText ?? '';
          _learningsController.text = entry.learnings ?? '';
          _winsController.text = entry.wins ?? '';
          _gratitudeController.text = entry.gratitude ?? '';
          _challengesController.text = entry.challenges ?? '';
          _tomorrowFocusController.text = entry.tomorrowFocus ?? '';
          _isPrivate = entry.isPrivate == 1;
        });
      }
    } catch (e) {
      debugPrint('Error loading existing reflection: $e');
    }
  }

  Future<void> _saveReflection() async {
    setState(() {
      _isSaving = true;
    });

    try {
      final db = await DatabaseHelper.instance.database;
      final todayStr = widget.date ?? DateTime.now().toIso8601String().substring(0, 10);
      final nowMs = DateTime.now().millisecondsSinceEpoch;

      final entry = ReflectionEntry(
        date: todayStr,
        moodScore: _moodScore,
        reflectionText: _reflectionController.text.trim().isNotEmpty ? _reflectionController.text.trim() : null,
        learnings: _learningsController.text.trim().isNotEmpty ? _learningsController.text.trim() : null,
        gratitude: _gratitudeController.text.trim().isNotEmpty ? _gratitudeController.text.trim() : null,
        wins: _winsController.text.trim().isNotEmpty ? _winsController.text.trim() : null,
        challenges: _challengesController.text.trim().isNotEmpty ? _challengesController.text.trim() : null,
        tomorrowFocus: _tomorrowFocusController.text.trim().isNotEmpty ? _tomorrowFocusController.text.trim() : null,
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
          'تأمل روزانه شما با موفقیت ثبت شد 🌙',
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
        setState(() {
          _isSaving = false;
        });
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
              // Mood Rating Score
              Text(
                'حالت روحی امروز شما چطور بود؟',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: RitmoSpacing.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                          setState(() {
                            _moodScore = score;
                          });
                        },
                        semanticLabel: opt['label'] as String,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? optColor.withValues(alpha: isDark ? 0.22 : 0.14)
                                : colors.surfaceSunken.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(RitmoRadius.card),
                            border: Border.all(
                              color: isSelected
                                  ? optColor
                                  : colors.border.withValues(alpha: 0.6),
                              width: isSelected ? 1.5 : 1.0,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                opt['emoji'] as String,
                                style: const TextStyle(fontSize: 22),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                opt['label'] as String,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
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
              const SizedBox(height: RitmoSpacing.lg),

              // Wins Note
              _buildInputField(
                controller: _winsController,
                label: '🏆 بردها و دستاوردهای امروز (چه کارهایی خوب پیش رفت؟)',
                hint: 'مثال: اتمام فاز اول پروژه، ورزش کردن، تمرکز خوب...',
                maxLines: 2,
                colors: colors,
                isDark: isDark,
              ),
              const SizedBox(height: RitmoSpacing.md),

              // Gratitude Note
              _buildInputField(
                controller: _gratitudeController,
                label: '💖 شکرگزاری (بابت چه چیزهایی در امروز سپاس‌گزارید؟)',
                hint: 'مثال: صحبت با یک دوست قدیمی، هوای خوب، سلامتی...',
                maxLines: 2,
                colors: colors,
                isDark: isDark,
              ),
              const SizedBox(height: RitmoSpacing.md),

              // Challenges Note
              _buildInputField(
                controller: _challengesController,
                label: '⚡ چالش‌ها و دشواری‌ها (چه چیزهایی سخت بود؟)',
                hint: 'مثال: حواس‌پرتی، کمبود خواب، بحث با همکار...',
                maxLines: 2,
                colors: colors,
                isDark: isDark,
              ),
              const SizedBox(height: RitmoSpacing.md),

              // Learnings Note
              _buildInputField(
                controller: _learningsController,
                label: '📚 درس‌های آموخته‌شده (امروز چه چیزی یاد گرفتید؟)',
                hint: 'مثال: نیاز به استراحت منظم دارم، برنامه‌ریزی واقع‌بینانه‌تر...',
                maxLines: 2,
                colors: colors,
                isDark: isDark,
              ),
              const SizedBox(height: RitmoSpacing.md),

              // Tomorrow Focus Note
              _buildInputField(
                controller: _tomorrowFocusController,
                label: '🎯 تمرکز اصلی فردا (مهم‌ترین کار برای فردا چیست؟)',
                hint: 'مثال: حل مسئله پیچیده الگوریتم، خواب زودتر...',
                maxLines: 2,
                colors: colors,
                isDark: isDark,
              ),
              const SizedBox(height: RitmoSpacing.md),

              // Reflection Note
              _buildInputField(
                controller: _reflectionController,
                label: '📝 یادداشت و بازتاب آزاد (هر چیزی که دوست دارید بنویسید)',
                hint: 'مثال: جریان کلی روز، احساسات و تحلیل شخصی...',
                maxLines: 3,
                colors: colors,
                isDark: isDark,
              ),
              const SizedBox(height: RitmoSpacing.md),

              // Privacy Switch
              Container(
                padding: const EdgeInsets.symmetric(horizontal: RitmoSpacing.sm, vertical: RitmoSpacing.xs),
                decoration: BoxDecoration(
                  color: colors.surfaceSunken.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(RitmoRadius.card),
                  border: Border.all(color: colors.border.withValues(alpha: 0.5)),
                ),
                child: SwitchListTile(
                  title: Text(
                    'پنهان کردن از هوش مصنوعی (یادداشت محرمانه)',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    'با فعال کردن این گزینه، اطلاعات این بازتاب صرفاً روی دستگاه شما می‌ماند.',
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
                  activeColor: colors.primary,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const SizedBox(height: RitmoSpacing.lg),

              // Submit Button
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(RitmoRadius.button),
                  ),
                ),
                onPressed: _isSaving ? null : _saveReflection,
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'ثبت و ذخیرهٔ تأمل روزانه',
                        style: TextStyle(
                          fontSize: 14,
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

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required int maxLines,
    required RitmoColors colors,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          style: TextStyle(color: colors.textPrimary, fontSize: 13),
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: colors.textTertiary.withValues(alpha: 0.6),
              fontSize: 11.5,
            ),
            fillColor: colors.surfaceSunken,
            filled: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(RitmoRadius.card),
              borderSide: BorderSide(color: colors.border.withValues(alpha: 0.6)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(RitmoRadius.card),
              borderSide: BorderSide(color: colors.primary, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
