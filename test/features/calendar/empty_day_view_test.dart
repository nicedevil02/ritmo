import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/agenda/models/day_agenda_snapshot.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/calendar/presentation/widgets/empty_day_view.dart';

void main() {
  testWidgets('EmptyDayView displays disabled modules chip when snapshot has disabled domains', (tester) async {
    final enabledMap = <AgendaDomain, bool>{
      AgendaDomain.routine: true,
      AgendaDomain.event: true,
      AgendaDomain.prayer: false,
      AgendaDomain.sport: false,
      AgendaDomain.medicine: true,
      AgendaDomain.course: false,
    };

    final dayAgenda = DayAgenda(
      dateStr: '2026-08-14',
      items: const [],
      rhythmScore: 100,
      enabledDomains: enabledMap,
    );

    final snapshot = DayAgendaSnapshot(
      dayAgenda: dayAgenda,
      completedCount: 0,
      remainingCount: 0,
      freeGaps: const [],
      conflicts: const [],
      overloadScore: 0.0,
      suggestions: const [],
      enabledDomains: enabledMap,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: RitmoTheme.darkTheme,
        home: Scaffold(
          body: EmptyDayView(
            date: DateTime(2026, 8, 14),
            onRefreshRequested: () {},
            snapshot: snapshot,
          ),
        ),
      ),
    );

    expect(find.text('برای این روز چیزی ثبت نشده.'), findsOneWidget);
    expect(find.textContaining('ماژول‌های غیرفعال:'), findsOneWidget);
    expect(find.textContaining('نماز'), findsOneWidget);
    expect(find.textContaining('ورزش'), findsOneWidget);
    expect(find.textContaining('دوره‌ها'), findsOneWidget);
  });
}
