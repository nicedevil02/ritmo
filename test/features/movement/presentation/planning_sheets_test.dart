import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/movement/domain/models/movement_activity_kind.dart';
import 'package:ritmo/features/movement/domain/models/movement_change_scope.dart';
import 'package:ritmo/features/movement/domain/models/movement_occurrence.dart';
import 'package:ritmo/features/movement/domain/models/movement_workout_log.dart';
import 'package:ritmo/features/movement/presentation/activity_picker/sheets/retro_log_form_sheet.dart';
import 'package:ritmo/features/movement/presentation/center/sheets/add_command_sheet.dart';
import 'package:ritmo/features/movement/presentation/center/sheets/move_session_sheet.dart';
import 'package:ritmo/features/movement/presentation/center/sheets/plan_b_sheet.dart';
import 'package:ritmo/features/movement/presentation/center/sheets/quick_complete_sheet.dart';
import 'package:ritmo/features/movement/presentation/center/sheets/skip_session_sheet.dart';
import 'package:ritmo/features/movement/presentation/center/sheets/smart_fill_sheet.dart';
import 'package:ritmo/features/movement/presentation/center/sheets/week_reshuffle_sheet.dart';
import 'package:ritmo/features/movement/presentation/common/movement_strings.dart';
import 'package:ritmo/features/movement/presentation/common/reason_chip.dart';
import 'package:ritmo/features/movement/presentation/planner/sheets/scope_picker_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final sampleKind = MovementActivityKind(
    id: 'kind_running',
    nameFa: 'دویدن',
    family: 'running',
    icon: 'directions_run',
    primaryMetric: 'duration',
    createdAt: DateTime.now(),
  );

  final sampleOccurrence = MovementOccurrence(
    id: 'occ_sheet_test',
    activityKindId: 'kind_running',
    activityKind: sampleKind,
    dateIso: '2026-08-16',
    startTime: '07:30',
    status: MovementOccurrenceStatus.planned,
    goalType: 'duration',
    goalValue: 30.0,
    goalUnit: 'دقیقه',
    origin: MovementOrigin.template,
    templateId: 'tmpl_1',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  Widget buildTestableWidget(Widget child) {
    return MaterialApp(
      theme: RitmoTheme.build(
        palette: RitmoPalette.jadeNoir,
        brightness: Brightness.dark,
      ),
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(body: child),
      ),
    );
  }

  group('8 Planning Sheets Tests (Step 6)', () {
    testWidgets(
      '1. AddCommandSheet renders 3 main choices and handles action taps',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        bool startNowTapped = false;

        await tester.pumpWidget(
          buildTestableWidget(
            AddCommandSheet(
              onStartNow: () => startNowTapped = true,
              onAddToPlan: () {},
              onRetroLog: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text(MovementStrings.addQuestion), findsOneWidget);
        expect(find.text(MovementStrings.addStartNow), findsOneWidget);
        expect(find.text(MovementStrings.addToPlan), findsOneWidget);
        expect(find.text(MovementStrings.addRetroLog), findsOneWidget);

        await tester.tap(find.text(MovementStrings.addStartNow));
        await tester.pumpAndSettle();

        expect(startNowTapped, isTrue);
      },
    );

    testWidgets(
      '2. ScopePickerSheet renders 3 scopes and returns selected scope',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        MovementChangeScope? chosenScope;

        await tester.pumpWidget(
          buildTestableWidget(
            ScopePickerSheet(
              initialScope: MovementChangeScope.onlyThis,
              onScopeSelected: (s) => chosenScope = s,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text(MovementStrings.scopeTitle), findsOneWidget);
        expect(find.text(MovementStrings.scopeOnlyThis), findsOneWidget);
        expect(find.text(MovementStrings.scopeThisAndFuture), findsOneWidget);
        expect(find.text(MovementStrings.scopeWholePlan), findsOneWidget);

        // Select thisAndFuture
        await tester.tap(find.text(MovementStrings.scopeThisAndFuture));
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text(MovementStrings.commonConfirm));
        await tester.tap(find.text(MovementStrings.commonConfirm));
        await tester.pumpAndSettle();

        expect(chosenScope, equals(MovementChangeScope.thisAndFuture));
      },
    );

    testWidgets(
      '3. MoveSessionSheet renders 7-day rail, time picker and confirm button',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        bool confirmCalled = false;

        await tester.pumpWidget(
          buildTestableWidget(
            MoveSessionSheet(
              occurrence: sampleOccurrence,
              onMoveConfirm: (d, t, s) async {
                confirmCalled = true;
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text(MovementStrings.moveSessionTitle), findsOneWidget);
        expect(find.text(MovementStrings.moveSelectDay), findsOneWidget);
        expect(find.text(MovementStrings.moveSelectTime), findsOneWidget);

        await tester.ensureVisible(find.text(MovementStrings.commonConfirm));
        await tester.tap(find.text(MovementStrings.commonConfirm));
        await tester.pumpAndSettle();

        expect(confirmCalled, isTrue);
      },
    );

    testWidgets(
      '4. SkipSessionSheet renders 4 supportive choices with zero guilt wording',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        SkipActionChoice? selectedChoice;

        await tester.pumpWidget(
          buildTestableWidget(
            SkipSessionSheet(onChoiceSelected: (c) => selectedChoice = c),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text(MovementStrings.skipTitle), findsOneWidget);
        expect(find.text(MovementStrings.skipOptionTodayOnly), findsOneWidget);
        expect(find.text(MovementStrings.skipOptionMove), findsOneWidget);
        expect(
          find.text(MovementStrings.skipOptionShortVersion),
          findsOneWidget,
        );
        expect(
          find.text(MovementStrings.skipOptionEditTemplate),
          findsOneWidget,
        );

        await tester.tap(find.text(MovementStrings.skipOptionTodayOnly));
        await tester.pumpAndSettle();

        expect(selectedChoice, equals(SkipActionChoice.skipTodayOnly));
      },
    );

    testWidgets(
      '5. QuickCompleteSheet records duration and feeling without live workout session',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        int? completedDuration;

        await tester.pumpWidget(
          buildTestableWidget(
            QuickCompleteSheet(
              occurrence: sampleOccurrence,
              onQuickComplete: (dur, metric, feel, note) async {
                completedDuration = dur;
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text(MovementStrings.quickCompleteTitle), findsOneWidget);
        expect(find.text('خوب'), findsOneWidget);

        await tester.ensureVisible(
          find.text(MovementStrings.quickCompleteButton),
        );
        await tester.tap(find.text(MovementStrings.quickCompleteButton));
        await tester.pumpAndSettle();

        expect(completedDuration, equals(1800)); // 30 mins = 1800 sec
      },
    );

    testWidgets(
      '6. PlanBSheet displays Short/Min dose/Move/Recovery with kept and dropped breakdown',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        PlanBOption? chosenOption;

        await tester.pumpWidget(
          buildTestableWidget(
            PlanBSheet(
              occurrence: sampleOccurrence,
              onApplyPlanB: (opt, val) async {
                chosenOption = opt;
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text(MovementStrings.planBTitle), findsOneWidget);
        expect(find.text(MovementStrings.planBShort), findsOneWidget);
        expect(find.text(MovementStrings.planBMinDose), findsOneWidget);
        expect(find.text(MovementStrings.planBFull), findsOneWidget);
        expect(find.textContaining(MovementStrings.planBKept), findsOneWidget);
        expect(
          find.textContaining(MovementStrings.planBDropped),
          findsOneWidget,
        );

        // Tap apply button
        final applyBtn = find.byType(ElevatedButton);
        await tester.ensureVisible(applyBtn);
        await tester.tap(applyBtn);
        await tester.pumpAndSettle();

        expect(chosenOption, isNotNull);
      },
    );

    testWidgets(
      '7. SmartFillSheet 2-step flow generates suggestions with reason chips',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          buildTestableWidget(
            SmartFillSheet(
              availableKinds: [sampleKind],
              onApplySuggestions: (sugs) async {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text(MovementStrings.smartFillTitle), findsOneWidget);
        expect(find.textContaining('تعداد روزهای تمرین'), findsOneWidget);

        // Tap generate suggestions button to move to Step 2
        final genBtn = find.widgetWithText(
          ElevatedButton,
          'تولید پیشنهاد هوشمند',
        );
        await tester.ensureVisible(genBtn);
        await tester.tap(genBtn);
        await tester.pumpAndSettle();

        expect(
          find.text(MovementStrings.smartFillApplySelected),
          findsOneWidget,
        );
        expect(find.byType(ReasonChip), findsWidgets);
      },
    );

    testWidgets(
      '8. WeekReshuffleSheet renders DiffList before/after and bulk apply buttons',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        bool applyChangesTapped = false;

        final changes = [
          WeekReshuffleChangeItem(
            occurrence: sampleOccurrence,
            originalDateIso: '2026-08-15',
            proposedDateIso: '2026-08-16',
            originalTime: '07:00',
            proposedTime: '18:00',
            reason: 'تداخل با کار',
          ),
        ];

        await tester.pumpWidget(
          buildTestableWidget(
            WeekReshuffleSheet(
              changes: changes,
              onApplyChanges: (selected) async {
                applyChangesTapped = true;
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text(MovementStrings.weekReshuffleTitle), findsOneWidget);
        expect(
          find.text(MovementStrings.weekReshuffleApplyAll),
          findsOneWidget,
        );

        await tester.ensureVisible(
          find.text(MovementStrings.weekReshuffleApplyAll),
        );
        await tester.tap(find.text(MovementStrings.weekReshuffleApplyAll));
        await tester.pumpAndSettle();

        expect(applyChangesTapped, isTrue);
      },
    );

    testWidgets(
      'RetroLogFormSheet renders date, duration, feeling and submits log',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        bool submitted = false;

        await tester.pumpWidget(
          buildTestableWidget(
            RetroLogFormSheet(
              activityKind: sampleKind,
              onSubmit:
                  ({
                    required dateIso,
                    startTime,
                    required durationSec,
                    metrics,
                    feeling,
                    note,
                    matchedOccurrenceId,
                  }) async {
                    submitted = true;
                    return MovementWorkoutLog(
                      id: 'log_new',
                      activityKindId: sampleKind.id,
                      dateIso: dateIso,
                      durationSec: durationSec,
                      source: 'retro',
                      createdAt: DateTime.now(),
                      updatedAt: DateTime.now(),
                    );
                  },
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.textContaining(MovementStrings.retroLogTitle),
          findsOneWidget,
        );
        expect(find.byIcon(Icons.calendar_today_rounded), findsOneWidget);
        expect(
          find.textContaining(MovementStrings.retroLogDuration),
          findsOneWidget,
        );
        expect(find.text(MovementStrings.retroLogFeeling), findsOneWidget);

        final submitBtn = find.widgetWithText(
          ElevatedButton,
          MovementStrings.retroLogSubmit,
        );
        await tester.ensureVisible(submitBtn);
        await tester.tap(submitBtn);
        await tester.pumpAndSettle();

        expect(submitted, isTrue);
      },
    );
  });
}
