import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('Phase 5: Config, Dependencies & Build Tests', () {
    test('RIT-062: ensureCriticalSchema performs JSON1 extension capability check', () async {
      final db = await DatabaseHelper.instance.database;
      await DatabaseHelper.ensureCriticalSchema(db);

      // Verify that json_valid query executes without error on modern SQLite
      final result = await db.rawQuery("SELECT json_valid('{\"key\": 123}') AS isValid;");
      expect(result.first['isValid'], equals(1));
    });

    test('RIT-066: analysis_options.yaml does not contain stale file exclusions', () {
      final file = File('analysis_options.yaml');
      expect(file.existsSync(), isTrue);

      final content = file.readAsStringSync();
      expect(content.contains('worship_collectors.dart'), isFalse);
    });

    test('RIT-060 & RIT-061: pubspec.yaml does not contain beta packages or redundant overrides', () {
      final file = File('pubspec.yaml');
      expect(file.existsSync(), isTrue);

      final content = file.readAsStringSync();
      expect(content.contains('12.0.0-beta.7'), isFalse);
      expect(content.contains('file_selector: ^1.0.3'), isTrue);
    });
  });
}
