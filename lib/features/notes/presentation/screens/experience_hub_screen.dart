import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_card.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_chip.dart';
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

    final filtered = _selectedCategory == null
        ? _experiences
        : _experiences.where((e) => e.category == _selectedCategory).toList();

    final featuredExp = _featuredExp;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: RitmoPageScaffold(
        padding: EdgeInsets.zero,
        appBar: AppBar(
          backgroundColor: colors.surface,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: colors.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'بانک درس‌ها و تجربه‌ها',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colors.textPrimary,
                ),
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.psychology_outlined, color: insightsColor, size: 22),
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
            const SizedBox(width: RitmoSpacing.xs),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
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
          icon: const Icon(CupertinoIcons.pencil, color: Colors.white, size: 18),
          label: Text(
            'ثبت تجربه جدید',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
          ),
        ),
        body: Column(
          children: [
            // Category Horizontal Sliding Selector
            Container(
              padding: const EdgeInsets.symmetric(vertical: RitmoSpacing.sm, horizontal: RitmoSpacing.lg),
              color: colors.surface,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    RitmoChip(
                      label: 'همه (${PersianDigits.convert(_experiences.length.toString())})',
                      isSelected: _selectedCategory == null,
                      color: insightsColor,
                      onTap: () {
                        setState(() => _selectedCategory = null);
                      },
                    ),
                    const SizedBox(width: RitmoSpacing.sm),
                    ...ExperienceCategory.values.map((cat) {
                      final count = _experiences.where((e) => e.category == cat).length;
                      return Padding(
                        padding: const EdgeInsets.only(left: RitmoSpacing.sm),
                        child: RitmoChip(
                          label: '${cat.emoji} ${cat.labelFa} (${PersianDigits.convert(count.toString())})',
                          isSelected: _selectedCategory == cat,
                          color: insightsColor,
                          onTap: () {
                            setState(() => _selectedCategory = cat);
                          },
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
                                padding: const EdgeInsets.symmetric(horizontal: RitmoSpacing.lg, vertical: RitmoSpacing.md),
                                sliver: SliverList(
                                  delegate: SliverChildListDelegate([
                                    if (_selectedCategory == null && featuredExp != null) ...[
                                      _buildFeaturedHeroCard(context, featuredExp),
                                      const SizedBox(height: RitmoSpacing.lg),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: RitmoSpacing.xs),
                                        child: Row(
                                          children: [
                                            Icon(CupertinoIcons.sparkles, size: 14, color: insightsColor),
                                            const SizedBox(width: RitmoSpacing.xs),
                                            Text(
                                              'همه آموزه‌ها (${PersianDigits.convert(filtered.length.toString())})',
                                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                                    fontWeight: FontWeight.bold,
                                                    color: colors.textPrimary,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: RitmoSpacing.sm),
                                    ],
                                  ]),
                                ),
                              ),
                              SliverPadding(
                                padding: const EdgeInsets.symmetric(horizontal: RitmoSpacing.lg),
                                sliver: SliverList(
                                  delegate: SliverChildBuilderDelegate(
                                    (ctx, i) => _buildWisdomCard(context, filtered[i]),
                                    childCount: filtered.length,
                                  ),
                                ),
                              ),
                              const SliverToBoxAdapter(child: SizedBox(height: RitmoSpacing.xxxl * 2)),
                            ],
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturedHeroCard(BuildContext context, Experience exp) {
    final colors = context.colors;
    final insightsColor = context.modules.insights;
    final isDark = context.isDark;

    return Container(
      padding: const EdgeInsets.all(RitmoSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [insightsColor.withValues(alpha: 0.2), colors.surfaceSunken]
              : [insightsColor.withValues(alpha: 0.12), colors.surface],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(RitmoRadius.hero),
        border: Border.all(color: insightsColor.withValues(alpha: 0.35)),
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
                padding: const EdgeInsets.symmetric(horizontal: RitmoSpacing.sm, vertical: RitmoSpacing.xs / 2),
                decoration: BoxDecoration(
                  color: insightsColor.withValues(alpha: isDark ? 0.25 : 0.15),
                  borderRadius: BorderRadius.circular(RitmoRadius.pill),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(CupertinoIcons.sparkles, size: 12, color: insightsColor),
                    const SizedBox(width: RitmoSpacing.xs),
                    Text(
                      'درس برگزیده • ${exp.category.labelFa}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
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
                      color: starFilled ? insightsColor : colors.textTertiary,
                    ),
                  );
                }),
              ),
            ],
          ),
          const SizedBox(height: RitmoSpacing.md),
          Text(
            '« ${exp.lesson} »',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colors.textPrimary,
                  height: 1.5,
                ),
          ),
          if (exp.contextText != null && exp.contextText!.isNotEmpty) ...[
            const SizedBox(height: RitmoSpacing.sm),
            Text(
              exp.contextText!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.textSecondary,
                    height: 1.45,
                  ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWisdomCard(BuildContext context, Experience exp) {
    final colors = context.colors;
    final insightsColor = context.modules.insights;

    return RitmoCard(
      margin: const EdgeInsets.symmetric(vertical: RitmoSpacing.xs),
      padding: const EdgeInsets.all(RitmoSpacing.md),
      onTap: () async {
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
                padding: const EdgeInsets.symmetric(horizontal: RitmoSpacing.sm, vertical: RitmoSpacing.xs / 2),
                decoration: BoxDecoration(
                  color: insightsColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(RitmoRadius.pill),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(exp.category.emoji, style: Theme.of(context).textTheme.labelSmall),
                    const SizedBox(width: RitmoSpacing.xs),
                    Text(
                      exp.category.labelFa,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
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
                    final isFilled = idx < exp.importance;
                    return GestureDetector(
                      onTap: () async {
                        RitmoHapticsPolicy.selection();
                        await ExperienceRepository.instance.setImportance(exp.noteId, idx + 1);
                        await _loadData();
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 1),
                        child: Icon(
                          isFilled ? CupertinoIcons.star_fill : CupertinoIcons.star,
                          size: 14,
                          color: isFilled ? insightsColor : colors.textTertiary,
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ],
          ),
          const SizedBox(height: RitmoSpacing.sm),

          // Lesson Text
          Text(
            exp.lesson,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                  height: 1.45,
                ),
          ),

          // Context Text
          if (exp.contextText != null && exp.contextText!.trim().isNotEmpty) ...[
            const SizedBox(height: RitmoSpacing.xs),
            Text(
              exp.contextText!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.textSecondary,
                    height: 1.4,
                  ),
            ),
          ],
          const SizedBox(height: RitmoSpacing.sm),

          // Footer: DayKey & Active Switch
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                exp.occurredOnDayKey != null ? 'ثبت در روز: ${PersianDigits.convert(exp.occurredOnDayKey!)}' : '',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colors.textTertiary,
                    ),
              ),
              Row(
                children: [
                  Text(
                    exp.isActive ? 'پیشنهاد روزانه فعال' : 'پیشنهاد غیرفعال',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: exp.isActive ? insightsColor : colors.textTertiary,
                        ),
                  ),
                  const SizedBox(width: RitmoSpacing.xs),
                  SizedBox(
                    height: 20,
                    width: 32,
                    child: Transform.scale(
                      scale: 0.65,
                      child: Switch(
                        value: exp.isActive,
                        activeThumbColor: insightsColor,
                        onChanged: (val) async {
                          RitmoHapticsPolicy.selection();
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
    );
  }

  Widget _buildEmptyState(RitmoColors colors) {
    return RitmoEmptyState(
      icon: Icons.lightbulb_outline_rounded,
      title: 'هنوز درسی ثبت نکرده‌اید',
      description: 'درس‌ها و آموزه‌های کلیدی زندگی خود را بنویسید تا سیستم بازنمایی روزانه آن‌ها را به شما یادآوری کند.',
      actionLabel: 'ثبت اولین تجربه',
      onAction: () async {
        RitmoHapticsPolicy.tap();
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const NoteEditorScreen(isExperience: true)),
        );
        if (mounted) await _loadData();
      },
    );
  }
}
