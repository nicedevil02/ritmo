import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/domain/engines/cycle_engine.dart';
import 'package:ritmo/core/domain/engines/ritmo_engine_bus.dart';
import 'package:ritmo/core/theme/palettes/jade_noir.dart';
import 'package:ritmo/features/cycle/logic/cycle_clock.dart';
import 'package:ritmo/features/cycle/logic/cycle_date_contract.dart';
import 'package:ritmo/features/cycle/logic/pregnancy_engine.dart';
import 'package:ritmo/features/cycle/logic/pregnancy_settings.dart';
import 'package:ritmo/features/cycle/models/pregnancy_models.dart';
import 'package:ritmo/features/cycle/presentation/widgets/kick_session_tracker.dart';
import 'package:ritmo/features/cycle/presentation/widgets/pregnancy/pregnancy_settings_sheet.dart';
import 'package:ritmo/features/cycle/presentation/widgets/pregnancy/pregnancy_tabs.dart';
import 'package:ritmo/l10n/app_localizations.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../test_helpers/cycle_test_db.dart';

Widget _buildTestApp(Widget child) {
  return MaterialApp(
    theme: ThemeData.light().copyWith(extensions: [kJadeNoirLight]),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('fa'),
    home: Scaffold(body: child),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  setUpAll(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('Configurable Kick Tracker Tests (PRG-36)', () {
    late Database db;

    setUp(() async {
      FlutterSecureStorage.setMockInitialValues({});
      db = await openCycleTestDb();
      DatabaseHelper.instance.overrideDatabaseForTesting(db);

      final engine = CycleEngine();
      final registry = EngineRegistry()..register(engine);
      RitmoEngineBus.init(registry);
    });

    tearDown(() async {
      await db.close();
    });

    test('KickSessionTracker respects custom target and limit', () {
      final now = DateTime(2026, 5, 10, 10, 0);

      // Default tracker
      final defaultTracker = KickSessionTracker();
      expect(defaultTracker.target, 10);
      expect(defaultTracker.limit, const Duration(hours: 2));

      // Custom tracker (target: 5, limit: 30 minutes)
      final customTracker = KickSessionTracker(
        target: 5,
        limit: const Duration(minutes: 30),
      );
      expect(customTracker.target, 5);
      expect(customTracker.limit, const Duration(minutes: 30));

      for (var i = 0; i < 4; i++) {
        final reached = customTracker.registerTap(
          now.add(Duration(minutes: i * 3)),
        );
        expect(reached, isFalse);
      }
      final reached5th = customTracker.registerTap(
        now.add(const Duration(minutes: 12)),
      );
      expect(reached5th, isTrue);

      // Expiry check
      expect(
        customTracker.isExpired(now.add(const Duration(minutes: 20))),
        isFalse,
      );
      expect(
        customTracker.isExpired(now.add(const Duration(minutes: 35))),
        isTrue,
      );
    });

    testWidgets('PregnancyKicksTab displays custom targetCount', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        _buildTestApp(
          PregnancyKicksTab(kickCount: 3, targetCount: 15, onKickTap: () {}),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('جلسه واقعی «شمارش تا ۱۵» حرکات جنین'), findsOneWidget);
      expect(find.text('تعداد حرکات ثبت شده: ۳ / ۱۵'), findsOneWidget);
    });

    testWidgets(
      'PregnancySettingsSheet Section 4 renders and saves kick settings',
      (tester) async {
        tester.view.physicalSize = const Size(800, 2000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.runAsync(() async {
          final now = CycleClock.now;
          final lmp = CycleDateContract.cleanDate(
            now.subtract(const Duration(days: 70)),
          );
          final due = PregnancyDateEngine.calculateEddFromLmp(lmp);

          final profile = PregnancyProfile(
            lmpDate: lmp,
            dueDate: due,
            kickTargetCount: 10,
            kickWindowMinutes: 120,
            kickBaselineComparison: false,
          );
          await PregnancySettings.saveProfile(profile, db);

          await tester.pumpWidget(
            _buildTestApp(PregnancySettingsSheet(initialProfile: profile)),
          );
          await tester.pump(const Duration(milliseconds: 100));

          expect(find.text('لگدشماری'), findsOneWidget);
          expect(find.text('تعداد هدف لگد'), findsOneWidget);
          expect(find.text('۱۰ حرکت'), findsOneWidget);
          expect(find.text('مدت پنجرهٔ شمارش'), findsOneWidget);
          expect(find.text('۱۲۰ دقیقه'), findsOneWidget);
          expect(find.text('مقایسه با الگوی شخصی خودم'), findsOneWidget);

          // Toggle baseline comparison switch (find all switches)
          final switches = find.byType(CupertinoSwitch);
          expect(switches, findsWidgets);

          // Tap on toggle row text
          await tester.tap(find.text('مقایسه با الگوی شخصی خودم'));
          await tester.pump(const Duration(milliseconds: 300));

          final rawRows = await db.query('app_settings');
          final settings = {
            for (final r in rawRows) r['key'] as String: r['value'],
          };
          expect(settings['preg_kick_target_count'], '10');
          expect(settings['preg_kick_window_minutes'], '120');
        });
      },
    );
  });
}
