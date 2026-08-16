import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/movement/presentation/common/confirm_dialog.dart';
import 'package:ritmo/features/movement/presentation/common/movement_strings.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: RitmoTheme.build(
      palette: RitmoPalette.jadeNoir,
      brightness: Brightness.dark,
    ),
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(body: child),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MovementConfirmDialog Widget Tests', () {
    testWidgets('Renders title, message, and all items in impactList', (tester) async {
      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  showMovementConfirmDialog(
                    context,
                    title: MovementStrings.settingsDeleteMovementData,
                    message: 'آیا از حذف داده‌های بخش حرکت اطمینان دارید؟',
                    impactList: [
                      '۸ جلسهٔ آینده حذف می‌شود',
                      'تاریخچهٔ تمرینات پاک خواهد شد',
                    ],
                    confirmLabel: MovementStrings.commonDelete,
                    cancelLabel: MovementStrings.commonCancel,
                    destructive: true,
                  );
                },
                child: const Text('نمایش دیالوگ'),
              );
            },
          ),
        ),
      );

      // Open dialog
      await tester.tap(find.text('نمایش دیالوگ'));
      await tester.pumpAndSettle();

      expect(find.text(MovementStrings.settingsDeleteMovementData), findsOneWidget);
      expect(find.text('آیا از حذف داده‌های بخش حرکت اطمینان دارید؟'), findsOneWidget);
      expect(find.text('۸ جلسهٔ آینده حذف می‌شود'), findsOneWidget);
      expect(find.text('تاریخچهٔ تمرینات پاک خواهد شد'), findsOneWidget);
      expect(find.text(MovementStrings.commonDelete), findsOneWidget);
      expect(find.text(MovementStrings.commonCancel), findsOneWidget);

      // Cancel dialog
      await tester.tap(find.text(MovementStrings.commonCancel));
      await tester.pumpAndSettle();

      expect(find.text(MovementStrings.settingsDeleteMovementData), findsNothing);
    });

    testWidgets('Confirm button returns true on dialog pop', (tester) async {
      bool? dialogResult;

      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () async {
                  dialogResult = await showMovementConfirmDialog(
                    context,
                    title: 'تأیید اقدام',
                    message: 'آیا ادامه می‌دهید؟',
                  );
                },
                child: const Text('باز کردن'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('باز کردن'));
      await tester.pumpAndSettle();

      await tester.tap(find.text(MovementStrings.commonConfirm));
      await tester.pumpAndSettle();

      expect(dialogResult, isTrue);
    });
  });
}
