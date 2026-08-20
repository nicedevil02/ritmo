import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/theme/palettes/jade_noir.dart';
import 'package:ritmo/features/cycle/logic/cycle_lock_service.dart';
import 'package:ritmo/features/cycle/models/pregnancy_models.dart';
import 'package:ritmo/features/cycle/presentation/onboarding/pregnancy_steps/preg_step_4_privacy.dart';
import 'package:ritmo/l10n/app_localizations.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../test_helpers/cycle_test_db.dart';

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
      body: PregStep4Privacy(
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
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  setUpAll(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('PregStep4Privacy Tests (PRG-21)', () {
    late Database db;

    setUp(() async {
      FlutterSecureStorage.setMockInitialValues({});
      db = await openCycleTestDb();
      DatabaseHelper.instance.overrideDatabaseForTesting(db);
      await CycleLockService.instance.setLockEnabled(false, db);
      await CycleLockService.instance.clearPin(db);
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('renders title, all 3 privacy toggles and privacy pill', (tester) async {
      const data = PregnancyOnboardingData(lockEnabled: false);

      await tester.pumpWidget(_buildTestWidget(
        data: data,
        onDataChanged: (_) {},
      ));
      await tester.pumpAndSettle();

      expect(find.text('حریم خصوصی و قفل'), findsOneWidget);
      expect(find.text('قفل ورود به بخش بارداری'), findsOneWidget);
      expect(find.text('پنهان کردن بارداری از صفحهٔ امروز'), findsOneWidget);
      expect(find.text('پوشاندن متن یادآوری‌ها در اعلان‌ها'), findsOneWidget);
      expect(find.text('اطلاعات فقط روی گوشی'), findsOneWidget);
    });

    testWidgets('when lockEnabled is true without configured PIN, shows helper text', (tester) async {
      const data = PregnancyOnboardingData(lockEnabled: true);

      await tester.pumpWidget(_buildTestWidget(
        data: data,
        onDataChanged: (_) {},
      ));
      await tester.pumpAndSettle();

      expect(find.text('رمز بعد از پایان راه‌اندازی تنظیم می‌شود.'), findsOneWidget);
    });

    testWidgets('toggling switches updates data accordingly', (tester) async {
      PregnancyOnboardingData currentData = const PregnancyOnboardingData(
        lockEnabled: false,
        hideFromDashboard: true,
        maskNotifications: true,
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

      final switches = find.byType(CupertinoSwitch);
      expect(switches, findsNWidgets(3));

      // Toggle lock
      await tester.tap(switches.at(0));
      await tester.pumpAndSettle();
      expect(currentData.lockEnabled, true);

      // Toggle hideFromDashboard
      await tester.tap(switches.at(1));
      await tester.pumpAndSettle();
      expect(currentData.hideFromDashboard, false);

      // Toggle maskNotifications
      await tester.tap(switches.at(2));
      await tester.pumpAndSettle();
      expect(currentData.maskNotifications, false);
    });
  });
}
