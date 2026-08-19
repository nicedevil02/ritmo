import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/movement/presentation/center/widgets/movement_app_bar.dart';
import 'package:ritmo/features/movement/presentation/common/movement_strings.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: RitmoTheme.build(
      palette: RitmoPalette.jadeNoir,
      brightness: Brightness.dark,
    ),
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(body: Column(children: [child])),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MovementAppBar Widget Tests', () {
    testWidgets(
      'Renders title, subtitle and action buttons with tooltips and semantics',
      (tester) async {
        bool progressTapped = false;
        bool settingsTapped = false;

        await tester.pumpWidget(
          _wrap(
            MovementAppBar(
              title: MovementStrings.centerTitle,
              subtitle: '۲۵ تا ۳۱ مرداد',
              onProgressPressed: () {
                progressTapped = true;
              },
              onSettingsPressed: () {
                settingsTapped = true;
              },
            ),
          ),
        );

        // Title & Subtitle check
        expect(find.text(MovementStrings.centerTitle), findsOneWidget);
        expect(find.text('۲۵ تا ۳۱ مرداد'), findsOneWidget);

        // Tooltips check
        expect(find.byTooltip(MovementStrings.progressTitle), findsOneWidget);
        expect(find.byTooltip(MovementStrings.settingsTitle), findsOneWidget);

        // Semantics header check on Title
        final titleSemantics = tester.getSemantics(
          find.text(MovementStrings.centerTitle),
        );
        expect(
          titleSemantics.getSemanticsData().flagsCollection.isHeader,
          isTrue,
        );

        // Tap buttons
        await tester.tap(find.byTooltip(MovementStrings.progressTitle));
        await tester.pumpAndSettle();
        expect(progressTapped, isTrue);

        await tester.tap(find.byTooltip(MovementStrings.settingsTitle));
        await tester.pumpAndSettle();
        expect(settingsTapped, isTrue);
      },
    );

    testWidgets(
      'Collapses subtitle after 24px scroll, but keeps title visible',
      (tester) async {
        // 1. Initial scroll (offset = 0) -> Subtitle visible
        await tester.pumpWidget(
          _wrap(
            MovementAppBar(
              title: MovementStrings.centerTitle,
              subtitle: '۲۵ تا ۳۱ مرداد',
              scrollOffset: 0.0,
              onProgressPressed: () {},
              onSettingsPressed: () {},
            ),
          ),
        );

        expect(find.text(MovementStrings.centerTitle), findsOneWidget);
        expect(find.text('۲۵ تا ۳۱ مرداد'), findsOneWidget);

        // 2. Scrolled past 24px -> Subtitle collapsed, Title still visible
        await tester.pumpWidget(
          _wrap(
            MovementAppBar(
              title: MovementStrings.centerTitle,
              subtitle: '۲۵ تا ۳۱ مرداد',
              scrollOffset: 25.0,
              onProgressPressed: () {},
              onSettingsPressed: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text(MovementStrings.centerTitle), findsOneWidget);
        expect(find.text('۲۵ تا ۳۱ مرداد'), findsNothing);
      },
    );
  });
}
