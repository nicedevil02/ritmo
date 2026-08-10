import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/ux/ritmo_haptics.dart';
import 'package:ritmo/features/notes/data/experience_repository.dart';
import 'package:ritmo/features/notes/data/notes_repository.dart';
import 'package:ritmo/features/notes/domain/note_models.dart';

import 'package:ritmo/features/notes/presentation/screens/note_editor_screen.dart';

class ExperienceHubScreen extends StatefulWidget {
  const ExperienceHubScreen({super.key});

  @override
  State<ExperienceHubScreen> createState() => _ExperienceHubScreenState();
}

class _ExperienceHubScreenState extends State<ExperienceHubScreen> {
  List<Experience> _experiences = [];
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
      if (mounted) {
        setState(() {
          _experiences = exps;
          _isLoading = false;
        });
      }
    } catch (e, st) {
      debugPrint('Error loading experiences in ExperienceHubScreen: $e\n$st');
      if (mounted) {
        setState(() {
          _experiences = [];
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
            'بانک تجربه‌ها و درس‌های زندگی 💡',
            style: TextStyle(
              fontFamily: 'Vazirmatn',
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: colors.textPrimary,
            ),
          ),
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
          backgroundColor: colors.primary,
          icon: const Icon(CupertinoIcons.add, color: Colors.white),
          label: const Text('ثبت تجربه جدید', style: TextStyle(fontFamily: 'Vazirmatn', fontWeight: FontWeight.bold, color: Colors.white)),
        ),

        body: Column(
          children: [
            // Category Tabs
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              color: colors.surface,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ChoiceChip(
                      label: Text('همه', style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 11, color: _selectedCategory == null ? Colors.white : colors.textPrimary)),
                      selected: _selectedCategory == null,
                      selectedColor: colors.primary,
                      backgroundColor: colors.surfaceSunken,
                      onSelected: (_) {
                        setState(() => _selectedCategory = null);
                      },
                    ),
                    const SizedBox(width: 6),
                    ...ExperienceCategory.values.map((cat) {
                      final isSelected = _selectedCategory == cat;
                      return Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: ChoiceChip(
                          label: Text('${cat.emoji} ${cat.labelFa}', style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 11, color: isSelected ? Colors.white : colors.textPrimary)),
                          selected: isSelected,
                          selectedColor: colors.primary,
                          backgroundColor: colors.surfaceSunken,
                          onSelected: (_) {
                            setState(() => _selectedCategory = cat);
                          },
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),

            // Experiences List
            Expanded(
              child: _isLoading
                  ? Center(child: CircularProgressIndicator(color: colors.primary))
                  : filtered.isEmpty
                      ? Center(
                          child: Text(
                            'هیچ تجربه‌ای در این دسته‌بندی ثبت نشده است 🌿',
                            style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 13, color: colors.textSecondary),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: filtered.length,
                          itemBuilder: (ctx, idx) {
                            final exp = filtered[idx];
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              color: colors.card,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                                side: BorderSide(color: colors.border.withValues(alpha: 0.3)),
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: () async {
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
                                            Text(exp.category.emoji, style: const TextStyle(fontSize: 16)),
                                            const SizedBox(width: 6),
                                            Text(
                                              exp.category.labelFa,
                                              style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 12, fontWeight: FontWeight.bold, color: colors.primary),
                                            ),
                                          ],
                                        ),
                                        Row(
                                          children: [
                                            Text('فعال در پیشنهاد روزانه', style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 10, color: colors.textSecondary)),
                                            const SizedBox(width: 4),
                                            CupertinoSwitch(
                                              value: exp.isActive,
                                              activeTrackColor: colors.primary,
                                              onChanged: (val) async {
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
                                      style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 14, fontWeight: FontWeight.bold, color: colors.textPrimary),
                                    ),
                                    if (exp.contextText != null && exp.contextText!.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        exp.contextText!,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 12, color: colors.textSecondary),
                                      ),
                                    ],
                                    const SizedBox(height: 8),
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
                                          'نمایش داده شده: ${exp.showCount} بار',
                                          style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 10, color: colors.textTertiary),
                                        ),
                                      ],
                                    ),
                                  ],
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
}
