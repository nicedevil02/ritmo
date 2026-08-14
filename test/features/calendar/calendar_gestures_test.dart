import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Calendar Time Travel Gestures Tests', () {
    testWidgets('RTL Horizontal swipe detects direction correctly', (tester) async {
      int periodOffset = 0;

      await tester.pumpWidget(
        MaterialApp(
          theme: RitmoTheme.darkTheme,
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragEnd: (details) {
                  if (details.primaryVelocity == null) return;
                  // RTL awareness: swipe left = next period (1), swipe right = prev period (-1)
                  if (details.primaryVelocity! < -150) {
                    periodOffset += 1;
                  } else if (details.primaryVelocity! > 150) {
                    periodOffset -= 1;
                  }
                },
                child: const SizedBox(
                  width: 400,
                  height: 600,
                  child: Center(child: Text('منطقه سوایپ')),
                ),
              ),
            ),
          ),
        ),
      );

      // Fling to the left (primaryVelocity < -150) -> next period (+1)
      await tester.fling(find.text('منطقه سوایپ'), const Offset(-300, 0), 1000);
      await tester.pumpAndSettle();
      expect(periodOffset, 1);

      // Fling to the right (primaryVelocity > 150) -> prev period (-1)
      await tester.fling(find.text('منطقه سوایپ'), const Offset(300, 0), 1000);
      await tester.pumpAndSettle();
      expect(periodOffset, 0);
    });
  });
}
