import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/movement/presentation/common/movement_strings.dart';
import 'package:ritmo/features/movement/presentation/common/undo_toast.dart';

Widget _wrap(
  Widget child, {
  TextScaler textScaler = TextScaler.noScaling,
  bool accessibleNavigation = false,
}) {
  return MaterialApp(
    theme: RitmoTheme.build(
      palette: RitmoPalette.jadeNoir,
      brightness: Brightness.dark,
    ),
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: MediaQuery(
        data: MediaQueryData(
          textScaler: textScaler,
          accessibleNavigation: accessibleNavigation,
          size: const Size(400, 800),
          padding: const EdgeInsets.only(top: 24),
        ),
        child: Scaffold(body: child),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MovementUndoToast Widget & Duration Tests (Point 2)', () {
    tearDown(() {
      MovementUndoToast.dismissCurrent();
    });

    testWidgets(
      'Standard text scale sets 6 seconds duration and auto-dismisses after 6 seconds',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            Builder(
              builder: (context) {
                return Padding(
                  padding: const EdgeInsets.only(top: 150.0),
                  child: ElevatedButton(
                    onPressed: () {
                      MovementUndoToast.show(
                        context,
                        message: MovementStrings.undoMovedTodayOnly,
                        onUndo: () {},
                      );
                    },
                    child: const Text('نمایش توست'),
                  ),
                );
              },
            ),
          ),
        );

        await tester.tap(find.text('نمایش توست'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        // Initial countdown must be 6 seconds: (۶)
        expect(find.text('${MovementStrings.commonUndo} (۶)'), findsOneWidget);

        // Advance by 2 seconds -> countdown becomes (۴)
        await tester.pump(const Duration(seconds: 2));
        expect(find.text('${MovementStrings.commonUndo} (۴)'), findsOneWidget);

        // Advance past 6 seconds and allow reverse animation to complete -> toast auto dismisses
        await tester.pump(const Duration(seconds: 4));
        await tester.pumpAndSettle();
        expect(find.text(MovementStrings.undoMovedTodayOnly), findsNothing);
      },
    );

    testWidgets(
      'High text scale (>1.2) sets 10 seconds duration and countdown starts at (۱۰)',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            Builder(
              builder: (context) {
                return Padding(
                  padding: const EdgeInsets.only(top: 150.0),
                  child: ElevatedButton(
                    onPressed: () {
                      MovementUndoToast.show(
                        context,
                        message: 'تغییر با مقیاس بزرگ',
                        onUndo: () {},
                      );
                    },
                    child: const Text('نمایش توست بزرگ'),
                  ),
                );
              },
            ),
            textScaler: const TextScaler.linear(1.3),
          ),
        );

        await tester.tap(find.text('نمایش توست بزرگ'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        // Initial countdown must be 10 seconds: (۱۰)
        expect(find.text('${MovementStrings.commonUndo} (۱۰)'), findsOneWidget);

        // Advance by 3 seconds -> countdown becomes (۷)
        await tester.pump(const Duration(seconds: 3));
        expect(find.text('${MovementStrings.commonUndo} (۷)'), findsOneWidget);

        // Still visible at 8 seconds
        await tester.pump(const Duration(seconds: 5));
        expect(find.text('${MovementStrings.commonUndo} (۲)'), findsOneWidget);

        // Dismisses after 10 seconds
        await tester.pump(const Duration(seconds: 2));
        await tester.pumpAndSettle();
        expect(find.text('تغییر با مقیاس بزرگ'), findsNothing);
      },
    );

    testWidgets('Accessible navigation mode also uses 10 seconds duration', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (context) {
              return Padding(
                padding: const EdgeInsets.only(top: 150.0),
                child: ElevatedButton(
                  onPressed: () {
                    MovementUndoToast.show(
                      context,
                      message: 'حالت دسترسی‌پذیری',
                      onUndo: () {},
                    );
                  },
                  child: const Text('نمایش توست دسترسی'),
                ),
              );
            },
          ),
          accessibleNavigation: true,
        ),
      );

      await tester.tap(find.text('نمایش توست دسترسی'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text('${MovementStrings.commonUndo} (۱۰)'), findsOneWidget);
    });

    testWidgets('Showing a new toast replaces the previous toast immediately', (
      tester,
    ) async {
      bool firstFinalized = false;

      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (context) {
              return Padding(
                padding: const EdgeInsets.only(top: 150.0),
                child: Column(
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        MovementUndoToast.show(
                          context,
                          message: 'پیام اول',
                          onUndo: () {},
                          onFinalize: () {
                            firstFinalized = true;
                          },
                        );
                      },
                      child: const Text('توست اول'),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () {
                        MovementUndoToast.show(
                          context,
                          message: 'پیام دوم',
                          onUndo: () {},
                        );
                      },
                      child: const Text('توست دوم'),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );

      // Show first toast
      await tester.tap(find.text('توست اول'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text('پیام اول'), findsOneWidget);
      expect(find.text('پیام دوم'), findsNothing);

      // Show second toast -> replaces first
      await tester.tap(find.text('توست دوم'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text('پیام اول'), findsNothing);
      expect(find.text('پیام دوم'), findsOneWidget);
      expect(firstFinalized, isTrue);
    });
  });
}
