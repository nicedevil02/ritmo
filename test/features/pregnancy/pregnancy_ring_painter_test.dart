import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/features/health/data/pregnancy_helpers.dart';

void main() {
  group('UX-02 Milestone Angle Tests', () {
    test('calculates correct milestone angle boundaries for weeks 1 to 40', () {
      expect(PregnancyHelpers.milestoneAngle(1), closeTo(9.0, 0.1));
      expect(PregnancyHelpers.milestoneAngle(10), closeTo(90.0, 0.1));
      expect(PregnancyHelpers.milestoneAngle(20), closeTo(180.0, 0.1));
      expect(PregnancyHelpers.milestoneAngle(30), closeTo(270.0, 0.1));
      expect(PregnancyHelpers.milestoneAngle(40), closeTo(360.0, 0.1));
    });
  });
}
