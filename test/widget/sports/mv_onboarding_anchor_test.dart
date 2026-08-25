import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/schema/tables/supplementary_sports_tables.dart';
import 'package:ritmo/features/supplementary_sports/application/application.dart';
import 'package:ritmo/features/supplementary_sports/data/repositories/repositories.dart';
import 'package:ritmo/features/supplementary_sports/domain/engines/engines.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';
import 'package:ritmo/features/supplementary_sports/movement/data/seed/movement_kinds_seed.dart';
import 'package:ritmo/features/supplementary_sports/presentation/screens/mv_onboarding_screen.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('MvOnboardingScreen Anchor Question Verification (S2-T5)', () {
    late Database db;
    late MvCommitmentRepository commitmentRepo;
    late MvKindRepository kindRepo;
    late MvKindUseCase kindUseCase;
    late List<MvMovementKind> allKinds;
    const planEngine = PlanEngine();

    setUp(() async {
      db = await databaseFactory.openDatabase(inMemoryDatabasePath);
      await SupplementarySportsTables.create(db);
      await MovementKindsSeed.seed(db);
      commitmentRepo = MvCommitmentRepositoryImpl(db);
      kindRepo = MvKindRepository(db);
      kindUseCase = MvKindUseCase(kindRepo);
      allKinds = await kindRepo.getAll();
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets(
      'Full onboarding flow WITH fixed anchor commitment produces valid plan and saves commitment',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        MvUserProfile? completedProfile;
        List<MvCommitment>? completedCommitments;

        await tester.pumpWidget(
          MaterialApp(
            home: MvOnboardingScreen(
              kindUseCase: kindUseCase,
              commitmentUseCase: MvCommitmentUseCase(commitmentRepo),
              initialKinds: allKinds,
              onComplete: (profile) async {
                completedProfile = profile;
              },
              onCompleteWithCommitments: (profile, commitments) async {
                completedProfile = profile;
                completedCommitments = commitments;
              },
            ),
          ),
        );

        await tester.pumpAndSettle();

        // 1. Verify title of anchor question exists
        expect(
          find.byKey(const ValueKey('mv_onboarding_anchor_title')),
          findsOneWidget,
        );

        // 2. Tap «بله، اضافه کنم»
        final addAnchorBtn =
            find.byKey(const ValueKey('onboarding_add_anchor_btn'));
        expect(addAnchorBtn, findsOneWidget);
        await tester.ensureVisible(addAnchorBtn);
        await tester.pumpAndSettle();

        await tester.tap(addAnchorBtn);
        await tester.pumpAndSettle();

        // 3. Search and select فوتسال in Kind Picker sheet
        await tester.enterText(find.byType(TextField), 'فوتسال');
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pumpAndSettle();

        final futsalKey = find.byKey(const ValueKey('kind_FUTSAL'));
        expect(futsalKey, findsOneWidget);
        await tester.ensureVisible(futsalKey);
        await tester.pumpAndSettle();
        await tester.tap(futsalKey);
        await tester.pumpAndSettle();

        // 4. Config sheet opens -> tap confirm
        final confirmBtn =
            find.byKey(const ValueKey('confirm_anchor_commitment_btn'));
        expect(confirmBtn, findsOneWidget);
        await tester.ensureVisible(confirmBtn);
        await tester.pumpAndSettle();
        await tester.tap(confirmBtn);
        await tester.pumpAndSettle();

        // 5. Verify added commitment card is displayed
        expect(find.textContaining('پنج‌شنبه: فوتسال'), findsOneWidget);

        // 6. Tap Submit Action
        final submitBtn =
            find.byKey(const ValueKey('onboarding_submit_action'));
        expect(submitBtn, findsOneWidget);
        await tester.ensureVisible(submitBtn);
        await tester.pumpAndSettle();

        await tester.runAsync(() async {
          await tester.tap(submitBtn);
          await Future.delayed(const Duration(milliseconds: 200));
        });
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // 7. Verify profile generated
        expect(completedProfile, isNotNull);
        expect(completedProfile!.daysPerWeek, equals(3));
        expect(completedCommitments, isNotNull);
        expect(completedCommitments!.length, equals(1));
        expect(completedCommitments!.first.kindCode, equals('FUTSAL'));

        // 8. Verify saved in database
        late List<MvCommitment> dbCommitments;
        await tester.runAsync(() async {
          dbCommitments = await commitmentRepo.getAll();
        });
        expect(dbCommitments.length, equals(1));
        expect(dbCommitments.first.kindCode, equals('FUTSAL'));

        // 9. Generate week plan and verify it is valid
        final weekPlan = planEngine.generateWeekPlan(
          profile: completedProfile!,
          weekSaturday: DateTime(2026, 8, 22),
        );
        expect(weekPlan.value.length, equals(7));
      },
    );

    testWidgets(
      'Full onboarding flow WITHOUT anchor (skipping) produces valid plan and zero commitments',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        MvUserProfile? completedProfile;

        await tester.pumpWidget(
          MaterialApp(
            home: MvOnboardingScreen(
              kindUseCase: kindUseCase,
              commitmentUseCase: MvCommitmentUseCase(commitmentRepo),
              initialKinds: allKinds,
              onComplete: (profile) async {
                completedProfile = profile;
              },
            ),
          ),
        );

        await tester.pumpAndSettle();

        // 1. Tap «فعلاً نه»
        final skipBtn =
            find.byKey(const ValueKey('onboarding_skip_anchor_btn'));
        expect(skipBtn, findsOneWidget);
        await tester.ensureVisible(skipBtn);
        await tester.pumpAndSettle();
        await tester.tap(skipBtn);
        await tester.pumpAndSettle();

        // 2. Submit onboarding
        final submitBtn =
            find.byKey(const ValueKey('onboarding_submit_action'));
        expect(submitBtn, findsOneWidget);
        await tester.ensureVisible(submitBtn);
        await tester.pumpAndSettle();

        await tester.runAsync(() async {
          await tester.tap(submitBtn);
          await Future.delayed(const Duration(milliseconds: 200));
        });
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // 3. Verify profile generated
        expect(completedProfile, isNotNull);
        expect(completedProfile!.daysPerWeek, equals(3));

        // 4. Verify no commitments in DB
        late List<MvCommitment> dbCommitments;
        await tester.runAsync(() async {
          dbCommitments = await commitmentRepo.getAll();
        });
        expect(dbCommitments, isEmpty);

        // 5. Verify week plan
        final weekPlan = planEngine.generateWeekPlan(
          profile: completedProfile!,
          weekSaturday: DateTime(2026, 8, 22),
        );
        expect(weekPlan.value.length, equals(7));
      },
    );
  });
}
