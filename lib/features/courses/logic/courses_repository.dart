import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/database/upsert_helper.dart';
import 'package:ritmo/core/di/service_locator.dart';
import 'package:ritmo/core/domain/engines/ritmo_event_bus.dart';
import 'package:ritmo/core/observability/ritmo_logger.dart';
import 'package:ritmo/core/notifications/notification_channel.dart';
import 'package:ritmo/core/notifications/notification_gateway.dart';
import 'package:ritmo/core/notifications/notification_request.dart';
import 'package:ritmo/core/platform/alarm_platform.dart';
import 'package:ritmo/core/services/snapshot_sync_service.dart';
import 'package:ritmo/features/courses/logic/course_date_contract.dart';
import 'package:ritmo/features/courses/logic/course_scheduler.dart';
import 'package:ritmo/features/courses/logic/course_timer_service.dart';
import 'package:ritmo/features/courses/logic/course_validation.dart';
import 'package:ritmo/features/courses/logic/sm2_review_engine.dart';
import 'package:ritmo/features/courses/models/course_models.dart';
import 'package:sqflite/sqflite.dart';

class CoursesRepository {
  CoursesRepository._init();
  static final CoursesRepository instance = CoursesRepository._init();

  Database? _testDatabase;

  @visibleForTesting
  void overrideDatabaseForTesting(Database? db) {
    _testDatabase = db;
  }

  Future<Database> get _database async => _testDatabase ?? await DatabaseHelper.instance.database;

  Stream<RitmoEvent> get events => RitmoEventBus().onEvents.where((e) => e.type == 'CoursesChanged' || e.type == 'CourseSessionCompleted');

  void _fireEvent(String reason, {String? courseId, String? sessionId, bool allSkipped = false}) {
    final now = DateTime.now();
    RitmoEventBus().fire(RitmoEvent(
      type: 'CoursesChanged',
      timestamp: now,
      payload: {
        ?courseId: courseId,
        ?sessionId: sessionId,
        'reason': reason,
        'allSkipped': allSkipped,
      },
    ));

    if (reason == 'COMPLETE') {
      RitmoEventBus().fire(RitmoEvent(
        type: 'CourseSessionCompleted',
        timestamp: now,
        payload: {
          ?sessionId: sessionId,
          ?courseId: courseId,
          'allSkipped': allSkipped,
        },
      ));
    }
  }

  /// Fetch all active and paused non-archived courses (Fixes N1)
  Future<List<Course>> getActiveCourses() async {
    final db = await _database;
    final maps = await db.query(
      'courses',
      where: 'isArchived = 0 AND status != ?',
      whereArgs: [CourseStatus.completed],
      orderBy: 'updatedAt DESC',
    );
    return maps.map(Course.fromMap).toList();
  }

  /// Fetch all completed, non-archived courses (Hall of Fame) (Fixes N1 & M11)
  Future<List<Course>> getCompletedCourses() async {
    final db = await _database;
    final maps = await db.query(
      'courses',
      where: 'status = ? AND isArchived = 0',
      whereArgs: [CourseStatus.completed],
      orderBy: 'completedAt DESC, updatedAt DESC',
    );
    return maps.map(Course.fromMap).toList();
  }

  /// Fetch all archived courses regardless of status (Fixes N1)
  Future<List<Course>> getArchivedCourses() async {
    final db = await _database;
    final maps = await db.query(
      'courses',
      where: 'isArchived = 1',
      orderBy: 'updatedAt DESC',
    );
    return maps.map(Course.fromMap).toList();
  }

  /// Deprecated helper for backward compatibility
  Future<List<Course>> getCompletedAndArchivedCourses() async {
    return getCompletedCourses();
  }

