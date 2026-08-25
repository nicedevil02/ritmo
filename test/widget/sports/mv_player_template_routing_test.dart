import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/features/supplementary_sports/application/application.dart';
import 'package:ritmo/features/supplementary_sports/data/repositories/repositories.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';
import 'package:ritmo/features/supplementary_sports/presentation/player/templates/templates.dart';
import 'package:ritmo/features/supplementary_sports/presentation/screens/screens.dart';
import 'package:ritmo/l10n/app_localizations.dart';

class RoutingFakeKindRepo implements MvKindRepository {
  final List<MvMovementKind> kinds = const [
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
      sortOrder: 1,
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
      code: 'RUNNING',
      titleFa: 'دویدن',
      emoji: '🏃',
      family: MovementFamily.endurance,
      baseMet: 9.8,
      metLow: 8.0,
      metHigh: 12.0,
      primaryMetric: MovementMetric.distance,
      isOutdoor: false,
      isSocial: false,
      needsVenue: false,
      jointImpact: 2,
      isCustom: false,
      isEnabled: true,
      usageCount: 0,
      sortOrder: 4,
    ),
    MvMovementKind(
      code: 'STRETCHING',
      titleFa: 'کشش و تحرک‌پذیری',
      emoji: '🧘',
      family: MovementFamily.mindBody,
      baseMet: 2.5,
      metLow: 2.0,
      metHigh: 3.5,
      primaryMetric: MovementMetric.duration,
      isOutdoor: false,
      isSocial: false,
      needsVenue: false,
      jointImpact: 0,
      isCustom: false,
      isEnabled: true,
      usageCount: 0,
      sortOrder: 5,
    ),
  ];

  @override
  Future<List<MvMovementKind>> getAll({bool onlyEnabled = true}) async => kinds;
  @override
  Future<MvMovementKind?> getByCode(String code) async =>
      kinds.where((k) => k.code == code).firstOrNull;
  @override
  Future<List<MvMovementKind>> searchFa(String q, {bool onlyEnabled = true}) async =>
      kinds.where((k) => k.titleFa.contains(q)).toList();
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class RoutingFakeProfileRepo implements MvProfileRepository {
  MvUserProfile profile = const MvUserProfile(
    id: 'user_1',
    onboardingCompleted: true,
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

class RoutingFakePrescriptionRepo implements MvPrescriptionRepository {
  List<MvSlot> slots = [];

  @override
  Future<MvSlot?> getPrescriptionForDate(String dateIso) async =>
      slots.where((s) => s.dateIso == dateIso).firstOrNull;

  @override
  Future<List<MvSlot>> getPrescriptionsForDates(List<String> dateIsos) async =>
      slots.where((s) => dateIsos.contains(s.dateIso)).toList();

  @override
  Future<List<MvSlot>> getWeekSlots(String weekStartIso) async => slots;

  @override
  Future<void> savePrescription(MvSlot slot) async {
    final idx = slots.indexWhere((s) => s.id == slot.id);
    if (idx >= 0) {
      slots[idx] = slot;
    } else {
      slots.add(slot);
    }
  }

  @override
  Future<void> savePrescriptions(List<MvSlot> newSlots) async =>
      slots = List.from(newSlots);

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class RoutingFakeSessionRepo implements MvSessionRepository {
  MvSession? active;

  @override
  Future<MvSession?> getActiveSession() async => active;
  @override
  Future<void> startSession(MvSession session) async => active = session;
  @override
  Future<void> updateSession(MvSession session) async => active = session;
  @override
  Future<void> recordEvent(MvSessionEvent event) async {}
  @override
  Future<List<MvSession>> getRecentSessions({int limit = 100}) async => [];
  @override
  Future<List<MvSession>> getSessionHistory({int limit = 20, int offset = 0}) async => [];
  @override
  Future<List<MvSession>> getCompletedSessionsBetween(DateTime from, DateTime to) async => [];
  @override
  Future<MvSession?> getLastCompletedSession() async => null;
  @override
  Future<void> finishSession(
    MvSession session, {
    List<MvSetLog> setLogs = const [],
    MvSessionFeeling? feeling,
    String? note,
  }) async {
    active = null;
  }
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class RoutingFakeExerciseRepo implements MvExerciseRepository {
  @override
  Future<List<MvExercise>> getAllExercises() async => [];
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class RoutingFakeCommitmentRepo implements MvCommitmentRepository {
  @override
  Future<List<MvCommitment>> getAll({bool onlyActive = true}) async => [];
  @override
  Future<List<MvCommitment>> getActive() async => [];
  @override
  Future<MvCommitment> upsert(MvCommitment c) async => c;
  @override
  Future<int> insert(MvCommitment c) async => 1;
  @override
  Future<void> update(MvCommitment c) async {}
  @override
  Future<void> delete(int id) async {}
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class RoutingFakePrRepo implements MvPrRepository {
  @override
  Future<List<MvPersonalRecord>> getAllPrs() async => [];
  @override
  Future<MvPersonalRecord?> getPrForKind(String kind, MvPrType type) async => null;
  @override
  Future<List<MvPersonalRecord>> getPrsForKind(String kind) async => [];
  @override
  Future<void> recordPr(MvPersonalRecord pr) async {}
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class RoutingFakeCheckinRepo implements MvDailyCheckinRepository {
  @override
  Future<MvDailyCheckin?> getCheckinForDate(String dateIso) async => null;
  @override
  Future<void> saveCheckin(MvDailyCheckin c) async {}
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

Widget createTestApp(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('fa'),
    home: child,
  );
}

void main() {
  group('S8-T10 Player Template Routing Table Verification Tests', () {
    final routingTable = [
      {
        'kindCode': 'HIKING',
        'templateType': MvRouteTemplate,
        'keyWidgetText': 'ارتفاع صعود',
      },
      {
        'kindCode': 'SWIMMING',
        'templateType': MvLapsTemplate,
        'keyWidgetText': '+۱ دور ثبت شد',
      },
      {
        'kindCode': 'FUTSAL',
        'templateType': MvMatchTemplate,
        'keyWidgetText': 'شروع نیمه دوم',
      },
      {
        'kindCode': 'RUNNING',
        'templateType': MvDistanceTemplate,
        'keyWidgetText': 'کیلومتر',
      },
      {
        'kindCode': 'STRETCHING',
        'templateType': MvTimedTemplate,
        'keyWidgetText': 'تمرین اصلی',
      },
    ];

    for (final row in routingTable) {
      final kindCode = row['kindCode'] as String;
      final templateType = row['templateType'] as Type;
      final keyWidgetText = row['keyWidgetText'] as String;

      testWidgets(
        'Routing table: Kind $kindCode routes to $templateType and shows "$keyWidgetText"',
        (tester) async {
          final kindRepo = RoutingFakeKindRepo();
          final profileRepo = RoutingFakeProfileRepo();
          final prescriptionRepo = RoutingFakePrescriptionRepo();
          final sessionRepo = RoutingFakeSessionRepo();
          final exerciseRepo = RoutingFakeExerciseRepo();
          final commitmentRepo = RoutingFakeCommitmentRepo();
          final prRepo = RoutingFakePrRepo();
          final checkinRepo = RoutingFakeCheckinRepo();

          final todayIso = MvCalendar.formatDateIso(DateTime.now());
          final initialSlot = MvSlot(
            id: 'slot_today',
            dateIso: todayIso,
            slotType: MvSlotType.sport,
            kindCode: kindCode,
            headlineFa: 'تمرین $kindCode',
            targetMinutes: 45,
            createdAt: 100,
            updatedAt: 100,
          );
          prescriptionRepo.slots = [initialSlot];

          final controller = MvHubController(
            profileRepo: profileRepo,
            prescriptionRepo: prescriptionRepo,
            sessionRepo: sessionRepo,
            exerciseRepo: exerciseRepo,
            kindRepo: kindRepo,
            commitmentRepo: commitmentRepo,
            prRepo: prRepo,
            checkinRepo: checkinRepo,
          );

          tester.view.physicalSize = const Size(800, 1400);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() => tester.view.resetPhysicalSize());

          await tester.pumpWidget(
            createTestApp(
              MvHubScreen(controller: controller),
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));

          // Today tab is displayed, tap on Start Session button
          final startBtn = find.byKey(const ValueKey('mv_hero_start_btn'));
          expect(startBtn, findsOneWidget);
          await tester.ensureVisible(startBtn);

          await tester.tap(startBtn);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));

          // Verify template is mounted
          expect(find.byType(templateType), findsOneWidget);
          expect(find.text(keyWidgetText), findsWidgets);
        },
      );
    }
  });
}
