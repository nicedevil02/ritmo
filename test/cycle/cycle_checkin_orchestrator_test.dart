// C-35: Unit tests for CycleCheckinOrchestrator
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/domain/engines/cycle_engine.dart';
import 'package:ritmo/features/cycle/logic/cycle_checkin_orchestrator.dart';
import 'package:ritmo/features/cycle/models/cycle_intelligence_models.dart';

void main() {
  group('CycleCheckinOrchestrator Tests (C-35)', () {
    final baseNow = DateTime(2026, 5, 20);

    test('Prompts forgotten open period when report has forgotten period', () {
      final prompt = CycleCheckinOrchestrator.determinePrompt(
        phase: CyclePhase.follicular,
        dataQuality: const DataQualityReport(
          hasEnoughCycles: true,
          hasRecentDailyLogs: true,
          hasForgottenOpenPeriod: true,
          hasPredictionConfidence: true,
          recentLogsCount: 5,
        ),
        pmsWindowStart: null,
        now: baseNow,
      );

      expect(prompt, equals(CycleCheckinPromptType.forgottenOpenPeriod));
    });

    test('Prompts menstrual active when in menstrual phase', () {
      final prompt = CycleCheckinOrchestrator.determinePrompt(
        phase: CyclePhase.menstrual,
        dataQuality: const DataQualityReport(
          hasEnoughCycles: true,
          hasRecentDailyLogs: true,
          hasForgottenOpenPeriod: false,
          hasPredictionConfidence: true,
          recentLogsCount: 5,
        ),
        pmsWindowStart: null,
        now: baseNow,
      );

      expect(prompt, equals(CycleCheckinPromptType.menstrualActive));
    });

    test(
      'Prompts PMS approaching when 2 days before PMS window start without recent logs',
      () {
        final pmsStart = DateTime(2026, 5, 22);
        final prompt = CycleCheckinOrchestrator.determinePrompt(
          phase: CyclePhase.luteal,
          dataQuality: const DataQualityReport(
            hasEnoughCycles: true,
            hasRecentDailyLogs: false,
            hasForgottenOpenPeriod: false,
            hasPredictionConfidence: true,
            recentLogsCount: 0,
          ),
          pmsWindowStart: pmsStart,
          now: baseNow,
        );

        expect(prompt, equals(CycleCheckinPromptType.pmsApproaching));
      },
    );

    test(
      'Prompts encourage daily log when user has enough cycles but no recent daily logs',
      () {
        final prompt = CycleCheckinOrchestrator.determinePrompt(
          phase: CyclePhase.follicular,
          dataQuality: const DataQualityReport(
            hasEnoughCycles: true,
            hasRecentDailyLogs: false,
            hasForgottenOpenPeriod: false,
            hasPredictionConfidence: true,
            recentLogsCount: 0,
          ),
          pmsWindowStart: null,
          now: baseNow,
        );

        expect(prompt, equals(CycleCheckinPromptType.encourageDailyLog));
      },
    );
  });
}
