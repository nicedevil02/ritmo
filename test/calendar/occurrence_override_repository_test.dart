import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/domain/agenda/occurrence_override_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;
  const repo = SqliteOccurrenceOverrideRepository();

  setUp(() async {
    db = await openDatabase(
      inMemoryDatabasePath,
      version: 1,
      onCreate: (d, v) async {
        await SqliteOccurrenceOverrideRepository.ensureTable(d);
      },
    );
    DatabaseHelper.databaseInstance = db;
  });

  tearDown(() async {
    DatabaseHelper.databaseInstance = null;
    await db.close();
  });

  group('CAL-57: OccurrenceOverrideRepository Comprehensive Tests', () {
    test('1. Merging upsert: resize (duration) then move (time) preserves durationMinutes (CAL-09)', () async {
      const initial = OccurrenceOverride(
        sourceType: 'routine',
        sourceId: 'r1',
        dateStr: '2026-08-18',
        durationMinutes: 45,
        createdAt: '2026-08-18T10:00:00.000',
        updatedAt: '2026-08-18T10:00:00.000',
      );
      await repo.upsert(initial);

      const moved = OccurrenceOverride(
        sourceType: 'routine',
        sourceId: 'r1',
        dateStr: '2026-08-18',
        timeOfDay: '11:00',
        createdAt: '2026-08-18T10:05:00.000',
        updatedAt: '2026-08-18T10:05:00.000',
      );
      await repo.upsert(moved);

      final merged = await repo.readOne('routine', 'r1', '2026-08-18');
      expect(merged, isNotNull);
      expect(merged!.timeOfDay, equals('11:00'));
      expect(merged.durationMinutes, equals(45));
    });

    test('2. skip then move: status remains SKIPPED (CAL-09)', () async {
      const skipped = OccurrenceOverride(
        sourceType: 'task',
        sourceId: 't1',
        dateStr: '2026-08-18',
        status: 'SKIPPED',
        createdAt: '2026-08-18T08:00:00.000',
        updatedAt: '2026-08-18T08:00:00.000',
      );
      await repo.upsert(skipped);

      const moved = OccurrenceOverride(
        sourceType: 'task',
        sourceId: 't1',
        dateStr: '2026-08-18',
        timeOfDay: '15:00',
        createdAt: '2026-08-18T08:30:00.000',
        updatedAt: '2026-08-18T08:30:00.000',
      );
      await repo.upsert(moved);

      final result = await repo.readOne('task', 't1', '2026-08-18');
      expect(result, isNotNull);
      expect(result!.status, equals('SKIPPED'));
      expect(result.timeOfDay, equals('15:00'));
    });

    test('3. createdAt does not change after second upsert (CAL-09)', () async {
      const originalCreatedAt = '2026-08-18T07:00:00.000';
      const first = OccurrenceOverride(
        sourceType: 'routine',
        sourceId: 'r2',
        dateStr: '2026-08-18',
        timeOfDay: '08:00',
        createdAt: originalCreatedAt,
        updatedAt: originalCreatedAt,
      );
      await repo.upsert(first);

      const second = OccurrenceOverride(
        sourceType: 'routine',
        sourceId: 'r2',
        dateStr: '2026-08-18',
        timeOfDay: '09:00',
        createdAt: '2026-08-18T09:00:00.000', // Different createdAt passed
        updatedAt: '2026-08-18T09:00:00.000',
      );
      await repo.upsert(second);

      final result = await repo.readOne('routine', 'r2', '2026-08-18');
      expect(result, isNotNull);
      expect(result!.createdAt, equals(originalCreatedAt));
    });

    test('4. readOne / readAllFuture / restoreAll snapshot operations (CAL-10)', () async {
      const o1 = OccurrenceOverride(
        sourceType: 'routine',
        sourceId: 'r3',
        dateStr: '2026-08-18',
        timeOfDay: '10:00',
        createdAt: '2026-08-18T00:00:00.000',
        updatedAt: '2026-08-18T00:00:00.000',
      );
      const o2 = OccurrenceOverride(
        sourceType: 'routine',
        sourceId: 'r3',
        dateStr: '2026-08-19',
        timeOfDay: '10:00',
        createdAt: '2026-08-18T00:00:00.000',
        updatedAt: '2026-08-18T00:00:00.000',
      );
      await repo.upsert(o1);
      await repo.upsert(o2);

      final futureList = await repo.readAllFuture('routine', 'r3', '2026-08-18');
      expect(futureList.length, equals(2));

      await repo.removeAllFuture('routine', 'r3', '2026-08-18');
      final emptyCheck = await repo.readAllFuture('routine', 'r3', '2026-08-18');
      expect(emptyCheck, isEmpty);

      // Restore
      await repo.restoreAll(futureList);
      final restored = await repo.readAllFuture('routine', 'r3', '2026-08-18');
      expect(restored.length, equals(2));
    });

    test('5. Snapshot-based undo: resize -> move -> undo -> state after resize (CAL-11)', () async {
      // 1. Initial state (resize)
      const resizeState = OccurrenceOverride(
        sourceType: 'routine',
        sourceId: 'r_undo',
        dateStr: '2026-08-18',
        timeOfDay: '08:00',
        durationMinutes: 90,
        createdAt: '2026-08-18T00:00:00.000',
        updatedAt: '2026-08-18T00:00:00.000',
      );
      await repo.upsert(resizeState);

      // Snapshot before move
      final snapshotBeforeMove = await repo.readOne('routine', 'r_undo', '2026-08-18');
      expect(snapshotBeforeMove, isNotNull);

      // 2. Move
      const moveState = OccurrenceOverride(
        sourceType: 'routine',
        sourceId: 'r_undo',
        dateStr: '2026-08-18',
        timeOfDay: '12:00',
        createdAt: '2026-08-18T01:00:00.000',
        updatedAt: '2026-08-18T01:00:00.000',
      );
      await repo.upsert(moveState);

      var current = await repo.readOne('routine', 'r_undo', '2026-08-18');
      expect(current!.timeOfDay, equals('12:00'));

      // 3. Undo (restore snapshotBeforeMove)
      await repo.restoreAll([snapshotBeforeMove!]);

      current = await repo.readOne('routine', 'r_undo', '2026-08-18');
      expect(current!.timeOfDay, equals('08:00'));
      expect(current.durationMinutes, equals(90));
    });

    test('6. allFutureDays: 3 future overrides -> removeAllFuture -> restoreAll restores all 3 (CAL-12)', () async {
      for (int i = 0; i < 3; i++) {
        final dStr = '2026-08-${(20 + i)}';
        await repo.upsert(OccurrenceOverride(
          sourceType: 'routine',
          sourceId: 'r_all',
          dateStr: dStr,
          timeOfDay: '07:00',
          createdAt: '2026-08-18T00:00:00.000',
          updatedAt: '2026-08-18T00:00:00.000',
        ));
      }

      final snapshot = await repo.readAllFuture('routine', 'r_all', '2026-08-20');
      expect(snapshot.length, equals(3));

      await repo.removeAllFuture('routine', 'r_all', '2026-08-20');
      var list = await repo.readAllFuture('routine', 'r_all', '2026-08-20');
      expect(list, isEmpty);

      await repo.restoreAll(snapshot);
      list = await repo.readAllFuture('routine', 'r_all', '2026-08-20');
      expect(list.length, equals(3));
    });

    test('7. task:42 and routine:42 on same date: override on task leaves routine untouched (CAL-13)', () async {
      await repo.upsert(const OccurrenceOverride(
        sourceType: 'task',
        sourceId: '42',
        dateStr: '2026-08-18',
        timeOfDay: '10:00',
        status: 'SKIPPED',
        createdAt: '2026-08-18T00:00:00.000',
        updatedAt: '2026-08-18T00:00:00.000',
      ));

      await repo.upsert(const OccurrenceOverride(
        sourceType: 'routine',
        sourceId: '42',
        dateStr: '2026-08-18',
        timeOfDay: '14:00',
        createdAt: '2026-08-18T00:00:00.000',
        updatedAt: '2026-08-18T00:00:00.000',
      ));

      final taskOverride = await repo.readOne('task', '42', '2026-08-18');
      final routineOverride = await repo.readOne('routine', '42', '2026-08-18');

      expect(taskOverride, isNotNull);
      expect(taskOverride!.status, equals('SKIPPED'));
      expect(taskOverride.timeOfDay, equals('10:00'));

      expect(routineOverride, isNotNull);
      expect(routineOverride!.status, isNull);
      expect(routineOverride.timeOfDay, equals('14:00'));
    });

    test('8. Missing table triggers ensureTable and succeeds on second attempt', () async {
      // Drop table to simulate fresh/unmigrated DB
      await db.execute('DROP TABLE occurrence_overrides;');

      const item = OccurrenceOverride(
        sourceType: 'routine',
        sourceId: 'r_fresh',
        dateStr: '2026-08-18',
        timeOfDay: '08:00',
        createdAt: '2026-08-18T00:00:00.000',
        updatedAt: '2026-08-18T00:00:00.000',
      );

      // Upsert should recover by creating table
      await repo.upsert(item);
      final read = await repo.readOne('routine', 'r_fresh', '2026-08-18');
      expect(read, isNotNull);
      expect(read!.timeOfDay, equals('08:00'));
    });
  });
}
