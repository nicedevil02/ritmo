import 'package:ritmo/core/database/database_helper.dart';
import 'package:sqflite/sqflite.dart';

class BridgedNote {
  final String id;
  final String text;
  final DateTime createdAt;
  final String? sourceModule;
  final String? sourceEntityId;
  final bool isPromoted;
  final String? title;

  const BridgedNote({
    required this.id,
    required this.text,
    required this.createdAt,
    this.sourceModule,
    this.sourceEntityId,
    this.isPromoted = false,
    this.title,
  });
}

/// Bridge to read both native module note columns and promoted/linked notes in unified format (M-12).
class NoteBridge {
  NoteBridge._();
  static final NoteBridge instance = NoteBridge._();

  Future<Database> get _db async => DatabaseHelper.instance.database;

  /// Fetches notes for a given module entity (both native notes and promoted notes).
  Future<List<BridgedNote>> forEntity({
    required String module,
    required String entityId,
  }) async {
    final db = await _db;
    final list = <BridgedNote>[];

    // 1. Check promoted notes from `notes` table if table exists
    try {
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='notes';",
      );
      if (tables.isNotEmpty) {
        final rows = await db.query(
          'notes',
          where: 'sourceModule = ? AND sourceEntityId = ? AND status = ?',
          whereArgs: [module, entityId, 'ACTIVE'],
          orderBy: 'createdAt DESC',
        );
        for (final r in rows) {
          final body = (r['body'] as String?) ?? '';
          if (body.trim().isNotEmpty) {
            list.add(
              BridgedNote(
                id: r['id'] as String,
                text: body,
                createdAt: DateTime.fromMillisecondsSinceEpoch(
                  r['createdAt'] as int,
                ),
                sourceModule: module,
                sourceEntityId: entityId,
                isPromoted: true,
                title: r['title'] as String?,
              ),
            );
          }
        }
      }
    } catch (_) {}

    // 2. Check native module tables for module-specific notes
    try {
      if (module == 'study') {
        final rows = await db.query(
          'konkur_study_sessions',
          where:
              'subjectId = ? AND note IS NOT NULL AND note != "" AND note NOT LIKE "ثبت خودکار%"',
          whereArgs: [entityId],
          orderBy: 'createdAt DESC',
        );
        for (final r in rows) {
          final note = r['note'] as String;
          if (note.trim().isNotEmpty) {
            list.add(
              BridgedNote(
                id: r['id'] as String,
                text: note,
                createdAt: DateTime.fromMillisecondsSinceEpoch(
                  r['createdAt'] as int,
                ),
                sourceModule: module,
                sourceEntityId: entityId,
                isPromoted: false,
              ),
            );
          }
        }
      } else if (module == 'routines') {
        final rows = await db.query(
          'routine_completions',
          where: 'routineId = ? AND note IS NOT NULL AND note != ""',
          whereArgs: [entityId],
          orderBy: 'completionTime DESC',
        );
        for (final r in rows) {
          final note = r['note'] as String;
          if (note.trim().isNotEmpty) {
            list.add(
              BridgedNote(
                id: r['id'] as String,
                text: note,
                createdAt: DateTime.fromMillisecondsSinceEpoch(
                  r['completionTime'] as int,
                ),
                sourceModule: module,
                sourceEntityId: entityId,
                isPromoted: false,
              ),
            );
          }
        }
      } else if (module == 'courses') {
        final rows = await db.query(
          'course_sessions',
          where: 'courseId = ? AND note IS NOT NULL AND note != ""',
          whereArgs: [entityId],
          orderBy: 'startTime DESC',
        );
        for (final r in rows) {
          final note = r['note'] as String;
          if (note.trim().isNotEmpty) {
            list.add(
              BridgedNote(
                id: r['id'] as String,
                text: note,
                createdAt: DateTime.fromMillisecondsSinceEpoch(
                  r['startTime'] as int,
                ),
                sourceModule: module,
                sourceEntityId: entityId,
                isPromoted: false,
              ),
            );
          }
        }
      }
    } catch (_) {}

    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  /// Fetches notes for a specific Jalali day key (YYYY-MM-DD format).
  Future<List<BridgedNote>> forDay(String dayKey) async {
    final db = await _db;
    final list = <BridgedNote>[];
    try {
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='notes';",
      );
      if (tables.isNotEmpty) {
        final rows = await db.query(
          'notes',
          where: 'dayKey = ? AND status = ?',
          whereArgs: [dayKey, 'ACTIVE'],
          orderBy: 'createdAt DESC',
        );
        for (final r in rows) {
          final body = (r['body'] as String?) ?? '';
          if (body.trim().isNotEmpty) {
            list.add(
              BridgedNote(
                id: r['id'] as String,
                text: body,
                createdAt: DateTime.fromMillisecondsSinceEpoch(
                  r['createdAt'] as int,
                ),
                sourceModule: r['sourceModule'] as String?,
                sourceEntityId: r['sourceEntityId'] as String?,
                isPromoted: true,
                title: r['title'] as String?,
              ),
            );
          }
        }
      }
    } catch (_) {}
    return list;
  }
}
