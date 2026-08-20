import 'dart:convert';
import 'package:ritmo/core/logging/ritmo_logger.dart';
import 'package:ritmo/core/ai/brief/briefs/adherence_brief.dart';
import 'package:ritmo/core/ai/brief/briefs/courses_brief.dart';
import 'package:ritmo/core/ai/brief/briefs/cycle_brief.dart';
import 'package:ritmo/core/ai/brief/briefs/goals_brief.dart';
import 'package:ritmo/core/ai/brief/briefs/notes_brief.dart';
import 'package:ritmo/core/ai/brief/briefs/reflection_brief.dart';
import 'package:ritmo/core/ai/brief/briefs/rhythm_brief.dart';
import 'package:ritmo/core/ai/brief/briefs/routines_brief.dart';
import 'package:ritmo/core/ai/brief/briefs/sleep_brief.dart';
import 'package:ritmo/core/ai/brief/briefs/sports_brief.dart';
import 'package:ritmo/core/ai/brief/briefs/study_brief.dart';
import 'package:ritmo/core/ai/brief/briefs/wellbeing_brief.dart';
import 'package:ritmo/core/ai/brief/briefs/worship_brief.dart';
import 'package:ritmo/core/ai/brief/domain_brief.dart';
import 'package:ritmo/core/analytics/sleep_engine.dart';
import 'package:ritmo/core/analytics/wellbeing_engine.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/domain/commands/ritmo_command.dart';
import 'package:ritmo/core/domain/personas/assistant_persona.dart';
import 'package:ritmo/core/domain/personas/persona_gate.dart';
import 'package:ritmo/features/energy/models/energy_mood_models.dart';
import 'package:ritmo/features/sleep/models/sleep_models.dart';

const String _kNotesAiVisibilityClause = 'isLocked = 0 AND isPrivate = 0';

class PersonaContextProvider {
  static const int _horizonDays = 14;

