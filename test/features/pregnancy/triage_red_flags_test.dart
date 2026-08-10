import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/features/health/data/pregnancy_helpers.dart';

void main() {
  group('UX-09 Symptom Triage Red Flags Tests', () {
    test('triggers red flag for severe headache + swelling', () {
      final symptoms = [
        {'code': 'headache', 'severity': 'SEVERE'},
        {'code': 'swelling', 'severity': 'MILD'},
      ];

      final flags = PregnancyHelpers.triageRedFlags(symptoms);
      expect(flags.length, equals(1));
      expect(flags.first, contains('سردرد شدید همراه با تورم'));
    });

    test('triggers red flag for severe headache + blurred vision', () {
      final symptoms = [
        {'code': 'HEADACHE', 'severity': 'severe'},
        {'code': 'BLURRED_VISION', 'severity': 'MODERATE'},
      ];

      final flags = PregnancyHelpers.triageRedFlags(symptoms);
      expect(flags.length, equals(1));
      expect(flags.first, contains('سردرد شدید همراه با تاری دید'));
    });

    test('triggers red flag for bleeding of any severity', () {
      final symptoms = [
        {'code': 'bleeding', 'severity': 'MILD'},
      ];

      final flags = PregnancyHelpers.triageRedFlags(symptoms);
      expect(flags.length, equals(1));
      expect(flags.first, contains('خونریزی بارداری'));
    });

    test('returns empty flags for mild/unrelated symptoms', () {
      final symptoms = [
        {'code': 'nausea', 'severity': 'MILD'},
        {'code': 'headache', 'severity': 'MILD'},
        {'code': 'fatigue', 'severity': 'MODERATE'},
      ];

      final flags = PregnancyHelpers.triageRedFlags(symptoms);
      expect(flags, isEmpty);
    });
  });
}
