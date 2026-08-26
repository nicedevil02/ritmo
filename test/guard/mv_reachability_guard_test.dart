import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/features/supplementary_sports/application/application.dart';
import 'package:ritmo/features/supplementary_sports/data/repositories/repositories.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';
import 'package:ritmo/features/supplementary_sports/presentation/components/components.dart';
import 'package:ritmo/features/supplementary_sports/presentation/player/player.dart';
import 'package:ritmo/features/supplementary_sports/presentation/screens/screens.dart';
import 'package:ritmo/features/supplementary_sports/presentation/sheets/sheets.dart';
import 'package:ritmo/l10n/app_localizations.dart';

class GuardFakeProfileRepo implements MvProfileRepository {
  MvUserProfile profile = const MvUserProfile(
    id: 'default',
    onboardingCompleted: true,
    goal: 'generalFitness',
    experienceLevel: 'intermediate',
    trainingLocation: 'home',
    daysPerWeek: 3,
    programStartDate: '2026-08-01',
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

class GuardFakePrescriptionRepo implements MvPrescriptionRepository {
  List<MvSlot> slots = [];

  @override
  Future<List<MvSlot>> getWeekSlots(String weekStartIso) async => slots;
  @override
  Future<MvSlot?> getPrescriptionForDate(String dateIso) async =>
      slots.where((s) => s.dateIso == dateIso).firstOrNull;
  @override
  Future<void> savePrescription(MvSlot slot) async {
    final idx = slots.indexWhere((s) => s.id == slot.id || s.dateIso == slot.dateIso);
    if (idx >= 0) {
      slots[idx] = slot;
    } else {
      slots.add(slot);
    }
  }
  @override
  Future<void> savePrescriptions(List<MvSlot> newSlots) async => slots = List.from(newSlots);
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class GuardFakeCommitmentRepo implements MvCommitmentRepository {
  List<MvCommitment> commitments = [];

  @override
  Future<List<MvCommitment>> getAll({bool onlyActive = true}) async =>
      onlyActive ? commitments.where((c) => c.isActive).toList() : commitments;
  @override
  Future<List<MvCommitment>> getActive() async =>
      commitments.where((c) => c.isActive).toList();
  @override
  Future<MvCommitment> upsert(MvCommitment c) async {
    final toSave = c.id == null
        ? MvCommitment(
            id: commitments.length + 1,
            kindCode: c.kindCode,
            titleFa: c.titleFa,
            dayOfWeekSat0: c.dayOfWeekSat0,
            startTime: c.startTime,
            durationMinutes: c.durationMinutes,
            venueNote: c.venueNote,
            partnerNote: c.partnerNote,
            recurrence: c.recurrence,
            isActive: c.isActive,
            isFlexible: c.isFlexible,
            startDateIso: c.startDateIso,
            endDateIso: c.endDateIso,
            reminderMinutes: c.reminderMinutes,
            createdAt: c.createdAt,
            updatedAt: c.updatedAt,
          )
        : c;
    final idx = commitments.indexWhere((item) => item.id == toSave.id);
    if (idx >= 0) {
      commitments[idx] = toSave;
    } else {
      commitments.add(toSave);
    }
    return toSave;
  }
  @override
  Future<void> delete(int id) async =>
      commitments.removeWhere((c) => c.id == id);
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class GuardFakeKindRepo implements MvKindRepository {
  final List<MvMovementKind> kinds = const [
    MvMovementKind(
      code: 'RUNNING',
      titleFa: 'دویدن',
      emoji: '🏃',
      family: MovementFamily.endurance,
      baseMet: 8.0,
      metLow: 6.0,
      metHigh: 10.0,
      primaryMetric: MovementMetric.distance,
      isOutdoor: true,
      isSocial: false,
      needsVenue: false,
      jointImpact: 2,
      isCustom: false,
      isEnabled: true,
      usageCount: 0,
      sortOrder: 1,
    ),
    MvMovementKind(
      code: 'FOOTBALL',
      titleFa: 'فوتبال',
      emoji: '⚽',
      family: MovementFamily.sport,
      baseMet: 8.0,
      metLow: 6.0,
      metHigh: 10.0,
      primaryMetric: MovementMetric.duration,
      isOutdoor: true,
      isSocial: true,
      needsVenue: true,
      jointImpact: 2,
      isCustom: false,
      isEnabled: true,
      usageCount: 0,
      sortOrder: 2,
    ),
    MvMovementKind(
      code: 'FUTSAL',
      titleFa: 'فوتسال',
      emoji: '⚽',
      family: MovementFamily.sport,
      baseMet: 8.0,
      metLow: 6.0,
      metHigh: 10.0,
      primaryMetric: MovementMetric.duration,
      isOutdoor: false,
      isSocial: true,
      needsVenue: true,
      jointImpact: 2,
      isCustom: false,
      isEnabled: true,
      usageCount: 0,
      sortOrder: 3,
    ),
    MvMovementKind(
      code: 'HIKING',
      titleFa: 'کوهنوردی',
      emoji: '🏔️',
      family: MovementFamily.outdoor,
      baseMet: 7.0,
      metLow: 5.0,
      metHigh: 9.0,
      primaryMetric: MovementMetric.elevation,
      isOutdoor: true,
      isSocial: true,
      needsVenue: false,
      jointImpact: 2,
      isCustom: false,
      isEnabled: true,
      usageCount: 0,
      sortOrder: 4,
    ),
    MvMovementKind(
      code: 'SWIMMING',
      titleFa: 'شنا',
      emoji: '🏊',
      family: MovementFamily.endurance,
      baseMet: 6.0,
      metLow: 4.0,
      metHigh: 8.0,
      primaryMetric: MovementMetric.laps,
      isOutdoor: false,
      isSocial: false,
      needsVenue: true,
      jointImpact: 0,
      isCustom: false,
      isEnabled: true,
      usageCount: 0,
      sortOrder: 5,
    ),
  ];

  @override
  Future<List<MvMovementKind>> getAll({bool onlyEnabled = true}) async =>
      onlyEnabled ? kinds.where((k) => k.isEnabled).toList() : kinds;
  @override
  Future<MvMovementKind?> getByCode(String code) async =>
      kinds.where((k) => k.code == code).firstOrNull;
  @override
  Future<Map<String, MvMovementKind>> getMapByCodes(List<String> codes) async =>
      {for (final k in kinds) if (codes.contains(k.code)) k.code: k};
  @override
  Future<void> bumpUsage(String code) async {}
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class GuardFakeKindProfileRepo implements MvKindProfileRepository {
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

class GuardFakeCampaignRepo implements MvCampaignRepository {
  MvCampaign? activeCampaign;
  List<MvCampaign> campaigns = [];

  @override
  Future<MvCampaign?> getActive() async => activeCampaign;
  @override
  Future<List<MvCampaign>> getAllCampaigns() async => campaigns;
  @override
  Future<MvCampaign> upsert(MvCampaign c) async {
    activeCampaign = c;
    campaigns.add(c);
    return c;
  }
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class GuardFakeSessionRepo implements MvSessionRepository {
  List<MvSession> sessions = [];
  List<MvSessionEvent> events = [];

  @override
  Future<MvSession?> getActiveSession() async => null;
  @override
  Future<List<MvSession>> getCompletedSessionsBetween(DateTime s, DateTime e) async => sessions;
  @override
  Future<List<MvSession>> getSessionHistory({int limit = 20, int offset = 0, String? kindCode}) async => sessions;
  @override
  Future<void> startSession(MvSession session) async {
    sessions.add(session);
  }
  @override
  Future<void> finishSession(
    MvSession session, {
    List<MvSetLog> setLogs = const [],
    MvSessionFeeling? feeling,
    String? note,
  }) async {
    sessions.add(session);
  }
  @override
  Future<void> recordEvent(MvSessionEvent event) async {
    events.add(event);
  }
  Future<void> logCompletedSession(MvSession session) async {
    sessions.add(session);
  }
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class GuardFakeExerciseRepo implements MvExerciseRepository {
  @override
  Future<List<MvExercise>> getAllExercises() async => [];
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class GuardFakePrRepo implements MvPrRepository {
  @override
  Future<List<MvPersonalRecord>> getAllPrs() async => [];
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class GuardFakeDailyCheckinRepo implements MvDailyCheckinRepository {
  @override
  Future<MvDailyCheckin?> getCheckinForDate(String dateIso) async => null;
  @override
  Future<void> saveCheckin(MvDailyCheckin c) async {}
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
  group('Reachability Guard Tests (S8-T13 / R-01..R-06)', () {
    late GuardFakeProfileRepo profileRepo;
    late GuardFakePrescriptionRepo prescriptionRepo;
    late GuardFakeCommitmentRepo commitmentRepo;
    late GuardFakeKindRepo kindRepo;
    late GuardFakeKindProfileRepo kindProfileRepo;
    late GuardFakeCampaignRepo campaignRepo;
    late GuardFakeSessionRepo sessionRepo;
    late GuardFakeExerciseRepo exerciseRepo;
    late GuardFakePrRepo prRepo;
    late GuardFakeDailyCheckinRepo checkinRepo;

    setUp(() {
      profileRepo = GuardFakeProfileRepo();
      prescriptionRepo = GuardFakePrescriptionRepo();
      commitmentRepo = GuardFakeCommitmentRepo();
      kindRepo = GuardFakeKindRepo();
      kindProfileRepo = GuardFakeKindProfileRepo();
      campaignRepo = GuardFakeCampaignRepo();
      sessionRepo = GuardFakeSessionRepo();
      exerciseRepo = GuardFakeExerciseRepo();
      prRepo = GuardFakePrRepo();
      checkinRepo = GuardFakeDailyCheckinRepo();
    });

    MvHubController createController() {
      return MvHubController(
        profileRepo: profileRepo,
        prescriptionRepo: prescriptionRepo,
        commitmentRepo: commitmentRepo,
        kindRepo: kindRepo,
        kindProfileRepo: kindProfileRepo,
        campaignRepo: campaignRepo,
        sessionRepo: sessionRepo,
        exerciseRepo: exerciseRepo,
        prRepo: prRepo,
        checkinRepo: checkinRepo,
      );
    }

    Future<void> pumpScreen(WidgetTester tester, [Duration duration = const Duration(milliseconds: 300)]) async {
      await tester.pump();
      await tester.pump(duration);
    }

    testWidgets('R-01: Create new anchor (max 3 taps from Hub)', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final controller = createController();
      await controller.loadAllData();

      await tester.pumpWidget(createTestApp(controller));
      await pumpScreen(tester);

      // Tap 1: AppBar Lock Icon -> Opens MvCommitmentsScreen
      final openCommitmentsBtn = find.byKey(const ValueKey('mv_open_commitments'));
      expect(openCommitmentsBtn, findsOneWidget);
      await tester.tap(openCommitmentsBtn);
      await pumpScreen(tester);
      expect(find.byType(MvCommitmentsScreen), findsOneWidget);

      // Tap 2: FAB (+) -> Opens MvCommitmentEditSheet
      final addBtn = find.byKey(const ValueKey('mv_add_commitment_fab'));
      expect(addBtn, findsOneWidget);
      await tester.tap(addBtn);
      await pumpScreen(tester);
      expect(find.byType(MvCommitmentEditSheet), findsOneWidget);

      // Tap 3: Save button -> Saves commitment and returns
      final saveBtn = find.byKey(const ValueKey('mv_commitment_save_btn'));
      expect(saveBtn, findsOneWidget);
      await tester.tap(saveBtn);
      await pumpScreen(tester);

      // Verification: Commitment was saved and sheet dismissed
      expect(find.byType(MvCommitmentEditSheet), findsNothing);
      final commitments = await commitmentRepo.getActive();
      expect(commitments.isNotEmpty, isTrue);
    });

    testWidgets('R-02: Change sport kind of a scheduled day (max 4 taps from Hub)', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final todayIso = MvCalendar.formatDateIso(DateTime.now());
      prescriptionRepo.slots = [
        MvSlot(
          id: 'slot_today',
          dateIso: todayIso,
          slotType: MvSlotType.sport,
          kindCode: 'FOOTBALL',
          targetMinutes: 60,
          intensityTier: MvIntensityTier.moderate,
          headlineFa: 'فوتبال',
          createdAt: 100,
          updatedAt: 100,
        ),
      ];

      final controller = createController();
      await controller.loadAllData();

      await tester.pumpWidget(createTestApp(controller));
      await pumpScreen(tester);

      // Tap 1: Week Tab destination
      final weekTabDestination = find.byType(NavigationDestination).at(1);
      await tester.tap(weekTabDestination);
      await pumpScreen(tester);
      expect(find.byType(MvWeekTab), findsOneWidget);

      // Tap 2: Day Slot Card in Week Tab -> Opens MvDayPlanSheet
      final dayCard = find.byType(MvDaySlotCard).first;
      await tester.tap(dayCard);
      await pumpScreen(tester);
      expect(find.byType(MvDayPlanSheet), findsOneWidget);

      // Tap 3: Change kind button -> Opens MvKindPickerSheet
      final changeKindBtn = find.byKey(const ValueKey('mv_change_kind_btn'));
      expect(changeKindBtn, findsOneWidget);
      await tester.tap(changeKindBtn);
      await pumpScreen(tester);
      expect(find.byType(MvKindPickerSheet), findsOneWidget);

      // Tap 4: Select Futsal item
      final futsalItem = find.byKey(const ValueKey('kind_FUTSAL'));
      expect(futsalItem, findsOneWidget);
      await tester.tap(futsalItem);
      await pumpScreen(tester);

      // Verification: Kind updated to Futsal in Day Plan Sheet
      expect(find.byType(MvKindPickerSheet), findsNothing);
      expect(find.textContaining('فوتسال'), findsWidgets);
    });

    testWidgets('R-03: Quick log with chosen sport (max 3 taps from Hub)', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final controller = createController();
      await controller.loadAllData();

      await tester.pumpWidget(createTestApp(controller));
      await pumpScreen(tester);

      // Tap 1: Custom quick log button on Today tab -> Opens MvQuickLogSheet
      final customLogBtn = find.byKey(const ValueKey('mv_quick_log_custom'));
      expect(customLogBtn, findsOneWidget);
      await tester.tap(customLogBtn);
      await pumpScreen(tester);
      expect(find.byType(MvQuickLogSheet), findsOneWidget);

      // Tap 2: Feeling chip 'good'
      final feelingGoodChip = find.byKey(const ValueKey('feeling_good'));
      expect(feelingGoodChip, findsOneWidget);
      await tester.tap(feelingGoodChip);
      await pumpScreen(tester);

      // Tap 3: Save button -> Saves quick log session
      final saveBtn = find.byKey(const ValueKey('quick_log_save_action'));
      expect(saveBtn, findsOneWidget);
      await tester.tap(saveBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Verification: Sheet closed and session logged
      expect(find.byType(MvQuickLogSheet), findsNothing);
      final sessions = await sessionRepo.getSessionHistory(limit: 10);
      expect(sessions.isNotEmpty, isTrue);
    });

    testWidgets('R-04: View training load card (max 1 tap from Hub)', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final controller = createController();
      await controller.loadAllData();

      await tester.pumpWidget(createTestApp(controller));
      await pumpScreen(tester);

      // Tap 1: Progress Tab destination
      final progressTabDestination = find.byType(NavigationDestination).at(2);
      await tester.tap(progressTabDestination);
      await pumpScreen(tester);

      // Verification: Training load section rendered
      expect(find.byType(MvProgressTab), findsOneWidget);
      expect(
        find.byKey(const ValueKey('mv_load_insufficient_data')),
        findsOneWidget,
      );
    });

    testWidgets('R-05: Create targeted campaign (max 2 taps from Hub)', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final controller = createController();
      await controller.loadAllData();

      await tester.pumpWidget(createTestApp(controller));
      await pumpScreen(tester);

      // Tap 1: Progress Tab destination
      final progressTabDestination = find.byType(NavigationDestination).at(2);
      await tester.tap(progressTabDestination);
      await pumpScreen(tester);

      // Tap 2: Create Campaign button
      final createCampaignBtn = find.byKey(const ValueKey('mv_campaign_create'));
      expect(createCampaignBtn, findsOneWidget);
      await tester.tap(createCampaignBtn);
      await pumpScreen(tester);

      // Verification: Campaign dialog is displayed
      expect(find.byKey(const ValueKey('mv_campaign_submit_btn')), findsOneWidget);
    });

    testWidgets('R-06: Start hiking session with route template (max 4 taps from Hub)', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final todayIso = MvCalendar.formatDateIso(DateTime.now());
      prescriptionRepo.slots = [
        MvSlot(
          id: 'slot_today_$todayIso',
          dateIso: todayIso,
          slotType: MvSlotType.outdoor,
          kindCode: 'HIKING',
          targetMinutes: 120,
          intensityTier: MvIntensityTier.moderate,
          headlineFa: 'کوهنوردی',
          createdAt: 100,
          updatedAt: 100,
        ),
      ];

      final controller = createController();
      await controller.loadAllData();

      await tester.pumpWidget(createTestApp(controller));
      await pumpScreen(tester);

      // Tap 1: Start button on Today Hero Card
      final startBtn = find.byKey(const ValueKey('mv_hero_start_btn'));
      expect(startBtn, findsOneWidget);
      await tester.tap(startBtn);
      await pumpScreen(tester, const Duration(milliseconds: 500));

      // Verification: Routes into MvRouteTemplate
      expect(find.byType(MvRouteTemplate), findsOneWidget);
      expect(find.text('ارتفاع صعود'), findsOneWidget);
      expect(find.text('وزن کوله'), findsOneWidget);
    });
  });
}
