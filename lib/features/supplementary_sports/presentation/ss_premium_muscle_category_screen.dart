// lib/features/supplementary_sports/presentation/ss_premium_muscle_category_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/supplementary_sports/presentation/widgets/shared/ss_lottie_player.dart';
import 'package:url_launcher/url_launcher.dart';

/// صفحه پرمیوم جذاب نمایش حرکات هر بخش (تفکیک‌شده از داشبورد اصلی برای جلوگیری از طولانی شدن کد)
class SSPremiumMuscleCategoryScreen extends StatefulWidget {
  const SSPremiumMuscleCategoryScreen({
    super.key,
    required this.categoryKey,
    required this.categoryName,
  });

  final String categoryKey;
  final String categoryName;

  @override
  State<SSPremiumMuscleCategoryScreen> createState() => _SSPremiumMuscleCategoryScreenState();
}

class _SSPremiumMuscleCategoryScreenState extends State<SSPremiumMuscleCategoryScreen> {
  List<Map<String, dynamic>> _allExercises = [];
  List<Map<String, dynamic>> _filteredExercises = [];
  String _selectedEquip = 'all'; // all, bodyweight, dumbbell, gym
  String _searchQuery = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadExercises();
  }

  String _normalizeCategoryKey(String? rawCategory) {
    final clean = (rawCategory ?? '').toLowerCase().trim();
    // ── Fitify native keys ────────────────────────────────────────
    if (clean == 'upper_body') return 'chest';
    if (clean == 'shoulder_and_back') return 'back';
    if (clean == 'lower_body') return 'legs';
    if (clean == 'core') return 'abs';
    if (clean == 'cardio') return 'cardio';
    if (clean == 'plyometric') return 'cardio';
    if (clean == 'stretching' || clean == 'yoga') return 'stretch';
    if (clean == 'warmup' || clean == 'balance') return 'stretch';

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

  Future<void> _loadExercises() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final results = await db.query('ss_exercise', orderBy: 'name ASC');

      // فیلتر کردن ورزش‌ها در سطح Dart بر اساس نگاشت دسته‌بندی استاندارد ریتمو
      final categoryExercises = results.where((ex) {
        final key = _normalizeCategoryKey(ex['category']?.toString());
        return key == widget.categoryKey;
      }).toList();

      if (mounted) {
        setState(() {
          _allExercises = categoryExercises;
          _isLoading = false;
          _filterExercises();
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _filterExercises() {
    var list = _allExercises;
    if (_searchQuery.isNotEmpty) {
      list = list.where((ex) {
        final name = (ex['name']?.toString() ?? '').toLowerCase();
        final nameEn = (ex['nameEn']?.toString() ?? '').toLowerCase();
        return name.contains(_searchQuery.toLowerCase()) || nameEn.contains(_searchQuery.toLowerCase());
      }).toList();
    }

    if (_selectedEquip != 'all') {
      list = list.where((ex) {
        final equip = (ex['equipment']?.toString() ?? '').toLowerCase().trim();
        final isBodyweight = equip.contains('bodyweight') || equip == 'none' || equip.isEmpty;
        final isDumbbell = equip.contains('dumbbell');

        if (_selectedEquip == 'bodyweight') return isBodyweight;
        if (_selectedEquip == 'dumbbell') return isDumbbell;
        return !isBodyweight && !isDumbbell; // gym / others
      }).toList();
    }

    setState(() {
      _filteredExercises = list;
    });
  }

  String _translateEquipment(String? raw) {
    final clean = (raw ?? '').toLowerCase().trim();
    if (clean.contains('bodyweight') || clean == 'none' || clean.isEmpty) return 'وزن بدن';
    if (clean.contains('dumbbell')) return 'دمبل';
    if (clean.contains('barbell')) return 'هالتر';
    if (clean.contains('cable')) return 'سیم‌کش';
    if (clean.contains('machine')) return 'دستگاه بدنسازی';
    return 'سایر تجهیزات';
  }

  void _showDetailSheet(Map<String, dynamic> exercise) {
    final colors = context.colors;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: colors.border.withValues(alpha: 0.8), width: 1.5),
          ),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 50,
                  height: 5,
                  decoration: BoxDecoration(
                    color: colors.border,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                exercise['name']?.toString() ?? '',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: colors.textPrimary,
                ),
              ),
              if (exercise['nameEn'] != null) ...[
                const SizedBox(height: 4),
                Text(
                  exercise['nameEn'].toString(),
                  style: TextStyle(
                    fontSize: 13,
                    color: colors.textSecondary,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  height: 180,
                  color: colors.background,
                  child: SSExerciseAnimationCard(
                    category: exercise['category']?.toString() ?? 'core',
                    exerciseId: exercise['id']?.toString(),
                    height: 180,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      widget.categoryName,
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: colors.textSecondary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _translateEquipment(exercise['equipment']?.toString()),
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'راهنمای اجرا:',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                exercise['instructions']?.toString() ?? 'راهنمایی برای این حرکت ثبت نشده است.',
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.6,
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              if (exercise['videoUrl'] != null && exercise['videoUrl'].toString().isNotEmpty) ...[
                SizedBox(
                  height: 52,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.red.withValues(alpha: 0.7), width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(CupertinoIcons.play_circle_fill, color: Colors.red),
                    label: const Text(
                      'مشاهده ویدیو آموزش حرکت 🎥',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                    onPressed: () async {
                      final urlStr = exercise['videoUrl'].toString();
                      final uri = Uri.parse(urlStr);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    },
                  ),
                ),
                const SizedBox(height: 12),
              ],
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text(
                    'متوجه شدم',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(
          backgroundColor: colors.surface,
          elevation: 0,
          title: Text(
            widget.categoryName,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          centerTitle: true,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: colors.textPrimary),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: Column(
          children: [
            // Search Bar & Filter Pills
            Container(
              color: colors.surface,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                children: [
                  // Glassmorphic Search Bar
                  Container(
                    decoration: BoxDecoration(
                      color: colors.background,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: colors.border.withValues(alpha: 0.5)),
                    ),
                    child: TextField(
                      style: TextStyle(color: colors.textPrimary, fontSize: 14),
                      onChanged: (val) {
                        _searchQuery = val;
                        _filterExercises();
                      },
                      decoration: InputDecoration(
                        hintText: 'جستجوی نام حرکت...',
                        hintStyle: TextStyle(color: colors.textSecondary, fontSize: 13),
                        prefixIcon: Icon(CupertinoIcons.search, color: colors.textSecondary, size: 20),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Filter Pills
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterPill('all', 'همه'),
                        const SizedBox(width: 8),
                        _buildFilterPill('bodyweight', 'بدون ابزار 🏃'),
                        const SizedBox(width: 8),
                        _buildFilterPill('dumbbell', 'دمبل 🏋️'),
                        const SizedBox(width: 8),
                        _buildFilterPill('gym', 'دستگاه و هالتر ⚙️'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Exercises Grid
            Expanded(
              child: _isLoading
                  ? const Center(child: CupertinoActivityIndicator())
                  : _filteredExercises.isEmpty
                      ? Center(
                          child: Text(
                            'حرکتی یافت نشد.',
                            style: TextStyle(color: colors.textSecondary, fontSize: 14),
                          ),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.all(16),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 0.95,
                          ),
                          itemCount: _filteredExercises.length,
                          itemBuilder: (context, index) {
                            final ex = _filteredExercises[index];
                            final equipText = _translateEquipment(ex['equipment']?.toString());
                            return Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    colors.surface,
                                    colors.surface.withValues(alpha: 0.6),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: colors.border.withValues(alpha: 0.6)),
                                boxShadow: [
                                  BoxShadow(
                                    color: colors.shadow.withValues(alpha: 0.03),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () => _showDetailSheet(ex),
                                  borderRadius: BorderRadius.circular(20),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        Expanded(
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(14),
                                            child: Container(
                                              color: colors.background,
                                              child: SSExerciseAnimationCard(
                                                category: ex['category']?.toString() ?? 'core',
                                                exerciseId: ex['id']?.toString(),
                                                height: double.infinity,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          ex['name']?.toString() ?? '',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                            color: colors.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          equipText,
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: colors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterPill(String key, String title) {
    final colors = context.colors;
    final isSelected = _selectedEquip == key;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedEquip = key;
          _filterExercises();
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? colors.primary : colors.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? colors.primary : colors.border.withValues(alpha: 0.8),
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : colors.textPrimary,
          ),
        ),
      ),
    );
  }
}
