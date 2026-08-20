import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NoRawPregnancyWrites Tests (PRG-06)', () {
    test('no presentation file in cycle feature has raw db.insert for pregnancy mode flag', () {
      final presentationDir = Directory('lib/features/cycle/presentation');
      expect(presentationDir.existsSync(), isTrue);

      final dartFiles = presentationDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));

      final insertCallPattern = RegExp(
        r"insert\s*\(\s*['" r'"]app_settings[^;]+?\)',
        dotAll: true,
      );

      for (final file in dartFiles) {
        final content = file.readAsStringSync();
        final matches = insertCallPattern.allMatches(content);
        for (final match in matches) {
          final callText = match.group(0)!;
          final containsPregnancyFlag =
              callText.contains('cycle_pregnancy_mode') ||
              callText.contains("'pregnancy_mode'");
          expect(
            containsPregnancyFlag,
            isFalse,
            reason:
                'File ${file.path} contains raw db.insert for pregnancy flag: $callText',
          );
        }
      }
    });
  });
}
