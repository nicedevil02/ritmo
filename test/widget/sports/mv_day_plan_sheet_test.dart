import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/features/supplementary_sports/application/application.dart';
import 'package:ritmo/features/supplementary_sports/data/repositories/mv_kind_repository.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';
import 'package:ritmo/features/supplementary_sports/movement/data/seed/movement_kinds_seed.dart';
import 'package:ritmo/features/supplementary_sports/presentation/sheets/mv_day_plan_sheet.dart';
import 'package:ritmo/l10n/app_localizations.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Widget createTestApp(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('fa'),
    home: Scaffold(body: child),
  );
}

void main() {
  late Database db;
  late MvKindRepository kindRepo;
  late MvKindUseCase kindUseCase;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await MovementKindsSeed.seed(db);
    kindRepo = MvKindRepository(db);
    kindUseCase = MvKindUseCase(kindRepo);
  });

  tearDown(() async {
    await db.close();
  });

  group('MvDayPlanSheet Integration Tests (S1-T7)', () {
    testWidgets(
      'Opening sheet for rest slot, selecting SPORT and FOOTBALL saves slot correctly',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(800, 1200));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        const initialSlot = MvSlot(
          id: 'slot_2026-08-25',
          dateIso: '2026-08-25',
          slotType: MvSlotType.rest,
          headlineFa: 'استراحت',
          createdAt: 1000,
          updatedAt: 1000,
        );

        MvSlot? savedSlot;

        await tester.pumpWidget(
          createTestApp(
            Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  MvDayPlanSheet.show(
                    context: context,
                    slot: initialSlot,
                    kindUseCase: kindUseCase,
                    onSave: (slot) {
                      savedSlot = slot;
                    },
                  );
                },
                child: const Text('Open Day Plan'),
              ),
            ),
          ),
        );

        // 1. Open Day Plan Sheet
        await tester.tap(find.text('Open Day Plan'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('برنامهٔ روز'), findsOneWidget);
        expect(find.byKey(const ValueKey('slot_type_REST')), findsOneWidget);
        expect(find.byKey(const ValueKey('slot_type_SPORT')), findsOneWidget);

        // Kind picker tile should NOT be visible when slotType is REST
        expect(
          find.byKey(const ValueKey('day_plan_kind_picker_tile')),
          findsNothing,
        );

        // 2. Select SPORT slot type
        await tester.ensureVisible(
          find.byKey(const ValueKey('slot_type_SPORT')),
        );
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('slot_type_SPORT')));
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pump();

        // Kind picker tile MUST appear now
        expect(
          find.byKey(const ValueKey('day_plan_kind_picker_tile')),
          findsOneWidget,
        );

        // 3. Open Kind Picker from Day Plan
        await tester.ensureVisible(
          find.byKey(const ValueKey('day_plan_kind_picker_tile')),
        );
        await tester.tap(
          find.byKey(const ValueKey('day_plan_kind_picker_tile')),
        );
        await tester.pump(const Duration(milliseconds: 400));
        await tester.runAsync(
          () => Future.delayed(const Duration(milliseconds: 200)),
        );
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('انتخاب نوع ورزش و فعالیت'), findsOneWidget);

        // 4. Filter for FOOTBALL (فوتبال) and tap
        await tester.enterText(find.byType(TextField).last, 'فوتبال');
        await tester.pump(const Duration(milliseconds: 350));
        await tester.runAsync(
          () => Future.delayed(const Duration(milliseconds: 200)),
        );
        await tester.pump(const Duration(milliseconds: 100));

        await tester.ensureVisible(find.byKey(const ValueKey('kind_FOOTBALL')));
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('kind_FOOTBALL')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(milliseconds: 200));

        // Kind picker closed, back to day plan
        expect(find.text('انتخاب نوع ورزش و فعالیت'), findsNothing);
        expect(find.text('برنامهٔ روز'), findsOneWidget);

        // 5. Select 45 minutes
        await tester.ensureVisible(
          find.byKey(const ValueKey('day_plan_duration_45')),
        );
        await tester.tap(find.byKey(const ValueKey('day_plan_duration_45')));
        await tester.pump();

        // 6. Save Day Plan
        await tester.ensureVisible(
          find.byKey(const ValueKey('day_plan_save_action')),
        );
        await tester.tap(find.byKey(const ValueKey('day_plan_save_action')));
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump();

        // Verify saved slot
        expect(savedSlot, isNotNull);
        expect(savedSlot!.slotType, equals(MvSlotType.sport));
        expect(savedSlot!.kindCode, equals('FOOTBALL'));
        expect(savedSlot!.targetMinutes, equals(45));
      },
    );

    testWidgets(
      'Selecting FUTSAL shows venue field and hides muscle focus field',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(800, 1200));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        const initialSlot = MvSlot(
          id: 'slot_futsal_test',
          dateIso: '2026-08-25',
          slotType: MvSlotType.strength,
          headlineFa: 'تمرین قدرتی',
          createdAt: 1000,
          updatedAt: 1000,
        );

        await tester.pumpWidget(
          createTestApp(
            Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  MvDayPlanSheet.show(
                    context: context,
                    slot: initialSlot,
                    kindUseCase: kindUseCase,
                    onSave: (_) {},
                  );
                },
                child: const Text('Open Day Plan'),
              ),
            ),
          ),
        );

        // Open sheet
        await tester.tap(find.text('Open Day Plan'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(milliseconds: 100));

        // For STRENGTH: muscle focus is shown, venue is hidden
        expect(
          find.byKey(const ValueKey('day_plan_muscle_focus')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('day_plan_venue_field')),
          findsNothing,
        );

        // Switch to SPORT
        await tester.ensureVisible(
          find.byKey(const ValueKey('slot_type_SPORT')),
        );
        await tester.tap(find.byKey(const ValueKey('slot_type_SPORT')));
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pump();

        // Open Kind Picker
        await tester.ensureVisible(
          find.byKey(const ValueKey('day_plan_kind_picker_tile')),
        );
        await tester.tap(
          find.byKey(const ValueKey('day_plan_kind_picker_tile')),
        );
        await tester.pump(const Duration(milliseconds: 400));
        await tester.runAsync(
          () => Future.delayed(const Duration(milliseconds: 200)),
        );
        await tester.pump(const Duration(milliseconds: 100));

        // Search and pick FUTSAL
        await tester.enterText(find.byType(TextField).last, 'فوتسال');
        await tester.pump(const Duration(milliseconds: 350));
        await tester.runAsync(
          () => Future.delayed(const Duration(milliseconds: 200)),
        );
        await tester.pump(const Duration(milliseconds: 100));

        await tester.ensureVisible(find.byKey(const ValueKey('kind_FUTSAL')));
        await tester.tap(find.byKey(const ValueKey('kind_FUTSAL')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(milliseconds: 200));

        // For FUTSAL: venue field MUST be visible, muscle focus MUST be hidden
        expect(
          find.byKey(const ValueKey('day_plan_venue_field')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('day_plan_muscle_focus')),
          findsNothing,
        );
      },
    );

    testWidgets(
      'Opening sheet for rest slot renders Recovery Insight Card, Mode Selector, and saves Passive/Active Rest with weekly repeat',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(800, 1200));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        const restSlot = MvSlot(
          id: 'slot_rest_test',
          dateIso: '2026-08-26',
          slotType: MvSlotType.rest,
          headlineFa: 'روز استراحت و ریکاوری',
          createdAt: 1000,
          updatedAt: 1000,
        );

        MvSlot? savedSlot;

        await tester.pumpWidget(
          createTestApp(
            Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  MvDayPlanSheet.show(
                    context: context,
                    slot: restSlot,
                    kindUseCase: kindUseCase,
                    onSave: (slot) {
                      savedSlot = slot;
                    },
                  );
                },
                child: const Text('Open Day Plan'),
              ),
            ),
          ),
        );

        // Open sheet
        await tester.tap(find.text('Open Day Plan'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(milliseconds: 100));

        // Verify Rest Insight Card is visible
        expect(
          find.byKey(const ValueKey('mv_rest_insight_card')),
          findsOneWidget,
        );
        expect(find.text('سبک ریکاوری امروز'), findsOneWidget);
        expect(find.text('استراحت کامل'), findsOneWidget);
        expect(find.text('کشش و موبیلیتی'), findsOneWidget);

        // Verify repeat rest weekly switch is present
        expect(
          find.byKey(const ValueKey('day_plan_repeat_rest_weekly_switch')),
          findsOneWidget,
        );

        // Switch to Gentle Stretch & Mobility
        await tester.ensureVisible(find.text('کشش و موبیلیتی'));
        await tester.tap(find.text('کشش و موبیلیتی'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        // Toggle repeat weekly
        await tester.ensureVisible(
          find.byKey(const ValueKey('day_plan_repeat_rest_weekly_switch')),
        );
        await tester.tap(
          find.byKey(const ValueKey('day_plan_repeat_rest_weekly_switch')),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        // Save
        await tester.ensureVisible(
          find.byKey(const ValueKey('day_plan_save_action')),
        );
        await tester.tap(find.byKey(const ValueKey('day_plan_save_action')), warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump();

        // Verify saved rest slot
        expect(savedSlot, isNotNull);
        expect(savedSlot!.slotType, equals(MvSlotType.rest));
        expect(savedSlot!.targetMinutes, equals(5));
        expect(savedSlot!.isLocked, isTrue);
        expect(savedSlot!.headlineFa, contains('کشش'));
        expect(savedSlot!.coachNoteFa, contains('کشش'));
      },
    );
  });
}
