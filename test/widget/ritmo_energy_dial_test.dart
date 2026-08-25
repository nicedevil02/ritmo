// test/widget/ritmo_energy_dial_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/widgets/ritmo_energy_dial.dart';

Widget _buildWrapper({
  required Widget child,
  bool isDark = false,
}) {
  return MaterialApp(
    theme: isDark
        ? ThemeData.dark().copyWith(
            extensions: [
              RitmoColors.dark,
            ],
          )
        : ThemeData.light().copyWith(
            extensions: [
              RitmoColors.light,
            ],
          ),
    home: Scaffold(
      body: Center(child: child),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RitmoEnergyDial Widget Tests', () {
    testWidgets('1. Renders correctly with percentage in Light Mode', (tester) async {
      await tester.pumpWidget(_buildWrapper(
        isDark: false,
        child: const RitmoEnergyDial(
          percentage: 45,
          isDarkMode: false,
          size: 80,
        ),
      ));

      expect(find.byType(RitmoEnergyDial), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
      expect(find.textContaining('۴۵'), findsOneWidget);
      expect(find.textContaining('٪'), findsOneWidget);
    });

    testWidgets('2. Renders correctly with percentage in Dark Mode', (tester) async {
      await tester.pumpWidget(_buildWrapper(
        isDark: true,
        child: const RitmoEnergyDial(
          percentage: 85,
          isDarkMode: true,
          size: 70,
        ),
      ));

      expect(find.byType(RitmoEnergyDial), findsOneWidget);
      expect(find.textContaining('۸۵'), findsOneWidget);
      expect(find.textContaining('٪'), findsOneWidget);
    });

    testWidgets('3. Renders dash when percentage is null (unrecorded)', (tester) async {
      await tester.pumpWidget(_buildWrapper(
        isDark: false,
        child: const RitmoEnergyDial(
          percentage: null,
          isDarkMode: false,
        ),
      ));

      expect(find.text('—'), findsOneWidget);
    });
  });
}
