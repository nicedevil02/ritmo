import 'package:ritmo/core/database/migration/migration_interface.dart';
import 'package:ritmo/core/database/migration/migrations_registry.dart';
import 'package:sqflite/sqflite.dart';

import 'package:ritmo/core/logging/ritmo_logger.dart';

import 'package:ritmo/core/database/migration/migrations/migration_v66_worship_seed.dart';
import 'package:ritmo/core/database/migration/migrations/migration_v67_worship_schema.dart';
import 'package:ritmo/core/database/migration/migrations/migration_v68_worship_backfill.dart';
import 'package:ritmo/core/database/migration/migrations/migration_v69_calendar_occurrence_overrides.dart';
import 'package:ritmo/core/database/migration/migrations/migration_v70_course_skip_reason.dart';
import 'package:ritmo/core/database/migration/migrations/migration_v71_motivation_cognitive.dart';
import 'package:ritmo/core/database/migration/migrations/migration_v72_cleanup.dart';
import 'package:ritmo/core/database/migration/migrations/migration_v73_study_schema.dart';
import 'package:ritmo/core/database/migration/migrations/migration_v74_psych_layer_settings.dart';
import 'package:ritmo/core/database/migration/migrations/migration_v75_notification_reliability.dart';
import 'package:ritmo/core/database/migration/migrations/migration_v76_simple_mode.dart';
import 'package:ritmo/core/database/migration/migrations/migration_v77_ai_connection.dart';
import 'package:ritmo/core/database/migration/migrations/migration_v78_settings_profile.dart';
import 'package:ritmo/core/database/migration/migrations/migration_v79_task_upgrade.dart';
import 'package:ritmo/core/database/migration/migrations/migration_v80_ai_opencode_defaults.dart';
import 'package:ritmo/core/database/migration/migrations/migration_v81_agent_layer.dart';
import 'package:ritmo/core/database/migration/migrations/migration_v82_sports_prescription.dart';
import 'package:ritmo/core/database/migration/migrations/migration_v83_calendar_upgrade.dart';
import 'package:ritmo/core/database/migration/migrations/migration_v84_module_ownership.dart';
import 'package:ritmo/core/database/migration/migrations/migration_v85_simple_tasks_title_normalized.dart';
import 'package:ritmo/core/database/migration/migrations/migration_v86_notes.dart';
import 'package:ritmo/core/database/migration/migrations/migration_v87_planning.dart';
import 'package:ritmo/core/database/migration/migrations/migration_v88_audit_fixes.dart';
import 'package:ritmo/core/database/migration/migrations/migration_v89_pregnancy_data_sync.dart';
import 'package:ritmo/core/database/migration/migrations/migration_v90_sports_integrity.dart';
import 'package:ritmo/core/database/migration/migrations/migration_v91_schema_canonicalization.dart';
import 'package:ritmo/core/database/migration/migrations/migration_v92_unification.dart';
import 'package:ritmo/core/database/migration/migrations/migration_v93_app_start_date.dart';
import 'package:ritmo/core/database/migration/migrations/migration_v94_worship_debts_fix.dart';
import 'package:ritmo/core/database/migration/migrations/migration_v95_movement_live_sessions.dart';
import 'package:ritmo/core/database/migration/migrations/migration_v96_onboarding_starter_category.dart';
import 'package:ritmo/core/database/migration/migrations/migration_v97_course_session_question_resolved.dart';
import 'package:ritmo/core/database/migration/migrations/migration_v98_movement_slot_overrides.dart';
import 'package:ritmo/core/database/migration/migrations/migration_v99_movement_muscle_focus.dart';
import 'package:ritmo/core/database/migration/migrations/migration_v100_sleep_program.dart';
import 'package:ritmo/core/database/migration/migrations/migration_v101_notification_control_center.dart';
import 'package:ritmo/core/database/migration/migrations/migration_v102_unify_one_off_tasks.dart';
import 'package:ritmo/core/database/migration/migrations/migration_v103_unify_day_plan_columns.dart';
import 'package:ritmo/core/database/migration/migrations/migration_v104_worship_day_exceptions.dart';
import 'package:ritmo/core/database/migration/migrations/migration_v105_canonical_schema_parity.dart';
import 'package:ritmo/core/database/migration/migrations/migration_v106_movement_greenfield.dart';
import 'package:ritmo/core/database/migration/migrations/migration_v107_movement_planning.dart';
import 'package:ritmo/core/database/migration/migrations/migration_v108_movement_live_events.dart';
import 'package:ritmo/core/database/migration/migrations/migration_v109_movement_strength_tables.dart';
import 'package:ritmo/core/database/migration/migrations/migration_v110_movement_readiness_preferences_pr_tables.dart';
import 'package:ritmo/core/database/migration/migrations/migration_v111_medication_identity_backfill.dart';
import 'package:ritmo/core/database/migration/migrations/migration_v112_medication_profiles.dart';
import 'package:ritmo/core/database/migration/migrations/migration_v113_cycle_confirmations.dart';
import 'package:ritmo/core/database/migration/migrations/migration_v114_cycle_fertility_cleanup.dart';
import 'package:ritmo/core/database/migration/migrations/migration_v115_my_day.dart';
import 'package:ritmo/core/database/migration/migrations/migration_v116_tags_and_normalized_fields.dart';
import 'package:ritmo/core/database/migration/migrations/migration_v117_cycle_hardening.dart';
import 'package:ritmo/core/database/migration/migrations/migration_v118_medication_integrity_and_safety.dart';
import 'package:ritmo/core/database/migration/migrations/migration_v119_konkur_study_isolation.dart';
import 'package:ritmo/core/database/migration/migrations/migration_v120_study_deadlines_and_pomodoro.dart';
import 'package:ritmo/core/database/migration/migrations/migration_v121_sports_unification.dart';

