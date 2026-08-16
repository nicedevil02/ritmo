import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/notifications/notification_channel.dart';
import 'package:ritmo/core/notifications/notification_request.dart';
import 'package:ritmo/features/movement/application/movement_notification_service.dart';
import 'package:ritmo/features/movement/domain/models/movement_activity_kind.dart';
import 'package:ritmo/features/movement/domain/models/movement_occurrence.dart';
import 'package:ritmo/features/movement/presentation/movement_routes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Movement Notification Service & Integration Tests (Gate 6)', () {
    late List<NotificationRequest> scheduledRequests;
    late List<String> cancelledIds;
    late MovementNotificationService service;

    setUp(() {
      scheduledRequests = [];
      cancelledIds = [];

      service = MovementNotificationService(
        scheduleFn: (req) async {
          scheduledRequests.add(req);
          return true;
        },
        cancelFn: (id) async {
          cancelledIds.add(id);
          return true;
        },
      );
    });

    final sampleOcc = MovementOccurrence(
      id: 'occ_test_notif',
      activityKindId: 'kind_running',
      dateIso: '2026-08-17',
      startTime: '18:00',
      goalType: 'duration',
      goalValue: 45,
      goalUnit: 'دقیقه',
      status: MovementOccurrenceStatus.planned,
      origin: MovementOrigin.template,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final sampleKind = MovementActivityKind(
      id: 'kind_running',
      nameFa: 'دویدن',
      family: 'running',
      icon: 'directions_run',
      primaryMetric: 'distance',
      createdAt: DateTime.now(),
    );

    test('1. Schedules pre-session reminder with correct offset and channel', () async {
      final success = await service.scheduleSessionReminder(
        occurrence: sampleOcc,
        kind: sampleKind,
        minutesBefore: 15,
      );

      expect(success, isTrue);
      expect(scheduledRequests.length, equals(1));

      final req = scheduledRequests.first;
      expect(req.id, equals('mov_rem_occ_test_notif'));
      expect(req.channel, equals(NotificationChannelId.routine));
      expect(req.title, equals('دویدن'));
      expect(req.scheduledAt, equals(DateTime(2026, 8, 17, 17, 45)));
      expect(req.privacy, equals(NotificationPrivacy.none));
      expect(req.payload!['route'], equals(MovementRoutes.occurrence));
    });

    test('2. Schedules morning summary reminder for daily occurrences', () async {
      final success = await service.scheduleMorningSummary(
        dateIso: '2026-08-17',
        dailyOccurrences: [sampleOcc, sampleOcc.copyWith(id: 'occ_2')],
        morningTime: '07:30',
      );

      expect(success, isTrue);
      expect(scheduledRequests.length, equals(1));

      final req = scheduledRequests.first;
      expect(req.id, equals('mov_morning_2026-08-17'));
      expect(req.channel, equals(NotificationChannelId.planning));
      expect(req.scheduledAt, equals(DateTime(2026, 8, 17, 7, 30)));
      expect(req.body, contains('۲'));
      expect(req.payload!['route'], equals(MovementRoutes.center));
    });

    test('3. Schedules partial session reminder with future delay', () async {
      final success = await service.schedulePartialSessionReminder(
        occurrenceId: 'occ_partial_123',
        delayMinutes: 60,
      );

      expect(success, isTrue);
      expect(scheduledRequests.length, equals(1));

      final req = scheduledRequests.first;
      expect(req.id, equals('mov_partial_occ_partial_123'));
      expect(req.channel, equals(NotificationChannelId.routine));
      expect(req.payload!['route'], equals(MovementRoutes.liveSession));
    });

    test('4. Privacy mode generates redacted neutral title and body', () async {
      await service.scheduleSessionReminder(
        occurrence: sampleOcc,
        kind: sampleKind,
        isPrivate: true,
      );

      expect(scheduledRequests.length, equals(1));
      final req = scheduledRequests.first;
      expect(req.privacy, equals(NotificationPrivacy.redacted));
      expect(req.redactedTitle, equals('یادآوری ریتمو'));
      expect(req.redactedBody, isNotEmpty);
    });

    test('5. Lifecycle rules: cancel, reschedule, pause strength, wipe all', () async {
      // Cancel on complete or skip
      await service.cancelOccurrenceReminders('occ_test_notif');
      expect(cancelledIds, contains('mov_rem_occ_test_notif'));
      expect(cancelledIds, contains('mov_partial_occ_test_notif'));

      // Reschedule on move
      cancelledIds.clear();
      scheduledRequests.clear();
      final movedOcc = sampleOcc.copyWith(dateIso: '2026-08-18', startTime: '19:00');
      await service.rescheduleOccurrenceReminder(movedOccurrence: movedOcc, kind: sampleKind);

      expect(cancelledIds, contains('mov_rem_occ_test_notif'));
      expect(scheduledRequests.length, equals(1));
      expect(scheduledRequests.first.scheduledAt, equals(DateTime(2026, 8, 18, 18, 45)));

      // Strength program pause
      cancelledIds.clear();
      await service.cancelStrengthProgramReminders(['s_occ_1', 's_occ_2']);
      expect(cancelledIds, contains('mov_rem_s_occ_1'));
      expect(cancelledIds, contains('mov_rem_s_occ_2'));

      // Wipe all movement data
      cancelledIds.clear();
      await service.cancelAllMovementReminders(allOccurrenceIds: ['occ_a', 'occ_b']);
      expect(cancelledIds, contains('mov_rem_occ_a'));
      expect(cancelledIds, contains('mov_rem_occ_b'));
    });

    testWidgets('6. Notification deep link navigation with safe fallback', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          routes: {
            MovementRoutes.center: (_) => const Text('Center Screen'),
            MovementRoutes.occurrence: (_) => const Text('Occurrence Details Screen'),
          },
          home: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  // Valid payload
                  MovementNotificationService.navigateFromPayload(context, {
                    'route': MovementRoutes.occurrence,
                    'occurrenceId': 'occ_123',
                  });
                },
                child: const Text('Navigate'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Navigate'));
      await tester.pumpAndSettle();

      expect(find.text('Occurrence Details Screen'), findsOneWidget);
    });
  });
}
