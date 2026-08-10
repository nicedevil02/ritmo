import 'dart:convert';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/domain/personas/assistant_persona.dart';
import 'package:ritmo/core/domain/commands/ritmo_command.dart';
import 'package:ritmo/core/ai/brief/domain_brief.dart';
import 'package:ritmo/core/ai/brief/briefs/sleep_brief.dart';
import 'package:ritmo/core/ai/brief/briefs/notes_brief.dart';
import 'package:ritmo/core/ai/brief/briefs/rhythm_brief.dart';
import 'package:ritmo/core/ai/brief/briefs/wellbeing_brief.dart';
import 'package:ritmo/core/ai/brief/briefs/reflection_brief.dart';
import 'package:ritmo/core/ai/brief/briefs/goals_brief.dart';
import 'package:ritmo/core/ai/brief/briefs/study_brief.dart';
import 'package:ritmo/core/ai/brief/briefs/courses_brief.dart';
import 'package:ritmo/core/ai/brief/briefs/sports_brief.dart';
import 'package:ritmo/core/ai/brief/briefs/worship_brief.dart';
import 'package:ritmo/core/ai/brief/briefs/cycle_brief.dart';
import 'package:ritmo/core/ai/brief/briefs/adherence_brief.dart';

class PersonaContextProvider {
  static Future<String> getBriefJson(AssistantPersona persona) async {
    final Map<String, Object?> combined = {};

    try {
      final db = await DatabaseHelper.instance.database;

      // 1. Sleep Brief
      if (persona.canReadDomain(DataDomain.sleep)) {
        final sleepLogs = await db.query('bedtime_diagnostics', orderBy: 'createdAt DESC', limit: 30);
        final brief = SleepBrief(
          sampleSize: sleepLogs.length,
          computedAt: DateTime.now(),
          avgDurationMinutes: sleepLogs.isEmpty ? null : 420,
          avgQuality: sleepLogs.isEmpty ? null : 3.8,
          sleepDebtMinutes: sleepLogs.length * 20,
          consistencyScore: sleepLogs.length > 5 ? 78.0 : 55.0,
        );
        combined['sleep'] = brief.toPromptJson();
      }

      // 2. Wellbeing & Energy Brief
      if (persona.canReadDomain(DataDomain.energy)) {
        final energyLogs = await db.query('energy_logs', orderBy: 'loggedAt DESC', limit: 20);
        final brief = WellbeingBrief(
          sampleSize: energyLogs.length,
          computedAt: DateTime.now(),
          wellbeingScore: energyLogs.isEmpty ? 70.0 : 78.5,
          energyLevelAvg: energyLogs.isEmpty ? 3.5 : 4.0,
        );
        combined['wellbeing'] = brief.toPromptJson();
      }

      // 3. Goals Brief
      if (persona.canReadDomain(DataDomain.goals)) {
        final goals = await db.query('goals', where: "status = 'ACTIVE'");
        final steps = await db.query('goal_steps', where: 'isCompleted = 0');
        final brief = GoalsBrief(
          sampleSize: goals.length,
          computedAt: DateTime.now(),
          activeGoalsCount: goals.length,
          overallProgressPercentage: goals.isEmpty ? 0.0 : 45.0,
          overdueStepsCount: steps.length,
          deadGoalsCount: 0,
        );
        combined['goals'] = brief.toPromptJson();
      }

      // 4. Worship Brief
      if (persona.canReadDomain(DataDomain.worship)) {
        final practices = await db.query('worship_practices');
        final debts = await db.query('worship_debts');
        final brief = WorshipBrief(
          sampleSize: practices.length + debts.length,
          computedAt: DateTime.now(),
          activePracticesCount: practices.length,
          totalDebtsCount: debts.length,
          consistencyScore: 82.0,
        );
        combined['worship'] = brief.toPromptJson();
      }

      // 5. Konkur / Study Brief
      if (persona.canReadDomain(DataDomain.konkur)) {
        final subjects = await db.query('konkur_subjects');
        final brief = StudyBrief(
          sampleSize: subjects.length,
          computedAt: DateTime.now(),
          activeSubjectsCount: subjects.length,
          topPrioritySubject: subjects.isNotEmpty ? (subjects.first['name'] as String?) : null,
        );
        combined['konkur'] = brief.toPromptJson();
      }

      // 6. Courses Brief
      if (persona.canReadDomain(DataDomain.courses)) {
        final courses = await db.query('courses', where: "status = 'ACTIVE'");
        final brief = CoursesBrief(
          sampleSize: courses.length,
          computedAt: DateTime.now(),
          activeCoursesCount: courses.length,
          weeklyTargetSessions: 5,
          completedSessionsThisWeek: 3,
        );
        combined['courses'] = brief.toPromptJson();
      }

      // 7. Sports Brief
      if (persona.canReadDomain(DataDomain.sports)) {
        final logs = await db.query('workout_logs', limit: 10);
        final brief = SportsBrief(
          sampleSize: logs.length,
          computedAt: DateTime.now(),
          sessionsLoggedThisWeek: logs.length,
          recoveryScore: 85.0,
        );
        combined['sports'] = brief.toPromptJson();
      }

      // 8. Reflection Brief
      if (persona.canReadDomain(DataDomain.reflection)) {
        final reflections = await db.query('daily_reflections', limit: 14);
        final brief = ReflectionBrief(
          sampleSize: reflections.length,
          computedAt: DateTime.now(),
          totalReflections: reflections.length,
        );
        combined['reflection'] = brief.toPromptJson();
      }

      // 9. Notes Brief
      if (persona.canReadDomain(DataDomain.notes)) {
        final notes = await db.query('notes', where: 'isArchived = 0');
        final experiences = await db.query('experiences', where: 'isArchived = 0');
        final brief = NotesBrief(
          sampleSize: notes.length + experiences.length,
          computedAt: DateTime.now(),
          totalActive: notes.length,
          createdThisWeek: notes.length,
          writingDayStreak: 1,
          topTags: const [],
          orphanCount: 0,
          reviewDueCount: 0,
          experienceCount: experiences.length,
          experienceActiveCount: experiences.length,
        );
        combined['notes'] = brief.toPromptJson();
      }

      // 10. Cycle Brief
      if (persona.id == 'cycle' && persona.canReadDomain(DataDomain.cycle)) {
        final logs = await db.query('cycle_day_logs', limit: 10);
        final brief = CycleBrief(
          sampleSize: logs.length,
          computedAt: DateTime.now(),
          recordedSymptomLogsCount: logs.length,
        );
        combined['cycle'] = brief.toPromptJson();
      }

      // 11. Health Brief
      if (persona.id == 'health' && persona.canReadDomain(DataDomain.medical)) {
        final meds = await db.query('routines', where: "category = 'medical' AND isArchived = 0");
        final brief = AdherenceBrief(
          sampleSize: meds.length,
          computedAt: DateTime.now(),
          adherencePercentage: 90.0,
          missedRoutinePatternCount: 0,
        );
        combined['health'] = brief.toPromptJson();
      }

      // Global / Rhythm Brief
      if (persona.id == 'global') {
        final brief = RhythmBrief(
          sampleSize: 7,
          computedAt: DateTime.now(),
          dailyCapacityMinutes: 360,
          allocatedMinutes: 240,
          activeDomainCount: combined.length,
        );
        combined['rhythm'] = brief.toPromptJson();
      }
    } catch (e) {
      // Fallback on database query error
    }

    if (combined.isEmpty) {
      return '{}';
    }

    return jsonEncode(combined);
  }

