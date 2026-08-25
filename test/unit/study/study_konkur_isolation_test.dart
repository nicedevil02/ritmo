import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/migration/migrations/migration_v119_konkur_study_isolation.dart';
import 'package:ritmo/features/konkur/models/konkur_models.dart';
import 'package:ritmo/features/study/domain/study_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Study & Konkur Data Isolation Tests', () {
    test('StudyOrigin serialization and parsing handles user, preset and custom', () {
      expect(StudyOrigin.user.dbValue, 'USER');
      expect(StudyOrigin.konkurPreset.dbValue, 'KONKUR_PRESET');
      expect(StudyOrigin.konkurCustom.dbValue, 'KONKUR_CUSTOM');

      expect(StudyOriginExtension.fromDbValue('KONKUR_PRESET'), StudyOrigin.konkurPreset);
      expect(StudyOriginExtension.fromDbValue('PRESET'), StudyOrigin.konkurPreset);
      expect(StudyOriginExtension.fromDbValue('KONKUR'), StudyOrigin.konkurPreset);
      expect(StudyOriginExtension.fromDbValue('KONKUR_CUSTOM'), StudyOrigin.konkurCustom);
      expect(StudyOriginExtension.fromDbValue('USER'), StudyOrigin.user);
      expect(StudyOriginExtension.fromDbValue(null), StudyOrigin.user);
      expect(StudyOriginExtension.fromDbValue('UNKNOWN'), StudyOrigin.user);
    });

    test('KonkurSubject toMap and fromMap preserves origin and preset status', () {
      final presetSub = KonkurSubject(
        id: 'ks_preset',
        name: 'زیست‌شناسی کنکور',
        createdAt: 1000,
        updatedAt: 1000,
        isPreset: true,
      );
      expect(presetSub.origin, 'KONKUR_PRESET');
      expect(presetSub.toMap()['origin'], 'KONKUR_PRESET');

      final customSub = KonkurSubject(
        id: 'ks_custom',
        name: 'شیمی آزمون آزمایشی',
        createdAt: 1000,
        updatedAt: 1000,
        isPreset: false,
      );
      expect(customSub.origin, 'KONKUR_CUSTOM');
      expect(customSub.toMap()['origin'], 'KONKUR_CUSTOM');

      final restored = KonkurSubject.fromMap(customSub.toMap());
      expect(restored.id, 'ks_custom');
      expect(restored.origin, 'KONKUR_CUSTOM');
      expect(restored.isPreset, isFalse);
    });

    test('KonkurTopic toMap and fromMap preserves origin', () {
      final topic = KonkurTopic(
        id: 'kt_1',
        subjectId: 'ks_preset',
        name: 'ژنتیک',
        createdAt: 1000,
        updatedAt: 1000,
        origin: 'KONKUR_PRESET',
      );
      expect(topic.origin, 'KONKUR_PRESET');
      expect(topic.toMap()['origin'], 'KONKUR_PRESET');

      final restored = KonkurTopic.fromMap(topic.toMap());
      expect(restored.origin, 'KONKUR_PRESET');
    });

    test('Migration V119 correctly isolates preset/custom konkur subjects from normal user subjects', () async {
      final db = await openDatabase(inMemoryDatabasePath, version: 1, onCreate: (db, version) async {
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
            isPreset INTEGER NOT NULL DEFAULT 0,
            origin TEXT NOT NULL DEFAULT 'USER'
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
            chapter TEXT,
            reviewCount INTEGER NOT NULL DEFAULT 0,
            origin TEXT NOT NULL DEFAULT 'USER'
          );
        ''');

        // Insert legacy seeded subjects where origin defaulted to 'USER'
        await db.insert('konkur_subjects', {
          'id': 'sub_konkur_preset',
          'name': 'زیست کنکور',
          'createdAt': 100,
          'updatedAt': 100,
          'isPreset': 1,
          'origin': 'USER', // legacy flaw
        });

        await db.insert('konkur_subjects', {
          'id': 'sub_konkur_custom',
          'name': 'فیزیک جامع قلمچی',
          'createdAt': 100,
          'updatedAt': 100,
          'isPreset': 0,
          'subjectGroup': 'SPECIALIZED',
          'examQuestionCount': 30,
          'origin': 'USER', // legacy flaw
        });

        await db.insert('konkur_subjects', {
          'id': 'sub_study_normal',
          'name': 'کتاب برنامه‌نویسی پایتون',
          'createdAt': 100,
          'updatedAt': 100,
          'isPreset': 0,
          'subjectGroup': 'GENERAL',
          'examQuestionCount': 0,
          'origin': 'USER', // valid user study subject
        });

        await db.insert('konkur_topics', {
          'id': 'top_1',
          'subjectId': 'sub_konkur_preset',
          'name': 'تنفس سلولی',
          'createdAt': 100,
          'updatedAt': 100,
          'origin': 'USER',
        });

        await db.insert('konkur_topics', {
          'id': 'top_2',
          'subjectId': 'sub_study_normal',
          'name': 'توابع پایتون',
          'createdAt': 100,
          'updatedAt': 100,
          'origin': 'USER',
        });
      });

      // Run Migration V119
      final migration = MigrationV119KonkurStudyIsolation();
      await migration.up(db);

      // Verify Konkur preset origin updated
      final presetRow = (await db.query('konkur_subjects', where: "id = 'sub_konkur_preset'")).first;
      expect(presetRow['origin'], 'KONKUR_PRESET');

      // Verify Konkur custom origin updated
      final customRow = (await db.query('konkur_subjects', where: "id = 'sub_konkur_custom'")).first;
      expect(customRow['origin'], 'KONKUR_CUSTOM');

      // Verify normal user study subject remains 'USER'
      final normalRow = (await db.query('konkur_subjects', where: "id = 'sub_study_normal'")).first;
      expect(normalRow['origin'], 'USER');

      // Query for Study mode (isKonkurMode: false)
      final studySubjects = await db.query(
        'konkur_subjects',
        where: "isArchived = 0 AND origin = 'USER' AND (isPreset IS NULL OR isPreset = 0)",
      );
      expect(studySubjects.length, 1);
      expect(studySubjects.first['id'], 'sub_study_normal');

      // Query for Konkur mode (isKonkurMode: true)
      final konkurSubjects = await db.query(
        'konkur_subjects',
        where: "isArchived = 0 AND (origin = 'KONKUR_PRESET' OR origin = 'KONKUR_CUSTOM' OR isPreset = 1)",
      );
      expect(konkurSubjects.length, 2);
      expect(konkurSubjects.map((s) => s['id']), containsAll(['sub_konkur_preset', 'sub_konkur_custom']));

      await db.close();
    });
  });
}
