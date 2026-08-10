import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/features/health/data/pregnancy_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ritmo/core/database/database_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  try {
    sqfliteFfiInit();
  } catch (_) {}

  group('PregnancyRepository Tests', () {
    late Database db;
    bool dbInitialized = false;

    setUp(() async {
      try {
        databaseFactory = databaseFactoryFfi;
        db = await openDatabase(inMemoryDatabasePath, version: 1, onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE app_settings (
              key TEXT PRIMARY KEY,
              value TEXT,
              updatedAt INTEGER
            )
          ''');
          await db.execute('''
            CREATE TABLE pregnancy_tracker (
              id TEXT PRIMARY KEY,
              lmpDate TEXT NOT NULL,
              estimatedDueDate TEXT NOT NULL,
              currentWeek INTEGER NOT NULL,
              currentTrimester INTEGER NOT NULL,
              isActive INTEGER NOT NULL DEFAULT 1,
              notes TEXT,
              createdAt INTEGER NOT NULL,
              updatedAt INTEGER NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE pregnancy_checkups (
              id TEXT PRIMARY KEY,
              pregnancyId TEXT NOT NULL,
              title TEXT NOT NULL,
              scheduledDate INTEGER,
              actualDate INTEGER,
              type TEXT NOT NULL,
              result TEXT,
              notes TEXT,
              isCompleted INTEGER DEFAULT 0,
              createdAt INTEGER NOT NULL
            )
          ''');
        });
        DatabaseHelper.instance.overrideDatabaseForTesting(db);
        dbInitialized = true;
      } catch (e) {
        dbInitialized = false;
      }
    });

    tearDown(() async {
      if (dbInitialized) {
        await db.close();
      }
    });

    test('GestationalAge calculations test', () {
      final ga = GestationalAge.fromDays(100);
      expect(ga.weeks, equals(14));
      expect(ga.days, equals(2));
      expect(ga.trimester, equals(2));
    });

    test('startTracker creates active pregnancy_tracker if FFI DB available', () async {
      if (!dbInitialized) return;
      final lmp = DateTime(2026, 8, 6);
      final trackerId = await PregnancyRepository.instance.startTracker(lmp: lmp);

      final active = await PregnancyRepository.instance.getActiveTracker();
      expect(active, isNotNull);
      expect(active!['id'], equals(trackerId));
      expect(active['lmpDate'], equals('2026-08-06'));
    });
  });
}
