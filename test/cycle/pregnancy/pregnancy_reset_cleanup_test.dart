import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/features/cycle/logic/pregnancy_settings.dart';
import 'package:ritmo/features/cycle/models/pregnancy_models.dart';
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

  group('Pregnancy Reset Cleanup Tests (PRG-45)', () {
    test('PregnancySettings.clearAll wipes all preg_ keys and preserves cycle data', () async {
      // 1. Setup pregnancy profile and extra preg_ keys
      final profile = PregnancyProfile(
        lmpDate: DateTime(2026, 1, 1),
        dueDate: DateTime(2026, 10, 8),
        tone: PregnancyTone.neutral,
        ageUnit: PregnancyAgeUnit.months,
        isMultiple: true,
        isHighRisk: true,
        sectionHidden: true,
        maskNotifications: true,
        lockEnabled: true,
      );
      await PregnancySettings.saveProfile(profile, db);
      await PregnancySettings.setPregnancyActive(true, db: db);
      await PregnancySettings.saveSetting('preg_custom_test_key', 'test_value', db);

      // Verify keys exist in app_settings
      final beforeRows = await db.query('app_settings');
      final beforePregKeys = beforeRows.where((r) => (r['key'] as String).startsWith('preg_')).toList();
      expect(beforePregKeys, isNotEmpty);

      // 2. Perform full clear
      await PregnancySettings.clearAll(db);

      // 3. Verify all preg_ keys are wiped from app_settings
      final afterRows = await db.query('app_settings');
      final afterPregKeys = afterRows.where((r) => (r['key'] as String).startsWith('preg_')).toList();
      expect(afterPregKeys, isEmpty);

      // 4. Verify pregnancy mode flags are false
      final afterMap = {for (final r in afterRows) r['key'] as String: r['value']};
      expect(afterMap['cycle_pregnancy_mode'], 'false');
      expect(afterMap['pregnancy_mode'], 'false');
      expect(afterMap['cycle_is_pregnant'], 'false');

      // 5. Verify general cycle settings and tables remain intact
      expect(afterMap['user_gender'], 'FEMALE');
      expect(afterMap['cycle_length_days'], '28');
      expect(afterMap['period_duration_days'], '6');
    });
  });
}
