import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/ai/brief/persona_context_provider.dart';
import 'package:ritmo/core/domain/personas/persona_registry.dart';
import 'package:ritmo/core/domain/commands/commands_registry.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ritmo/core/database/database_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;

  setUpAll(() async {
    registerAllRitmoCommands();
    PersonaRegistry.instance.initStandardPersonas();
  });

  setUp(() async {
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    DatabaseHelper.instance.overrideDatabaseForTesting(db);

    await db.execute('CREATE TABLE app_settings (key TEXT PRIMARY KEY, value TEXT)');
    await db.execute('CREATE TABLE routines (id TEXT PRIMARY KEY, title TEXT, isArchived INTEGER DEFAULT 0, durationMinutes INTEGER)');
    await db.execute('CREATE TABLE routine_completions (id TEXT PRIMARY KEY, routineId TEXT, completionDate TEXT)');
    await db.execute('CREATE TABLE bedtime_diagnostics (id TEXT PRIMARY KEY, date TEXT, bedtimeAt INTEGER, wakeAt INTEGER, quality REAL, durationMinutes INTEGER)');
    await db.execute('CREATE TABLE energy_logs (id TEXT PRIMARY KEY, loggedAt INTEGER, energyLevel TEXT)');
    await db.execute('CREATE TABLE mood_logs (id TEXT PRIMARY KEY, loggedAt INTEGER, mood TEXT, valence REAL)');
    await db.execute('CREATE TABLE daily_reflections (id TEXT PRIMARY KEY, date TEXT, mood_score REAL)');
  });

  tearDown(() async {
    await db.close();
  });

  group('PersonaGate Brief Routing Tests (PSN-27)', () {
    test('Returns consent_revoked when assistant_cloud_consent is false', () async {
      await db.insert('app_settings', {'key': 'assistant_cloud_consent', 'value': 'false'});

      final persona = PersonaRegistry.instance.getPersona('sleep')!;
      final briefJson = await PersonaContextProvider.getBriefJson(persona);

      final decoded = jsonDecode(briefJson) as Map<String, dynamic>;
      expect(decoded['status'], equals('consent_revoked'));
    });

    test('Omits domain data when corresponding module flag is disabled', () async {
      await db.insert('app_settings', {'key': 'assistant_cloud_consent', 'value': 'true'});
      await db.insert('app_settings', {'key': 'module_goals_enabled', 'value': 'false'});

      final persona = PersonaRegistry.instance.getPersona('global')!;
      final briefJson = await PersonaContextProvider.getBriefJson(persona);

      final decoded = jsonDecode(briefJson) as Map<String, dynamic>;
      expect(decoded.containsKey('goals'), isFalse);
    });

    test('Assembles brief when consent is true and modules are enabled', () async {
      await db.insert('app_settings', {'key': 'assistant_cloud_consent', 'value': 'true'});
      await db.insert('app_settings', {'key': 'module_today_routines', 'value': 'true'});

      final persona = PersonaRegistry.instance.getPersona('sleep')!;
      final briefJson = await PersonaContextProvider.getBriefJson(persona);

      final decoded = jsonDecode(briefJson) as Map<String, dynamic>;
      expect(decoded['status'], isNot(equals('consent_revoked')));
      expect(decoded.containsKey('sleep'), isTrue);
    });
  });
}
