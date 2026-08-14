import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/features/notes/data/notes_repository.dart';
import 'package:ritmo/features/notes/domain/note_models.dart';
import 'package:sqflite/sqflite.dart';

class ExperienceRepository {
  ExperienceRepository._();
  static final ExperienceRepository instance = ExperienceRepository._();

  Future<Database> get _db async => DatabaseHelper.instance.database;

  Future<Experience> create({
    required String lesson,
    String? contextText,
    ExperienceCategory category = ExperienceCategory.general,
    int importance = 3,
    String? occurredOnDayKey,
    bool isActive = true,
  }) async {
    final note = await NotesRepository.instance.create(
      title: lesson.length > 40 ? '${lesson.substring(0, 40)}...' : lesson,
      body: contextText ?? lesson,
      kind: NoteKind.experience,
    );

    final exp = Experience(
      noteId: note.id,
      lesson: lesson.trim(),
      contextText: contextText?.trim(),
      category: category,
      importance: importance.clamp(1, 5),
      occurredOnDayKey: occurredOnDayKey,
      isActive: isActive,
    );

    final db = await _db;
    await db.insert(
      'note_experience_meta',
      exp.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    return exp;
  }

  Future<Experience> createMetaForNote({
    required String noteId,
    required String lesson,
    String? contextText,
    ExperienceCategory category = ExperienceCategory.general,
    int importance = 3,
    String? occurredOnDayKey,
    bool isActive = true,
  }) async {
    final exp = Experience(
      noteId: noteId,
      lesson: lesson.trim(),
      contextText: contextText?.trim(),
      category: category,
      importance: importance.clamp(1, 5),
      occurredOnDayKey: occurredOnDayKey,
      isActive: isActive,
    );

    final db = await _db;
    await db.insert(
      'note_experience_meta',
      exp.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    return exp;
  }


  Future<void> deleteByNoteId(String noteId) async {
    final db = await _db;
    await db.delete(
      'note_experience_meta',
      where: 'noteId = ?',
      whereArgs: [noteId],
    );
  }

  Future<Experience?> getByNoteId(String noteId) async {
    final db = await _db;
    final rows = await db.query(
      'note_experience_meta',
      where: 'noteId = ?',
      whereArgs: [noteId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Experience.fromMap(rows.first);
  }

  Future<void> update(Experience experience) async {
    final db = await _db;
    await db.update(
      'note_experience_meta',
      experience.toMap(),
      where: 'noteId = ?',
      whereArgs: [experience.noteId],
    );
  }

  Future<void> setActive(String noteId, bool isActive) async {
    final db = await _db;
    await db.update(
      'note_experience_meta',
      {'isActive': isActive ? 1 : 0},
      where: 'noteId = ?',
      whereArgs: [noteId],
    );
  }

  Future<void> setImportance(String noteId, int importance) async {
    final db = await _db;
    await db.update(
      'note_experience_meta',
      {'importance': importance.clamp(1, 5)},
      where: 'noteId = ?',
      whereArgs: [noteId],
    );
  }

  Future<List<Experience>> listAll() async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT m.* FROM note_experience_meta m
      INNER JOIN notes n ON m.noteId = n.id
      WHERE n.status = 'ACTIVE' AND n.kind = 'EXPERIENCE'
      ORDER BY m.importance DESC, n.createdAt DESC
    ''');
    return rows.map((r) => Experience.fromMap(r)).toList();
  }

  Future<List<Experience>> listActive() async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT m.* FROM note_experience_meta m
      INNER JOIN notes n ON m.noteId = n.id
      WHERE m.isActive = 1 AND n.status = 'ACTIVE' AND n.kind = 'EXPERIENCE'
      ORDER BY m.importance DESC, n.createdAt DESC
    ''');
    return rows.map((r) => Experience.fromMap(r)).toList();
  }

  /// Single-query JOIN to fetch active experiences alongside their full note models (eliminates N+1).
  Future<List<ExperienceWithNote>> listActiveWithNotes() async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT 
        m.noteId, m.lesson, m.contextText AS m_contextText, m.category, m.importance,
        m.occurredOnDayKey, m.isActive, m.showCount, m.lastShownAtDayKey, m.acknowledgedCount,
        n.id, n.title, n.body, n.titleNormalized, n.bodyNormalized, n.kind, n.status,
        n.isPrivate, n.isPinned, n.dayKey, n.sourceModule, n.sourceEntityId,
        n.captureContextJson, n.wordCount, n.createdAt, n.updatedAt,
        n.openedAt, n.openCount, n.reviewAt, n.reviewStage, n.trashedAt
      FROM note_experience_meta m
      INNER JOIN notes n ON m.noteId = n.id
      WHERE m.isActive = 1 AND n.status = 'ACTIVE' AND n.kind = 'EXPERIENCE'
      ORDER BY m.importance DESC, n.createdAt DESC
    ''');

    return rows.map((r) {
      final exp = Experience(
        noteId: r['noteId'] as String,
        lesson: r['lesson'] as String,
        contextText: r['m_contextText'] as String?,
        category: ExperienceCategory.parse(r['category'] as String?),
        importance: (r['importance'] as int?) ?? 3,
        occurredOnDayKey: r['occurredOnDayKey'] as String?,
        isActive: (r['isActive'] as int? ?? 1) == 1,
        showCount: (r['showCount'] as int?) ?? 0,
        lastShownAtDayKey: r['lastShownAtDayKey'] as String?,
        acknowledgedCount: (r['acknowledgedCount'] as int?) ?? 0,
      );

      final note = Note(
        id: r['id'] as String,
        title: r['title'] as String?,
        body: (r['body'] as String?) ?? '',
        titleNormalized: (r['titleNormalized'] as String?) ?? '',
        bodyNormalized: (r['bodyNormalized'] as String?) ?? '',
        kind: NoteKind.parse(r['kind'] as String?),
        status: NoteStatus.parse(r['status'] as String?),
        isPrivate: (r['isPrivate'] as int? ?? 0) == 1,
        isPinned: (r['isPinned'] as int? ?? 0) == 1,
        dayKey: r['dayKey'] as String?,
        sourceModule: r['sourceModule'] as String?,
        sourceEntityId: r['sourceEntityId'] as String?,
        captureContextJson: r['captureContextJson'] as String?,
        wordCount: (r['wordCount'] as int?) ?? 0,
        createdAt: DateTime.fromMillisecondsSinceEpoch(r['createdAt'] as int),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(r['updatedAt'] as int),
        openedAt: r['openedAt'] != null ? DateTime.fromMillisecondsSinceEpoch(r['openedAt'] as int) : null,
        openCount: (r['openCount'] as int?) ?? 0,
        reviewAt: r['reviewAt'] != null ? DateTime.fromMillisecondsSinceEpoch(r['reviewAt'] as int) : null,
        reviewStage: (r['reviewStage'] as int?) ?? 0,
        trashedAt: r['trashedAt'] != null ? DateTime.fromMillisecondsSinceEpoch(r['trashedAt'] as int) : null,
      );

      return ExperienceWithNote(experience: exp, note: note);
    }).toList();
  }

  Future<void> recordShown(String noteId, String dayKey) async {
    final db = await _db;
    final exp = await getByNoteId(noteId);
    if (exp == null) return;
    if (exp.lastShownAtDayKey == dayKey) return; // Record at most once per day

    await db.rawUpdate('''
      UPDATE note_experience_meta
      SET showCount = showCount + 1, lastShownAtDayKey = ?
      WHERE noteId = ?
    ''', [dayKey, noteId]);
  }

  Future<void> recordAcknowledged(String noteId) async {
    final db = await _db;
    await db.rawUpdate('''
      UPDATE note_experience_meta
      SET acknowledgedCount = acknowledgedCount + 1
      WHERE noteId = ?
    ''', [noteId]);
  }

  Future<Map<String, int>> counts() async {
    final db = await _db;
    final total = Sqflite.firstIntValue(await db.rawQuery("SELECT COUNT(*) FROM note_experience_meta")) ?? 0;
    final active = Sqflite.firstIntValue(await db.rawQuery("SELECT COUNT(*) FROM note_experience_meta WHERE isActive = 1")) ?? 0;
    return {'total': total, 'active': active};
  }
}

class ExperienceWithNote {
  final Experience experience;
  final Note note;

  const ExperienceWithNote({
    required this.experience,
    required this.note,
  });
}
