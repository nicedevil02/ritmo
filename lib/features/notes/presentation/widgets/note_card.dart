import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/ux/ritmo_haptics.dart';
import 'package:ritmo/features/notes/data/notes_repository.dart';
import 'package:ritmo/features/notes/domain/note_models.dart';
import 'package:ritmo/features/notes/presentation/screens/note_editor_screen.dart';

class NoteCard extends StatelessWidget {
  final Note note;
  final VoidCallback onChanged;

  const NoteCard({
    super.key,
    required this.note,
    required this.onChanged,
  });

  String _getKindEmoji(NoteKind kind) {
    switch (kind) {
      case NoteKind.note:
        return '📓';
      case NoteKind.daily:
        return '📅';
      case NoteKind.experience:
        return '💡';
      case NoteKind.idea:
        return '⚡';
      case NoteKind.decision:
        return '🎯';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 4),
        color: colors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: note.isPinned ? colors.primary.withValues(alpha: 0.5) : colors.border.withValues(alpha: 0.3),
            width: note.isPinned ? 1.5 : 1.0,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            RitmoHaptics.selection();
            await NotesRepository.instance.markOpened(note.id);
            if (!context.mounted) return;
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => NoteEditorScreen(note: note)),
            );
            onChanged();
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: Emoji + Title + Pin & Menu
                Row(
                  children: [
                    Text(_getKindEmoji(note.kind), style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        note.title ?? 'بدون عنوان',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Vazirmatn',
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                    if (note.isPinned) ...[
                      Icon(CupertinoIcons.pin_fill, size: 14, color: colors.primary),
                      const SizedBox(width: 4),
                    ],
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert, size: 18, color: colors.textSecondary),
                      onSelected: (val) async {
                        RitmoHaptics.selection();
                        if (val == 'pin') {
                          if (note.isPinned) {
                            await NotesRepository.instance.unpin(note.id);
                          } else {
                            await NotesRepository.instance.pin(note.id);
                          }
                        } else if (val == 'archive') {
                          await NotesRepository.instance.archive(note.id);
                        } else if (val == 'delete') {
                          await NotesRepository.instance.delete(note.id);
                        }
                        onChanged();
                      },
                      itemBuilder: (ctx) => [
                        PopupMenuItem(
                          value: 'pin',
                          child: Text(note.isPinned ? 'حذف سنجاق' : 'سنجاق‌کردن 📌', style: const TextStyle(fontFamily: 'Vazirmatn')),
                        ),
                        const PopupMenuItem(
                          value: 'archive',
                          child: Text('آرشیو 📦', style: TextStyle(fontFamily: 'Vazirmatn')),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text('حذف 🗑️', style: TextStyle(fontFamily: 'Vazirmatn', color: Colors.redAccent)),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Body excerpt (max 2 lines)
                Text(
                  note.body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Vazirmatn',
                    fontSize: 12.5,
                    color: colors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 10),

                // Footer: Source module tag + word count
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (note.sourceModule != null && note.sourceModule!.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: colors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'از ماژول ${note.sourceModule}',
                          style: TextStyle(
                            fontFamily: 'Vazirmatn',
                            fontSize: 10,
                            color: colors.primary,
                          ),
                        ),
                      )
                    else
                      const SizedBox.shrink(),
                    Text(
                      '${note.wordCount} کلمه',
                      style: TextStyle(
                        fontFamily: 'Vazirmatn',
                        fontSize: 10,
                        color: colors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
