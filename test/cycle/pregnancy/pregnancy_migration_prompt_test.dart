import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/features/cycle/logic/pregnancy_settings.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../test_helpers/cycle_test_db.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late Database db;

  setUpAll(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    db = await openCycleTestDb();
    DatabaseHelper.instance.overrideDatabaseForTesting(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('Pregnancy Migration Prompt Tests (PRG-47)', () {
    test('shouldShowMigrationPrompt returns true when pregnancy mode is active but dates are missing and prompt not shown', () {
      final settings = <String, dynamic>{
        'cycle_pregnancy_mode': 'true',
        'pregnancy_mode': 'true',
        // No preg_start_date / preg_due_date
        // preg_setup_done is missing
        // preg_migration_prompt_shown is missing
      };

      expect(PregnancySettings.shouldShowMigrationPrompt(settings), isTrue);
    });

    test('shouldShowMigrationPrompt returns false when dates are valid', () {
      final settings = <String, dynamic>{
        'cycle_pregnancy_mode': 'true',
        'pregnancy_mode': 'true',
        'preg_start_date': '2026-01-01',
        'preg_due_date': '2026-10-08',
      };

      expect(PregnancySettings.shouldShowMigrationPrompt(settings), isFalse);
    });

    test('shouldShowMigrationPrompt returns false when setup was explicitly done', () {
      final settings = <String, dynamic>{
        'cycle_pregnancy_mode': 'true',
        'pregnancy_mode': 'true',
        'preg_setup_done': 'true',
      };

      expect(PregnancySettings.shouldShowMigrationPrompt(settings), isFalse);
    });

    test('shouldShowMigrationPrompt returns false when prompt was already shown once', () {
      final settings = <String, dynamic>{
        'cycle_pregnancy_mode': 'true',
        'pregnancy_mode': 'true',
        PregnancySettings.keyMigrationPromptShown: 'true',
      };

      expect(PregnancySettings.shouldShowMigrationPrompt(settings), isFalse);
    });

    test('shouldShowMigrationPrompt returns false when pregnancy mode is false', () {
      final settings = <String, dynamic>{
        'cycle_pregnancy_mode': 'false',
        'pregnancy_mode': 'false',
      };

      expect(PregnancySettings.shouldShowMigrationPrompt(settings), isFalse);
    });

    test('Saving keyMigrationPromptShown persists to app_settings', () async {
      await PregnancySettings.saveSetting(
        PregnancySettings.keyMigrationPromptShown,
        'true',
        db,
      );

      final rows = await db.query(
        'app_settings',
        where: 'key = ?',
        whereArgs: [PregnancySettings.keyMigrationPromptShown],
      );
      expect(rows, isNotEmpty);
      expect(rows.first['value'], 'true');
    });
  });
}
