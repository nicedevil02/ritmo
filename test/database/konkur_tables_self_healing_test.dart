import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/schema/tables/konkur_tables.dart';
import 'package:ritmo/features/study/domain/study_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('KonkurTables Schema & Self-Healing Tests', () {
    test('KonkurTables.create creates complete schema with origin and study_deadlines', () async {
      final db = await databaseFactory.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, version) async {
            await KonkurTables.create(db);
          },
        ),
      );

      // Verify konkur_subjects columns
      final subCols = await db.rawQuery('PRAGMA table_info(konkur_subjects)');
      final subColNames = subCols.map((c) => c['name'] as String).toSet();
      expect(subColNames.contains('origin'), isTrue);
      expect(subColNames.contains('emoji'), isTrue);
      expect(subColNames.contains('weeklyTargetMinutes'), isTrue);

      // Verify konkur_topics columns
      final topicCols = await db.rawQuery('PRAGMA table_info(konkur_topics)');
      final topicColNames = topicCols.map((c) => c['name'] as String).toSet();
      expect(topicColNames.contains('origin'), isTrue);
      expect(topicColNames.contains('reviewCount'), isTrue);

      // Verify study_deadlines table exists
      final deadlineCols = await db.rawQuery('PRAGMA table_info(study_deadlines)');
      expect(deadlineCols, isNotEmpty);

      // Insert and query via StudySubject / StudyTopic models
      const subject = StudySubject(
        id: 'test_sub_1',
        name: 'ریاضی عمومی',
        origin: StudyOrigin.user,
        emoji: '📐',
        weeklyTargetMinutes: 120,
      );
      await db.insert('konkur_subjects', subject.toMap());

      final loadedRows = await db.query(
        'konkur_subjects',
        where: "isArchived = 0 AND origin = 'USER' AND (isPreset IS NULL OR isPreset = 0)",
      );
      expect(loadedRows.length, equals(1));
      expect(loadedRows.first['origin'], equals('USER'));
      expect(loadedRows.first['emoji'], equals('📐'));

      await db.close();
    });

    test('KonkurTables.ensureSchema upgrades legacy DB missing origin column', () async {
      // Simulate legacy DB without origin column
      final db = await databaseFactory.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, version) async {
            await db.execute('''
              CREATE TABLE konkur_subjects (
                  id TEXT PRIMARY KEY,
                  name TEXT NOT NULL,
                  importanceFactor REAL NOT NULL DEFAULT 1.0,
                  progressPercentage REAL NOT NULL DEFAULT 0.0,
                  isArchived INTEGER NOT NULL DEFAULT 0,
                  createdAt INTEGER NOT NULL,
                  updatedAt INTEGER NOT NULL,
                  subjectGroup TEXT NOT NULL DEFAULT 'SPECIALIZED',
                  examQuestionCount INTEGER NOT NULL DEFAULT 0,
                  orderIndex INTEGER NOT NULL DEFAULT 0,
                  colorHex TEXT,
                  isPreset INTEGER NOT NULL DEFAULT 0
              );
            ''');
            await db.execute('''
              CREATE TABLE konkur_topics (
                  id TEXT PRIMARY KEY,
                  subjectId TEXT NOT NULL,
                  parentTopicId TEXT,
                  name TEXT NOT NULL,
                  progressPercentage REAL NOT NULL DEFAULT 0.0,
                  studyTargetMinutes INTEGER NOT NULL DEFAULT 0,
                  studyCompletedMinutes INTEGER NOT NULL DEFAULT 0,
                  createdAt INTEGER NOT NULL,
                  updatedAt INTEGER NOT NULL,
                  examQuestionCount INTEGER NOT NULL DEFAULT 0,
                  masteryLevel TEXT NOT NULL DEFAULT 'NOT_STARTED',
                  lastStudiedAt INTEGER,
                  nextReviewDate TEXT,
                  plannedDate TEXT,
                  orderIndex INTEGER NOT NULL DEFAULT 0,
                  prerequisiteTopicIds TEXT,
                  conceptCompletedMinutes INTEGER NOT NULL DEFAULT 0,
                  practiceCompletedMinutes INTEGER NOT NULL DEFAULT 0,
                  reviewCompletedMinutes INTEGER NOT NULL DEFAULT 0,
                  conceptTargetMinutes INTEGER NOT NULL DEFAULT 0,
                  practiceTargetMinutes INTEGER NOT NULL DEFAULT 0,
                  reviewTargetMinutes INTEGER NOT NULL DEFAULT 0,
                  chapter TEXT
              );
            ''');
            // Insert legacy preset subject
            await db.insert('konkur_subjects', {
              'id': 'preset_1',
              'name': 'ادبیات کنکور',
              'createdAt': 1000,
              'updatedAt': 1000,
              'isPreset': 1,
            });
          },
        ),
      );

      // Run self-healing schema migration
      await KonkurTables.ensureSchema(db);

      // Query which previously threw DatabaseException(no such column: origin)
      final userSubjects = await db.query(
        'konkur_subjects',
        where: "isArchived = 0 AND origin = 'USER' AND (isPreset IS NULL OR isPreset = 0)",
      );
      expect(userSubjects, isEmpty);

      final konkurSubjects = await db.query(
        'konkur_subjects',
        where: "isArchived = 0 AND (origin = 'KONKUR_PRESET' OR origin = 'KONKUR_CUSTOM' OR origin = 'KONKUR' OR isPreset = 1)",
      );
      expect(konkurSubjects.length, equals(1));
      expect(konkurSubjects.first['origin'], equals('KONKUR_PRESET'));

      await db.close();
    });
  });
}
