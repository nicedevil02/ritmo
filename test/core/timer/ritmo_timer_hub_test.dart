import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/timer/ritmo_timer_hub.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_sub_header_timer_banner.dart';

void main() {
  group('RitmoTimerHub Tests', () {
    setUp(() {
      RitmoTimerHub.instance.stopActiveSession();
    });

    tearDown(() {
      RitmoTimerHub.instance.stopActiveSession();
    });

    test('registerOrUpdateSession sets active session and emits state', () {
      bool paused = false;
      bool resumed = false;
      bool stopped = false;

      final session = ActiveLiveTimerSession(
        id: 'test_session',
        domain: RitmoTimerDomain.study,
        title: 'تست مطالعه',
        subtitle: 'فاز تمرکز',
        mode: RitmoTimerMode.pomodoroFocus,
        targetSeconds: 1500,
        elapsedSeconds: 10,
        onPause: () => paused = true,
        onResume: () => resumed = true,
        onStop: () => stopped = true,
      );

      RitmoTimerHub.instance.registerOrUpdateSession(session);

      expect(RitmoTimerHub.instance.hasActiveSession, isTrue);
      expect(RitmoTimerHub.instance.currentSession?.title, 'تست مطالعه');
      expect(RitmoTimerHub.instance.currentSession?.remainingSeconds, 1490);
      expect(RitmoTimerHub.instance.currentSession?.isCompleted, isFalse);

      // Test pause
      RitmoTimerHub.instance.pauseActiveSession();
      expect(paused, isTrue);
      expect(RitmoTimerHub.instance.currentSession?.isRunning, isFalse);

      // Test resume
      RitmoTimerHub.instance.resumeActiveSession();
      expect(resumed, isTrue);
      expect(RitmoTimerHub.instance.currentSession?.isRunning, isTrue);

      // Test stop
      RitmoTimerHub.instance.stopActiveSession();
      expect(stopped, isTrue);
      expect(RitmoTimerHub.instance.hasActiveSession, isFalse);
    });

    testWidgets('RitmoSubHeaderTimerBanner renders nothing when no session', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RitmoSubHeaderTimerBanner(),
          ),
        ),
      );

      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.text('تست مطالعه'), findsNothing);
    });

    testWidgets('RitmoSubHeaderTimerBanner renders and animates when session active', (tester) async {
      final session = ActiveLiveTimerSession(
        id: 'test_ui_session',
        domain: RitmoTimerDomain.sport,
        title: 'دویدن صبحگاهی',
        subtitle: 'کرونومتر زنده',
        mode: RitmoTimerMode.stopwatch,
        targetSeconds: 0,
        elapsedSeconds: 120,
      );

      RitmoTimerHub.instance.registerOrUpdateSession(session);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RitmoSubHeaderTimerBanner(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('دویدن صبحگاهی'), findsOneWidget);
      expect(find.text('کرونومتر زنده'), findsOneWidget);

      await RitmoTimerHub.instance.stopActiveSession();
      await tester.pumpAndSettle();
    });
  });
}
