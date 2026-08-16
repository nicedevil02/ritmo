import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/movement/presentation/common/movement_strings.dart';
import 'package:ritmo/features/movement/presentation/session/sheets/pain_report_sheet.dart';
import 'package:ritmo/features/movement/presentation/session/sheets/pause_exit_sheet.dart';
import 'package:ritmo/features/movement/presentation/session/sheets/session_actions_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildTestableWidget(Widget child) {
    return MaterialApp(
      theme: RitmoTheme.build(
        palette: RitmoPalette.jadeNoir,
        brightness: Brightness.dark,
      ),
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: child,
        ),
      ),
    );
  }

  group('Session Sheets Widget Tests (Gate 3)', () {
    testWidgets('1. SessionActionsSheet renders secondary actions and triggers callbacks', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      bool easeUpTapped = false;

      await tester.pumpWidget(
        buildTestableWidget(
          SessionActionsSheet(
            onEaseUp: () => easeUpTapped = true,
            onSwapMovement: () {},
            onPainReport: () {},
            onSkipStep: () {},
            onStopSession: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(MovementStrings.sessionActionsTitle), findsOneWidget);
      expect(find.text(MovementStrings.sessionActionEaseUp), findsOneWidget);
      expect(find.text(MovementStrings.sessionActionSwapMovement), findsOneWidget);
      expect(find.text(MovementStrings.sessionPainTitle), findsOneWidget);
      expect(find.text(MovementStrings.sessionActionSkipStep), findsOneWidget);
      expect(find.text(MovementStrings.sessionActionStopSession), findsOneWidget);

      await tester.tap(find.text(MovementStrings.sessionActionEaseUp));
      await tester.pumpAndSettle();
      expect(easeUpTapped, isTrue);
    });

    testWidgets('2. PauseExitSheet renders 3 ordered options with recommended pause option', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      PauseExitAction? selectedAction;

      await tester.pumpWidget(
        buildTestableWidget(
          PauseExitSheet(
            onActionSelected: (act) => selectedAction = act,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(MovementStrings.pauseExitTitle), findsOneWidget);
      expect(find.textContaining(MovementStrings.pauseExitPause), findsOneWidget);
      expect(find.text(MovementStrings.pauseExitFinish), findsOneWidget);
      expect(find.text(MovementStrings.pauseExitContinue), findsOneWidget);

      await tester.tap(find.textContaining(MovementStrings.pauseExitPause));
      await tester.pumpAndSettle();

      expect(selectedAction, equals(PauseExitAction.pauseAndBack));
    });

    testWidgets('3. PainReportSheet selects severity and location and produces PainReportData', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      PainReportData? reportData;

      await tester.pumpWidget(
        buildTestableWidget(
          PainReportSheet(
            onSubmitReport: (data) => reportData = data,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(MovementStrings.sessionPainTitle), findsOneWidget);
      expect(find.text(MovementStrings.painReportLocation), findsOneWidget);

      // Select severity 5 (high)
      await tester.tap(find.text('۵'));
      await tester.pumpAndSettle();

      // Submit report
      await tester.ensureVisible(find.text('پایان تمرین و ثبت گزارش'));
      await tester.tap(find.text('پایان تمرین و ثبت گزارش'));
      await tester.pumpAndSettle();

      expect(reportData, isNotNull);
      expect(reportData!.severity, equals(5));
      expect(reportData!.shouldStopSession, isTrue);
    });
  });
}
