import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/theme/palettes/jade_noir.dart';
import 'package:ritmo/features/cycle/logic/cycle_clock.dart';
import 'package:ritmo/features/cycle/logic/cycle_date_contract.dart';
import 'package:ritmo/features/cycle/logic/pregnancy_engine.dart';
import 'package:ritmo/features/cycle/models/pregnancy_models.dart';
import 'package:ritmo/features/cycle/presentation/onboarding/pregnancy_steps/preg_step_2_dates.dart';
import 'package:ritmo/l10n/app_localizations.dart';

Widget _buildTestWidget({
  required PregnancyOnboardingData data,
  required ValueChanged<PregnancyOnboardingData> onDataChanged,
  VoidCallback? onNext,
}) {
  return MaterialApp(
    theme: ThemeData.light().copyWith(extensions: [kJadeNoirLight]),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('fa'),
    home: Scaffold(
      body: PregStep2Dates(
        data: data,
        onDataChanged: onDataChanged,
        onNext: onNext ?? () {},
        colors: kJadeNoirLight,
        isDark: false,
      ),
    ),
  );
}

void main() {
  group('PregStep2Dates Tests (PRG-19)', () {
    testWidgets('renders all 3 method cards and default LMP section', (
      tester,
    ) async {
      final now = CycleClock.now;
      final lmp = CycleDateContract.cleanDate(
        now.subtract(const Duration(days: 56)),
      );
      final due = PregnancyDateEngine.dueDateFromLmp(lmp);

      final data = PregnancyOnboardingData(
        eddSource: PregnancyEddSource.lmp,
        lmpDate: lmp,
        dueDate: due,
      );

      await tester.pumpWidget(
        _buildTestWidget(data: data, onDataChanged: (_) {}),
      );
      await tester.pumpAndSettle();

      expect(find.text('مبنای محاسبهٔ تاریخ'), findsOneWidget);
      expect(find.text('اولین روز آخرین پریودم را می‌دانم'), findsOneWidget);
      expect(find.text('تاریخ زایمان را پزشک گفته'), findsOneWidget);
      expect(find.text('جواب سونوگرافی دارم'), findsOneWidget);

      // LMP date picker section visible
      expect(find.text('تاریخ شروع آخرین قاعدگی (LMP):'), findsOneWidget);

      // Live feedback banner visible
      expect(find.textContaining('یعنی الان'), findsOneWidget);
    });

    testWidgets(
      'switching to Doctor EDD changes eddSource and displays EDD section',
      (tester) async {
        final now = CycleClock.now;
        final lmp = CycleDateContract.cleanDate(
          now.subtract(const Duration(days: 56)),
        );
        final due = PregnancyDateEngine.dueDateFromLmp(lmp);

        PregnancyOnboardingData currentData = PregnancyOnboardingData(
          eddSource: PregnancyEddSource.lmp,
          lmpDate: lmp,
          dueDate: due,
        );

        await tester.pumpWidget(
          StatefulBuilder(
            builder: (context, setState) {
              return _buildTestWidget(
                data: currentData,
                onDataChanged: (updated) {
                  setState(() {
                    currentData = updated;
                  });
                },
              );
            },
          ),
        );
        await tester.pumpAndSettle();

        // Tap Doctor EDD
        await tester.tap(find.text('تاریخ زایمان را پزشک گفته'));
        await tester.pumpAndSettle();

        expect(currentData.eddSource, PregnancyEddSource.doctorEdd);
        expect(find.text('تاریخ تخمینی زایمان (EDD):'), findsOneWidget);
      },
    );

    testWidgets(
      'switching to Ultrasound displays scan date and counters, recalculates dates',
      (tester) async {
        final now = CycleClock.now;
        final lmp = CycleDateContract.cleanDate(
          now.subtract(const Duration(days: 56)),
        );
        final due = PregnancyDateEngine.dueDateFromLmp(lmp);

        PregnancyOnboardingData currentData = PregnancyOnboardingData(
          eddSource: PregnancyEddSource.lmp,
          lmpDate: lmp,
          dueDate: due,
        );

        await tester.pumpWidget(
          StatefulBuilder(
            builder: (context, setState) {
              return _buildTestWidget(
                data: currentData,
                onDataChanged: (updated) {
                  setState(() {
                    currentData = updated;
                  });
                },
              );
            },
          ),
        );
        await tester.pumpAndSettle();

        // Tap Ultrasound
        await tester.tap(find.text('جواب سونوگرافی دارم'));
        await tester.pumpAndSettle();

        expect(currentData.eddSource, PregnancyEddSource.ultrasound);
        expect(find.text('تاریخ انجام سونوگرافی:'), findsOneWidget);
        expect(find.text('سن جنین در تاریخ سونوگرافی:'), findsOneWidget);
        expect(find.text('هفته'), findsOneWidget);
        expect(find.text('روز'), findsOneWidget);
      },
    );

    testWidgets('shows error banner when dates are invalid (future LMP)', (
      tester,
    ) async {
      final now = CycleClock.now;
      final futureLmp = CycleDateContract.cleanDate(
        now.add(const Duration(days: 10)),
      );
      final futureDue = PregnancyDateEngine.dueDateFromLmp(futureLmp);

      final data = PregnancyOnboardingData(
        eddSource: PregnancyEddSource.lmp,
        lmpDate: futureLmp,
        dueDate: futureDue,
      );

      await tester.pumpWidget(
        _buildTestWidget(data: data, onDataChanged: (_) {}),
      );
      await tester.pumpAndSettle();

      expect(find.text('تاریخ شروع نمی‌تواند در آینده باشد.'), findsOneWidget);
    });
  });
}
