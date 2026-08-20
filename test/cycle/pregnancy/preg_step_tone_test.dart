import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/theme/palettes/jade_noir.dart';
import 'package:ritmo/features/cycle/models/pregnancy_models.dart';
import 'package:ritmo/features/cycle/presentation/onboarding/pregnancy_steps/preg_step_1_tone.dart';
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
      body: PregStep1Tone(
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
  group('PregStep1Tone Tests (PRG-18)', () {
    testWidgets('renders title, subtitle and both tone option cards', (tester) async {
      const data = PregnancyOnboardingData(tone: PregnancyTone.warm);

      await tester.pumpWidget(_buildTestWidget(
        data: data,
        onDataChanged: (_) {},
      ));
      await tester.pumpAndSettle();

      expect(find.text('قراره کنارت باشیم تا روز تولد'), findsOneWidget);
      expect(find.text('هر چیزی که وارد می‌کنی فقط روی همین گوشی می‌ماند.'), findsOneWidget);
      expect(find.text('گرم و صمیمی'), findsOneWidget);
      expect(find.text('پیام‌ها دلگرم‌کننده و همراه با ایموجی'), findsOneWidget);
      expect(find.text('آرام و ساده'), findsOneWidget);
      expect(find.text('فقط اطلاعات، بدون ایموجی و تبریک'), findsOneWidget);
    });

    testWidgets('selecting neutral tone invokes onDataChanged with PregnancyTone.neutral', (tester) async {
      PregnancyOnboardingData currentData = const PregnancyOnboardingData(tone: PregnancyTone.warm);

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

      // Tap neutral option
      await tester.tap(find.text('آرام و ساده'));
      await tester.pumpAndSettle();

      expect(currentData.tone, PregnancyTone.neutral);

      // Tap warm option back
      await tester.tap(find.text('گرم و صمیمی'));
      await tester.pumpAndSettle();

      expect(currentData.tone, PregnancyTone.warm);
    });
  });
}
