import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/features/supplementary_sports/data/repositories/repositories.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('MvStationBundleRepository CRUD & Seed Status Tests (S5-T5)', () {
    late Database db;
    late MvStationBundleRepository repo;

    setUp(() async {
      db = await openDatabase(
        inMemoryDatabasePath,
        version: 1,
        onCreate: (d, v) async {
          await d.execute('''
            CREATE TABLE IF NOT EXISTS station_bundles (
                id TEXT PRIMARY KEY,
                title TEXT NOT NULL,
                description TEXT,
                category TEXT NOT NULL,
                itemsJson TEXT NOT NULL,
                isUserTemplate INTEGER NOT NULL DEFAULT 0,
                usageCount INTEGER NOT NULL DEFAULT 0,
                createdAt INTEGER NOT NULL,
                updatedAt INTEGER NOT NULL
            );
          ''');
        },
      );
      repo = MvStationBundleRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('Fresh table is empty confirming missing seed data', () async {
      final bundles = await repo.getAllBundles();
      expect(bundles, isEmpty);
    });

    test('upsert, getById, getByCategory, bumpUsage, and delete lifecycle', () async {
      const bundle = MvStationBundle(
        id: 'bundle_bodyweight_core',
        title: 'ایستگاه شکم و مرکز',
        description: 'تمرینات بدون وسیله مرکز بدن',
        category: 'core',
        itemsJson: '["plank", "crunch"]',
        isUserTemplate: true,
        usageCount: 0,
        createdAt: 1700000000,
        updatedAt: 1700000000,
      );

      await repo.upsertBundle(bundle);

      final fetched = await repo.getById('bundle_bodyweight_core');
      expect(fetched, isNotNull);
      expect(fetched!.title, equals('ایستگاه شکم و مرکز'));
      expect(fetched.isUserTemplate, isTrue);

      final coreBundles = await repo.getByCategory('core');
      expect(coreBundles.length, equals(1));

      await repo.bumpUsage('bundle_bodyweight_core');
      final updated = await repo.getById('bundle_bodyweight_core');
      expect(updated!.usageCount, equals(1));

      final deleted = await repo.deleteBundle('bundle_bodyweight_core');
      expect(deleted, equals(1));
      expect(await repo.getById('bundle_bodyweight_core'), isNull);
    });
  });
}