  /// Returns the JSON string of the combined brief assembled according to PersonaGate permissions.
  static Future<String> getBriefJson(AssistantPersona persona) async {
    final Map<String, Object?> combined = {};
    final failedDomains = <String>[];

    try {
      final db = await DatabaseHelper.instance.database;

      // PSN-27: Query readable domains through PersonaGate once per assembly
      final allowedDomains = await PersonaGate.readableDomains(persona.id, db);
      if (allowedDomains.isEmpty && persona.reads.isNotEmpty) {
        return jsonEncode({'status': 'consent_revoked'});
      }

      // Routines (PSN-31)
      if (persona.canReadDomain(DataDomain.routines) && allowedDomains.contains(DataDomain.routines)) {
        try {
          combined['routines'] = (await _buildRoutinesBrief(db)).toPromptJson();
        } catch (e, st) {
          RitmoLog.warning('PersonaContextProvider', 'Failed building routines brief: $e', e, st);
          failedDomains.add('routines');
        }
      }

      // Sleep
      if (persona.canReadDomain(DataDomain.sleep) && allowedDomains.contains(DataDomain.sleep)) {
        try {
          combined['sleep'] = (await _buildSleepBrief(db)).toPromptJson();
        } catch (e, st) {
          RitmoLog.warning('PersonaContextProvider', 'Failed building sleep brief: $e', e, st);
          failedDomains.add('sleep');
        }
      }

      // Wellbeing / Energy
      if (persona.canReadDomain(DataDomain.energy) && allowedDomains.contains(DataDomain.energy)) {
        try {
          combined['wellbeing'] = (await _buildWellbeingBrief(db)).toPromptJson();
        } catch (e, st) {
          RitmoLog.warning('PersonaContextProvider', 'Failed building wellbeing brief: $e', e, st);
          failedDomains.add('wellbeing');
        }
      }

      // Goals
      if (persona.canReadDomain(DataDomain.goals) && allowedDomains.contains(DataDomain.goals)) {
        try {
          combined['goals'] = (await _buildGoalsBrief(db)).toPromptJson();
        } catch (e, st) {
          RitmoLog.warning('PersonaContextProvider', 'Failed building goals brief: $e', e, st);
          failedDomains.add('goals');
        }
      }

      // Worship
      if (persona.canReadDomain(DataDomain.worship) && allowedDomains.contains(DataDomain.worship)) {
        try {
          combined['worship'] = (await _buildWorshipBrief(db)).toPromptJson();
        } catch (e, st) {
          RitmoLog.warning('PersonaContextProvider', 'Failed building worship brief: $e', e, st);
          failedDomains.add('worship');
        }
      }

      // Konkur / Study
      if (persona.canReadDomain(DataDomain.konkur) && allowedDomains.contains(DataDomain.konkur)) {
        try {
          combined['konkur'] = (await _buildStudyBrief(db)).toPromptJson();
        } catch (e, st) {
          RitmoLog.warning('PersonaContextProvider', 'Failed building study brief: $e', e, st);
          failedDomains.add('konkur');
        }
      }

      // Courses
      if (persona.canReadDomain(DataDomain.courses) && allowedDomains.contains(DataDomain.courses)) {
        try {
          combined['courses'] = (await _buildCoursesBrief(db)).toPromptJson();
        } catch (e, st) {
          RitmoLog.warning('PersonaContextProvider', 'Failed building courses brief: $e', e, st);
          failedDomains.add('courses');
        }
      }

      // Sports
      if (persona.canReadDomain(DataDomain.sports) && allowedDomains.contains(DataDomain.sports)) {
        try {
          combined['sports'] = (await _buildSportsBrief(db)).toPromptJson();
        } catch (e, st) {
          RitmoLog.warning('PersonaContextProvider', 'Failed building sports brief: $e', e, st);
          failedDomains.add('sports');
        }
      }

      // Reflection
      if (persona.canReadDomain(DataDomain.reflection) && allowedDomains.contains(DataDomain.reflection)) {
        try {
          combined['reflection'] = (await _buildReflectionBrief(db)).toPromptJson();
        } catch (e, st) {
          RitmoLog.warning('PersonaContextProvider', 'Failed building reflection brief: $e', e, st);
          failedDomains.add('reflection');
        }
      }

      // Notes
      if (persona.canReadDomain(DataDomain.notes) && allowedDomains.contains(DataDomain.notes)) {
        try {
          combined['notes'] = (await _buildNotesBrief(db)).toPromptJson();
        } catch (e, st) {
          RitmoLog.warning('PersonaContextProvider', 'Failed building notes brief: $e', e, st);
          failedDomains.add('notes');
        }
      }

      // Cycle
      if (persona.id == 'cycle' && persona.canReadDomain(DataDomain.cycle) && allowedDomains.contains(DataDomain.cycle)) {
        try {
          combined['cycle'] = (await _buildCycleBrief(db)).toPromptJson();
        } catch (e, st) {
          RitmoLog.warning('PersonaContextProvider', 'Failed building cycle brief: $e', e, st);
          failedDomains.add('cycle');
        }
      }

      // Health / Medical
      if (persona.id == 'health' && persona.canReadDomain(DataDomain.medical) && allowedDomains.contains(DataDomain.medical)) {
        try {
          combined['health'] = (await _buildHealthBrief(db)).toPromptJson();
        } catch (e, st) {
          RitmoLog.warning('PersonaContextProvider', 'Failed building health brief: $e', e, st);
          failedDomains.add('health');
        }
      }

      // Global Rhythm (PSN-29)
      if (persona.id == 'global') {
        try {
          combined['rhythm'] = (await _buildRhythmBrief(db, combined.length)).toPromptJson();
        } catch (e, st) {
          RitmoLog.warning('PersonaContextProvider', 'Failed building rhythm brief: $e', e, st);
          failedDomains.add('rhythm');
        }
      }

      // PSN-32: Partial missing domains reporting
      if (failedDomains.isNotEmpty) {
        combined['partial_missing_domains'] = failedDomains;
      }
    } catch (e, st) {
      RitmoLog.error('PersonaContextProvider', 'Error assembling brief JSON: $e', e, st);
    }

    if (combined.isEmpty) return '{}';
    return jsonEncode(combined);
  }

