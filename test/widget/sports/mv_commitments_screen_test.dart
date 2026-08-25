import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/features/supplementary_sports/application/application.dart';
import 'package:ritmo/features/supplementary_sports/data/repositories/repositories.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';
import 'package:ritmo/features/supplementary_sports/presentation/components/components.dart';
import 'package:ritmo/features/supplementary_sports/presentation/screens/screens.dart';
import 'package:ritmo/l10n/app_localizations.dart';

class FakeCommitmentRepo implements MvCommitmentRepository {
  List<MvCommitment> items = [];

  FakeCommitmentRepo([List<MvCommitment>? initial]) {
    if (initial != null) items = List.from(initial);
  }

  @override
  Future<List<MvCommitment>> getAll({bool onlyActive = true}) async {
    return onlyActive ? items.where((i) => i.isActive).toList() : items;
  }

  @override
  Future<List<MvCommitment>> getActive() => getAll(onlyActive: true);

  @override
  Future<List<MvCommitment>> getForDay(int dayOfWeekSat0, {bool onlyActive = true}) async {
    return items.where((i) => i.dayOfWeekSat0 == dayOfWeekSat0 && (!onlyActive || i.isActive)).toList();
  }

  @override
  Future<MvCommitment?> getById(int id) async {
    return items.where((i) => i.id == id).firstOrNull;
  }

  @override
  Future<int> insert(MvCommitment c) async {
    final newId = items.length + 1;
    final created = c.copyWith(id: newId);
    items.add(created);
    return newId;
  }

  @override
  Future<void> update(MvCommitment c) async {
    final idx = items.indexWhere((i) => i.id == c.id);
    if (idx != -1) items[idx] = c;
  }

  @override
  Future<MvCommitment> upsert(MvCommitment c) async {
    if (c.id == null) {
      final id = await insert(c);
      return c.copyWith(id: id);
    }
    await update(c);
    return c;
  }

  @override
  Future<void> delete(int id) async {
    items.removeWhere((i) => i.id == id);
  }

  @override
  Future<void> toggleActive(int id, bool isActive) async {
    final idx = items.indexWhere((i) => i.id == id);
    if (idx != -1) items[idx] = items[idx].copyWith(isActive: isActive);
  }

  @override
  Future<void> deactivate(int id) async => toggleActive(id, false);
}

class FakeKindRepo implements MvKindRepository {
  @override
  Future<List<MvMovementKind>> getAll({bool onlyEnabled = true}) async {
    return const [
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
        code: 'WALKING',
        titleFa: 'پیاده‌روی',
        emoji: '🚶',
        family: MovementFamily.endurance,
        baseMet: 3.5,
        metLow: 2.5,
        metHigh: 4.5,
        primaryMetric: MovementMetric.distance,
        isOutdoor: true,
        isSocial: false,
        needsVenue: false,
        jointImpact: 1,
        isCustom: false,
        isEnabled: true,
        usageCount: 0,
        sortOrder: 2,
      ),
    ];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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
  group('S8-T3 MvCommitmentsScreen Tests', () {
    testWidgets('Renders empty state with CTA button when no commitments exist', (tester) async {
      final fakeRepo = FakeCommitmentRepo([]);
      final fakeKindRepo = FakeKindRepo();

      await tester.pumpWidget(
        createTestApp(
          MvCommitmentsScreen(
            commitmentUseCase: MvCommitmentUseCase(fakeRepo),
            kindUseCase: MvKindUseCase(fakeKindRepo),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(MvInsufficientData), findsOneWidget);
      expect(find.text('ورزش‌های ثابت هفتگی'), findsWidgets);
      expect(find.byKey(const ValueKey('mv_add_commitment_empty_btn')), findsOneWidget);
      expect(find.byKey(const ValueKey('mv_add_commitment_fab')), findsOneWidget);
    });

    testWidgets('Renders populated state with cards and toggle switch', (tester) async {
      final fakeRepo = FakeCommitmentRepo([
        MvCommitment(
          id: 1,
          kindCode: 'FUTSAL',
          titleFa: 'فوتسال هفتگی',
          dayOfWeekSat0: 5, // پنجشنبه
          startTime: '21:00',
          durationMinutes: 90,
          recurrence: CommitmentRecurrence.weekly,
          isActive: true,
          isFlexible: false,
          startDateIso: '2026-08-25',
        ),
      ]);
      final fakeKindRepo = FakeKindRepo();

      await tester.pumpWidget(
        createTestApp(
          MvCommitmentsScreen(
            commitmentUseCase: MvCommitmentUseCase(fakeRepo),
            kindUseCase: MvKindUseCase(fakeKindRepo),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('فوتسال هفتگی'), findsOneWidget);
      expect(find.textContaining('پنج'), findsOneWidget);
      expect(find.textContaining('21:00'), findsOneWidget);
      expect(find.byKey(const ValueKey('mv_commitment_switch_1')), findsOneWidget);

      // Toggle switch deactivates
      await tester.tap(find.byKey(const ValueKey('mv_commitment_switch_1')));
      await tester.pumpAndSettle();
      expect(fakeRepo.items.first.isActive, isFalse);
    });
  });
}
