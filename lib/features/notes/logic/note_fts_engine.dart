import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/features/notes/data/notes_repository.dart';
import 'package:ritmo/features/notes/domain/note_models.dart';
import 'package:ritmo/features/notes/logic/note_text_normalizer.dart';
import 'package:sqflite/sqflite.dart';

class NoteFtsEngine {
  NoteFtsEngine._();
  static final NoteFtsEngine instance = NoteFtsEngine._();

  bool? _cachedFtsAvailable;

  Future<Database> get _db async => DatabaseHelper.instance.database;

  Future<bool> isFtsAvailable() async {
    if (_cachedFtsAvailable != null) return _cachedFtsAvailable!;
    try {
      final db = await _db;
      final rows = await db.query(
        'app_settings',
        where: 'key = ?',
        whereArgs: ['notes_fts_available'],
        limit: 1,
      );
      if (rows.isNotEmpty) {
        _cachedFtsAvailable = rows.first['value'] == 'true';
        return _cachedFtsAvailable!;
      }
    } catch (_) {}
    _cachedFtsAvailable = false;
    return false;
  }

  void invalidateCache() {
    _cachedFtsAvailable = null;
  }

  Future<void> indexNote(Note note) async {
    final available = await isFtsAvailable();
    if (!available) return;

    try {
      final db = await _db;
      final tagsRows = await db.query('note_tags', where: 'noteId = ?', whereArgs: [note.id]);
      final tagsN = tagsRows.map((r) => r['tagNormalized'] as String).join(' ');

      final titleN = NoteTextNormalizer.forIndex(note.title ?? '');
      final bodyN = NoteTextNormalizer.forIndex(note.body);

      await db.delete('notes_fts', where: 'noteId = ?', whereArgs: [note.id]);
      await db.insert('notes_fts', {
        'noteId': note.id,
        'titleN': titleN,
        'bodyN': bodyN,
        'tagsN': tagsN,
      });
    } catch (_) {}
  }

  Future<void> deleteFromIndex(String noteId) async {
    final available = await isFtsAvailable();
    if (!available) return;
    try {
      final db = await _db;
      await db.delete('notes_fts', where: 'noteId = ?', whereArgs: [noteId]);
    } catch (_) {}
  }

  Future<void> rebuildIndex() async {
    final available = await isFtsAvailable();
    if (!available) return;

    try {
      final db = await _db;
      await db.delete('notes_fts');
      final notes = await db.query('notes', where: "status = 'ACTIVE'");

      for (final row in notes) {
        final note = Note.fromMap(row);
        await indexNote(note);
      }
    } catch (_) {}
  }

  Future<List<Note>> search(
    String rawQuery, {
    NoteKind? kind,
    String? tag,
    int limit = 30,
    int offset = 0,
  }) async {
    final trimmed = rawQuery.trim();
    if (trimmed.isEmpty) {
      if (kind != null) {
        return NotesRepository.instance.listByKind(kind);
      }
      if (tag != null && tag.isNotEmpty) {
        return NotesRepository.instance.listByTag(tag);
      }
      return NotesRepository.instance.listRecent(limit: limit, offset: offset);
    }

    final queryN = NoteTextNormalizer.forQuery(trimmed);
    if (queryN.isEmpty) {
      return NotesRepository.instance.listRecent(limit: limit, offset: offset);
    }

    final available = await isFtsAvailable();
    final db = await _db;

    if (available) {
      try {
        final ftsQuery = '$queryN*';
        String sql = '''
          SELECT n.* FROM notes n
          INNER JOIN notes_fts f ON n.id = f.noteId
          WHERE n.status = 'ACTIVE' AND (f.titleN MATCH ? OR f.bodyN MATCH ? OR f.tagsN MATCH ?)
        ''';
        final params = <dynamic>[ftsQuery, ftsQuery, ftsQuery];

        if (kind != null) {
          sql += ' AND n.kind = ?';
          params.add(kind.value);
        }

        if (tag != null && tag.isNotEmpty) {
          sql += ' AND EXISTS (SELECT 1 FROM note_tags t WHERE t.noteId = n.id AND t.tagNormalized = ?)';
          params.add(tag.toLowerCase());
        }

        sql += ' ORDER BY n.isPinned DESC, n.updatedAt DESC LIMIT ? OFFSET ?';
        params.add(limit);
        params.add(offset);

        final rows = await db.rawQuery(sql, params);
        if (rows.isNotEmpty) {
          return rows.map((r) => Note.fromMap(r)).toList();
        }
      } catch (_) {
        // Fallback to LIKE query if FTS expression fails
      }
    }

    // Fallback LIKE search
    final likePattern = '%$queryN%';
    String sql = '''
      SELECT DISTINCT n.* FROM notes n
      LEFT JOIN note_tags t ON n.id = t.noteId
      WHERE n.status = 'ACTIVE'
        AND (n.titleNormalized LIKE ? OR n.bodyNormalized LIKE ? OR t.tagNormalized LIKE ?)
    ''';
    final params = <dynamic>[likePattern, likePattern, likePattern];

    if (kind != null) {
      sql += ' AND n.kind = ?';
      params.add(kind.value);
    }
    if (tag != null && tag.isNotEmpty) {
      sql += ' AND t.tagNormalized = ?';
      params.add(tag.toLowerCase());
    }

    sql += ' ORDER BY n.isPinned DESC, n.updatedAt DESC LIMIT ? OFFSET ?';
    params.add(limit);
    params.add(offset);

    final rows = await db.rawQuery(sql, params);
    return rows.map((r) => Note.fromMap(r)).toList();
  }
}
