// lib/features/supplementary_sports/presentation/ss_exercise_library_screen.dart

import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/supplementary_sports/presentation/widgets/shared/ss_lottie_player.dart';
import 'package:url_launcher/url_launcher.dart';

class SSExerciseLibraryScreen extends StatefulWidget {
  const SSExerciseLibraryScreen({
    super.key,
    this.embedded = false,
    this.onExerciseAdded,
  });

  /// وقتی داخل تب «کتابخانه» میزبانی می‌شود، نباید Scaffold و AppBar و دکمهٔ
  /// بازگشت دوم بسازد؛ میزبان خودش هدر دارد.
  final bool embedded;

  /// تا میزبان بتواند پس از افزودن حرکت به برنامه، خودش را تازه کند.
  final VoidCallback? onExerciseAdded;

  @override
  State<SSExerciseLibraryScreen> createState() => _SSExerciseLibraryScreenState();
}

class _SSExerciseLibraryScreenState extends State<SSExerciseLibraryScreen> {
  List<Map<String, dynamic>> _allExercises = [];
  List<Map<String, dynamic>> _filteredExercises = [];
  List<String> _categories = ['all'];
  String _selectedCategory = 'all';
  String _searchQuery = '';
  bool _isLoading = true;
  String? _loadError;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadExercises();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _normalizeCategoryKey(String? rawCategory) {
    final clean = (rawCategory ?? '').toLowerCase().trim();
    // ── Fitify native keys ────────────────────────────────
    if (clean == 'upper_body') return 'chest'; // شنا / بالاتنه
    if (clean == 'shoulder_and_back') return 'back'; // کمر / زیربغل
    if (clean == 'lower_body') return 'legs'; // پا
    if (clean == 'core') return 'abs'; // شکم
    if (clean == 'cardio') return 'cardio'; // کاردیو
    if (clean == 'plyometric') return 'cardio'; // پلایومتریک
    if (clean == 'stretching' || clean == 'yoga') return 'stretch'; // کشش
    if (clean == 'warmup' || clean == 'balance') return 'stretch'; // گرم‌کردن

    // ── English keywords (legacy / custom exercises) ─────────────
    if (clean.contains('chest') ||
        clean.contains('pec') ||
        clean.contains('upper_body') ||
        clean.contains('push')) {
      return 'chest';
    }
    if (clean.contains('back') ||
        clean.contains('lat') ||
        clean.contains('row') ||
        clean.contains('shoulder_and_back')) {
      return 'back';
    }
    if (clean.contains('shoulder') || clean.contains('deltoid')) return 'back';
    if (clean.contains('lower_body') ||
        clean.contains('leg') ||
        clean.contains('quad') ||
        clean.contains('glute') ||
        clean.contains('hamstring') ||
        clean.contains('calf')) {
      return 'legs';
    }
    if (clean.contains('arm') || clean.contains('bicep') || clean.contains('tricep')) {
      return 'arms';
    }
    if (clean.contains('ab') || clean.contains('core') || clean.contains('waist')) {
      return 'abs';
    }
    if (clean.contains('cardio') ||
        clean.contains('hiit') ||
        clean.contains('run') ||
        clean.contains('plyo')) {
      return 'cardio';
    }
    if (clean.contains('stretch') ||
        clean.contains('recovery') ||
        clean.contains('yoga') ||
        clean.contains('flex') ||
        clean.contains('warmup')) {
      return 'stretch';
    }
    return 'other';
  }

  String _translateCategory(String categoryKey) {
    if (categoryKey == 'all') return 'همه';
    final key = _normalizeCategoryKey(categoryKey);
    switch (key) {
      case 'chest':
        return 'سینه و بالاتنه';
      case 'back':
        return 'پشت و زیربغل';
      case 'shoulders':
        return 'سرشانه';
      case 'legs':
        return 'پا و باسن';
      case 'arms':
        return 'بازو';
      case 'abs':
        return 'شکم و پهلو';
      case 'cardio':
        return 'کاردیو';
      case 'stretch':
        return 'کشش و یوگا';
      default:
        return 'سایر';
    }
  }

