import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/features/supplementary_sports/supplementary_sports.dart';

void main() {
  group('Phase P7 Architecture & Guard Tests (ADR 0008)', () {
    test('All 11 Domain Engines are properly constructed and accessible', () {
      const engines = [
        ProfileEngine(),
        ReadinessEngine(),
        PlanEngine(),
        SelectionEngine(),
        SubstitutionEngine(),
        ProgressionEngine(),
        AdaptationEngine(),
        BudgetEngine(),
        InsightEngine(),
        CoachEngine(),
        ReminderEngine(),
      ];

      expect(engines.length, equals(11));
    });

    test('Domain layer files must NEVER import Flutter UI packages (Pure Dart)', () {
      final domainDir = Directory('lib/features/supplementary_sports/domain');
      final dartFiles = domainDir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));

      for (final file in dartFiles) {
        final content = file.readAsStringSync();
        expect(
          content.contains("package:flutter/material.dart"),
          isFalse,
          reason: '${file.path} violates Pure Dart domain rule by importing material.dart',
        );
        expect(
          content.contains("package:flutter/widgets.dart"),
          isFalse,
          reason: '${file.path} violates Pure Dart domain rule by importing widgets.dart',
        );
      }
    });

    test('No unified sports code file exceeds 600 lines limit (Rule R-09)', () {
      final sportsDir = Directory('lib/features/supplementary_sports');
      final dartFiles = sportsDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart') && f.path.contains('mv_'));

      for (final file in dartFiles) {
        final lineCount = file.readAsLinesSync().length;
        expect(
          lineCount,
          lessThanOrEqualTo(600),
          reason: '${file.path} has $lineCount lines, exceeding the 600-line architecture limit',
        );
      }
    });
  });
}
