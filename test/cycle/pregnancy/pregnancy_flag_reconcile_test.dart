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

  group('Pregnancy Flag Reconcile Tests (PRG-48)', () {
    test('Reconciles when only cycle_pregnancy_mode is true', () async {
      final settings = <String, dynamic>{
        'cycle_pregnancy_mode': 'true',
      };

      await PregnancySettings.reconcileFlags(settings, db);

      expect(settings['cycle_pregnancy_mode'], 'true');
      expect(settings['pregnancy_mode'], 'true');
      expect(settings['cycle_is_pregnant'], 'true');

      final rows = await db.query('app_settings');
      final map = {for (final r in rows) r['key'] as String: r['value']};
      expect(map['cycle_pregnancy_mode'], 'true');
      expect(map['pregnancy_mode'], 'true');
      expect(map['cycle_is_pregnant'], 'true');
    });

    test('Reconciles when only pregnancy_mode is true', () async {
      final settings = <String, dynamic>{
        'pregnancy_mode': 'true',
      };

      await PregnancySettings.reconcileFlags(settings, db);

      expect(settings['cycle_pregnancy_mode'], 'true');
      expect(settings['pregnancy_mode'], 'true');
      expect(settings['cycle_is_pregnant'], 'true');
    });

    test('Reconciles when only cycle_is_pregnant is true', () async {
      final settings = <String, dynamic>{
        'cycle_is_pregnant': 'true',
      };

      await PregnancySettings.reconcileFlags(settings, db);

      expect(settings['cycle_pregnancy_mode'], 'true');
      expect(settings['pregnancy_mode'], 'true');
      expect(settings['cycle_is_pregnant'], 'true');
    });

    test('Does not reconcile when all flags are false or absent', () async {
      final settings = <String, dynamic>{
        'cycle_pregnancy_mode': 'false',
        'pregnancy_mode': 'false',
      };

      await PregnancySettings.reconcileFlags(settings, db);

      expect(settings['cycle_pregnancy_mode'], 'false');
      expect(settings['pregnancy_mode'], 'false');
      expect(settings['cycle_is_pregnant'], isNull);
    });
  });
}
