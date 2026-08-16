import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/schema/tables/movement_tables.dart';
import 'package:ritmo/features/movement/application/movement_readiness_service.dart';
import 'package:ritmo/features/movement/domain/models/movement_readiness_checkin.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  try {
    sqfliteFfiInit();
  } catch (_) {}

  group('MovementReadinessService Tests (Gate 5)', () {
    Database? db;
    bool dbInitialized = false;
    late MovementReadinessService service;

    setUp(() async {
      service = MovementReadinessService();
      try {
        databaseFactory = databaseFactoryFfi;
        db = await databaseFactory.openDatabase(inMemoryDatabasePath);
        await MovementTables.create(db!);
        service = MovementReadinessService(db: db);
        dbInitialized = true;
      } catch (_) {
        dbInitialized = false;
      }
    });

    tearDown(() async {
      if (dbInitialized && db != null) {
        await db!.close();
      }
    });

    test('records check-in with optional fields and retrieves today checkin', () async {
      if (!dbInitialized || db == null) return;
      final now = DateTime(2026, 8, 16);
      final checkin = MovementReadinessCheckin(
        id: 'chk_1',
        dateIso: '2026-08-16',
        sleep: 4,
        energy: 5,
        soreness: 1,
        stress: 2,
        availableMinutes: 30,
        createdAt: now,
      );

      await service.recordCheckin(checkin);
      final retrieved = await service.getTodayCheckin(now);

      expect(retrieved, isNotNull);
      expect(retrieved!.id, equals('chk_1'));
      expect(retrieved.sleep, equals(4));
      expect(retrieved.energy, equals(5));
      expect(retrieved.filledFieldsCount, equals(5));
    });

    test('computeReadinessResult returns descriptive status without numeric score', () {
      final highEnergyCheckin = MovementReadinessCheckin(
        id: 'chk_high',
        dateIso: '2026-08-16',
        sleep: 5,
        energy: 5,
        soreness: 1,
        stress: 1,
        createdAt: DateTime.now(),
      );

      final result = service.computeReadinessResult(highEnergyCheckin);
      expect(result.statusHeadline, contains('آمادگی بسیار مناسب'));
      expect(result.suggestions.length, inInclusiveRange(1, 3));
      expect(result.statusHeadline.contains('/100'), isFalse);
      expect(result.statusHeadline.contains('%'), isFalse);
    });

    test('computeReadinessResult handles sore or low sleep checkin with Plan B suggestion', () {
      final tiredCheckin = MovementReadinessCheckin(
        id: 'chk_tired',
        dateIso: '2026-08-16',
        sleep: 1,
        energy: 2,
        soreness: 5,
        stress: 4,
        createdAt: DateTime.now(),
      );

      final result = service.computeReadinessResult(tiredCheckin);
      expect(result.statusHeadline, contains('نیاز به تمرکز بر ریکاوری'));
      expect(result.suggestions.any((s) => s.contains('Plan B')), isTrue);
    });

    test('getCoachSuggestion produces actionable non-blocking suggestion', () async {
      final highEnergyCheckin = MovementReadinessCheckin(
        id: 'chk_high',
        dateIso: '2026-08-16',
        sleep: 5,
        energy: 5,
        soreness: 1,
        stress: 1,
        createdAt: DateTime.now(),
      );

      final suggestion = await service.getCoachSuggestion(
        checkin: highEnergyCheckin,
        dismissedSuggestionIds: [],
      );

      expect(suggestion, isNotNull);
      expect(suggestion!.id, equals('sug_high_energy_focus'));
      expect(suggestion.primaryActionLabel.isNotEmpty, isTrue);

      // If dismissed, returns null
      final dismissedSuggestion = await service.getCoachSuggestion(
        checkin: highEnergyCheckin,
        dismissedSuggestionIds: ['sug_high_energy_focus'],
      );
      expect(dismissedSuggestion, isNull);
    });
  });
}