  Future<void> _loadExercises() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final db = await DatabaseHelper.instance.database;
      final List<Map<String, dynamic>> results =
          await db.query('ss_exercise', orderBy: 'name ASC');

      final catKeys = <String>{'all'};
      for (final row in results) {
        catKeys.add(_normalizeCategoryKey(row['category']?.toString()));
      }

      const orderedKeys = [
        'all',
        'chest',
        'back',
        'shoulders',
        'legs',
        'arms',
        'abs',
        'cardio',
        'stretch',
        'other',
      ];
      final categoriesList = orderedKeys.where(catKeys.contains).toList();

      if (!mounted) return;
      setState(() {
        _allExercises = results;
        _categories = categoriesList;
        _selectedCategory = 'all';
        _isLoading = false;
        _applyFilters();
      });
    } catch (e) {
      debugPrint('[ExerciseLibrary] خطا در خواندن حرکات: $e');
      if (!mounted) return;
      // قبلاً فقط لودینگ خاموش می‌شد و کاربر یک لیست خالی می‌دید
      // که از «جدول خالی است» قابل تشخیص نبود.
      setState(() {
        _isLoading = false;
        _loadError = e.toString();
      });
    }
  }

  /// فیلترها را روی `_filteredExercises` اعمال می‌کند. خودش setState نمی‌زند
  /// تا قابل فراخوانی از داخل setState باشد (قبلاً setState تودرتو بود).
  void _applyFilters() {
    var temp = _allExercises;

    if (_selectedCategory != 'all') {
      temp = temp
          .where((ex) => _normalizeCategoryKey(ex['category']?.toString()) == _selectedCategory)
          .toList();
    }

    final q = _searchQuery.trim().toLowerCase();
    if (q.isNotEmpty) {
      temp = temp.where((ex) {
        final name = ex['name']?.toString().toLowerCase() ?? '';
        final nameEn = ex['nameEn']?.toString().toLowerCase() ?? '';
        final equipment = ex['equipment']?.toString().toLowerCase() ?? '';
        return name.contains(q) || nameEn.contains(q) || equipment.contains(q);
      }).toList();
    }

    _filteredExercises = temp;
  }

  bool get _hasActiveFilter => _selectedCategory != 'all' || _searchQuery.trim().isNotEmpty;

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _selectedCategory = 'all';
      _applyFilters();
    });
  }

  int _getFarsiDayOfWeek(DateTime dt) {
    switch (dt.weekday) {
      case DateTime.monday:
        return 3;
      case DateTime.tuesday:
        return 4;
      case DateTime.wednesday:
        return 5;
      case DateTime.thursday:
        return 6;
      case DateTime.friday:
        return 7;
      case DateTime.saturday:
        return 1;
      case DateTime.sunday:
        return 2;
    }
    return 1;
  }

  String _translateEquipment(String? equipment) {
    if (equipment == null || equipment.isEmpty) return 'وزن بدن';
    switch (equipment.toLowerCase()) {
      case 'dumbbell':
        return 'دمبل';
      case 'barbell':
        return 'هالتر';
      case 'kettlebell':
        return 'کتل‌بل';
      case 'machine':
        return 'دستگاه';
      case 'cable':
        return 'سیم‌کش';
      case 'band':
        return 'کش ورزشی';
      case 'none':
      case 'bodyweight':
        return 'وزن بدن';
      default:
        return equipment;
    }
  }

  Future<void> _addExerciseToTodayPlan(Map<String, dynamic> exercise) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final todayFarsiDay = _getFarsiDayOfWeek(DateTime.now());

      final plans = await db.query(
        'ss_workout_plan',
        where: 'dayOfWeek = ?',
        whereArgs: [todayFarsiDay],
      );

      String planId;
      if (plans.isEmpty) {
        planId = 'plan_today_${DateTime.now().millisecondsSinceEpoch}';
        await db.insert('ss_workout_plan', {
          'id': planId,
          'dayOfWeek': todayFarsiDay,
          'muscleGroups':
              jsonEncode([_translateCategory((exercise['category'] ?? 'سایر').toString())]),
          'estimatedMinutes': 30,
          'createdAt': DateTime.now().millisecondsSinceEpoch,
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        });
      } else {
        planId = plans.first['id'].toString();
      }

      final crossRefs = await db.query(
        'ss_workout_exercise_crossref',
        where: 'planId = ?',
        whereArgs: [planId],
      );

      var maxOrder = 0;
      for (final ref in crossRefs) {
        final order = ref['orderIndex'] as int? ?? 0;
        if (order > maxOrder) maxOrder = order;
      }

      final crossRefId =
          'ref_${planId}_${exercise['id']}_${DateTime.now().millisecondsSinceEpoch}';
      await db.insert('ss_workout_exercise_crossref', {
        'id': crossRefId,
        'planId': planId,
        'exerciseId': exercise['id'],
        'orderIndex': maxOrder + 1,
        'difficultyOffset': 0.0,
        'targetSets': 3,
        'targetReps': 10,
        'targetWeight': null,
      });

      if (!mounted) return;
      widget.onExerciseAdded?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'حرکت «${exercise['name']}» به برنامهٔ امروز اضافه شد.',
            style: const TextStyle(fontFamily: 'Vazirmatn'),
            textDirection: TextDirection.rtl,
          ),
          backgroundColor: context.colors.success,
        ),
      );
    } catch (e) {
      debugPrint('[ExerciseLibrary] خطا در افزودن به برنامه: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'حرکت به برنامه اضافه نشد.',
            style: TextStyle(fontFamily: 'Vazirmatn'),
            textDirection: TextDirection.rtl,
          ),
          backgroundColor: context.colors.error,
        ),
      );
    }
  }

  void _showExerciseDetailSheet(Map<String, dynamic> exercise) {
    final colors = context.colors;
    final accent = context.modules.sports;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Container(
            decoration: BoxDecoration(
              color: colors.surfaceElevated,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(RitmoRadius.sheet),
              ),
              border: Border.all(color: colors.border, width: 1.5),
            ),
            padding: const EdgeInsets.all(RitmoSpacing.xl),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: colors.textTertiary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: RitmoSpacing.lg),
                  Text(
                    exercise['name']?.toString() ?? '',
                    style: TextStyle(
                      fontFamily: 'Vazirmatn',
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: colors.textPrimary,
                    ),
                  ),
                  if (exercise['nameEn'] != null &&
                      exercise['nameEn'].toString().isNotEmpty) ...[
                    const SizedBox(height: RitmoSpacing.xs),
                    Text(
                      exercise['nameEn'].toString(),
                      style: TextStyle(
                        fontFamily: 'Vazirmatn',
                        fontSize: 13,
                        color: colors.textTertiary,
                      ),
                    ),
                  ],
                  const SizedBox(height: RitmoSpacing.md),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(RitmoRadius.card),
                    child: Container(
                      height: 140,
                      width: double.infinity,
                      color: colors.surfaceSunken,
                      child: SSExerciseAnimationCard(
                        category: exercise['category']?.toString() ?? 'core',
                        exerciseId: exercise['id']?.toString(),
                        height: 140,
                      ),
                    ),
                  ),
                  const SizedBox(height: RitmoSpacing.lg),
                  Row(
                    children: [
                      _Tag(
                        text: _translateCategory(exercise['category']?.toString() ?? ''),
                        color: accent,
                      ),
                      const SizedBox(width: RitmoSpacing.sm),
                      _Tag(
                        text: _translateEquipment(exercise['equipment']?.toString()),
                        color: colors.textSecondary,
                      ),
                    ],
                  ),
                  const SizedBox(height: RitmoSpacing.xl),
                  Text(
                    'راهنمای اجرا',
                    style: TextStyle(
                      fontFamily: 'Vazirmatn',
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: RitmoSpacing.sm),
                  Text(
                    exercise['instructions']?.toString() ??
                        'راهنمایی برای این حرکت ثبت نشده است.',
                    style: TextStyle(
                      fontFamily: 'Vazirmatn',
                      fontSize: 13.5,
                      height: 1.7,
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: RitmoSpacing.xl),
                  if (exercise['videoUrl'] != null &&
                      exercise['videoUrl'].toString().isNotEmpty) ...[
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: colors.border, width: 1.5),
                          foregroundColor: colors.textPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(RitmoRadius.card),
                          ),
                        ),
                        icon: Icon(CupertinoIcons.play_circle_fill, color: colors.textSecondary),
                        label: const Text(
                          'دیدن ویدیوی آموزشی',
                          style: TextStyle(
                            fontFamily: 'Vazirmatn',
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onPressed: () async {
                          final uri = Uri.tryParse(exercise['videoUrl'].toString());
                          if (uri == null) return;
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                          } else if (sheetContext.mounted) {
                            ScaffoldMessenger.of(sheetContext).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'ویدیو باز نشد.',
                                  style: TextStyle(fontFamily: 'Vazirmatn'),
                                ),
                              ),
                            );
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: RitmoSpacing.md),
                  ],
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(RitmoRadius.card),
                        ),
                      ),
                      icon: const Icon(CupertinoIcons.add, size: 20),
                      label: const Text(
                        'افزودن به برنامهٔ امروز',
                        style: TextStyle(
                          fontFamily: 'Vazirmatn',
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        _addExerciseToTodayPlan(exercise);
                      },
                    ),
                  ),
                  const SizedBox(height: RitmoSpacing.md),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final content = Directionality(
      textDirection: TextDirection.rtl,
      child: Column(
        children: [
          _buildFilterBar(colors),
          Expanded(child: _buildBody(colors)),
        ],
      ),
    );

    // در حالت توکار، میزبان خودش Scaffold و هدر دارد.
    if (widget.embedded) return content;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0.5,
        leading: BackButton(color: colors.textPrimary),
        title: Text(
          'کتابخانهٔ حرکات',
          style: TextStyle(
            fontFamily: 'Vazirmatn',
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: colors.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: content,
    );
  }

  Widget _buildFilterBar(RitmoColors colors) {
    final accent = context.modules.sports;

    return Container(
      color: widget.embedded ? Colors.transparent : colors.surface,
      padding: const EdgeInsets.symmetric(
        horizontal: RitmoSpacing.lg,
        vertical: RitmoSpacing.md,
      ),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            style: TextStyle(fontFamily: 'Vazirmatn', color: colors.textPrimary),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              isDense: true,
              prefixIcon: Icon(CupertinoIcons.search, size: 18, color: colors.textSecondary),
              hintText: 'جستجوی نام حرکت یا تجهیزات',
              hintStyle: TextStyle(
                fontFamily: 'Vazirmatn',
                fontSize: 13,
                color: colors.textTertiary,
              ),
              filled: true,
              fillColor: colors.surfaceSunken,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(RitmoRadius.field),
                borderSide: BorderSide(color: colors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(RitmoRadius.field),
                borderSide: BorderSide(color: accent, width: 1.5),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(RitmoRadius.field),
              ),
              // قبلاً فیلد کنترلر نداشت، پس این دکمه فقط فیلتر را پاک می‌کرد
              // و متن تایپ‌شده روی صفحه می‌ماند.
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      tooltip: 'پاک کردن',
                      icon: Icon(CupertinoIcons.xmark_circle_fill,
                          size: 18, color: colors.textTertiary),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                          _applyFilters();
                        });
                      },
                    )
                  : null,
            ),
            onChanged: (val) {
              setState(() {
                _searchQuery = val;
                _applyFilters();
              });
            },
          ),
          const SizedBox(height: RitmoSpacing.md),
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: RitmoSpacing.sm),
              itemBuilder: (context, idx) {
                final cat = _categories[idx];
                return _CategoryChip(
                  label: _translateCategory(cat),
                  isSelected: cat == _selectedCategory,
                  accent: accent,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _selectedCategory = cat;
                      _applyFilters();
                    });
                  },
                );
              },
            ),
          ),
          if (_hasActiveFilter && !_isLoading && _loadError == null) ...[
            const SizedBox(height: RitmoSpacing.sm),
            Row(
              children: [
                Text(
                  '${_filteredExercises.length.toPersianDigits()} حرکت',
                  style: TextStyle(
                    fontFamily: 'Vazirmatn',
                    fontSize: 12,
                    color: colors.textSecondary,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _clearFilters,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(64, 44),
                    foregroundColor: accent,
                  ),
                  child: const Text(
                    'حذف فیلترها',
                    style: TextStyle(
                      fontFamily: 'Vazirmatn',
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBody(RitmoColors colors) {
    if (_isLoading) {
      return const Center(child: CupertinoActivityIndicator());
    }

    if (_loadError != null) {
      return _EmptyState(
        icon: CupertinoIcons.exclamationmark_triangle_fill,
        iconColor: colors.warning,
        title: 'حرکات خوانده نشدند',
        message: 'دسترسی به دیتابیس تمرین‌ها خطا داد.',
        actionLabel: 'تلاش دوباره',
        onAction: _loadExercises,
      );
    }

    if (_filteredExercises.isEmpty) {
      // تفکیک «نتیجه‌ای برای این فیلتر نیست» از «کتابخانه خالی است».
      if (_hasActiveFilter) {
        return _EmptyState(
          icon: CupertinoIcons.search,
          iconColor: colors.textTertiary,
          title: 'نتیجه‌ای پیدا نشد',
          message: 'با این جستجو یا دسته، حرکتی وجود ندارد.',
          actionLabel: 'حذف فیلترها',
          onAction: _clearFilters,
        );
      }
      return _EmptyState(
        icon: CupertinoIcons.book,
        iconColor: colors.textTertiary,
        title: 'کتابخانه خالی است',
        message: 'هنوز هیچ حرکتی در دیتابیس ثبت نشده است.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        RitmoSpacing.lg,
        RitmoSpacing.xs,
        RitmoSpacing.lg,
        RitmoSpacing.xl,
      ),
      itemCount: _filteredExercises.length,
      itemBuilder: (context, idx) {
        final ex = _filteredExercises[idx];
        return Padding(
          padding: const EdgeInsets.only(bottom: RitmoSpacing.sm),
          child: Material(
            color: colors.surface,
            borderRadius: BorderRadius.circular(RitmoRadius.card),
            child: InkWell(
              borderRadius: BorderRadius.circular(RitmoRadius.card),
              onTap: () => _showExerciseDetailSheet(ex),
              child: Container(
                constraints: const BoxConstraints(minHeight: 64),
                padding: const EdgeInsets.symmetric(
                  horizontal: RitmoSpacing.lg,
                  vertical: RitmoSpacing.md,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(RitmoRadius.card),
                  border: Border.all(color: colors.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            ex['name']?.toString() ?? '',
                            style: TextStyle(
                              fontFamily: 'Vazirmatn',
                              fontSize: 14.5,
                              fontWeight: FontWeight.bold,
                              color: colors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${_translateCategory(ex['category']?.toString() ?? '')} · ${_translateEquipment(ex['equipment']?.toString())}',
                            style: TextStyle(
                              fontFamily: 'Vazirmatn',
                              fontSize: 12,
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(CupertinoIcons.chevron_back, size: 14, color: colors.textTertiary),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.isSelected,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      button: true,
      selected: isSelected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(RitmoRadius.pill),
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: RitmoSpacing.lg),
          decoration: BoxDecoration(
            color: isSelected ? accent.withValues(alpha: 0.16) : colors.surfaceSunken,
            borderRadius: BorderRadius.circular(RitmoRadius.pill),
            border: Border.all(
              color: isSelected ? accent : colors.border,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Vazirmatn',
              fontSize: 12.5,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? accent : colors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: RitmoSpacing.md,
        vertical: RitmoSpacing.xs + 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(RitmoRadius.badge),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'Vazirmatn',
          fontSize: 11.5,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(RitmoSpacing.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: iconColor),
            const SizedBox(height: RitmoSpacing.lg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Vazirmatn',
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: RitmoSpacing.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Vazirmatn',
                fontSize: 13,
                height: 1.6,
                color: colors.textSecondary,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: RitmoSpacing.lg),
              OutlinedButton(
                onPressed: onAction,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(120, 44),
                  foregroundColor: context.modules.sports,
                  side: BorderSide(color: colors.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(RitmoRadius.field),
                  ),
                ),
                child: Text(
                  actionLabel!,
                  style: const TextStyle(
                    fontFamily: 'Vazirmatn',
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
