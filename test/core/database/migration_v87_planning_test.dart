import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/migration/migrations/migration_v87_planning.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database db;

  setUp(() async {
    db = await openDatabase(
      inMemoryDatabasePath,
      version: 1,
      onCreate: (d, v) async {
        await d.execute('''
          CREATE TABLE IF NOT EXISTS app_settings (
            key TEXT PRIMARY KEY,
            value TEXT,
            updatedAt INTEGER
          );
        ''');
        await d.execute('''
          CREATE TABLE IF NOT EXISTS day_plan_templates (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            plan_json TEXT NOT NULL,
            created_at INTEGER NOT NULL DEFAULT 0,
            updated_at INTEGER NOT NULL DEFAULT 0
          );
        ''');
      },
    );
  });

  tearDown(() async {
    await db.close();
  });

  test('D-09 Migration V87 test: creates tables, converts day_plan_templates, populates settings keys', () async {
    final migration = MigrationV87Planning();
    expect(migration.version, equals(87));

    await migration.up(db);

    // Verify 4 new tables exist
    final tablesRes = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table';");
    final tableNames = tablesRes.map((r) => r['name'] as String).toSet();

    expect(tableNames.contains('planning_cycles'), isTrue);
    expect(tableNames.contains('planning_commitments'), isTrue);
    expect(tableNames.contains('planning_allocations'), isTrue);
    expect(tableNames.contains('planning_reviews'), isTrue);

    // Verify day_plan_templates column migration (A-03)
    final templateCols = (await db.rawQuery("PRAGMA table_info('day_plan_templates');"))
        .map((r) => r['name'] as String)
        .toSet();
    expect(templateCols.contains('name'), isTrue);
    expect(templateCols.contains('itemsJson'), isTrue);
    expect(templateCols.contains('lastUsedAt'), isTrue);
    expect(templateCols.contains('useCount'), isTrue);

    // Verify 6 app settings keys
    final settings = await db.query('app_settings');
    final settingsKeys = settings.map((s) => s['key'] as String).toSet();
    expect(settingsKeys.contains('planning_week_ritual_enabled'), isTrue);
    expect(settingsKeys.contains('planning_reserve_profile'), isTrue);
    expect(settingsKeys.contains('planning_month_focus_limit'), isTrue);
    expect(settingsKeys.contains('planning_midweek_checkin_enabled'), isTrue);
    expect(settingsKeys.contains('planning_show_on_dashboard'), isTrue);
    expect(settingsKeys.contains('planning_ai_scenarios_enabled'), isTrue);

    // Idempotent check
    await migration.up(db);

    // Test down method
    await migration.down(db);
    final tablesAfterDown = (await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table';"))
        .map((r) => r['name'] as String)
        .toSet();
    expect(tablesAfterDown.contains('planning_cycles'), isFalse);
    expect(tablesAfterDown.contains('planning_commitments'), isFalse);
    expect(tablesAfterDown.contains('planning_allocations'), isFalse);
    expect(tablesAfterDown.contains('planning_reviews'), isFalse);
  });
}
