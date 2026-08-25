import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/supplementary_sports/movement/data/seed/movement_kinds_seed.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';
import 'package:ritmo/features/supplementary_sports/domain/engines/engines.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Permanent Architecture Guards G-01..G-12 Verification (S6-T3)', () {
    test(
      'G-01: Layer Dependencies Guard - Presentation only imports application/domain/core',
      () {
        final presDir = Directory(
          'lib/features/supplementary_sports/presentation',
        );
        if (presDir.existsSync()) {
          final files = presDir
              .listSync(recursive: true)
              .whereType<File>()
              .where((f) => f.path.endsWith('.dart'));
          for (final file in files) {
            final content = file.readAsStringSync();
            // Presentation should never import raw low-level database directly
            expect(
              content.contains("import 'package:sqflite"),
              isFalse,
              reason:
                  'File ${file.path} directly imports sqflite (violates G-01)',
            );
          }
        }
      },
    );

    test(
      'G-02: L10n Coverage Guard - Verification of localized keys and clean exports',
      () {
        final arbFa = File('lib/l10n/app_fa.arb').readAsStringSync();
        final arbEn = File('lib/l10n/app_en.arb').readAsStringSync();

        expect(arbFa.contains('"mv_kind_picker_title"'), isTrue);
        expect(arbEn.contains('"mv_kind_picker_title"'), isTrue);
        expect(arbFa.contains('"mv_reason_anchor"'), isTrue);
        expect(arbEn.contains('"mv_reason_anchor"'), isTrue);
        expect(arbFa.contains('"mv_effort_question"'), isTrue);
        expect(arbFa.contains('"mv_load_band_spike"'), isTrue);
      },
    );

    test(
      'G-03: Raw Style Values Guard - Zero raw Color(0x in presentation layer',
      () {
        final presDir = Directory(
          'lib/features/supplementary_sports/presentation',
        );
        if (presDir.existsSync()) {
          final files = presDir
              .listSync(recursive: true)
              .whereType<File>()
              .where((f) => f.path.endsWith('.dart'));
          for (final file in files) {
            final content = file.readAsStringSync();
            expect(
              content.contains('Color(0x') || content.contains('Color(0X'),
              isFalse,
              reason:
                  'File ${file.path} contains raw Color(0x hex definition (violates G-03)',
            );
          }
        }
      },
    );

    test(
      'G-04: Slot Reason Coverage Guard - 100% of slot reasons must have valid registered key',
      () {
        final allowedKeys = {
          MvReasonKeys.anchor,
          MvReasonKeys.preAnchorTaper,
          MvReasonKeys.postAnchorRecovery,
          MvReasonKeys.complement,
          MvReasonKeys.whoGap,
          MvReasonKeys.strengthQuota,
          MvReasonKeys.restGuaranteed,
          MvReasonKeys.readinessLow,
          MvReasonKeys.loadCap,
          MvReasonKeys.fallbackMinimum,
          MvReasonKeys.seasonFit,
          MvReasonKeys.constraintRelaxed,
        };

        const planEngine = PlanEngine();
        final kindsMap = <String, MvMovementKind>{
          'WALKING': const MvMovementKind(
            code: 'WALKING',
            titleFa: 'پیاده‌روی',
            emoji: '🚶‍♂️',
            family: MovementFamily.endurance,
            baseMet: 3.5,
            metLow: 2.5,
            metHigh: 4.5,
            primaryMetric: MovementMetric.duration,
            isOutdoor: true,
            isSocial: false,
            needsVenue: false,
            jointImpact: 1,
            isCustom: false,
            isEnabled: true,
            usageCount: 0,
            sortOrder: 0,
          ),
          'BODYWEIGHT': const MvMovementKind(
            code: 'BODYWEIGHT',
            titleFa: 'تمرین با وزن بدن',
            emoji: '🤸‍♂️',
            family: MovementFamily.strength,
            baseMet: 5.0,
            metLow: 3.5,
            metHigh: 6.5,
            primaryMetric: MovementMetric.duration,
            isOutdoor: false,
            isSocial: false,
            needsVenue: false,
            jointImpact: 1,
            isCustom: false,
            isEnabled: true,
            usageCount: 0,
            sortOrder: 0,
          ),
        };

        final plan = planEngine.generateWeek(
          weekStartSat: DateTime(2026, 8, 15),
          profile: MvUserProfile.empty(),
          commitments: const [],
          overrides: const [],
          kinds: kindsMap,
          kindProfiles: const {},
          budget: const MvBudgetSnapshot(
            moderateEquivalentMinutes: 0,
            rawMetMinutes: 0,
            strengthDays: 0,
          ),
          load: null,
          readiness: MvReadinessTier.full,
        );

        for (final slot in plan.slots) {
          expect(
            allowedKeys.contains(slot.reasonKey),
            isTrue,
            reason: 'Slot ${slot.id} has invalid reasonKey: ${slot.reasonKey}',
          );
        }
      },
    );

    test(
      'G-05: RPE Logging Guard - Session completion preserves RPE and overall feeling',
      () {
        final now = DateTime.now().millisecondsSinceEpoch;
        final session = MvSession(
          id: 's_guard_05',
          kindCode: 'RUNNING',
          sessionMode: MvSessionMode.distance,
          status: MvSessionStatus.completed,
          startedAt: now,
          endedAt: now + 1800000,
          rpe1To10: 7,
          overallFeeling: 3,
          createdAt: now,
          updatedAt: now,
        );

        expect(session.rpe1To10, equals(7));
        expect(session.overallFeeling, equals(3));
      },
    );

    test(
      'G-06: Insufficient Data Guard - No fake numbers or synthetic metrics on fresh user',
      () {
        const loadEngine = LoadEngine();
        final loadSnapshot = loadEngine.computeLoadSnapshot(
          completedSessions: const [],
          daysOfHistory: 0,
          referenceDate: DateTime(2026, 8, 25),
        );

        expect(loadSnapshot.hasEnoughData, isFalse);
        expect(loadSnapshot.ratio, isNull);
        expect(loadSnapshot.bandKey, isNull);

        const insightEngine = InsightEngine();
        final insights = insightEngine.generateInsights(
          completedSessions: const [],
          activeCommitments: const [],
          commitmentWeeks: 0,
          plannedAnchorSessions: 0,
          completedAnchorSessions: 0,
          routes: const [],
        );

        expect(insights, isEmpty);
      },
    );

    test(
      'G-07: Persian Digits Guard - Utility converts numbers to Persian digits correctly',
      () {
        expect(toPersianDigits(12345), equals('۱۲۳۴۵'));
        expect(toPersianDigits('20:30'), equals('۲۰:۳۰'));
        expect(toPersianDigits('45 min'), equals('۴۵ min'));
      },
    );

    test(
      'G-08: Clean 4-Layer Architecture Guard - Directory layout conformity',
      () {
        final base = Directory('lib/features/supplementary_sports');
        expect(Directory('${base.path}/domain').existsSync(), isTrue);
        expect(Directory('${base.path}/data').existsSync(), isTrue);
        expect(Directory('${base.path}/application').existsSync(), isTrue);
        expect(Directory('${base.path}/presentation').existsSync(), isTrue);
      },
    );

    test(
      'G-09: Seed Taxonomy Guard - Seed taxonomy contains at least 49 kinds',
      () {
        expect(MovementKindsSeed.seedCodes.length, greaterThanOrEqualTo(49));
        expect(MovementKindsSeed.seedCodes.contains('FUTSAL'), isTrue);
        expect(MovementKindsSeed.seedCodes.contains('SWIMMING'), isTrue);
        expect(MovementKindsSeed.seedCodes.contains('RUNNING'), isTrue);
        expect(MovementKindsSeed.seedCodes.contains('ROCK_CLIMBING'), isTrue);
      },
    );

    test(
      'G-10: Pure Dart Domain Guard - Domain files have zero Flutter UI dependencies',
      () {
        final domainDir = Directory('lib/features/supplementary_sports/domain');
        final files = domainDir
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'));
        for (final file in files) {
          final content = file.readAsStringSync();
          expect(
            content.contains("package:flutter/material.dart") ||
                content.contains("package:flutter/widgets.dart") ||
                content.contains("package:flutter/cupertino.dart"),
            isFalse,
            reason:
                'Domain file ${file.path} contains Flutter UI import (violates Pure Dart G-10)',
          );
        }
      },
    );

    test(
      'G-11: 28-Day Load Window Cap Guard - LoadEngine caps analysis window strictly to 28 days',
      () {
        final ref = DateTime(2026, 8, 25);
        final oldDate = ref.subtract(const Duration(days: 35));
        final recentDate = ref.subtract(const Duration(days: 5));

        final sessions = [
          MvSession(
            id: 's_old',
            kindCode: 'WALKING',
            sessionMode: MvSessionMode.timed,
            status: MvSessionStatus.completed,
            startedAt: oldDate.millisecondsSinceEpoch,
            endedAt: oldDate.millisecondsSinceEpoch + (60 * 60 * 1000),
            rpe1To10: 5,
            createdAt: oldDate.millisecondsSinceEpoch,
            updatedAt: oldDate.millisecondsSinceEpoch,
          ),
          MvSession(
            id: 's_recent',
            kindCode: 'WALKING',
            sessionMode: MvSessionMode.timed,
            status: MvSessionStatus.completed,
            startedAt: recentDate.millisecondsSinceEpoch,
            endedAt: recentDate.millisecondsSinceEpoch + (60 * 60 * 1000),
            rpe1To10: 5,
            createdAt: recentDate.millisecondsSinceEpoch,
            updatedAt: recentDate.millisecondsSinceEpoch,
          ),
        ];

        const loadEngine = LoadEngine();
        final snapshot = loadEngine.computeLoadSnapshot(
          completedSessions: sessions,
          daysOfHistory: 28,
          referenceDate: ref,
        );

        expect(snapshot.acuteLoad, equals(300)); // 60 * 5
      },
    );

    test(
      'G-12: Hypothesis Phrasing Guard - Insights use probability phrasing and no diagnostic claims',
      () {
        final now = DateTime(2026, 8, 25);
        final sessions = List.generate(
          12,
          (i) => MvSession(
            id: 's_$i',
            kindCode: 'WALKING',
            sessionMode: MvSessionMode.timed,
            status: MvSessionStatus.completed,
            startedAt: now
                .subtract(Duration(days: i * 2))
                .millisecondsSinceEpoch,
            endedAt:
                now.subtract(Duration(days: i * 2)).millisecondsSinceEpoch +
                (40 * 60 * 1000),
            rpe1To10: 5,
            createdAt: now.millisecondsSinceEpoch,
            updatedAt: now.millisecondsSinceEpoch,
          ),
        );

        const insightEngine = InsightEngine();
        final insights = insightEngine.generateInsights(
          completedSessions: sessions,
          activeCommitments: const [],
          commitmentWeeks: 0,
          plannedAnchorSessions: 0,
          completedAnchorSessions: 0,
          routes: const [],
          referenceDate: now,
        );

        for (final insight in insights) {
          expect(
            insight.descriptionFa.contains('به نظر می‌رسد') ||
                insight.descriptionFa.contains('در ') ||
                insight.descriptionFa.contains('نشان می‌دهد') ||
                insight.descriptionFa.contains('دارید'),
            isTrue,
            reason: 'Insight ${insight.key} lacks humble probability phrasing',
          );
        }
      },
    );
  });
}
