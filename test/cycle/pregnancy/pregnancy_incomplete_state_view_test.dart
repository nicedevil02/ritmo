import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/domain/engines/cycle_engine.dart';
import 'package:ritmo/core/domain/engines/ritmo_engine_bus.dart';
import 'package:ritmo/core/theme/palettes/jade_noir.dart';
import 'package:ritmo/features/cycle/logic/cycle_lock_service.dart';
import 'package:ritmo/features/cycle/logic/cycle_state_provider.dart';
import 'package:ritmo/features/cycle/presentation/cycle_screen.dart';
import 'package:ritmo/features/cycle/presentation/widgets/cycle_pregnancy_mode.dart';
import 'package:ritmo/l10n/app_localizations.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../test_helpers/cycle_test_db.dart';

Widget _buildTestApp() {
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

  group('PregnancyIncompleteStateView Tests (PRG-11)', () {
    late Database db;
    late CycleEngine engine;
    late EngineRegistry registry;

    setUp(() async {
      FlutterSecureStorage.setMockInitialValues({});
      db = await openCycleTestDb(
        initialSettings: {
          'cycle_pregnancy_mode': 'true',
          // No start/due dates provided
        },
      );
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
      await tester.pumpWidget(_buildTestApp());
      for (var i = 0; i < 5; i++) {
        await Future.delayed(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    testWidgets(
      'shows incomplete state card instead of 0-week pregnancy view when dates are missing',
      (tester) async {
        await tester.runAsync(() async {
          await CycleStateNotifier.instance.loadState();
          await pumpScreen(tester);
        });

        expect(find.text('اطلاعات بارداری ناقص است'), findsOneWidget);
        expect(find.text('تکمیل راه‌اندازی بارداری'), findsOneWidget);
        expect(find.byType(CyclePregnancyModeView), findsNothing);
      },
    );

    testWidgets('shows CyclePregnancyModeView when dates are valid', (
      tester,
    ) async {
      await tester.runAsync(() async {
        // Add valid dates
        await db.insert('app_settings', {
          'key': 'preg_start_date',
          'value': '2026-01-01',
          'updatedAt': 1,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
        await db.insert('app_settings', {
          'key': 'preg_due_date',
          'value': '2026-10-08',
          'updatedAt': 1,
        }, conflictAlgorithm: ConflictAlgorithm.replace);

        await CycleStateNotifier.instance.loadState();
        await pumpScreen(tester);
      });

      expect(find.text('اطلاعات بارداری ناقص است'), findsNothing);
      expect(find.byType(CyclePregnancyModeView), findsOneWidget);
    });
  });
}
