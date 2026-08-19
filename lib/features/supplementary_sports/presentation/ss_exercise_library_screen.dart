import 'dart:async';
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
    this.initialCategory,
    this.embedded = false,
    this.onExerciseAdded,
  });

  final String? initialCategory;

  /// وقتی داخل تب «کتابخانه» جاسازی می‌شود: بدون Scaffold و AppBar.
  final bool embedded;

  /// پس از افزوده‌شدن یک حرکت به برنامهٔ امروز صدا زده می‌شود.
  final VoidCallback? onExerciseAdded;

  @override
  State<SSExerciseLibraryScreen> createState() => _SSExerciseLibraryScreenState();
}

class _SSExerciseLibraryScreenState extends State<SSExerciseLibraryScreen> {
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _allExercises = [];
  List<Map<String, dynamic>> _filteredExercises = [];
  List<String> _categories = ['all'];
  String _selectedCategory = 'all';
  String _searchQuery = '';
  bool _isLoading = true;
  String? _loadError;

  bool get _hasActiveFilter =>
      _searchQuery.trim().isNotEmpty || _selectedCategory != 'all';

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
    // ── Fitify native keys ────────────────────────────────────────
    if (clean == 'upper_body') return 'chest';          // شنا / بالاتنه
    if (clean == 'shoulder_and_back') return 'back';    // کمر / زیربغل
    if (clean == 'lower_body') return 'legs';           // پا
    if (clean == 'core') return 'abs';                  // شکم
    if (clean == 'cardio') return 'cardio';             // کاردیو
    if (clean == 'plyometric') return 'cardio';         // پلایومتریک
    if (clean == 'stretching' || clean == 'yoga') return 'stretch'; // کشش
    if (clean == 'warmup' || clean == 'balance') return 'stretch';  // گرم‌کردن

