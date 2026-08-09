import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/migration/migrations/migration_v86_notes.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('notebook_migration_v86_integrity_test (V-01)', () async {
    final db = await openDatabase(inMemoryDatabasePath);
    final migration = MigrationV86Notes();
    await migration.up(db);

    // Verify all 6 tables exist
    final tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table';");
    final tableNames = tables.map((t) => t['name'] as String).toSet();

    expect(tableNames.contains('notes'), isTrue);
    expect(tableNames.contains('note_links'), isTrue);
    expect(tableNames.contains('note_tags'), isTrue);
    expect(tableNames.contains('note_attachments'), isTrue);
    expect(tableNames.contains('note_revisions'), isTrue);
    expect(tableNames.contains('note_experience_meta'), isTrue);

    await db.close();
  });
}
