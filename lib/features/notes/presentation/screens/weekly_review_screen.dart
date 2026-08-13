import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/utils/ritmo_toast.dart';
import 'package:ritmo/core/ux/ritmo_haptics.dart';
import 'package:ritmo/features/notes/data/notes_repository.dart';
import 'package:ritmo/features/notes/domain/note_models.dart';
import 'package:ritmo/features/notes/logic/weekly_review_engine.dart';
import 'package:ritmo/features/notes/presentation/screens/note_editor_screen.dart';
import 'package:ritmo/features/notes/presentation/utils/note_ui_helper.dart';

class WeeklyReviewScreen extends StatefulWidget {
  const WeeklyReviewScreen({super.key});

  @override
  State<WeeklyReviewScreen> createState() => _WeeklyReviewScreenState();
}

class _WeeklyReviewScreenState extends State<WeeklyReviewScreen> {
  WeeklyReviewStats? _stats;
  List<Note> _orphanNotes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadWeeklyReview();
  }

  Future<void> _loadWeeklyReview() async {
    setState(() => _isLoading = true);
    final stats = await WeeklyReviewEngine.instance.generateWeeklyStats();
    final orphans = await NotesRepository.instance.listOrphans(minDays: 30);
    if (mounted) {
      setState(() {
        _stats = stats;
        _orphanNotes = orphans;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

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
            'مرور هفتگی دفترچه 📊',
            style: TextStyle(
              fontFamily: 'Vazirmatn',
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: colors.textPrimary,
            ),
          ),
        ),
        body: _isLoading
            ? Center(child: CircularProgressIndicator(color: colors.primary))
            : RefreshIndicator(
                onRefresh: _loadWeeklyReview,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Summary Banner
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [colors.primary.withValues(alpha: 0.15), colors.card],
                          begin: Alignment.topRight,
                          end: Alignment.bottomLeft,
                        ),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: colors.primary.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text('✨', style: TextStyle(fontSize: 20)),
                              const SizedBox(width: 8),
                              Text(
                                'گزارش دستاوردهای ۷ روز اخیر',
                                style: TextStyle(
                                  fontFamily: 'Vazirmatn',
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: colors.primary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildStatItem(
                                  label: 'یادداشت جدید',
                                  value: PersianDigits.convert(_stats?.notesCreatedCount.toString() ?? '۰'),
                                  emoji: '📝',
                                ),
                              ),
                              Expanded(
                                child: _buildStatItem(
                                  label: 'درس زندگی',
                                  value: PersianDigits.convert(_stats?.experiencesAddedCount.toString() ?? '۰'),
                                  emoji: '💡',
                                ),
                              ),
                              Expanded(
                                child: _buildStatItem(
                                  label: 'مجموع کلمات',
                                  value: PersianDigits.convert(_stats?.wordCountSum.toString() ?? '۰'),
                                  emoji: '✍️',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Top Tags Section
                    if (_stats != null && _stats!.topTags.isNotEmpty) ...[
                      Text(
                        'موضوعات و برچسب‌های پرکاربرد هفته',
                        style: TextStyle(
                          fontFamily: 'Vazirmatn',
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _stats!.topTags.map((tag) {
                          return Chip(
                            backgroundColor: colors.surfaceSunken,
                            label: Text(
                              '#$tag',
                              style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 11, color: colors.primary),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Orphans Review Queue (Inbox Zero for Notes)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Text('📦', style: TextStyle(fontSize: 16)),
                            const SizedBox(width: 6),
                            Text(
                              'صف مرور یادداشت‌های خاک‌خورده',
                              style: TextStyle(
                                fontFamily: 'Vazirmatn',
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: colors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: colors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${PersianDigits.convert(_orphanNotes.length.toString())} مورد',
                            style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 11, color: colors.primary),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'یادداشت‌هایی که بیش از ۳۰ روز است باز نشده‌اند و پیوندی ندارند.',
                      style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 11, color: colors.textSecondary),
                    ),
                    const SizedBox(height: 10),

                    if (_orphanNotes.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: colors.card,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Center(
                          child: Text(
                            'هیچ یادداشت خاک‌خورده‌ای نداری! دفترچه‌ات کاملاً به‌روز است 🌿',
                            style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 12, color: colors.textSecondary),
                          ),
                        ),
                      )
                    else
                      ..._orphanNotes.map((note) => _buildOrphanCard(context, note)),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildStatItem({
    required String label,
    required String value,
    required String emoji,
  }) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: colors.surfaceSunken,
        borderRadius: BorderRadius.circular(RitmoRadius.card),
        border: Border.all(color: colors.border.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 16, fontWeight: FontWeight.bold, color: colors.primary),
          ),
          Text(
            label,
            style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 10, color: colors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildOrphanCard(BuildContext context, Note note) {
    final colors = context.colors;
    final style = NoteUiHelper.getKindStyle(context, note.kind);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: style.bgTint,
        borderRadius: BorderRadius.circular(RitmoRadius.card),
        border: Border.all(color: colors.border.withValues(alpha: 0.25)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(style.icon, size: 14, color: style.accentColor),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    note.title ?? 'بدون عنوان',
                    style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 13, fontWeight: FontWeight.bold, color: colors.textPrimary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              note.body,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 11.5, color: colors.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () async {
                    await NotesRepository.instance.markOpened(note.id);
                    if (!context.mounted) return;
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => NoteEditorScreen(note: note)),
                    );
                    _loadWeeklyReview();
                  },
                  child: const Text('مشاهده و ویرایش', style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 11)),
                ),
                TextButton(
                  onPressed: () async {
                    RitmoHaptics.selection();
                    await NotesRepository.instance.archive(note.id);
                    RitmoToast.show(context, 'یادداشت بایگانی شد 📦');
                    _loadWeeklyReview();
                  },
                  child: const Text('آرشیو 📦', style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 11)),
                ),
                TextButton(
                  onPressed: () async {
                    RitmoHaptics.selection();
                    await NotesRepository.instance.delete(note.id);
                    RitmoToast.show(context, 'به سطل زباله منتقل شد 🗑️');
                    _loadWeeklyReview();
                  },
                  child: const Text('حذف 🗑️', style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 11, color: Colors.redAccent)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
