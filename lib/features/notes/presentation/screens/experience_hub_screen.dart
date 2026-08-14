import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_empty_state.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_page_scaffold.dart';
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
    final insightsColor = context.modules.insights;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final filtered = _selectedCategory == null
        ? _experiences
        : _experiences.where((e) => e.category == _selectedCategory).toList();

    final featuredExp = _featuredExp;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: RitmoPageScaffold(
        padding: EdgeInsets.zero,
        floatingActionButton: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: insightsColor.withValues(alpha: 0.3),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: FloatingActionButton.extended(
            onPressed: () async {
              RitmoHapticsPolicy.tap();
              if (!context.mounted) return;
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NoteEditorScreen(isExperience: true)),
              );
              if (mounted) await _loadData();
            },
            backgroundColor: insightsColor,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            icon: Icon(CupertinoIcons.pencil, color: colors.onPrimary, size: 18),
            label: Text(
              'ثبت تجربه جدید',
              style: TextStyle(
                fontFamily: 'Vazirmatn',
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: colors.onPrimary,
              ),
            ),
          ),
        ),
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // Top Luxury App Bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              RitmoHapticsPolicy.tap();
                              Navigator.pop(context);
                            },
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: colors.surfaceSunken,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: colors.border,
                                  width: 1,
                                ),
                              ),
                              child: Icon(
                                CupertinoIcons.arrow_right,
                                size: 18,
                                color: colors.textPrimary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'بانک درس‌ها و تجربه‌ها',
                          style: TextStyle(
                            fontSize: 18.5,
                            fontWeight: FontWeight.w900,
                            color: colors.textPrimary,
                            fontFamily: 'Vazirmatn',
                          ),
                        ),
                      ],
                    ),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          RitmoHapticsPolicy.tap();
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const NoteSrsReviewScreen()),
                          ).then((_) {
                            if (mounted) _loadData();
                          });
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: insightsColor.withValues(alpha: isDark ? 0.2 : 0.12),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: insightsColor.withValues(alpha: 0.4),
                              width: 1,
                            ),
                          ),
                          child: Icon(
                            Icons.psychology_outlined,
                            size: 20,
                            color: insightsColor,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Category Horizontal Sliding Selector
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: SizedBox(
                  height: 38,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      _buildFilterChip(
                        label: 'همه (${PersianDigits.convert(_experiences.length.toString())})',
                        isSelected: _selectedCategory == null,
                        onTap: () => setState(() => _selectedCategory = null),
                        isDark: isDark,
                        colors: colors,
                        insightsColor: insightsColor,
                      ),
                      const SizedBox(width: 8),
                      ...ExperienceCategory.values.map((cat) {
                        final count = _experiences.where((e) => e.category == cat).length;
                        return Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: _buildFilterChip(
                            label: '${cat.emoji} ${cat.labelFa} (${PersianDigits.convert(count.toString())})',
                            isSelected: _selectedCategory == cat,
                            onTap: () => setState(() => _selectedCategory = cat),
                            isDark: isDark,
                            colors: colors,
                            insightsColor: insightsColor,
                          ),
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
                            child: CustomScrollView(
                              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                              slivers: [
                                SliverPadding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  sliver: SliverList(
                                    delegate: SliverChildListDelegate([
                                      if (_selectedCategory == null && featuredExp != null) ...[
                                        _buildFeaturedHeroCard(context, featuredExp, isDark, colors, insightsColor),
                                        const SizedBox(height: 14),
                                        Row(
                                          children: [
                                            Icon(CupertinoIcons.sparkles, size: 14, color: insightsColor),
                                            const SizedBox(width: 6),
                                            Text(
                                              'همه آموزه‌ها (${PersianDigits.convert(filtered.length.toString())})',
                                              style: TextStyle(
                                                fontFamily: 'Vazirmatn',
                                                fontSize: 13.5,
                                                fontWeight: FontWeight.w800,
                                                color: colors.textPrimary,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                      ],
                                    ]),
                                  ),
                                ),
                                SliverPadding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  sliver: SliverList(
                                    delegate: SliverChildBuilderDelegate(
                                      (ctx, i) => _buildWisdomCard(context, filtered[i], isDark, colors, insightsColor),
                                      childCount: filtered.length,
                                    ),
                                  ),
                                ),
                                const SliverToBoxAdapter(child: SizedBox(height: 90)),
                              ],
                            ),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
    required RitmoColors colors,
    required Color insightsColor,
  }) {
    return InkWell(
      onTap: () {
        RitmoHapticsPolicy.selection();
        onTap();
      },
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? insightsColor.withValues(alpha: isDark ? 0.22 : 0.14)
              : colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? insightsColor.withValues(alpha: 0.6)
                : colors.border,
            width: isSelected ? 1.2 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Vazirmatn',
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? insightsColor : colors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildFeaturedHeroCard(
    BuildContext context,
    Experience exp,
    bool isDark,
    RitmoColors colors,
    Color insightsColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: insightsColor.withValues(alpha: 0.45),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: insightsColor.withValues(alpha: isDark ? 0.12 : 0.08),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: insightsColor.withValues(alpha: isDark ? 0.2 : 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: insightsColor.withValues(alpha: 0.4),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(CupertinoIcons.sparkles, size: 12, color: insightsColor),
                    const SizedBox(width: 5),
                    Text(
                      'درس برگزیده • ${exp.category.labelFa}',
                      style: TextStyle(
                        fontFamily: 'Vazirmatn',
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: insightsColor,
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
                      color: starFilled ? insightsColor : colors.textTertiary.withValues(alpha: 0.35),
                    ),
                  );
                }),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '« ${exp.lesson} »',
            style: TextStyle(
              fontFamily: 'Vazirmatn',
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: colors.textPrimary,
              height: 1.45,
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
                fontSize: 12,
                color: colors.textSecondary.withValues(alpha: 0.8),
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWisdomCard(
    BuildContext context,
    Experience exp,
    bool isDark,
    RitmoColors colors,
    Color insightsColor,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colors.border,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: isDark ? 0.22 : 0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () async {
            RitmoHapticsPolicy.tap();
            final note = await NotesRepository.instance.getById(exp.noteId);
            if (note != null && context.mounted) {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => NoteEditorScreen(note: note, isExperience: true)),
              );
              await _loadData();
            }
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Category, Stars & Active Switch
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: insightsColor.withValues(alpha: isDark ? 0.2 : 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: insightsColor.withValues(alpha: 0.4),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(exp.category.emoji, style: const TextStyle(fontSize: 12)),
                        const SizedBox(width: 4),
                        Text(
                          exp.category.labelFa,
                          style: TextStyle(
                            fontFamily: 'Vazirmatn',
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: insightsColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      ...List.generate(5, (idx) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 1),
                          child: Icon(
                            idx < exp.importance ? CupertinoIcons.star_fill : CupertinoIcons.star,
                            size: 11,
                            color: idx < exp.importance ? insightsColor : colors.textTertiary.withValues(alpha: 0.35),
                          ),
                        );
                      }),
                      const SizedBox(width: 8),
                      CupertinoSwitch(
                        value: exp.isActive,
                        activeTrackColor: colors.success,
                        onChanged: (val) async {
                          RitmoHapticsPolicy.selection();
                          await ExperienceRepository.instance.setActive(exp.noteId, val);
                          await _loadData();
                        },
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Lesson Text
              Text(
                '« ${exp.lesson} »',
                style: TextStyle(
                  fontFamily: 'Vazirmatn',
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: colors.textPrimary,
                  height: 1.4,
                ),
              ),

              if (exp.contextText != null && exp.contextText!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  exp.contextText!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Vazirmatn',
                    fontSize: 11.5,
                    color: colors.textSecondary.withValues(alpha: 0.75),
                    height: 1.35,
                  ),
                ),
              ],
              const SizedBox(height: 10),

              // Bottom Stats Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'مرور شده: ${PersianDigits.convert(exp.showCount.toString())} بار',
                    style: TextStyle(
                      fontFamily: 'Vazirmatn',
                      fontSize: 10.5,
                      color: colors.textTertiary,
                    ),
                  ),
                  Row(
                    children: [
                      Icon(CupertinoIcons.checkmark_seal_fill, size: 12, color: colors.success),
                      const SizedBox(width: 4),
                      Text(
                        '${PersianDigits.convert(exp.acknowledgedCount.toString())} تایید',
                        style: TextStyle(
                          fontFamily: 'Vazirmatn',
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: colors.success,
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
    );
  }

  Widget _buildEmptyState(RitmoColors colors) {
    return RitmoEmptyState(
      icon: CupertinoIcons.lightbulb,
      title: 'هیچ تجربه یا درسی ثبت نشده',
      description: 'با ثبت درس‌های ماندگار زندگی، سیستم بازخوانی هوشمند روزانه آن‌ها را به شما یادآوری می‌کند.',
    );
  }
}
