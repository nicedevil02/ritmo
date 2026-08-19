import 'package:ritmo/core/database/schema/tables/cycle_tables.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<Database> openCycleTestDb({
  Map<String, String>? initialSettings,
}) async {
  sqfliteFfiInit();
  final db = await databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      version: 1,
      onCreate: (db, v) async {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS app_settings (
            key TEXT PRIMARY KEY,
            value TEXT,
            updatedAt INTEGER
          );
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS cycle_confirmations (
            id TEXT PRIMARY KEY,
            kind TEXT NOT NULL,
            targetDate TEXT NOT NULL,
            answer TEXT,
            answeredAt INTEGER,
            askCount INTEGER NOT NULL DEFAULT 0,
            lastAskedAt INTEGER,
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL
          );
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS fasting_debt (
            id TEXT PRIMARY KEY,
            dateIso TEXT,
            daysOwed INTEGER,
            isResolved INTEGER,
            reason TEXT,
            createdAt INTEGER,
            updatedAt INTEGER
          );
        ''');
        await CycleTables.create(db);
      },
    ),
  );

  final now = DateTime.now().millisecondsSinceEpoch;
  final defaultSettings = {
    'user_gender': 'FEMALE',
    'module_cycle_enabled': 'true',
    'cycle_length_days': '28',
    'period_duration_days': '6',
    'luteal_phase_days': '14',
    'cycle_pms_window_days': '4',
    'cycle_consent_worship': 'false',
    'cycle_consent_reminders': 'false',
    'cycle_pregnancy_mode': 'false',
    ...?initialSettings,
  };

  for (final e in defaultSettings.entries) {
    await db.insert(
      'app_settings',
      {
        'key': e.key,
        'value': e.value,
        'updatedAt': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  return db;
}
