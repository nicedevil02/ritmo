import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/time/ritmo_clock.dart';
import 'package:ritmo/features/notes/data/note_attachment_repository.dart';
import 'package:ritmo/features/notes/domain/note_models.dart';
import 'package:ritmo/features/notes/domain/capture_context.dart';
import 'package:ritmo/features/notes/logic/note_fts_engine.dart';
import 'package:ritmo/core/database/schema/tables/note_tables.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

class NotesRepository {
  NotesRepository._();
  static final NotesRepository instance = NotesRepository._();

  static const _uuid = Uuid();
  bool _schemaEnsured = false;

  Future<Database> get _db async {
    final db = await DatabaseHelper.instance.database;
    if (!_schemaEnsured) {
      await NoteTables.ensureSchema(db);
      _schemaEnsured = true;
    }
    return db;
  }

  Future<Note> create({
    String? title,
    required String body,
    NoteKind kind = NoteKind.note,
    bool isPrivate = false,
    bool isPinned = false,
    String? dayKey,
    String? sourceModule,
    String? sourceEntityId,
    List<String>? tags,
    String? linkModule,
    String? linkEntityId,
    String? activeZone,
  }) async {
    final db = await _db;
    final id = 'note_${_uuid.v4()}';
    final clock = SystemClock();
    final nowMs = clock.now().millisecondsSinceEpoch;
    final currentDayKey = dayKey ?? clock.today().value;

    final trimmedBody = body.trim();
    final derivedTitle = title?.trim().isNotEmpty == true
        ? title!.trim()
        : (trimmedBody.length > 40 ? '${trimmedBody.substring(0, 40)}...' : trimmedBody);

    final captureContext = await CaptureContext.buildCurrent(activeZone: activeZone);
    final wordCount = trimmedBody.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;

    final note = Note(
      id: id,
      title: derivedTitle,
      body: trimmedBody,
      titleNormalized: derivedTitle.toLowerCase(),
      bodyNormalized: trimmedBody.toLowerCase(),
      kind: kind,
      status: NoteStatus.active,
      isPrivate: isPrivate,
      isPinned: isPinned,
      dayKey: currentDayKey,
      sourceModule: sourceModule,
      sourceEntityId: sourceEntityId,
      captureContextJson: captureContext.toJson(),
      wordCount: wordCount,
      createdAt: DateTime.fromMillisecondsSinceEpoch(nowMs),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(nowMs),
    );

    await db.insert('notes', note.toMap());

    // Auto-link if captureContext has activeSession
    if (captureContext.activeSession != null) {
      final actMod = captureContext.activeSession!['module'] as String?;
      final actEnt = captureContext.activeSession!['entityId'] as String?;
      if (actMod != null && actEnt != null && actEnt.isNotEmpty) {
        await addLink(
          noteId: id,
          linkModule: actMod,
          linkEntityId: actEnt,
          relation: 'ABOUT',
        );
      }
    }

    // Explicit link if provided
    if (linkModule != null && linkEntityId != null) {
      await addLink(
        noteId: id,
        linkModule: linkModule,
        linkEntityId: linkEntityId,
        relation: 'MENTIONS',
      );
    }

    // Set initial tags if provided
    if (tags != null && tags.isNotEmpty) {
      await setTags(id, tags);
    }

    await NoteFtsEngine.instance.indexNote(note);
    return note;
  }

