import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('E-09 Guard: No raw fontSize or raw typography in Sports presentation layer', () {
    test('Presentation files must not contain raw fontSize declarations', () {
      final presDir = Directory('lib/features/supplementary_sports/presentation');
      expect(presDir.existsSync(), isTrue, reason: 'Presentation directory must exist');

      final dartFiles = presDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

      final rawFontSizeRegex = RegExp(r'fontSize:\s*\d+');
      final violations = <String>[];

      for (final file in dartFiles) {
        final lines = file.readAsLinesSync();

        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          final trimmed = line.trim();

          // Ignore pure comments
          if (trimmed.startsWith('//') ||
              trimmed.startsWith('/*') ||
              trimmed.startsWith('*') ||
              trimmed.startsWith('///')) {
            continue;
          }

          // Strip inline single-line comments
          final codePart = line.contains('//') ? line.substring(0, line.indexOf('//')) : line;

          if (rawFontSizeRegex.hasMatch(codePart)) {
            violations.add('${file.path}:${i + 1} -> $trimmed');
          }
        }
      }

      if (violations.isNotEmpty) {
        // ignore: avoid_print
        print('=== Found ${violations.length} Raw fontSize Violations in Presentation ===');
        for (final v in violations) {
          // ignore: avoid_print
          print(v);
        }
      }

      expect(
        violations,
        isEmpty,
        reason:
            'All text styles in supplementary_sports/presentation must use Theme.of(context).textTheme instead of raw fontSize values (per docs/RITMO_DESIGN_TOKENS.md).',
      );
    });
  });
}