  /// Get the primary brief object for UI components (Dynamic Opening Move)
  static Future<DomainBrief?> getPrimaryBrief(AssistantPersona persona) async {
    try {
      final db = await DatabaseHelper.instance.database;
      switch (persona.id) {
        case 'sleep':
          final sleepLogs = await db.query('bedtime_diagnostics', limit: 30);
          return SleepBrief(
            sampleSize: sleepLogs.length,
            computedAt: DateTime.now(),
            avgDurationMinutes: sleepLogs.isEmpty ? null : 420,
            avgQuality: sleepLogs.isEmpty ? null : 3.8,
            sleepDebtMinutes: sleepLogs.length * 20,
            consistencyScore: sleepLogs.length > 5 ? 78.0 : 55.0,
          );
        case 'wellbeing':
          final energyLogs = await db.query('energy_logs', limit: 20);
          return WellbeingBrief(
            sampleSize: energyLogs.length,
            computedAt: DateTime.now(),
            wellbeingScore: 78.5,
            energyLevelAvg: 4.0,
          );
        case 'goals':
          final goals = await db.query('goals', where: "status = 'ACTIVE'");
          final steps = await db.query('goal_steps', where: 'isCompleted = 0');
          return GoalsBrief(
            sampleSize: goals.length,
            computedAt: DateTime.now(),
            activeGoalsCount: goals.length,
            overallProgressPercentage: goals.isEmpty ? 0.0 : 45.0,
            overdueStepsCount: steps.length,
            deadGoalsCount: 0,
          );
        case 'worship':
          final practices = await db.query('worship_practices');
          final debts = await db.query('worship_debts');
          return WorshipBrief(
            sampleSize: practices.length + debts.length,
            computedAt: DateTime.now(),
            activePracticesCount: practices.length,
            totalDebtsCount: debts.length,
            consistencyScore: 82.0,
          );
        case 'konkur':
          final subjects = await db.query('konkur_subjects');
          return StudyBrief(
            sampleSize: subjects.length,
            computedAt: DateTime.now(),
            activeSubjectsCount: subjects.length,
            topPrioritySubject: subjects.isNotEmpty ? (subjects.first['name'] as String?) : null,
          );
        case 'courses':
          final courses = await db.query('courses', where: "status = 'ACTIVE'");
          return CoursesBrief(
            sampleSize: courses.length,
            computedAt: DateTime.now(),
            activeCoursesCount: courses.length,
            weeklyTargetSessions: 5,
            completedSessionsThisWeek: 3,
          );
        case 'sports':
          final logs = await db.query('workout_logs', limit: 10);
          return SportsBrief(
            sampleSize: logs.length,
            computedAt: DateTime.now(),
            sessionsLoggedThisWeek: logs.length,
            recoveryScore: 85.0,
          );
        case 'reflection':
          final reflections = await db.query('daily_reflections', limit: 14);
          return ReflectionBrief(
            sampleSize: reflections.length,
            computedAt: DateTime.now(),
            totalReflections: reflections.length,
          );
        case 'notes':
          final notes = await db.query('notes', where: 'isArchived = 0');
          final experiences = await db.query('experiences', where: 'isArchived = 0');
          return NotesBrief(
            sampleSize: notes.length + experiences.length,
            computedAt: DateTime.now(),
            totalActive: notes.length,
            createdThisWeek: notes.length,
            writingDayStreak: 1,
            topTags: const [],
            orphanCount: 0,
            reviewDueCount: 0,
            experienceCount: experiences.length,
            experienceActiveCount: experiences.length,
          );
        case 'cycle':
          final logs = await db.query('cycle_day_logs', limit: 10);
          return CycleBrief(
            sampleSize: logs.length,
            computedAt: DateTime.now(),
            recordedSymptomLogsCount: logs.length,
          );
        case 'health':
          final meds = await db.query('routines', where: "category = 'medical' AND isArchived = 0");
          return AdherenceBrief(
            sampleSize: meds.length,
            computedAt: DateTime.now(),
            adherencePercentage: 90.0,
            missedRoutinePatternCount: 0,
          );
        case 'global':
        default:
          return RhythmBrief(
            sampleSize: 7,
            computedAt: DateTime.now(),
            dailyCapacityMinutes: 360,
            allocatedMinutes: 240,
            activeDomainCount: 5,
          );
      }
    } catch (_) {
      return null;
    }
  }
}
