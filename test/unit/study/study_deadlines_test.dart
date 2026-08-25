import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/util/ritmo_date.dart';
import 'package:ritmo/features/study/domain/study_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('StudyDeadline Model & Repository Tests', () {
    late Database db;

    setUp(() async {
      db = await databaseFactory.openDatabase(inMemoryDatabasePath);
      await db.execute('''
        CREATE TABLE study_deadlines (
          id TEXT PRIMARY KEY,
          subjectId TEXT,
          title TEXT NOT NULL,
          deadlineType TEXT NOT NULL DEFAULT 'EXAM',
          dueDateIso TEXT NOT NULL,
          dueTime TEXT,
          priority TEXT NOT NULL DEFAULT 'MEDIUM',
          isCompleted INTEGER NOT NULL DEFAULT 0,
          weight REAL DEFAULT 1.0,
          note TEXT,
          createdAt INTEGER NOT NULL,
          updatedAt INTEGER NOT NULL
        );
      ''');
    });

    tearDown(() async {
      await db.close();
    });

    test('StudyDeadline model daysRemaining and status helpers work correctly', () {
      final now = DateTime(2026, 8, 25);
      const deadlineFuture = StudyDeadline(
        id: 'd1',
        title: 'امتحان ریاضی',
        dueDateIso: '2026-08-28',
        createdAtMs: 0,
        updatedAtMs: 0,
      );

      expect(deadlineFuture.daysRemaining(now), 3);
      expect(deadlineFuture.isOverdue(now), isFalse);
      expect(deadlineFuture.isToday(now), isFalse);
      expect(deadlineFuture.isUpcoming(now, days: 7), isTrue);

      final deadlineToday = deadlineFuture.copyWith(dueDateIso: '2026-08-25');
      expect(deadlineToday.daysRemaining(now), 0);
      expect(deadlineToday.isToday(now), isTrue);

      final deadlinePast = deadlineFuture.copyWith(dueDateIso: '2026-08-20');
      expect(deadlinePast.daysRemaining(now), -5);
      expect(deadlinePast.isOverdue(now), isTrue);
    });

    test('StudyDeadline CRUD operations work in sqlite', () async {
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final deadline = StudyDeadline(
        id: 'dl_101',
        subjectId: 'sub_1',
        title: 'پروژه پایگاه داده',
        deadlineType: DeadlineType.project,
        dueDateIso: RitmoDate.dayKey(DateTime.now().add(const Duration(days: 4))),
        priority: DeadlinePriority.high,
        createdAtMs: nowMs,
        updatedAtMs: nowMs,
      );

      await db.insert('study_deadlines', deadline.toMap());

      final rows = await db.query('study_deadlines', where: 'id = ?', whereArgs: ['dl_101']);
      expect(rows.length, 1);
      final fetched = StudyDeadline.fromMap(rows.first);
      expect(fetched.title, 'پروژه پایگاه داده');
      expect(fetched.deadlineType, DeadlineType.project);
      expect(fetched.priority, DeadlinePriority.high);
      expect(fetched.isCompleted, isFalse);

      // Mark completed
      await db.update(
        'study_deadlines',
        {'isCompleted': 1, 'updatedAt': nowMs + 100},
        where: 'id = ?',
        whereArgs: ['dl_101'],
      );

      final updatedRows = await db.query('study_deadlines', where: 'id = ?', whereArgs: ['dl_101']);
      expect(StudyDeadline.fromMap(updatedRows.first).isCompleted, isTrue);

      // Delete
      await db.delete('study_deadlines', where: 'id = ?', whereArgs: ['dl_101']);
      final afterDelete = await db.query('study_deadlines', where: 'id = ?', whereArgs: ['dl_101']);
      expect(afterDelete.isEmpty, isTrue);
    });
  });
}
