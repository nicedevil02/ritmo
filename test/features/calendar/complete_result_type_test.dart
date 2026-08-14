import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/domain/models/completion_result.dart';

void main() {
  group('P0-1: Occurrence Result Type Tests', () {
    test('OccurrenceResultType defines full, light, minimal, partial, skipped', () {
      expect(OccurrenceResultType.full, equals('FULL'));
      expect(OccurrenceResultType.light, equals('LIGHT'));
      expect(OccurrenceResultType.minimal, equals('MINIMAL'));
      expect(OccurrenceResultType.partial, equals('PARTIAL'));
      expect(OccurrenceResultType.skipped, equals('SKIPPED'));
    });

    test('CompletionResult parses OccurrenceResultType constants and maps correctly', () {
      expect(CompletionResult.fromDb(OccurrenceResultType.full), equals(CompletionResult.full));
      expect(CompletionResult.fromDb(OccurrenceResultType.light), equals(CompletionResult.light));
      expect(CompletionResult.fromDb(OccurrenceResultType.minimal), equals(CompletionResult.minimal));
      expect(CompletionResult.fromDb(OccurrenceResultType.partial), equals(CompletionResult.partial));
      expect(CompletionResult.fromDb(OccurrenceResultType.skipped), equals(CompletionResult.skipped));

      expect(CompletionResult.fromDb(OccurrenceResultType.full).keepsStreak, isTrue);
      expect(CompletionResult.fromDb(OccurrenceResultType.full).advancesProgression, isTrue);
    });
  });
}
