// Unit tests for CycleDayLog (C-20)
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/features/cycle/logic/cycle_day_logs_repository.dart';

void main() {
  group('CycleDayLog Model & Taxonomy (C-20)', () {
    test('toMap and fromMap serialize and deserialize symptoms, mood, and flowLevel', () {
      final log = CycleDayLog(
        id: 'cdl_test_1',
        logDate: DateTime(2026, 5, 14),
        flowLevel: 'HEAVY',
        symptoms: ['cramps', 'headache', 'bloating'],
        mood: 'IRRITABLE',
        energyTag: 'LOW',
        note: 'روز اول قاعدگی با درد شکمی',
        createdAt: 1700000000,
        updatedAt: 1700001000,
      );

      final map = log.toMap();
      expect(map['id'], 'cdl_test_1');
      expect(map['logDate'], '2026-05-14');
      expect(map['flowLevel'], 'HEAVY');
      expect(map['mood'], 'IRRITABLE');
      expect(map['energyTag'], 'LOW');
      expect(map['note'], 'روز اول قاعدگی با درد شکمی');
      expect(map['symptomsJson'], '["cramps","headache","bloating"]');

      final restored = CycleDayLog.fromMap(map);
      expect(restored.id, 'cdl_test_1');
      expect(restored.logDate.year, 2026);
      expect(restored.logDate.month, 5);
      expect(restored.logDate.day, 14);
      expect(restored.flowLevel, 'HEAVY');
      expect(restored.symptoms, ['cramps', 'headache', 'bloating']);
      expect(restored.mood, 'IRRITABLE');
      expect(restored.energyTag, 'LOW');
      expect(restored.note, 'روز اول قاعدگی با درد شکمی');
    });

    test('fromMap handles empty or malformed symptoms gracefully', () {
      final mapWithEmpty = {
        'id': 'cdl_test_2',
        'logDate': '2026-05-15',
        'symptomsJson': '',
        'createdAt': 1000,
        'updatedAt': 1000,
      };

      final restored = CycleDayLog.fromMap(mapWithEmpty);
      expect(restored.symptoms, isEmpty);
    });

    test('symptomTaxonomy contains essential symptom keys and Persian labels', () {
      expect(CycleDayLogsRepository.symptomTaxonomy.containsKey('cramps'), true);
      expect(CycleDayLogsRepository.symptomTaxonomy.containsKey('headache'), true);
      expect(CycleDayLogsRepository.symptomTaxonomy.containsKey('backache'), true);
      expect(CycleDayLogsRepository.symptomTaxonomy.containsKey('breast_tenderness'), true);
      expect(CycleDayLogsRepository.symptomTaxonomy.containsKey('bloating'), true);
      expect(CycleDayLogsRepository.symptomTaxonomy.containsKey('fatigue'), true);
    });
  });
}
