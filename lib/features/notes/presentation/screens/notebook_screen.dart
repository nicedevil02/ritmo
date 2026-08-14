import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/ux/ritmo_haptics.dart';
import 'package:ritmo/features/notes/data/notes_repository.dart';
import 'package:ritmo/features/notes/domain/note_models.dart';
import 'package:ritmo/features/notes/logic/note_fts_engine.dart';
import 'package:ritmo/core/domain/personas/persona_registry.dart';
import 'package:ritmo/features/assistant/presentation/widgets/unified_assistant_sheet.dart';
import 'package:ritmo/features/notes/presentation/screens/experience_hub_screen.dart';
import 'package:ritmo/features/notes/presentation/screens/note_editor_screen.dart';
import 'package:ritmo/features/notes/presentation/screens/note_srs_review_screen.dart';
import 'package:ritmo/features/notes/presentation/screens/note_trash_archive_screen.dart';
import 'package:ritmo/features/notes/presentation/screens/weekly_review_screen.dart';
import 'package:ritmo/features/notes/presentation/widgets/note_card.dart';
import 'package:ritmo/features/notes/presentation/widgets/ritmo_shimmer.dart';

class NotebookScreen extends StatefulWidget {
  const NotebookScreen({super.key});

  @override
  State<NotebookScreen> createState() => _NotebookScreenState();
}

class _NotebookScreenState extends State<NotebookScreen> with SingleTickerProviderStateMixin {
  List<Note> _notes = [];
  bool _isLoading = true;
  String _searchQuery = '';
  NoteKind? _selectedKind;
  bool _isGridView = true;

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  Timer? _searchDebounceTimer;
  int _searchSequence = 0;
  Map<String, int> _countsByKind = {};

  bool _isSearchingFocused = false;
  bool _isFabCompact = false;
  bool _hasInitialAnimated = false;

  @override
  void initState() {
    super.initState();
    _searchFocusNode.addListener(_onSearchFocusChanged);
    _scrollController.addListener(_onScrollChanged);
    _loadNotes();
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    _searchController.dispose();
    _searchFocusNode.removeListener(_onSearchFocusChanged);
    _searchFocusNode.dispose();
    _scrollController.removeListener(_onScrollChanged);
    _scrollController.dispose();
    super.dispose();
  }

  void _onSearchFocusChanged() {
    if (mounted) {
      setState(() {
        _isSearchingFocused = _searchFocusNode.hasFocus;
      });
    }
  }

  void _onScrollChanged() {
    if (_scrollController.position.userScrollDirection == ScrollDirection.reverse) {
      if (!_isFabCompact) {
        setState(() => _isFabCompact = true);
      }
    } else if (_scrollController.position.userScrollDirection == ScrollDirection.forward) {
      if (_isFabCompact) {
        setState(() => _isFabCompact = false);
      }
    }
  }

