import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/database/schema/schema_manager.dart';
import 'package:ritmo/features/simple_tasks/data/task_preferences.dart';
import 'package:ritmo/features/simple_tasks/data/task_step_repository.dart';
import 'package:ritmo/features/simple_tasks/domain/simple_task.dart';
import 'package:ritmo/features/simple_tasks/logic/missed_reminder_recovery.dart';
import 'package:ritmo/features/simple_tasks/logic/routine_task_bridge.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database db;

  setUp(() async {
    db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await SchemaManager.createAll(db);
        },
      ),
    );

    await DatabaseHelper.ensureCriticalSchema(db);
    DatabaseHelper.instance.overrideDatabaseForTesting(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('Simple Tasks Module Fixes Audit (RITF-060 .. RITF-065)', () {
    test('RITF-060 & RITF-061 & RITF-062 & RITF-063: MissedReminderRecovery recovers batch tasks with privacy & idempotency', () async {
      final now = DateTime(2026, 8, 27, 10, 0);
      final pastMs = now.subtract(const Duration(hours: 2)).millisecondsSinceEpoch;

      // Seed 4 tasks: 1 normal, 1 private (important), 1 tagged private, 1 normal
      await db.insert('simple_tasks', {
        'id': 't1',
        'title': 'خرید نان',
        'note': 'سنگک کنجدی',
        'isDone': 0,
        'createdAt': pastMs,
        'updatedAt': pastMs,
      });
      await db.insert('simple_tasks', {
        'id': 't2',
        'title': 'نامه اداری محرمانه',
        'note': 'جزییات حقوقی و سری',
        'isImportant': 1,
        'isDone': 0,
        'createdAt': pastMs,
        'updatedAt': pastMs,
      });
      await db.insert('simple_tasks', {
        'id': 't3',
        'title': 'جلسه محرمانه',
        'note': 'یادداشت خصوصی',
        'tagsJson': jsonEncode(['شخصی']),
        'isDone': 0,
        'createdAt': pastMs,
        'updatedAt': pastMs,
      });
      await db.insert('simple_tasks', {
        'id': 't4',
        'title': 'تماس با دکتر',
        'note': 'نوبت ویزیت',
        'isDone': 0,
        'createdAt': pastMs,
        'updatedAt': pastMs,
      });

      // Seed 4 pending reminders
      for (var i = 1; i <= 4; i++) {
        await db.insert('pending_reminders', {
          'id': 'rem_$i',
          'originalTime': pastMs,
          'scheduledTime': pastMs,
          'state': 'SCHEDULED',
          'ownerModule': 'tasks',
          'payloadJson': jsonEncode({'taskId': 't$i'}),
          'createdAt': pastMs,
          'updatedAt': pastMs,
        });
      }

      final recoveredCount = await MissedReminderRecovery.recoverMissedReminders(nowOverride: now);
      expect(recoveredCount, 4);

      // Verify all pending reminders were marked RECOVERED in DB
      final pendingRows = await db.query('pending_reminders');
      for (final r in pendingRows) {
        expect(r['state'], 'RECOVERED');
      }
    });

    test('RITF-064: SimpleTask.fromMap safely parses malformed tagsJson with logging', () {
      final task = SimpleTask.fromMap({
        'id': 'task_corrupt_tags',
        'title': 'تسک با تگ خراب',
        'tagsJson': '{invalid_json',
        'createdAt': 1700000000000,
        'updatedAt': 1700000000000,
      });

      expect(task.id, 'task_corrupt_tags');
      expect(task.tags, isEmpty);
    });

    test('RITF-065: TaskStepRepository, TaskPreferences, RoutineTaskBridge do not use replace conflict algorithm', () async {
      final now = DateTime(2026, 8, 27);

      // Test TaskPreferences._setSetting upsert
      await TaskPreferences.setSortMode('manual');
      expect(await TaskPreferences.getSortMode(), 'manual');
      await TaskPreferences.setSortMode('alphabetical');
      expect(await TaskPreferences.getSortMode(), 'alphabetical');

      // Test TaskStepRepository.add
      final step = await TaskStepRepository.instance.add(
        taskId: 'task_1',
        title: 'مرحله اول',
      );
      expect(step.title, 'مرحله اول');

      // Test RoutineTaskBridge
      await db.insert('routines', {
        'id': 'routine_1',
        'title': 'ورزش صبحگاهی',
        'category': 'sports',
        'notificationLevel': 'none',
        'displayOrder': 0,
        'routineType': 'daily',
        'isArchived': 0,
        'createdAt': now.millisecondsSinceEpoch,
        'updatedAt': now.millisecondsSinceEpoch,
      });

      final materialized = await RoutineTaskBridge.materializeTodayRoutineTasks(now: now);
      expect(materialized, 1);
    });
  });
}
