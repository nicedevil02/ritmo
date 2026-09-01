import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/database/schema/tables/assistant_tables.dart';
import 'package:ritmo/core/database/schema/tables/supplementary_sports_tables.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/assistant/models/assistant_models.dart';
import 'package:ritmo/features/supplementary_sports/presentation/widgets/ss_ai_coach_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Sports Assistant Actions & Model Tests', () {
    test('AssistantActionType parses all sports action types correctly', () {
      expect(
        AssistantActionType.fromString('swapExercise'),
        equals(AssistantActionType.swapExercise),
      );
      expect(
        AssistantActionType.fromString('adjustWorkoutIntensity'),
        equals(AssistantActionType.adjustWorkoutIntensity),
      );
      expect(
        AssistantActionType.fromString('setQuietMode'),
        equals(AssistantActionType.setQuietMode),
      );
      expect(
        AssistantActionType.fromString('changeSetProgram'),
        equals(AssistantActionType.changeSetProgram),
      );
      expect(
        AssistantActionType.fromString('rescheduleDay'),
        equals(AssistantActionType.rescheduleDay),
      );
    });

    test('AssistantActionType sports labels are Persian and descriptive', () {
      expect(AssistantActionType.swapExercise.label, equals('تعویض حرکت ورزشی'));
      expect(
        AssistantActionType.adjustWorkoutIntensity.label,
        equals('تنظیم شدت تمرین'),
      );
      expect(AssistantActionType.setQuietMode.label, equals('تنظیم حالت بی‌صدا'));
      expect(
        AssistantActionType.changeSetProgram.label,
        equals('تغییر برنامه تمرین'),
      );
      expect(AssistantActionType.rescheduleDay.label, equals('تغییر روز تمرین'));
    });
  });

  group('SSAiCoachSheet Widget Tests', () {
    testWidgets('renders SSAiCoachSheet header, chips, and input field', (
      tester,
    ) async {
      Database? db;
      await tester.runAsync(() async {
        db = await databaseFactory.openDatabase(inMemoryDatabasePath);
        await AssistantTables.create(db!);
        await SupplementarySportsTables.create(db!);
        DatabaseHelper.instance.overrideDatabaseForTesting(db!);
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: RitmoTheme.build(
            palette: RitmoPalette.jadeNoir,
            brightness: Brightness.dark,
          ),
          home: const Scaffold(
            body: SizedBox(
              height: 700,
              width: 400,
              child: SSAiCoachSheet(),
            ),
          ),
        ),
      );

      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 300));
      });
      await tester.pump();

      // Verify title is rendered
      expect(find.text('مربی هوشمند ریتمو'), findsOneWidget);

      // Verify text field exists
      expect(find.byType(TextField), findsOneWidget);

      // Verify quick action chips
      expect(find.text('📉 این هفته را سبک‌تر کن'), findsOneWidget);
      expect(find.text('🔄 یک حرکت جایگزین بده'), findsOneWidget);
      expect(find.text('🍎 تغذیه بعد تمرین چی باشه؟'), findsOneWidget);
      expect(find.text('🔇 ورزش بدون پرش و بی‌صدا'), findsOneWidget);

      if (db != null) {
        await tester.runAsync(() async {
          await db!.close();
        });
      }
    });
  });
}
