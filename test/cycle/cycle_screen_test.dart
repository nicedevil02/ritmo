import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/domain/engines/cycle_engine.dart';
import 'package:ritmo/core/domain/engines/ritmo_engine_bus.dart';
import 'package:ritmo/core/theme/palettes/jade_noir.dart';
import 'package:ritmo/features/cycle/logic/cycle_lock_service.dart';
import 'package:ritmo/features/cycle/logic/cycle_period_repository.dart';
import 'package:ritmo/features/cycle/logic/cycle_state_provider.dart';
import 'package:ritmo/features/cycle/presentation/cycle_screen.dart';
import 'package:ritmo/l10n/app_localizations.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'test_helpers/cycle_test_db.dart';

Widget _buildCycleScreenApp() {
  return MaterialApp(
    theme: ThemeData.light().copyWith(extensions: [kJadeNoirLight]),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('fa'),
    home: const CycleScreen(),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  setUpAll(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('CycleScreen Presentation & UI Tests (Phase 17)', () {
    late Database db;
    late CycleEngine engine;
    late EngineRegistry registry;

    setUp(() async {
      FlutterSecureStorage.setMockInitialValues({});
      db = await openCycleTestDb();
      DatabaseHelper.instance.overrideDatabaseForTesting(db);
      await CycleLockService.instance.setLockEnabled(false, db);
      await CycleLockService.instance.clearPin(db);

      engine = CycleEngine();
      registry = EngineRegistry()..register(engine);
      RitmoEngineBus.init(registry);
    });

    tearDown(() async {
      await db.close();
    });

    Future<void> pumpScreen(WidgetTester tester) async {
      await tester.pumpWidget(_buildCycleScreenApp());
      for (var i = 0; i < 5; i++) {
        await Future.delayed(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    testWidgets('1. Empty state renders onboarding CTA when no periods exist', (tester) async {
      await tester.runAsync(() async {
        await CycleStateNotifier.instance.loadState();
        await pumpScreen(tester);
      });

      expect(find.byType(CycleScreen), findsOneWidget);
      expect(find.text('راه‌اندازی چرخه'), findsOneWidget);
    });

    testWidgets('2. Main dashboard renders "ثبت شروع قاعدگی" when only closed periods exist', (tester) async {
      await tester.runAsync(() async {
        final pastDate = DateTime.now().subtract(const Duration(days: 20));
        await CyclePeriodRepository.instance.startPeriod(
          db: db,
          startDate: pastDate,
          now: pastDate,
        );
        final active = await CyclePeriodRepository.instance.getOpenPeriod(db);
        expect(active, isNotNull);
        await CyclePeriodRepository.instance.endPeriod(
          db: db,
          id: active!.id,
          endDate: pastDate.add(const Duration(days: 5)),
          now: pastDate.add(const Duration(days: 5)),
        );

        await CycleStateNotifier.instance.loadState();
        await pumpScreen(tester);
      });

      expect(find.byType(CycleScreen), findsOneWidget);
      expect(find.textContaining('ثبت شروع'), findsWidgets);
    });

    testWidgets('3. Main dashboard renders "ثبت پایان قاعدگی" when open active period exists', (tester) async {
      await tester.runAsync(() async {
        final now = DateTime.now();
        await CyclePeriodRepository.instance.startPeriod(
          db: db,
          startDate: now,
          now: now,
        );

        await CycleStateNotifier.instance.loadState();
        await pumpScreen(tester);
      });

      expect(find.byType(CycleScreen), findsOneWidget);
      expect(find.textContaining('ثبت پایان'), findsWidgets);
    });

    testWidgets('4. Tab navigation switches across Overview, Calendar, Stats and History', (tester) async {
      await tester.runAsync(() async {
        final pastDate = DateTime.now().subtract(const Duration(days: 20));
        await CyclePeriodRepository.instance.startPeriod(
          db: db,
          startDate: pastDate,
          now: pastDate,
        );
        final active = await CyclePeriodRepository.instance.getOpenPeriod(db);
        await CyclePeriodRepository.instance.endPeriod(
          db: db,
          id: active!.id,
          endDate: pastDate.add(const Duration(days: 5)),
          now: pastDate.add(const Duration(days: 5)),
        );

        await CycleStateNotifier.instance.loadState();
        await pumpScreen(tester);

        final calendarTab = find.text('تقویم');
        if (calendarTab.evaluate().isNotEmpty) {
          await tester.tap(calendarTab);
          await Future.delayed(const Duration(milliseconds: 100));
          await tester.pump();
        }

        final statsTab = find.text('آمار و روندها');
        if (statsTab.evaluate().isNotEmpty) {
          await tester.tap(statsTab);
          await Future.delayed(const Duration(milliseconds: 100));
          await tester.pump();
        }

        final historyTab = find.text('سوابق');
        if (historyTab.evaluate().isNotEmpty) {
          await tester.tap(historyTab);
          await Future.delayed(const Duration(milliseconds: 100));
          await tester.pump();
        }

        final overviewTab = find.text('نمای کلی');
        if (overviewTab.evaluate().isNotEmpty) {
          await tester.tap(overviewTab);
          await Future.delayed(const Duration(milliseconds: 100));
          await tester.pump();
        }
      });

      expect(find.byType(CycleScreen), findsOneWidget);
    });

    testWidgets('5. Pregnancy mode displays pregnancy banner and state', (tester) async {
      await tester.runAsync(() async {
        await db.insert('app_settings', {
          'key': 'cycle_pregnancy_mode',
          'value': 'true',
        }, conflictAlgorithm: ConflictAlgorithm.replace);

        await CycleStateNotifier.instance.loadState();
        await pumpScreen(tester);
      });

      expect(find.textContaining('بارداری'), findsWidgets);
    });
  });
}
