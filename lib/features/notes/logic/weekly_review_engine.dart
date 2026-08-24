import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/time/ritmo_clock.dart';
import 'package:ritmo/features/notes/data/notes_repository.dart';
import 'package:sqflite/sqflite.dart';

class WeeklyReviewStats {
  final int notesCreatedCount;
  final int experiencesAddedCount;
  final int wordCountSum;
  final List<String> topTags;
  final int orphansCount;

  const WeeklyReviewStats({
    required this.notesCreatedCount,
    required this.experiencesAddedCount,
    required this.wordCountSum,
    required this.topTags,
    required this.orphansCount,
  });
}

class WeeklyReviewEngine {
  WeeklyReviewEngine._();
  static final WeeklyReviewEngine instance = WeeklyReviewEngine._();

  Future<Database> get _db async => DatabaseHelper.instance.database;

  Future<WeeklyReviewStats> generateWeeklyStats() async {
    final db = await _db;
    final thresholdMs = SystemClock()
        .now()
        .subtract(const Duration(days: 7))
        .millisecondsSinceEpoch;

    final createdRows = await db.rawQuery(
      "SELECT COUNT(*), SUM(wordCount) FROM notes WHERE status = 'ACTIVE' AND createdAt >= ?",
      [thresholdMs],
    );
    final notesCreatedCount = Sqflite.firstIntValue(createdRows) ?? 0;
    final wordCountSum =
        (createdRows.first['SUM(wordCount)'] as num?)?.toInt() ?? 0;

    final expCount =
        Sqflite.firstIntValue(
          await db.rawQuery(
            "SELECT COUNT(*) FROM notes WHERE status = 'ACTIVE' AND kind = 'EXPERIENCE' AND createdAt >= ?",
            [thresholdMs],
          ),
        ) ??
        0;

    final tagRows = await db.rawQuery(
      '''
      SELECT t.tag, COUNT(*) as cnt FROM note_tags t
      INNER JOIN notes n ON t.noteId = n.id
      WHERE n.createdAt >= ?
      GROUP BY t.tagNormalized
      ORDER BY cnt DESC
      LIMIT 5
    ''',
      [thresholdMs],
    );
    final topTags = tagRows.map((r) => r['tag'] as String).toList();

    final orphans = await NotesRepository.instance.listOrphans(minDays: 30);

    return WeeklyReviewStats(
      notesCreatedCount: notesCreatedCount,
      experiencesAddedCount: expCount,
      wordCountSum: wordCountSum,
      topTags: topTags,
      orphansCount: orphans.length,
    );
  }
}
