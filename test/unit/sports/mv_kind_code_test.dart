import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('KindCode Canonical UPPER_SNAKE_CASE Enforcement (S0-T2)', () {
    final validKindCodePattern = RegExp(r'^[A-Z][A-Z0-9_]*$');
    final kindCodeArgPattern = RegExp(
      r'''(?<!\.)\bkindCode\s*:\s*['"]([^'"]+)['"]''',
    );

    test(
      'all kindCode literal arguments in supplementary_sports are UPPER_SNAKE_CASE',
      () {
        final dir = Directory('lib/features/supplementary_sports');
        final dartFiles = dir
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'));

        final violations = <String>[];

        for (final file in dartFiles) {
          final content = file.readAsStringSync();
          for (final match in kindCodeArgPattern.allMatches(content)) {
            final code = match.group(1)!;
            if (!validKindCodePattern.hasMatch(code)) {
              violations.add(
                '${file.path}: kindCode "$code" is not UPPER_SNAKE_CASE',
              );
            }
          }
        }

        expect(
          violations,
          isEmpty,
          reason:
              r'All literal kindCode parameters must match ^[A-Z][A-Z0-9_]*$',
        );
      },
    );

    test('sample canonical kind codes all validate successfully', () {
      const canonicalCodes = [
        'WALKING',
        'RUNNING',
        'CYCLING',
        'FOOTBALL',
        'FUTSAL',
        'BASKETBALL',
        'VOLLEYBALL',
        'SWIMMING',
        'HIKING',
        'ROCK_CLIMBING',
        'STRETCHING',
        'BODYWEIGHT',
        'YOGA',
      ];

      for (final code in canonicalCodes) {
        expect(
          validKindCodePattern.hasMatch(code),
          isTrue,
          reason: '$code must match canonical pattern',
        );
      }
    });
  });
}
