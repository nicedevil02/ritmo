import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/settings/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('Phase 6: Architecture & Maintainability Tests', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final db = await databaseFactory.openDatabase(inMemoryDatabasePath);
      await db.execute('''
        CREATE TABLE IF NOT EXISTS app_settings (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL,
          updatedAt INTEGER NOT NULL
        );
      ''');
      DatabaseHelper.instance.overrideDatabaseForTesting(db);
    });

    test('RIT-073: DatabaseHelper.normalizeGender normalizes Persian and English gender strings', () {
      expect(DatabaseHelper.normalizeGender('FEMALE'), equals('FEMALE'));
      expect(DatabaseHelper.normalizeGender('woman'), equals('FEMALE'));
      expect(DatabaseHelper.normalizeGender('zan'), equals('FEMALE'));
      expect(DatabaseHelper.normalizeGender('زن'), equals('FEMALE'));

      expect(DatabaseHelper.normalizeGender('MALE'), equals('MALE'));
      expect(DatabaseHelper.normalizeGender('man'), equals('MALE'));
      expect(DatabaseHelper.normalizeGender('mard'), equals('MALE'));
      expect(DatabaseHelper.normalizeGender('مرد'), equals('MALE'));

      expect(DatabaseHelper.normalizeGender(null), isNull);
      expect(DatabaseHelper.normalizeGender('unknown'), isNull);
    });

    test('RIT-076: overrideDatabaseForTesting assigns databaseInstance properly', () async {
      final db = await databaseFactory.openDatabase(inMemoryDatabasePath);
      DatabaseHelper.instance.overrideDatabaseForTesting(db);
      expect(DatabaseHelper.rawDatabase, equals(db));
    });

    test('RIT-070: setBatch applies transactional batch updates', () async {
      final service = SettingsService.instance;
      await service.init();

      final count = await service.setBatch({
        'app_mode': 'simple',
        'coalescing_window_minutes': 30,
      });

      expect(count, greaterThan(0));
      expect(service.get<String>('app_mode'), equals('simple'));
      expect(service.get<int>('coalescing_window_minutes'), equals(30));
    });

    test('RIT-071: setChecked emits change notification for derived key', () async {
      final service = SettingsService.instance;
      await service.init();

      final changed = <String>[];
      final sub = service.changes.listen(changed.add);

      await service.setChecked('app_mode', 'full');
      await Future.delayed(const Duration(milliseconds: 50));

      expect(changed, contains('app_mode'));
      expect(changed, contains('show_advanced_settings'));
      expect(service.get<bool>('show_advanced_settings'), isTrue);

      await sub.cancel();
    });
  });
}
