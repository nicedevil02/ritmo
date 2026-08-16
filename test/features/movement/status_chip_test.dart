import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/movement/domain/models/movement_occurrence.dart';
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
      child: Scaffold(body: Center(child: child)),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('StatusChip Widget Tests', () {
    testWidgets('Renders all 8 statuses with accurate Persian labels in standard mode', (tester) async {
      const statuses = MovementOccurrenceStatus.values;
      expect(statuses.length, equals(8));

      for (final status in statuses) {
        await tester.pumpWidget(_wrap(StatusChip(status: status)));
        expect(find.byType(StatusChip), findsOneWidget);
      }

      // Verify specific mapped texts
      await tester.pumpWidget(_wrap(const StatusChip(status: MovementOccurrenceStatus.planned)));
      expect(find.text(MovementStrings.statusPlanned), findsOneWidget);

      await tester.pumpWidget(_wrap(const StatusChip(status: MovementOccurrenceStatus.completed)));
      expect(find.text(MovementStrings.statusCompleted), findsOneWidget);

      await tester.pumpWidget(_wrap(const StatusChip(status: MovementOccurrenceStatus.inProgress)));
      expect(find.text(MovementStrings.statusInProgress), findsOneWidget);

      await tester.pumpWidget(_wrap(const StatusChip(status: MovementOccurrenceStatus.late)));
      expect(find.text(MovementStrings.statusLate), findsOneWidget);
    });

    testWidgets('In compact mode, label text is hidden but full semantics is preserved', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const StatusChip(
            status: MovementOccurrenceStatus.completed,
            compact: true,
          ),
        ),
      );

      expect(find.text(MovementStrings.statusCompleted), findsNothing);
      final semantics = tester.getSemantics(find.byType(StatusChip));
      expect(semantics.label, contains('وضعیت: ${MovementStrings.statusCompleted}'));
    });
  });
}
