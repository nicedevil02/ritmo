import 'package:flutter/foundation.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/domain/engines/ritmo_engine_bus.dart';
import 'package:ritmo/core/time/ritmo_clock.dart';
import 'package:sqflite/sqflite.dart';

class NotesEngineInput {
  final DateTime? now;
  final String? dayKey;

  const NotesEngineInput({
    this.now,
    this.dayKey,
  });

  @override
  String toString() => 'NotesEngineInput(dayKey: $dayKey, now: $now)';
}

class NotesEngineOutput {
  final int totalActive;
  final int createdThisWeek;
  final int writingDayStreak;
  final List<String> topTags;
  final int orphanCount;
  final int reviewDueCount;
  final int experienceCount;
  final int experienceActiveCount;
  final String? resurfacedToday;
  final double avgWordCount;
  final int sampleSize;
  final String confidence;

  const NotesEngineOutput({
    this.totalActive = 0,
    this.createdThisWeek = 0,
    this.writingDayStreak = 0,
    this.topTags = const [],
    this.orphanCount = 0,
    this.reviewDueCount = 0,
    this.experienceCount = 0,
    this.experienceActiveCount = 0,
    this.resurfacedToday,
    this.avgWordCount = 0.0,
    this.sampleSize = 0,
    this.confidence = 'LOW',
  });

  Map<String, dynamic> toMap() => {
    'totalActive': totalActive,
    'createdThisWeek': createdThisWeek,
    'writingDayStreak': writingDayStreak,
    'topTags': topTags,
    'orphanCount': orphanCount,
    'reviewDueCount': reviewDueCount,
    'experienceCount': experienceCount,
    'experienceActiveCount': experienceActiveCount,
    'resurfacedToday': resurfacedToday,
    'avgWordCount': avgWordCount,
    'sampleSize': sampleSize,
    'confidence': confidence,
  };
}

class NotesEngine extends CachedEngine<NotesEngineInput, NotesEngineOutput> {
  Future<Database> get _db async => DatabaseHelper.instance.database;

  @override
  Duration get ttl => const Duration(minutes: 10);

  @override
  String fingerprint(NotesEngineInput input) {
    final day = input.dayKey ?? SystemClock().today().value;
    return 'notes_engine_$day';
  }

  @override
  void invalidate() {}

  @override
  bool canRun(NotesEngineInput input) => true;

  @override
  List<Type> dependencies() => [];

  @override
  Future<NotesEngineOutput> calculate(NotesEngineInput input) async {
    try {
      final db = await _db;

      // 1. Check if notes table exists
      final tableCheck = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='notes';");
      if (tableCheck.isEmpty) {
        return const NotesEngineOutput();
      }

      final now = input.now ?? DateTime.now();
      final nowMs = now.millisecondsSinceEpoch;

      // Active notes count
      final activeNotesResult = await db.rawQuery("SELECT COUNT(*) as count, AVG(wordCount) as avgWords FROM notes WHERE status = 'ACTIVE'");
      final totalActive = Sqflite.firstIntValue(activeNotesResult) ?? 0;
      final avgWordCount = (activeNotesResult.first['avgWords'] as num?)?.toDouble() ?? 0.0;

      // Created this week (last 7 days)
      final sevenDaysAgoMs = nowMs - (7 * 24 * 60 * 60 * 1000);
      final thisWeekResult = await db.rawQuery(
        "SELECT COUNT(*) FROM notes WHERE status = 'ACTIVE' AND createdAt >= ?",
        [sevenDaysAgoMs],
      );
      final createdThisWeek = Sqflite.firstIntValue(thisWeekResult) ?? 0;

      // Top tags (top 5 by usage count)
      final topTagsResult = await db.rawQuery('''
        SELECT tag, COUNT(*) as cnt 
        FROM note_tags 
        GROUP BY tagNormalized 
        ORDER BY cnt DESC 
        LIMIT 5
      ''');
      final topTags = topTagsResult.map((r) => r['tag'] as String).toList();

      // Orphan notes: active notes with openCount = 0 and created > 60 days ago with 0 links
      final sixtyDaysAgoMs = nowMs - (60 * 24 * 60 * 60 * 1000);
      final orphanResult = await db.rawQuery('''
        SELECT COUNT(*) 
        FROM notes n 
        WHERE n.status = 'ACTIVE' 
          AND n.openCount = 0 
          AND n.createdAt <= ? 
          AND NOT EXISTS (SELECT 1 FROM note_links nl WHERE nl.noteId = n.id)
      ''', [sixtyDaysAgoMs]);
      final orphanCount = Sqflite.firstIntValue(orphanResult) ?? 0;

      // Review due count
      final reviewDueResult = await db.rawQuery(
        "SELECT COUNT(*) FROM notes WHERE status = 'ACTIVE' AND reviewAt IS NOT NULL AND reviewAt <= ?",
        [nowMs],
      );
      final reviewDueCount = Sqflite.firstIntValue(reviewDueResult) ?? 0;

      // Experience stats
      final expTotalResult = await db.rawQuery("SELECT COUNT(*) FROM note_experience_meta");
      final experienceCount = Sqflite.firstIntValue(expTotalResult) ?? 0;

      final expActiveResult = await db.rawQuery("SELECT COUNT(*) FROM note_experience_meta WHERE isActive = 1");
      final experienceActiveCount = Sqflite.firstIntValue(expActiveResult) ?? 0;

      // Resurfaced note for today if any
      final resurfacedResult = await db.rawQuery('''
        SELECT title, body FROM notes 
        WHERE status = 'ACTIVE' 
          AND isPrivate = 0 
          AND (sourceModule IS NULL OR sourceModule != 'cycle') 
        ORDER BY openCount DESC, createdAt ASC 
        LIMIT 1
      ''');
      String? resurfacedToday;
      if (resurfacedResult.isNotEmpty) {
        final title = resurfacedResult.first['title'] as String?;
        final body = resurfacedResult.first['body'] as String?;
        resurfacedToday = (title != null && title.isNotEmpty) ? title : (body != null && body.length > 30 ? '${body.substring(0, 30)}...' : body);
      }

      // Writing streak (distinct dayKeys)
      final daysResult = await db.rawQuery('''
        SELECT DISTINCT dayKey FROM notes 
        WHERE status = 'ACTIVE' AND dayKey IS NOT NULL AND dayKey != '' 
        ORDER BY dayKey DESC 
        LIMIT 30
      ''');
      int streak = 0;
      if (daysResult.isNotEmpty) {
        streak = daysResult.length > 7 ? 7 : daysResult.length;
      }

      final confidence = totalActive >= 20
          ? 'HIGH'
          : (totalActive >= 5 ? 'MEDIUM' : 'LOW');

      return NotesEngineOutput(
        totalActive: totalActive,
        createdThisWeek: createdThisWeek,
        writingDayStreak: streak,
        topTags: topTags,
        orphanCount: orphanCount,
        reviewDueCount: reviewDueCount,
        experienceCount: experienceCount,
        experienceActiveCount: experienceActiveCount,
        resurfacedToday: resurfacedToday,
        avgWordCount: avgWordCount,
        sampleSize: totalActive,
        confidence: confidence,
      );
    } catch (e) {
      debugPrint('[NotesEngine] Error computing analytics: $e');
      return const NotesEngineOutput();
    }
  }
}
