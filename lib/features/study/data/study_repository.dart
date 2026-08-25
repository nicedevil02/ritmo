import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/domain/engines/ritmo_event_bus.dart';
import 'package:ritmo/core/util/ritmo_date.dart';
import 'package:ritmo/features/study/domain/study_models.dart';
import 'package:ritmo/features/study/domain/study_validation.dart';
import 'package:sqflite/sqflite.dart';

class SubjectStats {
  const SubjectStats({
    required this.subjectId,
    required this.totalMinutes,
    required this.sessionCount,
    this.lastStudiedDateIso,
  });

  final String subjectId;
  final int totalMinutes;
  final int sessionCount;
  final String? lastStudiedDateIso;
}

class StudyRepository {
  StudyRepository({DatabaseHelper? dbHelper, RitmoEventBus? eventBus})
      : _dbHelper = dbHelper ?? DatabaseHelper.instance,
        _eventBus = eventBus ?? RitmoEventBus();

  static final StudyRepository instance = StudyRepository();

  final DatabaseHelper _dbHelper;
  final RitmoEventBus _eventBus;

  Future<Database> get _database async => _dbHelper.database;

  Future<List<StudySubject>> getSubjects({bool isKonkurMode = false}) async {
    final db = await _database;
    final whereStr = isKonkurMode
        ? 'isArchived = 0'
        : "isArchived = 0 AND (origin = 'USER' OR origin IS NULL)";
    final rows = await db.query('konkur_subjects', where: whereStr, orderBy: 'orderIndex ASC');
    return rows.map(StudySubject.fromMap).toList();
  }

