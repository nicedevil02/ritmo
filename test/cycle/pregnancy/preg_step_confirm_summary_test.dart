import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/theme/palettes/jade_noir.dart';
import 'package:ritmo/features/cycle/logic/cycle_clock.dart';
import 'package:ritmo/features/cycle/logic/cycle_date_contract.dart';
import 'package:ritmo/features/cycle/logic/pregnancy_engine.dart';
import 'package:ritmo/features/cycle/models/pregnancy_models.dart';
import 'package:ritmo/features/cycle/presentation/onboarding/pregnancy_steps/preg_step_5_confirm.dart';
import 'package:ritmo/l10n/app_localizations.dart';

Widget _buildTestWidget({
  required PregnancyOnboardingData data,
  required VoidCallback onSave,
  required VoidCallback onBack,
  bool isSaving = false,
  bool isEditMode = false,
}) {
  return MaterialApp(
    theme: ThemeData.light().copyWith(extensions: [kJadeNoirLight]),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('fa'),
    home: Scaffold(
      body: PregStep5Confirm(
        data: data,
        onSave: onSave,
        onBack: onBack,
        isSaving: isSaving,
        isEditMode: isEditMode,
        colors: kJadeNoirLight,
        isDark: false,
      ),
    ),
  );
}

void main() {
  group('PregStep5Confirm Tests (PRG-22)', () {
    testWidgets('renders all summary rows matching data', (tester) async {
      final now = CycleClock.now;
      final lmp = CycleDateContract.cleanDate(
        now.subtract(const Duration(days: 56)),
      );
      final due = PregnancyDateEngine.dueDateFromLmp(lmp);

      final data = PregnancyOnboardingData(
        tone: PregnancyTone.warm,
        eddSource: PregnancyEddSource.lmp,
        lmpDate: lmp,
        dueDate: due,
        pauseCyclePredictions: true,
        suspendWorship: true,
        lockEnabled: true,
        hideFromDashboard: true,
        maskNotifications: true,
      );

      await tester.pumpWidget(
        _buildTestWidget(data: data, onSave: () {}, onBack: () {}),
      );
      await tester.pumpAndSettle();

      expect(find.text('تأیید و راه‌اندازی بارداری'), findsOneWidget);
      expect(find.text('سن بارداری امروز:'), findsOneWidget);
      expect(find.text('تاریخ تقریبی زایمان:'), findsOneWidget);
      expect(find.text('مبنای محاسبه:'), findsOneWidget);
      expect(find.text('آخرین پریود'), findsOneWidget);
      expect(find.text('لحن همراهی:'), findsOneWidget);
      expect(find.text('گرم و صمیمی'), findsOneWidget);
      expect(find.text('پیش‌بینی پریود:'), findsOneWidget);
      expect(find.text('متوقف می‌شود'), findsOneWidget);
      expect(find.text('وضعیت عبادات:'), findsOneWidget);
      expect(find.text('تعلیق می‌شود'), findsOneWidget);
      expect(find.text('قفل ورود:'), findsOneWidget);
      expect(find.text('فعال‌سازی حالت بارداری'), findsOneWidget);
    });

    testWidgets('tapping onSave triggers callback and shows edit mode label', (
      tester,
    ) async {
      final now = CycleClock.now;
      final lmp = CycleDateContract.cleanDate(
        now.subtract(const Duration(days: 56)),
      );
      final due = PregnancyDateEngine.dueDateFromLmp(lmp);

      final data = PregnancyOnboardingData(lmpDate: lmp, dueDate: due);

      var saved = false;

      await tester.pumpWidget(
        _buildTestWidget(
          data: data,
          onSave: () => saved = true,
          onBack: () {},
          isEditMode: true,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('بازبینی و ذخیرهٔ تغییرات'), findsOneWidget);
      final saveBtn = find.text('ذخیرهٔ تغییرات');
      expect(saveBtn, findsOneWidget);

      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      expect(saved, true);
    });

    testWidgets('shows loading spinner when isSaving is true', (tester) async {
      final now = CycleClock.now;
      final lmp = CycleDateContract.cleanDate(
        now.subtract(const Duration(days: 56)),
      );
      final due = PregnancyDateEngine.dueDateFromLmp(lmp);

      final data = PregnancyOnboardingData(lmpDate: lmp, dueDate: due);

      await tester.pumpWidget(
        _buildTestWidget(
          data: data,
          onSave: () {},
          onBack: () {},
          isSaving: true,
        ),
      );
      await tester.pump();

      expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
    });
  });
}
