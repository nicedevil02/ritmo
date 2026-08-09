import 'package:flutter/material.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/time/ritmo_clock.dart';
import 'package:ritmo/core/utils/ritmo_toast.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

/// Helper to promote a module note to full notebook note (M-13).
class NotePromoter {
  NotePromoter._();
  static final NotePromoter instance = NotePromoter._();

  static const _uuid = Uuid();

  Future<String?> promote({
    required BuildContext context,
    required String module,
    required String entityId,
    required String text,
    String? titleHint,
    String? dayKey,
  }) async {
    // ⛔ Security requirement: cycle module notes CANNOT be promoted to notes table
    if (module == 'cycle') {
      return null;
    }

    final trimmedText = text.trim();
    if (trimmedText.isEmpty) return null;

    final noteId = 'note_${_uuid.v4()}';
    final linkId = 'link_${_uuid.v4()}';
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final currentDayKey = dayKey ?? SystemClock().today().value;

    final title = titleHint ?? (trimmedText.length > 40 ? '${trimmedText.substring(0, 40)}...' : trimmedText);

    final db = await DatabaseHelper.instance.database;

    try {
      await db.transaction((txn) async {
        // 1. Create note in `notes` table
        await txn.insert('notes', {
          'id': noteId,
          'title': title,
          'body': trimmedText,
          'titleNormalized': title.toLowerCase(),
          'bodyNormalized': trimmedText.toLowerCase(),
          'kind': 'NOTE',
          'status': 'ACTIVE',
          'isPrivate': 0,
          'isPinned': 0,
          'dayKey': currentDayKey,
          'sourceModule': module,
          'sourceEntityId': entityId,
          'wordCount': trimmedText.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length,
          'createdAt': nowMs,
          'updatedAt': nowMs,
          'openCount': 0,
          'reviewStage': 0,
        }, conflictAlgorithm: ConflictAlgorithm.replace);

        // 2. Create note_links entry with SPAWNED relation
        await txn.insert('note_links', {
          'id': linkId,
          'noteId': noteId,
          'linkModule': module,
          'linkEntityId': entityId,
          'relation': 'SPAWNED',
          'createdAt': nowMs,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      });

      if (context.mounted) {
        RitmoToast.show(
          context,
          'به دفترچه منتقل شد 📓',
          actionLabel: 'برگردان',
          onAction: () async {
            try {
              await db.delete('notes', where: 'id = ?', whereArgs: [noteId]);
              await db.delete('note_links', where: 'id = ?', whereArgs: [linkId]);
            } catch (_) {}
          },
        );
      }

      return noteId;
    } catch (e) {
      if (context.mounted) {
        RitmoToast.show(
          context,
          'خطا در ثبت دفترچه',
        );
      }
      return null;
    }
  }
}