  Future<Note?> getById(String id) async {
    final db = await _db;
    final rows = await db.query('notes', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return Note.fromMap(rows.first);
  }

  Future<void> update(Note note, {String? reason}) async {
    final db = await _db;
    final nowMs = SystemClock().now().millisecondsSinceEpoch;
    final existing = await getById(note.id);

    final trimmedBody = note.body.trim();
    final derivedTitle = note.title?.trim().isNotEmpty == true
        ? note.title!.trim()
        : (trimmedBody.length > 40 ? '${trimmedBody.substring(0, 40)}...' : trimmedBody);

    if (existing != null) {
      // Save revision if body or title changed meaningfully or reason is explicitly provided
      final bodyChanged = existing.body != trimmedBody;
      final titleChanged = (existing.title ?? '') != derivedTitle;
      final timeDiffMin = (nowMs - existing.updatedAt.millisecondsSinceEpoch) / 60000;

      if ((bodyChanged && (timeDiffMin > 2 || reason != null)) || (titleChanged && timeDiffMin > 2) || reason == 'AI_EDIT') {
        await db.insert('note_revisions', {
          'id': 'rev_${_uuid.v4()}',
          'noteId': note.id,
          'body': existing.body,
          'wordCount': existing.wordCount,
          'reason': reason ?? 'AUTOSAVE',
          'createdAt': existing.updatedAt.millisecondsSinceEpoch,
        });
      }
    }

    final wordCount = trimmedBody.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    final updatedNote = note.copyWith(
      title: derivedTitle,
      body: trimmedBody,
      wordCount: wordCount,
      titleNormalized: derivedTitle.toLowerCase(),
      bodyNormalized: trimmedBody.toLowerCase(),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(nowMs),
    );

    await db.update(
      'notes',
      updatedNote.toMap(),
      where: 'id = ?',
      whereArgs: [note.id],
    );

    await NoteFtsEngine.instance.indexNote(updatedNote);
  }

  Future<void> delete(String noteId) async {
    final db = await _db;
    final nowMs = SystemClock().now().millisecondsSinceEpoch;
    await db.update(
      'notes',
      {
        'status': 'TRASHED',
        'trashedAt': nowMs,
        'updatedAt': nowMs,
      },
      where: 'id = ?',
      whereArgs: [noteId],
    );

    await NoteFtsEngine.instance.deleteFromIndex(noteId);
  }

  Future<void> restore(String noteId) async {
    final db = await _db;
    final nowMs = SystemClock().now().millisecondsSinceEpoch;
    await db.update(
      'notes',
      {
        'status': 'ACTIVE',
        'trashedAt': null,
        'updatedAt': nowMs,
      },
      where: 'id = ?',
      whereArgs: [noteId],
    );

    final note = await getById(noteId);
    if (note != null) {
      await NoteFtsEngine.instance.indexNote(note);
    }
  }

  Future<void> permanentDelete(String noteId) async {
    final db = await _db;
    await NoteAttachmentRepository.instance.removeAllForNote(noteId);
    await NoteFtsEngine.instance.deleteFromIndex(noteId);
    await db.delete('notes', where: 'id = ?', whereArgs: [noteId]);
  }

  Future<void> purge({int daysOld = 30}) async {
    final db = await _db;
    final thresholdMs = SystemClock().now().subtract(Duration(days: daysOld)).millisecondsSinceEpoch;
    
    final toPurge = await db.query(
      'notes',
      columns: ['id'],
      where: 'status = ? AND trashedAt IS NOT NULL AND trashedAt <= ?',
      whereArgs: ['TRASHED', thresholdMs],
    );

    for (final row in toPurge) {
      final id = row['id'] as String;
      await NoteAttachmentRepository.instance.removeAllForNote(id);
      await NoteFtsEngine.instance.deleteFromIndex(id);
    }

    await db.delete(
      'notes',
      where: 'status = ? AND trashedAt IS NOT NULL AND trashedAt <= ?',
      whereArgs: ['TRASHED', thresholdMs],
    );
  }

  Future<void> archive(String noteId) async {
    final db = await _db;
    final nowMs = SystemClock().now().millisecondsSinceEpoch;
    await db.update('notes', {'status': 'ARCHIVED', 'updatedAt': nowMs}, where: 'id = ?', whereArgs: [noteId]);
  }

  Future<void> unarchive(String noteId) async {
    final db = await _db;
    final nowMs = SystemClock().now().millisecondsSinceEpoch;
    await db.update('notes', {'status': 'ACTIVE', 'updatedAt': nowMs}, where: 'id = ?', whereArgs: [noteId]);
    final note = await getById(noteId);
    if (note != null) {
      await NoteFtsEngine.instance.indexNote(note);
    }
  }

  Future<void> pin(String noteId) async {
    final db = await _db;
    await db.update('notes', {'isPinned': 1}, where: 'id = ?', whereArgs: [noteId]);
  }

  Future<void> unpin(String noteId) async {
    final db = await _db;
    await db.update('notes', {'isPinned': 0}, where: 'id = ?', whereArgs: [noteId]);
  }

  /// Records that the note was opened/read without tampering with `updatedAt`.
  Future<void> markOpened(String noteId) async {
    final db = await _db;
    final nowMs = SystemClock().now().millisecondsSinceEpoch;
    await db.rawUpdate('''
      UPDATE notes
      SET openCount = openCount + 1, openedAt = ?
      WHERE id = ?
    ''', [nowMs, noteId]);
  }

  Future<List<Note>> listRecent({int limit = 30, int offset = 0}) async {
    final db = await _db;
    final rows = await db.query(
      'notes',
      where: 'status = ?',
      whereArgs: ['ACTIVE'],
      orderBy: 'isPinned DESC, updatedAt DESC',
      limit: limit,
      offset: offset,
    );
    return rows.map((r) => Note.fromMap(r)).toList();
  }

  Future<List<Note>> listPinned() async {
    final db = await _db;
    final rows = await db.query(
      'notes',
      where: 'status = ? AND isPinned = 1',
      whereArgs: ['ACTIVE'],
      orderBy: 'updatedAt DESC',
    );
    return rows.map((r) => Note.fromMap(r)).toList();
  }

  Future<List<Note>> listByKind(NoteKind kind) async {
    final db = await _db;
    final rows = await db.query(
      'notes',
      where: 'status = ? AND kind = ?',
      whereArgs: ['ACTIVE', kind.value],
      orderBy: 'updatedAt DESC',
    );
    return rows.map((r) => Note.fromMap(r)).toList();
  }

  Future<List<Note>> listArchived({int limit = 50, int offset = 0}) async {
    final db = await _db;
    final rows = await db.query(
      'notes',
      where: 'status = ?',
      whereArgs: ['ARCHIVED'],
      orderBy: 'updatedAt DESC',
      limit: limit,
      offset: offset,
    );
    return rows.map((r) => Note.fromMap(r)).toList();
  }

  Future<List<Note>> listTrashed({int limit = 50, int offset = 0}) async {
    final db = await _db;
    final rows = await db.query(
      'notes',
      where: 'status = ?',
      whereArgs: ['TRASHED'],
      orderBy: 'trashedAt DESC, updatedAt DESC',
      limit: limit,
      offset: offset,
    );
    return rows.map((r) => Note.fromMap(r)).toList();
  }

  Future<List<Note>> listByDay(String dayKey) async {
    final db = await _db;
    final rows = await db.query(
      'notes',
      where: 'status = ? AND dayKey = ?',
      whereArgs: ['ACTIVE', dayKey],
      orderBy: 'createdAt DESC',
    );
    return rows.map((r) => Note.fromMap(r)).toList();
  }

  Future<List<Note>> listByTag(String tagNormalized) async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT n.* FROM notes n
      INNER JOIN note_tags t ON n.id = t.noteId
      WHERE n.status = 'ACTIVE' AND t.tagNormalized = ?
      ORDER BY n.updatedAt DESC
    ''', [tagNormalized.toLowerCase()]);
    return rows.map((r) => Note.fromMap(r)).toList();
  }

  Future<List<NoteLink>> listBacklinks(String module, String entityId) async {
    final db = await _db;
    final rows = await db.query(
      'note_links',
      where: 'linkModule = ? AND linkEntityId = ?',
      whereArgs: [module, entityId],
      orderBy: 'createdAt DESC',
    );
    return rows.map((r) => NoteLink.fromMap(r)).toList();
  }

  Future<List<Note>> listOrphans({int minDays = 60}) async {
    final db = await _db;
    final thresholdMs = SystemClock().now().subtract(Duration(days: minDays)).millisecondsSinceEpoch;
    final rows = await db.rawQuery('''
      SELECT n.* FROM notes n
      LEFT JOIN note_links l ON n.id = l.noteId
      WHERE n.status = 'ACTIVE'
        AND n.openCount = 0
        AND n.createdAt <= ?
        AND l.id IS NULL
      ORDER BY n.createdAt DESC
    ''', [thresholdMs]);
    return rows.map((r) => Note.fromMap(r)).toList();
  }

  Future<List<Note>> listReviewDue(int nowMs) async {
    final db = await _db;
    final rows = await db.query(
      'notes',
      where: 'status = ? AND reviewAt IS NOT NULL AND reviewAt <= ?',
      whereArgs: ['ACTIVE', nowMs],
      orderBy: 'reviewAt ASC',
    );
    return rows.map((r) => Note.fromMap(r)).toList();
  }

  Future<void> setReview(String noteId, int stage, int? reviewAtMs) async {
    final db = await _db;
    await db.update(
      'notes',
      {
        'reviewStage': stage,
        'reviewAt': reviewAtMs,
        'updatedAt': SystemClock().now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [noteId],
    );
  }

  Future<void> addTag(String noteId, String tag, {String source = 'USER'}) async {
    final db = await _db;
    final norm = tag.trim().toLowerCase();
    if (norm.isEmpty) return;
    await db.insert(
      'note_tags',
      {
        'noteId': noteId,
        'tag': tag.trim(),
        'tagNormalized': norm,
        'source': source,
        'createdAt': SystemClock().now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );

    final note = await getById(noteId);
    if (note != null) {
      await NoteFtsEngine.instance.indexNote(note);
    }
  }

  Future<void> removeTag(String noteId, String tagNormalized) async {
    final db = await _db;
    await db.delete(
      'note_tags',
      where: 'noteId = ? AND tagNormalized = ?',
      whereArgs: [noteId, tagNormalized.toLowerCase()],
    );

    final note = await getById(noteId);
    if (note != null) {
      await NoteFtsEngine.instance.indexNote(note);
    }
  }

  Future<void> setTags(String noteId, List<String> tags, {String source = 'USER'}) async {
    final db = await _db;
    await db.delete('note_tags', where: 'noteId = ?', whereArgs: [noteId]);
    for (final t in tags) {
      final norm = t.trim().toLowerCase();
      if (norm.isNotEmpty) {
        await db.insert(
          'note_tags',
          {
            'noteId': noteId,
            'tag': t.trim(),
            'tagNormalized': norm,
            'source': source,
            'createdAt': SystemClock().now().millisecondsSinceEpoch,
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    }

    final note = await getById(noteId);
    if (note != null) {
      await NoteFtsEngine.instance.indexNote(note);
    }
  }

  Future<List<NoteRevision>> listRevisions(String noteId) async {
    final db = await _db;
    final rows = await db.query(
      'note_revisions',
      where: 'noteId = ?',
      whereArgs: [noteId],
      orderBy: 'createdAt DESC',
    );
    return rows.map((r) => NoteRevision.fromMap(r)).toList();
  }

  Future<void> addLink({
    required String noteId,
    required String linkModule,
    required String linkEntityId,
    String? linkAction,
    String relation = 'MENTIONS',
  }) async {
    final db = await _db;
    await db.insert(
      'note_links',
      {
        'id': 'link_${_uuid.v4()}',
        'noteId': noteId,
        'linkModule': linkModule,
        'linkEntityId': linkEntityId,
        'linkAction': linkAction,
        'relation': relation,
        'createdAt': SystemClock().now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> removeLink(String linkId) async {
    final db = await _db;
    await db.delete('note_links', where: 'id = ?', whereArgs: [linkId]);
  }

  Future<List<NoteLink>> listLinks(String noteId) async {
    final db = await _db;
    final rows = await db.query('note_links', where: 'noteId = ?', whereArgs: [noteId]);
    return rows.map((r) => NoteLink.fromMap(r)).toList();
  }

  Future<Map<String, int>> counts() async {
    final db = await _db;
    final active = Sqflite.firstIntValue(await db.rawQuery("SELECT COUNT(*) FROM notes WHERE status = 'ACTIVE'")) ?? 0;
    final archived = Sqflite.firstIntValue(await db.rawQuery("SELECT COUNT(*) FROM notes WHERE status = 'ARCHIVED'")) ?? 0;
    final trashed = Sqflite.firstIntValue(await db.rawQuery("SELECT COUNT(*) FROM notes WHERE status = 'TRASHED'")) ?? 0;
    final exp = Sqflite.firstIntValue(await db.rawQuery("SELECT COUNT(*) FROM notes WHERE kind = 'EXPERIENCE' AND status = 'ACTIVE'")) ?? 0;
    return {
      'active': active,
      'archived': archived,
      'trashed': trashed,
      'experiences': exp,
    };
  }
}
