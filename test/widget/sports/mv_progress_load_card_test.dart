import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';
import 'package:ritmo/features/supplementary_sports/presentation/screens/screens.dart';
import 'package:ritmo/l10n/app_localizations.dart';

Widget createTestApp(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('fa'),
    home: Scaffold(body: child),
  );
}

void main() {
  group('S8-T7 Progress Tab Load Card Tests', () {
    testWidgets('State 1: Insufficient data renders MvInsufficientData without zero charts', (tester) async {
      const insufficientLoad = MvLoadSnapshot(
        acuteLoad: 120,
        chronicWeeklyLoad: 150.0,
        ratio: null,
        bandKey: null,
        daysOfHistory: 5,
        completedSessions: 2,
      );

      await tester.pumpWidget(
        createTestApp(
          const MvProgressTab(
            loadSnapshot: insufficientLoad,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('mv_load_insufficient_data')), findsOneWidget);
      expect(find.byKey(const ValueKey('mv_training_load_card')), findsNothing);
    });

    testWidgets('State 2: Sufficient data renders training load card with ACWR ratio and band', (tester) async {
      const sufficientLoad = MvLoadSnapshot(
        acuteLoad: 350,
        chronicWeeklyLoad: 320.0,
        ratio: 1.09,
        bandKey: 'mv_load_band_optimal',
        daysOfHistory: 21,
        completedSessions: 8,
      );

      await tester.pumpWidget(
        createTestApp(
          const MvProgressTab(
            loadSnapshot: sufficientLoad,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('mv_training_load_card')), findsOneWidget);
      expect(find.byKey(const ValueKey('mv_load_band_optimal')), findsOneWidget);
      expect(find.text('مطلوب و سازنده'), findsWidgets);
      expect(find.byKey(const ValueKey('mv_load_ratio_text')), findsOneWidget);
      expect(find.byKey(const ValueKey('mv_load_insufficient_data')), findsNothing);
    });
  });
}
