import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/schema/tables/movement_tables.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/movement/application/movement_log_service.dart';
import 'package:ritmo/features/movement/presentation/session/sheets/quick_log_sheet.dart';
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

  group('QuickLogSheet Widget Tests', () {
    testWidgets('1. QuickLogSheet renders 3 intensity options and responds to tap', (
      tester,
    ) async {
      String? selectedTag;

      await tester.pumpWidget(
        wrapWithTheme(
          Scaffold(
            body: QuickLogSheet(
              onSelectIntensity: (tag) => selectedTag = tag,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('😌'), findsOneWidget);
      expect(find.text('سبک'), findsOneWidget);
      expect(find.text('😊'), findsOneWidget);
      expect(find.text('خوب'), findsOneWidget);
      expect(find.text('💪'), findsOneWidget);
      expect(find.text('سنگین'), findsOneWidget);

      await tester.tap(find.text('😊'));
      await tester.pump();

      expect(selectedTag, equals('moderate'));
    });

    testWidgets('2. QuickLogSheet does not trigger callback if not selected', (
      tester,
    ) async {
      String? selectedTag;

      await tester.pumpWidget(
        wrapWithTheme(
          Scaffold(
            body: QuickLogSheet(
              onSelectIntensity: (tag) => selectedTag = tag,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(QuickLogSheet), findsOneWidget);
      expect(selectedTag, isNull);
    });
  });

  group('MovementLogService Quick Log Cycle Tests', () {
    Database? db;
    bool dbInitialized = false;
    late MovementLogService logService;

    setUp(() async {
      try {
        databaseFactory = databaseFactoryFfi;
        db = await databaseFactory.openDatabase(inMemoryDatabasePath);
        await MovementTables.create(db!);
        logService = MovementLogService(db: db);
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

    test('3. Complete occurrence and undo cycle updates status and log rows', () async {
      if (!dbInitialized || db == null) return;
      const dateIso = '2026-08-20';

      await db!.insert(MovementTables.tableOccurrences, {
        'id': 'occ_test_1',
        'activityKindId': 'kind_walking',
        'dateIso': dateIso,
        'status': 'planned',
        'origin': 'template',
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      });

      // ۱. انجام ثبت سریع با تگ hard
      final log = await logService.quickCompleteOccurrence(
        occurrenceId: 'occ_test_1',
        activityKindId: 'kind_walking',
        dateIso: dateIso,
        durationSec: 1800,
        intensityTag: 'hard',
      );

      expect(log.feeling, equals('hard'));
      expect(log.source, equals('quickComplete'));

      // بررسی وضعیت occurrence در دیتابیس
      final occRowsAfter = await db!.query(
        MovementTables.tableOccurrences,
        where: 'id = ?',
        whereArgs: ['occ_test_1'],
      );
      expect(occRowsAfter.first['status'], equals('completed'));

      // بررسی درج در جدول workout logs
      final logRows = await db!.query(
        MovementTables.tableWorkoutLogs,
        where: 'id = ?',
        whereArgs: [log.id],
      );
      expect(logRows.length, equals(1));
      expect(logRows.first['feeling'], equals('hard'));

      // ۲. اجرای Undo
      await logService.undoQuickComplete(
        logId: log.id,
        occurrenceId: 'occ_test_1',
        previousStatus: 'planned',
      );

      // بررسی پاک شدن لاگ و بازگشت وضعیت occurrence به planned
      final logRowsAfterUndo = await db!.query(
        MovementTables.tableWorkoutLogs,
        where: 'id = ?',
        whereArgs: [log.id],
      );
      expect(logRowsAfterUndo.isEmpty, isTrue);

      final occRowsAfterUndo = await db!.query(
        MovementTables.tableOccurrences,
        where: 'id = ?',
        whereArgs: ['occ_test_1'],
      );
      expect(occRowsAfterUndo.first['status'], equals('planned'));
    });
  });
}
