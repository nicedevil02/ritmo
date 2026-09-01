import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/database/schema/tables/supplementary_sports_tables.dart';
import 'package:ritmo/core/domain/engines/ritmo_break_mobility_engine.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/study/presentation/widgets/study_break_mobility_card.dart';
import 'package:ritmo/features/study/presentation/widgets/study_break_mobility_player_sheet.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RitmoBreakMobilityEngine Unit Tests', () {
    test('getDeskBreakExercises returns curated list of desk stretches', () async {
      const engine = RitmoBreakMobilityEngine();
      final list = await engine.getDeskBreakExercises(count: 3);

      expect(list.length, equals(3));
      for (final ex in list) {
        expect(ex.id, isNotEmpty);
        expect(ex.nameFa, isNotEmpty);
        expect(ex.descriptionFa, isNotEmpty);
        expect(ex.durationSeconds, greaterThan(0));
        expect(ex.targetArea, isNotEmpty);
      }
    });

    test('BreakMobilityExercise.fromMap handles missing or default fields safely', () {
      final ex = BreakMobilityExercise.fromMap({});
      expect(ex.id, equals('stretch_custom'));
      expect(ex.nameFa, equals('کشش ملایم'));
      expect(ex.durationSeconds, equals(30));
    });

    test('getDeskBreakExercises loads from SQLite ss_exercise when table exists', () async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      final db = await databaseFactory.openDatabase(inMemoryDatabasePath);
      await SupplementarySportsTables.create(db);
      DatabaseHelper.instance.overrideDatabaseForTesting(db);

      await db.insert('ss_exercise', {
        'id': 'test_db_stretch',
        'name': 'کشش شانه دیتابیس',
        'category': 'stretching',
        'instructions': 'دستورالعمل کشش تست دیتابیس',
        'cat_stretching': 1,
        'noisy': 0,
        'durationSeconds': 40,
        'toolsRequired': '[]',
      });

      const engine = RitmoBreakMobilityEngine();
      final list = await engine.getDeskBreakExercises(count: 1);
      expect(list, isNotEmpty);
      expect(list.first.nameFa, equals('کشش شانه دیتابیس'));
      await db.close();
    });
  });

  group('StudyBreakMobilityCard Widget Tests', () {
    testWidgets('renders StudyBreakMobilityCard with header and action button', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: RitmoTheme.build(
            palette: RitmoPalette.jadeNoir,
            brightness: Brightness.dark,
          ),
          home: const Scaffold(
            body: SingleChildScrollView(
              child: StudyBreakMobilityCard(),
            ),
          ),
        ),
      );

      // Allow async exercise load to complete
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();

      // Verify header and badge
      expect(find.text('کشش و رفع خستگی مطالعه'), findsOneWidget);
      expect(find.text('استراحت پومودورو ☕'), findsOneWidget);
      expect(find.text('شروع کشش ۲ دقیقه‌ای 🌿'), findsOneWidget);
    });
  });

  group('StudyBreakMobilityPlayerSheet Widget Tests', () {
    testWidgets('cycles through exercises and displays finished state', (
      tester,
    ) async {
      const testExercises = [
        BreakMobilityExercise(
          id: 'test_1',
          nameFa: 'کشش گردن تست',
          descriptionFa: 'گردن را به آرامی به چپ و راست حرکت دهید.',
          durationSeconds: 15,
          targetArea: 'گردن',
          emoji: '💆',
        ),
        BreakMobilityExercise(
          id: 'test_2',
          nameFa: 'چرخش شانه تست',
          descriptionFa: 'شانه‌ها را به جلو و عقب بچرخانید.',
          durationSeconds: 15,
          targetArea: 'شانه',
          emoji: '🔄',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          theme: RitmoTheme.build(
            palette: RitmoPalette.jadeNoir,
            brightness: Brightness.dark,
          ),
          home: const Scaffold(
            body: SizedBox(
              height: 600,
              child: StudyBreakMobilityPlayerSheet(exercises: testExercises),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      // Verify first exercise is active
      expect(find.text('کشش گردن تست'), findsOneWidget);
      expect(find.text('گردن'), findsOneWidget);
      expect(find.text('۱ از ۲'), findsOneWidget);

      // Tap next exercise button
      final nextButton = find.byTooltip('حرکت بعدی');
      expect(nextButton, findsOneWidget);
      await tester.tap(nextButton);
      await tester.pump(const Duration(milliseconds: 100));

      // Verify second exercise is active
      expect(find.text('چرخش شانه تست'), findsOneWidget);
      expect(find.text('شانه'), findsOneWidget);
      expect(find.text('۲ از ۲'), findsOneWidget);

      // Tap next again to finish
      await tester.tap(nextButton);
      await tester.pump(const Duration(milliseconds: 100));

      // Verify finished view
      expect(find.text('پایان کشش استراحت ✨'), findsOneWidget);
      expect(find.text('خداقوت! بدن و ذهن آماده شد ✨'), findsOneWidget);
      expect(find.text('بازگشت به تایمر مطالعه'), findsOneWidget);
    });
  });
}
