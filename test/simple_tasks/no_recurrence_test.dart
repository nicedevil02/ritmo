import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Phase 6 Architecture Guard (T-36): No Recurrence in Simple Tasks', () {
    test('Ensures simple_tasks feature never contains recurrence concepts or repeat rules', () {
      final simpleTasksDir = Directory('lib/features/simple_tasks');
      expect(simpleTasksDir.existsSync(), isTrue);

      final forbiddenTokens = [
        'repeatRule',
        'recurrence',
        'rrule',
        'everyNDays',
        'weeklyPattern',
      ];

      final violations = <String>[];

      for (final entity in simpleTasksDir.listSync(recursive: true)) {
        if (entity is File && entity.path.endsWith('.dart')) {
          final codeOnly = entity.readAsStringSync()
              .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
              .replaceAll(RegExp(r'//.*'), '');

          for (final token in forbiddenTokens) {
            // Case-insensitive check on code contents
            if (codeOnly.toLowerCase().contains(token.toLowerCase())) {
              violations.add('${entity.path} contains forbidden token: $token');
            }
          }
        }
      }

      expect(violations, isEmpty, reason: 'Simple Tasks must remain strictly non-recurring');
    });
  });
}
