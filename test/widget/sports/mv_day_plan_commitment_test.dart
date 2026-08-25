import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/schema/tables/supplementary_sports_tables.dart';
import 'package:ritmo/features/supplementary_sports/application/application.dart';
import 'package:ritmo/features/supplementary_sports/data/repositories/repositories.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';
import 'package:ritmo/features/supplementary_sports/movement/data/seed/movement_kinds_seed.dart';
import 'package:ritmo/features/supplementary_sports/presentation/sheets/mv_day_plan_sheet.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('MvDayPlanSheet Commitment Creation Integration Tests (S2-T4)', () {
    late Database db;
    late MvCommitmentRepository commitmentRepo;
    late MvPrescriptionRepository prescriptionRepo;
    late MvProfileRepository profileRepo;
    late MvKindRepository kindRepo;
    late MvSaveCommitmentUseCase saveCommitmentUseCase;
    late MvKindUseCase kindUseCase;

    setUp(() async {
      db = await databaseFactory.openDatabase(inMemoryDatabasePath);
      await SupplementarySportsTables.create(db);
      await MovementKindsSeed.seed(db);
      commitmentRepo = MvCommitmentRepositoryImpl(db);
      prescriptionRepo = MvPrescriptionRepository(db);
      profileRepo = MvProfileRepository(db);
      kindRepo = MvKindRepository(db);
      kindUseCase = MvKindUseCase(kindRepo);
      saveCommitmentUseCase = MvSaveCommitmentUseCase(
        commitmentRepo: commitmentRepo,
        prescriptionRepo: prescriptionRepo,
        profileRepo: profileRepo,
      );
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets(
      'Opening sheet with plannedTime 21:00 and repeatWeekly switch saves MvCommitment and regenerates week',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        // پنجشنبه ۲۷ آگوست ۲۰۲۶
        final initialSlot = MvSlot(
          id: 'slot_2026-08-27',
          dateIso: '2026-08-27',
          cycleWeek: 1,
          slotType: MvSlotType.sport,
          kindCode: 'FUTSAL',
          plannedTime: '21:00',
          targetMinutes: 90,
          intensityTier: MvIntensityTier.hard,
          headlineFa: 'فوتسال پنجشنبه‌ها',
          createdAt: DateTime.now().millisecondsSinceEpoch,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        );

        MvSlot? savedResult;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    key: const ValueKey('open_plan_sheet_btn'),
                    onPressed: () {
                      MvDayPlanSheet.show(
                        context: context,
                        slot: initialSlot,
                        kindUseCase: kindUseCase,
                        saveCommitmentUseCase: saveCommitmentUseCase,
                        onSave: (s) {
                          savedResult = s;
                        },
                      );
                    },
                    child: const Text('Open Sheet'),
                  );
                },
              ),
            ),
          ),
        );

        // 1. Open sheet
        await tester.tap(find.byKey(const ValueKey('open_plan_sheet_btn')));
        await tester.pumpAndSettle();

        // 2. Verify Repeat Weekly Switch is present and turn it on
        final repeatSwitchFinder =
            find.byKey(const ValueKey('day_plan_repeat_weekly_switch'));
        expect(repeatSwitchFinder, findsOneWidget);
        await tester.ensureVisible(repeatSwitchFinder);
        await tester.pumpAndSettle();
        await tester.tap(repeatSwitchFinder);
        await tester.pumpAndSettle();

        // 3. Tap Save Button
        final saveBtn = find.byKey(const ValueKey('day_plan_save_action'));
        expect(saveBtn, findsOneWidget);
        await tester.ensureVisible(saveBtn);
        await tester.pumpAndSettle();

        await tester.runAsync(() async {
          await tester.tap(saveBtn);
          await Future.delayed(const Duration(milliseconds: 250));
        });
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // 4. Verify commitment saved in DB
        late List<MvCommitment> commitments;
        await tester.runAsync(() async {
          commitments = await commitmentRepo.getAll();
        });
        expect(commitments.length, equals(1));
        final c = commitments.first;
        expect(c.kindCode, equals('FUTSAL'));
        expect(c.dayOfWeekSat0, equals(5)); // پنجشنبه
        expect(c.startTime, equals('21:00'));
        expect(c.durationMinutes, equals(90));
        expect(c.isActive, isTrue);

        // 5. Verify saved slot has isLocked == true
        expect(savedResult, isNotNull);
        expect(savedResult!.isLocked, isTrue);
        expect(savedResult!.plannedTime, equals('21:00'));
      },
    );

    testWidgets(
      'When repeatWeekly switch is OFF, saves single-day locked slot without creating MvCommitment',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final initialSlot = MvSlot(
          id: 'slot_2026-08-28',
          dateIso: '2026-08-28',
          cycleWeek: 1,
          slotType: MvSlotType.cardio,
          kindCode: 'RUNNING',
          plannedTime: '07:00',
          targetMinutes: 45,
          intensityTier: MvIntensityTier.moderate,
          headlineFa: 'دویدن صبح جمعه',
          createdAt: DateTime.now().millisecondsSinceEpoch,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        );

        MvSlot? savedResult;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    key: const ValueKey('open_plan_sheet_btn_2'),
                    onPressed: () {
                      MvDayPlanSheet.show(
                        context: context,
                        slot: initialSlot,
                        kindUseCase: kindUseCase,
                        saveCommitmentUseCase: saveCommitmentUseCase,
                        onSave: (s) {
                          savedResult = s;
                        },
                      );
                    },
                    child: const Text('Open Sheet'),
                  );
                },
              ),
            ),
          ),
        );

        await tester.tap(find.byKey(const ValueKey('open_plan_sheet_btn_2')));
        await tester.pumpAndSettle();

        // Do NOT turn on repeat weekly switch
        final saveBtn = find.byKey(const ValueKey('day_plan_save_action'));
        expect(saveBtn, findsOneWidget);
        await tester.ensureVisible(saveBtn);
        await tester.pumpAndSettle();
        await tester.tap(saveBtn);
        await tester.pumpAndSettle();

        // Verify NO commitment in DB
        late List<MvCommitment> commitments;
        await tester.runAsync(() async {
          commitments = await commitmentRepo.getAll();
        });
        expect(commitments, isEmpty);

        // Verify single day slot is locked
        expect(savedResult, isNotNull);
        expect(savedResult!.isLocked, isTrue);
        expect(savedResult!.plannedTime, equals('07:00'));
      },
    );
  });
}
