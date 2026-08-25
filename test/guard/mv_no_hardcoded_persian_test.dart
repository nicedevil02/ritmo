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

      // Target files from S8-T11: mv_hub_screen.dart, mv_week_tab.dart, mv_settings_screen.dart, mv_quick_log_sheet.dart
      final targetCoreFiles = {
        'mv_hub_screen.dart',
        'mv_week_tab.dart',
        'mv_settings_screen.dart',
        'mv_quick_log_sheet.dart',
      };

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

      if (violations.isNotEmpty) {
        // ignore: avoid_print
        print('=== Found ${violations.length} Hardcoded Persian Violations in Presentation ===');
        for (final v in violations) {
          // ignore: avoid_print
          print(v);
        }
      }

      // Check specifically that the core 4 files from S8-T11 are 100% clean
      final coreViolations = violations.where((v) {
        return targetCoreFiles.any((target) => v.contains(target));
      }).toList();

      expect(
        coreViolations,
        isEmpty,
        reason: 'The 4 target presentation files must have 0 hardcoded Persian strings:\n${coreViolations.join('\n')}',
      );
    });
  });
}