  /// Returns the pool of valid field names for all domains included in the combined brief (PSN-28).
  static Future<Set<String>> getAllowedFieldNames(AssistantPersona persona, [dynamic dbExecutor]) async {
    final db = dbExecutor ?? await DatabaseHelper.instance.database;
    final allowedDomains = await PersonaGate.readableDomains(persona.id, db);
    final fieldSet = <String>{};

    if (allowedDomains.contains(DataDomain.routines)) {
      fieldSet.addAll(const [
        'routines.activeRoutinesCount',
        'routines.weeklyAdherencePercentage',
        'routines.longestStreak',
        'routines.remainingTodayCount',
      ]);
    }
    if (allowedDomains.contains(DataDomain.sleep)) {
      fieldSet.addAll(const [
        'sleep.avgDurationMinutes',
        'sleep.avgQuality',
        'sleep.sleepDebtMinutes',
        'sleep.consistencyScore',
        'sleep.bestBedtimeWindow',
      ]);
    }
    if (allowedDomains.contains(DataDomain.energy)) {
      fieldSet.addAll(const [
        'wellbeing.wellbeingScore',
        'wellbeing.energyLevelAvg',
        'wellbeing.recentMood',
      ]);
    }
    if (allowedDomains.contains(DataDomain.goals)) {
      fieldSet.addAll(const [
        'goals.activeGoalsCount',
        'goals.overallProgressPercentage',
        'goals.overdueStepsCount',
        'goals.deadGoalsCount',
      ]);
    }
    if (allowedDomains.contains(DataDomain.worship)) {
      fieldSet.addAll(const [
        'worship.activePracticesCount',
        'worship.totalDebtsCount',
      ]);
    }
    if (allowedDomains.contains(DataDomain.konkur)) {
      fieldSet.addAll(const [
        'konkur.activeSubjectsCount',
        'konkur.topPrioritySubject',
      ]);
    }
    if (allowedDomains.contains(DataDomain.courses)) {
      fieldSet.addAll(const [
        'courses.activeCoursesCount',
        'courses.weeklyTargetSessions',
        'courses.completedSessionsThisWeek',
      ]);
    }
    if (allowedDomains.contains(DataDomain.sports)) {
      fieldSet.addAll(const [
        'sports.sessionsLoggedThisWeek',
      ]);
    }
    if (allowedDomains.contains(DataDomain.reflection)) {
      fieldSet.addAll(const [
        'reflection.totalReflections',
      ]);
    }
    if (allowedDomains.contains(DataDomain.notes)) {
      fieldSet.addAll(const [
        'notes.totalActive',
        'notes.createdThisWeek',
        'notes.writingDayStreak',
        'notes.topTags',
        'notes.orphanCount',
        'notes.reviewDueCount',
        'notes.experienceCount',
        'notes.experienceActiveCount',
      ]);
    }
    if (persona.id == 'cycle' && allowedDomains.contains(DataDomain.cycle)) {
      fieldSet.addAll(const [
        'cycle.recordedSymptomLogsCount',
      ]);
    }
    if (persona.id == 'health' && allowedDomains.contains(DataDomain.medical)) {
      fieldSet.addAll(const [
        'health.adherencePercentage',
        'health.missedRoutinePatternCount',
      ]);
    }
    if (persona.id == 'global') {
      fieldSet.addAll(const [
        'rhythm.dailyCapacityMinutes',
        'rhythm.allocatedMinutes',
        'rhythm.activeDomainCount',
      ]);
    }

    return fieldSet;
  }

  static Future<DomainBrief?> getPrimaryBrief(AssistantPersona persona) async {
    try {
      final db = await DatabaseHelper.instance.database;
      switch (persona.id) {
        case 'sleep':
          return _buildSleepBrief(db);
        case 'wellbeing':
          return _buildWellbeingBrief(db);
        case 'goals':
          return _buildGoalsBrief(db);
        case 'worship':
          return _buildWorshipBrief(db);
        case 'konkur':
          return _buildStudyBrief(db);
        case 'courses':
          return _buildCoursesBrief(db);
        case 'sports':
          return _buildSportsBrief(db);
        case 'reflection':
          return _buildReflectionBrief(db);
        case 'notes':
          return _buildNotesBrief(db);
        case 'cycle':
          return _buildCycleBrief(db);
        case 'health':
          return _buildHealthBrief(db);
        case 'global':
          return _buildRhythmBrief(db, 5);
        default:
          return _buildRhythmBrief(db, 0);
      }
    } catch (e, st) {
      RitmoLog.warning('PersonaContextProvider', 'Failed getting primary brief for "${persona.id}": $e', e, st);
      return null;
    }
  }

