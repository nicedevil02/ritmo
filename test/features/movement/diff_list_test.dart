import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/movement/presentation/common/diff_list.dart';
import 'package:ritmo/features/movement/presentation/common/movement_strings.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: RitmoTheme.build(
      palette: RitmoPalette.jadeNoir,
      brightness: Brightness.dark,
    ),
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DiffList Widget Tests', () {
    final testItems = [
      const MovementDiffItem(
        id: '1',
        kind: MovementDiffKind.moved,
        beforeText: 'شنبه ۱۸:۰۰',
        afterText: 'یکشنبه ۱۹:۰۰',
        reason: 'تداخل با برنامه دیگر',
        isSelected: true,
      ),
      const MovementDiffItem(
        id: '2',
        kind: MovementDiffKind.locked,
        beforeText: '',
        afterText: 'جلسهٔ اجرا شده پیاده‌روی',
        reason: 'جلسه انجام‌شده قفل است',
        isLocked: true,
        isSelected: false,
      ),
      const MovementDiffItem(
        id: '3',
        kind: MovementDiffKind.added,
        beforeText: '',
        afterText: 'جلسه قدرتی بالاتنه',
        reason: 'تکمیل برنامه هفتگی',
        isSelected: true,
      ),
    ];

    testWidgets('Renders before/after/reason and locked label', (tester) async {
      await tester.pumpWidget(
        _wrap(DiffList(items: testItems, onItemToggled: (_) {})),
      );

      expect(find.textContaining('شنبه ۱۸:۰۰'), findsOneWidget);
      expect(find.textContaining('یکشنبه ۱۹:۰۰'), findsOneWidget);
      expect(find.textContaining(MovementStrings.diffLocked), findsOneWidget);
      expect(find.textContaining('تکمیل برنامه هفتگی'), findsOneWidget);
    });

    testWidgets('Locked row cannot be selected or toggled', (tester) async {
      MovementDiffItem? toggledItem;

      await tester.pumpWidget(
        _wrap(
          DiffList(
            items: testItems,
            onItemToggled: (item) {
              toggledItem = item;
            },
          ),
        ),
      );

      final checkboxes = find.byType(Checkbox);
      expect(checkboxes, findsNWidgets(3));

      // First checkbox is enabled
      final firstCheckbox = tester.widget<Checkbox>(checkboxes.at(0));
      expect(firstCheckbox.onChanged, isNotNull);

      // Second checkbox (locked) is disabled
      final lockedCheckbox = tester.widget<Checkbox>(checkboxes.at(1));
      expect(lockedCheckbox.onChanged, isNull);

      // Tapping first checkbox toggles it
      await tester.tap(checkboxes.at(0));
      await tester.pumpAndSettle();

      expect(toggledItem, isNotNull);
      expect(toggledItem!.id, equals('1'));
      expect(toggledItem!.isSelected, isFalse);
    });
  });
}
