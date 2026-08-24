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
          onMoodTap: () {},
          onEnergyTap: () {},
          onSleepTap: () {},
          onReflectionTap: () {},
        ),
      ));

      expect(find.text('ارزیابی و چک‌این سریع امروز'), findsOneWidget);
      expect(find.text('حس‌وحال الان'), findsOneWidget);
      expect(find.text('ثبت حس الان +'), findsOneWidget);

      expect(find.text('سطح انرژی'), findsOneWidget);
      expect(find.text('ثبت انرژی +'), findsOneWidget);

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
          onMoodTap: () {},
          onEnergyTap: () {},
          onSleepTap: () {},
          onReflectionTap: () {},
        ),
      ));

      expect(find.text('خوب و آرام'), findsOneWidget);
      expect(find.text('انرژی بالا ⚡'), findsOneWidget);
      expect(find.text('۸ ساعت'), findsOneWidget);
      expect(find.text('ثبت شد ✓'), findsOneWidget);
    });

    testWidgets('3. Tapping each pillar invokes its corresponding callback', (tester) async {
      bool moodTapped = false;
      bool energyTapped = false;
      bool sleepTapped = false;
      bool reflectionTapped = false;

      await tester.pumpWidget(_wrap(
        WellbeingQuickCheckinBar(
          latestMood: null,
          latestEnergy: null,
          latestSleep: null,
          todayReflection: null,
          onMoodTap: () => moodTapped = true,
          onEnergyTap: () => energyTapped = true,
          onSleepTap: () => sleepTapped = true,
          onReflectionTap: () => reflectionTapped = true,
        ),
      ));

      await tester.tap(find.text('حس‌وحال الان'));
      expect(moodTapped, isTrue);

      await tester.tap(find.text('سطح انرژی'));
      expect(energyTapped, isTrue);

      await tester.tap(find.text('خواب دیشب'));
      expect(sleepTapped, isTrue);

      await tester.tap(find.text('بازتاب روز'));
      expect(reflectionTapped, isTrue);
    });
  });
}
