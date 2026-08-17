import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class CycleTestDb {
  static Future<Database> createInMemoryDb() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    final db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS app_settings (
              key TEXT PRIMARY KEY,
              value TEXT,
              updatedAt INTEGER
            )
          ''');

          await db.execute('''
            CREATE TABLE IF NOT EXISTS cycle_periods (
              id TEXT PRIMARY KEY,
              startDate TEXT NOT NULL,
              endDate TEXT,
              flowIntensity TEXT,
              isPredicted INTEGER DEFAULT 0,
              createdAt INTEGER,
              updatedAt INTEGER
            )
          ''');

          await db.execute('''
            CREATE TABLE IF NOT EXISTS cycle_day_logs (
              dayKey TEXT PRIMARY KEY,
              flow TEXT,
              pain INTEGER,
              mood TEXT,
              symptoms TEXT,
              sexualActivity INTEGER,
              notes TEXT,
              createdAt INTEGER,
              updatedAt INTEGER
            )
          ''');

          await db.execute('''
            CREATE TABLE IF NOT EXISTS worship_debts (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              type TEXT NOT NULL,
              count INTEGER DEFAULT 0,
              status TEXT DEFAULT 'pending',
              notes TEXT,
              createdAt INTEGER,
              updatedAt INTEGER
            )
          ''');

          await db.execute('''
            CREATE TABLE IF NOT EXISTS daily_checkins (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              date TEXT,
              energy INTEGER,
              focus INTEGER,
              mood TEXT,
              stress INTEGER,
              notes TEXT,
              createdAt INTEGER
            )
          ''');
        },
      ),
    );

    return db;
  }

  static Future<void> seedSettings(
    Database db,
    Map<String, String> settings,
  ) async {
    final batch = db.batch();
    for (final entry in settings.entries) {
      batch.insert('app_settings', {
        'key': entry.key,
        'value': entry.value,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  static Future<void> seedPeriods(
    Database db,
    List<Map<String, dynamic>> periods,
  ) async {
    final batch = db.batch();
    for (final p in periods) {
      batch.insert(
        'cycle_periods',
        p,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  static Future<void> seedDayLogs(
    Database db,
    List<Map<String, dynamic>> logs,
  ) async {
    final batch = db.batch();
    for (final l in logs) {
      batch.insert(
        'cycle_day_logs',
        l,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }
}
