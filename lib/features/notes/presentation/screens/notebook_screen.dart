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
import 'package:ritmo/core/utils/ritmo_toast.dart';
import 'package:ritmo/features/notes/presentation/utils/note_actions.dart';
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
  WeeklyReviewStats? _weeklyStats;
  List<Note> _dustyNotes = [];
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
      final orphans = await NotesRepository.instance.listOrphans(minDays: 30);
      final archived = await NotesRepository.instance.listArchived();
      final trash = await NotesRepository.instance.listTrashed();

      if (mounted) {
        setState(() {
          _dueNotesCount = due.length;
          _weeklyStats = stats;
          _dustyNotes = orphans;
          _dustyNotesCount = orphans.length;
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
                                ),
                            ),
                            if (totalActiveCount > 0)
                              Text(
                                '${PersianDigits.convert(totalActiveCount.toString())} یادداشت فعال',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: colors.textSecondary.withValues(alpha: 0.7),
                                  ),
                              ),
                          ],
                        ),
                      ],
                    ),

                    // Left side: AI Assistant Badge
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _openAiAssistantSheet,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: colors.primaryContainer,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: colors.primary.withValues(alpha: isDark ? 0.45 : 0.35),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: colors.primary.withValues(alpha: isDark ? 0.12 : 0.08),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                CupertinoIcons.sparkles,
                                size: 14,
                                color: colors.primary,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                'دستیار هوش مصنوعی',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: colors.primary,
                                  ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 4),

              // 2. Modern Segmented Tab Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Container(
                  height: 46,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: colors.border,
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: colors.shadow.withValues(alpha: isDark ? 0.2 : 0.06),
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
                      color: colors.primaryContainer,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: colors.primary.withValues(alpha: 0.4),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: colors.shadow.withValues(alpha: isDark ? 0.25 : 0.12),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    labelColor: isDark ? colors.accent : colors.primary,
                    unselectedLabelColor: colors.textSecondary.withValues(alpha: 0.7),
                    labelStyle: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    tabs: [
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(CupertinoIcons.doc_text_fill, size: 14),
                            const SizedBox(width: 5),
                            Text('یادداشت‌ها (${PersianDigits.convert(totalActiveCount.toString())})'),
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(CupertinoIcons.lightbulb_fill, size: 14),
                            const SizedBox(width: 5),
                            Text('درس‌ها و تجارب (${PersianDigits.convert(_experiences.length.toString())})'),
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(CupertinoIcons.arrow_2_circlepath_circle_fill, size: 14),
                            const SizedBox(width: 5),
                            const Text('مرور و تحلیل'),
                            if (_dueNotesCount > 0) ...[
                              const SizedBox(width: 4),
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: colors.error,
                                  shape: BoxShape.circle,
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

              const SizedBox(height: 4),

              // 3. Tab Views Content
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  physics: const BouncingScrollPhysics(),
                  children: [
                    // Tab 0: Notes
                    _buildNotesTab(context, colors, isDark),

                    // Tab 1: Experiences & Lessons
                    _buildExperiencesTab(context, colors, isDark),

                    // Tab 2: Spaced Repetition & Reviews
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
  // TAB 0: ALL NOTES & NOTEBOOK VIEW
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
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _isSearchingFocused ? colors.primary : colors.border,
                            width: _isSearchingFocused ? 1.4 : 1.0,
                          ),
                        ),
                        child: TextField(
                          controller: _searchController,
                          focusNode: _searchFocusNode,
                          textDirection: TextDirection.rtl,
                          style: TextStyle(
                            fontSize: 13.5,
                            color: colors.textPrimary,
                          ),
                          decoration: InputDecoration(
                            hintText: 'جستجو در یادداشت‌ها، متن یا برچسب‌ها...',
                            hintStyle: TextStyle(
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
                              color: colors.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: colors.border,
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
                        Icon(CupertinoIcons.pin_fill, size: 14, color: colors.accent),
                        const SizedBox(width: 6),
                        Text(
                          'سنجاق‌شده (${PersianDigits.convert(pinnedNotes.length.toString())})',
                          style: TextStyle(
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
    final insightsColor = context.modules.insights;

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
    final insightsColor = context.modules.insights;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: colors.border,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: isDark ? 0.28 : 0.08),
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
                      color: colors.primaryContainer,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: colors.primary.withValues(alpha: 0.4),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      Icons.psychology_rounded,
                      color: colors.primary,
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
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'تثبیت دائمی درس‌ها و یادداشت‌ها در حافظه بلندمدت',
                        style: TextStyle(
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
                    color: colors.error.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: colors.error.withValues(alpha: 0.4), width: 1),
                  ),
                  child: Text(
                    '${PersianDigits.convert(_dueNotesCount.toString())} سررسید امروز',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: colors.error,
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
                color: colors.primary,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: colors.primary.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(CupertinoIcons.play_circle_fill, size: 18, color: colors.onPrimary),
                  const SizedBox(width: 8),
                  Text(
                    'شروع مرور فلش‌کارت‌ها',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: colors.onPrimary,
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

  // --- Consolidated Weekly Review Section Widget ---
  Widget _buildWeeklyReviewCard(BuildContext context, RitmoColors colors, bool isDark) {
    final stats = _weeklyStats;
    final topTags = stats?.topTags ?? [];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: colors.border,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: isDark ? 0.28 : 0.08),
            blurRadius: 28,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header: Icon, Title, and Review Status Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: colors.success.withValues(alpha: isDark ? 0.2 : 0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: colors.success.withValues(alpha: 0.4),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      CupertinoIcons.chart_bar_alt_fill,
                      color: colors.success,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'مرور و تحلیل هفتگی',
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'گزارش جامع دستاوردهای ۷ روز اخیر',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: colors.success,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (_dustyNotes.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: colors.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: colors.accent.withValues(alpha: 0.4), width: 1),
                  ),
                  child: Text(
                    '${PersianDigits.convert(_dustyNotes.length.toString())} خاک‌خورده',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: colors.accent,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // 2. 7-Day Achievement Metrics Row (3 Equal Cards)
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                  decoration: BoxDecoration(
                    color: colors.surfaceSunken,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: colors.border,
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(CupertinoIcons.doc_text, size: 18, color: colors.primary),
                      const SizedBox(height: 4),
                      Text(
                        PersianDigits.convert((stats?.notesCreatedCount ?? _createdThisWeekCount).toString()),
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'یادداشت جدید',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                  decoration: BoxDecoration(
                    color: colors.surfaceSunken,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: colors.border,
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.lightbulb_outline_rounded, size: 18, color: context.modules.insights),
                      const SizedBox(height: 4),
                      Text(
                        PersianDigits.convert((stats?.experiencesAddedCount ?? 0).toString()),
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: context.modules.insights,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'درس زندگی',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                  decoration: BoxDecoration(
                    color: colors.surfaceSunken,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: colors.border,
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(CupertinoIcons.pencil, size: 18, color: colors.success),
                      const SizedBox(height: 4),
                      Text(
                        PersianDigits.convert((stats?.wordCountSum ?? 0).toString()),
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: colors.success,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'کلمه ثبت‌شده',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // 3. Top Weekly Tags Section
          if (topTags.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'موضوعات و برچسب‌های پرکاربرد هفته',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: topTags.map((tag) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: colors.primary.withValues(alpha: 0.35),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    '#$tag',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: colors.primary,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],

          const SizedBox(height: 20),

          // 4. In-Place Dusty Notes Review Queue
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(CupertinoIcons.archivebox_fill, size: 16, color: colors.textPrimary),
                  const SizedBox(width: 6),
                  Text(
                    'صف مرور یادداشت‌های خاک‌خورده (>۳۰ روز)',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: colors.textPrimary,
                    ),
                  ),
                ],
              ),
              Text(
                '${PersianDigits.convert(_dustyNotes.length.toString())} مورد',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: _dustyNotes.isEmpty ? colors.success : colors.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'یادداشت‌هایی که مدتی است بازبینی نشده‌اند و نیازمند تعیین تکلیف هستند.',
            style: TextStyle(
              fontSize: 11,
              color: colors.textSecondary.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 12),

          // Dusty Notes Items or Celebratory Clean State
          if (_dustyNotes.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              decoration: BoxDecoration(
                color: colors.success.withValues(alpha: isDark ? 0.2 : 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: colors.success.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(CupertinoIcons.checkmark_seal_fill, size: 20, color: colors.success),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'آفرین! هیچ یادداشت خاک‌خورده‌ای نداری و تمام دفترچه‌ات به‌روز و مرتب است.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: colors.success,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            ..._dustyNotes.map((note) => _buildDustyNoteCard(context, note, colors, isDark)),
        ],
      ),
    );
  }

  // --- Dusty Note In-Place Action Card ---
  Widget _buildDustyNoteCard(BuildContext context, Note note, RitmoColors colors, bool isDark) {
    final style = NoteUiHelper.getKindStyle(context, note.kind);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceSunken,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colors.border,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(style.icon, size: 15, color: style.accentColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  note.title ?? 'بدون عنوان',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: colors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          if (note.body.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              note.body,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: colors.textSecondary.withValues(alpha: 0.8),
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Edit Button
              TextButton.icon(
                onPressed: () async {
                  await NotesRepository.instance.markOpened(note.id);
                  if (!context.mounted) return;
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => NoteEditorScreen(note: note)),
                  );
                  await _loadAllData();
                },
                icon: const Icon(CupertinoIcons.pencil, size: 13),
                label: const Text(
                  'ویرایش',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                ),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: colors.primary,
                ),
              ),
              const SizedBox(width: 4),
              // Archive Button
              TextButton.icon(
                onPressed: () async {
                  RitmoHapticsPolicy.selection();
                  await NotesRepository.instance.archive(note.id);
                  if (context.mounted) {
                    RitmoToast.show(context, 'یادداشت با موفقیت بایگانی شد 📦');
                  }
                  await _loadAllData();
                },
                icon: const Icon(CupertinoIcons.archivebox, size: 13),
                label: const Text(
                  'بایگانی',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                ),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: colors.accent,
                ),
              ),
              const SizedBox(width: 4),
              // Trash Button
              TextButton.icon(
                onPressed: () {
                  NoteActions.confirmAndTrash(context, note, _loadAllData);
                },
                icon: const Icon(CupertinoIcons.trash, size: 13),
                label: const Text(
                  'حذف',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                ),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: colors.error,
                ),
              ),
            ],
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
        color: colors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: colors.border,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: isDark ? 0.28 : 0.08),
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
                      color: colors.surfaceSunken,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: colors.border,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(CupertinoIcons.archivebox, size: 20, color: colors.accent),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'بایگانی',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '${PersianDigits.convert(_archivedCount.toString())} مورد',
                              style: TextStyle(fontSize: 11, color: colors.textSecondary),
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
                      color: colors.surfaceSunken,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: colors.border,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(CupertinoIcons.trash, size: 20, color: colors.error),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'سطل زباله',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '${PersianDigits.convert(_trashCount.toString())} مورد',
                              style: TextStyle(fontSize: 11, color: colors.textSecondary),
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
      fabBg = context.modules.insights;
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
      fabBg = colors.primary;
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
        icon: Icon(fabIcon, color: colors.onPrimary, size: 20),
        label: Text(
          fabLabel,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: colors.onPrimary,
          ),
        ),
      ),
    );
  }

  // --- Featured Hero Card for Experiences ---
  Widget _buildFeaturedHeroCard(BuildContext context, Experience exp, bool isDark) {
    final colors = context.colors;
    final insightsColor = context.modules.insights;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: colors.border,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: isDark ? 0.28 : 0.08),
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
                  color: insightsColor.withValues(alpha: isDark ? 0.2 : 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: insightsColor.withValues(alpha: 0.4),
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
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
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
    final insightsColor = context.modules.insights;

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
                  color: insightsColor.withValues(alpha: isDark ? 0.2 : 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: insightsColor.withValues(alpha: 0.35),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(exp.category.emoji, style: const TextStyle(fontSize: 12)),
                    const SizedBox(width: 5),
                    Text(
                      exp.category.labelFa,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        color: insightsColor,
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
