import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/onboarding/presentation/steps/step_identity.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('StepIdentity Layout Resilience Tests (Huawei & Narrow Screen)', () {
    testWidgets('Renders properly without overflow on 320dp narrow width with FEMALE selected', (tester) async {
      String selectedGender = 'FEMALE';
      tester.view.physicalSize = const Size(320 * 2.0, 640 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: RitmoTheme.build(
            palette: RitmoPalette.jadeNoir,
            brightness: Brightness.dark,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: SizedBox(
                width: 320,
                child: StepIdentity(
                  name: 'الی',
                  onNameChanged: (_) {},
                  gender: selectedGender,
                  onGenderChanged: (g) => selectedGender = g,
                  age: 25,
                  onAgeChanged: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(find.text('مرد'), findsOneWidget);
      expect(find.text('زن'), findsOneWidget);
      expect(find.text('ترجیح می‌دم نگم'), findsOneWidget);
    });

    testWidgets('Tapping gender options updates selection smoothly without overflow', (tester) async {
      String selectedGender = 'MALE';

      await tester.pumpWidget(
        MaterialApp(
          theme: RitmoTheme.build(
            palette: RitmoPalette.jadeNoir,
            brightness: Brightness.dark,
          ),
          home: StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                body: SizedBox(
                  width: 360,
                  child: StepIdentity(
                    name: 'علی',
                    onNameChanged: (_) {},
                    gender: selectedGender,
                    onGenderChanged: (g) => setState(() => selectedGender = g),
                    age: 30,
                    onAgeChanged: (_) {},
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('زن'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(selectedGender, 'FEMALE');
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('ترجیح می‌دم نگم'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(selectedGender, 'PREFER_NOT_TO_SAY');
      expect(tester.takeException(), isNull);
    });
  });
}
