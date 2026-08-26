import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/features/sleep/logic/sleep_plan_insights.dart';
import 'package:ritmo/features/sleep/models/sleep_models.dart';

void main() {
  group('Sleep Module Fixes Audit (RITF-045 .. RITF-048)', () {
    test('RITF-045: SleepTarget handles malformed bedtime/wake strings without crashing', () {
      final target = SleepTarget(bedtime: 'invalid', wake: 'bad', durationMinutes: 480);
      expect(target.bedtimeHour, 23);
      expect(target.bedtimeMinute, 30);
      expect(target.wakeHour, 7);
      expect(target.wakeMinute, 0);

      final validTarget = SleepTarget(bedtime: '22:15', wake: '06:45', durationMinutes: 510);
      expect(validTarget.bedtimeHour, 22);
      expect(validTarget.bedtimeMinute, 15);
      expect(validTarget.wakeHour, 6);
      expect(validTarget.wakeMinute, 45);
    });

    test('RITF-046: SleepPlanInsights.hhmm formats negative differences without FormatException', () {
      // Normal positive minute of day
      expect(SleepPlanInsights.hhmm(1410), '۲۳:۳۰');
      // 0 minute of day
      expect(SleepPlanInsights.hhmm(0), '۰۰:۰۰');
      // Wrapping/negative minute
      expect(SleepPlanInsights.hhmm(-30), '۲۳:۳۰');
    });
  });
}
