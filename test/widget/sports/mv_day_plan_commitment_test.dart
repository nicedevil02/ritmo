import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/features/supplementary_sports/application/application.dart';
import 'package:ritmo/features/supplementary_sports/data/repositories/repositories.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';
import 'package:ritmo/features/supplementary_sports/presentation/sheets/mv_day_plan_sheet.dart';

class _FakeCommitmentRepo implements MvCommitmentRepository {
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

class _FakePrescriptionRepo implements MvPrescriptionRepository {
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

class _FakeProfileRepo implements MvProfileRepository {
  @override
  Future<MvUserProfile> getProfile() async => MvUserProfile.empty();
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _FakeKindRepo implements MvKindRepository {
  final List<MvMovementKind> kinds = const [
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
      sortOrder: 1,
    ),
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
      sortOrder: 2,
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
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _FakeKindProfileRepo implements MvKindProfileRepository {
  @override
  Future<MvKindProfile?> getByCode(String kindCode) async => null;
  @override
  Future<Map<String, MvKindProfile>> getMapByCodes(List<String> codes) async => {};
  @override
  Future<List<MvKindProfile>> getAll() async => [];
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  group('MvDayPlanSheet Commitment Creation Integration Tests (S2-T4)', () {
    late _FakeCommitmentRepo commitmentRepo;
    late _FakePrescriptionRepo prescriptionRepo;
    late _FakeProfileRepo profileRepo;
    late _FakeKindRepo kindRepo;
    late _FakeKindProfileRepo kindProfileRepo;
    late MvSaveCommitmentUseCase saveCommitmentUseCase;
    late MvKindUseCase kindUseCase;

    setUp(() {
      commitmentRepo = _FakeCommitmentRepo();
      prescriptionRepo = _FakePrescriptionRepo();
      profileRepo = _FakeProfileRepo();
      kindRepo = _FakeKindRepo();
      kindProfileRepo = _FakeKindProfileRepo();
      kindUseCase = MvKindUseCase(kindRepo);
      saveCommitmentUseCase = MvSaveCommitmentUseCase(
        commitmentRepo: commitmentRepo,
        prescriptionRepo: prescriptionRepo,
        profileRepo: profileRepo,
        kindRepo: kindRepo,
        kindProfileRepo: kindProfileRepo,
      );
    });

    testWidgets(
      'Opening sheet with plannedTime 21:00 and repeatWeekly switch saves MvCommitment and regenerates week',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

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

        await tester.tap(find.byKey(const ValueKey('open_plan_sheet_btn')));
        await tester.pumpAndSettle();

        final repeatSwitchFinder = find.byKey(
          const ValueKey('day_plan_repeat_weekly_switch'),
        );
        expect(repeatSwitchFinder, findsOneWidget);
        await tester.ensureVisible(repeatSwitchFinder);
        await tester.pumpAndSettle();
        await tester.tap(repeatSwitchFinder);
        await tester.pumpAndSettle();

        final saveBtn = find.byKey(const ValueKey('day_plan_save_action'));
        expect(saveBtn, findsOneWidget);
        await tester.ensureVisible(saveBtn);
        await tester.pumpAndSettle();

        await tester.tap(saveBtn);
        await tester.pumpAndSettle();

        final commitments = await commitmentRepo.getAll();
        expect(commitments.length, equals(1));
        final c = commitments.first;
        expect(c.kindCode, equals('FUTSAL'));
        expect(c.dayOfWeekSat0, equals(5));
        expect(c.startTime, equals('21:00'));
        expect(c.durationMinutes, equals(90));
        expect(c.isActive, isTrue);

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

        final saveBtn = find.byKey(const ValueKey('day_plan_save_action'));
        expect(saveBtn, findsOneWidget);
        await tester.ensureVisible(saveBtn);
        await tester.pumpAndSettle();
        await tester.tap(saveBtn);
        await tester.pumpAndSettle();

        final commitments = await commitmentRepo.getAll();
        expect(commitments, isEmpty);

        expect(savedResult, isNotNull);
        expect(savedResult!.isLocked, isTrue);
        expect(savedResult!.plannedTime, equals('07:00'));
      },
    );
  });
}
