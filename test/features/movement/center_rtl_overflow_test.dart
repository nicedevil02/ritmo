import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/movement/application/movement_occurrence_service.dart';
import 'package:ritmo/features/movement/application/movement_session_service.dart';
import 'package:ritmo/features/movement/application/strength_program_service.dart';
import 'package:ritmo/features/movement/domain/models/movement_activity_kind.dart';
import 'package:ritmo/features/movement/domain/models/movement_live_session.dart';
import 'package:ritmo/features/movement/domain/models/movement_occurrence.dart';
import 'package:ritmo/features/movement/domain/models/movement_strength_program.dart';
import 'package:ritmo/features/movement/domain/models/movement_week_summary.dart';
import 'package:ritmo/features/movement/presentation/center/movement_center_controller.dart';
import 'package:ritmo/features/movement/presentation/center/movement_center_screen.dart';
import 'package:ritmo/features/movement/presentation/center/widgets/hero_session_card.dart';
import 'package:ritmo/features/movement/presentation/center/widgets/session_card.dart';

Widget _wrapScale(Widget child, {double textScale = 1.3}) {
  return MaterialApp(
    theme: RitmoTheme.build(
      palette: RitmoPalette.jadeNoir,
      brightness: Brightness.dark,
    ),
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: MediaQuery(
        data: MediaQueryData(
          textScaler: TextScaler.linear(textScale),
          size: const Size(380, 750),
          padding: const EdgeInsets.only(top: 24, bottom: 16),
        ),
        child: child,
      ),
    ),
  );
}

class FakeFullOccurrenceService extends MovementOccurrenceService {
  @override
  Future<Map<String, List<MovementOccurrence>>> getWeekOccurrencesGrouped(
    String startDateIso,
    String endDateIso,
  ) async {
    final now = DateTime.now();
    final todayIso =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    return {
      todayIso: [
        MovementOccurrence(
          id: 'occ_full_1',
          activityKindId: 'kind_running',
          activityKind: MovementActivityKind(
            id: 'kind_running',
            nameFa: 'دویدن استقامتی طولانی',
            family: 'running',
            icon: 'directions_run',
            primaryMetric: 'distance',
            createdAt: DateTime.now(),
          ),
          dateIso: todayIso,
          startTime: '18:30',
          status: MovementOccurrenceStatus.planned,
          goalType: 'duration',
          goalValue: 45,
          goalUnit: 'دقیقه',
          origin: MovementOrigin.template,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ],
    };
  }

  @override
  Future<MovementWeekSummary> getWeekSummary(
    String startDateIso,
    String endDateIso,
    List<String> allSevenDaysIso,
  ) async {
    return const MovementWeekSummary(
      completedCount: 2,
      plannedCount: 4,
      activeMinutes: 90,
      recoveryDaysCount: 3,
    );
  }
}

class FakeSessionService extends MovementSessionService {
  @override
  Future<MovementLiveSession?> getActiveOrPausedSession() async => null;
}

class FakeStrengthProgramService extends StrengthProgramService {
  @override
  Future<MovementStrengthProgram?> getCurrentProgram() async => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Movement Center RTL & Text Scale 1.3x Tests (Requirement 6)', () {
    testWidgets('HeroSessionCard renders with zero overflow at 1.3x text scale across all variants', (tester) async {
      for (final variant in HeroCardVariant.values) {
        await tester.pumpWidget(
          _wrapScale(
            Scaffold(
              body: SingleChildScrollView(
                child: HeroSessionCard(
                  variant: variant,
                  onPrimaryAction: () {},
                  onSecondaryAction: () {},
                  onMoveAction: () {},
                  onShortVersionAction: () {},
                  onLogManualAction: () {},
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('SessionCard renders with zero overflow at 1.3x text scale', (tester) async {
      final occ = MovementOccurrence(
        id: 'occ_1',
        activityKindId: 'kind_hiking',
        activityKind: MovementActivityKind(
          id: 'kind_hiking',
          nameFa: 'کوهنوردی مسیر قله توچال',
          family: 'hiking',
          icon: 'hiking',
          primaryMetric: 'elevation',
          createdAt: DateTime.now(),
        ),
        dateIso: '2026-08-16',
        startTime: '06:00',
        status: MovementOccurrenceStatus.planned,
        goalType: 'elevation',
        goalValue: 800,
        goalUnit: 'متر',
        origin: MovementOrigin.template,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        _wrapScale(
          Scaffold(
            body: SessionCard(
              occurrence: occ,
              onTap: () {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('Complete MovementCenterScreen renders with zero overflow at 1.3x text scale in RTL', (tester) async {
      final controller = MovementCenterController(
        occurrenceService: FakeFullOccurrenceService(),
        sessionService: FakeSessionService(),
        strengthProgramService: FakeStrengthProgramService(),
      );

      await controller.loadData();

      await tester.pumpWidget(
        _wrapScale(
          MovementCenterScreen(controller: controller),
        ),
      );

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
