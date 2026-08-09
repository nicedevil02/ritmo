import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/migration/migrations/migration_v86_notes.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('migration_v86_upgrade_test (D-10)', () async {
    final db = await openDatabase(inMemoryDatabasePath);

    // Run migration up to V86
    final migration = MigrationV86Notes();
    expect(migration.version, equals(86));
    await migration.up(db);

    // Verify all 6 tables exist
    final tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table';");
    final tableNames = tables.map((t) => t['name'] as String).toList();

    expect(tableNames, contains('notes'));
    expect(tableNames, contains('note_links'));
    expect(tableNames, contains('note_tags'));
    expect(tableNames, contains('note_attachments'));
    expect(tableNames, contains('note_revisions'));
    expect(tableNames, contains('note_experience_meta'));

    // Verify key indices exist
    final indices = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='index';");
    final indexNames = indices.map((i) => i['name'] as String).toList();

    expect(indexNames, contains('idx_notes_status_updated'));
    expect(indexNames, contains('idx_notes_kind_status'));
    expect(indexNames, contains('idx_notes_daykey'));
    expect(indexNames, contains('idx_notes_source'));
    expect(indexNames, contains('idx_note_links_unique'));
    expect(indexNames, contains('idx_note_tags_norm'));
    expect(indexNames, contains('idx_experience_active'));

    await db.close();
  });
}