  void _onSearchChanged(String query) {
    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() => _searchQuery = query);
        _loadNotes();
      }
    });
  }

  Future<void> _loadNotes() async {
    final currentSeq = ++_searchSequence;
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final notes = await NoteFtsEngine.instance.search(
        _searchQuery,
        kind: _selectedKind,
      );
      final counts = await NotesRepository.instance.countByKind();

      if (mounted && currentSeq == _searchSequence) {
        setState(() {
          _notes = notes;
          _countsByKind = counts;
          _isLoading = false;
        });

        // Mark entrance animation played
        if (!_hasInitialAnimated) {
          Future.delayed(const Duration(milliseconds: 600), () {
            if (mounted) _hasInitialAnimated = true;
          });
        }
      }
    } catch (e, st) {
      debugPrint('Error loading notes in NotebookScreen: $e\n$st');
      if (mounted && currentSeq == _searchSequence) {
        setState(() {
          _notes = [];
          _isLoading = false;
        });
      }
    }
  }

  void _onKindSelected(NoteKind? kind) {
    RitmoHaptics.selection();
    setState(() {
      _selectedKind = kind;
    });
    _loadNotes();
  }

  void _openAiAssistantSheet() {
    RitmoHaptics.selection();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final persona = PersonaRegistry.instance.getPersona('notes') ?? PersonaRegistry.instance.getPersona('global')!;
        return AssistantSheet(persona: persona);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final pinnedNotes = _notes.where((n) => n.isPinned).toList();
    final otherNotes = _notes.where((n) => !n.isPinned).toList();

    final totalActiveCount = _countsByKind.values.fold<int>(0, (sum, c) => sum + c);
    final noteCount = _countsByKind['NOTE'] ?? 0;
    final experienceCount = _countsByKind['EXPERIENCE'] ?? 0;
    final ideaCount = _countsByKind['IDEA'] ?? 0;
    final decisionCount = _countsByKind['DECISION'] ?? 0;
    final dailyCount = _countsByKind['DAILY'] ?? 0;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: colors.background,
        floatingActionButton: AnimatedScale(
          scale: _isFabCompact ? 0.92 : 1.0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          child: FloatingActionButton.extended(
            onPressed: () async {
              RitmoHaptics.confirm();
              if (!context.mounted) return;
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NoteEditorScreen()),
              );
              if (mounted) await _loadNotes();
            },
            elevation: 4,
            highlightElevation: 8,
            backgroundColor: colors.primary,
            icon: const Icon(CupertinoIcons.pencil, color: Colors.white, size: 20),
            label: const Text(
              'یادداشت جدید',
              style: TextStyle(
                fontFamily: 'Vazirmatn',
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontSize: 13.5,
              ),
            ),
          ),
        ),
        body: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          slivers: [
            // iOS-Style Large Title SliverAppBar
            SliverAppBar(
              backgroundColor: colors.surface,
              expandedHeight: 110,
              pinned: true,
              elevation: 0,
              scrolledUnderElevation: 0.5,
              shadowColor: Colors.black.withValues(alpha: 0.1),
              leading: IconButton(
                icon: Icon(Icons.arrow_back, color: colors.textPrimary),
                onPressed: () => Navigator.pop(context),
              ),
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: const EdgeInsetsDirectional.only(start: 20, bottom: 14),
                title: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      'دفترچه',
                      style: TextStyle(
                        fontFamily: 'Vazirmatn',
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: colors.textPrimary,
                      ),
                    ),
                    if (!_isLoading && totalActiveCount > 0) ...[
                      const SizedBox(width: 8),
                      Text(
                        '(${PersianDigits.convert(totalActiveCount.toString())} یادداشت)',
                        style: TextStyle(
                          fontFamily: 'Vazirmatn',
                          fontSize: 11,
                          fontWeight: FontWeight.normal,
                          color: colors.textTertiary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.lightbulb_rounded, color: Color(0xFFE5A00D), size: 22),
                  tooltip: 'بانک درس‌های زندگی',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ExperienceHubScreen()),
                    ).then((_) {
                      if (mounted) _loadNotes();
                    });
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.psychology_outlined, color: Color(0xFF10B981), size: 22),
                  tooltip: 'مرور فاصله‌دار یادگیری',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const NoteSrsReviewScreen()),
                    ).then((_) {
                      if (mounted) _loadNotes();
                    });
                  },
                ),
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, color: colors.textPrimary, size: 22),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  onSelected: (val) {
                    RitmoHaptics.selection();
                    if (val == 'weekly') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const WeeklyReviewScreen()),
                      ).then((_) {
                        if (mounted) _loadNotes();
                      });
                    } else if (val == 'trash') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const NoteTrashArchiveScreen()),
                      ).then((_) {
                        if (mounted) _loadNotes();
                      });
                    } else if (val == 'assistant') {
                      _openAiAssistantSheet();
                    }
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'weekly',
                      child: Row(
                        children: [
                          Icon(CupertinoIcons.chart_bar_alt_fill, size: 16),
                          SizedBox(width: 10),
                          Text('مرور هفتگی دفترچه', style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 13)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'trash',
                      child: Row(
                        children: [
                          Icon(CupertinoIcons.archivebox, size: 16),
                          SizedBox(width: 10),
                          Text('سطل زباله و بایگانی', style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 13)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'assistant',
                      child: Row(
                        children: [
                          Icon(CupertinoIcons.sparkles, size: 16, color: Color(0xFF8B5CF6)),
                          SizedBox(width: 10),
                          Text('دستیار هوش مصنوعی', style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 6),
              ],
            ),

            // Pinned Search & Filter Controls Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                child: Column(
                  children: [
                    // Search Bar Row
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 44,
                            decoration: BoxDecoration(
                              color: colors.surfaceSunken,
                              borderRadius: BorderRadius.circular(RitmoRadius.field),
                              border: Border.all(
                                color: _isSearchingFocused
                                    ? colors.primary.withValues(alpha: 0.5)
                                    : colors.border.withValues(alpha: 0.15),
                                width: _isSearchingFocused ? 1.2 : 0.8,
                              ),
                            ),
                            child: TextField(
                              controller: _searchController,
                              focusNode: _searchFocusNode,
                              textDirection: TextDirection.rtl,
                              style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 13.5, color: colors.textPrimary),
                              decoration: InputDecoration(
                                hintText: 'جستجو در عنوان، متن یا برچسب‌ها...',
                                hintStyle: TextStyle(fontFamily: 'Vazirmatn', fontSize: 12.5, color: colors.textTertiary),
                                prefixIcon: Icon(CupertinoIcons.search, size: 17, color: colors.textSecondary),
                                suffixIcon: _searchController.text.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(CupertinoIcons.clear_circled_solid, size: 16),
                                        onPressed: () {
                                          _searchController.clear();
                                          setState(() => _searchQuery = '');
                                          _loadNotes();
                                        },
                                      )
                                    : null,
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(vertical: 11),
                              ),
                              onChanged: _onSearchChanged,
                            ),
                          ),
                        ),
                        if (_isSearchingFocused) ...[
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: () {
                              _searchController.clear();
                              _searchFocusNode.unfocus();
                              setState(() {
                                _searchQuery = '';
                                _isSearchingFocused = false;
                              });
                              _loadNotes();
                            },
                            child: Text(
                              'انصراف',
                              style: TextStyle(
                                fontFamily: 'Vazirmatn',
                                fontSize: 13,
                                color: colors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                        if (!_isSearchingFocused) ...[
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: () {
                              RitmoHaptics.selection();
                              setState(() => _isGridView = !_isGridView);
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              height: 44,
                              width: 44,
                              decoration: BoxDecoration(
                                color: colors.surfaceSunken,
                                borderRadius: BorderRadius.circular(RitmoRadius.field),
                                border: Border.all(color: colors.border.withValues(alpha: 0.15)),
                              ),
                              child: Icon(
                                _isGridView ? CupertinoIcons.rectangle_grid_1x2 : CupertinoIcons.square_grid_2x2,
                                size: 18,
                                color: colors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),

                    // Filter Chips Bar (Animated Fade when search is focused)
                    AnimatedCrossFade(
                      duration: const Duration(milliseconds: 200),
                      crossFadeState: _isSearchingFocused ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                      secondChild: const SizedBox(height: 8),
                      firstChild: Column(
                        children: [
                          const SizedBox(height: 12),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            child: Row(
                              children: [
                                _buildFilterPill(null, 'همه (${PersianDigits.convert(totalActiveCount.toString())})', Icons.all_inclusive_rounded, colors.primary),
                                const SizedBox(width: 8),
                                _buildFilterPill(NoteKind.note, 'یادداشت‌ها (${PersianDigits.convert(noteCount.toString())})', Icons.description_rounded, colors.primary),
                                const SizedBox(width: 8),
                                _buildFilterPill(NoteKind.experience, 'درس زندگی (${PersianDigits.convert(experienceCount.toString())})', Icons.lightbulb_rounded, const Color(0xFFE5A00D)),
                                const SizedBox(width: 8),
                                _buildFilterPill(NoteKind.idea, 'ایده‌ها (${PersianDigits.convert(ideaCount.toString())})', Icons.bolt_rounded, const Color(0xFF00B4D8)),
                                const SizedBox(width: 8),
                                _buildFilterPill(NoteKind.decision, 'تصمیم‌ها (${PersianDigits.convert(decisionCount.toString())})', Icons.check_circle_rounded, const Color(0xFF10B981)),
                                const SizedBox(width: 8),
                                _buildFilterPill(NoteKind.daily, 'ژورنال (${PersianDigits.convert(dailyCount.toString())})', Icons.auto_stories_rounded, const Color(0xFFEC4899)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Content Area
            if (_isLoading)
              const SliverToBoxAdapter(
                child: RitmoShimmerGrid(count: 6),
              )
            else if (_notes.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _buildEmptyState(colors),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Pinned Notes Section
                    if (pinnedNotes.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8, top: 4),
                        child: Row(
                          children: [
                            const Icon(CupertinoIcons.pin_fill, size: 14, color: Color(0xFFE5A00D)),
                            const SizedBox(width: 6),
                            Text(
                              'سنجاق‌شده (${PersianDigits.convert(pinnedNotes.length.toString())})',
                              style: TextStyle(
                                fontFamily: 'Vazirmatn',
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: colors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _buildNotesLayout(pinnedNotes),
                      const SizedBox(height: 16),
                      if (otherNotes.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            'سایر یادداشت‌ها',
                            style: TextStyle(
                              fontFamily: 'Vazirmatn',
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: colors.textSecondary,
                            ),
                          ),
                        ),
                    ],

                    // Other Notes Section
                    if (otherNotes.isNotEmpty) _buildNotesLayout(otherNotes),

                    const SizedBox(height: 80),
                  ]),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterPill(NoteKind? kind, String label, IconData icon, Color color) {
    final isSelected = _selectedKind == kind;
    final colors = context.colors;

    return AnimatedScale(
      scale: isSelected ? 1.0 : 0.97,
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOutCubic,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(RitmoRadius.pill),
          onTap: () => _onKindSelected(kind),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6.5),
            decoration: BoxDecoration(
              color: isSelected ? color.withValues(alpha: 0.15) : colors.surfaceSunken,
              borderRadius: BorderRadius.circular(RitmoRadius.pill),
              border: Border.all(
                color: isSelected ? color.withValues(alpha: 0.5) : colors.border.withValues(alpha: 0.15),
                width: isSelected ? 1.2 : 0.8,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 13, color: isSelected ? color : colors.textSecondary),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Vazirmatn',
                    fontSize: 11.5,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? color : colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNotesLayout(List<Note> notesList) {
    if (_isGridView) {
      final col1 = <Widget>[];
      final col2 = <Widget>[];

      for (int i = 0; i < notesList.length; i++) {
        final note = notesList[i];
        final cardWidget = _wrapStaggeredAnimation(
          index: i,
          child: NoteCard(
            note: note,
            isGrid: true,
            searchQuery: _searchQuery,
            onChanged: _loadNotes,
          ),
        );

        if (i % 2 == 0) {
          col1.add(cardWidget);
        } else {
          col2.add(cardWidget);
        }
      }

      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Column(children: col1)),
          const SizedBox(width: 8),
          Expanded(child: Column(children: col2)),
        ],
      );
    } else {
      return Column(
        children: List.generate(notesList.length, (i) {
          final note = notesList[i];
          return _wrapStaggeredAnimation(
            index: i,
            child: NoteCard(
              note: note,
              isGrid: false,
              searchQuery: _searchQuery,
              onChanged: _loadNotes,
            ),
          );
        }),
      );
    }
  }

  Widget _wrapStaggeredAnimation({required int index, required Widget child}) {
    if (_hasInitialAnimated || MediaQuery.of(context).disableAnimations) {
      return child;
    }

    final delay = (40 * index).clamp(0, 360);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 280 + delay),
      curve: Curves.easeOutCubic,
      builder: (context, value, animChild) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 12 * (1 - value)),
            child: animChild,
          ),
        );
      },
      child: child,
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
                color: colors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _searchQuery.isNotEmpty ? CupertinoIcons.search : CupertinoIcons.book,
                size: 32,
                color: colors.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty ? 'نتیجه‌ای یافت نشد' : 'دفترچه یادداشت شما خالی است',
              style: TextStyle(
                fontFamily: 'Vazirmatn',
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _searchQuery.isNotEmpty
                  ? 'عبارت دیگری را جستجو کنید یا فیلتر دسته‌بندی را تغییر دهید.'
                  : 'ایده‌ها، تصمیمات و تجارب ارزشمند زندگی خود را بنویسید تا ماندگار شوند.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Vazirmatn',
                fontSize: 12.5,
                color: colors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            if (_searchQuery.isEmpty)
              ElevatedButton.icon(
                onPressed: () async {
                  RitmoHaptics.confirm();
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const NoteEditorScreen()),
                  );
                  if (mounted) await _loadNotes();
                },
                icon: const Icon(CupertinoIcons.pencil, size: 16),
                label: const Text(
                  'نوشتن اولین یادداشت',
                  style: TextStyle(fontFamily: 'Vazirmatn', fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary,
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
