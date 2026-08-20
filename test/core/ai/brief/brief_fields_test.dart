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

    await db.execute(
      'CREATE TABLE goals (id TEXT PRIMARY KEY, title TEXT, status TEXT)',
    );
    await db.execute(
      'CREATE TABLE goal_steps (id TEXT PRIMARY KEY, goalId TEXT, title TEXT, isCompleted INTEGER, dueDate TEXT, completedAt INTEGER)',
    );
    await db.execute(
      'CREATE TABLE konkur_subjects (id TEXT PRIMARY KEY, name TEXT, priority INTEGER)',
    );
    await db.execute(
      'CREATE TABLE courses (id TEXT PRIMARY KEY, title TEXT, status TEXT, targetSessionsPerWeek INTEGER)',
    );
    await db.execute(
      'CREATE TABLE course_sessions (id TEXT PRIMARY KEY, courseId TEXT, completedAt INTEGER)',
    );
    await db.execute(
      'CREATE TABLE notes (id TEXT PRIMARY KEY, title TEXT, content TEXT, tags TEXT, isArchived INTEGER, isLocked INTEGER, isPrivate INTEGER, createdAt INTEGER, reviewDueDate INTEGER)',
    );
    await db.execute(
      'CREATE TABLE experiences (id TEXT PRIMARY KEY, title TEXT, isArchived INTEGER)',
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('Computed Brief Fields Tests (PSN-30)', () {
    test(
      'GoalsBrief correctly distinguishes overdue steps from normal incomplete steps',
      () async {
        final now = DateTime.now();
        final pastDate = now
            .subtract(const Duration(days: 3))
            .toIso8601String();
        final futureDate = now.add(const Duration(days: 5)).toIso8601String();

        await db.insert('goals', {
          'id': 'g1',
          'title': 'هدف فعال',
          'status': 'ACTIVE',
        });
        // Step 1: overdue
        await db.insert('goal_steps', {
          'id': 's1',
          'goalId': 'g1',
          'title': 'گام ۱',
          'isCompleted': 0,
          'dueDate': pastDate,
        });
        // Step 2: not overdue (future)
        await db.insert('goal_steps', {
          'id': 's2',
          'goalId': 'g1',
          'title': 'گام ۲',
          'isCompleted': 0,
          'dueDate': futureDate,
        });
        // Step 3: completed
        await db.insert('goal_steps', {
          'id': 's3',
          'goalId': 'g1',
          'title': 'گام ۳',
          'isCompleted': 1,
          'dueDate': pastDate,
        });

        final goalsPersona = PersonaRegistry.instance.getPersona('goals')!;
        final brief = await PersonaContextProvider.getPrimaryBrief(
          goalsPersona,
        );

        expect(brief, isNotNull);
        final json = brief!.toPromptJson();
        expect(json['overdueStepsCount'], equals(1));
      },
    );

    test('StudyBrief sorts subjects by priority DESC', () async {
      await db.insert('konkur_subjects', {
        'id': 'sub1',
        'name': 'ریاضی',
        'priority': 5,
      });
      await db.insert('konkur_subjects', {
        'id': 'sub2',
        'name': 'زیست‌شناسی',
        'priority': 10,
      });
      await db.insert('konkur_subjects', {
        'id': 'sub3',
        'name': 'شیمی',
        'priority': 8,
      });

      final studyPersona = PersonaRegistry.instance.getPersona('konkur')!;
      final brief = await PersonaContextProvider.getPrimaryBrief(studyPersona);

      expect(brief, isNotNull);
      final json = brief!.toPromptJson();
      expect(json['topPrioritySubject'], equals('زیست‌شناسی'));
    });
  });
}
