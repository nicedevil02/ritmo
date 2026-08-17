import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Agent Terminology & Persian Spelling Integrity Tests (T42)', () {
    const forbiddenTypos = <String, String>{
      'تنطیم': 'تنظیم',
      'منتطر': 'منتظر',
      'حافطه': 'حافظه',
      'لحطه': 'لحظه',
      'حفط': 'حفظ',
    };

    test('lib/core/ai directory has 0 forbidden typographical errors', () {
      final dir = Directory('lib/core/ai');
      expect(dir.existsSync(), isTrue);

      final dartFiles = dir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .toList();

      final violations = <String>[];

      for (final file in dartFiles) {
        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          for (final entry in forbiddenTypos.entries) {
            if (line.contains(entry.key)) {
              violations.add(
                '${file.path}:${i + 1} contains "${entry.key}" (should be "${entry.value}"): "$line"',
              );
            }
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason: 'Found typographical errors:\n${violations.join('\n')}',
      );
    });
  });
}