  /// Fetch a single course by ID
  Future<Course?> getCourseById(String courseId) async {
    final db = await _database;
    final maps = await db.query(
      'courses',
      where: 'id = ?',
      whereArgs: [courseId],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Course.fromMap(maps.first);
  }

  /// Fetch all sessions of a specific course
  Future<List<CourseSession>> getSessionsForCourse(String courseId) async {
    final db = await _database;
    final maps = await db.query(
      'course_sessions',
      where: 'courseId = ?',
      whereArgs: [courseId],
      orderBy: 'displayOrder ASC, sessionNumber ASC',
    );
    return maps.map(CourseSession.fromMap).toList();
  }

  /// Batch fetch sessions for multiple courses (fixes N+1)
  Future<Map<String, List<CourseSession>>> getSessionsForCourses(Set<String> courseIds) async {
    if (courseIds.isEmpty) return {};
    final db = await _database;
    final placeholders = List.filled(courseIds.length, '?').join(',');
    final maps = await db.query(
      'course_sessions',
      where: 'courseId IN ($placeholders)',
      whereArgs: courseIds.toList(),
      orderBy: 'displayOrder ASC, sessionNumber ASC',
    );

    final result = <String, List<CourseSession>>{};
    for (final id in courseIds) {
      result[id] = [];
    }
    for (final map in maps) {
      final session = CourseSession.fromMap(map);
      result[session.courseId]?.add(session);
    }
    return result;
  }

  /// Fetch sessions for date range
  Future<List<CourseSession>> getSessionsForDateRange(String fromIso, String toIso) async {
    final db = await _database;
    final maps = await db.query(
      'course_sessions',
      where: 'plannedDate >= ? AND plannedDate <= ?',
      whereArgs: [fromIso, toIso],
      orderBy: 'plannedDate ASC, displayOrder ASC, sessionNumber ASC',
    );
    return maps.map(CourseSession.fromMap).toList();
  }

  /// Fetch sessions scheduled for a particular date
  Future<List<CourseSession>> getSessionsForDate(String dateStr) async {
    return getSessionsForDateRange(dateStr, dateStr);
  }

  /// Save course: routes to createCourse if isNew==true, or updateCourse if isNew==false (Fixes N2)
  Future<ScheduleResult?> saveCourse(Course course, {required bool isNew}) async {
    if (isNew) {
      return await createCourse(course);
    } else {
      await updateCourse(course);
      return null;
    }
  }

  /// Create a new course and schedule its sessions (Fixes N2)
  Future<ScheduleResult> createCourse(Course course) async {
    CourseValidator.validateCourse(course);
    final db = await _database;
    final now = DateTime.now();
    late ScheduleResult scheduleResult;

    await db.transaction((txn) async {
      await UpsertHelper.upsert(
        txn,
        'courses',
        course.toMap(),
        conflictColumns: const ['id'],
      );

      scheduleResult = CourseScheduler.distributeSessions(
        pendingCount: course.totalSessions,
        from: now,
        weeklyTarget: course.weeklyTargetSessions,
        preferredDays: course.preferredDays,
      );
      final sessionDates = scheduleResult.dates;

      for (var i = 0; i < course.totalSessions; i++) {
        final sessionId = 'sess_${now.millisecondsSinceEpoch}_${course.id}_${i}_${DateTime.now().microsecondsSinceEpoch % 10000}';
        String? plannedDateStr;
        if (i < sessionDates.length) {
          plannedDateStr = CourseDate.toDayKey(sessionDates[i]);
        }

        final session = CourseSession(
          id: sessionId,
          courseId: course.id,
          sessionNumber: i + 1,
          displayOrder: i + 1,
          plannedDate: plannedDateStr,
          createdAt: now.millisecondsSinceEpoch,
          updatedAt: now.millisecondsSinceEpoch,
          sessionTitle: '${course.unitLabelResolved} ${i + 1}',
        );

        await txn.insert(
          'course_sessions',
          session.toMap(),
          conflictAlgorithm: ConflictAlgorithm.abort,
        );
      }

      await _rebuildRemindersForCourse(txn, course);
    });

    await syncCourseAlarms();
    _fireEvent('CREATE', courseId: course.id);
    return scheduleResult;
  }

  /// Create a course with pre-defined draft sessions (AI Syllabus import) - Fixes D-6 SOT totalSessions & M8 & N2
  Future<ScheduleResult> createCourseWithSessions(Course course, List<CourseSession> draftSessions) async {
    final syncedCourse = course.copyWith(totalSessions: draftSessions.length);
    CourseValidator.validateCourse(syncedCourse);
    final db = await _database;
    final now = DateTime.now();
    late ScheduleResult scheduleResult;

    await db.transaction((txn) async {
      await UpsertHelper.upsert(
        txn,
        'courses',
        syncedCourse.toMap(),
        conflictColumns: const ['id'],
      );

      final pendingCount = draftSessions.length;
      scheduleResult = CourseScheduler.distributeSessions(
        pendingCount: pendingCount,
        from: now,
        weeklyTarget: syncedCourse.weeklyTargetSessions,
        preferredDays: syncedCourse.preferredDays,
      );
      final sessionDates = scheduleResult.dates;

      for (var i = 0; i < draftSessions.length; i++) {
        final draft = draftSessions[i];
        String? plannedDateStr;
        if (i < sessionDates.length) {
          plannedDateStr = CourseDate.toDayKey(sessionDates[i]);
        }

        final session = draft.copyWith(
          // Always generate a fresh collision-safe ID (Fixes M8)
          id: 'sess_${now.millisecondsSinceEpoch}_${syncedCourse.id}_${i}_${DateTime.now().microsecondsSinceEpoch % 10000}',
          courseId: syncedCourse.id,
          sessionNumber: i + 1,
          displayOrder: i + 1,
          plannedDate: plannedDateStr,
          createdAt: now.millisecondsSinceEpoch,
          updatedAt: now.millisecondsSinceEpoch,
        );

        await txn.insert(
          'course_sessions',
          session.toMap(),
          conflictAlgorithm: ConflictAlgorithm.abort,
        );
      }

      await _rebuildRemindersForCourse(txn, syncedCourse);
    });

    await syncCourseAlarms();
    _fireEvent('CREATE', courseId: syncedCourse.id);
    return scheduleResult;
  }

  /// Update / edit course details with transactional session count adjustment and rescheduling (Fixes Root 1, D-5, K-10, K-11, C4, H5, M8)
  Future<CourseMutationResult> updateCourse(Course updatedCourse) async {
    CourseValidator.validateCourse(updatedCourse);
    final db = await _database;
    final now = DateTime.now();

    final existingCourse = await getCourseById(updatedCourse.id);
    if (existingCourse == null) return CourseMutationResult.notFound;

    final existingSessions = await getSessionsForCourse(updatedCourse.id);
    // Completed AND skipped sessions are both "locked" — they cannot be removed,
    // so shrinking below their combined count must be rejected up front. (Fixes H5)
    final completedSessionsCount = existingSessions.where((s) => s.isCompleted).length;
    final skippedSessionsCount = existingSessions.where((s) => s.isSkipped).length;
    final lockedSessionsCount = completedSessionsCount + skippedSessionsCount;

    if (updatedCourse.totalSessions < lockedSessionsCount) {
      throw CourseValidationException(
        'CANNOT_SHRINK_BELOW_LOCKED',
        'تعداد جلسات نمی‌تواند کمتر از جلسات انجام‌شده یا ردشده ($lockedSessionsCount) باشد.',
      );
    }

    if (updatedCourse.totalSessions < existingSessions.length) {
      final countToRemove = existingSessions.length - updatedCourse.totalSessions;
      final pendingFromEnd = existingSessions.reversed.where((s) => !s.isCompleted && !s.isSkipped && !s.isReview).take(countToRemove).toList();
      if (pendingFromEnd.length < countToRemove) {
        throw CourseValidationException(
          'CANNOT_SHRINK_BELOW_LOCKED',
          'نمی‌توان تعداد جلسات را به ${updatedCourse.totalSessions} کاهش داد زیرا تنها ${pendingFromEnd.length} جلسه عادی قابل حذف وجود دارد.',
        );
      }
    }

    // Reminder-only changes (preferredTime / reminderEnabled / status / isArchived) must NOT trigger a
    // date redistribution — reminders are rebuilt conditionally in step 4 below (Fixes H7).
    final needsReschedule = existingCourse.weeklyTargetSessions != updatedCourse.weeklyTargetSessions ||
        !listEquals(existingCourse.preferredDays, updatedCourse.preferredDays) ||
        existingCourse.totalSessions != updatedCourse.totalSessions;

    final reminderSettingsChanged = existingCourse.reminderEnabled != updatedCourse.reminderEnabled ||
        existingCourse.preferredTime != updatedCourse.preferredTime ||
        existingCourse.status != updatedCourse.status ||
        existingCourse.isArchived != updatedCourse.isArchived;

    final alarmsToCancel = <String>[];

    await db.transaction((txn) async {
      // 1. Adjust session count if totalSessions changed (Fixes K-11, M8, and Session Reduction Inconsistency)
      final actualExistingCount = existingSessions.length;
      if (updatedCourse.totalSessions > actualExistingCount) {
        final countToAdd = updatedCourse.totalSessions - actualExistingCount;
        final maxNumRes = await txn.rawQuery(
          'SELECT COALESCE(MAX(sessionNumber), 0) + 1 as nextNum FROM course_sessions WHERE courseId = ?',
          [updatedCourse.id],
        );
        final startSessionNumber = (maxNumRes.first['nextNum'] as int?) ?? 1;

        final maxOrderRes = await txn.rawQuery(
          'SELECT COALESCE(MAX(displayOrder), 0) + 1 as nextOrder FROM course_sessions WHERE courseId = ?',
          [updatedCourse.id],
        );
        final startDisplayOrder = (maxOrderRes.first['nextOrder'] as int?) ?? startSessionNumber;

        for (var i = 0; i < countToAdd; i++) {
          final sNum = startSessionNumber + i;
          final dOrder = startDisplayOrder + i;
          final sessionId = 'sess_${now.millisecondsSinceEpoch}_${updatedCourse.id}_${sNum}_${DateTime.now().microsecondsSinceEpoch % 10000}';
          final newSession = CourseSession(
            id: sessionId,
            courseId: updatedCourse.id,
            sessionNumber: sNum,
            displayOrder: dOrder,
            createdAt: now.millisecondsSinceEpoch,
            updatedAt: now.millisecondsSinceEpoch,
            sessionTitle: '${updatedCourse.unitLabelResolved} $sNum',
          );
          await txn.insert(
            'course_sessions',
            newSession.toMap(),
            conflictAlgorithm: ConflictAlgorithm.abort,
          );
        }
      } else if (updatedCourse.totalSessions < actualExistingCount) {
        final countToRemove = actualExistingCount - updatedCourse.totalSessions;
        final pendingFromEnd = existingSessions.reversed.where((s) => !s.isCompleted && !s.isSkipped && !s.isReview).take(countToRemove).toList();
        for (final s in pendingFromEnd) {
          final rems = await txn.query('pending_reminders', where: 'courseSessionId = ?', whereArgs: [s.id]);
          for (final r in rems) {
            if (r['id'] != null) alarmsToCancel.add(r['id']! as String);
          }
          await txn.delete('pending_reminders', where: 'courseSessionId = ?', whereArgs: [s.id]);
          await txn.delete('course_sessions', where: 'id = ?', whereArgs: [s.id]);
        }
      }

      // 2. Count actual remaining sessions in DB and sync totalSessions (SOT)
      final remainingCountRes = await txn.rawQuery(
        'SELECT COUNT(*) as cnt FROM course_sessions WHERE courseId = ?',
        [updatedCourse.id],
      );
      final actualTotal = remainingCountRes.isNotEmpty ? (remainingCountRes.first['cnt'] as int? ?? updatedCourse.totalSessions) : updatedCourse.totalSessions;
      
      // Reactivate completed course if new pending sessions exist (Fixes C4)
      final pendingCountRes = await txn.rawQuery(
        'SELECT COUNT(*) as cnt FROM course_sessions WHERE courseId = ? AND completionStatus = ?',
        [updatedCourse.id, SessionStatus.pending.dbValue],
      );
      final hasPending = (pendingCountRes.first['cnt'] as int? ?? 0) > 0;
      var syncedCourse = updatedCourse.copyWith(totalSessions: actualTotal);
      if (hasPending && syncedCourse.status == CourseStatus.completed) {
        syncedCourse = syncedCourse.copyWith(
          status: CourseStatus.active,
          completedAtSet: true,
          completedAt: null,
        );
      }

      await txn.update(
        'courses',
        syncedCourse.toMap(),
        where: 'id = ?',
        whereArgs: [syncedCourse.id],
      );

      // 3. Reschedule pending sessions if needed
      if (needsReschedule) {
        final currentSessionsMaps = await txn.query(
          'course_sessions',
          where: 'courseId = ?',
          whereArgs: [syncedCourse.id],
          orderBy: 'displayOrder ASC, sessionNumber ASC',
        );
        final currentSessions = currentSessionsMaps.map(CourseSession.fromMap).toList();

        final occupiedMap = CourseScheduler.weeklyOccupancy(
          sessions: currentSessions.where((s) => s.isCompleted || s.isSkipped || s.isUserScheduled).toList(),
        );

        final pendingToSchedule = currentSessions.where((s) => !s.isCompleted && !s.isSkipped && !s.isUserScheduled).toList();

        if (pendingToSchedule.isNotEmpty) {
          final scheduleResult = CourseScheduler.distributeSessions(
            pendingCount: pendingToSchedule.length,
            from: now,
            weeklyTarget: syncedCourse.weeklyTargetSessions,
            preferredDays: syncedCourse.preferredDays,
            occupiedWeeklyCounts: occupiedMap,
          );
          final newDates = scheduleResult.dates;

          for (var i = 0; i < pendingToSchedule.length; i++) {
            final session = pendingToSchedule[i];
            String? newDateStr;
            if (i < newDates.length) {
              newDateStr = CourseDate.toDayKey(newDates[i]);
            }
            await txn.update(
              'course_sessions',
              {
                'plannedDate': newDateStr,
                'updatedAt': now.millisecondsSinceEpoch,
              },
              where: 'id = ?',
              whereArgs: [session.id],
            );
          }
        }
      }

      // 4. Rebuild reminders for course only if schedule or reminder configuration changed (Fixes H7)
      if (needsReschedule || reminderSettingsChanged) {
        final rebuildAlarms = await _rebuildRemindersForCourse(txn, syncedCourse);
        alarmsToCancel.addAll(rebuildAlarms);
      }
    });

    for (final id in alarmsToCancel) {
      await _cancelAlarmSafely(id);
    }

    await syncCourseAlarms();
    _fireEvent('UPDATE', courseId: updatedCourse.id);
    return CourseMutationResult.applied;
  }

  /// Complete a specific course session (Fixes D-1, D-2, D-25, K-10, H6, M6)
  Future<CourseMutationResult> completeSession({
    required String sessionId,
    required int actualDurationMinutes,
    String? note,
    int? understandingScore,
    bool needsReview = false,
    String? keyTakeaway,
    String? openQuestion,
  }) async {
    final db = await _database;
    final now = DateTime.now();
    String? courseId;
    final alarmsToCancel = <String>[];
    var allSkipped = false;

    final mutation = await db.transaction<CourseMutationResult>((txn) async {
      final sessionMaps = await txn.query('course_sessions', where: 'id = ?', whereArgs: [sessionId]);
      if (sessionMaps.isEmpty) return CourseMutationResult.notFound;
      final session = CourseSession.fromMap(sessionMaps.first);
      courseId = session.courseId;

      // Partial update: preserve existing note if note parameter is null (Fixes D-1)
      final updates = <String, dynamic>{
        'completionStatus': SessionStatus.completed.dbValue,
        'actualDurationMinutes': actualDurationMinutes,
        'completedAt': now.millisecondsSinceEpoch,
        'updatedAt': now.millisecondsSinceEpoch,
      };
      if (note != null) updates['note'] = note;
      if (understandingScore != null) updates['understandingScore'] = understandingScore;
      if (needsReview) updates['needsReview'] = 1;
      if (keyTakeaway != null) updates['keyTakeaway'] = keyTakeaway;
      if (openQuestion != null) updates['openQuestion'] = openQuestion;

      await txn.update(
        'course_sessions',
        updates,
        where: 'id = ?',
        whereArgs: [sessionId],
      );

      final rems = await txn.query('pending_reminders', where: 'courseSessionId = ?', whereArgs: [sessionId]);
      for (final r in rems) {
        if (r['id'] != null) alarmsToCancel.add(r['id']! as String);
      }
      await txn.delete('pending_reminders', where: 'courseSessionId = ?', whereArgs: [sessionId]);

      // Check course configuration
      final courseMaps = await txn.query('courses', where: 'id = ?', whereArgs: [courseId]);
      if (courseMaps.isNotEmpty) {
        final course = Course.fromMap(courseMaps.first);

        // SM-2 Review Session Generation (Fixes H6 & N3)
        if ((needsReview || (understandingScore != null && understandingScore <= 2)) && course.reviewEnabled) {
          final openReviewRes = await txn.query(
            'course_sessions',
            columns: ['id'],
            where: 'courseId = ? AND sourceSessionId = ? AND completionStatus = ?',
            whereArgs: [courseId, sessionId, SessionStatus.pending.dbValue],
          );

          final activeReviewsRes = await txn.rawQuery(
            'SELECT COUNT(*) as cnt FROM course_sessions WHERE courseId = ? AND activityKind = ? AND completionStatus = ?',
            [courseId, CourseActivityKind.review.dbValue, SessionStatus.pending.dbValue],
          );
          final activeReviewsCount = (activeReviewsRes.first['cnt'] as int? ?? 0);

          if (openReviewRes.isEmpty && activeReviewsCount < CourseLimits.maxActiveReviewSessions) {
            final prevReviews = await txn.query(
              'course_sessions',
              where: 'sourceSessionId = ? AND activityKind = ?',
              whereArgs: [sessionId, CourseActivityKind.review.dbValue],
            );
            final sm2Result = SM2ReviewEngine.calculateNextReview(
              qualityScore: understandingScore ?? 3,
              previousRepetitions: prevReviews.length,
              fromDate: now,
            );
            final reviewDateStr = CourseDate.toDayKey(sm2Result.nextReviewDate);
            final maxNumRes = await txn.rawQuery(
              'SELECT COALESCE(MAX(sessionNumber), 0) + 1 as nextNum, COALESCE(MAX(displayOrder), 0) + 1 as nextOrder FROM course_sessions WHERE courseId = ?',
              [courseId],
            );
            final nextNum = (maxNumRes.first['nextNum'] as int?) ?? 1;
            final nextOrder = (maxNumRes.first['nextOrder'] as int?) ?? nextNum;
            final reviewSessionId = 'sess_${now.millisecondsSinceEpoch}_${courseId}_rev_$nextNum';
            final reviewSession = CourseSession(
              id: reviewSessionId,
              courseId: courseId!,
              sessionNumber: nextNum,
              displayOrder: nextOrder,
              plannedDate: reviewDateStr,
              activityKind: CourseActivityKind.review,
              sourceSessionId: sessionId,
              createdAt: now.millisecondsSinceEpoch,
              updatedAt: now.millisecondsSinceEpoch,
              sessionTitle: 'مرور: ${session.sessionTitle ?? '${course.unitLabelResolved} ${session.sessionNumber}'}',
            );
            await txn.insert('course_sessions', reviewSession.toMap(), conflictAlgorithm: ConflictAlgorithm.abort);

            final reviewAlarms = await _rebuildReminderForSession(txn, course, reviewSession);
            alarmsToCancel.addAll(reviewAlarms);
          }
        }

        // Sync courses.totalSessions with actual row count in same transaction (Fixes N3)
        final totalCountRes = await txn.rawQuery(
          'SELECT COUNT(*) as cnt FROM course_sessions WHERE courseId = ?',
          [courseId],
        );
        final actualTotal = totalCountRes.first['cnt'] as int;
        await txn.update(
          'courses',
          {'totalSessions': actualTotal, 'updatedAt': now.millisecondsSinceEpoch},
          where: 'id = ?',
          whereArgs: [courseId],
        );

        // Update Course Mastery Score (Fixes H6)
        final scoredSessions = await txn.rawQuery(
          'SELECT AVG(understandingScore) as avgScore FROM course_sessions WHERE courseId = ? AND understandingScore IS NOT NULL',
          [courseId],
        );
        if (scoredSessions.isNotEmpty && scoredSessions.first['avgScore'] != null) {
          final avgScore = (scoredSessions.first['avgScore'] as num).toDouble();
          final mastery = (avgScore / 5.0 * 100.0).clamp(0.0, 100.0);
          await txn.update('courses', {'masteryScore': mastery, 'updatedAt': now.millisecondsSinceEpoch}, where: 'id = ?', whereArgs: [courseId]);
        }

        // Linked Goal Progress Update (Fixes D-25 & M6)
        if (course.linkedGoalId != null) {
          final allSess = await txn.query('course_sessions', where: 'courseId = ?', whereArgs: [courseId]);
          final doneSess = allSess.where((s) => s['completionStatus'] == SessionStatus.completed.dbValue).length;
          final ratio = allSess.isNotEmpty ? (doneSess / allSess.length).clamp(0.0, 1.0) : 0.0;
          await txn.update(
            'goals',
            {'progressCache': ratio, 'updatedAt': now.millisecondsSinceEpoch},
            where: 'id = ?',
            whereArgs: [course.linkedGoalId],
          );
        }
      }

      // Check remaining pending sessions to complete course
      final remainingPending = await txn.query(
        'course_sessions',
        where: 'courseId = ? AND completionStatus = ?',
        whereArgs: [courseId, SessionStatus.pending.dbValue],
      );

      if (remainingPending.isEmpty) {
        final allSessions = await txn.query('course_sessions', where: 'courseId = ?', whereArgs: [courseId]);
        final completedCount = allSessions.where((s) => s['completionStatus'] == SessionStatus.completed.dbValue).length;
        allSkipped = completedCount == 0;

        await txn.update(
          'courses',
          {
            'status': CourseStatus.completed,
            'completedAt': now.millisecondsSinceEpoch,
            'updatedAt': now.millisecondsSinceEpoch,
          },
          where: 'id = ?',
          whereArgs: [courseId],
        );
      }

      return CourseMutationResult.applied;
    });

    if (!mutation.isApplied) return mutation;

    // Check and cancel active timer if running on this session
    await CourseTimerService.instance.checkAndCancelTimerForSession(sessionId);

    for (final id in alarmsToCancel) {
      await _cancelAlarmSafely(id);
    }

    await syncCourseAlarms();
    _fireEvent('COMPLETE', courseId: courseId, sessionId: sessionId, allSkipped: allSkipped);
    return CourseMutationResult.applied;
  }

  /// Uncomplete a session (Fixes D-12, K-10, H1, M6)
  Future<CourseMutationResult> uncompleteSession(String sessionId) async {
    final db = await _database;
    final now = DateTime.now();
    String? courseId;
    final alarmsToCancel = <String>[];

    final mutation = await db.transaction<CourseMutationResult>((txn) async {
      final sessionMaps = await txn.query('course_sessions', where: 'id = ?', whereArgs: [sessionId]);
      if (sessionMaps.isEmpty) return CourseMutationResult.notFound;
      final session = CourseSession.fromMap(sessionMaps.first);
      courseId = session.courseId;

      await txn.update(
        'course_sessions',
        {
          'completionStatus': SessionStatus.pending.dbValue,
          'completedAt': null,
          'actualDurationMinutes': null,
          'understandingScore': null,
          'needsReview': 0,
          'updatedAt': now.millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [sessionId],
      );

      // Delete any pending review session created from this session (Fixes N3)
      final pendingReviews = await txn.query(
        'course_sessions',
        columns: ['id'],
        where: 'courseId = ? AND sourceSessionId = ? AND completionStatus = ?',
        whereArgs: [courseId, sessionId, SessionStatus.pending.dbValue],
      );
      for (final r in pendingReviews) {
        final rId = r['id'] as String;
        final rems = await txn.query('pending_reminders', columns: ['id'], where: 'courseSessionId = ?', whereArgs: [rId]);
        for (final rem in rems) {
          if (rem['id'] != null) alarmsToCancel.add(rem['id']! as String);
        }
        await txn.delete('pending_reminders', where: 'courseSessionId = ?', whereArgs: [rId]);
        await txn.delete('course_sessions', where: 'id = ?', whereArgs: [rId]);
      }

      final courseMaps = await txn.query('courses', where: 'id = ?', whereArgs: [courseId]);
      if (courseMaps.isNotEmpty) {
        final course = Course.fromMap(courseMaps.first);

        // Sync courses.totalSessions via COUNT(*) in same transaction (Fixes N3)
        final totalCountRes = await txn.rawQuery(
          'SELECT COUNT(*) as cnt FROM course_sessions WHERE courseId = ?',
          [courseId],
        );
        final actualTotal = totalCountRes.first['cnt'] as int;

        if (course.status == CourseStatus.completed && !course.isArchived) {
          await txn.update(
            'courses',
            {
              'status': CourseStatus.active,
              'completedAt': null,
              'totalSessions': actualTotal,
              'updatedAt': now.millisecondsSinceEpoch,
            },
            where: 'id = ?',
            whereArgs: [courseId],
          );
        } else {
          await txn.update(
            'courses',
            {
              'totalSessions': actualTotal,
              'updatedAt': now.millisecondsSinceEpoch,
            },
            where: 'id = ?',
            whereArgs: [courseId],
          );
        }

        // Keep linked goal progress in sync (Fixes M6)
        if (course.linkedGoalId != null) {
          final allSess = await txn.query('course_sessions', where: 'courseId = ?', whereArgs: [courseId]);
          final doneSess = allSess.where((s) => s['completionStatus'] == SessionStatus.completed.dbValue).length;
          final ratio = allSess.isNotEmpty ? (doneSess / allSess.length).clamp(0.0, 1.0) : 0.0;
          await txn.update(
            'goals',
            {'progressCache': ratio, 'updatedAt': now.millisecondsSinceEpoch},
            where: 'id = ?',
            whereArgs: [course.linkedGoalId],
          );
        }

        // Rebuild reminder point-wise for this restored session (Fixes H7)
        final rebuildAlarms = await _rebuildReminderForSession(
          txn,
          course,
          session.copyWith(
            completionStatus: SessionStatus.pending,
            completedAtSet: true,
            completedAt: null,
            actualDurationMinutesSet: true,
            actualDurationMinutes: null,
            understandingScoreSet: true,
            understandingScore: null,
            needsReview: false,
          ),
        );
        alarmsToCancel.addAll(rebuildAlarms);
      }
      return CourseMutationResult.applied;
    });

    if (!mutation.isApplied) return mutation;

    // Cancel zombie alarms (Fixes H1)
    for (final id in alarmsToCancel) {
      await _cancelAlarmSafely(id);
    }

    await syncCourseAlarms();
    _fireEvent('UNCOMPLETE', courseId: courseId, sessionId: sessionId);
    return CourseMutationResult.applied;
  }

  /// Skip a session (Fixes D-1, D-27, D-13, K-10)
  Future<CourseMutationResult> skipSession(String sessionId, {String? reason}) async {
    final db = await _database;
    final now = DateTime.now();
    String? courseId;
    final alarmsToCancel = <String>[];
    var allSkipped = false;

    final mutation = await db.transaction<CourseMutationResult>((txn) async {
      final sessionMaps = await txn.query('course_sessions', where: 'id = ?', whereArgs: [sessionId]);
      if (sessionMaps.isEmpty) return CourseMutationResult.notFound;
      final session = CourseSession.fromMap(sessionMaps.first);
      courseId = session.courseId;

      await txn.update(
        'course_sessions',
        {
          'completionStatus': SessionStatus.skipped.dbValue,
          'skipReason': reason,
          'completedAt': null,
          'updatedAt': now.millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [sessionId],
      );

      final rems = await txn.query('pending_reminders', where: 'courseSessionId = ?', whereArgs: [sessionId]);
      for (final r in rems) {
        if (r['id'] != null) alarmsToCancel.add(r['id']! as String);
      }
      await txn.delete('pending_reminders', where: 'courseSessionId = ?', whereArgs: [sessionId]);

      final remainingPending = await txn.query(
        'course_sessions',
        where: 'courseId = ? AND completionStatus = ?',
        whereArgs: [courseId, SessionStatus.pending.dbValue],
      );

      if (remainingPending.isEmpty) {
        final allSessions = await txn.query('course_sessions', where: 'courseId = ?', whereArgs: [courseId]);
        final completedCount = allSessions.where((s) => s['completionStatus'] == SessionStatus.completed.dbValue).length;
        allSkipped = completedCount == 0;

        await txn.update(
          'courses',
          {
            'status': CourseStatus.completed,
            'completedAt': now.millisecondsSinceEpoch,
            'updatedAt': now.millisecondsSinceEpoch,
          },
          where: 'id = ?',
          whereArgs: [courseId],
        );
      }

      final courseMaps = await txn.query('courses', where: 'id = ?', whereArgs: [courseId]);
      if (courseMaps.isNotEmpty) {
        final course = Course.fromMap(courseMaps.first);
        final rebuildAlarms = await _rebuildReminderForSession(
          txn,
          course,
          session.copyWith(completionStatus: SessionStatus.skipped),
        );
        alarmsToCancel.addAll(rebuildAlarms);
      }
      return CourseMutationResult.applied;
    });

    if (!mutation.isApplied) return mutation;

    await CourseTimerService.instance.checkAndCancelTimerForSession(sessionId);

    for (final id in alarmsToCancel) {
      await _cancelAlarmSafely(id);
    }

    await syncCourseAlarms();
    _fireEvent('SKIP', courseId: courseId, sessionId: sessionId, allSkipped: allSkipped);
    return CourseMutationResult.applied;
  }

  /// Batch-skip sessions across multiple courses with complete multi-course finalization (Fixes H8)
  Future<CourseMutationResult> skipSessions(List<String> sessionIds, {String? reason}) async {
    if (sessionIds.isEmpty) return CourseMutationResult.noOp;
    final db = await _database;
    final now = DateTime.now();
    final alarmsToCancel = <String>[];
    final affectedCourseIds = <String>{};

    final mutation = await db.transaction<CourseMutationResult>((txn) async {
      for (final sessionId in sessionIds) {
        final sessionMaps = await txn.query('course_sessions', where: 'id = ?', whereArgs: [sessionId]);
        if (sessionMaps.isEmpty) continue;
        final session = CourseSession.fromMap(sessionMaps.first);
        affectedCourseIds.add(session.courseId);

        await txn.update(
          'course_sessions',
          {
            'completionStatus': SessionStatus.skipped.dbValue,
            'skipReason': reason,
            'completedAt': null,
            'updatedAt': now.millisecondsSinceEpoch,
          },
          where: 'id = ?',
          whereArgs: [sessionId],
        );

        final rems = await txn.query('pending_reminders', where: 'courseSessionId = ?', whereArgs: [sessionId]);
        for (final r in rems) {
          if (r['id'] != null) alarmsToCancel.add(r['id']! as String);
        }
        await txn.delete('pending_reminders', where: 'courseSessionId = ?', whereArgs: [sessionId]);
      }

      // Rebuild and finalize EACH affected course (Fixes H8)
      for (final cid in affectedCourseIds) {
        final remainingPending = await txn.query(
          'course_sessions',
          where: 'courseId = ? AND completionStatus = ?',
          whereArgs: [cid, SessionStatus.pending.dbValue],
        );
        if (remainingPending.isEmpty) {
          await txn.update(
            'courses',
            {
              'status': CourseStatus.completed,
              'completedAt': now.millisecondsSinceEpoch,
              'updatedAt': now.millisecondsSinceEpoch,
            },
            where: 'id = ?',
            whereArgs: [cid],
          );
        }

        final courseMaps = await txn.query('courses', where: 'id = ?', whereArgs: [cid]);
        if (courseMaps.isNotEmpty) {
          final course = Course.fromMap(courseMaps.first);
          final rebuildAlarms = await _rebuildRemindersForCourse(txn, course);
          alarmsToCancel.addAll(rebuildAlarms);
        }
      }
      return CourseMutationResult.applied;
    });

    if (!mutation.isApplied) return mutation;

    for (final id in alarmsToCancel) {
      await _cancelAlarmSafely(id);
    }

    await syncCourseAlarms();
    for (final cid in affectedCourseIds) {
      _fireEvent('SKIP_BATCH', courseId: cid);
    }
    return CourseMutationResult.applied;
  }

  /// Reorder sessions within a course & keep titles synchronized (Fixes D-17, K-12, C3)
  Future<CourseMutationResult> reorderSessions(String courseId, List<String> orderedSessionIds) async {
    final db = await _database;
    final now = DateTime.now().millisecondsSinceEpoch;

    final mutation = await db.transaction<CourseMutationResult>((txn) async {
      final courseMaps = await txn.query('courses', where: 'id = ?', whereArgs: [courseId]);
      if (courseMaps.isEmpty) return CourseMutationResult.notFound;
      final unitLabel = Course.fromMap(courseMaps.first).unitLabelResolved;

      final sessionMaps = await txn.query('course_sessions', where: 'courseId = ?', whereArgs: [courseId]);
      final sessionsById = <String, CourseSession>{
        for (final m in sessionMaps) m['id'] as String: CourseSession.fromMap(m),
      };

      // Ensure all existing sessions are included in the reordered list (Fixes C3)
      final allSessionIds = List<String>.from(orderedSessionIds);
      for (final existingId in sessionsById.keys) {
        if (!allSessionIds.contains(existingId)) {
          allSessionIds.add(existingId);
        }
      }

      // Step 1: Temporarily negate numbers to avoid UNIQUE constraint collision
      await txn.rawUpdate('''
        UPDATE course_sessions 
        SET sessionNumber = -sessionNumber, displayOrder = -displayOrder, updatedAt = ?
        WHERE courseId = ?
      ''', [now, courseId]);

      // Step 2: Assign new positive numbers and displayOrder for 100% of sessions
      for (var i = 0; i < allSessionIds.length; i++) {
        final sId = allSessionIds[i];
        final newNum = i + 1;
        final existing = sessionsById[sId];

        String? newTitle;
        final currentTitle = existing?.sessionTitle;
        if (currentTitle == null ||
            currentTitle.trim().isEmpty ||
            currentTitle == '$unitLabel ${existing?.sessionNumber}') {
          newTitle = '$unitLabel $newNum';
        }

        await txn.update(
          'course_sessions',
          {
            'displayOrder': newNum,
            'sessionNumber': newNum,
            'sessionTitle': ?newTitle,
            'updatedAt': now,
          },
          where: 'id = ? AND courseId = ?',
          whereArgs: [sId, courseId],
        );
      }
      return CourseMutationResult.applied;
    });

    if (mutation.isApplied) {
      _fireEvent('REORDER', courseId: courseId);
    }
    return mutation;
  }

  /// Manually reschedule a specific session to a new date
  Future<CourseMutationResult> rescheduleSession(String sessionId, String? newDateStr) async {
    final db = await _database;
    final now = DateTime.now();
    String? courseId;
    final alarmsToCancel = <String>[];

    final mutation = await db.transaction<CourseMutationResult>((txn) async {
      final sessionMaps = await txn.query('course_sessions', where: 'id = ?', whereArgs: [sessionId]);
      if (sessionMaps.isEmpty) return CourseMutationResult.notFound;

      await txn.update(
        'course_sessions',
        {
          'plannedDate': newDateStr,
          'isUserScheduled': 1,
          'updatedAt': now.millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [sessionId],
      );

      final session = CourseSession.fromMap(sessionMaps.first);
      courseId = session.courseId;

      final courseMaps = await txn.query('courses', where: 'id = ?', whereArgs: [courseId]);
      if (courseMaps.isNotEmpty) {
        final course = Course.fromMap(courseMaps.first);
        final rebuildAlarms = await _rebuildReminderForSession(
          txn,
          course,
          session.copyWith(plannedDate: newDateStr, plannedDateSet: true),
        );
        alarmsToCancel.addAll(rebuildAlarms);
      }
      return CourseMutationResult.applied;
    });

    if (!mutation.isApplied) return mutation;

    for (final id in alarmsToCancel) {
      await _cancelAlarmSafely(id);
    }

    await syncCourseAlarms();
    _fireEvent('RESCHEDULE', courseId: courseId, sessionId: sessionId);
    return CourseMutationResult.applied;
  }

  /// Reschedule all pending, non-user-scheduled sessions of a course starting from today (Fixes N2)
  Future<CourseMutationResult> rescheduleCoursePendingSessions(String courseId) async {
    final db = await _database;
    final now = DateTime.now();
    final alarmsToCancel = <String>[];

    final mutation = await db.transaction<CourseMutationResult>((txn) async {
      final courseMaps = await txn.query('courses', where: 'id = ?', whereArgs: [courseId]);
      if (courseMaps.isEmpty) return CourseMutationResult.notFound;
      final course = Course.fromMap(courseMaps.first);

      final sessionMaps = await txn.query(
        'course_sessions',
        where: 'courseId = ?',
        whereArgs: [courseId],
        orderBy: 'displayOrder ASC, sessionNumber ASC',
      );
      final sessions = sessionMaps.map(CourseSession.fromMap).toList();
      final updatedSessions = CourseScheduler.reschedulePendingSessions(
        sessions: sessions,
        from: now,
        weeklyTarget: course.weeklyTargetSessions,
        preferredDays: course.preferredDays,
      );

      for (final s in updatedSessions) {
        await txn.update(
          'course_sessions',
          {'plannedDate': s.plannedDate, 'updatedAt': now.millisecondsSinceEpoch},
          where: 'id = ?',
          whereArgs: [s.id],
        );
      }

      final rebuildAlarms = await _rebuildRemindersForCourse(txn, course);
      alarmsToCancel.addAll(rebuildAlarms);
      return CourseMutationResult.applied;
    });

    if (!mutation.isApplied) return mutation;

    for (final id in alarmsToCancel) {
      await _cancelAlarmSafely(id);
    }

    await syncCourseAlarms();
    _fireEvent('RESCHEDULE', courseId: courseId);
    return CourseMutationResult.applied;
  }

  /// Apply Catch-up Plan atomically (Fixes H2)
  Future<void> applyCatchupPlan({
    required String courseId,
    required int proposedWeeklyTarget,
    required List<CourseSession> rescheduledSessions,
  }) async {
    final db = await _database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final alarmsToCancel = <String>[];

    await db.transaction((txn) async {
      final courseMaps = await txn.query('courses', where: 'id = ?', whereArgs: [courseId]);
      if (courseMaps.isEmpty) return;
      final course = Course.fromMap(courseMaps.first);

      await txn.update(
        'courses',
        {
          'weeklyTargetSessions': proposedWeeklyTarget,
          'updatedAt': now,
        },
        where: 'id = ?',
        whereArgs: [courseId],
      );

      for (final session in rescheduledSessions) {
        await txn.update(
          'course_sessions',
          {
            'plannedDate': session.plannedDate,
            'isUserScheduled': 0, // Unfreeze from sticky user scheduled
            'updatedAt': now,
          },
          where: 'id = ?',
          whereArgs: [session.id],
        );
      }

      final rebuildAlarms = await _rebuildRemindersForCourse(
        txn,
        course.copyWith(weeklyTargetSessions: proposedWeeklyTarget),
      );
      alarmsToCancel.addAll(rebuildAlarms);
    });

    for (final id in alarmsToCancel) {
      await _cancelAlarmSafely(id);
    }

    await syncCourseAlarms();
    _fireEvent('CATCHUP', courseId: courseId);
  }

  /// Save pre-adjustment snapshot for 24h rollback support (Fixes H3)
  Future<void> saveAdaptiveSnapshot({
    required String courseId,
    required int oldWeeklyTarget,
    required int newWeeklyTarget,
    required List<CourseSession> sessions,
  }) async {
    final db = await _database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final snapshotList = sessions.map((s) => {'id': s.id, 'plannedDate': s.plannedDate}).toList();
    final snapshotJson = jsonEncode(snapshotList);
    final id = 'snap_${now}_$courseId';

    await db.insert('course_adaptive_snapshots', {
      'id': id,
      'courseId': courseId,
      'oldWeeklyTarget': oldWeeklyTarget,
      'newWeeklyTarget': newWeeklyTarget,
      'snapshotJson': snapshotJson,
      'createdAt': now,
    });
  }

  /// Rollback an adaptive schedule adjustment within 24 hours (Fixes H3)
  Future<CourseMutationResult> rollbackAdaptiveAdjustment(String courseId) async {
    final db = await _database;
    final now = DateTime.now();
    final alarmsToCancel = <String>[];

    final mutation = await db.transaction<CourseMutationResult>((txn) async {
      final snapMaps = await txn.query(
        'course_adaptive_snapshots',
        where: 'courseId = ?',
        whereArgs: [courseId],
        orderBy: 'createdAt DESC',
        limit: 1,
      );
      if (snapMaps.isEmpty) {
        return CourseMutationResult.notFound;
      }

      final snap = snapMaps.first;
      final createdAt = snap['createdAt'] as int;
      final ageMs = now.millisecondsSinceEpoch - createdAt;
      if (ageMs > 24 * 60 * 60 * 1000) {
        throw CourseValidationException(
          'ROLLBACK_EXPIRED',
          'مهلت بازگردانی تغییرات تطبیقی (۲۴ ساعت) به پایان رسیده است.',
        );
      }

      final oldWeeklyTarget = snap['oldWeeklyTarget'] as int;
      final snapshotJsonStr = snap['snapshotJson'] as String;
      final snapshotList = (jsonDecode(snapshotJsonStr) as List).cast<Map<String, dynamic>>();

      for (final item in snapshotList) {
        final sId = item['id'] as String;
        final pDate = item['plannedDate'] as String?;
        await txn.update(
          'course_sessions',
          {'plannedDate': pDate, 'updatedAt': now.millisecondsSinceEpoch},
          where: 'id = ?',
          whereArgs: [sId],
        );
      }

      final courseMaps = await txn.query('courses', where: 'id = ?', whereArgs: [courseId]);
      if (courseMaps.isNotEmpty) {
        final course = Course.fromMap(courseMaps.first);
        await txn.update(
          'courses',
          {
            'weeklyTargetSessions': oldWeeklyTarget,
            'updatedAt': now.millisecondsSinceEpoch,
          },
          where: 'id = ?',
          whereArgs: [courseId],
        );
        final updatedCourse = course.copyWith(weeklyTargetSessions: oldWeeklyTarget);
        final rebuildAlarms = await _rebuildRemindersForCourse(txn, updatedCourse);
        alarmsToCancel.addAll(rebuildAlarms);
      }

      // Delete the used snapshot
      await txn.delete('course_adaptive_snapshots', where: 'id = ?', whereArgs: [snap['id']]);

      return CourseMutationResult.applied;
    });

    if (!mutation.isApplied) return mutation;

    for (final id in alarmsToCancel) {
      await _cancelAlarmSafely(id);
    }

    await syncCourseAlarms();
    _fireEvent('UPDATE', courseId: courseId);
    return CourseMutationResult.applied;
  }

  /// Delete a course and cancel in-memory timers and alarms (Fixes C5 & M6)
  Future<CourseMutationResult> deleteCourse(String courseId) async {
    final db = await _database;
    final alarmsToCancel = <String>[];

    final mutation = await db.transaction<CourseMutationResult>((txn) async {
      final courseMaps = await txn.query('courses', where: 'id = ?', whereArgs: [courseId], limit: 1);
      if (courseMaps.isEmpty) return CourseMutationResult.notFound;
      final course = Course.fromMap(courseMaps.first);

      final maps = await txn.rawQuery('''
        SELECT id FROM pending_reminders 
        WHERE courseSessionId IN (SELECT id FROM course_sessions WHERE courseId = ?)
      ''', [courseId]);
      for (final row in maps) {
        if (row['id'] != null) {
          alarmsToCancel.add(row['id']! as String);
        }
      }

      await txn.delete('course_active_timers', where: 'courseId = ?', whereArgs: [courseId]);
      await txn.delete('pending_reminders', where: 'courseSessionId IN (SELECT id FROM course_sessions WHERE courseId = ?)', whereArgs: [courseId]);
      await txn.delete('course_sessions', where: 'courseId = ?', whereArgs: [courseId]);
      await txn.delete('courses', where: 'id = ?', whereArgs: [courseId]);

      // Linked Goal Cleanup (Fixes M6)
      if (course.linkedGoalId != null) {
        final otherCourses = await txn.query('courses', where: 'linkedGoalId = ? AND isArchived = 0', whereArgs: [course.linkedGoalId]);
        if (otherCourses.isEmpty) {
          await txn.update('goals', {'progressCache': 0.0, 'updatedAt': DateTime.now().millisecondsSinceEpoch}, where: 'id = ?', whereArgs: [course.linkedGoalId]);
        } else {
          final otherCourseIds = otherCourses.map((c) => c['id'] as String).toList();
          final placeholders = List.filled(otherCourseIds.length, '?').join(',');
          final allSess = await txn.rawQuery('SELECT completionStatus FROM course_sessions WHERE courseId IN ($placeholders)', otherCourseIds);
          final done = allSess.where((s) => s['completionStatus'] == SessionStatus.completed.dbValue).length;
          final ratio = allSess.isNotEmpty ? (done / allSess.length).clamp(0.0, 1.0) : 0.0;
          await txn.update('goals', {'progressCache': ratio, 'updatedAt': DateTime.now().millisecondsSinceEpoch}, where: 'id = ?', whereArgs: [course.linkedGoalId]);
        }
      }

      return CourseMutationResult.applied;
    });

    if (!mutation.isApplied) return mutation;

    // In-memory active timer cleanup (Fixes C5)
    await CourseTimerService.instance.checkAndCancelTimerForCourse(courseId);

    for (final id in alarmsToCancel) {
      await _cancelAlarmSafely(id);
    }

    await syncCourseAlarms();
    await SnapshotSyncService.syncAll();
    _fireEvent('DELETE', courseId: courseId);
    return CourseMutationResult.applied;
  }

  /// Helper to pause, resume, or complete a course (Fixes D-15 auto-reschedule on resume)
  Future<void> updateCourseStatus(String courseId, String status) async {
    final db = await _database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final alarmsToCancel = <String>[];

    await db.transaction((txn) async {
      final courseMaps = await txn.query('courses', where: 'id = ?', whereArgs: [courseId]);
      if (courseMaps.isEmpty) return;
      final course = Course.fromMap(courseMaps.first);

      await txn.update(
        'courses',
        {
          'status': status,
          'updatedAt': now,
        },
        where: 'id = ?',
        whereArgs: [courseId],
      );

      // D-15: Auto-reschedule pending sessions starting from today when resuming a course!
      if (status == CourseStatus.active) {
        // Do NOT touch user-scheduled sessions — manual reschedules are sticky.
        final pendingMaps = await txn.query(
          'course_sessions',
          where: 'courseId = ? AND completionStatus = ? AND isUserScheduled = 0',
          whereArgs: [courseId, SessionStatus.pending.dbValue],
          orderBy: 'displayOrder ASC, sessionNumber ASC',
        );
        final pendingSessions = pendingMaps.map(CourseSession.fromMap).toList();
        if (pendingSessions.isNotEmpty) {
          final scheduleResult = CourseScheduler.distributeSessions(
            pendingCount: pendingSessions.length,
            from: DateTime.now(),
            weeklyTarget: course.weeklyTargetSessions,
            preferredDays: course.preferredDays,
          );
          final newDates = scheduleResult.dates;
          for (var i = 0; i < pendingSessions.length; i++) {
            String? newDateStr;
            if (i < newDates.length) {
              newDateStr = CourseDate.toDayKey(newDates[i]);
            }
            await txn.update(
              'course_sessions',
              {'plannedDate': newDateStr, 'updatedAt': now},
              where: 'id = ?',
              whereArgs: [pendingSessions[i].id],
            );
          }
        }
      }

      final rebuildAlarms = await _rebuildRemindersForCourse(txn, course.copyWith(status: status));
      alarmsToCancel.addAll(rebuildAlarms);
    });

    for (final id in alarmsToCancel) {
      await _cancelAlarmSafely(id);
    }

    await syncCourseAlarms();
    _fireEvent('STATUS', courseId: courseId);
  }

  /// Restore an archived course with automatic status resolution based on pending sessions (Fixes N1)
  Future<CourseMutationResult> restoreCourse(String courseId) async {
    final db = await _database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final alarmsToCancel = <String>[];

    final mutation = await db.transaction<CourseMutationResult>((txn) async {
      final courseMaps = await txn.query('courses', where: 'id = ?', whereArgs: [courseId]);
      if (courseMaps.isEmpty) return CourseMutationResult.notFound;
      final course = Course.fromMap(courseMaps.first);

      final pendingCountRes = await txn.rawQuery(
        'SELECT COUNT(*) as cnt FROM course_sessions WHERE courseId = ? AND completionStatus = ?',
        [courseId, SessionStatus.pending.dbValue],
      );
      final hasPending = (pendingCountRes.first['cnt'] as int? ?? 0) > 0;
      final targetStatus = hasPending ? CourseStatus.active : CourseStatus.completed;

      await txn.update(
        'courses',
        {
          'isArchived': 0,
          'status': targetStatus,
          'completedAt': targetStatus == CourseStatus.active ? null : course.completedAt,
          'updatedAt': now,
        },
        where: 'id = ?',
        whereArgs: [courseId],
      );

      final updatedCourse = course.copyWith(
        isArchived: false,
        status: targetStatus,
        completedAtSet: true,
        completedAt: targetStatus == CourseStatus.active ? null : course.completedAt,
        updatedAt: now,
      );

      if (targetStatus == CourseStatus.active) {
        final rebuildAlarms = await _rebuildRemindersForCourse(txn, updatedCourse);
        alarmsToCancel.addAll(rebuildAlarms);
      }

      return CourseMutationResult.applied;
    });

    if (!mutation.isApplied) return mutation;

    for (final id in alarmsToCancel) {
      await _cancelAlarmSafely(id);
    }

    await syncCourseAlarms();
    _fireEvent('STATUS', courseId: courseId);
    return CourseMutationResult.applied;
  }

  Future<void> _cancelAlarmSafely(String id) async {
    try {
      if (sl.isRegistered<AlarmPlatform>()) {
        await sl<AlarmPlatform>().cancelAlarm(id);
      }
    } catch (e, st) {
      RitmoLogger.warning(
        'CoursesRepository: Failed to cancel alarm $id: $e',
        error: e,
        stack: st,
      );
    }
  }

  /// Point reminder rebuild for a single session without wiping course reminders (Fixes H7)
  Future<List<String>> _rebuildReminderForSession(Transaction txn, Course course, CourseSession session) async {
    final alarmsToCancel = <String>[];

    final existingRems = await txn.query(
      'pending_reminders',
      columns: ['id'],
      where: 'courseSessionId = ?',
      whereArgs: [session.id],
    );

    for (final row in existingRems) {
      if (row['id'] != null) {
        alarmsToCancel.add(row['id']! as String);
      }
    }

    await txn.delete(
      'pending_reminders',
      where: 'courseSessionId = ?',
      whereArgs: [session.id],
    );

    if (course.status == CourseStatus.paused ||
        course.status == CourseStatus.completed ||
        course.isArchived ||
        !course.reminderEnabled ||
        course.preferredTime == null ||
        session.isCompleted ||
        session.isSkipped ||
        session.plannedDate == null) {
      return alarmsToCancel;
    }

    final dateStr = session.plannedDate!;
    final timeStr = session.plannedStartTime ?? course.preferredTime!;
    final parts = timeStr.split(':');
    if (parts.length != 2) return alarmsToCancel;
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;

    final dateParts = dateStr.split('-');
    if (dateParts.length != 3) return alarmsToCancel;
    final year = int.tryParse(dateParts[0]) ?? 0;
    final month = int.tryParse(dateParts[1]) ?? 0;
    final day = int.tryParse(dateParts[2]) ?? 0;

    final reminderDateTime = DateTime(year, month, day, hour, minute);
    final reminderTimeMs = reminderDateTime.millisecondsSinceEpoch;
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    if (reminderTimeMs > nowMs) {
      final reminderId = 'rem_${nowMs}_${session.id}_${DateTime.now().microsecondsSinceEpoch % 10000}';
      await UpsertHelper.upsert(
        txn,
        'pending_reminders',
        {
          'id': reminderId,
          'routineId': null,
          'scheduleId': null,
          'courseSessionId': session.id,
          'originalTime': reminderTimeMs,
          'scheduledTime': reminderTimeMs,
          'state': 'SCHEDULED',
          'deferCount': 0,
          'createdAt': nowMs,
          'updatedAt': nowMs,
        },
        conflictColumns: const ['id'],
      );
    }

    return alarmsToCancel;
  }

  /// Unified method to rebuild reminders for a course, gathering alarm IDs to cancel before delete (Fixes Root 2, D-2, H7, M8)
  Future<List<String>> _rebuildRemindersForCourse(Transaction txn, Course course) async {
    final alarmsToCancel = <String>[];

    final existingRems = await txn.rawQuery('''
      SELECT id FROM pending_reminders 
      WHERE courseSessionId IN (SELECT id FROM course_sessions WHERE courseId = ?)
    ''', [course.id]);

    for (final row in existingRems) {
      if (row['id'] != null) {
        alarmsToCancel.add(row['id']! as String);
      }
    }

    await txn.rawDelete('''
      DELETE FROM pending_reminders 
      WHERE courseSessionId IN (SELECT id FROM course_sessions WHERE courseId = ?)
    ''', [course.id]);

    if (course.status == CourseStatus.paused ||
        course.status == CourseStatus.completed ||
        course.isArchived ||
        !course.reminderEnabled ||
        course.preferredTime == null) {
      return alarmsToCancel;
    }

    final sessions = await txn.query(
      'course_sessions',
      where: 'courseId = ? AND completionStatus = ? AND plannedDate IS NOT NULL',
      whereArgs: [course.id, SessionStatus.pending.dbValue],
    );

    final parts = course.preferredTime!.split(':');
    if (parts.length != 2) return alarmsToCancel;
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;

    final nowMs = DateTime.now().millisecondsSinceEpoch;

    for (final s in sessions) {
      final session = CourseSession.fromMap(s);
      final dateStr = session.plannedDate!;
      final timeStr = session.plannedStartTime ?? course.preferredTime!;
      final sParts = timeStr.split(':');
      final sHour = sParts.length == 2 ? (int.tryParse(sParts[0]) ?? hour) : hour;
      final sMinute = sParts.length == 2 ? (int.tryParse(sParts[1]) ?? minute) : minute;

      final dateParts = dateStr.split('-');
      if (dateParts.length != 3) continue;
      final year = int.tryParse(dateParts[0]) ?? 0;
      final month = int.tryParse(dateParts[1]) ?? 0;
      final day = int.tryParse(dateParts[2]) ?? 0;

      final reminderDateTime = DateTime(year, month, day, sHour, sMinute);
      final reminderTimeMs = reminderDateTime.millisecondsSinceEpoch;

      if (reminderTimeMs > nowMs) {
        // Collision safe reminder ID (Fixes M8)
        final reminderId = 'rem_${nowMs}_${session.id}_${DateTime.now().microsecondsSinceEpoch % 10000}';
        await UpsertHelper.upsert(
          txn,
          'pending_reminders',
          {
            'id': reminderId,
            'routineId': null,
            'scheduleId': null,
            'courseSessionId': session.id,
            'originalTime': reminderTimeMs,
            'scheduledTime': reminderTimeMs,
            'state': 'SCHEDULED',
            'deferCount': 0,
            'createdAt': nowMs,
            'updatedAt': nowMs,
          },
          conflictColumns: const ['id'],
        );
      }
    }

    return alarmsToCancel;
  }

  /// Remove raw SQL from UI: fetch linked goal title safely
  Future<String?> getLinkedGoalTitle(String goalId) async {
    final db = await _database;
    final maps = await db.query('goals', columns: ['title'], where: 'id = ?', whereArgs: [goalId], limit: 1);
    if (maps.isNotEmpty) return maps.first['title'] as String?;
    return null;
  }

  /// Fetch linked goal title + progressCache + status for the course detail card & dropdown (Fixes K-07)
  Future<Map<String, dynamic>?> getLinkedGoalInfo(String goalId) async {
    final db = await _database;
    final maps = await db.query('goals', columns: ['id', 'title', 'status', 'isPrivate', 'progressCache'], where: 'id = ?', whereArgs: [goalId], limit: 1);
    if (maps.isEmpty) return null;
    return maps.first;
  }

  /// Persist the resolved state of a session's open question.
  Future<void> setSessionQuestionResolved(String sessionId, bool resolved) async {
    final db = await _database;
    await db.update(
      'course_sessions',
      {
        'questionResolved': resolved ? 1 : 0,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [sessionId],
    );
  }

  /// Remove raw SQL from UI: fetch active goals list safely
  Future<List<Map<String, dynamic>>> getActiveGoalsList() async {
    final db = await _database;
    return await db.query('goals', columns: ['id', 'title'], where: "status = 'ACTIVE' AND isPrivate = 0");
  }

  /// Fetch current energy level safely with 24-hour lookback and fallback (Fixes K-09 & M12)
  Future<String> getCurrentEnergyLevel() async {
    final db = await _database;
    final now = DateTime.now();
    final lookbackCutoff = now.subtract(const Duration(hours: 24)).millisecondsSinceEpoch;

    try {
      final logs = await db.query(
        'energy_logs',
        columns: ['energyLevel'],
        where: 'loggedAt >= ?',
        whereArgs: [lookbackCutoff],
        orderBy: 'loggedAt DESC',
        limit: 1,
      );
      if (logs.isNotEmpty) {
        final lvl = logs.first['energyLevel'] as String?;
        if (lvl != null && lvl.trim().isNotEmpty) {
          return CourseEnergyLevelExtension.fromString(lvl).dbValue;
        }
      }
    } catch (e, st) {
      RitmoLogger.warning(
        'CoursesRepository: Failed to fetch energy_logs: $e',
        error: e,
        stack: st,
      );
    }

    try {
      final settings = await db.query('app_settings', where: "key = 'default_energy_level'");
      if (settings.isNotEmpty) {
        final val = settings.first['value'] as String?;
        if (val != null && val.trim().isNotEmpty) {
          return CourseEnergyLevelExtension.fromString(val).dbValue;
        }
      }
    } catch (e, st) {
      RitmoLogger.warning(
        'CoursesRepository: Failed to fetch default_energy_level: $e',
        error: e,
        stack: st,
      );
    }

    return CourseEnergyLevel.medium.dbValue;
  }

  /// Remove raw SQL from UI: fetch course settings safely
  Future<Map<String, String>> getCourseSettings() async {
    final db = await _database;
    final maps = await db.query('app_settings', where: "key LIKE 'module_courses_%' OR key = 'default_energy_level'");
    final result = <String, String>{};
    for (final row in maps) {
      final k = row['key'] as String?;
      final v = row['value'] as String?;
      if (k != null && v != null) {
        result[k] = v;
      }
    }
    return result;
  }

  Future<void> syncCourseAlarms() async {
    final db = await _database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final horizonEndMs = now + (14 * 24 * 60 * 60 * 1000);

    final reminders = await db.rawQuery('''
      SELECT pr.id, pr.scheduledTime, c.title
      FROM pending_reminders pr
      JOIN course_sessions cs ON pr.courseSessionId = cs.id
      JOIN courses c ON cs.courseId = c.id
      WHERE pr.state = 'SCHEDULED' AND pr.scheduledTime > ? AND pr.scheduledTime <= ? AND c.status = 'ACTIVE' AND c.isArchived = 0
      ORDER BY pr.scheduledTime ASC
      LIMIT 150
    ''', [now, horizonEndMs]);

    for (final r in reminders) {
      final alarmId = r['id']! as String;
      final timeMs = r['scheduledTime']! as int;
      final courseTitle = r['title']! as String;

      await NotificationGateway.schedule(
        NotificationRequest(
          id: alarmId,
          channel: NotificationChannelId.planning,
          scheduledAt: DateTime.fromMillisecondsSinceEpoch(timeMs),
          title: 'کلاس: $courseTitle',
          sourceSystem: 'courses',
          entityId: alarmId,
        ),
      );
    }

    await SnapshotSyncService.syncAll();
  }
}
