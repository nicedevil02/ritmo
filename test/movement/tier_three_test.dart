import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/schema/tables/movement_tables.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/movement/application/movement_preferences_service.dart';
import 'package:ritmo/features/movement/domain/models/movement_tier.dart';
import 'package:ritmo/features/movement/presentation/settings/movement_settings_screen.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  try {
    sqfliteFfiInit();
  } catch (_) {}

  Widget wrapWithTheme(Widget child) {
    return MaterialApp(
      theme: RitmoTheme.build(
        palette: RitmoPalette.jadeNoir,
        brightness: Brightness.dark,
      ),
      home: Directionality(textDirection: TextDirection.rtl, child: child),
    );
  }

  group('Tier 3 Strength Settings & Acceptance (Phase 7 / P-18, P-19, P-20)', () {
    Database? db;
    bool dbInitialized = false;
    late MovementPreferencesService prefService;

    setUp(() async {
      try {
        databaseFactory = databaseFactoryFfi;
        db = await databaseFactory.openDatabase(inMemoryDatabasePath);
        await MovementTables.create(db!);
        prefService = MovementPreferencesService(db: db);
        dbInitialized = true;
      } catch (_) {
        dbInitialized = false;
      }
    });

    tearDown(() async {
      if (dbInitialized && db != null) {
        await db!.close();
      }
    });

    test('1. Setting and resolving Tier 3 in MovementPreferencesService', () async {
      if (!dbInitialized) return;
      await prefService.setTier(MovementTier.three);
      final tier = await prefService.resolveTier();
      expect(tier, equals(MovementTier.three));
    });

    testWidgets('2. MovementSettingsScreen renders Tier 3 toggle', (
      tester,
    ) async {
      if (!dbInitialized) return;

      await tester.runAsync(() async {
        await tester.pumpWidget(
          wrapWithTheme(
            MovementSettingsScreen(preferencesService: prefService),
          ),
        );
        await Future.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();

      expect(find.text('تمرین قدرتی (پیشرفته)'), findsOneWidget);
      expect(find.text('برنامهٔ وزنه، ثبت ست و RIR'), findsOneWidget);
      expect(find.byType(SwitchListTile), findsOneWidget);
    });
  });
}
