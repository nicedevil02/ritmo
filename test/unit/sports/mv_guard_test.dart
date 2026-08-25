import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/features/supplementary_sports/movement/data/seed/movement_kinds_seed.dart';
import 'package:ritmo/features/supplementary_sports/supplementary_sports.dart';

void main() {
  group('Phase P7 Architecture & Guard Tests (ADR 0008)', () {
    test('All 13 Domain Engines are properly constructed and accessible', () {
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
        LoadEngine(),
        CampaignEngine(),
      ];

      expect(engines.length, equals(13));
    });

    test(
      'Domain layer files must NEVER import Flutter UI packages (Pure Dart)',
      () {
        final domainDir = Directory('lib/features/supplementary_sports/domain');
        final dartFiles = domainDir
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'));

        for (final file in dartFiles) {
          final content = file.readAsStringSync();
          expect(
            content.contains("package:flutter/material.dart"),
            isFalse,
            reason:
                '${file.path} violates Pure Dart domain rule by importing material.dart',
          );
          expect(
            content.contains("package:flutter/widgets.dart"),
            isFalse,
            reason:
                '${file.path} violates Pure Dart domain rule by importing widgets.dart',
          );
        }
      },
    );

    test(
      'Presentation layer files must NEVER import data repositories directly (Rule C-04)',
      () {
        final presDir = Directory(
          'lib/features/supplementary_sports/presentation',
        );
        final dartFiles = presDir
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart') && f.path.contains('mv_'));

        for (final file in dartFiles) {
          final content = file.readAsStringSync();
          expect(
            content.contains(
              "package:ritmo/features/supplementary_sports/data/",
            ),
            isFalse,
            reason:
                '${file.path} violates Clean Architecture rule C-04 by directly importing data layer',
          );
        }
      },
    );

    test('Guard S1-T9.1: All literal kindCode references must exist in seed (or CUSTOM_*)', () {
      const seedCodes = MovementKindsSeed.seedCodes;
      final sportsDir = Directory('lib/features/supplementary_sports');
      final dartFiles = sportsDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));

      final kindCodeRegex = RegExp(r"kindCode\s*(?::|==)\s*['" '"' r"]([A-Z0-9_]+)['" '"' r"]");

      for (final file in dartFiles) {
        final content = file.readAsStringSync();
        for (final match in kindCodeRegex.allMatches(content)) {
          final code = match.group(1)!;
          if (code.startsWith('CUSTOM_')) continue;

          expect(
            seedCodes.contains(code),
            isTrue,
            reason: '${file.path} references unseeded kindCode "$code"',
          );
        }
      }
    });

    test('Guard S1-T9.2: Presentation files must not contain raw sport kind code literals', () {
      const seedCodes = MovementKindsSeed.seedCodes;
      final presDir = Directory('lib/features/supplementary_sports/presentation');
      final dartFiles = presDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart') && f.path.contains('mv_'));

      // Whitelisted non-kind tokens in presentation
      const allowedPresentationTokens = {
        'ALL', 'REST', 'STRENGTH', 'CARDIO', 'SPORT', 'OUTDOOR', 'ENDURANCE',
        'MIND_BODY', 'MARTIAL_SKILL', 'DAILY',
        'DURATION_ONLY', 'DISTANCE_M', 'REPS', 'ROUNDS_TIME',
        'LOW', 'MEDIUM', 'HIGH', 'LIGHT', 'MODERATE', 'HARD',
        'CHEST', 'BACK', 'LEGS', 'SHOULDERS', 'ARMS', 'CORE', 'FULL_BODY',
        'FEMALE', 'WOMAN', 'ZAN', 'MALE', 'MAN', 'NONE',
      };

      final uppercaseLiteralRegex = RegExp(r"'([A-Z][A-Z0-9_]{2,})'");

      for (final file in dartFiles) {
        // Exclude sheet pickers/custom kinds if they have localized seed references
        if (file.path.contains('mv_quick_log_sheet.dart')) continue;

        final content = file.readAsStringSync();
        for (final match in uppercaseLiteralRegex.allMatches(content)) {
          final token = match.group(1)!;
          if (allowedPresentationTokens.contains(token)) continue;
          if (token.startsWith('CUSTOM_')) continue;

          expect(
            seedCodes.contains(token),
            isFalse,
            reason: '${file.path} contains raw kindCode literal "$token" instead of using repository/model',
          );
        }
      }
    });
  });
}
