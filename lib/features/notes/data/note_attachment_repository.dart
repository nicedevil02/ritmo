import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/features/notes/domain/note_models.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

class NoteAttachmentRepository {
  NoteAttachmentRepository._();
  static final NoteAttachmentRepository instance = NoteAttachmentRepository._();

  static const int maxSizeBytes = 10 * 1024 * 1024; // 10 MB
  static const _uuid = Uuid();

  Future<Database> get _db async => DatabaseHelper.instance.database;

  Future<String> get _docsDir async {
    final dir = await getApplicationDocumentsDirectory();
    return dir.path;
  }

  Future<String> resolveAbsolutePath(String relativePath) async {
    final docs = await _docsDir;
    return p.join(docs, relativePath);
  }

  Future<List<NoteAttachment>> forNote(String noteId) async {
    final db = await _db;
    final rows = await db.query(
      'note_attachments',
      where: 'noteId = ?',
      whereArgs: [noteId],
      orderBy: 'createdAt ASC',
    );
    return rows.map((r) => NoteAttachment.fromMap(r)).toList();
  }

  Future<NoteAttachment> add({
    required String noteId,
    required File sourceFile,
    required String fileName,
    String? mimeType,
    String? caption,
  }) async {
    final size = await sourceFile.length();
    if (size > maxSizeBytes) {
      throw Exception('حجم پیوست بیشتر از ۱۰ مگابایت است');
    }

    final id = 'att_${_uuid.v4()}';
    final relativePath = p.join('note_attachments', noteId, '${id}_$fileName');
    final absolutePath = await resolveAbsolutePath(relativePath);

    final destFile = File(absolutePath);
    await destFile.parent.create(recursive: true);
    await sourceFile.copy(absolutePath);

    final isImg =
        mimeType?.startsWith('image/') ??
        [
          '.png',
          '.jpg',
          '.jpeg',
          '.webp',
          '.gif',
        ].any((ext) => fileName.toLowerCase().endsWith(ext));

    final attachment = NoteAttachment(
      id: id,
      noteId: noteId,
      kind: isImg ? 'IMAGE' : 'FILE',
      fileName: fileName,
      relativePath: relativePath,
      fileSizeBytes: size,
      mimeType: mimeType,
      caption: caption,
      createdAt: DateTime.now(),
    );

    final db = await _db;
    await db.insert('note_attachments', attachment.toMap());
    return attachment;
  }

  Future<void> remove(String attachmentId) async {
    final db = await _db;
    final rows = await db.query(
      'note_attachments',
      where: 'id = ?',
      whereArgs: [attachmentId],
      limit: 1,
    );
    if (rows.isEmpty) return;

    final attachment = NoteAttachment.fromMap(rows.first);
    final absPath = await resolveAbsolutePath(attachment.relativePath);
    final f = File(absPath);
    if (await f.exists()) {
      try {
        await f.delete();
      } catch (_) {}
    }

    await db.delete(
      'note_attachments',
      where: 'id = ?',
      whereArgs: [attachmentId],
    );
  }

  Future<void> removeAllForNote(String noteId) async {
    final attachments = await forNote(noteId);
    for (final att in attachments) {
      await remove(att.id);
    }
  }
}
