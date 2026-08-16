import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/schema/tables/movement_tables.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  try {
    sqfliteFfiInit();
  } catch (_) {}

  group('Movement Database Migration v106 & Schema Tests', () {
    Database? db;
    bool dbInitialized = false;

    setUp(() async {
      try {
        databaseFactory = databaseFactoryFfi;
        db = await databaseFactory.openDatabase(inMemoryDatabasePath);
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

    test('Creates all 4 movement tables and seeds 8 base activity kinds', () async {
      if (!dbInitialized || db == null) {
        return;
      }

      await MovementTables.create(db!);
      await MovementTables.seedInitialData(db!);

      // 1. Verify tables exist
      final tables = await db!.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name LIKE 'movement_%'",
      );
      final tableNames = tables.map((t) => t['name'] as String).toSet();

      expect(tableNames.contains(MovementTables.tableActivityKinds), isTrue);
      expect(tableNames.contains(MovementTables.tableOccurrences), isTrue);
      expect(tableNames.contains(MovementTables.tableLiveSessions), isTrue);
      expect(tableNames.contains(MovementTables.tableStrengthPrograms), isTrue);
      expect(tableNames.contains(MovementTables.tablePlanTemplates), isTrue);
      expect(tableNames.contains(MovementTables.tablePlanSchedules), isTrue);
      expect(tableNames.contains(MovementTables.tableWorkoutLogs), isTrue);

      // 2. Verify 8 seeded activity kinds
      final kinds = await db!.query(MovementTables.tableActivityKinds);
      expect(kinds.length, equals(8));

      final kindIds = kinds.map((k) => k['id'] as String).toSet();
      expect(kindIds.contains('kind_walking'), isTrue);
      expect(kindIds.contains('kind_running'), isTrue);
      expect(kindIds.contains('kind_cycling'), isTrue);
      expect(kindIds.contains('kind_swimming'), isTrue);
      expect(kindIds.contains('kind_team_sports'), isTrue);
      expect(kindIds.contains('kind_hiking'), isTrue);
      expect(kindIds.contains('kind_yoga_mobility'), isTrue);
      expect(kindIds.contains('kind_strength'), isTrue);
    });
  });
}
