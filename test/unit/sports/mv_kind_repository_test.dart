import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/features/supplementary_sports/data/repositories/mv_kind_repository.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';
import 'package:ritmo/features/supplementary_sports/movement/data/seed/movement_kinds_seed.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database db;
  late MvKindRepository repo;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await MovementKindsSeed.seed(db);
    repo = MvKindRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('MvKindRepository Verification (S1-T2)', () {
    test('getAll() returns at least 40 movement kinds', () async {
      final all = await repo.getAll();
      expect(all.length, greaterThanOrEqualTo(40));
    });

    test(
      "getByCode('FOOTBALL') returns complete movement kind specifications",
      () async {
        final football = await repo.getByCode('FOOTBALL');
        expect(football, isNotNull);
        expect(football!.code, equals('FOOTBALL'));
        expect(football.titleFa, equals('فوتبال'));
        expect(football.emoji, equals('⚽'));
        expect(football.family, equals(MovementFamily.sport));
        expect(football.baseMet, equals(7.0));
        expect(football.isSocial, isTrue);
      },
    );

    test("searchFa('توپ') returns football and volleyball", () async {
      final results = await repo.searchFa('توپ');
      final codes = results.map((k) => k.code).toList();

      expect(codes, contains('FOOTBALL'));
      expect(codes, contains('VOLLEYBALL'));
    });

    test(
      "recordUsage('SWIMMING') increments counter and updates lastUsedAt",
      () async {
        final initial = await repo.getByCode('SWIMMING');
        expect(initial, isNotNull);
        final initialCount = initial!.usageCount;

        await repo.recordUsage('SWIMMING');

        final updated = await repo.getByCode('SWIMMING');
        expect(updated, isNotNull);
        expect(updated!.usageCount, equals(initialCount + 1));
        expect(updated.lastUsedAt, isNotNull);
      },
    );

    test('getMapByCodes returns keyed map of movement kinds', () async {
      final map = await repo.getMapByCodes(['FOOTBALL', 'HIKING']);
      expect(map.containsKey('FOOTBALL'), isTrue);
      expect(map.containsKey('HIKING'), isTrue);
      expect(map['FOOTBALL']!.titleFa, equals('فوتبال'));
      expect(map['HIKING']!.titleFa, equals('کوه‌نوردی'));
    });

    test('getByFamily filters movement kinds correctly', () async {
      final martial = await repo.getByFamily(MovementFamily.martialSkill);
      expect(martial.isNotEmpty, isTrue);
      expect(
        martial.every((k) => k.family == MovementFamily.martialSkill),
        isTrue,
      );
    });
  });
}
