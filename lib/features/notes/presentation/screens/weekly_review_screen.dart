import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/utils/ritmo_toast.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_card.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_chip.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_page_scaffold.dart';
import 'package:ritmo/features/notes/data/notes_repository.dart';
import 'package:ritmo/features/notes/domain/note_models.dart';
import 'package:ritmo/features/notes/logic/weekly_review_engine.dart';
import 'package:ritmo/features/notes/presentation/screens/note_editor_screen.dart';
import 'package:ritmo/features/notes/presentation/utils/note_actions.dart';
import 'package:ritmo/features/notes/presentation/utils/note_ui_helper.dart';
import 'package:ritmo/features/notes/presentation/widgets/ritmo_shimmer.dart';

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
      child: RitmoPageScaffold(
        padding: EdgeInsets.zero,
        appBar: AppBar(
          backgroundColor: colors.surface,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_forward_rounded, color: colors.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'مرور هفتگی دفترچه',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colors.textPrimary,
                ),
          ),
        ),
        body: _isLoading
            ? const RitmoShimmerList(count: 4)
            : RefreshIndicator(
                onRefresh: _loadWeeklyReview,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(14, RitmoSpacing.lg, 14, RitmoSpacing.xl),
                  children: [
                    // Summary Banner
                    Container(
                      padding: const EdgeInsets.all(RitmoSpacing.lg),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [colors.primary.withValues(alpha: 0.15), colors.surface],
                          begin: Alignment.topRight,
                          end: Alignment.bottomLeft,
                        ),
                        borderRadius: BorderRadius.circular(RitmoRadius.hero),
                        border: Border.all(color: colors.primary.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(CupertinoIcons.sparkles, color: colors.primary, size: 20),
                              const SizedBox(width: RitmoSpacing.xs),
                              Text(
                                'گزارش دستاوردهای ۷ روز اخیر',
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: colors.primary,
                                    ),
                              ),
                            ],
                          ),
                          const SizedBox(height: RitmoSpacing.md),
                          Row(
                            children: [
                              Expanded(
                                child: _buildStatItem(
                                  label: 'یادداشت جدید',
                                  value: PersianDigits.convert(_stats?.notesCreatedCount.toString() ?? '۰'),
                                  icon: CupertinoIcons.doc_text,
                                ),
                              ),
                              const SizedBox(width: RitmoSpacing.xs),
                              Expanded(
                                child: _buildStatItem(
                                  label: 'درس زندگی',
                                  value: PersianDigits.convert(_stats?.experiencesAddedCount.toString() ?? '۰'),
                                  icon: Icons.lightbulb_outline_rounded,
                                ),
                              ),
                              const SizedBox(width: RitmoSpacing.xs),
                              Expanded(
                                child: _buildStatItem(
                                  label: 'مجموع کلمات',
                                  value: PersianDigits.convert(_stats?.wordCountSum.toString() ?? '۰'),
                                  icon: CupertinoIcons.pencil,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: RitmoSpacing.lg),

                    // Top Tags Section
                    if (_stats != null && _stats!.topTags.isNotEmpty) ...[
                      Text(
                        'موضوعات و برچسب‌های پرکاربرد هفته',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colors.textPrimary,
                            ),
                      ),
                      const SizedBox(height: RitmoSpacing.sm),
                      Wrap(
                        spacing: RitmoSpacing.sm,
                        runSpacing: RitmoSpacing.sm,
                        children: _stats!.topTags.map((tag) {
                          return RitmoChip(
                            label: '#$tag',
                            color: colors.primary,
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: RitmoSpacing.lg),
                    ],

                    // Orphans Review Queue
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(CupertinoIcons.archivebox, size: 16, color: colors.textPrimary),
                            const SizedBox(width: RitmoSpacing.xs),
                            Text(
                              'صف مرور یادداشت‌های خاک‌خورده',
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: colors.textPrimary,
                                  ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: RitmoSpacing.sm, vertical: RitmoSpacing.xs / 2),
                          decoration: BoxDecoration(
                            color: colors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(RitmoRadius.badge),
                          ),
                          child: Text(
                            '${PersianDigits.convert(_orphanNotes.length.toString())} مورد',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: colors.primary,
                                ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: RitmoSpacing.xs / 2),
                    Text(
                      'یادداشت‌هایی که بیش از ۳۰ روز است باز نشده‌اند و پیوندی ندارند.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.textSecondary),
                    ),
                    const SizedBox(height: RitmoSpacing.sm),

                    if (_orphanNotes.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(RitmoSpacing.xl),
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(RitmoRadius.card),
                        ),
                        child: Center(
                          child: Text(
                            'هیچ یادداشت خاک‌خورده‌ای نداری! دفترچه‌ات کاملاً به‌روز است.',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: colors.textSecondary,
                                ),
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
    required IconData icon,
  }) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: RitmoSpacing.sm, horizontal: RitmoSpacing.xs),
      decoration: BoxDecoration(
        color: colors.surfaceSunken,
        borderRadius: BorderRadius.circular(RitmoRadius.card),
        border: Border.all(color: colors.border.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: colors.primary),
          const SizedBox(height: RitmoSpacing.xs / 2),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colors.primary,
                ),
          ),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colors.textSecondary,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrphanCard(BuildContext context, Note note) {
    final colors = context.colors;
    final style = NoteUiHelper.getKindStyle(context, note.kind);

    return RitmoCard(
      margin: const EdgeInsets.symmetric(vertical: RitmoSpacing.xs),
      padding: const EdgeInsets.all(RitmoSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(style.icon, size: 14, color: style.accentColor),
              const SizedBox(width: RitmoSpacing.xs),
              Expanded(
                child: Text(
                  note.title ?? 'بدون عنوان',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colors.textPrimary,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: RitmoSpacing.xs),
          Text(
            note.body,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.textSecondary,
                  height: 1.4,
                ),
          ),
          const SizedBox(height: RitmoSpacing.sm),
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
                  await _loadWeeklyReview();
                },
                child: Text('مشاهده و ویرایش', style: Theme.of(context).textTheme.labelSmall),
              ),
              TextButton(
                onPressed: () async {
                  RitmoHapticsPolicy.selection();
                  await NotesRepository.instance.archive(note.id);
                  if (context.mounted) {
                    RitmoToast.show(context, 'یادداشت بایگانی شد 📦');
                  }
                  await _loadWeeklyReview();
                },
                child: Text('آرشیو', style: Theme.of(context).textTheme.labelSmall),
              ),
              TextButton(
                onPressed: () {
                  NoteActions.confirmAndTrash(context, note, _loadWeeklyReview);
                },
                child: Text(
                  'حذف',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colors.error,
                      ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

