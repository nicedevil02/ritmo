import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/domain/models.dart';
import 'package:ritmo/features/energy/presentation/widgets/quick_log_sheet.dart';
import 'package:ritmo/features/routines/presentation/widgets/planner_category_grid.dart';
import 'package:ritmo/features/routines/presentation/planner_controller.dart';
import 'package:ritmo/features/routines/shared/widgets/routine_niyyah_sheet.dart';
import 'package:ritmo/features/settings/presentation/widgets/quick_settings_sheet.dart';
import 'package:ritmo/features/worship/presentation/widgets/worship_solar_calendar.dart';
import 'package:shamsi_date/shamsi_date.dart';
import '../support/responsive_harness.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  group('R-44: Responsive Golden Matrix - All critical components across 4 viewports x 3 text scales', () {
    // 1. PlannerCategoryGrid
    testAcrossViewports('PlannerCategoryGrid with worst-case Persian labels', () {
      final controller = PlannerController(
        onSaved: () {},
        onPageChanged: (_) {},
      );
      return Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: PlannerCategoryGrid(controller: controller),
        ),
      );
    });

    // 2. QuickLogSheet
    testAcrossViewports('QuickLogSheet mood and energy selectors', () {
      return Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: QuickLogSheet(onSaved: () {}),
        ),
      );
    });

    // 3. QuickSettingsSheet
    testAcrossViewports('QuickSettingsSheet adaptive grid items', () {
      return const Scaffold(
        body: SingleChildScrollView(
          child: QuickSettingsSheet(),
        ),
      );
    });

    // 4. WorshipSolarCalendar
    testAcrossViewports('WorshipSolarCalendar in full month view', () {
      return Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: WorshipSolarCalendar(
            initialJalali: Jalali(1403, 5, 1),
          ),
        ),
      );
    });

    // 5. RoutineNiyyahSheet
    testAcrossViewports('RoutineNiyyahSheet with Persian text', () {
      final routine = Routine(
        id: 'r_matrix_test',
        title: kWorstCaseFa.longLabel,
        category: Category.work,
        routineType: RoutineType.timeBased,
        notificationLevel: NotificationLevel.normal,
        targetDurationMinutes: 45,
        energyRule: EnergyRule.none,
        isEssential: false,
      );

      return Scaffold(
        body: SingleChildScrollView(
          child: RoutineNiyyahSheet(routine: routine),
        ),
      );
    });
  });
}

