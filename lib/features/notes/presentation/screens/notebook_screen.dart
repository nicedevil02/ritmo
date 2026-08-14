import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_card.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_chip.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_empty_state.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_page_scaffold.dart';
import 'package:ritmo/core/domain/personas/persona_registry.dart';
import 'package:ritmo/features/assistant/presentation/widgets/unified_assistant_sheet.dart';
import 'package:ritmo/features/notes/data/experience_repository.dart';
import 'package:ritmo/features/notes/data/notes_repository.dart';
import 'package:ritmo/features/notes/domain/note_models.dart';
import 'package:ritmo/features/notes/logic/note_fts_engine.dart';
import 'package:ritmo/features/notes/logic/spaced_repetition_engine.dart';
import 'package:ritmo/features/notes/logic/weekly_review_engine.dart';
import 'package:ritmo/features/notes/presentation/screens/note_editor_screen.dart';
import 'package:ritmo/features/notes/presentation/screens/note_srs_review_screen.dart';
import 'package:ritmo/features/notes/presentation/screens/note_trash_archive_screen.dart';
import 'package:ritmo/features/notes/presentation/screens/weekly_review_screen.dart';
import 'package:ritmo/features/notes/presentation/utils/note_ui_helper.dart';
import 'package:ritmo/features/notes/presentation/widgets/note_card.dart';
import 'package:ritmo/features/notes/presentation/widgets/ritmo_shimmer.dart';

const Duration _kSearchDebounce = Duration(milliseconds: 300);

class NotebookScreen extends StatefulWidget {
  const NotebookScreen({super.key});

  @override
  State<NotebookScreen> createState() => _NotebookScreenState();
}