  Future<StudySubject?> getSubjectById(String id) async {
    final db = await _database;
    final rows = await db.query('konkur_subjects', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return StudySubject.fromMap(rows.first);
  }

  Future<void> saveSubject(StudySubject subject) async {
    StudyValidator.validateSubject(subject);
    final db = await _database;
    await db.insert('konkur_subjects', subject.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteSubject(String id) async {
    final db = await _database;
    await db.transaction((txn) async {
      await txn.delete('konkur_subjects', where: 'id = ?', whereArgs: [id]);
      await txn.delete('konkur_topics', where: 'subjectId = ?', whereArgs: [id]);
      await txn.delete('konkur_study_sessions', where: 'subjectId = ?', whereArgs: [id]);
      await txn.delete('study_active_session', where: 'subjectId = ?', whereArgs: [id]);
    });
  }

  Future<List<StudyTopic>> getTopics({String? subjectId, bool isKonkurMode = false}) async {
    final db = await _database;
    String whereStr = isKonkurMode
        ? 'subjectId IN (SELECT id FROM konkur_subjects WHERE isArchived = 0)'
        : "(origin = 'USER' OR origin IS NULL) AND subjectId IN (SELECT id FROM konkur_subjects WHERE isArchived = 0)";
    final args = <dynamic>[];
    if (subjectId != null) {
      whereStr += ' AND subjectId = ?';
      args.add(subjectId);
    }
    final rows = await db.query('konkur_topics', where: whereStr, whereArgs: args, orderBy: 'orderIndex ASC');
    return rows.map(StudyTopic.fromMap).toList();
  }

  Future<StudyTopic?> getTopicById(String id) async {
    final db = await _database;
    final rows = await db.query('konkur_topics', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return StudyTopic.fromMap(rows.first);
  }

  Future<void> saveTopic(StudyTopic topic) async {
    StudyValidator.validateTopic(topic);
    final db = await _database;
    await db.insert('konkur_topics', topic.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> saveTopicsBulk(List<StudyTopic> topics) async {
    for (final topic in topics) {
      StudyValidator.validateTopic(topic);
    }
    final db = await _database;
    await db.transaction((txn) async {
      for (final topic in topics) {
        await txn.insert('konkur_topics', topic.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<void> deleteTopic(String id) async {
    final db = await _database;
    await db.transaction((txn) async {
      await txn.delete('konkur_topics', where: 'id = ?', whereArgs: [id]);
      await txn.update('konkur_study_sessions', {'topicId': null}, where: 'topicId = ?', whereArgs: [id]);
      await txn.update('study_active_session', {'topicId': null}, where: 'topicId = ?', whereArgs: [id]);
    });
  }

  Future<List<StudySession>> getSessions({
    String? dateIso,
    String? startDateIso,
    String? endDateIso,
    String? subjectId,
    String? topicId,
    int? limit,
  }) async {
    final db = await _database;
    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];

    if (dateIso != null && dateIso.isNotEmpty) {
      whereClauses.add('dateIso = ?');
      whereArgs.add(dateIso);
    }
    if (startDateIso != null && startDateIso.isNotEmpty) {
      whereClauses.add('dateIso >= ?');
      whereArgs.add(startDateIso);
    }
    if (endDateIso != null && endDateIso.isNotEmpty) {
      whereClauses.add('dateIso <= ?');
      whereArgs.add(endDateIso);
    }
    if (subjectId != null && subjectId.isNotEmpty) {
      whereClauses.add('subjectId = ?');
      whereArgs.add(subjectId);
    }
    if (topicId != null && topicId.isNotEmpty) {
      whereClauses.add('topicId = ?');
      whereArgs.add(topicId);
    }

    final whereStr = whereClauses.isNotEmpty ? whereClauses.join(' AND ') : null;
    final rows = await db.query(
      'konkur_study_sessions',
      where: whereStr,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'createdAt DESC',
      limit: limit,
    );
    return rows.map(StudySession.fromMap).toList();
  }

  Future<void> recordSession(
    StudySession session, {
    StudyMastery? newMastery,
    String? nextReviewDateIso,
    int? newReviewCount,
  }) async {
    StudyValidator.validateSession(session);
    final db = await _database;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final sessionEndMs = session.endedAtMs ??
        (RitmoDate.tryParseDayKey(session.dateIso)?.millisecondsSinceEpoch ?? nowMs);

    await db.transaction((txn) async {
      await txn.insert('konkur_study_sessions', session.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);

      if (session.topicId != null && session.topicId!.isNotEmpty) {
        final topicRows = await txn.query('konkur_topics', where: 'id = ?', whereArgs: [session.topicId]);
        if (topicRows.isNotEmpty) {
          final oldTopic = StudyTopic.fromMap(topicRows.first);
          final updatedMinutes = oldTopic.studyCompletedMinutes + session.durationMinutes;

          final effectiveLastStudiedAt = (oldTopic.lastStudiedAtMs == null || sessionEndMs > oldTopic.lastStudiedAtMs!)
              ? sessionEndMs
              : oldTopic.lastStudiedAtMs;

          final mStr = (newMastery ?? oldTopic.mastery).dbValue;
          final resolvedReviewCount = newReviewCount ?? oldTopic.reviewCount;

          final updateMap = <String, dynamic>{
            'studyCompletedMinutes': updatedMinutes,
            'lastStudiedAt': effectiveLastStudiedAt,
            'masteryLevel': mStr,
            'reviewCount': resolvedReviewCount,
            'updatedAt': nowMs,
          };
          if (nextReviewDateIso != null) {
            updateMap['nextReviewDate'] = nextReviewDateIso;
          }

          await txn.update('konkur_topics', updateMap, where: 'id = ?', whereArgs: [session.topicId]);
        }
      }
    });

    _eventBus.fire(RitmoEvent(
      type: RitmoEventType.completionRecorded.code,
      timestamp: DateTime.now(),
      payload: {
        'domain': 'study_session',
        'sessionId': session.id,
        'subjectId': session.subjectId,
        'topicId': session.topicId,
        'durationMinutes': session.durationMinutes,
        'dateIso': session.dateIso,
      },
    ));
  }

  Future<Map<String, SubjectStats>> getAggregatedSubjectStats({String? sinceDateIso}) async {
    final db = await _database;
    String sql = '''
      SELECT subjectId,
             SUM(durationMinutes) AS totalMinutes,
             COUNT(*)             AS sessionCount,
             MAX(dateIso)         AS lastStudiedDate
      FROM konkur_study_sessions
    ''';
    final args = <dynamic>[];
    if (sinceDateIso != null) {
      sql += ' WHERE dateIso >= ?';
      args.add(sinceDateIso);
    }
    sql += ' GROUP BY subjectId';

    final rows = await db.rawQuery(sql, args);
    final map = <String, SubjectStats>{};
    for (final r in rows) {
      final sId = r['subjectId'] as String? ?? '';
      if (sId.isEmpty) continue;
      map[sId] = SubjectStats(
        subjectId: sId,
        totalMinutes: (r['totalMinutes'] as num?)?.toInt() ?? 0,
        sessionCount: (r['sessionCount'] as num?)?.toInt() ?? 0,
        lastStudiedDateIso: r['lastStudiedDate'] as String?,
      );
    }
    return map;
  }
}
