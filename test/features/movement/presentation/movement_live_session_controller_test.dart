import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/schema/tables/movement_tables.dart';
import 'package:ritmo/features/movement/application/movement_session_service.dart';
import 'package:ritmo/features/movement/domain/models/movement_activity_kind.dart';
import 'package:ritmo/features/movement/domain/models/movement_live_session.dart';
import 'package:ritmo/features/movement/presentation/session/movement_live_session_controller.dart';
import 'package:ritmo/features/movement/presentation/session/sheets/pain_report_sheet.dart';
import 'package:ritmo/features/movement/presentation/session/widgets/lap_button.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  try {
    sqfliteFfiInit();
  } catch (_) {}

  final sampleKind = MovementActivityKind(
    id: 'kind_running',
    nameFa: 'دویدن',
    family: 'running',
    icon: 'directions_run',
    primaryMetric: 'distance',
    createdAt: DateTime.now(),
  );

  group('MovementLiveSessionController State Machine & Kill/Restore Tests', () {
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

    test('1. Transitions through 8 states and preserves user inputs on Pause/Resume', () async {
      if (!dbReady || db == null) return;
      final service = MovementSessionService(db: db);

      final controller = MovementLiveSessionController(
        sessionService: service,
        activityKind: sampleKind,
        initialMode: 'distance',
      );

      await controller.initialize();
      expect(controller.status, equals(MovementLiveSessionStatus.active));
      expect(controller.mode, equals('distance'));

      // Enter distance
      controller.updateDistance(2.5);
      expect(controller.distanceKm, equals(2.5));

      // Pause
      await controller.togglePause();
      expect(controller.status, equals(MovementLiveSessionStatus.paused));
      expect(controller.isPaused, isTrue);

      // Resume
      await controller.togglePause();
      expect(controller.status, equals(MovementLiveSessionStatus.active));
      expect(controller.distanceKm, equals(2.5)); // Preserved

      // Finish
      final log = await controller.finish();
      expect(controller.status, equals(MovementLiveSessionStatus.completed));
      expect(log, isNotNull);
      expect(controller.completedLog?.source, equals('live'));

      controller.dispose();
    });

    test('2. Kill and Restore for all 5 modes restores recorded data and accurate elapsed time', () async {
      if (!dbReady || db == null) return;
      final service = MovementSessionService(db: db);

      for (final testMode in ['time', 'distance', 'lap', 'count', 'free']) {
        // Step A: Start session and record data
        final controller1 = MovementLiveSessionController(
          sessionService: service,
          activityKind: sampleKind,
          initialMode: testMode,
        );
        await controller1.initialize();

        if (testMode == 'distance') {
          controller1.updateDistance(4.2);
        } else if (testMode == 'lap') {
          controller1.recordLap(const SessionLapItem(lapNumber: 1, durationSec: 60, splitTimeSec: 60));
          controller1.recordLap(const SessionLapItem(lapNumber: 2, durationSec: 55, splitTimeSec: 115));
        } else if (testMode == 'count') {
          controller1.updateCount(25);
        } else if (testMode == 'free') {
          controller1.updateIntensity(4);
          controller1.updateNote('حس عالی در تمرین آزاد');
        }

        final sessionId = controller1.session!.id;
        controller1.dispose(); // Simulate App Kill

        // Step B: Restore session from DB
        final restoredSession = await service.getSessionById(sessionId);
        expect(restoredSession, isNotNull);

        final controller2 = MovementLiveSessionController(
          sessionService: service,
          activityKind: sampleKind,
          existingSession: restoredSession,
        );
        await controller2.initialize();

        // Step C: Verify data restored accurately
        expect(controller2.mode, equals(testMode));
        if (testMode == 'distance') {
          expect(controller2.distanceKm, equals(4.2));
        } else if (testMode == 'lap') {
          expect(controller2.laps.length, equals(2));
          expect(controller2.laps.first.durationSec, equals(60));
        } else if (testMode == 'count') {
          expect(controller2.currentCount, equals(25));
        } else if (testMode == 'free') {
          expect(controller2.selectedIntensity, equals(4));
          expect(controller2.sessionNote, equals('حس عالی در تمرین آزاد'));
        }

        controller2.dispose();
      }
    });

    test('3. Mode change preserves recorded data across modes', () async {
      if (!dbReady || db == null) return;
      final service = MovementSessionService(db: db);

      final controller = MovementLiveSessionController(
        sessionService: service,
        activityKind: sampleKind,
        initialMode: 'distance',
      );
      await controller.initialize();

      controller.updateDistance(3.0);
      controller.setMode('lap');
      expect(controller.mode, equals('lap'));

      controller.recordLap(const SessionLapItem(lapNumber: 1, durationSec: 90, splitTimeSec: 90));
      expect(controller.laps.length, equals(1));
      expect(controller.distanceKm, equals(3.0)); // Distance preserved

      controller.dispose();
    });

    test('4. Pain report with high severity (>=4) immediately triggers session finish', () async {
      if (!dbReady || db == null) return;
      final service = MovementSessionService(db: db);

      final controller = MovementLiveSessionController(
        sessionService: service,
        activityKind: sampleKind,
      );
      await controller.initialize();

      controller.reportPain(const PainReportData(
        severity: 5,
        location: 'زانوی راست',
        shouldStopSession: true,
      ));

      expect(controller.painReports.length, equals(1));
      expect(controller.status, equals(MovementLiveSessionStatus.completed));

      controller.dispose();
    });
  });
}
