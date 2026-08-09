import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/ux/ritmo_haptics.dart';
import 'package:ritmo/features/notes/data/notes_repository.dart';
import 'package:ritmo/features/notes/domain/note_models.dart';
import 'package:ritmo/features/notes/logic/note_fts_engine.dart';
import 'package:ritmo/core/domain/personas/persona_registry.dart';
import 'package:ritmo/features/assistant/presentation/widgets/unified_assistant_sheet.dart';
import 'package:ritmo/features/chat/presentation/ai_chat_screen.dart';
import 'package:ritmo/features/notes/presentation/screens/experience_hub_screen.dart';
import 'package:ritmo/features/notes/presentation/screens/note_editor_screen.dart';
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
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    setState(() => _isLoading = true);
    final notes = await NoteFtsEngine.instance.search(
      _searchQuery,
      kind: _selectedKind,
    );
    if (mounted) {
      setState(() {
        _notes = notes;
        _isLoading = false;
      });
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
            'دفترچه و یادداشت‌ها 📓',
            style: TextStyle(
              fontFamily: 'Vazirmatn',
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: colors.textPrimary,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(CupertinoIcons.lightbulb_fill, color: Colors.amber),
              tooltip: 'بانک تجربه‌ها',
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
              icon: Icon(CupertinoIcons.sparkles, color: colors.primary),
              tooltip: 'دستیار هوش مصنوعی دفترچه',
              onPressed: _openAiAssistantSheet,
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
            if (mounted) _loadNotes();
          },

          backgroundColor: colors.primary,
          icon: const Icon(CupertinoIcons.add, color: Colors.white),
          label: const Text(
            'یادداشت جدید',
            style: TextStyle(fontFamily: 'Vazirmatn', fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ),
        body: Column(
          children: [
            // Search Bar & Filter Chips
            Container(
              padding: const EdgeInsets.all(12),
              color: colors.surface,
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 13, color: colors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'جستجو در عنوان، متن یا تگ‌ها...',
                      hintStyle: TextStyle(fontFamily: 'Vazirmatn', fontSize: 12, color: colors.textTertiary),
                      prefixIcon: Icon(CupertinoIcons.search, size: 18, color: colors.textSecondary),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(CupertinoIcons.clear, size: 16),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                                _loadNotes();
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: colors.surfaceSunken,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    onChanged: (val) {
                      setState(() => _searchQuery = val);
                      _loadNotes();
                    },
                  ),
                  const SizedBox(height: 10),

                  // Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip('همه', null),
                        const SizedBox(width: 6),
                        _buildFilterChip('یادداشت‌ها', NoteKind.note),
                        const SizedBox(width: 6),
                        _buildFilterChip('تجربه‌ها 💡', NoteKind.experience),
                        const SizedBox(width: 6),
                        _buildFilterChip('تصمیم‌ها 🎯', NoteKind.decision),
                        const SizedBox(width: 6),
                        _buildFilterChip('ایده‌ها 💡', NoteKind.idea),
                        const SizedBox(width: 6),
                        _buildFilterChip('یادداشت روزانه 📅', NoteKind.daily),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Notes List Body
            Expanded(
              child: _isLoading
                  ? Center(child: CircularProgressIndicator(color: colors.primary))
                  : _notes.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(CupertinoIcons.doc_plaintext, size: 48, color: colors.textTertiary),
                              const SizedBox(height: 12),
                              Text(
                                _searchQuery.isNotEmpty ? 'هیچ یادداشتی یافت نشد 🔍' : 'دفترچه یادداشت خالی است 🌿',
                                style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 14, color: colors.textSecondary),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadNotes,
                          child: ListView(
                            padding: const EdgeInsets.all(12),
                            children: [
                              if (pinnedNotes.isNotEmpty) ...[
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                                  child: Row(
                                    children: [
                                      Icon(CupertinoIcons.pin_fill, size: 14, color: colors.primary),
                                      const SizedBox(width: 4),
                                      Text(
                                        'سنجاق‌شده‌ها',
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
                                ...pinnedNotes.map((n) => NoteCard(note: n, onChanged: _loadNotes)),
                                const SizedBox(height: 12),
                              ],
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
                                ...otherNotes.map((n) => NoteCard(note: n, onChanged: _loadNotes)),
                              ],
                            ],
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, NoteKind? kind) {
    final colors = context.colors;
    final isSelected = _selectedKind == kind;

    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontFamily: 'Vazirmatn',
          fontSize: 11,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Colors.white : colors.textPrimary,
        ),
      ),
      selected: isSelected,
      selectedColor: colors.primary,
      backgroundColor: colors.surfaceSunken,
      onSelected: (_) => _onKindSelected(kind),
    );
  }
}
