import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';
import 'package:ritmo/features/supplementary_sports/presentation/player/player.dart';

Widget createTestApp(Widget child) {
  return MaterialApp(
    theme: ThemeData.light(),
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(body: child),
    ),
  );
}

void main() {
  group('Phase P6 Unified Player & Summary Tests', () {
    const testExercise = MvExercise(
      id: 'push_up',
      name: 'شنا سوئدی',
      category: 'CHEST',
      defaultReps: 12,
    );

    final testSession = MvSession(
      id: 'sess_1',
      kindCode: 'bodyweight',
      startedAt: DateTime.now().millisecondsSinceEpoch,
      createdAt: 100,
      updatedAt: 100,
    );

    testWidgets('MvSessionPlayerScreen renders workout components and advances set', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          MvSessionPlayerScreen(
            initialSession: testSession,
            plannedExercises: const [testExercise],
            initialAudioEnabled: false,
          ),
        ),
      );

      expect(find.text('شنا سوئدی'), findsWidgets);
      expect(find.text('ست 1 از 3'), findsOneWidget);
      expect(find.text('12 تکرار'), findsOneWidget);

      // Complete Set 1
      await tester.tap(find.text('ثبت ست و ادامه (ست 1)'));
      await tester.pumpAndSettle();

      expect(find.text('زمان استراحت'), findsOneWidget);
      expect(find.text('رد کردن استراحت و شروع'), findsOneWidget);
    });

    testWidgets('MvSessionSummaryScreen records feeling and triggers callback', (tester) async {
      MvSessionFeeling? selectedFeeling;

      await tester.pumpWidget(
        createTestApp(
          MvSessionSummaryScreen(
            session: testSession,
            setLogs: const [
              MvSetLog(id: '1', sessionId: 'sess_1', exerciseId: 'push_up', setNumber: 1, reps: 12, loggedAt: 100),
            ],
            onFinish: (f, note) async => selectedFeeling = f,
          ),
        ),
      );

      expect(find.text('خسته نباشی! جلسه به پایان رسید'), findsOneWidget);
      expect(find.text('شدت تمرین امروز برایت چطور بود؟'), findsOneWidget);

      // Tap Easy feeling
      await tester.tap(find.text('راحت / جا داشتم'));
      await tester.pumpAndSettle();

      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pumpAndSettle();

      await tester.tap(find.text('ثبت و بازگشت به هاب'));
      await tester.pump();
      expect(selectedFeeling, equals(MvSessionFeeling.easy));
    });
  });
}
