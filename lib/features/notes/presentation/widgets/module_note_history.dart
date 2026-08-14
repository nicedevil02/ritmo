import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_button.dart';
import 'package:ritmo/core/widgets/ritmo_sheet_scaffold.dart';
import 'package:ritmo/features/notes/presentation/widgets/ritmo_shimmer.dart';
import 'package:ritmo/features/notes/data/note_bridge.dart';
import 'package:shamsi_date/shamsi_date.dart';

/// Card widget to display a single past note (M-01).
class ModuleNoteHistoryTile extends StatelessWidget {
  const ModuleNoteHistoryTile({
    super.key,
    required this.note,
    this.onTap,
  });

  final BridgedNote note;
  final VoidCallback? onTap;

  String _formatJalali(DateTime dt) {
    final j = Jalali.fromDateTime(dt);
    final year = PersianDigits.convert(j.year.toString());
    final month = PersianDigits.convert(j.month.toString().padLeft(2, '0'));
    final day = PersianDigits.convert(j.day.toString().padLeft(2, '0'));
    return '$year/$month/$day';
  }

  IconData _getModuleIcon(String? module) {
    switch (module) {
      case 'study':
      case 'konkur':
        return CupertinoIcons.book_solid;
      case 'courses':
        return CupertinoIcons.briefcase_fill;
      case 'routines':
        return CupertinoIcons.repeat;
      case 'tasks':
        return CupertinoIcons.checkmark_square_fill;
      case 'sleep':
        return CupertinoIcons.moon_stars_fill;
      case 'energy':
        return CupertinoIcons.bolt_fill;
      case 'sports':
        return Icons.fitness_center;
      case 'health':
        return CupertinoIcons.heart_fill;
      default:
        return CupertinoIcons.doc_text_fill;
    }
  }

  void _showNoteBottomSheet(BuildContext context) {
    final colors = context.colors;
    RitmoSheetScaffold.present(
      context: context,
      title: note.title ?? 'یادداشت',
      subtitle: _formatJalali(note.createdAt),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(RitmoSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (note.isPromoted)
              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: RitmoSpacing.sm, vertical: RitmoSpacing.xs / 2),
                  margin: const EdgeInsets.only(bottom: RitmoSpacing.md),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(RitmoRadius.badge),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.menu_book_rounded, size: 12, color: colors.primary),
                      const SizedBox(width: RitmoSpacing.xs),
                      Text(
                        'دفترچه',
                        style: Theme.of(ctx).textTheme.labelSmall?.copyWith(
                              color: colors.primary,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            Text(
              note.text,
              textDirection: TextDirection.rtl,
              style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                    height: 1.6,
                    color: colors.textPrimary,
                  ),
            ),
            const SizedBox(height: RitmoSpacing.xl),
            RitmoPrimaryButton(
              label: 'بستن',
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDarkMode = context.isDark;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: RitmoSpacing.xs),
      child: RitmoTheme.glassCardLight(
        blurSigma: 10,
        color: colors.surface.withValues(alpha: isDarkMode ? 0.7 : 0.85),
        child: InkWell(
          onTap: onTap ?? () => _showNoteBottomSheet(context),
          borderRadius: BorderRadius.circular(RitmoRadius.card),
          child: Padding(
            padding: const EdgeInsets.all(RitmoSpacing.md),
            child: Row(
              children: [
                Icon(_getModuleIcon(note.sourceModule), size: 18, color: colors.primary),
                const SizedBox(width: RitmoSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        note.text,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textDirection: TextDirection.rtl,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colors.textPrimary,
                            ),
                      ),
                      const SizedBox(height: RitmoSpacing.xs),
                      Text(
                        _formatJalali(note.createdAt),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: colors.textSecondary,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Section listing past notes for a module entity (M-01).
class ModuleNoteHistorySection extends StatefulWidget {
  const ModuleNoteHistorySection({
    super.key,
    required this.module,
    required this.entityId,
  });

  final String module;
  final String entityId;

  @override
  State<ModuleNoteHistorySection> createState() => _ModuleNoteHistorySectionState();
}

class _ModuleNoteHistorySectionState extends State<ModuleNoteHistorySection> {
  late Future<List<BridgedNote>> _notesFuture;

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  @override
  void didUpdateWidget(covariant ModuleNoteHistorySection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.module != widget.module || oldWidget.entityId != widget.entityId) {
      _loadNotes();
    }
  }

  void _loadNotes() {
    _notesFuture = NoteBridge.instance.forEntity(
      module: widget.module,
      entityId: widget.entityId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return FutureBuilder<List<BridgedNote>>(
      future: _notesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const RitmoShimmerList(count: 2);
        }

        final notes = snapshot.data ?? [];
        if (notes.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: RitmoSpacing.md),
            child: Text(
              'هنوز یادداشتی برای این مورد ثبت نکردی.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.textSecondary,
                  ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: notes.map((n) => ModuleNoteHistoryTile(note: n)).toList(),
        );
      },
    );
  }
}
