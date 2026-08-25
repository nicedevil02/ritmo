import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/agenda/models/day_agenda_snapshot.dart';
import 'package:ritmo/core/settings/settings_service.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/calendar/presentation/journey_controller.dart';
import 'package:ritmo/features/calendar/presentation/widgets/calendar_management_sheet.dart';
import 'package:ritmo/features/calendar/presentation/widgets/day_review_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SettingsService.instance.init();
  });

  const dummySnapshot = DayAgendaSnapshot(
    dayAgenda: DayAgenda(
      dateStr: '2026-08-26',
      items: [],
      rhythmScore: 85,
    ),
    completedCount: 5,
    remainingCount: 2,
    freeGaps: [],
    conflicts: [],
    overloadScore: 0.0,
    suggestions: [],
  );

  group('Calendar Sheets Glassmorphism Tests', () {
    testWidgets('CalendarManagementSheet renders BackdropFilter when glass is enabled', (tester) async {
      final glassTheme = RitmoTheme.build(
        palette: RitmoPalette.jadeNoir,
        brightness: Brightness.dark,
        reduceTransparency: false,
        glassBlurSigma: 20.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: glassTheme,
          home: Scaffold(
            body: CalendarManagementSheet(
              currentScale: JourneyScale.week,
              onSelectScale: (_) {},
              selectedDate: DateTime.now(),
              onRefresh: () {},
              onOpenDayReview: () {},
              onOpenDayMarkPicker: () {},
              onOpenAllPlans: () {},
              healthIssueCount: 0,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(BackdropFilter), findsOneWidget);
    });

    testWidgets('CalendarManagementSheet renders opaque container when glass is disabled', (tester) async {
      final opaqueTheme = RitmoTheme.build(
        palette: RitmoPalette.jadeNoir,
        brightness: Brightness.dark,
        reduceTransparency: true,
        glassBlurSigma: 0.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: opaqueTheme,
          home: Scaffold(
            body: CalendarManagementSheet(
              currentScale: JourneyScale.week,
              onSelectScale: (_) {},
              selectedDate: DateTime.now(),
              onRefresh: () {},
              onOpenDayReview: () {},
              onOpenDayMarkPicker: () {},
              onOpenAllPlans: () {},
              healthIssueCount: 0,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(BackdropFilter), findsNothing);
    });

    testWidgets('DayReviewSheet renders BackdropFilter when glass is enabled', (tester) async {
      final glassTheme = RitmoTheme.build(
        palette: RitmoPalette.jadeNoir,
        brightness: Brightness.dark,
        reduceTransparency: false,
        glassBlurSigma: 20.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: glassTheme,
          home: const Scaffold(
            body: DayReviewSheet(
              dateStr: '2026-08-26',
              snapshot: dummySnapshot,
              onReviewed: _noOp,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(BackdropFilter), findsOneWidget);
    });

    testWidgets('DayReviewSheet renders opaque container when glass is disabled', (tester) async {
      final opaqueTheme = RitmoTheme.build(
        palette: RitmoPalette.jadeNoir,
        brightness: Brightness.dark,
        reduceTransparency: true,
        glassBlurSigma: 0.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: opaqueTheme,
          home: const Scaffold(
            body: DayReviewSheet(
              dateStr: '2026-08-26',
              snapshot: dummySnapshot,
              onReviewed: _noOp,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(BackdropFilter), findsNothing);
    });
  });
}

void _noOp() {}
