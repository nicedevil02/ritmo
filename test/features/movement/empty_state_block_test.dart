import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/movement/presentation/common/empty_state_block.dart';
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

  group('EmptyStateBlock Widget Tests', () {
    testWidgets('Renders all 8 empty state kinds with distinct icons', (tester) async {
      const kinds = MovementEmptyStateKind.values;
      expect(kinds.length, equals(8));

      for (final kind in kinds) {
        await tester.pumpWidget(
          _wrap(
            EmptyStateBlock(
              kind: kind,
              title: 'عنوان تست برای $kind',
              message: 'پیام تست برای $kind',
              primaryActionLabel: MovementStrings.heroBuildWeek,
              onPrimaryAction: () {},
            ),
          ),
        );

        expect(find.text('عنوان تست برای $kind'), findsOneWidget);
        expect(find.text('پیام تست برای $kind'), findsOneWidget);
        expect(find.text(MovementStrings.heroBuildWeek), findsOneWidget);
      }
    });

    testWidgets('Tapping primary and secondary actions triggers callbacks', (tester) async {
      bool primaryTapped = false;
      bool secondaryTapped = false;

      await tester.pumpWidget(
        _wrap(
          EmptyStateBlock(
            kind: MovementEmptyStateKind.emptyWeek,
            title: MovementStrings.weekNoSessionYet,
            message: 'می‌توانی هفته‌ات را با یک برنامهٔ سبک بچینی',
            primaryActionLabel: MovementStrings.heroBuildWeek,
            onPrimaryAction: () {
              primaryTapped = true;
            },
            secondaryActionLabel: MovementStrings.heroSmartWeek,
            onSecondaryAction: () {
              secondaryTapped = true;
            },
          ),
        ),
      );

      await tester.tap(find.text(MovementStrings.heroBuildWeek));
      await tester.pumpAndSettle();
      expect(primaryTapped, isTrue);

      await tester.tap(find.text(MovementStrings.heroSmartWeek));
      await tester.pumpAndSettle();
      expect(secondaryTapped, isTrue);
    });
  });
}
