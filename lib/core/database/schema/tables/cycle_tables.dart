import 'package:sqflite/sqflite.dart';

class CycleTables {
  static Future<void> create(DatabaseExecutor db) async {
    // 22. cycle_logs (V2 table)
    await db.execute('''
      CREATE TABLE cycle_logs (
          id TEXT PRIMARY KEY,
          cycleStartDate TEXT NOT NULL,
          cycleEndDate TEXT,
          phase TEXT,
          flowLevel TEXT,
          symptomsJson TEXT,
          isPredicted INTEGER NOT NULL DEFAULT 0,
          suppressedPrayer INTEGER NOT NULL DEFAULT 1,
          fastDebtCreated INTEGER NOT NULL DEFAULT 0,
          note TEXT,
          createdAt INTEGER NOT NULL,
          updatedAt INTEGER NOT NULL
      );
    ''');
    await db.execute('CREATE INDEX index_cycle_logs_cycleStartDate ON cycle_logs(cycleStartDate);');

    // هر تغییری در ستون‌های این جدول باید هم‌زمان در
    // lib/features/cycle/logic/cycle_period_contract.dart و
    // test/cycle/cycle_schema_contract_test.dart اعمال شود.
    // V14 cycle_periods table
    await db.execute('''
      CREATE TABLE cycle_periods (
          id TEXT PRIMARY KEY,
          startDate TEXT NOT NULL,
          endDate TEXT,
          flowIntensity TEXT DEFAULT 'MEDIUM',
          isPredicted INTEGER DEFAULT 0,
          note TEXT,
          autoClosed INTEGER NOT NULL DEFAULT 0,
          createdAt INTEGER,
          updatedAt INTEGER
      );
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS index_cycle_periods_startDate ON cycle_periods(startDate);');
    await db.execute('CREATE INDEX IF NOT EXISTS index_cycle_periods_endDate ON cycle_periods(endDate);');
    await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS uq_cycle_periods_single_open ON cycle_periods(autoClosed) WHERE endDate IS NULL;');

    // V14 cycle_day_logs table
    await db.execute('''
      CREATE TABLE cycle_day_logs (
          id TEXT PRIMARY KEY,
          logDate TEXT NOT NULL UNIQUE,
          flowLevel TEXT,
          symptomsJson TEXT,
          mood TEXT,
          energyTag TEXT,
          note TEXT,
          createdAt INTEGER,
          updatedAt INTEGER
      );
    ''');
  }
}