class MigrationRunner {
  static final List<Migration> _migrations = [
    MigrationV2(),
    MigrationV3(),
    MigrationV4(),
    MigrationV5(),
    MigrationV6(),
    MigrationV7(),
    MigrationV8(),
    MigrationV9(),
    MigrationV10(),
    MigrationV11(),
    MigrationV12(),
    MigrationV13(),
    MigrationV14(),
    MigrationV15(),
    MigrationV16(),
    MigrationV17(),
    MigrationV18(),
    MigrationV19(),
    MigrationV20(),
    MigrationV21(),
    MigrationV22(),
    MigrationV23(),
    MigrationV24(),
    MigrationV25(),
    MigrationV26(),
    MigrationV27(),
    MigrationV28(),
    MigrationV29(),
    MigrationV30(),
    MigrationV31(),
    MigrationV32(),
    MigrationV33(),
    MigrationV34(),
    MigrationV35(),
    MigrationV36(),
    MigrationV37(),
    MigrationV38(),
    MigrationV39(),
    MigrationV40(),
    MigrationV41(),
    MigrationV42(),
    MigrationV43(),
    MigrationV44(),
    MigrationV45(),
    MigrationV46(),
    MigrationV47(),
    MigrationV48(),
    MigrationV49(),
    MigrationV50(),
    MigrationV51(),
    MigrationV52(),
    MigrationV53(),
    MigrationV54(),
    MigrationV55(),
    MigrationV56(),
    MigrationV57(),
    MigrationV58(),
    MigrationV59(),
    MigrationV60(),
    MigrationV61(),
    MigrationV62(), // T3(p045): deduplicate routine_completions for non-interval routines
    MigrationV63(), // Fix active_timers schema alignment & legacy NOT NULL constraint compatibility
    MigrationV64(), // Prompt 046 goals schema migration M1-M4
    MigrationV65(), // Prompt 049 wellbeing daily table and performance indexes
    MigrationV66(),
    MigrationV67(),
    MigrationV68(),
    MigrationV69(),
    MigrationV70CourseSkipReason(), // Prompt 056: Add skipReason column to course_sessions
    MigrationV71MotivationCognitive(), // Prompt 059: Motivation diagnosis, cognitive load & identity habit columns
    MigrationV72Cleanup(), // Prompt 055: Drop deprecated zones, zone_schedules & worship_seasons tables
    MigrationV73StudySchema(), // Prompt 056: Study module schema refactoring
    MigrationV74PsychLayerSettings(), // Prompt 060: Psychology layer settings
    MigrationV75NotificationReliability(), // Prompt 061: Notification reliability & full-screen alarm
    MigrationV76SimpleMode(), // Prompt 057: Simple Mode & tasks table
    MigrationV77AiConnection(), // Prompt 062: AI Connection mode, presets, timeout and model cleanups
    MigrationV78SettingsProfile(), // Prompt 058: Settings registry, quiet hours, PIN split, dead keys cleanup
    MigrationV79TaskUpgrade(), // Prompt 063: Task steps, importance, attachments
    MigrationV80AiOpencodeDefaults(), // OpenCode AI default configuration
    MigrationV81AgentLayer(),
    MigrationV82SportsPrescription(),
    MigrationV83CalendarUpgrade(), // Prompt 067: day_marks table + calendar default settings
    MigrationV84(),
    MigrationV85(),
    MigrationV86Notes(),
    MigrationV87Planning(),
    MigrationV88AuditFixes(),
    MigrationV89PregnancyDataSync(),
    MigrationV90SportsIntegrity(),
    MigrationV91SchemaCanonicalization(),
    MigrationV92Unification(),
    MigrationV93AppStartDate(),
    MigrationV94(),
    MigrationV95(),
    MigrationV96OnboardingStarterCategory(), // Fix: recategorize onboarding starter habits out of fitness (sports)
    MigrationV97SessionQuestionResolved(), // Persist resolved state of course session open questions
    MigrationV98MovementSlotOverrides(), // Tab 1: this-week exceptions for movement slots
    MigrationV99MovementMuscleFocus(), // Tab 1: muscle focus for strength movements
    MigrationV100SleepProgram(), // قدم ۲ مسیر خواب: sleep_programs + sleep_plan_days
    MigrationV101NotificationControlCenter(), // Notification Control Center and Privacy Engine
    MigrationV102UnifyOneOffTasks(), // Unify one-off tasks from routines into simple_tasks
    MigrationV103UnifyDayPlanColumns(), // Unify day_plan_templates & day_plan_commits columns to canonical camelCase
    MigrationV104WorshipDayExceptions(), // Worship day exceptions and occurrence overrides
    MigrationV105CanonicalSchemaParity(), // Backfill missing tables to ensure full canonical parity
    MigrationV106MovementGreenfield(), // Movement Greenfield: 4 tables & base activity kinds seeds
    MigrationV107MovementPlanning(), // Movement Planning: templates, schedules, workout logs
    MigrationV108MovementLiveEvents(), // Movement Live Events: movement_session_events & finishedAt
    MigrationV109MovementStrengthTables(), // Movement Strength: programs, days, exercises, set logs
    MigrationV110MovementReadinessPreferencesPrTables(), // Movement Readiness, Preferences & Personal Records (Gate 5)
    MigrationV111MedicationIdentityBackfill(), // Medication Identity backfill (Phase 0)
    MigrationV112MedicationProfiles(), // Medication Profiles (Phase 1)
    MigrationV113CycleConfirmations(), // Cycle Confirmations and settings (Lifecycle & Privacy)
    MigrationV114CycleFertilityCleanup(), // Cycle Fertility setting cleanup
    MigrationV115MyDay(), // Simple Tasks: addedToMyDayAt column
    MigrationV116TagsAndNormalizedFields(), // Simple Tasks: tagsJson, noteNormalized, titleNormalized
    MigrationV117CycleHardening(), // Cycle module hardening: autoClosed, indexes, normalization & cleanup
    MigrationV118MedicationIntegrityAndSafety(), // Medication integrity, stock tracking & safety indexes
    MigrationV119KonkurStudyIsolation(), // Strict isolation between Konkur presets/custom subjects and study mode
    MigrationV120StudyDeadlinesAndPomodoro(), // Study exams, assignments, deadlines table & pomodoro active session fields
    MigrationV121SportsUnification(), // Unified Sports & Movement: M1-M7 migrations
  ];