  static Future<SleepTarget> _loadSleepTarget(dynamic db) async {
    String bedtime = '23:30';
    String wake = '07:00';
    int durationMinutes = 450;
    try {
      final rows = await db.query('app_settings', where: "key LIKE 'sleep_target_%'");
      for (final r in rows) {
        final k = r['key'] as String?;
        final v = r['value'] as String?;
        if (k == null || v == null) continue;
        if (k == 'sleep_target_bedtime') bedtime = v;
        if (k == 'sleep_target_wake') wake = v;
        if (k == 'sleep_target_duration_minutes') {
          durationMinutes = int.tryParse(v) ?? 450;
        }
      }
    } catch (e) {
      RitmoLog.debug('PersonaContextProvider', 'Could not parse sleep targets: $e');
    }
    return SleepTarget(bedtime: bedtime, wake: wake, durationMinutes: durationMinutes);
  }

  static List<SleepLog> _parseSleepLogs(List<dynamic> rows) {
    final logs = <SleepLog>[];
    for (final row in rows) {
      try {
        logs.add(SleepLog.fromMap(Map<String, dynamic>.from(row as Map)));
      } catch (e) {
        RitmoLog.debug('PersonaContextProvider', 'Could not parse sleep log: $e');
      }
    }
    return logs;
  }

  static double? _energyLevel1to3(String? raw) {
    if (raw == null) return null;
    final u = raw.toUpperCase();
    if (u == 'HIGH') return 3.0;
    if (u == 'MEDIUM') return 2.0;
    if (u == 'LOW') return 1.0;
    final n = double.tryParse(raw);
    if (n != null) return n.clamp(1.0, 3.0);
    return null;
  }

  // ────────────────────────────────────────── Individual Domain Brief Builders

  static Future<RoutinesBrief> _buildRoutinesBrief(dynamic db) async {
    final routines = await db.query('routines', where: 'isArchived = 0');
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);
    final weekAgoStr = DateTime.now().subtract(const Duration(days: 7)).toIso8601String().substring(0, 10);

    final completedToday = await db.query(
      'routine_completions',
      where: 'completionDate = ?',
      whereArgs: [todayStr],
    );
    final completedThisWeek = await db.query(
      'routine_completions',
      where: 'completionDate >= ?',
      whereArgs: [weekAgoStr],
    );

    final activeCount = routines.length;
    final remainingToday = (activeCount - completedToday.length).clamp(0, activeCount);
    final weeklyExpected = activeCount * 7;
    final adherence = weeklyExpected > 0 ? ((completedThisWeek.length / weeklyExpected) * 100).clamp(0, 100).toDouble() : 0.0;

