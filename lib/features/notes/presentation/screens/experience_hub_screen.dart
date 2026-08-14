import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/ux/ritmo_haptics.dart';
import 'package:ritmo/features/notes/data/experience_repository.dart';
import 'package:ritmo/features/notes/data/notes_repository.dart';
import 'package:ritmo/features/notes/domain/note_models.dart';
import 'package:ritmo/features/notes/presentation/screens/note_editor_screen.dart';
import 'package:ritmo/features/notes/presentation/screens/note_srs_review_screen.dart';
import 'package:ritmo/features/notes/presentation/widgets/ritmo_shimmer.dart';

class ExperienceHubScreen extends StatefulWidget {
  const ExperienceHubScreen({super.key});

  @override
  State<ExperienceHubScreen> createState() => _ExperienceHubScreenState();
}

class _ExperienceHubScreenState extends State<ExperienceHubScreen> {
  List<Experience> _experiences = [];
  Experience? _featuredExp;
  bool _isLoading = true;
  ExperienceCategory? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final exps = await ExperienceRepository.instance.listAll();
      Experience? featured = _featuredExp != null
          ? exps.where((e) => e.noteId == _featuredExp!.noteId).firstOrNull
          : null;
      if (featured == null && exps.isNotEmpty) {
        featured = (exps.where((e) => e.isActive && e.importance >= 4).toList()..shuffle()).firstOrNull ?? exps.first;
      }
      if (mounted) {
        setState(() {
          _experiences = exps;
          _featuredExp = featured;
          _isLoading = false;
        });
      }
    } catch (e, st) {
      debugPrint('Error loading experiences in ExperienceHubScreen: $e\n$st');
      if (mounted) {
        setState(() {
          _experiences = [];
          _featuredExp = null;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final filtered = _selectedCategory == null
        ? _experiences
        : _experiences.where((e) => e.category == _selectedCategory).toList();

    final featuredExp = _featuredExp;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(
          backgroundColor: colors.surface,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: colors.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'بانک درس‌ها و تجربه‌ها',
            style: TextStyle(
              fontFamily: 'Vazirmatn',
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: colors.textPrimary,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.psychology_outlined, color: Color(0xFFE5A00D), size: 22),
              tooltip: 'مرور فاصله‌دار درس‌ها',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NoteSrsReviewScreen()),
                ).then((_) {
                  if (mounted) _loadData();
                });
              },
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () async {
            RitmoHaptics.confirm();
            if (!context.mounted) return;
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NoteEditorScreen(isExperience: true)),
            );
            if (mounted) await _loadData();
          },
          backgroundColor: const Color(0xFFE5A00D),
          icon: const Icon(CupertinoIcons.pencil, color: Colors.white, size: 18),
          label: const Text(
            'ثبت تجربه جدید',
            style: TextStyle(
              fontFamily: 'Vazirmatn',
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontSize: 13,
            ),
          ),
        ),
        body: Column(
          children: [
            // Category Horizontal Sliding Selector
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              color: colors.surface,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    _buildCategoryPill('همه', null, '🌟', _experiences.length),
                    const SizedBox(width: 8),
                    ...ExperienceCategory.values.map((cat) {
                      final count = _experiences.where((e) => e.category == cat).length;
                      return Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: _buildCategoryPill(cat.labelFa, cat, cat.emoji, count),
                      );
                    }),
                  ],
                ),
              ),
            ),

            // Main Content Area
            Expanded(
              child: _isLoading
                  ? const RitmoShimmerGrid(count: 4)
                  : filtered.isEmpty
                      ? _buildEmptyState(colors)
                      : RefreshIndicator(
                          onRefresh: _loadData,
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            children: [
                              // Featured Wisdom Hero Card (Shown when 'All' is selected)
                              if (_selectedCategory == null && featuredExp != null) ...[
                                _buildFeaturedHeroCard(context, featuredExp),
                                const SizedBox(height: 18),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  child: Row(
                                    children: [
                                      const Icon(CupertinoIcons.sparkles, size: 14, color: Color(0xFFE5A00D)),
                                      const SizedBox(width: 6),
                                      Text(
                                        'همه آموزه‌ها (${PersianDigits.convert(filtered.length.toString())})',
                                        style: TextStyle(
                                          fontFamily: 'Vazirmatn',
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: colors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 10),
                              ],

                              // Wisdom Cards List
                              ...filtered.map((exp) => _buildWisdomCard(context, exp)),
                              const SizedBox(height: 80),
                            ],
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryPill(String label, ExperienceCategory? cat, String emoji, int count) {
    final colors = context.colors;
    final isSelected = _selectedCategory == cat;

    return AnimatedScale(
      scale: isSelected ? 1.0 : 0.97,
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOutCubic,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            RitmoHaptics.selection();
            setState(() => _selectedCategory = cat);
          },
          borderRadius: BorderRadius.circular(RitmoRadius.pill),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFFE5A00D) : colors.surfaceSunken,
              borderRadius: BorderRadius.circular(RitmoRadius.pill),
              border: Border.all(
                color: isSelected ? const Color(0xFFE5A00D) : colors.border.withValues(alpha: 0.15),
                width: isSelected ? 1.2 : 0.8,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 12)),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Vazirmatn',
                    fontSize: 11.5,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? Colors.white : colors.textPrimary,
                  ),
                ),
                if (count > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.white.withValues(alpha: 0.25)
                          : const Color(0xFFE5A00D).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(RitmoRadius.pill),
                    ),
                    child: Text(
                      PersianDigits.convert(count.toString()),
                      style: TextStyle(
                        fontFamily: 'Vazirmatn',
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : const Color(0xFFE5A00D),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeaturedHeroCard(BuildContext context, Experience exp) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF332505), colors.surfaceSunken]
              : [const Color(0xFFFFFBEB), const Color(0xFFFEF3C7)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(RitmoRadius.hero),
        border: Border.all(color: const Color(0xFFE5A00D).withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE5A00D).withValues(alpha: isDark ? 0.12 : 0.08),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Subtle quote decoration watermark
          Positioned(
            top: -10,
            left: 0,
            child: Text(
              '“',
              style: TextStyle(
                fontFamily: 'Vazirmatn',
                fontSize: 64,
                fontWeight: FontWeight.bold,
                color: const Color(0xFFE5A00D).withValues(alpha: 0.12),
                height: 1.0,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5A00D).withValues(alpha: isDark ? 0.25 : 0.15),
                      borderRadius: BorderRadius.circular(RitmoRadius.pill),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('✨', style: TextStyle(fontSize: 12)),
                        const SizedBox(width: 4),
                        Text(
                          'درس برگزیده • ${exp.category.labelFa}',
                          style: const TextStyle(
                            fontFamily: 'Vazirmatn',
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFE5A00D),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: List.generate(5, (idx) {
                      final starFilled = idx < exp.importance;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 1),
                        child: Icon(
                          starFilled ? CupertinoIcons.star_fill : CupertinoIcons.star,
                          size: 13,
                          color: starFilled ? const Color(0xFFE5A00D) : colors.textTertiary,
                        ),
                      );
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '« ${exp.lesson} »',
                style: TextStyle(
                  fontFamily: 'Vazirmatn',
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: colors.textPrimary,
                  height: 1.5,
                ),
              ),
              if (exp.contextText != null && exp.contextText!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  exp.contextText!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Vazirmatn',
                    fontSize: 12.5,
                    color: colors.textSecondary,
                    height: 1.45,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWisdomCard(BuildContext context, Experience exp) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? colors.surfaceSunken.withValues(alpha: 0.8) : colors.surface,
        borderRadius: BorderRadius.circular(RitmoRadius.card),
        border: Border.all(
          color: const Color(0xFFE5A00D).withValues(alpha: isDark ? 0.25 : 0.15),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.03),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(RitmoRadius.card),
          onTap: () async {
            RitmoHaptics.selection();
            final note = await NotesRepository.instance.getById(exp.noteId);
            if (note != null && context.mounted) {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => NoteEditorScreen(note: note, isExperience: true)),
              );
              await _loadData();
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: Category, Stars & Options
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5A00D).withValues(alpha: isDark ? 0.18 : 0.1),
                        borderRadius: BorderRadius.circular(RitmoRadius.pill),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(exp.category.emoji, style: const TextStyle(fontSize: 12)),
                          const SizedBox(width: 4),
                          Text(
                            exp.category.labelFa,
                            style: const TextStyle(
                              fontFamily: 'Vazirmatn',
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFE5A00D),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        ...List.generate(5, (idx) {
                          final isFilled = idx < exp.importance;
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 1),
                            child: Icon(
                              isFilled ? CupertinoIcons.star_fill : CupertinoIcons.star,
                              size: 12,
                              color: isFilled ? const Color(0xFFE5A00D) : colors.textTertiary,
                            ),
                          );
                        }),
                        const SizedBox(width: 4),
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: PopupMenuButton<String>(
                            padding: EdgeInsets.zero,
                            icon: Icon(Icons.more_horiz, size: 18, color: colors.textTertiary),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            onSelected: (val) async {
                              RitmoHaptics.selection();
                              if (val == 'toggle') {
                                await ExperienceRepository.instance.setActive(exp.noteId, !exp.isActive);
                                await _loadData();
                              } else if (val == 'importance_up') {
                                if (exp.importance < 5) {
                                  await ExperienceRepository.instance.setImportance(exp.noteId, exp.importance + 1);
                                  await _loadData();
                                }
                              } else if (val == 'importance_down') {
                                if (exp.importance > 1) {
                                  await ExperienceRepository.instance.setImportance(exp.noteId, exp.importance - 1);
                                  await _loadData();
                                }
                              }
                            },
                            itemBuilder: (ctx) => [
                              PopupMenuItem(
                                value: 'toggle',
                                child: Text(
                                  exp.isActive ? 'غیرفعال کردن پیشنهاد' : 'فعال‌سازی پیشنهاد',
                                  style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 12),
                                ),
                              ),
                              if (exp.importance < 5)
                                const PopupMenuItem(
                                  value: 'importance_up',
                                  child: Text('افزایش اهمیت ⭐', style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 12)),
                                ),
                              if (exp.importance > 1)
                                const PopupMenuItem(
                                  value: 'importance_down',
                                  child: Text('کاهش اهمیت 📉', style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 12)),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Lesson Text
                Text(
                  exp.lesson,
                  style: TextStyle(
                    fontFamily: 'Vazirmatn',
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                    height: 1.45,
                  ),
                ),

                // Context Text
                if (exp.contextText != null && exp.contextText!.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    exp.contextText!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Vazirmatn',
                      fontSize: 12,
                      color: colors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
                const SizedBox(height: 10),

                // Footer: DayKey & Active Switch
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      exp.occurredOnDayKey != null ? 'ثبت در روز: ${PersianDigits.convert(exp.occurredOnDayKey!)}' : '',
                      style: TextStyle(
                        fontFamily: 'Vazirmatn',
                        fontSize: 10.5,
                        color: colors.textTertiary,
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          exp.isActive ? 'پیشنهاد روزانه فعال' : 'پیشنهاد غیرفعال',
                          style: TextStyle(
                            fontFamily: 'Vazirmatn',
                            fontSize: 10,
                            color: exp.isActive ? const Color(0xFFE5A00D) : colors.textTertiary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        SizedBox(
                          height: 20,
                          width: 32,
                          child: Transform.scale(
                            scale: 0.65,
                            child: Switch(
                              value: exp.isActive,
                              activeThumbColor: const Color(0xFFE5A00D),
                              onChanged: (val) async {
                                RitmoHaptics.selection();
                                await ExperienceRepository.instance.setActive(exp.noteId, val);
                                await _loadData();
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(RitmoColors colors) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFFE5A00D).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.lightbulb_outline_rounded,
                size: 36,
                color: Color(0xFFE5A00D),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'هنوز درسی ثبت نکرده‌اید',
              style: TextStyle(
                fontFamily: 'Vazirmatn',
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'درس‌ها و آموزه‌های کلیدی زندگی خود را بنویسید تا سیستم بازنمایی روزانه آن‌ها را به شما یادآوری کند.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Vazirmatn',
                fontSize: 12.5,
                color: colors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () async {
                RitmoHaptics.confirm();
                if (!context.mounted) return;
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NoteEditorScreen(isExperience: true)),
                );
                if (mounted) await _loadData();
              },
              icon: const Icon(CupertinoIcons.pencil, size: 16),
              label: const Text(
                'ثبت اولین تجربه',
                style: TextStyle(fontFamily: 'Vazirmatn', fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE5A00D),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
