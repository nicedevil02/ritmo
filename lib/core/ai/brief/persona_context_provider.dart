import 'dart:convert';
import 'package:ritmo/core/ai/brief/briefs/adherence_brief.dart';
import 'package:ritmo/core/ai/brief/briefs/courses_brief.dart';
import 'package:ritmo/core/ai/brief/briefs/cycle_brief.dart';
import 'package:ritmo/core/ai/brief/briefs/goals_brief.dart';
import 'package:ritmo/core/ai/brief/briefs/notes_brief.dart';
import 'package:ritmo/core/ai/brief/briefs/reflection_brief.dart';
import 'package:ritmo/core/ai/brief/briefs/rhythm_brief.dart';
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
import 'package:ritmo/features/energy/models/energy_mood_models.dart';
import 'package:ritmo/features/sleep/models/sleep_models.dart';

class PersonaContextProvider {
  static const int _horizonDays = 14;

  static Future<String> getBriefJson(AssistantPersona persona) async {
    final Map<String, Object?> combined = {};

    try {
      final db = await DatabaseHelper.instance.database;

      if (persona.canReadDomain(DataDomain.sleep)) {
        combined['sleep'] = (await _buildSleepBrief(db)).toPromptJson();
      }

      if (persona.canReadDomain(DataDomain.energy)) {
        combined['wellbeing'] = (await _buildWellbeingBrief(db)).toPromptJson();
      }

      if (persona.canReadDomain(DataDomain.goals)) {
        combined['goals'] = (await _buildGoalsBrief(db)).toPromptJson();
      }

      if (persona.canReadDomain(DataDomain.worship)) {
        combined['worship'] = (await _buildWorshipBrief(db)).toPromptJson();
      }

      if (persona.canReadDomain(DataDomain.konkur)) {
        combined['konkur'] = (await _buildStudyBrief(db)).toPromptJson();
      }

      if (persona.canReadDomain(DataDomain.courses)) {
        combined['courses'] = (await _buildCoursesBrief(db)).toPromptJson();
      }

      if (persona.canReadDomain(DataDomain.sports)) {
        combined['sports'] = (await _buildSportsBrief(db)).toPromptJson();
      }

      if (persona.canReadDomain(DataDomain.reflection)) {
        combined['reflection'] = (await _buildReflectionBrief(db)).toPromptJson();
      }

      if (persona.canReadDomain(DataDomain.notes)) {
        combined['notes'] = (await _buildNotesBrief(db)).toPromptJson();
      }

      if (persona.id == 'cycle' && persona.canReadDomain(DataDomain.cycle)) {
        combined['cycle'] = (await _buildCycleBrief(db)).toPromptJson();
      }

      if (persona.id == 'health' && persona.canReadDomain(DataDomain.medical)) {
        combined['health'] = (await _buildHealthBrief(db)).toPromptJson();
      }

      if (persona.id == 'global') {
        combined['rhythm'] = RhythmBrief(
          sampleSize: combined.length,
          computedAt: DateTime.now(),
          dailyCapacityMinutes: 0,
          allocatedMinutes: 0,
          activeDomainCount: combined.length,
        ).toPromptJson();
      }
    } catch (_) {
      // Fallback on database query error — return whatever was built.
    }

    if (combined.isEmpty) return '{}';
    return jsonEncode(combined);
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
        default:
          return RhythmBrief(
            sampleSize: 0,
            computedAt: DateTime.now(),
            dailyCapacityMinutes: 0,
            allocatedMinutes: 0,
            activeDomainCount: 0,
          );
      }
    } catch (_) {
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
    } catch (_) {}
    return SleepTarget(bedtime: bedtime, wake: wake, durationMinutes: durationMinutes);
  }

  static List<SleepLog> _parseSleepLogs(List<dynamic> rows) {
    final logs = <SleepLog>[];
    for (final row in rows) {
      try {
        logs.add(SleepLog.fromMap(Map<String, dynamic>.from(row as Map)));
      } catch (_) {}
    }
    return logs;
  }

  static double? _energyLevel1to3(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    switch (raw.toUpperCase()) {
      case 'HIGH':
        return 3.0;
      case 'MEDIUM':
        return 2.0;
      case 'LOW':
        return 1.0;
      default:
        return null;
    }
  }

  static Future<SleepBrief> _buildSleepBrief(dynamic db) async {
    final now = DateTime.now();
    final sleepRows = await db.query('sleep_logs', orderBy: 'date DESC', limit: 45);
    final energyRows = await db.query('energy_logs', orderBy: 'loggedAt DESC', limit: 200);
    final moodRows = await db.query('mood_logs', orderBy: 'loggedAt DESC', limit: 200);
    final logs = _parseSleepLogs(sleepRows);
    final out = await SleepEngine().calculate(
      SleepEngineInput(
        sleepLogs: logs,
        target: await _loadSleepTarget(db),
        energyLogs: List<Map<String, dynamic>>.from(energyRows),
        moodLogs: List<Map<String, dynamic>>.from(moodRows),
        today: now,
        horizonDays: _horizonDays,
      ),
    );
    return SleepBrief.fromEngine(out, logs.length);
  }

  static Future<WellbeingBrief> _buildWellbeingBrief(dynamic db) async {
    final now = DateTime.now();
    final energyRows = await db.query('energy_logs', orderBy: 'loggedAt DESC', limit: 200);
    final moodRows = await db.query('mood_logs', orderBy: 'loggedAt DESC', limit: 200);
    final sleepRows = await db.query('sleep_logs', orderBy: 'date DESC', limit: 45);
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
          reflectionRows.length,
      computedAt: now,
      wellbeingScore: index.value,
      energyLevelAvg: avgEnergy,
      recentMood: recentMood,
    );
  }

  static Future<GoalsBrief> _buildGoalsBrief(dynamic db) async {
    final goals = await db.query('goals', where: "status = 'ACTIVE'");
    final steps = await db.query('goal_steps');
    var completed = 0;
    var incomplete = 0;
    for (final step in steps) {
      final flag = step['isCompleted'];
      final done = flag == 1 || flag == true;
      if (done) {
        completed++;
      } else {
        incomplete++;
      }
    }
    final progress = steps.isEmpty ? 0.0 : (completed / steps.length) * 100.0;
    return GoalsBrief(
      sampleSize: goals.length,
      computedAt: DateTime.now(),
      activeGoalsCount: goals.length,
      overallProgressPercentage: progress,
      overdueStepsCount: incomplete,
      deadGoalsCount: 0,
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
    final subjects = await db.query('konkur_subjects');
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
    return CoursesBrief(
      sampleSize: courses.length,
      computedAt: DateTime.now(),
      activeCoursesCount: courses.length,
      weeklyTargetSessions: 0,
      completedSessionsThisWeek: 0,
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
    return NotesBrief(
      sampleSize: notes.length + experiences.length,
      computedAt: DateTime.now(),
      totalActive: notes.length,
      createdThisWeek: 0,
      writingDayStreak: 0,
      topTags: const [],
      orphanCount: 0,
      reviewDueCount: 0,
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
      } catch (_) {}
    }
    final pct = totalDoses > 0 ? ((taken / totalDoses) * 100).clamp(0, 100).toDouble() : 0.0;
    return AdherenceBrief(
      sampleSize: meds.length,
      computedAt: DateTime.now(),
      adherencePercentage: pct,
      missedRoutinePatternCount: 0,
    );
  }
}
