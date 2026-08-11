import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/features/worship/logic/worship_completion_repository.dart';

void main() {
  group('Mustahab & Worship Section Audit Tests', () {
    test('WorshipDayStatus.isSkipped covers both SKIPPED and QADA_ADDED', () {
      const statusSkipped = WorshipDayStatus(
        recordId: '1',
        resultType: 'SKIPPED',
        countDone: 0,
      );
      const statusQada = WorshipDayStatus(
        recordId: '2',
        resultType: 'QADA_ADDED',
        countDone: 0,
      );
      const statusDone = WorshipDayStatus(
        recordId: '3',
        resultType: 'DONE',
        countDone: 1,
      );

      expect(statusSkipped.isSkipped, isTrue);
      expect(statusQada.isSkipped, isTrue);
      expect(statusQada.isQadaAdded, isTrue);
      expect(statusDone.isSkipped, isFalse);
      expect(statusDone.isDone, isTrue);
    });
  });
}
