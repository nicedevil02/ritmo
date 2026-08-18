import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/domain/agenda/occurrence_override_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;
  late SqliteOccurrenceOverrideRepository repo;

  setUp(() async {
    db = await openDatabase(
      inMemoryDatabasePath,
      version: 1,
      onCreate: (d, v) async {
        await SqliteOccurrenceOverrideRepository.ensureTable(d);
      },
    );
    DatabaseHelper.databaseInstance = db;
    repo = const SqliteOccurrenceOverrideRepository();
  });

  tearDown(() async {
    DatabaseHelper.databaseInstance = null;
    await db.close();
  });

  group('SqliteOccurrenceOverrideRepository Merge & Preservation (CAL-09 / CAL-57)', () {
    test('upsert preserves neighboring fields and original createdAt on subsequent updates', () async {
      const initialCreatedAt = '2026-08-01T10:00:00.000Z';
      const resizeOverride = OccurrenceOverride(
        sourceType: 'routine',
        sourceId: 'routine-101',
        dateStr: '2026-08-18',
        durationMinutes: 45,
        status: 'RESIZED',
        createdAt: initialCreatedAt,
        updatedAt: '2026-08-01T10:00:00.000Z',
      );

      // 1. Initial resize
      await repo.upsert(resizeOverride);

      var read = await repo.readOne('routine', 'routine-101', '2026-08-18');
      expect(read, isNotNull);
      expect(read!.durationMinutes, equals(45));
      expect(read.status, equals('RESIZED'));
      expect(read.timeOfDay, isNull);
      expect(read.createdAt, equals(initialCreatedAt));

      // 2. Drag (move) on the same occurrence - specifies only timeOfDay and status
      const moveOverride = OccurrenceOverride(
        sourceType: 'routine',
        sourceId: 'routine-101',
        dateStr: '2026-08-18',
        timeOfDay: '11:15',
        status: 'MOVED',
        createdAt: '2026-08-18T12:00:00.000Z', // New timestamp that shouldn't overwrite createdAt
        updatedAt: '2026-08-18T12:00:00.000Z',
      );

      await repo.upsert(moveOverride);

      // 3. Verify merged record: durationMinutes=45, timeOfDay='11:15', status='MOVED', original createdAt
      read = await repo.readOne('routine', 'routine-101', '2026-08-18');
      expect(read, isNotNull);
      expect(read!.durationMinutes, equals(45), reason: 'durationMinutes was lost during drag');
      expect(read.timeOfDay, equals('11:15'));
      expect(read.status, equals('MOVED'));
      expect(read.createdAt, equals(initialCreatedAt), reason: 'createdAt was overwritten');
      expect(read.updatedAt, equals('2026-08-18T12:00:00.000Z'));
    });

    test('clearFields clears specific fields without affecting others', () async {
      const override = OccurrenceOverride(
        sourceType: 'routine',
        sourceId: 'routine-202',
        dateStr: '2026-08-18',
        timeOfDay: '09:00',
        durationMinutes: 60,
        status: 'CUSTOM',
        note: 'Some note',
        createdAt: '2026-08-18T08:00:00.000Z',
        updatedAt: '2026-08-18T08:00:00.000Z',
      );

      await repo.upsert(override);

      // Clear only timeOfDay
      await repo.clearFields('routine', 'routine-202', '2026-08-18', timeOfDay: true);

      var read = await repo.readOne('routine', 'routine-202', '2026-08-18');
      expect(read, isNotNull);
      expect(read!.timeOfDay, isNull);
      expect(read.durationMinutes, equals(60));
      expect(read.status, equals('CUSTOM'));
      expect(read.note, equals('Some note'));

      // Clear remaining fields
      await repo.clearFields(
        'routine',
        'routine-202',
        '2026-08-18',
        durationMinutes: true,
        status: true,
        note: true,
      );

      // Entire empty override row should now be deleted
      read = await repo.readOne('routine', 'routine-202', '2026-08-18');
      expect(read, isNull);
    });
  });
}
