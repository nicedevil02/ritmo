import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/database/schema/schema_manager.dart';
import 'package:ritmo/core/database/migration/migration_runner.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('Fresh Install DB Schema Verification', () async {
    final db = await databaseFactory.openDatabase(inMemoryDatabasePath, options: OpenDatabaseOptions(
      version: 92,
      onCreate: (db, version) async {
         await SchemaManager.createAll(db);
      },
    ));
    
    final tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table';");
    final tableNames = tables.map((t) => t['name'] as String).toList();
    
    expect(tableNames.contains('wellbeing_entry'), isTrue);
    expect(tableNames.contains('ss_session_set_log'), isTrue);
    expect(tableNames.contains('ai_memory'), isTrue);
    
    final aiMemoryCols = await db.rawQuery("PRAGMA table_info(ai_memory)");
    expect(aiMemoryCols.any((c) => c['name'] == 'scope'), isTrue);
    
    print('Fresh install schema checks passed!');
    await db.close();
  });
}
