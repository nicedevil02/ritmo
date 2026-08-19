import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/movement/application/strength_program_service.dart';
import 'package:ritmo/features/movement/domain/models/movement_strength_day.dart';
import 'package:ritmo/features/movement/domain/models/movement_strength_program.dart';
import 'package:ritmo/features/movement/presentation/common/diff_list.dart';
import 'package:ritmo/features/movement/presentation/common/movement_strings.dart';
import 'package:ritmo/features/movement/presentation/strength/sheets/program_manage_sheet.dart';
import 'package:ritmo/features/movement/presentation/strength/strength_hub_screen.dart';
import 'package:ritmo/features/movement/presentation/strength/widgets/program_header.dart';
import 'package:ritmo/features/movement/presentation/strength/widgets/program_session_tile.dart';
import 'package:ritmo/features/movement/presentation/strength/widgets/program_week_strip.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildTestableWidget(Widget child) {
    return MaterialApp(
      theme: RitmoTheme.build(
        palette: RitmoPalette.jadeNoir,
        brightness: Brightness.dark,
      ),
      home: Directionality(textDirection: TextDirection.rtl, child: child),
    );
  }

  group('StrengthHubScreen & ManageSheet Widget Tests (Gate 4)', () {
    testWidgets(
      '1. Inactive state renders benefits, FAQs and Create Plan CTA',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          buildTestableWidget(const StrengthHubScreen(initialProgram: null)),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text(MovementStrings.strengthHubTitle), findsWidgets);
        expect(
          find.text(MovementStrings.strengthHubCreatePlan),
          findsOneWidget,
        );
        expect(find.textContaining('آیا بدون دمبل'), findsOneWidget);
      },
    );

    testWidgets(
      '2. Active program renders Header, WeekStrip and SessionTiles',
      (tester) async {
        final service = StrengthProgramService();
        final planMap = service.generateProgramPlan(
          goal: 'muscle',
          level: 'intermediate',
          sensitiveAreas: [],
          equipment: ['bodyweight'],
          daysPerWeek: 3,
          sessionMinutes: 30,
          preferredDays: [1, 3, 5],
        );

        final program = (planMap['program'] as MovementStrengthProgram)
            .copyWith(status: MovementStrengthProgramStatus.active);
        final days = planMap['days'] as List<MovementStrengthDay>;

        await tester.pumpWidget(
          buildTestableWidget(
            StrengthHubScreen(initialProgram: program, initialDays: days),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byType(ProgramHeader), findsOneWidget);
        expect(find.byType(ProgramWeekStrip), findsOneWidget);
        expect(find.byType(ProgramSessionTile), findsWidgets);
        expect(find.text('جلسهٔ بعدی:'), findsOneWidget);
      },
    );

    testWidgets('3. ProgramManageSheet shows DiffList when settings change', (
      tester,
    ) async {
      final program = MovementStrengthProgram(
        id: 'p_manage_1',
        name: 'برنامهٔ من',
        daysPerWeek: 3,
        sessionMinutes: 30,
        status: MovementStrengthProgramStatus.active,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: RitmoTheme.build(
            palette: RitmoPalette.jadeNoir,
            brightness: Brightness.dark,
          ),
          home: Scaffold(
            body: Directionality(
              textDirection: TextDirection.rtl,
              child: Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () {
                    ProgramManageSheet.show(
                      ctx,
                      program: program,
                      onPauseToggle: () {},
                      onFinishProgram: () {},
                      onStartNewCycle: () {},
                      onUpdateSettings:
                          ({required newDays, required newDuration}) async {},
                    );
                  },
                  child: const Text('Open Sheet'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Open Sheet'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text(MovementStrings.strengthManageTitle), findsOneWidget);
      expect(
        find.text(MovementStrings.strengthManageNoDeleteNotice),
        findsOneWidget,
      );

      // Change days from 3 to 4
      await tester.tap(find.text('4 روز'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('مشاهدهٔ پیش‌نمایش تغییرات'), findsOneWidget);
      await tester.tap(find.text('مشاهدهٔ پیش‌نمایش تغییرات'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // DiffList is displayed
      expect(find.byType(DiffList), findsOneWidget);
      expect(find.text('تأیید و اعمال تغییرات'), findsOneWidget);
    });
  });
}
