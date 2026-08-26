import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/features/supplementary_sports/application/application.dart';
import 'package:ritmo/features/supplementary_sports/data/repositories/repositories.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';
import 'package:ritmo/features/supplementary_sports/presentation/screens/screens.dart';
import 'package:ritmo/l10n/app_localizations.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class FakeProfileRepo implements MvProfileRepository {
  MvUserProfile profile;
  FakeProfileRepo([MvUserProfile? initial])
      : profile = initial ??
            const MvUserProfile(
              id: 'test_user',
              goal: 'generalFitness',
              onboardingCompleted: true,
              daysPerWeek: 3,
              createdAt: 100,
              updatedAt: 100,
            );

  @override
  Future<MvUserProfile> getProfile() async => profile;
  @override
  Future<void> saveProfile(MvUserProfile p) async => profile = p;
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class FakePrescriptionRepo implements MvPrescriptionRepository {
  List<MvSlot> slots;
  FakePrescriptionRepo([List<MvSlot>? initial])
      : slots = initial ??
            List.generate(7, (i) {
              final dayStr = (22 + i).toString().padLeft(2, '0');
              return MvSlot(
                id: 'slot_$i',
                dateIso: '2026-08-$dayStr',
                slotType: i % 2 == 0 ? MvSlotType.strength : MvSlotType.rest,
                headlineFa: i % 2 == 0 ? 'تمرین روز $i' : 'استراحت',
                targetMinutes: i % 2 == 0 ? 30 : 0,
                createdAt: 100,
                updatedAt: 100,
              );
            });

  @override
  Future<List<MvSlot>> getWeekSlots(String weekStartIso) async => slots;
  @override
  Future<void> savePrescription(MvSlot slot) async {}
  @override
  Future<void> savePrescriptions(List<MvSlot> newSlots) async => slots = newSlots;
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class FakeCommitmentRepo implements MvCommitmentRepository {
  List<MvCommitment> commitments = [];
  @override
  Future<List<MvCommitment>> getAll({bool onlyActive = true}) async =>
      onlyActive ? commitments.where((c) => c.isActive).toList() : commitments;
  @override
  Future<List<MvCommitment>> getActive() async =>
      commitments.where((c) => c.isActive).toList();
  @override
  Future<MvCommitment> upsert(MvCommitment c) async {
    commitments.add(c);
    return c;
  }
  @override
  Future<void> delete(int id) async =>
      commitments.removeWhere((c) => c.id == id);
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class FakeExerciseRepo implements MvExerciseRepository {
  @override
  Future<List<MvExercise>> getAllExercises() async => [];
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class FakeSessionRepo implements MvSessionRepository {
  @override
  Future<MvSession?> getActiveSession() async => null;
  @override
  Future<List<MvSession>> getCompletedSessionsBetween(DateTime s, DateTime e) async => [];
  @override
  Future<List<MvSession>> getSessionHistory({int limit = 20, int offset = 0, String? kindCode}) async => [];
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class FakePrRepo implements MvPrRepository {
  @override
  Future<List<MvPersonalRecord>> getAllPrs() async => [];
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class FakeKindRepo implements MvKindRepository {
  @override
  Future<List<MvMovementKind>> getAll({bool onlyEnabled = true}) async => const [];
  @override
  Future<MvMovementKind?> getByCode(String code) async => null;
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class FakeDailyCheckinRepo implements MvDailyCheckinRepository {
  @override
  Future<MvDailyCheckin?> getCheckinForDate(String dateIso) async => null;
  @override
  Future<void> saveCheckin(MvDailyCheckin checkin) async {}
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class FakeCampaignRepo implements MvCampaignRepository {
  @override
  Future<MvCampaign?> getActive() async => null;
  @override
  Future<List<MvCampaign>> getAllCampaigns() async => [];
  @override
  Future<MvCampaign> upsert(MvCampaign c) async => c;
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class FakeKindProfileRepo implements MvKindProfileRepository {
  @override
  Future<MvKindProfile?> getByCode(String kindCode) async => null;
  @override
  Future<Map<String, MvKindProfile>> getMapByCodes(List<String> codes) async => {};
  @override
  Future<List<MvKindProfile>> getAll() async => [];
  @override
  Future<void> upsert(MvKindProfile profile) async {}
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

Widget createTestApp(MvHubController controller) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('fa'),
    home: MvHubScreen(controller: controller),
  );
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('S8-T4 Anchor Reachability Tests (3 Mandatory Entrypoints)', () {
    late MvHubController controller;

    setUp(() {
      controller = MvHubController(
        profileRepo: FakeProfileRepo(),
        prescriptionRepo: FakePrescriptionRepo(),
        commitmentRepo: FakeCommitmentRepo(),
        kindRepo: FakeKindRepo(),
        kindProfileRepo: FakeKindProfileRepo(),
        campaignRepo: FakeCampaignRepo(),
        checkinRepo: FakeDailyCheckinRepo(),
        exerciseRepo: FakeExerciseRepo(),
        sessionRepo: FakeSessionRepo(),
        prRepo: FakePrRepo(),
      );
    });

    testWidgets('Entrypoint 1: MvHubScreen AppBar lock action opens MvCommitmentsScreen', (tester) async {
      await controller.loadAllData();
      await tester.pumpWidget(createTestApp(controller));
      await tester.pump();
      await tester.pumpAndSettle();

      final lockAction = find.byKey(const ValueKey('mv_open_commitments'));
      expect(lockAction, findsOneWidget);

      await tester.tap(lockAction);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();

      expect(find.byType(MvCommitmentsScreen), findsOneWidget);
    });

    testWidgets('Entrypoint 2: Week tab invite CTA card opens MvCommitmentsScreen', (tester) async {
      await controller.loadAllData();
      await tester.pumpWidget(createTestApp(controller));
      await tester.pump();
      await tester.pumpAndSettle();

      // Switch to Week Tab (Tab 1)
      await tester.tap(find.byIcon(Icons.calendar_view_week_outlined));
      await tester.pump();
      await tester.pumpAndSettle();

      final weekCta = find.byKey(const ValueKey('mv_week_anchor_cta'));
      expect(weekCta, findsOneWidget);

      await tester.tap(weekCta);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();

      expect(find.byType(MvCommitmentsScreen), findsOneWidget);
    });

    testWidgets('Entrypoint 3: Settings Screen Fixed Sports tile opens MvCommitmentsScreen', (tester) async {
      await controller.loadAllData();
      await tester.pumpWidget(createTestApp(controller));
      await tester.pump();
      await tester.pumpAndSettle();

      // Open Settings
      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.byType(MvSettingsScreen), findsOneWidget);

      // Tap Commitments Tile in Settings
      final settingsTile = find.byKey(const ValueKey('mv_settings_commitments_tile'));
      expect(settingsTile, findsOneWidget);

      await tester.tap(settingsTile);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();

      expect(find.byType(MvCommitmentsScreen), findsOneWidget);
    });
  });
}
