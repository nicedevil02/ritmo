import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/database/schema/schema_manager.dart';
import 'package:ritmo/features/onboarding/logic/day_arc_inferencer.dart';
import 'package:ritmo/features/onboarding/logic/onboarding_draft.dart';
import 'package:ritmo/features/onboarding/logic/onboarding_gate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});

    db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await SchemaManager.createAll(db);
        },
      ),
    );

    await DatabaseHelper.ensureCriticalSchema(db);
    DatabaseHelper.instance.overrideDatabaseForTesting(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('Onboarding Fixes Audit (RITF-082 .. RITF-084)', () {
    test('RITF-082: OnboardingGate heals SQLite app_settings from SharedPreferences', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_completed', true);
      await prefs.setString('user_name', 'Ali');

      // Before calling isCompleted, DB has no rows
      final beforeDb = await db.query('app_settings', where: "key = 'onboarding_completed'");
      expect(beforeDb.isEmpty, isTrue);

      final completed = await OnboardingGate.isCompleted(db);
      expect(completed, isTrue);

      // Now DB is healed with user_name and onboarding_completed
      final afterDb = await db.query('app_settings', where: "key = 'onboarding_completed'");
      expect(afterDb.isNotEmpty, isTrue);
      expect(afterDb.first['value'], 'true');

      final userRow = await db.query('app_settings', where: "key = 'user_name'");
      expect(userRow.isNotEmpty, isTrue);
      expect(userRow.first['value'], 'Ali');
    });

    test('RITF-083: OnboardingGate.markCompleted uses atomic upsert without corrupting', () async {
      await OnboardingGate.markCompleted(db, version: 1, userName: 'Sara');
      expect(await OnboardingGate.isCompleted(db), isTrue);
      expect(await OnboardingGate.completedVersion(db), 1);

      // Updating version or name overwrites gracefully
      await OnboardingGate.markCompleted(db, version: 2, userName: 'Sara J');
      expect(await OnboardingGate.completedVersion(db), 2);

      final userRow = await db.query('app_settings', where: "key = 'user_name'");
      expect(userRow.first['value'], 'Sara J');
    });

    test('RITF-083: OnboardingDraftStore saves, loads, and clears draft cleanly', () async {
      final draft = OnboardingDraft(
        stepIndex: 2,
        state: {'selectedRoutines': ['wake_up', 'reading']},
        savedAt: DateTime.now().millisecondsSinceEpoch,
      );

      await OnboardingDraftStore.save(draft);
      final loaded = await OnboardingDraftStore.load();
      expect(loaded, isNotNull);
      expect(loaded!.stepIndex, 2);
      expect(loaded.state['selectedRoutines'], ['wake_up', 'reading']);

      await OnboardingDraftStore.clear();
      final cleared = await OnboardingDraftStore.load();
      expect(cleared, isNull);
    });

    test('RITF-084: DayArcInferencer returns default suggestion if prayer time unavailable', () async {
      final suggestion = await DayArcInferencer.suggest();
      expect(suggestion.wakeTime, isNotEmpty);
      expect(suggestion.sleepTime, isNotEmpty);
      expect(suggestion.reasonFa, isNotEmpty);
    });
  });
}
