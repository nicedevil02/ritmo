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

  group('Partial Brief Error Isolation Tests (PSN-32)', () {
    test('Failure in one domain does not collapse the rest of the brief', () async {
      await db.insert('app_settings', {'key': 'assistant_cloud_consent', 'value': 'true'});
      await db.insert('app_settings', {'key': 'module_today_routines', 'value': 'true'});

      // Intentionally drop bedtime_diagnostics table to cause sleep brief failure
      await db.execute('DROP TABLE bedtime_diagnostics');

      final globalPersona = PersonaRegistry.instance.getPersona('global')!;
      final briefJson = await PersonaContextProvider.getBriefJson(globalPersona);

      final decoded = jsonDecode(briefJson) as Map<String, dynamic>;
      // Sleep failed, but routines and wellbeing remain intact
      expect(decoded.containsKey('routines'), isTrue);
      expect(decoded.containsKey('partial_missing_domains'), isTrue);
      final missing = List<String>.from(decoded['partial_missing_domains'] as List);
      expect(missing, contains('sleep'));
    });
  });
}
