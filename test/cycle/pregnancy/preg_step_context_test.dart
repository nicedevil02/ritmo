import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/theme/palettes/jade_noir.dart';
import 'package:ritmo/features/cycle/models/pregnancy_models.dart';
import 'package:ritmo/features/cycle/presentation/onboarding/pregnancy_steps/preg_step_3_context.dart';
import 'package:ritmo/l10n/app_localizations.dart';

Widget _buildTestWidget({
  required PregnancyOnboardingData data,
  required ValueChanged<PregnancyOnboardingData> onDataChanged,
  VoidCallback? onNext,
}) {
  return MaterialApp(
    theme: ThemeData.light().copyWith(extensions: [kJadeNoirLight]),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('fa'),
    home: Scaffold(
      body: PregStep3Context(
        data: data,
        onDataChanged: onDataChanged,
        onNext: onNext ?? () {},
        colors: kJadeNoirLight,
        isDark: false,
      ),
    ),
  );
}

void main() {
  group('PregStep3Context Tests (PRG-20)', () {
    testWidgets('renders title, all 4 toggle rows, and reassuring note', (
      tester,
    ) async {
      const data = PregnancyOnboardingData();

      await tester.pumpWidget(
        _buildTestWidget(data: data, onDataChanged: (_) {}),
      );
      await tester.pumpAndSettle();

      expect(find.text('شرایط و اتصالات بارداری'), findsOneWidget);
      expect(find.text('بارداری چندقلو'), findsOneWidget);
      expect(find.text('بارداری پرخطر بر اساس نظر پزشک'), findsOneWidget);
      expect(find.text('توقف پیش‌بینی و یادآوری پریود'), findsOneWidget);
      expect(find.text('تعلیق نماز و روزه در عبادات'), findsOneWidget);
      expect(
        find.textContaining('سابقهٔ چرخه‌ات دست‌نخورده می‌ماند'),
        findsOneWidget,
      );
    });

    testWidgets('toggling switches updates data correctly', (tester) async {
      PregnancyOnboardingData currentData = const PregnancyOnboardingData(
        isMultiple: false,
        isHighRisk: false,
        pauseCyclePredictions: true,
        suspendWorship: false,
      );

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return _buildTestWidget(
              data: currentData,
              onDataChanged: (updated) {
                setState(() {
                  currentData = updated;
                });
              },
            );
          },
        ),
      );
      await tester.pumpAndSettle();

      // Toggle multiple pregnancy
      await tester.tap(find.widgetWithText(Container, 'بارداری چندقلو').last);
      await tester.pumpAndSettle();
      // Or toggle switch directly
      final switches = find.byType(CupertinoSwitch);
      expect(switches, findsNWidgets(4));

      await tester.tap(switches.at(0));
      await tester.pumpAndSettle();
      expect(currentData.isMultiple, true);

      await tester.tap(switches.at(1));
      await tester.pumpAndSettle();
      expect(currentData.isHighRisk, true);

      await tester.tap(switches.at(2));
      await tester.pumpAndSettle();
      expect(currentData.pauseCyclePredictions, false);

      await tester.tap(switches.at(3));
      await tester.pumpAndSettle();
      expect(currentData.suspendWorship, true);
    });
  });
}
