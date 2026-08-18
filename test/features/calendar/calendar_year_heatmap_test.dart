import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/agenda/models/day_agenda_snapshot.dart';
import 'package:ritmo/core/domain/models.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/calendar/presentation/widgets/journey_year_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CAL-47: Year View Heatmap and Legend', () {
    testWidgets('JourneyYearView renders heatmap cells with semantics and legend', (tester) async {
      final item = AgendaItem(
        id: '1',
        sourceId: '1',
        title: 'Task',
        domain: AgendaDomain.task,
        kind: AgendaItemKind.task,
        category: Category.fitness,
        deepLink: const AgendaDeepLink(domain: AgendaDomain.task, targetId: '1'),
        dateStr: '2026-08-18',
        completion: AgendaCompletion.done,
      );

      final snapshot = DayAgendaSnapshot(
        dayAgenda: DayAgenda(dateStr: '2026-08-18', items: [item]),
        completedCount: 1,
        remainingCount: 0,
        freeGaps: const [],
        conflicts: const [],
        overloadScore: 0.0,
        suggestions: const [],
      );

      final rangeSnapshots = <String, DayAgendaSnapshot>{
        '2026-08-18': snapshot,
      };

      await tester.pumpWidget(
        MaterialApp(
          theme: RitmoTheme.darkTheme,
          home: Scaffold(
            body: JourneyYearView(
              selectedDate: DateTime(2026, 8, 18),
              rangeSnapshots: rangeSnapshots,
              onSelectMonth: (_) {},
            ),
          ),
        ),
      );

      // Verify header and month cards
      expect(find.textContaining('نقشهٔ حرارتی و نمای سال'), findsOneWidget);
      expect(find.text('فروردین'), findsOneWidget);
      expect(find.text('مرداد'), findsOneWidget);

      // Verify legend is rendered
      expect(find.textContaining('فعالیت: کمتر'), findsOneWidget);
      expect(find.text('بیشتر'), findsOneWidget);
    });
  });
}
