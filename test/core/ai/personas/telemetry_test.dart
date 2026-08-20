import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/ai/personas/persona_telemetry.dart';

void main() {
  setUp(() {
    PersonaTelemetryCollector.instance.clear();
  });

  group('PersonaTelemetryCollector Tests (PSN-48)', () {
    test('Records single telemetry entry and preserves fields', () {
      final now = DateTime.now();
      final record = PersonaTelemetryRecord(
        timestamp: now,
        personaId: 'sleep',
        selectedSkill: 'debt_report',
        requestedConfidence: 'high',
        finalConfidence: 'medium',
        validationSeverity: 'annotate',
        violatedRuleId: 'RULE_CORRELATION',
        droppedCommandsCount: 1,
        promptMenuLength: 5,
        incompleteDomains: ['routines'],
      );

      PersonaTelemetryCollector.instance.record(record);

      expect(PersonaTelemetryCollector.instance.length, 1);
      final r = PersonaTelemetryCollector.instance.records.first;
      expect(r.personaId, 'sleep');
      expect(r.selectedSkill, 'debt_report');
      expect(r.finalConfidence, 'medium');
      expect(r.droppedCommandsCount, 1);
      expect(r.incompleteDomains, ['routines']);
    });

    test(
      'Circular buffer enforces maxCapacity of 200 and discards oldest records',
      () {
        final collector = PersonaTelemetryCollector.instance;

        for (var i = 0; i < 250; i++) {
          collector.record(
            PersonaTelemetryRecord(
              timestamp: DateTime.now(),
              personaId: 'persona_$i',
              selectedSkill: 'skill_$i',
            ),
          );
        }

        // Max capacity must be exactly 200
        expect(collector.length, PersonaTelemetryCollector.maxCapacity);
        expect(collector.length, 200);

        // Oldest 50 records (0..49) must have been discarded
        expect(collector.records.first.personaId, 'persona_50');
        expect(collector.records.last.personaId, 'persona_249');
      },
    );

    test('Clear empties the in-memory collector', () {
      final collector = PersonaTelemetryCollector.instance;
      collector.record(
        PersonaTelemetryRecord(timestamp: DateTime.now(), personaId: 'worship'),
      );
      expect(collector.length, 1);

      collector.clear();
      expect(collector.length, 0);
      expect(collector.records, isEmpty);
    });
  });
}
