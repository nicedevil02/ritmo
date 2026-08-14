import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
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

class NotebookScreen extends StatefulWidget {
  const NotebookScreen({super.key});

  @override
  State<NotebookScreen> createState() => _NotebookScreenState();
}

class _NotebookScreenState extends State<NotebookScreen> {
  List<Note> _notes = [];
  bool _isLoading = true;
  String _searchQuery = '';
  NoteKind? _selectedKind;
  bool _isGridView = true;
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounceTimer;
  int _searchSequence = 0;
  Map<String, int> _countsByKind = {};
  int _totalWordCount = 0;

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = Timer(const Duration(milliseconds: 350), () {
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
      final totalWords = await NotesRepository.instance.getTotalWordCount();

      if (mounted && currentSeq == _searchSequence) {
        setState(() {
          _notes = notes;
          _countsByKind = counts;
          _totalWordCount = totalWords;
          _isLoading = false;
        });
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
        appBar: AppBar(
          backgroundColor: colors.surface,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: colors.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'دفترچه و حکمت‌ها 📓',
            style: TextStyle(
              fontFamily: 'Vazirmatn',
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: colors.textPrimary,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.lightbulb_rounded, color: Color(0xFFE5A00D)),
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
              icon: const Icon(Icons.psychology, color: Colors.indigoAccent),
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
              icon: Icon(Icons.more_vert, color: colors.textPrimary),
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
                      Text('📊'),
                      SizedBox(width: 8),
                      Text('مرور هفتگی دفترچه', style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 13)),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'trash',
                  child: Row(
                    children: [
                      Text('📦'),
                      SizedBox(width: 8),
                      Text('سطل زباله و بایگانی', style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 13)),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'assistant',
                  child: Row(
                    children: [
                      Text('✨'),
                      SizedBox(width: 8),
                      Text('دستیار هوش مصنوعی', style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () async {
            RitmoHaptics.confirm();
            if (!context.mounted) return;
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NoteEditorScreen()),
            );
            if (mounted) await _loadNotes();
          },
          backgroundColor: colors.primary,
          icon: const Icon(CupertinoIcons.add, color: Colors.white, size: 20),
          label: const Text(
            'یادداشت جدید',
            style: TextStyle(fontFamily: 'Vazirmatn', fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
          ),
        ),
        body: Column(
          children: [
            // Knowledge Quick Stats Header Bar
            if (_searchQuery.isEmpty && _selectedKind == null && !_isLoading && _notes.isNotEmpty)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? colors.surfaceSunken : colors.surface,
                  borderRadius: BorderRadius.circular(RitmoRadius.card),
                  border: Border.all(color: colors.border.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatPill('یادداشت‌ها', PersianDigits.convert(totalActiveCount.toString()), '📓', colors.primary),
                    Container(height: 24, width: 1, color: colors.border.withValues(alpha: 0.3)),
                    _buildStatPill('درس‌های زندگی', PersianDigits.convert(experienceCount.toString()), '💡', const Color(0xFFE5A00D)),
                    Container(height: 24, width: 1, color: colors.border.withValues(alpha: 0.3)),
                    _buildStatPill('کلمات مکتوب', PersianDigits.convert(_totalWordCount.toString()), '✍️', colors.textSecondary),
                  ],
                ),
              ),

            // Search Bar & Filter Chips & Layout Toggle
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Search Input Field
                      Expanded(
                        child: Container(
                          height: 42,
                          decoration: BoxDecoration(
                            color: colors.surfaceSunken,
                            borderRadius: BorderRadius.circular(RitmoRadius.field),
                            border: Border.all(color: colors.border.withValues(alpha: 0.25)),
                          ),
                          child: TextField(
                            controller: _searchController,
                            textDirection: TextDirection.rtl,
                            style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 13, color: colors.textPrimary),
                            decoration: InputDecoration(
                              hintText: 'جستجو در عنوان، متن یا تگ‌ها...',
                              hintStyle: TextStyle(fontFamily: 'Vazirmatn', fontSize: 12, color: colors.textTertiary),
                              prefixIcon: Icon(CupertinoIcons.search, size: 16, color: colors.textSecondary),
                              suffixIcon: _searchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(CupertinoIcons.clear, size: 14),
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() => _searchQuery = '');
                                        _loadNotes();
                                      },
                                    )
                                  : null,
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            onChanged: _onSearchChanged,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Layout Switcher Button (Grid vs List)
                      InkWell(
                        onTap: () {
                          RitmoHaptics.selection();
                          setState(() => _isGridView = !_isGridView);
                        },
                        borderRadius: BorderRadius.circular(RitmoRadius.field),
                        child: Container(
                          height: 42,
                          width: 42,
                          decoration: BoxDecoration(
                            color: colors.surfaceSunken,
                            borderRadius: BorderRadius.circular(RitmoRadius.field),
                            border: Border.all(color: colors.border.withValues(alpha: 0.25)),
                          ),
                          child: Icon(
                            _isGridView ? CupertinoIcons.rectangle_grid_1x2 : CupertinoIcons.square_grid_2x2,
                            size: 18,
                            color: colors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Kind Filter Chips with Count & Icons
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterPill('همه', null, '🌟', totalActiveCount),
                        const SizedBox(width: 6),
                        _buildFilterPill('یادداشت‌ها', NoteKind.note, '📓', noteCount),
                        const SizedBox(width: 6),
                        _buildFilterPill('درس‌ها', NoteKind.experience, '💡', experienceCount),
                        const SizedBox(width: 6),
                        _buildFilterPill('ایده‌ها', NoteKind.idea, '⚡', ideaCount),
                        const SizedBox(width: 6),
                        _buildFilterPill('تصمیم‌ها', NoteKind.decision, '🎯', decisionCount),
                        const SizedBox(width: 6),
                        _buildFilterPill('روزانه', NoteKind.daily, '📅', dailyCount),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Notes Content Area
            Expanded(
              child: _isLoading
                  ? Center(child: CircularProgressIndicator(color: colors.primary))
                  : _notes.isEmpty
                      ? _buildEmptyState(context)
                      : RefreshIndicator(
                          onRefresh: _loadNotes,
                          child: ListView(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            children: [
                              // Pinned Notes
                              if (pinnedNotes.isNotEmpty) ...[
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                                  child: Row(
                                    children: [
                                      Icon(CupertinoIcons.pin_fill, size: 13, color: colors.primary),
                                      const SizedBox(width: 6),
                                      Text(
                                        'سنجاق‌شده‌ها (${PersianDigits.convert(pinnedNotes.length.toString())})',
                                        style: TextStyle(
                                          fontFamily: 'Vazirmatn',
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: colors.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                _renderNotesLayout(pinnedNotes),
                                const SizedBox(height: 14),
                              ],

                              // Regular Notes
                              if (otherNotes.isNotEmpty) ...[
                                if (pinnedNotes.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
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
                                _renderNotesLayout(otherNotes),
                              ],
                              const SizedBox(height: 80), // Fab space
                            ],
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _renderNotesLayout(List<Note> items) {
    if (!_isGridView) {
      return Column(
        children: items.map((n) => NoteCard(note: n, onChanged: _loadNotes, isGrid: false)).toList(),
      );
    }

    // 2-Column Staggered Masonry Layout
    final leftColumn = <Note>[];
    final rightColumn = <Note>[];

    for (int i = 0; i < items.length; i++) {
      if (i % 2 == 0) {
        leftColumn.add(items[i]);
      } else {
        rightColumn.add(items[i]);
      }
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            children: leftColumn.map((n) => NoteCard(note: n, onChanged: _loadNotes, isGrid: true)).toList(),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            children: rightColumn.map((n) => NoteCard(note: n, onChanged: _loadNotes, isGrid: true)).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildStatPill(String label, String value, String emoji, Color accent) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 13)),
            const SizedBox(width: 4),
            Text(
              value,
              style: TextStyle(
                fontFamily: 'Vazirmatn',
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: accent,
              ),
            ),
          ],
        ),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Vazirmatn',
            fontSize: 10,
            color: Theme.of(context).textTheme.bodySmall?.color,
          ),
        ),
      ],
    );
  }

  Widget _buildFilterPill(String label, NoteKind? kind, String emoji, int count) {
    final colors = context.colors;
    final isSelected = _selectedKind == kind;

    return InkWell(
      onTap: () => _onKindSelected(kind),
      borderRadius: BorderRadius.circular(RitmoRadius.pill),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? colors.primary : colors.surfaceSunken,
          borderRadius: BorderRadius.circular(RitmoRadius.pill),
          border: Border.all(
            color: isSelected ? colors.primary : colors.border.withValues(alpha: 0.25),
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
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white.withValues(alpha: 0.25) : colors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  PersianDigits.convert(count.toString()),
                  style: TextStyle(
                    fontFamily: 'Vazirmatn',
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : colors.primary,
                  ),
                ),
              ),
            ],
          ],
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
                color: colors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _searchQuery.isNotEmpty ? CupertinoIcons.search : CupertinoIcons.doc_text_fill,
                size: 48,
                color: colors.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty ? 'نتیجه‌ای یافت نشد' : 'دفترچه یادداشت و حکمت‌ها خالی است',
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
                  ? 'عبارت دیگری را جستجو کنید یا فیلترها را تغییر دهید.'
                  : 'جملات الهام‌بخش، تجارب ارزشمند و یادداشت‌هایت را در این بوم امن ذخیره کن.',
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
                  MaterialPageRoute(builder: (_) => const NoteEditorScreen()),
                );
                await _loadNotes();
              },
              icon: const Icon(CupertinoIcons.add, size: 16),
              label: const Text('نوشتن اولین یادداشت', style: TextStyle(fontFamily: 'Vazirmatn', fontWeight: FontWeight.bold)),
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
