// C-41, C-43, C-44: Architecture Source Guard & Static Constraint Tests
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Cycle Source Guards & Quality Constraints (C-41, C-43, C-44)', () {
    final cycleDir = Directory('lib/features/cycle');
    final logicDir = Directory('lib/features/cycle/logic');
    final presentationDir = Directory('lib/features/cycle/presentation');

    test(
      'C-44: Every file in lib/features/cycle must have fewer than 800 lines',
      () {
        expect(cycleDir.existsSync(), isTrue);

        final files = cycleDir
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'));

        final longFiles = <String, int>{};
        for (final file in files) {
          final lineCount = file.readAsLinesSync().length;
          if (lineCount >= 800) {
            longFiles[file.path] = lineCount;
          }
        }

        expect(
          longFiles,
          isEmpty,
          reason: 'Files exceeding 800-line limit: $longFiles',
        );
      },
    );

    test(
      'C-41: Zero Persian Unicode characters in lib/features/cycle/logic',
      () {
        expect(logicDir.existsSync(), isTrue);

        final files = logicDir
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart') && !f.path.endsWith('cycle_privacy_text.dart'));

        final persianRegex = RegExp(
          r'[\u0600-\u06FF\uFB50-\uFDFF\uFE70-\uFEFF]',
        );
        final filesWithPersian = <String>[];

        for (final file in files) {
          final lines = file.readAsLinesSync();
          for (var i = 0; i < lines.length; i++) {
            final line = lines[i];
            // Allow comments if any, but verify code lines
            final nonComment = line.split('//').first;
            if (persianRegex.hasMatch(nonComment)) {
              filesWithPersian.add('${file.path}:${i + 1}');
            }
          }
        }

        expect(
          filesWithPersian,
          isEmpty,
          reason:
              'Logic files containing Persian characters: $filesWithPersian',
        );
      },
    );

    test(
      'C-43: Zero hardcoded Color(0x...) in lib/features/cycle/presentation',
      () {
        expect(presentationDir.existsSync(), isTrue);

        final files = presentationDir
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'));

        final hardcodedColorRegex = RegExp(r'Color\(\s*0x');
        final filesWithHardcodedColors = <String>[];

        for (final file in files) {
          final lines = file.readAsLinesSync();
          for (var i = 0; i < lines.length; i++) {
            final line = lines[i];
            final nonComment = line.split('//').first;
            if (hardcodedColorRegex.hasMatch(nonComment)) {
              filesWithHardcodedColors.add('${file.path}:${i + 1}');
            }
          }
        }

        expect(
          filesWithHardcodedColors,
          isEmpty,
          reason:
              'Presentation files containing hardcoded colors: $filesWithHardcodedColors',
        );
      },
    );
  });
}
