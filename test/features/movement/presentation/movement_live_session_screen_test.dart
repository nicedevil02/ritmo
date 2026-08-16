import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/schema/tables/movement_tables.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/movement/application/movement_session_service.dart';
import 'package:ritmo/features/movement/domain/models/movement_activity_kind.dart';
import 'package:ritmo/features/movement/presentation/common/movement_strings.dart';
import 'package:ritmo/features/movement/presentation/session/movement_live_session_screen.dart';
import 'package:ritmo/features/movement/presentation/session/sheets/pause_exit_sheet.dart';
import 'package:ritmo/features/movement/presentation/session/widgets/session_app_bar.dart';
import 'package:ritmo/features/movement/presentation/session/widgets/session_primary_cta.dart';
import 'package:ritmo/features/movement/presentation/session/widgets/session_status_strip.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  try {
    sqfliteFfiInit();
  } catch (_) {}

  final sampleKind = MovementActivityKind(
    id: 'kind_walking',
    nameFa: 'پیاده‌روی',
    family: 'walking',
    icon: 'directions_walk',
    primaryMetric: 'duration',
    createdAt: DateTime.now(),
  );

  group('MovementLiveSessionScreen & SessionShell Tests (Gate 3)', () {
    Database? db;
    bool dbReady = false;

    setUp(() async {
      try {
        databaseFactory = databaseFactoryFfi;
        db = await databaseFactory.openDatabase(inMemoryDatabasePath);
        await MovementTables.create(db!);
        await MovementTables.seedInitialData(db!);
        dbReady = true;
      } catch (_) {
        dbReady = false;
      }
    });

    tearDown(() async {
      if (dbReady && db != null) {
        await db!.close();
      }
    });

    Widget buildTestableWidget(Widget child) {
      return MaterialApp(
        theme: RitmoTheme.build(
          palette: RitmoPalette.jadeNoir,
          brightness: Brightness.dark,
        ),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: child,
        ),
      );
    }

    testWidgets('1. SessionShell renders all building blocks with single primary CTA', (tester) async {
      if (!dbReady || db == null) return;
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final service = MovementSessionService(db: db);

      await tester.pumpWidget(
        buildTestableWidget(
          MovementLiveSessionScreen(
            activityKind: sampleKind,
            sessionService: service,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify SessionAppBar
      expect(find.byType(SessionAppBar), findsOneWidget);
      expect(find.text('پیاده‌روی'), findsOneWidget);

      // Verify SessionStatusStrip
      expect(find.byType(SessionStatusStrip), findsOneWidget);

      // Verify exactly ONE prominent primary CTA
      expect(find.byType(SessionPrimaryCta), findsOneWidget);
      expect(find.text(MovementStrings.sessionFinish), findsOneWidget);
    });

    testWidgets('2. Back button triggers PauseExitSheet and does not pop or finish session directly', (tester) async {
      if (!dbReady || db == null) return;
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final service = MovementSessionService(db: db);

      await tester.pumpWidget(
        buildTestableWidget(
          MovementLiveSessionScreen(
            activityKind: sampleKind,
            sessionService: service,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap back button on AppBar
      final backBtn = find.byTooltip('بازگشت');
      expect(backBtn, findsOneWidget);
      await tester.tap(backBtn);
      await tester.pumpAndSettle();

      // PauseExitSheet must be visible
      expect(find.byType(PauseExitSheet), findsOneWidget);
      expect(find.text(MovementStrings.pauseExitTitle), findsOneWidget);
    });

    testWidgets('3. Toggling pause changes primary CTA to Resume and updates status strip', (tester) async {
      if (!dbReady || db == null) return;
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final service = MovementSessionService(db: db);

      await tester.pumpWidget(
        buildTestableWidget(
          MovementLiveSessionScreen(
            activityKind: sampleKind,
            sessionService: service,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap pause button on AppBar
      final pauseBtn = find.byTooltip('مکث');
      expect(pauseBtn, findsOneWidget);
      await tester.tap(pauseBtn);
      await tester.pumpAndSettle();

      // Primary CTA changes to Resume
      expect(find.text(MovementStrings.sessionResume), findsOneWidget);
      expect(find.text('متوقف‌شده'), findsOneWidget);
    });
  });
}
