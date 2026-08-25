import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/features/supplementary_sports/data/repositories/repositories.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('S5-T1 MvCampaignRepository Tests', () {
    late Database db;
    late MvCampaignRepository repo;

    setUp(() async {
      db = await openDatabase(
        inMemoryDatabasePath,
        version: 1,
        onCreate: (d, v) async {
          await d.execute('''
            CREATE TABLE IF NOT EXISTS movement_campaigns (
              id           TEXT PRIMARY KEY,
              titleFa      TEXT NOT NULL,
              goalCode     TEXT NOT NULL,
              startDate    TEXT NOT NULL,
              weeks        INTEGER NOT NULL,
              status       TEXT NOT NULL,
              routineIds   TEXT NOT NULL,
              progressJson TEXT,
              createdAt    INTEGER NOT NULL,
              updatedAt    INTEGER NOT NULL
            );
          ''');
        },
      );

      repo = MvCampaignRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    test(
      'upsert, getActive, getById, and complete work correctly on movement_campaigns table',
      () async {
        // 1. Initial getActive is null
        final initial = await repo.getActive();
        expect(initial, isNull);

        // 2. Insert campaign «صعود به دماوند»
        const campaign = MvCampaign(
          id: 'camp_damavand_2026',
          titleFa: 'صعود به قله دماوند',
          goalCode: 'OUTDOOR',
          startDate: '2026-08-01',
          weeks: 12,
          status: 'ACTIVE',
          routineIds: ['rt_hike_1', 'rt_strength_1'],
          progressJson: '{"targetElevationM": 5671, "targetPackKg": 15}',
          createdAt: 1700000000,
          updatedAt: 1700000000,
        );

        final inserted = await repo.upsert(campaign);
        expect(inserted.id, equals('camp_damavand_2026'));

        // 3. getActive returns this campaign
        final active = await repo.getActive();
        expect(active, isNotNull);
        expect(active!.titleFa, equals('صعود به قله دماوند'));
        expect(active.weeks, equals(12));
        expect(active.routineIds, equals(['rt_hike_1', 'rt_strength_1']));
        expect(active.isActive, isTrue);

        // 4. getById
        final byId = await repo.getById('camp_damavand_2026');
        expect(byId, isNotNull);
        expect(byId!.goalCode, equals('OUTDOOR'));

        // 5. Complete campaign
        await repo.complete('camp_damavand_2026');

        final activeAfterComplete = await repo.getActive();
        expect(activeAfterComplete, isNull);

        final completedCampaign = await repo.getById('camp_damavand_2026');
        expect(completedCampaign, isNotNull);
        expect(completedCampaign!.status, equals('COMPLETED'));
        expect(completedCampaign.isActive, isFalse);
        expect(completedCampaign.updatedAt, greaterThanOrEqualTo(1700000000));
      },
    );
  });
}
