import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/ai/brief/briefs/routines_brief.dart';
import 'package:ritmo/core/ai/brief/domain_brief.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Routines Brief Model Tests (PSN-31)', () {
    test('RoutinesBrief provides valid domainId, fields, and json serialization', () {
      final brief = RoutinesBrief(
        sampleSize: 7,
        computedAt: DateTime.now(),
        activeRoutinesCount: 5,
        weeklyAdherencePercentage: 85.5,
        longestStreak: 12,
        remainingTodayCount: 2,
      );

      expect(brief.domainId, equals('routines'));
      expect(brief.confidence, equals(BriefConfidence.high));
      expect(brief.fieldNames, contains('routines.activeRoutinesCount'));

      final json = brief.toPromptJson();
      expect(json['activeRoutinesCount'], equals(5));
      expect(json['weeklyAdherencePercentage'], equals(85.5));
      expect(json['longestStreak'], equals(12));
      expect(json['remainingTodayCount'], equals(2));
      expect(json['confidence'], equals('high'));
    });
  });
}
