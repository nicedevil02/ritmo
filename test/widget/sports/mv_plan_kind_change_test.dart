import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/features/supplementary_sports/application/application.dart';
import 'package:ritmo/features/supplementary_sports/data/repositories/repositories.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';
import 'package:ritmo/features/supplementary_sports/presentation/sheets/sheets.dart';
import 'package:ritmo/l10n/app_localizations.dart';

class FakeKindRepo implements MvKindRepository {
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
      baseMet: 9.8,
      metLow: 8.0,
      metHigh: 12.0,
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

Widget createTestApp(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('fa'),
    home: Scaffold(body: child),
  );
}

void main() {
  group('S8-T6 Day Plan Kind Picker & Change Tests', () {
    const initialSlot = MvSlot(
      id: 'slot_1',
      dateIso: '2026-08-26',
      slotType: MvSlotType.strength,
      headlineFa: 'تمرین قدرتی',
      targetMinutes: 30,
      createdAt: 100,
      updatedAt: 100,
    );

    testWidgets('Opening kind picker and selecting sport kind updates slot and renders sport card', (tester) async {
      final fakeRepo = FakeKindRepo();
      final kindUseCase = MvKindUseCase(fakeRepo);
      MvSlot? savedSlot;

      await tester.pumpWidget(
        createTestApp(
          MvDayPlanSheet(
            slot: initialSlot,
            kindUseCase: kindUseCase,
            onSave: (slot) => savedSlot = slot,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('نوع ورزش / فعالیت'), findsOneWidget);
      expect(find.byKey(const ValueKey('day_plan_kind_picker_tile')), findsOneWidget);

      // Open Kind Picker
      await tester.tap(find.byKey(const ValueKey('day_plan_kind_picker_tile')));
      await tester.pumpAndSettle();

      expect(find.byType(MvKindPickerSheet), findsOneWidget);
      expect(find.text('فوتسال'), findsOneWidget);

      // Select Futsal
      await tester.tap(find.text('فوتسال'));
      await tester.pumpAndSettle();

      // Picker is closed, sheet is updated
      expect(find.byKey(const ValueKey('mv_sport_kind_info_card')), findsOneWidget);
      expect(find.textContaining('ورزش تخصصی فوتسال'), findsOneWidget);

      // Save
      await tester.tap(find.byKey(const ValueKey('day_plan_save_action')));
      await tester.pumpAndSettle();

      expect(savedSlot, isNotNull);
      expect(savedSlot!.kindCode, equals('FUTSAL'));
      expect(savedSlot!.slotType, equals(MvSlotType.sport));
      expect(savedSlot!.headlineFa, equals('فوتسال'));
    });
  });
}
