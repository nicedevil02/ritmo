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
    this.totalTests = 0,
    this.totalCorrect = 0,
    this.totalWrong = 0,
  });

  final String subjectId;
  final int totalMinutes;
  final int sessionCount;
  final String? lastStudiedDateIso;
  final int totalTests;
  final int totalCorrect;
  final int totalWrong;

  double get accuracyPercentage =>
      totalTests > 0 ? (totalCorrect / totalTests) * 100.0 : 0.0;
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
        ? "isArchived = 0 AND (origin = 'KONKUR_PRESET' OR origin = 'KONKUR_CUSTOM' OR origin = 'KONKUR' OR isPreset = 1)"
        : "isArchived = 0 AND origin = 'USER' AND (isPreset IS NULL OR isPreset = 0)";
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
      await txn.delete('study_deadlines', where: 'subjectId = ?', whereArgs: [id]);
    });
  }

  Future<List<StudyTopic>> getTopics({String? subjectId, bool isKonkurMode = false}) async {
    final db = await _database;
    String whereStr = isKonkurMode
        ? "subjectId IN (SELECT id FROM konkur_subjects WHERE isArchived = 0 AND (origin = 'KONKUR_PRESET' OR origin = 'KONKUR_CUSTOM' OR origin = 'KONKUR' OR isPreset = 1))"
        : "origin = 'USER' AND subjectId IN (SELECT id FROM konkur_subjects WHERE isArchived = 0 AND origin = 'USER' AND (isPreset IS NULL OR isPreset = 0))";
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
             MAX(dateIso)         AS lastStudiedDate,
             SUM(testsTotal)      AS totalTests,
             SUM(testsCorrect)    AS totalCorrect,
             SUM(testsWrong)      AS totalWrong
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
        totalTests: (r['totalTests'] as num?)?.toInt() ?? 0,
        totalCorrect: (r['totalCorrect'] as num?)?.toInt() ?? 0,
        totalWrong: (r['totalWrong'] as num?)?.toInt() ?? 0,
      );
    }
    return map;
  }

  // --- STUDY DEADLINES & EXAMS CRUD ---

  Future<List<StudyDeadline>> getDeadlines({
    String? subjectId,
    bool includeCompleted = false,
  }) async {
    final db = await _database;
    final whereClauses = <String>[];
    final args = <dynamic>[];

    if (!includeCompleted) {
      whereClauses.add('isCompleted = 0');
    }
    if (subjectId != null) {
      whereClauses.add('subjectId = ?');
      args.add(subjectId);
    }

    final whereStr = whereClauses.isNotEmpty ? whereClauses.join(' AND ') : null;
    final rows = await db.query(
      'study_deadlines',
      where: whereStr,
      whereArgs: args.isNotEmpty ? args : null,
      orderBy: "dueDateIso ASC, CASE priority WHEN 'HIGH' THEN 1 WHEN 'MEDIUM' THEN 2 WHEN 'LOW' THEN 3 ELSE 4 END ASC",
    );
    return rows.map(StudyDeadline.fromMap).toList();
  }

  Future<List<StudyDeadline>> getUpcomingDeadlines({int daysLimit = 14}) async {
    final db = await _database;
    final today = DateTime.now();
    final todayIso = RitmoDate.dayKey(today);
    final limitDate = today.add(Duration(days: daysLimit));
    final limitIso = RitmoDate.dayKey(limitDate);

    final rows = await db.query(
      'study_deadlines',
      where: 'isCompleted = 0 AND dueDateIso >= ? AND dueDateIso <= ?',
      whereArgs: [todayIso, limitIso],
      orderBy: "dueDateIso ASC, CASE priority WHEN 'HIGH' THEN 1 WHEN 'MEDIUM' THEN 2 WHEN 'LOW' THEN 3 ELSE 4 END ASC",
    );
    return rows.map(StudyDeadline.fromMap).toList();
  }

  Future<void> saveDeadline(StudyDeadline deadline) async {
    final db = await _database;
    await db.insert(
      'study_deadlines',
      deadline.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> toggleDeadlineCompleted(String id, bool isCompleted) async {
    final db = await _database;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    await db.update(
      'study_deadlines',
      {
        'isCompleted': isCompleted ? 1 : 0,
        'updatedAt': nowMs,
      },
      where: 'id = ?',
      whereArgs: [id],
    );

    if (isCompleted) {
      _eventBus.fire(RitmoEvent(
        type: RitmoEventType.completionRecorded.code,
        timestamp: DateTime.now(),
        payload: {
          'domain': 'study_deadline',
          'deadlineId': id,
          'action': 'complete',
        },
      ));
    }
  }

  Future<void> deleteDeadline(String id) async {
    final db = await _database;
    await db.delete('study_deadlines', where: 'id = ?', whereArgs: [id]);
  }
}