    // ── English keywords (legacy / custom exercises) ─────────────
    if (clean.contains('chest') || clean.contains('pec') ||
        clean.contains('upper_body') || clean.contains('push')) {
      return 'chest';
    }
    // سینه و بالاتنه شامل سرشانه و بازو نیز می‌شود
    if (clean.contains('shoulder') || clean.contains('deltoid') ||
        clean.contains('arm') || clean.contains('bicep') || clean.contains('tricep')) {
      return 'chest';
    }
    if (clean.contains('back') || clean.contains('lat') ||
        clean.contains('row') || clean.contains('shoulder_and_back')) {
      return 'back';
    }
    if (clean.contains('lower_body') || clean.contains('leg') ||
        clean.contains('quad') || clean.contains('glute') ||
        clean.contains('hamstring') || clean.contains('calf')) {
      return 'legs';
    }
    if (clean.contains('ab') || clean.contains('core') ||
        clean.contains('waist')) {
      return 'abs';
    }
    if (clean.contains('cardio') || clean.contains('hiit') ||
        clean.contains('run') || clean.contains('plyo')) {
      return 'cardio';
    }
    if (clean.contains('stretch') || clean.contains('recovery') ||
        clean.contains('yoga') || clean.contains('flex') ||
        clean.contains('warmup')) {
      return 'stretch';
    }
    return 'other';
  }

  String _translateCategory(String categoryKey) {
    final key = _normalizeCategoryKey(categoryKey);
    switch (key) {
      case 'all': return 'همه';
      case 'chest': return 'سینه و بالاتنه';
      case 'back': return 'پشت و زیربغل';
      case 'legs': return 'پا و باسن';
      case 'abs': return 'شکم و پهلو';
      case 'cardio': return 'کاردیو';
      case 'stretch': return 'کشش و یوگا';
      default: return 'سایر';
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
        final normKey = _normalizeCategoryKey(row['category']?.toString());
        catKeys.add(normKey);
      }

      const orderedKeys = ['all', 'chest', 'back', 'legs', 'abs', 'cardio', 'stretch', 'other'];
      final categoriesList = orderedKeys.where(catKeys.contains).toList();

      if (!mounted) return;
      setState(() {
        _allExercises = results;
        _categories = categoriesList;
        _selectedCategory = (widget.initialCategory != null &&
                categoriesList.contains(widget.initialCategory))
            ? widget.initialCategory!
            : 'all';
        _filteredExercises = _applyFilters();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading library exercises: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = e.toString();
      });
    }
  }

  /// خالص — بدون setState تودرتو. نتیجه را برمی‌گرداند.
  List<Map<String, dynamic>> _applyFilters() {
    var temp = _allExercises;

    if (_selectedCategory != 'all') {
      temp = temp.where((ex) {
        final normKey = _normalizeCategoryKey(ex['category']?.toString());
        return normKey == _selectedCategory;
      }).toList();
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

    return temp;
  }

  void _refilter() {
    setState(() => _filteredExercises = _applyFilters());
  }

  void _clearFilters() {
    HapticFeedback.selectionClick();
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _selectedCategory = 'all';
      _filteredExercises = _applyFilters();
    });
  }

  int _getFarsiDayOfWeek(DateTime dt) {
    switch (dt.weekday) {
      case DateTime.monday: return 3;
      case DateTime.tuesday: return 4;
      case DateTime.wednesday: return 5;
      case DateTime.thursday: return 6;
      case DateTime.friday: return 7;
      case DateTime.saturday: return 1;
      case DateTime.sunday: return 2;
    }
    return 1;
  }

  String _translateEquipment(String? equipment) {
    if (equipment == null || equipment.isEmpty) return 'وزن بدن';
    switch (equipment.toLowerCase()) {
      case 'dumbbell': return 'دمبل';
      case 'barbell': return 'هالتر';
      case 'kettlebell': return 'کتل‌بل';
      case 'machine': return 'دستگاه';
      case 'cable': return 'سیم‌کش';
      case 'band': return 'کش ورزشی';
      case 'none':
      case 'bodyweight': return 'وزن بدن';
      default: return equipment;
    }
  }

  Future<void> _addExerciseToTodayPlan(Map<String, dynamic> exercise) async {
    final colors = context.colors;
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
          'muscleGroups': jsonEncode([_translateCategory((exercise['category'] ?? 'سایر').toString())]),
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

      final crossRefId = 'ref_${planId}_${exercise['id']}_${DateTime.now().millisecondsSinceEpoch}';
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
      unawaited(HapticFeedback.mediumImpact());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'حرکت «${exercise['name']}» به برنامهٔ امروز اضافه شد.',
            style: const TextStyle(fontFamily: 'Vazirmatn'),
          ),
          backgroundColor: colors.success,
        ),
      );
      widget.onExerciseAdded?.call();
    } catch (e) {
      debugPrint('Error adding exercise to plan: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'خطا در اضافه کردن حرکت به برنامه.',
            style: TextStyle(fontFamily: 'Vazirmatn'),
          ),
          backgroundColor: colors.error,
        ),
      );
    }
  }

  void _showExerciseDetailSheet(Map<String, dynamic> exercise) {
    final colors = context.colors;
    final accent = context.modules.sports;
    final videoUrl = exercise['videoUrl']?.toString() ?? '';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Container(
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(RitmoRadius.sheet)),
              border: Border.all(color: colors.border, width: 1),
            ),
            // قبلاً ثابت بود؛ با محتوای بلند سرریز می‌کرد.
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 16,
                bottom: 24 + MediaQuery.of(sheetContext).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: colors.divider,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    exercise['name']?.toString() ?? '',
                    style: TextStyle(
                      fontFamily: 'Vazirmatn',
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: ClipRRect(
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
                  ),
                  if (exercise['nameEn'] != null &&
                      exercise['nameEn'].toString().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      exercise['nameEn'].toString(),
                      style: TextStyle(
                        fontSize: 13,
                        color: colors.textTertiary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _Tag(
                        label: _translateCategory(exercise['category']?.toString() ?? ''),
                        color: accent,
                      ),
                      const SizedBox(width: 8),
                      _Tag(
                        label: _translateEquipment(exercise['equipment']?.toString()),
                        color: colors.textSecondary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'راهنمای اجرا:',
                    style: TextStyle(
                      fontFamily: 'Vazirmatn',
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
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
                  const SizedBox(height: 24),
                  if (videoUrl.isNotEmpty) ...[
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: colors.error, width: 1.2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(RitmoRadius.card),
                          ),
                        ),
                        icon: Icon(CupertinoIcons.play_circle_fill, color: colors.error),
                        label: Text(
                          'مشاهدهٔ ویدیوی آموزش حرکت',
                          style: TextStyle(
                            fontFamily: 'Vazirmatn',
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: colors.error,
                          ),
                        ),
                        onPressed: () async {
                          final uri = Uri.tryParse(videoUrl);
                          final messenger = ScaffoldMessenger.of(context);
                          if (uri != null && await canLaunchUrl(uri)) {
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                          } else {
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'امکان باز کردن لینک ویدیو نیست.',
                                  style: TextStyle(fontFamily: 'Vazirmatn'),
                                ),
                              ),
                            );
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
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
                      icon: const Icon(CupertinoIcons.add, color: Colors.white),
                      label: const Text(
                        'اضافه کردن به برنامهٔ امروز',
                        style: TextStyle(
                          fontFamily: 'Vazirmatn',
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        _addExerciseToTodayPlan(exercise);
                      },
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

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final body = Directionality(
      textDirection: TextDirection.rtl,
      child: Column(
        children: [
          _buildHeader(context),
          Expanded(child: _buildBody(context)),
        ],
      ),
    );

    if (widget.embedded) {
      return Container(color: colors.background, child: body);
    }

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0.5,
        leading: BackButton(
          color: colors.textPrimary,
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'کتابخانهٔ حرکات ورزشی',
          style: TextStyle(
            fontFamily: 'Vazirmatn',
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: colors.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: body,
    );
  }

  Widget _buildHeader(BuildContext context) {
    final colors = context.colors;
    final accent = context.modules.sports;

    return Container(
      color: colors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          // جست‌وجو — با کنترلر واقعی تا «پاک کردن» متن را هم پاک کند
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: colors.surfaceElevated,
              borderRadius: BorderRadius.circular(RitmoRadius.card),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextField(
              controller: _searchController,
              style: TextStyle(
                fontFamily: 'Vazirmatn',
                fontSize: 14,
                color: colors.textPrimary,
              ),
              decoration: InputDecoration(
                icon: Icon(CupertinoIcons.search, color: colors.textTertiary, size: 20),
                hintText: 'جست‌وجوی نام حرکت یا تجهیزات...',
                hintStyle: TextStyle(
                  fontFamily: 'Vazirmatn',
                  fontSize: 13,
                  color: colors.textTertiary,
                ),
                border: InputBorder.none,
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        tooltip: 'پاک کردن',
                        icon: Icon(CupertinoIcons.xmark_circle_fill,
                            color: colors.textTertiary, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                            _filteredExercises = _applyFilters();
                          });
                        },
                      )
                    : null,
              ),
              onChanged: (val) {
                _searchQuery = val;
                _refilter();
              },
            ),
          ),
          const SizedBox(height: 12),
          // چیپ‌های دسته‌بندی — ۴۴px و RTL-safe
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
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
                      _filteredExercises = _applyFilters();
                    });
                  },
                );
              },
            ),
          ),
          if (_hasActiveFilter && !_isLoading && _loadError == null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                '${_filteredExercises.length.toPersianDigits()} حرکت پیدا شد',
                style: TextStyle(
                  fontFamily: 'Vazirmatn',
                  fontSize: 11.5,
                  color: colors.textTertiary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final colors = context.colors;

    if (_isLoading) {
      return const Center(child: CupertinoActivityIndicator());
    }

    // خطای واقعی — قبلاً catch خاموش لیست خالی جعلی نشان می‌داد
    if (_loadError != null) {
      return _EmptyState(
        icon: CupertinoIcons.exclamationmark_triangle,
        title: 'کتابخانه بارگذاری نشد',
        subtitle: 'یک خطای موقت رخ داد. دوباره تلاش کن.',
        actionLabel: 'تلاش دوباره',
        onAction: _loadExercises,
      );
    }

    if (_allExercises.isEmpty) {
      return const _EmptyState(
        icon: CupertinoIcons.square_stack_3d_up_slash,
        title: 'کتابخانه خالی است',
        subtitle: 'هنوز هیچ حرکتی در پایگاه‌داده ثبت نشده است.',
      );
    }

    if (_filteredExercises.isEmpty) {
      return _EmptyState(
        icon: CupertinoIcons.search,
        title: 'نتیجه‌ای پیدا نشد',
        subtitle: 'عبارت دیگری را امتحان کن یا فیلترها را حذف کن.',
        actionLabel: 'حذف فیلترها',
        onAction: _clearFilters,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredExercises.length,
      itemBuilder: (context, idx) {
        final ex = _filteredExercises[idx];
        final accent = context.modules.sports;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Material(
            color: colors.surface,
            borderRadius: BorderRadius.circular(RitmoRadius.card),
            child: InkWell(
              onTap: () => _showExerciseDetailSheet(ex),
              borderRadius: BorderRadius.circular(RitmoRadius.card),
              child: Container(
                constraints: const BoxConstraints(minHeight: 64),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                _translateCategory(ex['category']?.toString() ?? ''),
                                style: TextStyle(
                                  fontFamily: 'Vazirmatn',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: accent,
                                ),
                              ),
                              Text(
                                ' · ${_translateEquipment(ex['equipment']?.toString())}',
                                style: TextStyle(
                                  fontFamily: 'Vazirmatn',
                                  fontSize: 12,
                                  color: colors.textTertiary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      CupertinoIcons.chevron_back,
                      size: 16,
                      color: colors.textTertiary,
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
}

// ─── ویجت‌های کوچک ─────────────────────────────────────────────────────────

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
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: isSelected ? accent : colors.surfaceElevated,
            borderRadius: BorderRadius.circular(RitmoRadius.pill),
            border: Border.all(
              color: isSelected ? accent : colors.border,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Vazirmatn',
              fontSize: 12.5,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? Colors.white : colors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(RitmoRadius.badge),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Vazirmatn',
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: colors.textTertiary),
            const SizedBox(height: 14),
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
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Vazirmatn',
                fontSize: 12.5,
                height: 1.6,
                color: colors.textSecondary,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              SizedBox(
                height: 44,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.textPrimary,
                    side: BorderSide(color: colors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(RitmoRadius.field),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                  ),
                  onPressed: onAction,
                  child: Text(
                    actionLabel!,
                    style: const TextStyle(
                      fontFamily: 'Vazirmatn',
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
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
