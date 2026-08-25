import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/features/supplementary_sports/application/application.dart';
import 'package:ritmo/features/supplementary_sports/data/repositories/repositories.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';
import 'package:ritmo/features/supplementary_sports/movement/data/seed/movement_kinds_seed.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('S4-T4 Deterministic Player Mode Selection Tests', () {
    late Database db;
    late MvKindRepository kindRepo;

    setUp(() async {
      db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      await MovementKindsSeed.seed(db);
      kindRepo = MvKindRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('Table test for 8 key movement kinds mode resolution', () async {
      final testCases = <String, MvSessionMode>{
        'HIKING': MvSessionMode.route,
        'SWIMMING': MvSessionMode.laps,
        'FUTSAL': MvSessionMode.match,
        'FOOTBALL': MvSessionMode.match,
        'KARATE': MvSessionMode.match,
        'STRETCHING': MvSessionMode.timed,
      };

      for (final entry in testCases.entries) {
        final kind = await kindRepo.getByCode(entry.key);
        expect(kind, isNotNull, reason: 'Kind ${entry.key} must exist in seed');
        final resolvedMode = MvStartSessionUseCase.resolveSessionMode(
          kind: kind!,
        );
        expect(
          resolvedMode,
          equals(entry.value),
          reason:
              'Expected ${entry.key} to resolve to ${entry.value.name}, but got ${resolvedMode.name}',
        );
      }

      // Test RUNNING (distance or route depending on isOutdoor)
      final runningKind = await kindRepo.getByCode('RUNNING');
      expect(runningKind, isNotNull);
      final runningMode = MvStartSessionUseCase.resolveSessionMode(
        kind: runningKind!,
      );
      expect(
        runningMode == MvSessionMode.distance ||
            runningMode == MvSessionMode.route,
        isTrue,
      );

      // Test kind with SETS metric (e.g. BODYWEIGHT calisthenics)
      const bodyweightKind = MvMovementKind(
        code: 'BODYWEIGHT',
        titleFa: 'وزن بدن',
        emoji: '🤸',
        family: MovementFamily.strength,
        baseMet: 5.0,
        metLow: 3.5,
        metHigh: 7.0,
        primaryMetric: MovementMetric.sets,
        isOutdoor: false,
        isSocial: false,
        needsVenue: false,
        jointImpact: 1,
        isCustom: false,
        isEnabled: true,
        usageCount: 0,
        sortOrder: 1,
      );

      final bwGuided = MvStartSessionUseCase.resolveSessionMode(
        kind: bodyweightKind,
        hasPrescription: true,
      );
      expect(bwGuided, equals(MvSessionMode.guided));
      final bwStructured = MvStartSessionUseCase.resolveSessionMode(
        kind: bodyweightKind,
        hasPrescription: false,
      );
      expect(bwStructured, equals(MvSessionMode.structured));
    });

    test('SessionModeOverride takes absolute precedence if set', () {
      const customKind = MvMovementKind(
        code: 'CUSTOM_GAME',
        titleFa: 'بازی سفارشی',
        emoji: '🎮',
        family: MovementFamily.sport,
        baseMet: 4.0,
        metLow: 3.0,
        metHigh: 5.0,
        primaryMetric: MovementMetric.duration,
        isOutdoor: false,
        isSocial: true,
        needsVenue: false,
        jointImpact: 1,
        isCustom: true,
        isEnabled: true,
        usageCount: 0,
        sortOrder: 1,
        sessionModeOverride: MvSessionMode.laps, // explicit override
      );

      final mode = MvStartSessionUseCase.resolveSessionMode(kind: customKind);
      expect(mode, equals(MvSessionMode.laps));
    });

    test(
      'Architecture Guard: No unconditional hardcoded MvSessionMode.guided in application layer',
      () {
        final appDir = Directory(
          'lib/features/supplementary_sports/application',
        );
        final dartFiles = appDir
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'));

        for (final file in dartFiles) {
          final lines = file.readAsLinesSync();
          for (var i = 0; i < lines.length; i++) {
            final line = lines[i];
            if (line.contains('MvSessionMode.guided')) {
              // Must be conditional (e.g. within switch/ternary/resolver)
              final isSafeUsage =
                  line.contains('?') ||
                  line.contains(':') ||
                  line.contains('==') ||
                  line.contains('case') ||
                  line.contains('//');
              expect(
                isSafeUsage,
                isTrue,
                reason:
                    'Found unconditional MvSessionMode.guided in ${file.path}:${i + 1}: "$line"',
              );
            }
          }
        }
      },
    );
  });
}
