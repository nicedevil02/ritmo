// test/features/wellbeing/wellbeing_quick_checkin_bar_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/energy/models/energy_mood_models.dart';
import 'package:ritmo/features/reflection/models/reflection_models.dart';
import 'package:ritmo/features/sleep/models/sleep_models.dart';
import 'package:ritmo/features/wellbeing/presentation/widgets/wellbeing_quick_checkin_bar.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: ThemeData.light().copyWith(
      extensions: [
        RitmoColors.light,
      ],
    ),
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WellbeingQuickCheckinBar Tests', () {
    testWidgets('1. Renders empty states with prompt subtitles', (tester) async {
      await tester.pumpWidget(_wrap(
        WellbeingQuickCheckinBar(
          latestMood: null,
          latestEnergy: null,
          latestSleep: null,
          todayReflection: null,
          onMoodEnergyTap: () {},
          onSleepTap: () {},
          onReflectionTap: () {},
        ),
      ));

      expect(find.text('ارزیابی و چک‌این سریع امروز'), findsOneWidget);
      expect(find.text('۳ ستون تعادل'), findsOneWidget);
      expect(find.text('حال روحی و انرژی'), findsOneWidget);
      expect(find.text('ثبت خلق و انرژی الان +'), findsOneWidget);

      expect(find.text('خواب دیشب'), findsOneWidget);
      expect(find.text('ثبت خواب +'), findsOneWidget);

      expect(find.text('بازتاب روز'), findsOneWidget);
      expect(find.text('نوشتن حس روز +'), findsOneWidget);
    });

    testWidgets('2. Renders recorded states with active subtitles', (tester) async {
      final now = DateTime.now();
      final mood = MoodLog(
        id: 'm1',
        loggedAt: now.millisecondsSinceEpoch,
        mood: Mood.happy,
        valence: 4,
        note: 'feeling good',
      );
      final energy = EnergyLog(
        id: 'e1',
        loggedAt: now.millisecondsSinceEpoch,
        energyLevel: EnergyLevel.high,
        source: 'MANUAL',
      );
      final sleep = SleepLog(
        date: '2026-08-23',
        reason: 'regular',
        durationMinutes: 480, // 8 hours
        quality: SleepQuality.good,
        createdAt: now.millisecondsSinceEpoch,
      );
      final reflection = ReflectionEntry(
        date: '2026-08-23',
        moodScore: 4,
        wins: 'Had a great morning',
        createdAt: now.millisecondsSinceEpoch,
      );

      await tester.pumpWidget(_wrap(
        WellbeingQuickCheckinBar(
          latestMood: mood,
          latestEnergy: energy,
          latestSleep: sleep,
          todayReflection: reflection,
          onMoodEnergyTap: () {},
          onSleepTap: () {},
          onReflectionTap: () {},
        ),
      ));

      expect(find.text('خوب و آرام • انرژی بالا ⚡'), findsOneWidget);
      expect(find.text('۸ ساعت'), findsOneWidget);
      expect(find.text('ثبت شد ✓'), findsOneWidget);
    });

    testWidgets('3. Triggers callbacks on tap', (tester) async {
      bool moodEnergyTapped = false;
      bool sleepTapped = false;
      bool reflectionTapped = false;

      await tester.pumpWidget(_wrap(
        WellbeingQuickCheckinBar(
          latestMood: null,
          latestEnergy: null,
          latestSleep: null,
          todayReflection: null,
          onMoodEnergyTap: () => moodEnergyTapped = true,
          onSleepTap: () => sleepTapped = true,
          onReflectionTap: () => reflectionTapped = true,
        ),
      ));

      await tester.tap(find.text('حال روحی و انرژی'));
      await tester.pumpAndSettle();
      expect(moodEnergyTapped, isTrue);

      await tester.tap(find.text('خواب دیشب'));
      await tester.pumpAndSettle();
      expect(sleepTapped, isTrue);

      await tester.tap(find.text('بازتاب روز'));
      await tester.pumpAndSettle();
      expect(reflectionTapped, isTrue);
    });
  });
}
