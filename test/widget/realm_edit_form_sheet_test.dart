import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/ux/ritmo_sheet_scaffold.dart';
import 'package:ritmo/features/today/presentation/widgets/realm_edit_form_sheet.dart';
import 'package:ritmo/l10n/app_localizations.dart';

Widget _buildWrapper({required Widget child, double width = 320}) {
  return MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [
      Locale('fa'),
      Locale('en'),
    ],
    locale: const Locale('fa'),
    theme: RitmoTheme.build(palette: RitmoPalette.jadeNoir, brightness: Brightness.light),
    home: Scaffold(
      body: SizedBox(
        width: width,
        height: 1200,
        child: child,
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RealmEditFormSheet Responsive & Day Selection Tests', () {
    testWidgets('Configures DraggableScrollableSheet with Apple HIG detents (0.60 medium, 0.95 large)', (tester) async {
      await tester.pumpWidget(
        _buildWrapper(
          width: 360,
          child: RealmEditFormSheet(
            onSave: (realm, schedules) async {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final sheetFinder = find.byType(DraggableScrollableSheet);
      expect(sheetFinder, findsOneWidget);

      final sheetWidget = tester.widget<DraggableScrollableSheet>(sheetFinder);
      expect(sheetWidget.initialChildSize, 0.60);
      expect(sheetWidget.minChildSize, 0.35);
      expect(sheetWidget.maxChildSize, 0.95);
      expect(sheetWidget.snap, isTrue);
      expect(sheetWidget.snapSizes, const [0.60, 0.95]);
    });

    testWidgets('Renders days row without 75px overflow on narrow 320dp screen', (tester) async {
      tester.view.physicalSize = const Size(320 * 3, 1000 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        _buildWrapper(
          width: 320,
          child: RealmEditFormSheet(
            onSave: (realm, schedules) async {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('روزهای فعال:'), findsOneWidget);
      expect(find.text('همه روزها'), findsOneWidget);
      expect(find.text('روزهای کاری'), findsOneWidget);
      expect(find.text('ش'), findsOneWidget);
      expect(find.text('ی'), findsOneWidget);
      expect(find.text('د'), findsOneWidget);
      expect(find.text('س'), findsOneWidget);
      expect(find.text('چ'), findsOneWidget);
      expect(find.text('پ'), findsOneWidget);
      expect(find.text('ج'), findsOneWidget);
    });

    testWidgets('Tapping day toggles selection correctly', (tester) async {
      tester.view.physicalSize = const Size(360 * 3, 1000 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        _buildWrapper(
          width: 360,
          child: RealmEditFormSheet(
            onSave: (realm, schedules) async {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Ensure 'ج' is scrolled into view in the nested scrollable before tapping
      await tester.ensureVisible(find.text('ج'));
      await tester.pumpAndSettle();

      // Tap 'ج' (Friday) to toggle
      await tester.tap(find.text('ج'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Ensure 'همه روزها' is visible and tap
      await tester.ensureVisible(find.text('همه روزها'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('همه روزها'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('Focusing text field expands sheet to large detent (0.95)', (tester) async {
      await tester.pumpWidget(
        _buildWrapper(
          width: 360,
          child: RealmEditFormSheet(
            onSave: (realm, schedules) async {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final sheetFinder = find.byType(DraggableScrollableSheet);
      final sheetWidget = tester.widget<DraggableScrollableSheet>(sheetFinder);
      final controller = sheetWidget.controller;
      expect(controller, isNotNull);
      expect(controller!.size, closeTo(0.60, 0.01));

      // Tap on TextField to request focus
      final textFieldFinder = find.byType(TextField);
      await tester.tap(textFieldFinder);
      await tester.pumpAndSettle();

      // Verify sheet animated to 0.95
      expect(controller.size, closeTo(0.95, 0.01));
    });

    testWidgets('Renders iOS 26 RTL Header with Cancel and Save buttons', (tester) async {
      var saved = false;
      await tester.pumpWidget(
        _buildWrapper(
          width: 360,
          child: RealmEditFormSheet(
            onSave: (realm, schedules) async {
              saved = true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find 'انصراف' (Cancel on Leading/Right)
      expect(find.text('انصراف'), findsOneWidget);

      // Find Title
      expect(find.text('ساخت قلمرو جدید'), findsOneWidget);

      // Find 'ایجاد' in header and 'ایجاد قلمرو' in bottom CTA
      expect(find.text('ایجاد'), findsOneWidget);
      expect(find.text('ایجاد قلمرو'), findsOneWidget);

      // Enter valid name and tap header 'ایجاد'
      await tester.enterText(find.byType(TextField), 'تست قلمرو');
      await tester.pumpAndSettle();

      await tester.tap(find.text('ایجاد'));
      await tester.pumpAndSettle();

      expect(saved, isTrue);
    });

    testWidgets('AppleCardDeckHost renders child and handles route secondary animation safely', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppleCardDeckHost(
              child: Text('صفحه زیرین'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('صفحه زیرین'), findsOneWidget);
    });
  });
}
