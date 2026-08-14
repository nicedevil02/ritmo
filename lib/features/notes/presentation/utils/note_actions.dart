import 'package:flutter/material.dart';
import 'package:ritmo/core/utils/ritmo_toast.dart';
import 'package:ritmo/core/ux/ritmo_haptics.dart';
import 'package:ritmo/features/notes/data/notes_repository.dart';
import 'package:ritmo/features/notes/domain/note_models.dart';

class NoteActions {
  NoteActions._();

  static Future<void> confirmAndTrash(
    BuildContext context,
    Note note,
    VoidCallback onChanged,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('انتقال به سطل زباله', style: TextStyle(fontFamily: 'Vazirmatn')),
        content: Text(
          'آیا از انتقال یادداشت «${note.title ?? "بدون عنوان"}» به سطل زباله اطمینان دارید؟',
          style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('انصراف', style: TextStyle(fontFamily: 'Vazirmatn')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            child: const Text('انتقال به زباله', style: TextStyle(fontFamily: 'Vazirmatn')),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      RitmoHaptics.selection();
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
