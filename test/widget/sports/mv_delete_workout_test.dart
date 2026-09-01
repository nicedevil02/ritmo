import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/schema/tables/supplementary_sports_tables.dart';
import 'package:ritmo/features/supplementary_sports/application/mv_hub_controller.dart';
import 'package:ritmo/features/supplementary_sports/data/repositories/repositories.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';
import 'package:ritmo/features/supplementary_sports/presentation/components/mv_day_slot_card.dart';
import 'package:ritmo/features/supplementary_sports/presentation/screens/mv_day_detail_screen.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Mv Delete Workout & Exercise Tests', () {
    test('deleteWorkoutPlan resets slot to rest and returns previous slot for undo', () async {
      final db = await databaseFactory.openDatabase(inMemoryDatabasePath);
      await SupplementarySportsTables.create(db);

      final controller = MvHubController(
        prescriptionRepo: MvPrescriptionRepository(db),
        commitmentRepo: MvCommitmentRepositoryImpl(db),
      );

      const slot = MvSlot(
        id: 'test_slot_1',
        dateIso: '2026-09-02',
        slotType: MvSlotType.strength,
        headlineFa: 'تمرین سینه و بازو',
        targetMinutes: 45,
        createdAt: 1000,
        updatedAt: 1000,
      );

      final result = await controller.deleteWorkoutPlan(slot: slot);

      expect(result.previousSlot.id, equals('test_slot_1'));
      expect(result.previousSlot.headlineFa, equals('تمرین سینه و بازو'));

      // Check slot is in weekSlots as rest
      final updatedSlot = controller.weekSlots.firstWhere((s) => s.dateIso == '2026-09-02');
      expect(updatedSlot.isRest, isTrue);
      expect(updatedSlot.targetMinutes, equals(0));

      // Restore
      await controller.restoreWorkoutPlan(
        previousSlot: result.previousSlot,
        previousCommitment: result.previousCommitment,
      );

      final restoredSlot = controller.weekSlots.firstWhere((s) => s.dateIso == '2026-09-02');
      expect(restoredSlot.isRest, isFalse);
      expect(restoredSlot.headlineFa, equals('تمرین سینه و بازو'));
      expect(restoredSlot.targetMinutes, equals(45));

      await db.close();
    });

    testWidgets('MvDaySlotCard renders 3-dots menu with delete action when not rest', (tester) async {
      bool deleteCalled = false;

      const slot = MvSlot(
        id: 'test_card_slot',
        dateIso: '2026-09-02',
        slotType: MvSlotType.cardio,
        kindCode: 'RUNNING',
        headlineFa: 'دویدن صبحگاهی',
        targetMinutes: 30,
        createdAt: 1000,
        updatedAt: 1000,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MvDaySlotCard(
              slot: slot,
              onDelete: () {
                deleteCalled = true;
              },
            ),
          ),
        ),
      );

      // Verify the 3-dots popup button exists
      final menuBtn = find.byKey(const ValueKey('day_slot_menu_2026-09-02'));
      expect(menuBtn, findsOneWidget);

      await tester.tap(menuBtn);
      await tester.pumpAndSettle();

      // Verify menu item exists
      final deleteItem = find.text('حذف برنامهٔ این روز');
      expect(deleteItem, findsOneWidget);

      await tester.tap(deleteItem);
      await tester.pumpAndSettle();

      expect(deleteCalled, isTrue);
    });

    testWidgets('MvDayDetailScreen allows removing an exercise and undoing it', (tester) async {
      const slot = MvSlot(
        id: 'test_detail_slot',
        dateIso: '2026-09-02',
        slotType: MvSlotType.strength,
        headlineFa: 'تمرین قدرتی',
        targetMinutes: 30,
        createdAt: 1000,
        updatedAt: 1000,
      );

      final exercises = <MvExercise>[
        const MvExercise(
          id: 'ex_1',
          name: 'شنا سوئدی',
          category: 'سینه',
          defaultReps: 12,
        ),
        const MvExercise(
          id: 'ex_2',
          name: 'پلانک',
          category: 'شکم',
          defaultReps: 30,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: MvDayDetailScreen(
            slot: slot,
            plannedExercises: exercises,
            onStartSession: () {},
            onSlotUpdated: (_) {},
          ),
        ),
      );

      expect(find.text('شنا سوئدی'), findsOneWidget);
      expect(find.text('پلانک'), findsOneWidget);

      // Tap remove on the first exercise
      final removeButtons = find.byIcon(Icons.close_rounded);
      expect(removeButtons, findsNWidgets(2));

      await tester.tap(removeButtons.first);
      await tester.pumpAndSettle();

      // Verify 'شنا سوئدی' was removed
      expect(find.text('شنا سوئدی'), findsNothing);
      expect(find.text('پلانک'), findsOneWidget);

      // Verify undo button is displayed
      final undoBtn = find.text('بازگردانی');
      expect(undoBtn, findsOneWidget);

      // Tap undo
      await tester.tap(undoBtn);
      await tester.pumpAndSettle();

      // Verify 'شنا سوئدی' is restored
      expect(find.text('شنا سوئدی'), findsOneWidget);
    });
  });
}
