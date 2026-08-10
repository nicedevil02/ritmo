import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/services/module_management_service.dart';
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
        await d.execute('CREATE TABLE IF NOT EXISTS goals (id TEXT PRIMARY KEY);');
        await d.execute('CREATE TABLE IF NOT EXISTS goal_steps (id TEXT PRIMARY KEY);');
        await d.execute('CREATE TABLE IF NOT EXISTS planning_cycles (id TEXT PRIMARY KEY);');
        await d.execute('CREATE TABLE IF NOT EXISTS planning_commitments (id TEXT PRIMARY KEY);');
        await d.execute('CREATE TABLE IF NOT EXISTS planning_allocations (id TEXT PRIMARY KEY);');
        await d.execute('CREATE TABLE IF NOT EXISTS planning_reviews (id TEXT PRIMARY KEY);');
        await d.execute('CREATE TABLE IF NOT EXISTS app_settings (key TEXT PRIMARY KEY, value TEXT, updatedAt INTEGER);');
      },
    );
    DatabaseHelper.databaseInstance = db;
  });

  tearDown(() async {
    DatabaseHelper.databaseInstance = null;
    await db.close();
  });

  test('D-10 resetModuleData(module_goals_enabled) clears planning tables', () async {
    await db.insert('goals', {'id': 'g1'});
    await db.insert('planning_cycles', {'id': 'c1'});
    await db.insert('planning_commitments', {'id': 'cm1'});
    await db.insert('planning_allocations', {'id': 'a1'});
    await db.insert('planning_reviews', {'id': 'r1'});
    await db.insert('app_settings', {'key': 'planning_test_key', 'value': 'val', 'updatedAt': 100});

    await ModuleManagementService.instance.resetModuleData('module_goals_enabled');

    expect((await db.query('goals')).isEmpty, isTrue);
    expect((await db.query('planning_cycles')).isEmpty, isTrue);
    expect((await db.query('planning_commitments')).isEmpty, isTrue);
    expect((await db.query('planning_allocations')).isEmpty, isTrue);
    expect((await db.query('planning_reviews')).isEmpty, isTrue);
    expect((await db.query('app_settings', where: 'key = ?', whereArgs: ['planning_test_key'])).isEmpty, isTrue);
  });
}
