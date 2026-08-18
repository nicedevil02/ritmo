import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CAL-58: Architectural & Dependency Invariant Guards', () {
    final calendarDirs = [
      Directory('lib/features/calendar'),
      Directory('lib/core/domain/agenda'),
    ];

    List<File> getDartFiles(Directory dir) {
      if (!dir.existsSync()) return [];
      return dir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .toList();
    }

    test('1. No forbidden feature imports (features/courses/) in lib/features/calendar (CAL-41)', () {
      final violations = <String>[];
      final calendarDir = Directory('lib/features/calendar');
      for (final file in getDartFiles(calendarDir)) {
        final content = file.readAsStringSync();
        final lines = content.split('\n');
        for (int i = 0; i < lines.length; i++) {
          final line = lines[i];
          if (line.startsWith('import ') && line.contains('package:ritmo/features/courses/')) {
            violations.add('${file.path}:${i + 1} -> $line');
          }
        }
      }
      expect(violations, isEmpty, reason: 'Forbidden features/courses imports found: $violations');
    });

    test('2. No debugPrint in lib/features/calendar or lib/core/domain/agenda (CAL-06)', () {
      final violations = <String>[];
      for (final dir in calendarDirs) {
        for (final file in getDartFiles(dir)) {
          final content = file.readAsStringSync();
          final lines = content.split('\n');
          for (int i = 0; i < lines.length; i++) {
            final line = lines[i];
            if (line.contains('debugPrint(') && !line.trim().startsWith('//')) {
              violations.add('${file.path}:${i + 1} -> $line');
            }
          }
        }
      }
      expect(violations, isEmpty, reason: 'debugPrint calls found (must use RitmoLog): $violations');
    });

    test('3. No silent catch (_) or catch(_) in lib/features/calendar or lib/core/domain/agenda (CAL-37)', () {
      final violations = <String>[];
      final regex = RegExp(r'catch\s*\(\s*_\s*\)');
      for (final dir in calendarDirs) {
        for (final file in getDartFiles(dir)) {
          final content = file.readAsStringSync();
          final lines = content.split('\n');
          for (int i = 0; i < lines.length; i++) {
            final line = lines[i];
            if (regex.hasMatch(line) && !line.trim().startsWith('//')) {
              violations.add('${file.path}:${i + 1} -> $line');
            }
          }
        }
      }
      expect(violations, isEmpty, reason: 'Silent catch (_) found (must bind e, st and log): $violations');
    });

    test('4. No toIso8601String().substring date truncation in calendar or agenda domain (CAL-02)', () {
      final violations = <String>[];
      final regex = RegExp(r'toIso8601String\(\)\.substring');
      for (final dir in calendarDirs) {
        for (final file in getDartFiles(dir)) {
          final content = file.readAsStringSync();
          final lines = content.split('\n');
          for (int i = 0; i < lines.length; i++) {
            final line = lines[i];
            if (regex.hasMatch(line) && !line.trim().startsWith('//')) {
              violations.add('${file.path}:${i + 1} -> $line');
            }
          }
        }
      }
      expect(violations, isEmpty, reason: 'Unsafe toIso8601String().substring found (must use DateKey.of): $violations');
    });

    test('5. No db.query("app_settings") inside lib/features/ (CAL-22)', () {
      final featuresDir = Directory('lib/features/calendar');
      final violations = <String>[];
      final regex = RegExp(r"db\.(raw)?query\s*\(\s*['\x22]app_settings");
      for (final file in getDartFiles(featuresDir)) {
        final content = file.readAsStringSync();
        final lines = content.split('\n');
        for (int i = 0; i < lines.length; i++) {
          final line = lines[i];
          if (regex.hasMatch(line) && !line.trim().startsWith('//')) {
            violations.add('${file.path}:${i + 1} -> $line');
          }
        }
      }
      expect(violations, isEmpty, reason: 'Direct app_settings SQL query found (must use SettingsService): $violations');
    });

    test('6. No English _errorMessage = "Failed..." strings in calendar (CAL-07)', () {
      final calendarDir = Directory('lib/features/calendar');
      final violations = <String>[];
      final regex = RegExp(r"_errorMessage\s*=\s*['\x22]Failed", caseSensitive: false);
      for (final file in getDartFiles(calendarDir)) {
        final content = file.readAsStringSync();
        final lines = content.split('\n');
        for (int i = 0; i < lines.length; i++) {
          final line = lines[i];
          if (regex.hasMatch(line) && !line.trim().startsWith('//')) {
            violations.add('${file.path}:${i + 1} -> $line');
          }
        }
      }
      expect(violations, isEmpty, reason: 'English error messages found (must use Persian CalendarMessagesFa): $violations');
    });
  });
}
