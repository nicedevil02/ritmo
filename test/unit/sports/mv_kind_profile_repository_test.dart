import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/schema/tables/supplementary_sports_tables.dart';
import 'package:ritmo/features/supplementary_sports/data/repositories/repositories.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('MvKindProfileRepository Unit Tests (S3-T2)', () {
    late Database db;
    late MvKindProfileRepository repo;

    setUp(() async {
      db = await databaseFactory.openDatabase(inMemoryDatabasePath);
      await SupplementarySportsTables.create(db);
      repo = MvKindProfileRepositoryImpl(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('getByCode returns accurate MvKindProfile with parsed lists', () async {
      final footballProfile = await repo.getByCode('FOOTBALL');
      expect(footballProfile, isNotNull);
      expect(footballProfile!.kindCode, equals('FOOTBALL'));
      expect(
        footballProfile.primaryMuscles,
        equals(['hamstrings', 'quads', 'calves', 'glutes']),
      );
      expect(footballProfile.neuroCost, equals(3));
      expect(footballProfile.recoveryHours, equals(48));
      expect(
        footballProfile.complementFocus,
        equals(['posterior_chain', 'adductors', 'ankle']),
      );
      expect(
        footballProfile.prehabTags,
        equals(['nordic_hamstring', 'copenhagen', 'ankle_hop']),
      );
      expect(footballProfile.recommendedTierBefore, equals(MvIntensityTier.light));
      expect(footballProfile.recommendedTierAfter, equals(MvIntensityTier.light));

      // Test non-existent kind
      final unknown = await repo.getByCode('NON_EXISTENT_KIND');
      expect(unknown, isNull);
    });

    test('getMapByCodes returns Map<String, MvKindProfile> for batch requested codes', () async {
      final map = await repo.getMapByCodes(['SWIMMING', 'YOGA', 'FUTSAL', 'NON_EXISTENT']);
      expect(map.length, equals(3));
      expect(map.containsKey('SWIMMING'), isTrue);
      expect(map.containsKey('YOGA'), isTrue);
      expect(map.containsKey('FUTSAL'), isTrue);
      expect(map.containsKey('NON_EXISTENT'), isFalse);

      expect(map['SWIMMING']!.primaryMuscles, equals(['lats', 'shoulders', 'core']));
      expect(map['YOGA']!.primaryMuscles, equals(['full_body']));
      expect(map['YOGA']!.recoveryHours, equals(0));
      expect(map['FUTSAL']!.neuroCost, equals(3));
    });

    test('getAll returns all 49 kind profiles', () async {
      final allProfiles = await repo.getAll();
      expect(allProfiles.length, equals(49));
      expect(allProfiles.any((p) => p.kindCode == 'WALKING'), isTrue);
      expect(allProfiles.any((p) => p.kindCode == 'ROCK_CLIMBING'), isTrue);
    });

    test('upsert modifies existing profile and persists correctly', () async {
      final initial = await repo.getByCode('WALKING');
      expect(initial, isNotNull);

      final updated = initial!.copyWith(
        recoveryHours: 8,
        complementFocus: ['mobility'],
      );
      await repo.upsert(updated);

      final retrieved = await repo.getByCode('WALKING');
      expect(retrieved, isNotNull);
      expect(retrieved!.recoveryHours, equals(8));
      expect(retrieved.complementFocus, equals(['mobility']));
    });
  });
}
