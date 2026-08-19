import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/movement/application/movement_progress_service.dart';
import 'package:ritmo/features/movement/domain/models/movement_personal_record.dart';
import 'package:ritmo/features/movement/presentation/progress/movement_progress_screen.dart';
import 'package:ritmo/features/movement/presentation/progress/widgets/distribution_card.dart';
import 'package:ritmo/features/movement/presentation/progress/widgets/kpi_grid.dart';
import 'package:ritmo/features/movement/presentation/progress/widgets/pr_list.dart';
import 'package:ritmo/features/movement/presentation/progress/widgets/range_filter_bar.dart';
import 'package:ritmo/features/movement/presentation/progress/widgets/status_breakdown_card.dart';

class FakeMovementProgressService extends MovementProgressService {
  @override
  Future<MovementKpiData> getKpiData({
    required MovementProgressRange range,
    DateTime? now,
  }) async {
    return const MovementKpiData(
      sessionCount: 5,
      activeMinutes: 150,
      activeDaysCount: 4,
      adherenceRate: 0.8,
      totalStrengthVolumeKg: 1200,
      totalDistanceKm: 12.5,
    );
  }

  @override
  Future<MovementTrendData> getTrendData({
    required MovementProgressRange range,
    DateTime? now,
  }) async {
    return const MovementTrendData(
      points: [
        MovementTrendPoint(
          label: 'هفته ۱',
          sessionCount: 2,
          activeMinutes: 60,
          volumeKg: 500,
        ),
        MovementTrendPoint(
          label: 'هفته ۲',
          sessionCount: 3,
          activeMinutes: 90,
          volumeKg: 700,
        ),
        MovementTrendPoint(
          label: 'هفته ۳',
          sessionCount: 4,
          activeMinutes: 120,
          volumeKg: 900,
        ),
      ],
      interpretationSentence:
          'روند صعودی و پیوستگی مطلوب در تمرینات ثبت شده است.',
      hasEnoughData: true,
    );
  }

  @override
  Future<List<MovementDistributionItem>> getDistributionData() async {
    return const [
      MovementDistributionItem(
        family: 'running',
        nameFa: 'دویدن در فضای باز',
        count: 3,
        percentage: 60,
      ),
      MovementDistributionItem(
        family: 'walking',
        nameFa: 'پیاده‌روی روزانه',
        count: 2,
        percentage: 40,
      ),
    ];
  }

  @override
  Future<List<MovementMuscleWorkloadItem>> getMuscleWorkload() async {
    return const [
      MovementMuscleWorkloadItem(
        muscleGroup: 'پا و باسن',
        setsCount: 8,
        percentage: 50,
      ),
      MovementMuscleWorkloadItem(
        muscleGroup: 'سینه',
        setsCount: 8,
        percentage: 50,
      ),
    ];
  }

  @override
  Future<MovementStrengthProgressData?> getStrengthProgressData() async {
    return const MovementStrengthProgressData(
      weeklyVolumes: [500, 700, 900],
      compoundLifts: {
        'اسکوات': [60, 65, 70],
      },
      completionRate: 0.9,
      isDeloadActive: false,
    );
  }

  @override
  Future<MovementStatusBreakdownData> getStatusBreakdown() async {
    return const MovementStatusBreakdownData(
      completedCount: 4,
      partialCount: 1,
      skippedCount: 0,
      movedCount: 1,
    );
  }

  @override
  Future<List<MovementPersonalRecord>> getPersonalRecords() async {
    return [
      MovementPersonalRecord(
        id: 'pr_1',
        activityKindId: 'kind_running',
        recordType: 'max_distance',
        value: 5.0,
        unit: 'کیلومتر',
        achievedAt: DateTime(2026, 8, 16),
        exerciseOrActivityNameFa: 'رکورد دویدن',
      ),
    ];
  }
}

void main() {
  Widget createTestWidget(Widget child) {
    return MaterialApp(
      theme: RitmoTheme.build(
        palette: RitmoPalette.jadeNoir,
        brightness: Brightness.dark,
      ),
      home: Directionality(textDirection: TextDirection.rtl, child: child),
    );
  }

  group('MovementProgressScreen & Progress Widgets Tests (Gate 5)', () {
    testWidgets('Renders full progress screen with 8 zones and real data', (
      tester,
    ) async {
      await tester.pumpWidget(
        createTestWidget(
          MovementProgressScreen(
            progressService: FakeMovementProgressService(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check header and blocks
      expect(find.text('پیشرفت و تحلیل حرکت'), findsOneWidget);
      expect(find.byType(RangeFilterBar), findsOneWidget);
      expect(find.byType(KpiGrid), findsOneWidget);
      expect(find.byType(DistributionCard), findsOneWidget);
      expect(find.byType(PrList), findsOneWidget);
      expect(find.byType(StatusBreakdownCard), findsOneWidget);

      // Verify PR item
      expect(find.text('رکورد دویدن'), findsOneWidget);
      expect(find.text('۵ کیلومتر'), findsOneWidget);
    });
  });
}
