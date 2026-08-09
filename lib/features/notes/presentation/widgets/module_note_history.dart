import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
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
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colors.textSecondary.withValues(alpha: 0.15)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(_getModuleIcon(note.sourceModule), size: 18, color: colors.primary),
                      const SizedBox(width: 8),
                      Text(
                        _formatJalali(note.createdAt),
                        style: TextStyle(
                          fontFamily: 'Vazirmatn',
                          fontSize: 13,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  if (note.isPromoted)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '📓 دفترچه',
                        style: TextStyle(
                          fontFamily: 'Vazirmatn',
                          fontSize: 11,
                          color: colors.primary,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (note.title != null && note.title!.isNotEmpty) ...[
                Text(
                  note.title!,
                  style: TextStyle(
                    fontFamily: 'Vazirmatn',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Text(
                note.text,
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  fontFamily: 'Vazirmatn',
                  fontSize: 14,
                  height: 1.6,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('بستن', style: TextStyle(fontFamily: 'Vazirmatn')),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: RitmoTheme.glassCardLight(
        blurSigma: 10,
        color: colors.card.withValues(alpha: isDarkMode ? 0.7 : 0.85),
        child: InkWell(
          onTap: onTap ?? () => _showNoteBottomSheet(context),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(_getModuleIcon(note.sourceModule), size: 18, color: colors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        note.text,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textDirection: TextDirection.rtl,
                        style: TextStyle(
                          fontFamily: 'Vazirmatn',
                          fontSize: 13,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatJalali(note.createdAt),
                        style: TextStyle(
                          fontFamily: 'Vazirmatn',
                          fontSize: 11,
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
          return const Center(child: Padding(
            padding: EdgeInsets.all(16.0),
            child: CupertinoActivityIndicator(),
          ));
        }

        final notes = snapshot.data ?? [];
        if (notes.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'هنوز یادداشتی برای این مورد ثبت نکردی.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Vazirmatn',
                fontSize: 12,
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
