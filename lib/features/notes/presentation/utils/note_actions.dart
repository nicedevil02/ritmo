import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/ritmo_toast.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_dialog.dart';
import 'package:ritmo/features/notes/data/notes_repository.dart';
import 'package:ritmo/features/notes/domain/note_models.dart';

class NoteActions {
  NoteActions._();

  static Future<void> confirmAndTrash(
    BuildContext context,
    Note note,
    VoidCallback onChanged,
  ) async {
    final confirmed = await RitmoDialog.show(
      context,
      title: 'انتقال به سطل زباله',
      content:
          'آیا از انتقال یادداشت «${note.title ?? "بدون عنوان"}» به سطل زباله اطمینان دارید؟',
      confirmLabel: 'انتقال به زباله',
      cancelLabel: 'انصراف',
      isDestructive: true,
    );

    if (confirmed == true) {
      RitmoHapticsPolicy.selection();
      await NotesRepository.instance.delete(note.id);
      onChanged();

      if (!context.mounted) return;
      RitmoToast.show(
        context,
        'یادداشت به سطل زباله منتقل شد 🗑️',
        actionLabel: 'برگردان',
        onAction: () async {
          await NotesRepository.instance.restore(note.id);
          onChanged();
        },
      );
    }
  }
}
