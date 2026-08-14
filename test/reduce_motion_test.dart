import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';

void main() {
  testWidgets('RitmoMotion.effective returns Duration.zero when disableAnimations is true', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Builder(
            builder: (context) {
              final d = RitmoMotion.effective(context, const Duration(milliseconds: 300));
              expect(d, Duration.zero);
              return const SizedBox();
            },
          ),
        ),
      ),
    );
  });

  testWidgets('RitmoMotion.effective returns base duration when disableAnimations is false', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: false),
          child: Builder(
            builder: (context) {
              final d = RitmoMotion.effective(context, const Duration(milliseconds: 300));
              expect(d, const Duration(milliseconds: 300));
              return const SizedBox();
            },
          ),
        ),
      ),
    );
  });
}