class _NotebookScreenState extends State<NotebookScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // --- Tab 0 (Notes) State ---
  List<Note> _notes = [];
  bool _isLoadingNotes = true;
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

  // --- Tab 1 (Experiences) State ---
  List<Experience> _experiences = [];
  Experience? _featuredExp;
  bool _isLoadingExp = true;
  ExperienceCategory? _selectedCategory;

  // --- Tab 2 (Review & Analytics) State ---
  bool _isLoadingReview = true;
  int _dueNotesCount = 0;
  int _dustyNotesCount = 0;
  int _createdThisWeekCount = 0;
  int _archivedCount = 0;
  int _trashCount = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);

    _searchFocusNode.addListener(_onSearchFocusChanged);
    _scrollController.addListener(_onScrollChanged);

    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _searchDebounceTimer?.cancel();
    _searchController.dispose();
    _searchFocusNode.removeListener(_onSearchFocusChanged);
    _searchFocusNode.dispose();
    _scrollController.removeListener(_onScrollChanged);
    _scrollController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (mounted) {
      RitmoHapticsPolicy.selection();
      setState(() {});
    }
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

  Future<void> _loadAllData() async {
    await Future.wait([
      _loadNotes(),
      _loadExperiences(),
      _loadReviewStats(),
    ]);
  }

  // --- Load Notes (Tab 0) ---
  void _onSearchChanged(String query) {
    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = Timer(_kSearchDebounce, () {
      if (mounted) {
        setState(() => _searchQuery = query);
        _loadNotes();
      }
    });
  }

  Future<void> _loadNotes() async {
    final currentSeq = ++_searchSequence;
    if (!mounted) return;
    setState(() => _isLoadingNotes = true);

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
          _isLoadingNotes = false;
        });

        if (!_hasInitialAnimated) {
          Future.delayed(RitmoMotion.sheet, () {
            if (mounted) _hasInitialAnimated = true;
          });
        }
      }
    } catch (e, st) {
      debugPrint('Error loading notes in NotebookScreen: $e\n$st');
      if (mounted && currentSeq == _searchSequence) {
        setState(() {
          _notes = [];
          _isLoadingNotes = false;
        });
      }
    }
  }

  void _onKindSelected(NoteKind? kind) {
    RitmoHapticsPolicy.selection();
    setState(() {
      _selectedKind = kind;
    });
    _loadNotes();
  }

  // --- Load Experiences (Tab 1) ---
  Future<void> _loadExperiences() async {
    if (!mounted) return;
    setState(() => _isLoadingExp = true);
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
          _isLoadingExp = false;
        });
      }
    } catch (e, st) {
      debugPrint('Error loading experiences in NotebookScreen: $e\n$st');
      if (mounted) {
        setState(() {
          _experiences = [];
          _featuredExp = null;
          _isLoadingExp = false;
        });
      }
    }
  }

  // --- Load Review Stats (Tab 2) ---
  Future<void> _loadReviewStats() async {
    if (!mounted) return;
    setState(() => _isLoadingReview = true);
    try {
      final due = await SpacedRepetitionEngine.instance.listDueReviews();
      final stats = await WeeklyReviewEngine.instance.generateWeeklyStats();
      final archived = await NotesRepository.instance.listArchived();
      final trash = await NotesRepository.instance.listTrashed();

      if (mounted) {
        setState(() {
          _dueNotesCount = due.length;
          _dustyNotesCount = stats.orphansCount;
          _createdThisWeekCount = stats.notesCreatedCount;
          _archivedCount = archived.length;
          _trashCount = trash.length;
          _isLoadingReview = false;
        });
      }
    } catch (e, st) {
      debugPrint('Error loading review stats: $e\n$st');
      if (mounted) {
        setState(() => _isLoadingReview = false);
      }
    }
  }

  void _openAiAssistantSheet() {
    RitmoHapticsPolicy.selection();
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final totalActiveCount = _countsByKind.values.fold<int>(0, (sum, c) => sum + c);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: RitmoPageScaffold(
        padding: EdgeInsets.zero,
        floatingActionButton: _buildAdaptiveFab(context, colors),
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // 1. Top Luxury Bar: Back Badge, Title, AI Lens Badge
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Right side: Back Button & Screen Title
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
                                color: isDark ? const Color(0xFF19221E) : const Color(0xFFF4F0E6),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isDark ? const Color(0xFF28463B) : const Color(0xFFE2D9C5),
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
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'دفترچه و تجارب',
                              style: TextStyle(
                                fontSize: 19.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.4,
                                color: colors.textPrimary,
                                fontFamily: 'Vazirmatn',
                              ),
                            ),
                            if (totalActiveCount > 0)
                              Text(
                                '${PersianDigits.convert(totalActiveCount.toString())} یادداشت فعال',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: colors.textSecondary.withValues(alpha: 0.7),
                                  fontFamily: 'Vazirmatn',
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),

                    // Left side: AI Assistant Badge & Archive/Trash Shortcut
                    Row(
                      children: [
                        // AI Assistant Luxury Pill
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _openAiAssistantSheet,
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E2F26) : const Color(0xFFF1EAD9),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isDark ? const Color(0xFF3D6E57) : const Color(0xFFD4A843).withValues(alpha: 0.6),
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFD4A843).withValues(alpha: isDark ? 0.12 : 0.08),
                                    blurRadius: 10,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    CupertinoIcons.sparkles,
                                    size: 14,
                                    color: Color(0xFFC48A1A),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    'دستیار هوش مصنوعی',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w800,
                                      color: isDark ? const Color(0xFFE8C46D) : const Color(0xFF9E7018),
                                      fontFamily: 'Vazirmatn',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 4),

              // 2. Modern 2026 Segmented Glass Tab Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Container(
                  height: 46,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF151A18) : const Color(0xFFFFFEFB),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark ? const Color(0xFF25443A) : const Color(0xFFE8E0CD),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isDark
                            ? Colors.black.withValues(alpha: 0.2)
                            : const Color(0xFFB79B62).withValues(alpha: 0.06),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    indicator: BoxDecoration(
                      color: isDark ? const Color(0xFF23382D) : const Color(0xFFEFE8D6),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? const Color(0xFF3B6B55) : const Color(0xFFD4A843).withValues(alpha: 0.5),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isDark ? Colors.black.withValues(alpha: 0.25) : const Color(0xFFD4A843).withValues(alpha: 0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    labelColor: isDark ? const Color(0xFFE8C46D) : const Color(0xFF9E7018),
                    unselectedLabelColor: colors.textSecondary.withValues(alpha: 0.7),
                    labelStyle: const TextStyle(
                      fontFamily: 'Vazirmatn',
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontFamily: 'Vazirmatn',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    tabs: [
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.edit_note_rounded, size: 16),
                            const SizedBox(width: 4),
                            const Text('یادداشت‌ها'),
                            if (totalActiveCount > 0) ...[
                              const SizedBox(width: 4),
                              Text(
                                '(${PersianDigits.convert(totalActiveCount.toString())})',
                                style: const TextStyle(fontSize: 10),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.lightbulb_rounded, size: 15),
                            const SizedBox(width: 4),
                            const Text('درس‌های زندگی'),
                            if (_experiences.isNotEmpty) ...[
                              const SizedBox(width: 4),
                              Text(
                                '(${PersianDigits.convert(_experiences.length.toString())})',
                                style: const TextStyle(fontSize: 10),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.psychology_rounded, size: 16),
                            const SizedBox(width: 4),
                            const Text('مرور و تحلیل'),
                            if (_dueNotesCount > 0) ...[
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEF4444),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  PersianDigits.convert(_dueNotesCount.toString()),
                                  style: const TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 3. Tab Views
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Tab 0: Notes & Ideas
                    _buildNotesTab(context, colors, isDark),

                    // Tab 1: Life Lessons & Experiences Hub
                    _buildExperiencesTab(context, colors, isDark),

                    // Tab 2: Spaced Repetition & Reviews Hub
                    _buildReviewTab(context, colors, isDark),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // TAB 0: NOTES & IDEAS VIEW
  // ==========================================
  Widget _buildNotesTab(BuildContext context, RitmoColors colors, bool isDark) {
    final pinnedNotes = _notes.where((n) => n.isPinned).toList();
    final otherNotes = _notes.where((n) => !n.isPinned).toList();

    final totalActiveCount = _countsByKind.values.fold<int>(0, (sum, c) => sum + c);
    final noteCount = _countsByKind['NOTE'] ?? 0;
    final experienceCount = _countsByKind['EXPERIENCE'] ?? 0;
    final ideaCount = _countsByKind['IDEA'] ?? 0;
    final decisionCount = _countsByKind['DECISION'] ?? 0;
    final dailyCount = _countsByKind['DAILY'] ?? 0;

    return CustomScrollView(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      slivers: [
        // Search Bar & Filter Chips Header
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Column(
              children: [
                // Search Bar Row
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF151A18) : const Color(0xFFFFFEFB),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _isSearchingFocused
                                ? (isDark ? const Color(0xFF3B6B55) : const Color(0xFFD4A843))
                                : (isDark ? const Color(0xFF25443A) : const Color(0xFFE8E0CD)),
                            width: _isSearchingFocused ? 1.4 : 1.0,
                          ),
                        ),
                        child: TextField(
                          controller: _searchController,
                          focusNode: _searchFocusNode,
                          textDirection: TextDirection.rtl,
                          style: TextStyle(
                            fontFamily: 'Vazirmatn',
                            fontSize: 13.5,
                            color: colors.textPrimary,
                          ),
                          decoration: InputDecoration(
                            hintText: 'جستجو در یادداشت‌ها، متن یا برچسب‌ها...',
                            hintStyle: TextStyle(
                              fontFamily: 'Vazirmatn',
                              fontSize: 12.5,
                              color: colors.textSecondary.withValues(alpha: 0.6),
                            ),
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
                            contentPadding: const EdgeInsets.symmetric(vertical: 12),
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
                            color: colors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                    if (!_isSearchingFocused) ...[
                      const SizedBox(width: 8),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            RitmoHapticsPolicy.selection();
                            setState(() => _isGridView = !_isGridView);
                          },
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            height: 44,
                            width: 44,
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF151A18) : const Color(0xFFFFFEFB),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isDark ? const Color(0xFF25443A) : const Color(0xFFE8E0CD),
                                width: 1,
                              ),
                            ),
                            child: Icon(
                              _isGridView ? CupertinoIcons.rectangle_grid_1x2 : CupertinoIcons.square_grid_2x2,
                              size: 18,
                              color: colors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),

                // Filter Chips Bar
                AnimatedCrossFade(
                  duration: RitmoMotion.state,
                  crossFadeState: _isSearchingFocused ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                  secondChild: const SizedBox(height: 6),
                  firstChild: Column(
                    children: [
                      const SizedBox(height: 10),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: [
                            RitmoChip(
                              label: 'همه (${PersianDigits.convert(totalActiveCount.toString())})',
                              icon: Icons.all_inclusive_rounded,
                              color: colors.primary,
                              isSelected: _selectedKind == null,
                              onTap: () => _onKindSelected(null),
                            ),
                            const SizedBox(width: 8),
                            RitmoChip(
                              label: 'یادداشت‌ها (${PersianDigits.convert(noteCount.toString())})',
                              icon: Icons.description_rounded,
                              color: colors.primary,
                              isSelected: _selectedKind == NoteKind.note,
                              onTap: () => _onKindSelected(NoteKind.note),
                            ),
                            const SizedBox(width: 8),
                            RitmoChip(
                              label: 'درس زندگی (${PersianDigits.convert(experienceCount.toString())})',
                              icon: Icons.lightbulb_rounded,
                              color: NoteUiHelper.getKindStyle(context, NoteKind.experience).accentColor,
                              isSelected: _selectedKind == NoteKind.experience,
                              onTap: () => _onKindSelected(NoteKind.experience),
                            ),
                            const SizedBox(width: 8),
                            RitmoChip(
                              label: 'ایده‌ها (${PersianDigits.convert(ideaCount.toString())})',
                              icon: Icons.bolt_rounded,
                              color: NoteUiHelper.getKindStyle(context, NoteKind.idea).accentColor,
                              isSelected: _selectedKind == NoteKind.idea,
                              onTap: () => _onKindSelected(NoteKind.idea),
                            ),
                            const SizedBox(width: 8),
                            RitmoChip(
                              label: 'تصمیم‌ها (${PersianDigits.convert(decisionCount.toString())})',
                              icon: Icons.check_circle_rounded,
                              color: NoteUiHelper.getKindStyle(context, NoteKind.decision).accentColor,
                              isSelected: _selectedKind == NoteKind.decision,
                              onTap: () => _onKindSelected(NoteKind.decision),
                            ),
                            const SizedBox(width: 8),
                            RitmoChip(
                              label: 'ژورنال (${PersianDigits.convert(dailyCount.toString())})',
                              icon: Icons.auto_stories_rounded,
                              color: NoteUiHelper.getKindStyle(context, NoteKind.daily).accentColor,
                              isSelected: _selectedKind == NoteKind.daily,
                              onTap: () => _onKindSelected(NoteKind.daily),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Notes Content Area
        if (_isLoadingNotes)
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Pinned Notes Section
                if (pinnedNotes.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8, top: 4),
                    child: Row(
                      children: [
                        const Icon(CupertinoIcons.pin_fill, size: 14, color: Color(0xFFC48A1A)),
                        const SizedBox(width: 6),
                        Text(
                          'سنجاق‌شده (${PersianDigits.convert(pinnedNotes.length.toString())})',
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
                  _buildNotesLayout(pinnedNotes),
                  const SizedBox(height: 16),
                  if (otherNotes.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        'سایر یادداشت‌ها',
                        style: TextStyle(
                          fontFamily: 'Vazirmatn',
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                ],

                // Other Notes Section
                if (otherNotes.isNotEmpty) _buildNotesLayout(otherNotes),

                const SizedBox(height: 90),
              ]),
            ),
          ),
      ],
    );
  }

  // ==========================================
  // TAB 1: LIFE LESSONS & EXPERIENCES VIEW
  // ==========================================
  Widget _buildExperiencesTab(BuildContext context, RitmoColors colors, bool isDark) {
    final insightsColor = const Color(0xFFD4A843);

    final filtered = _selectedCategory == null
        ? _experiences
        : _experiences.where((e) => e.category == _selectedCategory).toList();

    final featuredExp = _featuredExp;

    if (_isLoadingExp) {
      return const RitmoShimmerGrid(count: 4);
    }

    if (_experiences.isEmpty) {
      return RitmoEmptyState(
        icon: CupertinoIcons.lightbulb,
        title: 'بانک درس‌های زندگی خالی است',
        description: 'تجربه‌ها، آموخته‌ها و حکمت‌هایی که در جریان زندگی کسب می‌کنید را ثبت کنید تا چراغ راه تصمیمات آینده‌تان باشند.',
        actionLabel: 'ثبت اولین آموزه زندگی',
        onAction: () async {
          RitmoHapticsPolicy.tap();
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NoteEditorScreen(isExperience: true)),
          );
          if (mounted) await _loadExperiences();
        },
      );
    }

    return RefreshIndicator(
      onRefresh: _loadExperiences,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        slivers: [
          // Category Selector Chips
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
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
                    const SizedBox(width: 8),
                    ...ExperienceCategory.values.map((cat) {
                      final count = _experiences.where((e) => e.category == cat).length;
                      return Padding(
                        padding: const EdgeInsets.only(left: 8),
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
          ),

          // Featured Wisdom Banner
          if (_selectedCategory == null && featuredExp != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
                child: _buildFeaturedHeroCard(context, featuredExp, isDark),
              ),
            ),

          // Header for all lessons
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                children: [
                  Icon(CupertinoIcons.sparkles, size: 14, color: insightsColor),
                  const SizedBox(width: 6),
                  Text(
                    'همه آموزه‌ها (${PersianDigits.convert(filtered.length.toString())})',
                    style: TextStyle(
                      fontFamily: 'Vazirmatn',
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: colors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Wisdom Cards List
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) => _buildWisdomCard(context, filtered[i], isDark),
                childCount: filtered.length,
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 90)),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 2: SPACED REPETITION & REVIEWS VIEW
  // ==========================================
  Widget _buildReviewTab(BuildContext context, RitmoColors colors, bool isDark) {
    if (_isLoadingReview) {
      return const RitmoShimmerGrid(count: 3);
    }

    return RefreshIndicator(
      onRefresh: _loadReviewStats,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
        children: [
          // 1. Spaced Repetition (SRS) Flashcards Hero Card
          _buildSrsHeroCard(context, colors, isDark),

          const SizedBox(height: 14),

          // 2. Weekly Review Card
          _buildWeeklyReviewCard(context, colors, isDark),

          const SizedBox(height: 14),

          // 3. Archive & Trash Hub
          _buildArchiveAndTrashSection(context, colors, isDark),
        ],
      ),
    );
  }

  // --- SRS Hero Card Widget ---
  Widget _buildSrsHeroCard(BuildContext context, RitmoColors colors, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151A18) : const Color(0xFFFFFEFB),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isDark ? const Color(0xFF25443A) : const Color(0xFFE8E0CD),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withValues(alpha: 0.28) : const Color(0xFFB79B62).withValues(alpha: 0.08),
            blurRadius: 28,
            offset: const Offset(0, 8),
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
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E2F26) : const Color(0xFFF1EAD9),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark ? const Color(0xFF3B6B55) : const Color(0xFFD4A843).withValues(alpha: 0.5),
                        width: 1,
                      ),
                    ),
                    child: const Icon(
                      Icons.psychology_rounded,
                      color: Color(0xFFC48A1A),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'مرور فاصله‌دار هوشمند (SRS)',
                        style: TextStyle(
                          fontFamily: 'Vazirmatn',
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'تثبیت دائمی درس‌ها و یادداشت‌ها در حافظه بلندمدت',
                        style: TextStyle(
                          fontFamily: 'Vazirmatn',
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: colors.textSecondary.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (_dueNotesCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.4), width: 1),
                  ),
                  child: Text(
                    '${PersianDigits.convert(_dueNotesCount.toString())} سررسید امروز',
                    style: const TextStyle(
                      fontFamily: 'Vazirmatn',
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFEF4444),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _dueNotesCount > 0
                ? 'امروز ${_dueNotesCount} کارت برای مرور و یادآوری طبق منحنی فراموشی آماده هستند.'
                : 'آفرین! کارت سررسیدشده‌ای برای مرور امروز نداری. تمام آموخته‌هایت به‌روز هستند.',
            style: TextStyle(
              fontFamily: 'Vazirmatn',
              fontSize: 13,
              color: colors.textSecondary,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: () async {
              RitmoHapticsPolicy.tap();
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NoteSrsReviewScreen()),
              );
              await _loadReviewStats();
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFC38D29), Color(0xFF9E7018)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFC38D29).withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(CupertinoIcons.play_circle_fill, size: 18, color: Colors.white),
                  SizedBox(width: 8),
                  Text(
                    'شروع مرور فلش‌کارت‌ها',
                    style: TextStyle(
                      fontFamily: 'Vazirmatn',
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Weekly Review Card Widget ---
  Widget _buildWeeklyReviewCard(BuildContext context, RitmoColors colors, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151A18) : const Color(0xFFFFFEFB),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isDark ? const Color(0xFF25443A) : const Color(0xFFE8E0CD),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withValues(alpha: 0.28) : const Color(0xFFB79B62).withValues(alpha: 0.08),
            blurRadius: 28,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF16241E) : const Color(0xFFE7F3ED),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark ? const Color(0xFF2E5946) : const Color(0xFF10B981).withValues(alpha: 0.4),
                    width: 1,
                  ),
                ),
                child: const Icon(
                  CupertinoIcons.chart_bar_alt_fill,
                  color: Color(0xFF10B981),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'مرور هفتگی و یادداشت‌های خاک‌خورده',
                    style: TextStyle(
                      fontFamily: 'Vazirmatn',
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${PersianDigits.convert(_dustyNotesCount.toString())} یادداشت نیازمند بازبینی',
                    style: TextStyle(
                      fontFamily: 'Vazirmatn',
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF10B981),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF19221E) : const Color(0xFFF7F5EE),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Text(
                        PersianDigits.convert(_createdThisWeekCount.toString()),
                        style: TextStyle(
                          fontFamily: 'Vazirmatn',
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'ثبت این هفته',
                        style: TextStyle(
                          fontFamily: 'Vazirmatn',
                          fontSize: 11,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF19221E) : const Color(0xFFF7F5EE),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Text(
                        PersianDigits.convert(_dustyNotesCount.toString()),
                        style: const TextStyle(
                          fontFamily: 'Vazirmatn',
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFD4A843),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'خاک‌خورده (>۳۰ روز)',
                        style: TextStyle(
                          fontFamily: 'Vazirmatn',
                          fontSize: 11,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          InkWell(
            onTap: () async {
              RitmoHapticsPolicy.tap();
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const WeeklyReviewScreen()),
              );
              await _loadReviewStats();
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF19221E) : const Color(0xFFF4F0E6),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? const Color(0xFF28463B) : const Color(0xFFE2D9C5),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(CupertinoIcons.arrow_right_circle_fill, size: 16, color: colors.textPrimary),
                  const SizedBox(width: 8),
                  Text(
                    'ورود به اتاق مرور هفتگی',
                    style: TextStyle(
                      fontFamily: 'Vazirmatn',
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: colors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Archive & Trash Section ---
  Widget _buildArchiveAndTrashSection(BuildContext context, RitmoColors colors, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151A18) : const Color(0xFFFFFEFB),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isDark ? const Color(0xFF25443A) : const Color(0xFFE8E0CD),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withValues(alpha: 0.28) : const Color(0xFFB79B62).withValues(alpha: 0.08),
            blurRadius: 28,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'بایگانی و مدیریت حذف‌شده‌ها',
            style: TextStyle(
              fontFamily: 'Vazirmatn',
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () async {
                    RitmoHapticsPolicy.tap();
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const NoteTrashArchiveScreen(initialTabIndex: 1)),
                    );
                    await _loadAllData();
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF19221E) : const Color(0xFFF7F5EE),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? const Color(0xFF28463B) : const Color(0xFFE2D9C5),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(CupertinoIcons.archivebox, size: 20, color: Color(0xFFC48A1A)),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'بایگانی',
                              style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '${PersianDigits.convert(_archivedCount.toString())} مورد',
                              style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 11, color: colors.textSecondary),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: InkWell(
                  onTap: () async {
                    RitmoHapticsPolicy.tap();
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const NoteTrashArchiveScreen(initialTabIndex: 0)),
                    );
                    await _loadAllData();
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF19221E) : const Color(0xFFF7F5EE),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? const Color(0xFF28463B) : const Color(0xFFE2D9C5),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(CupertinoIcons.trash, size: 20, color: Color(0xFFEF4444)),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'سطل زباله',
                              style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '${PersianDigits.convert(_trashCount.toString())} مورد',
                              style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 11, color: colors.textSecondary),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- Dynamic Adaptive FAB ---
  Widget _buildAdaptiveFab(BuildContext context, RitmoColors colors) {
    final tabIndex = _tabController.index;

    IconData fabIcon;
    String fabLabel;
    Color fabBg;
    VoidCallback fabAction;

    if (tabIndex == 1) {
      // Experience tab
      fabIcon = CupertinoIcons.lightbulb_fill;
      fabLabel = 'ثبت آموزه زندگی';
      fabBg = const Color(0xFFC38D29);
      fabAction = () async {
        RitmoHapticsPolicy.tap();
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const NoteEditorScreen(isExperience: true)),
        );
        if (mounted) await _loadExperiences();
      };
    } else if (tabIndex == 2) {
      // Review tab
      fabIcon = CupertinoIcons.play_circle_fill;
      fabLabel = 'شروع مرور امروز';
      fabBg = const Color(0xFF10B981);
      fabAction = () async {
        RitmoHapticsPolicy.tap();
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const NoteSrsReviewScreen()),
        );
        if (mounted) await _loadReviewStats();
      };
    } else {
      // Notes tab
      fabIcon = CupertinoIcons.pencil;
      fabLabel = 'یادداشت جدید';
      fabBg = colors.primary;
      fabAction = () async {
        RitmoHapticsPolicy.tap();
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const NoteEditorScreen()),
        );
        if (mounted) await _loadNotes();
      };
    }

    return AnimatedScale(
      scale: _isFabCompact ? 0.92 : 1.0,
      duration: RitmoMotion.state,
      curve: RitmoMotion.enter,
      child: FloatingActionButton.extended(
        onPressed: fabAction,
        elevation: 4,
        highlightElevation: 8,
        backgroundColor: fabBg,
        icon: Icon(fabIcon, color: Colors.white, size: 20),
        label: Text(
          fabLabel,
          style: const TextStyle(
            fontFamily: 'Vazirmatn',
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  // --- Featured Hero Card for Experiences ---
  Widget _buildFeaturedHeroCard(BuildContext context, Experience exp, bool isDark) {
    final colors = context.colors;
    final insightsColor = const Color(0xFFD4A843);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151A18) : const Color(0xFFFFFEFB),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isDark ? const Color(0xFF25443A) : const Color(0xFFE8E0CD),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withValues(alpha: 0.28) : const Color(0xFFB79B62).withValues(alpha: 0.08),
            blurRadius: 28,
            offset: const Offset(0, 8),
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
                  color: isDark ? const Color(0xFF23382D) : const Color(0xFFF1E8D5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? const Color(0xFF3B6B55) : const Color(0xFFD4A843).withValues(alpha: 0.5),
                    width: 1,
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
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        color: isDark ? const Color(0xFFE8C46D) : const Color(0xFF9E7018),
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
                      color: starFilled ? insightsColor : colors.textTertiary.withValues(alpha: 0.4),
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
              fontWeight: FontWeight.w800,
              fontSize: 16,
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
                color: colors.textSecondary.withValues(alpha: 0.75),
                height: 1.45,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // --- Wisdom Card Widget ---
  Widget _buildWisdomCard(BuildContext context, Experience exp, bool isDark) {
    final colors = context.colors;
    final insightsColor = const Color(0xFFD4A843);

    return RitmoCard(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(16),
      onTap: () async {
        final note = await NotesRepository.instance.getById(exp.noteId);
        if (note != null && context.mounted) {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => NoteEditorScreen(note: note, isExperience: true)),
          );
          await _loadExperiences();
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Category, Stars
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E2F26) : const Color(0xFFF1EAD9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(exp.category.emoji, style: const TextStyle(fontSize: 12)),
                    const SizedBox(width: 5),
                    Text(
                      exp.category.labelFa,
                      style: TextStyle(
                        fontFamily: 'Vazirmatn',
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        color: isDark ? const Color(0xFFE8C46D) : const Color(0xFF9E7018),
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: List.generate(5, (idx) {
                  final isFilled = idx < exp.importance;
                  return GestureDetector(
                    onTap: () async {
                      RitmoHapticsPolicy.selection();
                      await ExperienceRepository.instance.setImportance(exp.noteId, idx + 1);
                      await _loadExperiences();
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1.5),
                      child: Icon(
                        isFilled ? CupertinoIcons.star_fill : CupertinoIcons.star,
                        size: 14,
                        color: isFilled ? insightsColor : colors.textTertiary.withValues(alpha: 0.35),
                      ),
                    ),
                  );
                }),
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
              fontWeight: FontWeight.w700,
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
                color: colors.textSecondary.withValues(alpha: 0.65),
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // --- Notes Layout (Grid or List) ---
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

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: RitmoMotion.sheet,
      curve: RitmoMotion.enter,
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
    return RitmoEmptyState(
      icon: _searchQuery.isNotEmpty ? CupertinoIcons.search : CupertinoIcons.book,
      title: _searchQuery.isNotEmpty ? 'نتیجه‌ای یافت نشد' : 'دفترچه یادداشت شما خالی است',
      description: _searchQuery.isNotEmpty
          ? 'عبارت دیگری را جستجو کنید یا فیلتر دسته‌بندی را تغییر دهید.'
          : 'ایده‌ها، تصمیمات و تجارب ارزشمند زندگی خود را بنویسید تا ماندگار شوند.',
      actionLabel: _searchQuery.isEmpty ? 'نوشتن اولین یادداشت' : null,
      onAction: _searchQuery.isEmpty
          ? () async {
              RitmoHapticsPolicy.tap();
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NoteEditorScreen()),
              );
              if (mounted) await _loadNotes();
            }
          : null,
    );
  }
}
