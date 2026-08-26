import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('E-08 Guard: No hardcoded Persian strings in Sports presentation layer', () {
    test('Presentation files must not contain hardcoded Persian string literals', () {
      final presDir = Directory('lib/features/supplementary_sports/presentation');
      expect(presDir.existsSync(), isTrue, reason: 'Presentation directory must exist');

      final dartFiles = presDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

      final persianStringRegex = RegExp(r"""(?<!//.*)['"][^'"]*[\u0600-\u06FF][^'"]*['"]""");
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

          final matches = persianStringRegex.allMatches(codePart);
          for (final m in matches) {
            final matchedText = m.group(0)!;
            violations.add('${file.path}:${i + 1} -> $matchedText ($trimmed)');
          }
        }
      }

      final fileMap = <String, List<String>>{};
      for (final v in violations) {
        final parts = v.split(' -> ');
        final fileLoc = parts[0];
        final str = parts.length > 1 ? parts[1] : '';
        final file = fileLoc.split(':')[0];
        final line = fileLoc.split(':')[1];
        fileMap.putIfAbsent(file, () => []).add('Line $line: $str');
      }

      if (fileMap.isNotEmpty) {
        // ignore: avoid_print
        print('=== Total ${violations.length} violations across ${fileMap.length} files ===');
        fileMap.forEach((file, list) {
          // ignore: avoid_print
          print('$file: ${list.length} violations');
        });
      }

      expect(
        violations.length,
        equals(0),
        reason: 'All presentation files must have 0 hardcoded Persian strings, but found ${violations.length}',
      );
    });
  });
}
