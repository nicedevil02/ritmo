import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/features/cycle/logic/pregnancy_settings.dart';
import 'package:ritmo/features/cycle/presentation/onboarding/pregnancy_onboarding_controller.dart';
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

  group('Consent Restore After Pregnancy Tests (PRG-44)', () {
    test('restores pre-pregnancy consent values upon pregnancy exit', () async {
      // 1. Initial state: custom consents
      await db.insert('app_settings', {
        'key': 'cycle_consent_reminders',
        'value': 'true',
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await db.insert('app_settings', {
        'key': 'cycle_consent_worship',
        'value': 'false',
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await db.insert('app_settings', {
        'key': 'cycle_consent_dashboard',
        'value': 'true',
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      // 2. Onboard into pregnancy with suspensions enabled
      final controller = PregnancyOnboardingController();
      controller.setLmpDate(DateTime(2026, 1, 1));
      controller.pauseCyclePredictions = true;
      controller.suspendWorship = true;
      controller.hideFromDashboard = true;

      await controller.save(db: db);

      // Verify consents suspended
      final duringRows = await db.query('app_settings');
      final duringMap = {for (final r in duringRows) r['key'] as String: r['value']};
      expect(duringMap['cycle_consent_reminders'], 'false');
      expect(duringMap['cycle_consent_worship'], 'false');
      expect(duringMap['cycle_consent_dashboard'], 'false');
      expect(duringMap['cycle_pregnancy_mode'], 'true');

      // Verify backup keys created
      expect(duringMap[PregnancySettings.keyPrevConsentReminders], 'true');
      expect(duringMap[PregnancySettings.keyPrevConsentWorship], 'false');
      expect(duringMap[PregnancySettings.keyPrevConsentDashboard], 'true');

      // 3. Exit pregnancy
      await PregnancySettings.setPregnancyActive(false, db: db);

      // 4. Verify original consents restored
      final afterRows = await db.query('app_settings');
      final afterMap = {for (final r in afterRows) r['key'] as String: r['value']};
      expect(afterMap['cycle_pregnancy_mode'], 'false');
      expect(afterMap['cycle_consent_reminders'], 'true');
      expect(afterMap['cycle_consent_worship'], 'false');
      expect(afterMap['cycle_consent_dashboard'], 'true');

      // Verify backup keys cleaned up
      expect(afterMap.containsKey(PregnancySettings.keyPrevConsentReminders), isFalse);
      expect(afterMap.containsKey(PregnancySettings.keyPrevConsentWorship), isFalse);
      expect(afterMap.containsKey(PregnancySettings.keyPrevConsentDashboard), isFalse);
    });

    test('defaults to true for legacy users without backup consent keys', () async {
      await db.insert('app_settings', {
        'key': 'cycle_pregnancy_mode',
        'value': 'true',
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await db.insert('app_settings', {
        'key': 'cycle_consent_reminders',
        'value': 'false',
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await db.insert('app_settings', {
        'key': 'cycle_consent_worship',
        'value': 'false',
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      // Call restoreCycleConsents without any backup keys in app_settings
      await PregnancySettings.restoreCycleConsents(db: db);

      final rows = await db.query('app_settings');
      final map = {for (final r in rows) r['key'] as String: r['value']};
      expect(map['cycle_consent_reminders'], 'true');
      expect(map['cycle_consent_worship'], 'true');
      expect(map['cycle_consent_dashboard'], 'true');
    });
  });
}
