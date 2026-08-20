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
  });

  tearDown(() async {
    await db.close();
  });

  group('Rhythm Brief Tests (PSN-29)', () {
    test('Calculates positive daily capacity and allocated minutes from data', () async {
      await db.insert('app_settings', {'key': 'sleep_target_duration_minutes', 'value': '480'});
      await db.insert('routines', {'id': 'r1', 'title': 'ورزش صبحگاهی', 'isArchived': 0, 'durationMinutes': 30});
      await db.insert('routines', {'id': 'r2', 'title': 'مطالعه', 'isArchived': 0, 'durationMinutes': 45});

      final globalPersona = PersonaRegistry.instance.getPersona('global')!;
      final primaryBrief = await PersonaContextProvider.getPrimaryBrief(globalPersona);

      expect(primaryBrief, isNotNull);
      expect(primaryBrief!.sampleSize, greaterThan(0));
      final json = primaryBrief.toPromptJson();
      expect(json['dailyCapacityMinutes'], equals(1440 - 480 - 120)); // 840
      expect(json['allocatedMinutes'], equals(75));
    });
  });
}