    return RoutinesBrief(
      sampleSize: activeCount + completedThisWeek.length,
      computedAt: DateTime.now(),
      activeRoutinesCount: activeCount,
      weeklyAdherencePercentage: adherence,
      longestStreak: 5,
      remainingTodayCount: remainingToday,
    );
  }

  static Future<SleepBrief> _buildSleepBrief(dynamic db) async {
    final sleepRows = await db.query('bedtime_diagnostics', orderBy: 'date DESC', limit: 45);
    final energyRows = await db.query('energy_logs', orderBy: 'loggedAt DESC', limit: 200);
    final moodRows = await db.query('mood_logs', orderBy: 'loggedAt DESC', limit: 200);
    final logs = _parseSleepLogs(sleepRows);
    final target = await _loadSleepTarget(db);
    final out = await SleepEngine().calculate(
      SleepEngineInput(
        sleepLogs: logs,
        target: target,
        energyLogs: List<Map<String, dynamic>>.from(energyRows),
        moodLogs: List<Map<String, dynamic>>.from(moodRows),
        today: DateTime.now(),
        horizonDays: _horizonDays,
      ),
    );
    return SleepBrief.fromEngine(out, logs.length);
  }

  static Future<WellbeingBrief> _buildWellbeingBrief(dynamic db) async {
    final now = DateTime.now();
    final energyRows = await db.query('energy_logs', orderBy: 'loggedAt DESC', limit: 200);
    final moodRows = await db.query('mood_logs', orderBy: 'loggedAt DESC', limit: 200);
    final sleepRows = await db.query('bedtime_diagnostics', orderBy: 'date DESC', limit: 45);
    final reflectionRows = await db.query('daily_reflections', orderBy: 'date DESC', limit: 45);
    final sleepLogs = _parseSleepLogs(sleepRows);
    final target = await _loadSleepTarget(db);

    SleepEngineOutput? sleepOut;
    if (sleepLogs.isNotEmpty) {
      sleepOut = await SleepEngine().calculate(
        SleepEngineInput(
          sleepLogs: sleepLogs,
          target: target,
          energyLogs: List<Map<String, dynamic>>.from(energyRows),
          moodLogs: List<Map<String, dynamic>>.from(moodRows),
          today: now,
          horizonDays: _horizonDays,
        ),
      );
    }

    final energyScores = <double>[];
    for (final row in energyRows) {
      final score = _energyLevel1to3(row['energyLevel']?.toString());
      if (score != null) energyScores.add(score);
    }

    final moodScores = <double>[];
    String? recentMood;
    for (final row in moodRows) {
      final valence = row['valence'];
      if (valence is num) moodScores.add(valence.toDouble());
      if (recentMood == null) {
        final raw = row['mood']?.toString();
        if (raw != null && raw.isNotEmpty) {
          recentMood = Mood.fromString(raw).label;
        }
      }
    }

    final reflectionMoods = <double>[];
    for (final row in reflectionRows) {
      final score = row['mood_score'] ?? row['moodScore'];
      if (score is num) reflectionMoods.add(score.toDouble());
    }

    final avgSleepHours = sleepLogs.isEmpty
        ? null
        : sleepLogs.map((l) => l.durationHours).reduce((a, b) => a + b) / sleepLogs.length;
    final avgEnergy = energyScores.isEmpty
        ? null
        : energyScores.reduce((a, b) => a + b) / energyScores.length;
    final avgMood = moodScores.isEmpty
        ? null
        : moodScores.reduce((a, b) => a + b) / moodScores.length;
    final avgReflection = reflectionMoods.isEmpty
        ? null
        : reflectionMoods.reduce((a, b) => a + b) / reflectionMoods.length;

    final index = const WellbeingEngine().compute(
      WellbeingEngineInput(
        now: now,
        horizonDays: _horizonDays,
        sleepNights: sleepLogs.length,
        avgSleepHours: avgSleepHours,
        targetSleepHours: target.durationMinutes / 60.0,
        avgSleepQuality: sleepOut?.avgQuality,
        sleepConsistency: sleepOut?.consistencyScore,
        energySamples: energyScores.length,
        avgEnergyLevel: avgEnergy,
        moodSamples: moodScores.length,
        avgMoodScore: avgMood,
        reflectionEntries: reflectionRows.length,
        avgReflectionMood: avgReflection,
      ),
    );

    return WellbeingBrief(
      sampleSize: energyScores.length +
          moodScores.length +
          sleepLogs.length +
          (reflectionRows.length as int),
      computedAt: now,
      wellbeingScore: index.value,
      energyLevelAvg: avgEnergy,
      recentMood: recentMood,
    );
  }

  static Future<GoalsBrief> _buildGoalsBrief(dynamic db) async {
    final goals = await db.query('goals', where: "status = 'ACTIVE'");
    final steps = await db.query('goal_steps');
    final now = DateTime.now();
    var completed = 0;
    var overdue = 0;

    for (final step in steps) {
      final flag = step['isCompleted'];
      final done = flag == 1 || flag == true;
      if (done) {
        completed++;
      } else {
        // PSN-30: overdue only if step has due date and it has passed
        final dueRaw = step['dueDate'] ?? step['scheduledDate'];
        if (dueRaw != null) {
          final dueDt = DateTime.tryParse(dueRaw.toString());
          if (dueDt != null && dueDt.isBefore(now)) {
            overdue++;
          }
        }
      }
    }

    // Dead goals: active goals with 0 completed steps in last 14 days
    var deadCount = 0;
    final fourteenDaysAgo = now.subtract(const Duration(days: 14)).millisecondsSinceEpoch;
    for (final g in goals) {
      final gId = g['id'];
      final recentSteps = await db.query(
        'goal_steps',
        where: 'goalId = ? AND isCompleted = 1 AND completedAt >= ?',
        whereArgs: [gId, fourteenDaysAgo],
      );
      if (recentSteps.isEmpty) {
        deadCount++;
      }
    }

    final progress = steps.isEmpty ? 0.0 : (completed / steps.length) * 100.0;
    return GoalsBrief(
      sampleSize: goals.length + steps.length,
      computedAt: now,
      activeGoalsCount: goals.length,
      overallProgressPercentage: progress,
      overdueStepsCount: overdue,
      deadGoalsCount: deadCount,
    );
  }

  static Future<WorshipBrief> _buildWorshipBrief(dynamic db) async {
    final practices = await db.query('worship_practices');
    final debts = await db.query('worship_debts');
    return WorshipBrief(
      sampleSize: practices.length + debts.length,
      computedAt: DateTime.now(),
      activePracticesCount: practices.length,
      totalDebtsCount: debts.length,
    );
  }

  static Future<StudyBrief> _buildStudyBrief(dynamic db) async {
    // PSN-30: explicit sort by priority DESC, name ASC
    List<Map<String, dynamic>> subjects;
    try {
      subjects = await db.query('konkur_subjects', orderBy: 'priority DESC, name ASC');
    } catch (_) {
      subjects = await db.query('konkur_subjects', orderBy: 'name ASC');
    }
    return StudyBrief(
      sampleSize: subjects.length,
      computedAt: DateTime.now(),
      activeSubjectsCount: subjects.length,
      topPrioritySubject:
          subjects.isNotEmpty ? (subjects.first['name'] as String?) : null,
    );
  }

  static Future<CoursesBrief> _buildCoursesBrief(dynamic db) async {
    final courses = await db.query('courses', where: "status = 'ACTIVE'");
    final weekAgo = DateTime.now().subtract(const Duration(days: 7)).millisecondsSinceEpoch;
    var completedThisWeek = 0;
    var weeklyTarget = 0;

    for (final c in courses) {
      final targetPerWeek = (c['targetSessionsPerWeek'] ?? c['sessionsPerWeek'] ?? 2) as int;
      weeklyTarget += targetPerWeek;
      final cId = c['id'];
      try {
        final sessions = await db.query(
          'course_sessions',
          where: 'courseId = ? AND completedAt >= ?',
          whereArgs: [cId, weekAgo],
        );
        completedThisWeek += sessions.length as int;
      } catch (_) {}
    }

    return CoursesBrief(
      sampleSize: courses.length + completedThisWeek,
      computedAt: DateTime.now(),
      activeCoursesCount: courses.length,
      weeklyTargetSessions: weeklyTarget,
      completedSessionsThisWeek: completedThisWeek,
    );
  }

  static Future<SportsBrief> _buildSportsBrief(dynamic db) async {
    final weekAgo = DateTime.now().subtract(const Duration(days: 7)).millisecondsSinceEpoch;
    List<dynamic> logs = const [];
    try {
      logs = await db.query(
        'workout_logs',
        where: 'loggedAt >= ?',
        whereArgs: [weekAgo],
      );
    } catch (_) {
      logs = await db.query('workout_logs', limit: 10);
    }
    return SportsBrief(
      sampleSize: logs.length,
      computedAt: DateTime.now(),
      sessionsLoggedThisWeek: logs.length,
    );
  }

  static Future<ReflectionBrief> _buildReflectionBrief(dynamic db) async {
    final reflections = await db.query('daily_reflections', limit: 14);
    return ReflectionBrief(
      sampleSize: reflections.length,
      computedAt: DateTime.now(),
      totalReflections: reflections.length,
    );
  }

  static Future<NotesBrief> _buildNotesBrief(dynamic db) async {
    final notes = await db.query(
      'notes',
      where: 'isArchived = 0 AND $kNotesAiVisibilityClause',
    );
    final experiences = await db.query('experiences', where: 'isArchived = 0');
    final weekAgo = DateTime.now().subtract(const Duration(days: 7)).millisecondsSinceEpoch;

    var createdThisWeek = 0;
    var orphanCount = 0;
    var reviewDueCount = 0;
    final tagCounts = <String, int>{};
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    for (final n in notes) {
      final created = n['createdAt'] as int?;
      if (created != null && created >= weekAgo) {
        createdThisWeek++;
      }
      final tagsRaw = n['tags']?.toString() ?? '';
      if (tagsRaw.isEmpty) {
        orphanCount++;
      } else {
        for (final tag in tagsRaw.split(',')) {
          final t = tag.trim();
          if (t.isNotEmpty) {
            tagCounts[t] = (tagCounts[t] ?? 0) + 1;
          }
        }
      }
      final reviewDue = n['reviewDueDate'] as int?;
      if (reviewDue != null && reviewDue <= nowMs) {
        reviewDueCount++;
      }
    }

    final sortedTags = tagCounts.keys.toList()
      ..sort((a, b) => tagCounts[b]!.compareTo(tagCounts[a]!));
    final topTags = sortedTags.take(5).toList();

    return NotesBrief(
      sampleSize: notes.length + experiences.length,
      computedAt: DateTime.now(),
      totalActive: notes.length,
      createdThisWeek: createdThisWeek,
      writingDayStreak: createdThisWeek > 0 ? (createdThisWeek > 7 ? 7 : createdThisWeek) : 0,
      topTags: topTags,
      orphanCount: orphanCount,
      reviewDueCount: reviewDueCount,
      experienceCount: experiences.length,
      experienceActiveCount: experiences.length,
    );
  }

  static Future<CycleBrief> _buildCycleBrief(dynamic db) async {
    final logs = await db.query('cycle_day_logs', limit: 10);
    return CycleBrief(
      sampleSize: logs.length,
      computedAt: DateTime.now(),
      recordedSymptomLogsCount: logs.length,
    );
  }

  static Future<AdherenceBrief> _buildHealthBrief(dynamic db) async {
    final meds = await db.query(
      'routines',
      where: "category = 'medical' AND isArchived = 0",
    );
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);
    var totalDoses = 0;
    var taken = 0;
    for (final r in meds) {
      final maxDoses = (r['maxDosesPerDay'] as int?) ?? 1;
      totalDoses += maxDoses <= 0 ? 1 : maxDoses;
      try {
        final completions = await db.query(
          'routine_completions',
          where: 'routineId = ? AND completionDate = ?',
          whereArgs: [r['id'], todayStr],
        );
        taken += completions.length as int;
      } catch (e) {
        RitmoLog.debug('PersonaContextProvider', 'Could not query routine completions: $e');
      }
    }
    final pct = totalDoses > 0 ? ((taken / totalDoses) * 100).clamp(0, 100).toDouble() : 0.0;
    return AdherenceBrief(
      sampleSize: meds.length,
      computedAt: DateTime.now(),
      adherencePercentage: pct,
      missedRoutinePatternCount: 0,
    );
  }

  static Future<RhythmBrief> _buildRhythmBrief(dynamic db, int activeDomainsCount) async {
    final target = await _loadSleepTarget(db);
    final dailyCapacity = (1440 - target.durationMinutes - 120).clamp(300, 1000);

    int allocatedMinutes = 0;
    try {
      final activeRoutines = await db.query('routines', where: 'isArchived = 0');
      for (final r in activeRoutines) {
        allocatedMinutes += (r['durationMinutes'] as int?) ?? 15;
      }
    } catch (_) {}

    return RhythmBrief(
      sampleSize: activeDomainsCount > 0 ? activeDomainsCount * 5 : 1,
      computedAt: DateTime.now(),
      dailyCapacityMinutes: dailyCapacity,
      allocatedMinutes: allocatedMinutes,
      activeDomainCount: activeDomainsCount,
    );
  }
}
