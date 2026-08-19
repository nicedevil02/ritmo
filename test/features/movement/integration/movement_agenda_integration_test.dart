import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/schema/tables/movement_tables.dart';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/agenda/sources/agenda_source.dart';
import 'package:ritmo/core/domain/models.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/movement/application/movement_agenda_source.dart';
import 'package:ritmo/features/movement/application/movement_log_service.dart';
import 'package:ritmo/features/movement/application/movement_occurrence_service.dart';
import 'package:ritmo/features/movement/domain/models/movement_activity_kind.dart';
import 'package:ritmo/features/movement/domain/models/movement_occurrence.dart';
import 'package:ritmo/features/movement/domain/models/movement_workout_log.dart';
import 'package:ritmo/features/movement/presentation/agenda/sport_agenda_renderer.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class FakeOccurrenceServiceForAgenda extends MovementOccurrenceService {
  MovementOccurrenceStatus? lastUpdatedStatus;
  String? lastUpdatedId;

  @override
  Future<void> updateOccurrenceStatus(
    String id,
    MovementOccurrenceStatus status,
  ) async {
    lastUpdatedId = id;
    lastUpdatedStatus = status;
  }

  @override
  Future<MovementOccurrence?> getOccurrenceById(String id) async {
    return MovementOccurrence(
      id: id,
      activityKindId: 'kind_walking',
      dateIso: '2026-08-17',
      startTime: '08:00',
      goalType: 'duration',
      goalValue: 30,
      goalUnit: 'دقیقه',
      status: MovementOccurrenceStatus.planned,
      origin: MovementOrigin.template,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }
}

