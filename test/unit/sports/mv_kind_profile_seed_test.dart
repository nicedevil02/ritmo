import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/schema/tables/supplementary_sports_tables.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('MvKindProfileSeed & Schema Verification (S3-T1)', () {
    late Database db;

    setUp(() async {
      db = await databaseFactory.openDatabase(inMemoryDatabasePath);
      await SupplementarySportsTables.create(db);
    });

    tearDown(() async {
      await db.close();
    });

    test(
      'Table mv_kind_profile exists and count matches all active movement_kinds',
      () async {
        final kinds = await db.query('movement_kinds');
        final profiles = await db.query('mv_kind_profile');

        expect(kinds.isNotEmpty, isTrue);
        expect(profiles.isNotEmpty, isTrue);
        // Acceptance test: Total profile count matches movement_kinds count (49 rows)
        expect(profiles.length, equals(kinds.length));

        final profileKindCodes = profiles
            .map((p) => p['kindCode'] as String)
            .toSet();
        final movementKindCodes = kinds.map((k) => k['code'] as String).toSet();

        expect(profileKindCodes, equals(movementKindCodes));
      },
    );

    test(
      'Explicit profiles match specified values with exact precision',
      () async {
        // FOOTBALL
        final footballRows = await db.query(
          'mv_kind_profile',
          where: 'kindCode = ?',
          whereArgs: ['FOOTBALL'],
        );
        expect(footballRows, isNotEmpty);
        final football = footballRows.first;
        expect(
          football['primaryMuscles'],
          equals('hamstrings,quads,calves,glutes'),
        );
        expect(football['neuroCost'], equals(3));
        expect(football['recoveryHours'], equals(48));
        expect(
          football['complementFocus'],
          equals('posterior_chain,adductors,ankle'),
        );
        expect(
          football['prehabTags'],
          equals('nordic_hamstring,copenhagen,ankle_hop'),
        );
        expect(football['recommendedTierBefore'], equals('light'));
        expect(football['recommendedTierAfter'], equals('light'));

        // FUTSAL
        final futsalRows = await db.query(
          'mv_kind_profile',
          where: 'kindCode = ?',
          whereArgs: ['FUTSAL'],
        );
        expect(futsalRows, isNotEmpty);
        final futsal = futsalRows.first;
        expect(
          futsal['primaryMuscles'],
          equals('hamstrings,quads,calves,core'),
        );
        expect(futsal['neuroCost'], equals(3));
        expect(futsal['recoveryHours'], equals(48));
        expect(
          futsal['complementFocus'],
          equals('posterior_chain,adductors,ankle'),
        );
        expect(
          futsal['prehabTags'],
          equals('nordic_hamstring,copenhagen,ankle_hop'),
        );

        // BASKETBALL
        final basketballRows = await db.query(
          'mv_kind_profile',
          where: 'kindCode = ?',
          whereArgs: ['BASKETBALL'],
        );
        expect(basketballRows, isNotEmpty);
        final basketball = basketballRows.first;
        expect(
          basketball['primaryMuscles'],
          equals('quads,calves,glutes,core'),
        );
        expect(basketball['neuroCost'], equals(3));
        expect(basketball['recoveryHours'], equals(48));
        expect(basketball['complementFocus'], equals('landing,knee,hip'));
        expect(
          basketball['prehabTags'],
          equals('lateral_bound,nordic,copenhagen'),
        );

        // SWIMMING
        final swimmingRows = await db.query(
          'mv_kind_profile',
          where: 'kindCode = ?',
          whereArgs: ['SWIMMING'],
        );
        expect(swimmingRows, isNotEmpty);
        final swimming = swimmingRows.first;
        expect(swimming['primaryMuscles'], equals('lats,shoulders,core'));
        expect(swimming['neuroCost'], equals(1));
        expect(swimming['recoveryHours'], equals(12));
        expect(swimming['complementFocus'], equals('thoracic,scapular,hip'));
        expect(
          swimming['prehabTags'],
          equals('scapular_retraction,thoracic_rotation'),
        );

        // YOGA
        final yogaRows = await db.query(
          'mv_kind_profile',
          where: 'kindCode = ?',
          whereArgs: ['YOGA'],
        );
        expect(yogaRows, isNotEmpty);
        final yoga = yogaRows.first;
        expect(yoga['primaryMuscles'], equals('full_body'));
        expect(yoga['neuroCost'], equals(1));
        expect(yoga['recoveryHours'], equals(0));
        expect(yoga['complementFocus'], equals('none'));
        expect(yoga['prehabTags'], equals('none'));

        // WALKING
        final walkingRows = await db.query(
          'mv_kind_profile',
          where: 'kindCode = ?',
          whereArgs: ['WALKING'],
        );
        expect(walkingRows, isNotEmpty);
        final walking = walkingRows.first;
        expect(walking['primaryMuscles'], equals('calves,glutes'));
        expect(walking['neuroCost'], equals(1));
        expect(walking['recoveryHours'], equals(0));
        expect(walking['complementFocus'], equals('none'));
        expect(walking['prehabTags'], equals('none'));

        // STRENGTH_HOME
        final bwRows = await db.query(
          'mv_kind_profile',
          where: 'kindCode = ?',
          whereArgs: ['STRENGTH_HOME'],
        );
        expect(bwRows, isNotEmpty);
        final bw = bwRows.first;
        expect(bw['primaryMuscles'], equals('full_body'));
        expect(bw['neuroCost'], equals(2));
        expect(bw['recoveryHours'], equals(36));
        expect(bw['complementFocus'], equals('mobility,core'));
        expect(bw['prehabTags'], equals('none'));
      },
    );

    test('Non-explicit kind fallback profile is generated correctly', () async {
      // SKATING (non-explicit in 25 table, has jointImpact)
      final skatingRows = await db.query(
        'mv_kind_profile',
        where: 'kindCode = ?',
        whereArgs: ['SKATING'],
      );
      expect(skatingRows, isNotEmpty);
      final skating = skatingRows.first;
      expect(skating['primaryMuscles'], equals('full_body'));
      expect(skating['complementFocus'], equals('mobility,core'));
      expect(skating['recommendedTierBefore'], equals('light'));
      expect(skating['recommendedTierAfter'], equals('light'));
      expect(skating['neuroCost'], isIn([1, 2, 3]));
      expect(skating['recoveryHours'], greaterThanOrEqualTo(0));
    });
  });
}
