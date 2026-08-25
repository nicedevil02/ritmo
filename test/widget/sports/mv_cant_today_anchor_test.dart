import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';
import 'package:ritmo/features/supplementary_sports/presentation/sheets/mv_cant_today_sheet.dart';

void main() {
  group('MvCantTodaySheet Anchor Cancellation Widget Tests (S2-T7)', () {
    testWidgets('Locked slot renders «این هفته لغو شد» option and triggers callback', (tester) async {
      bool cancelAnchorTapped = false;

      const lockedSlot = MvSlot(
        id: 'slot_1',
        dateIso: '2026-08-27',
        headlineFa: 'فوتسال',
        targetMinutes: 60,
        isLocked: true,
        createdAt: 100,
        updatedAt: 100,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    MvCantTodaySheet.show(
                      context: context,
                      slot: lockedSlot,
                      onMinimalDose: () {},
                      onMoveToTomorrow: () {},
                      onChangeToStretch: () {},
                      onSkipEntirely: () {},
                      onCancelAnchorThisWeek: () {
                        cancelAnchorTapped = true;
                      },
                    );
                  },
                  child: const Text('Open Sheet'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      final cancelOption = find.byKey(const ValueKey('mv_anchor_cancelled_this_week'));
      expect(cancelOption, findsOneWidget);
      expect(find.text('این هفته لغو شد'), findsOneWidget);

      await tester.tap(cancelOption);
      await tester.pumpAndSettle();

      expect(cancelAnchorTapped, isTrue);
      expect(find.byType(MvCantTodaySheet), findsNothing); // Sheet popped
    });

    testWidgets('Non-locked slot does NOT render «این هفته لغو شد» option', (tester) async {
      const regularSlot = MvSlot(
        id: 'slot_2',
        dateIso: '2026-08-27',
        headlineFa: 'تمرین هوازی',
        targetMinutes: 30,
        isLocked: false,
        createdAt: 100,
        updatedAt: 100,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    MvCantTodaySheet.show(
                      context: context,
                      slot: regularSlot,
                      onMinimalDose: () {},
                      onMoveToTomorrow: () {},
                      onChangeToStretch: () {},
                      onSkipEntirely: () {},
                    );
                  },
                  child: const Text('Open Sheet'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      final cancelOption = find.byKey(const ValueKey('mv_anchor_cancelled_this_week'));
      expect(cancelOption, findsNothing);
      expect(find.text('این هفته لغو شد'), findsNothing);
    });
  });
}
