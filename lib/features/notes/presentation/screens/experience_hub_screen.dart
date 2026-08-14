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
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
            'بانک درس‌ها و تجربه‌ها 💡',
            style: TextStyle(
              fontFamily: 'Vazirmatn',
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: colors.textPrimary,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.psychology, color: Color(0xFFE5A00D)),
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
          icon: const Icon(CupertinoIcons.add, color: Colors.white, size: 20),
          label: const Text(
            'ثبت تجربه جدید',
            style: TextStyle(fontFamily: 'Vazirmatn', fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
          ),
        ),
        body: Column(
          children: [
            // Category Horizontal Selector
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
              color: colors.surface,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildCategoryPill('همه', null, '🌟', _experiences.length),
                    const SizedBox(width: 6),
                    ...ExperienceCategory.values.map((cat) {
                      final count = _experiences.where((e) => e.category == cat).length;
                      return Padding(
                        padding: const EdgeInsets.only(left: 6),
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
                  ? Center(child: CircularProgressIndicator(color: const Color(0xFFE5A00D)))
                  : filtered.isEmpty
                      ? _buildEmptyState(context)
                      : RefreshIndicator(
                          onRefresh: _loadData,
                          child: ListView(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            children: [
                              // Featured Wisdom Hero Card (Shown when 'All' is selected)
                              if (_selectedCategory == null && featuredExp != null) ...[
                                _buildFeaturedHeroCard(context, featuredExp),
                                const SizedBox(height: 16),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  child: Text(
                                    'همه آموزه‌ها (${PersianDigits.convert(filtered.length.toString())})',
                                    style: TextStyle(
                                      fontFamily: 'Vazirmatn',
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: colors.textSecondary,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
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

    return InkWell(
      onTap: () {
        RitmoHaptics.selection();
        setState(() => _selectedCategory = cat);
      },
      borderRadius: BorderRadius.circular(RitmoRadius.pill),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE5A00D) : colors.surfaceSunken,
          borderRadius: BorderRadius.circular(RitmoRadius.pill),
          border: Border.all(
            color: isSelected ? const Color(0xFFE5A00D) : colors.border.withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 12)),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Vazirmatn',
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.white : colors.textPrimary,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white.withValues(alpha: 0.25) : const Color(0xFFE5A00D).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  PersianDigits.convert(count.toString()),
                  style: TextStyle(
                    fontFamily: 'Vazirmatn',
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : const Color(0xFFE5A00D),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturedHeroCard(BuildContext context, Experience exp) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF332505), colors.card]
              : [const Color(0xFFFFF7DB), const Color(0xFFFFFDF5)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(RitmoRadius.hero),
        border: Border.all(color: const Color(0xFFE5A00D).withValues(alpha: 0.45)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE5A00D).withValues(alpha: 0.1),
            blurRadius: 16,
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
              Row(
                children: [
                  const Text('✨', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 6),
                  Text(
                    'درس برگزیده • ${exp.category.labelFa}',
                    style: TextStyle(
                      fontFamily: 'Vazirmatn',
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFE5A00D),
                    ),
                  ),
                ],
              ),
              Row(
                children: List.generate(5, (idx) {
                  return Icon(
                    idx < exp.importance ? CupertinoIcons.star_fill : CupertinoIcons.star,
                    size: 13,
                    color: idx < exp.importance ? Colors.amber : colors.textTertiary,
                  );
                }),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '« ${exp.lesson} »',
            style: TextStyle(
              fontFamily: 'Vazirmatn',
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: colors.textPrimary,
              height: 1.45,
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
                fontSize: 12,
                color: colors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWisdomCard(BuildContext context, Experience exp) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF241C06) : const Color(0xFFFFFDF7),
        borderRadius: BorderRadius.circular(RitmoRadius.card),
        border: Border.all(
          color: const Color(0xFFE5A00D).withValues(alpha: 0.25),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
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
                MaterialPageRoute(builder: (_) => NoteEditorScreen(note: note)),
              );
              if (mounted) await _loadData();
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(exp.category.emoji, style: const TextStyle(fontSize: 15)),
                        const SizedBox(width: 6),
                        Text(
                          exp.category.labelFa,
                          style: TextStyle(
                            fontFamily: 'Vazirmatn',
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFFE5A00D),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          'پیشنهاد روزانه',
                          style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 10, color: colors.textSecondary),
                        ),
                        const SizedBox(width: 4),
                        CupertinoSwitch(
                          value: exp.isActive,
                          activeTrackColor: const Color(0xFFE5A00D),
                          onChanged: (val) async {
                            RitmoHaptics.selection();
                            await ExperienceRepository.instance.setActive(exp.noteId, val);
                            if (mounted) await _loadData();
                          },
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  exp.lesson,
                  style: TextStyle(
                    fontFamily: 'Vazirmatn',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: colors.textPrimary,
                    height: 1.4,
                  ),
                ),
                if (exp.contextText != null && exp.contextText!.isNotEmpty) ...[
                  const SizedBox(height: 4),
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: List.generate(5, (sIdx) {
                        return Icon(
                          sIdx < exp.importance ? CupertinoIcons.star_fill : CupertinoIcons.star,
                          size: 12,
                          color: sIdx < exp.importance ? Colors.amber : colors.textTertiary,
                        );
                      }),
                    ),
                    Text(
                      'مرور شده: ${PersianDigits.convert(exp.showCount.toString())} بار',
                      style: TextStyle(
                        fontFamily: 'Vazirmatn',
                        fontSize: 10,
                        color: colors.textTertiary,
                      ),
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

  Widget _buildEmptyState(BuildContext context) {
    final colors = context.colors;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFE5A00D).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.lightbulb_outline_rounded,
                size: 48,
                color: Color(0xFFE5A00D),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'هیچ تجربه‌ای در این بخش ثبت نشده',
              style: TextStyle(
                fontFamily: 'Vazirmatn',
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'درس‌هایی که از شکست‌ها، موفقیت‌ها و رخدادهای زندگی می‌گیری را ثبت کن تا در زمان مناسب یادآوری شوند.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Vazirmatn',
                fontSize: 12,
                color: colors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () async {
                RitmoHaptics.confirm();
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NoteEditorScreen(isExperience: true)),
                );
                _loadData();
              },
              icon: const Icon(CupertinoIcons.add, size: 16),
              label: const Text('ثبت اولین تجربه', style: TextStyle(fontFamily: 'Vazirmatn', fontWeight: FontWeight.bold)),
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
