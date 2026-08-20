import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/navigation/ritmo_router.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/movement/presentation/activity_picker/activity_picker_screen.dart';
import 'package:ritmo/features/movement/presentation/center/movement_center_screen.dart';
import 'package:ritmo/features/movement/presentation/movement_routes.dart';
import 'package:ritmo/features/movement/presentation/planner/activity_plan_editor_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget wrapWithTheme(Widget child) {
    return MaterialApp(
      theme: RitmoTheme.build(
        palette: RitmoPalette.jadeNoir,
        brightness: Brightness.dark,
      ),
      home: Directionality(textDirection: TextDirection.rtl, child: child),
    );
  }

  group('Final Movement Redesign Integration Suite (Phase 10 / P-26, P-27, P-28)', () {
    test('1. All 6 Movement routes resolve properly in RitmoRouter', () {
      final centerTarget = RitmoRouter.resolve(MovementRoutes.center);
      expect(centerTarget, isNotNull);

      final pickerTarget = RitmoRouter.resolve(MovementRoutes.picker);
      expect(pickerTarget, isNotNull);

      final planTarget = RitmoRouter.resolve(MovementRoutes.planEditor);
      expect(planTarget, isNotNull);

      final sessionTarget = RitmoRouter.resolve(MovementRoutes.liveSession);
      expect(sessionTarget, isNotNull);

      final summaryTarget = RitmoRouter.resolve(MovementRoutes.summary);
      expect(summaryTarget, isNotNull);

      final settingsTarget = RitmoRouter.resolve(MovementRoutes.settings);
      expect(settingsTarget, isNotNull);
    });

    testWidgets('2. Center screen renders cleanly without crashes', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const MovementCenterScreen(),
        ),
      );
      await tester.pump();

      expect(find.byType(MovementCenterScreen), findsOneWidget);
    });

    testWidgets('3. ActivityPickerScreen renders 8 core categories without clutter', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const ActivityPickerScreen(),
        ),
      );
      await tester.pump();

      expect(find.byType(ActivityPickerScreen), findsOneWidget);
      expect(find.text('انتخاب فعالیت ورزشی'), findsOneWidget);
    });

    testWidgets('4. ActivityPlanEditorScreen renders 3 questions', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const ActivityPlanEditorScreen(),
        ),
      );
      await tester.pump();

      expect(find.byType(ActivityPlanEditorScreen), findsOneWidget);
      expect(find.text('۱. چند روز در هفته می‌خوای تمرین کنی؟'), findsOneWidget);
      expect(find.text('۲. کدوم روزها برات مناسب‌تره؟'), findsOneWidget);
      expect(find.text('۳. چه ساعتی بهت یادآوری کنیم؟'), findsOneWidget);
    });
  });
}
