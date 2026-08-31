import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/schema/tables/planning_tables.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/goals/logic/planning_repository.dart';
import 'package:ritmo/features/goals/presentation/planning_screen.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database db;

  setUp(() async {
    db = await openDatabase(
      inMemoryDatabasePath,
      version: 1,
      onCreate: (d, v) async {
        await PlanningTables.create(d);
        await d.execute('''
          CREATE TABLE IF NOT EXISTS calendar_exceptions (
            id TEXT PRIMARY KEY,
            date TEXT NOT NULL,
            behavior TEXT NOT NULL,
            reason TEXT NOT NULL,
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL
          );
        ''');
      },
    );
    PlanningRepository.instance.setTestDatabase(db);
  });

  tearDown(() async {
    PlanningRepository.instance.setTestDatabase(null);
    await db.close();
  });

  Widget buildTestableWidget(Widget child) {
    return MaterialApp(
      theme: RitmoTheme.build(
        palette: RitmoPalette.jadeNoir,
        brightness: Brightness.dark,
      ),
      home: child,
    );
  }

  testWidgets('U-14 Test 1 & 2: Renders 3 horizons SegmentedControl and default is این هفته', (tester) async {
    await tester.pumpWidget(buildTestableWidget(const PlanningScreen()));
    await tester.runAsync(() async {
      await Future.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();

    expect(find.text('امروز'), findsOneWidget);
    expect(find.text('این هفته'), findsOneWidget);
    expect(find.text('این ماه'), findsOneWidget);
  });

  testWidgets('U-14 Test 3: Switching to امروز renders today command card', (tester) async {
    await tester.pumpWidget(buildTestableWidget(const PlanningScreen()));
    await tester.runAsync(() async {
      await Future.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();

    await tester.tap(find.text('امروز'));
    await tester.runAsync(() async {
      await Future.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();

    expect(find.textContaining('چیدمان امروز با ✨'), findsOneWidget);
  });

  testWidgets('U-14 Test 4: Switching to این ماه renders MonthPlanSection', (tester) async {
    await tester.pumpWidget(buildTestableWidget(const PlanningScreen()));
    await tester.runAsync(() async {
      await Future.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();

    await tester.tap(find.text('این ماه'));
    await tester.runAsync(() async {
      await Future.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();

    expect(find.textContaining('تمرکزهای اصلی ماه'), findsOneWidget);
  });

  testWidgets('U-14 Test 5: Empty state in Today tab shows Persian fallback message', (tester) async {
    await tester.pumpWidget(buildTestableWidget(const PlanningScreen()));
    await tester.runAsync(() async {
      await Future.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();

    await tester.tap(find.text('امروز'));
    await tester.runAsync(() async {
      await Future.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();

    expect(find.textContaining('امروز هیچ تعهدی نداری'), findsOneWidget);
  });
}
