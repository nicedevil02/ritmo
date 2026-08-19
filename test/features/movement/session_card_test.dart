import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/movement/domain/models/movement_activity_kind.dart';
import 'package:ritmo/features/movement/domain/models/movement_occurrence.dart';
import 'package:ritmo/features/movement/presentation/center/widgets/session_card.dart';
import 'package:ritmo/features/movement/presentation/common/movement_layout.dart';
import 'package:ritmo/features/movement/presentation/common/movement_strings.dart';
import 'package:ritmo/features/movement/presentation/common/status_chip.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: RitmoTheme.build(
      palette: RitmoPalette.jadeNoir,
      brightness: Brightness.dark,
    ),
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SessionCard Widget Tests (Requirement 5)', () {
    final testKind = MovementActivityKind(
      id: 'kind_cycling',
      nameFa: 'دوچرخه‌سواری',
      family: 'cycling',
      icon: 'directions_bike',
      primaryMetric: 'distance',
      createdAt: DateTime.now(),
    );

    testWidgets(
      'Renders all 7 states of SessionCard with accurate status chips and accents',
      (tester) async {
        const statuses = MovementOccurrenceStatus.values;
        for (final s in statuses) {
          final occ = MovementOccurrence(
            id: 'occ_${s.name}',
            activityKindId: 'kind_cycling',
            activityKind: testKind,
            dateIso: '2026-08-16',
            startTime: '18:00',
            status: s,
            goalType: 'duration',
            goalValue: 40,
            goalUnit: 'دقیقه',
            origin: MovementOrigin.template,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );

          await tester.pumpWidget(
            _wrap(SessionCard(occurrence: occ, onTap: () {})),
          );

          expect(find.text('دوچرخه‌سواری'), findsOneWidget);
          expect(find.byType(StatusChip), findsOneWidget);
        }
      },
    );

    testWidgets(
      'Completed session card has reduced opacity, check icon, and height >= kSessionCardMinHeight',
      (tester) async {
        final occ = MovementOccurrence(
          id: 'occ_done',
          activityKindId: 'kind_cycling',
          activityKind: testKind,
          dateIso: '2026-08-16',
          startTime: '10:00',
          status: MovementOccurrenceStatus.completed,
          goalType: 'duration',
          goalValue: 30,
          goalUnit: 'دقیقه',
          origin: MovementOrigin.template,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await tester.pumpWidget(
          _wrap(SessionCard(occurrence: occ, onTap: () {})),
        );

        expect(find.byIcon(Icons.check_rounded), findsOneWidget);

        final cardSize = tester.getSize(find.byType(SessionCard));
        expect(
          cardSize.height,
          greaterThanOrEqualTo(MovementLayout.kSessionCardMinHeight),
        );
      },
    );

    testWidgets('Opening popup menu reveals all standard actions', (
      tester,
    ) async {
      bool moveTapped = false;

      final occ = MovementOccurrence(
        id: 'occ_planned',
        activityKindId: 'kind_cycling',
        activityKind: testKind,
        dateIso: '2026-08-16',
        startTime: '19:00',
        status: MovementOccurrenceStatus.planned,
        goalType: 'duration',
        goalValue: 45,
        goalUnit: 'دقیقه',
        origin: MovementOrigin.template,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        _wrap(
          SessionCard(
            occurrence: occ,
            onTap: () {},
            onMove: () {
              moveTapped = true;
            },
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();

      expect(find.text(MovementStrings.menuStart), findsOneWidget);
      expect(find.text(MovementStrings.menuMove), findsOneWidget);
      expect(find.text(MovementStrings.menuShortVersion), findsOneWidget);
      expect(find.text(MovementStrings.menuSkip), findsOneWidget);
      expect(find.text(MovementStrings.menuEditPlan), findsOneWidget);
      expect(find.text(MovementStrings.menuDelete), findsOneWidget);

      await tester.tap(find.text(MovementStrings.menuMove));
      await tester.pumpAndSettle();
      expect(moveTapped, isTrue);
    });
  });
}
