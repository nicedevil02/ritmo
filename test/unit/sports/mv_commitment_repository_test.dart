import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/schema/tables/supplementary_sports_tables.dart';
import 'package:ritmo/features/supplementary_sports/data/repositories/mv_commitment_repository.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('MvCommitmentRepository CRUD & Filtering (S2-T3)', () {
    late Database db;
    late MvCommitmentRepository repo;

    setUp(() async {
      db = await databaseFactory.openDatabase(inMemoryDatabasePath);
      await SupplementarySportsTables.ensureCommitmentTables(db);
      repo = MvCommitmentRepositoryImpl(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('insert, getById, update, delete full CRUD lifecycle', () async {
      final commitment = MvCommitment(
        kindCode: 'FUTSAL',
        titleFa: 'فوتسال پنجشنبه‌ها',
        dayOfWeekSat0: 5,
        startTime: '21:00',
        durationMinutes: 90,
        venueNote: 'سالن تختی',
        partnerNote: 'تیم بچه‌ها',
        recurrence: CommitmentRecurrence.weekly,
      );

      // 1. Insert
      final id = await repo.insert(commitment);
      expect(id, isPositive);

      // 2. GetById
      final retrieved = await repo.getById(id);
      expect(retrieved, isNotNull);
      expect(retrieved!.kindCode, equals('FUTSAL'));
      expect(retrieved.durationMinutes, equals(90));
      expect(retrieved.venueNote, equals('سالن تختی'));

      // 3. Update
      final updated = retrieved.copyWith(
        durationMinutes: 120,
        venueNote: 'سالن یادگار',
      );
      await repo.update(updated);

      final afterUpdate = await repo.getById(id);
      expect(afterUpdate!.durationMinutes, equals(120));
      expect(afterUpdate.venueNote, equals('سالن یادگار'));

      // 4. Delete
      await repo.delete(id);
      final afterDelete = await repo.getById(id);
      expect(afterDelete, isNull);
    });

    test(
      'getForDay filters by dayOfWeekSat0 and onlyActive correctly',
      () async {
        // شنبه (۰) فعال
        await repo.insert(
          MvCommitment(
            kindCode: 'RUNNING',
            dayOfWeekSat0: 0,
            startTime: '06:30',
            durationMinutes: 45,
            isActive: true,
          ),
        );

        // پنجشنبه (۵) فعال
        final futsalId = await repo.insert(
          MvCommitment(
            kindCode: 'FUTSAL',
            dayOfWeekSat0: 5,
            startTime: '21:00',
            durationMinutes: 90,
            isActive: true,
          ),
        );

        // پنجشنبه (۵) غیرفعال
        await repo.insert(
          MvCommitment(
            kindCode: 'SWIMMING',
            dayOfWeekSat0: 5,
            startTime: '18:00',
            durationMinutes: 60,
            isActive: false,
          ),
        );

        // جمعه (۶) فعال
        await repo.insert(
          MvCommitment(
            kindCode: 'HIKING',
            dayOfWeekSat0: 6,
            startTime: '07:00',
            durationMinutes: 180,
            isActive: true,
          ),
        );

        // 1. getForDay for Thursday (5) with onlyActive = true
        final thuActive = await repo.getForDay(5, onlyActive: true);
        expect(thuActive.length, equals(1));
        expect(thuActive.first.kindCode, equals('FUTSAL'));

        // 2. getForDay for Thursday (5) with onlyActive = false
        final thuAll = await repo.getForDay(5, onlyActive: false);
        expect(thuAll.length, equals(2));

        // 3. getAll with onlyActive = true
        final allActive = await repo.getAll(onlyActive: true);
        expect(allActive.length, equals(3));

        // 4. getAll with onlyActive = false
        final all = await repo.getAll(onlyActive: false);
        expect(all.length, equals(4));

        // 5. toggleActive on FUTSAL
        await repo.toggleActive(futsalId, false);
        final thuActiveAfterToggle = await repo.getForDay(5, onlyActive: true);
        expect(thuActiveAfterToggle, isEmpty);
      },
    );

    test(
      'deactivate sets isActive to 0 without deleting row, getActive returns only active',
      () async {
        final cId = await repo.insert(
          MvCommitment(
            kindCode: 'VOLLEYBALL',
            dayOfWeekSat0: 3,
            startTime: '19:00',
            durationMinutes: 60,
            isActive: true,
          ),
        );

        expect((await repo.getActive()).length, equals(1));

        // Deactivate
        await repo.deactivate(cId);

        // Verify not deleted
        final retrieved = await repo.getById(cId);
        expect(retrieved, isNotNull);
        expect(retrieved!.isActive, isFalse);

        // Verify excluded from getActive
        expect(await repo.getActive(), isEmpty);
      },
    );

    test('upsert inserts new commitment or updates existing one', () async {
      final newCommitment = MvCommitment(
        kindCode: 'PADEL',
        dayOfWeekSat0: 4,
        startTime: '17:00',
        durationMinutes: 90,
      );

      // 1. Insert via upsert
      final created = await repo.upsert(newCommitment);
      expect(created.id, isNotNull);

      // 2. Update via upsert
      final modified = created.copyWith(durationMinutes: 120);
      final updated = await repo.upsert(modified);
      expect(updated.id, equals(created.id));
      expect(updated.durationMinutes, equals(120));

      final fromDb = await repo.getById(created.id!);
      expect(fromDb!.durationMinutes, equals(120));
    });
  });
}
