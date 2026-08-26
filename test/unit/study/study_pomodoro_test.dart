import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/features/study/domain/study_models.dart';

void main() {
  group('ActiveStudySessionState Pomodoro Tests', () {
    test('Calculates remaining seconds and handles focus/break transitions', () {
      const startTime = 1000000;
      const state = ActiveStudySessionState(
        id: 'singleton',
        subjectId: 's1',
        startedAtMs: startTime,
        accumulatedSeconds: 0,
        isPaused: false,
        pomodoroPhase: 'FOCUS',
        pomodoroCycle: 1,
        targetSeconds: 1500, // 25 min
        createdAtMs: startTime,
      );

      expect(state.isPomodoro, isTrue);
      expect(state.isBreak, isFalse);

      // 5 minutes elapsed (300 seconds)
      const now5min = startTime + 300 * 1000;
      expect(state.elapsedSeconds(now5min), 300);
      expect(state.remainingSeconds(now5min), 1200);

      // Switch to break
      final breakState = state.copyWith(
        startedAtMs: now5min,
        accumulatedSeconds: 300,
        pomodoroPhase: 'BREAK',
        targetSeconds: 300, // 5 min break
      );

      expect(breakState.isBreak, isTrue);
      expect(breakState.targetSeconds, 300);

      // 2 minutes of break elapsed
      const now7min = now5min + 120 * 1000;
      expect(breakState.elapsedSeconds(now7min), 420);
      expect(breakState.remainingSeconds(now7min), 180);
    });

    test('Serialization toMap and fromMap preserves Pomodoro fields', () {
      const state = ActiveStudySessionState(
        id: 'singleton',
        subjectId: 'sub_xyz',
        startedAtMs: 5000,
        accumulatedSeconds: 100,
        isPaused: true,
        pomodoroPhase: 'BREAK',
        pomodoroCycle: 3,
        targetSeconds: 600,
        createdAtMs: 5000,
      );

      final map = state.toMap();
      expect(map['pomodoroPhase'], 'BREAK');
      expect(map['pomodoroCycle'], 3);
      expect(map['targetSeconds'], 600);
      expect(map['isPaused'], 1);

      final restored = ActiveStudySessionState.fromMap(map);
      expect(restored.pomodoroPhase, 'BREAK');
      expect(restored.pomodoroCycle, 3);
      expect(restored.targetSeconds, 600);
      expect(restored.isPaused, isTrue);
    });

    test('Pause and resume preserves phase elapsed and remaining seconds (Fixes د.۱)', () {
      const startTime = 1000000;
      const runningState = ActiveStudySessionState(
        id: 'singleton',
        subjectId: 's1',
        startedAtMs: startTime,
        accumulatedSeconds: 0,
        phaseAccumulatedSeconds: 0,
        isPaused: false,
        pomodoroPhase: 'FOCUS',
        pomodoroCycle: 1,
        targetSeconds: 1500, // 25 min
        createdAtMs: startTime,
      );

      // Run for 7 minutes (420 seconds)
      const now7min = startTime + 420 * 1000;
      expect(runningState.phaseElapsedSeconds(now7min), 420);
      expect(runningState.remainingSeconds(now7min), 1080); // 18 min left

      // Pause the session
      final pausedState = runningState.copyWith(
        startedAtMs: now7min,
        accumulatedSeconds: 420,
        phaseAccumulatedSeconds: 420,
        isPaused: true,
      );

      // While paused, even 10 minutes later, phase elapsed stays 420 and remaining stays 1080
      const now17min = now7min + 600 * 1000;
      expect(pausedState.phaseElapsedSeconds(now17min), 420);
      expect(pausedState.remainingSeconds(now17min), 1080);

      // Resume the session at now17min
      final resumedState = pausedState.copyWith(
        startedAtMs: now17min,
        isPaused: false,
      );

      // 3 minutes after resume (now20min)
      const now20min = now17min + 180 * 1000;
      expect(resumedState.phaseElapsedSeconds(now20min), 420 + 180); // 600 seconds total in this phase
      expect(resumedState.remainingSeconds(now20min), 900); // 15 min left
      expect(resumedState.elapsedSeconds(now20min), 600);
    });
  });
}