  static List<Migration> get debugMigrations => List.unmodifiable(_migrations);

  static Future<void> run(Database db, int oldVersion, int newVersion) async {
    RitmoLog.info('MigrationRunner', 'Running migrations from v$oldVersion to v$newVersion');

    final sorted = [..._migrations]..sort((a, b) => a.version.compareTo(b.version));

    final seen = <int>{};
    for (final m in sorted) {
      if (!seen.add(m.version)) {
        throw StateError('Duplicate migration version: ${m.version}');
      }
    }

    for (final migration in sorted) {
      if (migration.version > oldVersion && migration.version <= newVersion) {
        try {
          if (migration.requiresTransaction) {
            await db.transaction((txn) async {
              await migration.up(txn);
            });
          } else {
            await migration.up(db);
          }
          RitmoLog.info('MigrationRunner', 'Successfully applied migration v${migration.version}');
        } catch (e, st) {
          RitmoLog.error('MigrationRunner', 'Failed to apply migration v${migration.version}', e, st);
          rethrow;
        }
      }
    }
  }

  /// Completes the schema of a **freshly created** database (onCreate path).
  ///
  /// `onCreate` builds the canonical schema with `SchemaManager.createAll`, so
  /// historically the migration chain never ran on a new install. Everything
  /// that exists *only* inside a migration - extra tables such as `day_marks`
  /// (v83), added columns, default settings rows - was therefore present on
  /// every upgraded install but missing on a brand-new device, which surfaced
  /// at runtime as `no such table` / `no such column` errors. Replaying the
  /// chain here makes a new database equivalent to a migrated one.
  ///
  /// Differences from [run], on purpose:
  /// - **Never fatal.** On a canonical base schema many historical steps are
  ///   legitimately redundant (adding a column that already exists, back-filling
  ///   empty tables). A redundant step must not be able to break first launch,
  ///   so each step is isolated and only logged.
  /// - **No nested transactions.** sqflite already runs `onCreate` inside a
  ///   transaction, so every step is applied directly on [db].
  static Future<void> runForFreshInstall(Database db, int newVersion) async {
    final sorted = [..._migrations]..sort((a, b) => a.version.compareTo(b.version));

    var applied = 0;
    var skipped = 0;
    for (final migration in sorted) {
      if (migration.version > newVersion) continue;
      try {
        await migration.up(db);
        applied++;
      } catch (e) {
        skipped++;
        RitmoLog.warning(
          'MigrationRunner',
          'Fresh-install step v${migration.version} skipped (already satisfied by base schema): $e',
        );
      }
    }

    RitmoLog.info(
      'MigrationRunner',
      'Fresh-install schema completion: applied=$applied skipped=$skipped target=v$newVersion',
    );
  }
}
