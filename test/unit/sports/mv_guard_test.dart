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

    test('Presentation layer files must NEVER import data repositories directly (Rule C-04)', () {
      final presDir = Directory('lib/features/supplementary_sports/presentation');
      final dartFiles = presDir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart') && f.path.contains('mv_'));

      for (final file in dartFiles) {
        final content = file.readAsStringSync();
        expect(
          content.contains("package:ritmo/features/supplementary_sports/data/"),
          isFalse,
          reason: '${file.path} violates Clean Architecture rule C-04 by directly importing data layer',
        );
      }
    });
  });
}