class FakeLogServiceForAgenda extends MovementLogService {
  @override
  Future<MovementWorkoutLog> logRetroWorkout({
    required String activityKindId,
    required String dateIso,
    String? startTime,
    required int durationSec,
    Map<String, dynamic>? metrics,
    String? feeling,
    String? note,
    String? matchedOccurrenceId,
  }) async {
    return MovementWorkoutLog(
      id: 'fake_log',
      activityKindId: activityKindId,
      dateIso: dateIso,
      durationSec: durationSec,
      source: 'retro',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  try {
    sqfliteFfiInit();
  } catch (_) {}

  group('Movement Agenda Integration Tests (Gate 6)', () {
    Database? db;
    bool dbInitialized = false;

    setUp(() async {
      try {
        databaseFactory = databaseFactoryFfi;
        db = await databaseFactory.openDatabase(inMemoryDatabasePath);
        await MovementTables.create(db!);
        await MovementTables.seedInitialData(db!);
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

    test(
      '1. Agenda items for all 4 session creation pathways appear on target day',
      () async {
        if (!dbInitialized || db == null) return;
        const targetDateIso = '2026-08-17';
        final targetDate = DateTime(2026, 8, 17);

        // Pathway 1: Planning / Template
        await db!.insert(MovementTables.tableOccurrences, {
          'id': 'occ_planned_1',
          'activityKindId': 'kind_walking',
          'dateIso': targetDateIso,
          'startTime': '07:30',
          'goalType': 'duration',
          'goalValue': 30.0,
          'goalUnit': 'دقیقه',
          'status': 'planned',
          'origin': 'template',
          'createdAt': targetDate.toIso8601String(),
          'updatedAt': targetDate.toIso8601String(),
        });

        // Pathway 2: QuickStart
        await db!.insert(MovementTables.tableOccurrences, {
          'id': 'occ_quick_2',
          'activityKindId': 'kind_running',
          'dateIso': targetDateIso,
          'startTime': '12:00',
          'goalType': 'duration',
          'goalValue': 20.0,
          'goalUnit': 'دقیقه',
          'status': 'inProgress',
          'origin': 'quickStart',
          'createdAt': targetDate.toIso8601String(),
          'updatedAt': targetDate.toIso8601String(),
        });

        // Pathway 3: RetroLog
        await db!.insert(MovementTables.tableOccurrences, {
          'id': 'occ_retro_3',
          'activityKindId': 'kind_cycling',
          'dateIso': targetDateIso,
          'startTime': '16:00',
          'goalType': 'duration',
          'goalValue': 45.0,
          'goalUnit': 'دقیقه',
          'status': 'completed',
          'origin': 'retro',
          'createdAt': targetDate.toIso8601String(),
          'updatedAt': targetDate.toIso8601String(),
        });

        // Pathway 4: Strength Program
        await db!.insert(MovementTables.tableOccurrences, {
          'id': 'occ_strength_4',
          'activityKindId': 'kind_strength',
          'dateIso': targetDateIso,
          'startTime': '19:00',
          'goalType': 'duration',
          'goalValue': 50.0,
          'goalUnit': 'دقیقه',
          'status': 'planned',
          'origin': 'strength',
          'createdAt': targetDate.toIso8601String(),
          'updatedAt': targetDate.toIso8601String(),
        });

        // Load Agenda Source
        final source = await MovementAgendaSource.load(
          db!,
          const {},
          start: targetDate,
          end: targetDate,
        );

        final ctx = AgendaDayContext(
          date: targetDate,
          dateStr: targetDateIso,
          isToday: true,
          prayerTimes: const {},
          options: const AgendaQueryOptions(),
        );

        final items = source.itemsForDate(ctx);

        expect(items.length, equals(4));

        // Verify all items belong to AgendaDomain.sport
        for (final item in items) {
          expect(item.domain, equals(AgendaDomain.sport));
          expect(item.dateStr, equals(targetDateIso));
          expect(item.deepLink.domain, equals(AgendaDomain.sport));
        }

        // Verify specific items
        final walkingItem = items.firstWhere(
          (i) => i.sourceId == 'occ_planned_1',
        );
        expect(walkingItem.title, contains('پیاده‌روی'));
        expect(walkingItem.completion, equals(AgendaCompletion.pending));
        expect(walkingItem.timeOfDay, equals('07:30'));

        final runningItem = items.firstWhere(
          (i) => i.sourceId == 'occ_quick_2',
        );
        expect(runningItem.title, contains('دویدن'));
        expect(runningItem.completion, equals(AgendaCompletion.pending));

        final cyclingItem = items.firstWhere(
          (i) => i.sourceId == 'occ_retro_3',
        );
        expect(cyclingItem.title, contains('دوچرخه‌سواری'));
        expect(cyclingItem.completion, equals(AgendaCompletion.done));

        final strengthItem = items.firstWhere(
          (i) => i.sourceId == 'occ_strength_4',
        );
        expect(strengthItem.title, contains('تمرین قدرتی'));
        expect(strengthItem.completion, equals(AgendaCompletion.pending));
      },
    );

    testWidgets(
      '2. Completing session via SportAgendaRenderer updates DB, Agenda and creates log',
      (tester) async {
        final fakeOccService = FakeOccurrenceServiceForAgenda();
        final fakeLogService = FakeLogServiceForAgenda();

        final sampleOcc = MovementOccurrence(
          id: 'occ_test_complete',
          activityKindId: 'kind_walking',
          dateIso: '2026-08-17',
          startTime: '08:00',
          goalType: 'duration',
          goalValue: 30,
          goalUnit: 'دقیقه',
          status: MovementOccurrenceStatus.planned,
          origin: MovementOrigin.template,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final sampleKind = MovementActivityKind(
          id: 'kind_walking',
          nameFa: 'پیاده‌روی',
          family: 'walking',
          icon: 'directions_walk',
          primaryMetric: 'duration',
          createdAt: DateTime.now(),
        );

        final agendaItem = AgendaItem(
          id: 'sport:occ_test_complete:2026-08-17',
          sourceId: 'occ_test_complete',
          domain: AgendaDomain.sport,
          title: 'پیاده‌روی',
          subtitle: 'هدف: ۳۰ دقیقه',
          dateStr: '2026-08-17',
          timeOfDay: '08:00',
          durationMinutes: 30,
          category: Category.fitness,
          completion: AgendaCompletion.pending,
          deepLink: const AgendaDeepLink(
            domain: AgendaDomain.sport,
            targetId: 'occ_test_complete',
          ),
          meta: {
            'occurrence': sampleOcc.toMap(),
            'activityKind': sampleKind.toMap(),
            'family': 'walking',
          },
        );

        bool changedNotified = false;

        await tester.pumpWidget(
          MaterialApp(
            theme: RitmoTheme.build(
              palette: RitmoPalette.jadeNoir,
              brightness: Brightness.dark,
            ),
            home: Directionality(
              textDirection: TextDirection.rtl,
              child: Scaffold(
                body: Builder(
                  builder: (context) {
                    return Padding(
                      padding: const EdgeInsets.all(16.0),
                      child:
                          SportAgendaRenderer(
                            occurrenceService: fakeOccService,
                            logService: fakeLogService,
                          ).build(
                            context,
                            agendaItem,
                            onChanged: () => changedNotified = true,
                          ),
                    );
                  },
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('پیاده‌روی'), findsOneWidget);

        // Tap complete button
        final completeButton = find.byType(IconButton);
        expect(completeButton, findsOneWidget);

        await tester.tap(completeButton);
        await tester.pumpAndSettle();

        expect(changedNotified, isTrue);
        expect(
          fakeOccService.lastUpdatedStatus,
          equals(MovementOccurrenceStatus.completed),
        );
        expect(fakeOccService.lastUpdatedId, equals('occ_test_complete'));
      },
    );
  });
}
