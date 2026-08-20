import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/notifications/notification_request.dart';
import 'package:ritmo/features/movement/application/movement_notification_service.dart';
import 'package:ritmo/features/movement/domain/models/movement_occurrence.dart';

void main() {
  group('Movement Notification Policy Tests (Phase 8 / P-21, P-22)', () {
    test('1. Early notification before 08:00 is clamped to 08:00', () async {
      NotificationRequest? capturedReq;
      final service = MovementNotificationService(
        scheduleFn: (req) async {
          capturedReq = req;
          return true;
        },
      );

      final occ = MovementOccurrence(
        id: 'occ_early',
        activityKindId: 'kind_walking',
        dateIso: '2026-08-20',
        startTime: '06:30',
        status: MovementOccurrenceStatus.planned,
        origin: MovementOrigin.template,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await service.scheduleSessionReminder(
        occurrence: occ,
        minutesBefore: 15,
      );

      expect(capturedReq, isNotNull);
      expect(capturedReq!.scheduledAt.hour, equals(8));
      expect(capturedReq!.scheduledAt.minute, equals(0));
    });

    test('2. Late notification at or after 22:00 is clamped to 21:59', () async {
      NotificationRequest? capturedReq;
      final service = MovementNotificationService(
        scheduleFn: (req) async {
          capturedReq = req;
          return true;
        },
      );

      final occ = MovementOccurrence(
        id: 'occ_late',
        activityKindId: 'kind_walking',
        dateIso: '2026-08-20',
        startTime: '23:00',
        status: MovementOccurrenceStatus.planned,
        origin: MovementOrigin.template,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await service.scheduleSessionReminder(
        occurrence: occ,
        minutesBefore: 15,
      );

      expect(capturedReq, isNotNull);
      expect(capturedReq!.scheduledAt.hour, equals(21));
      expect(capturedReq!.scheduledAt.minute, equals(59));
    });

    test('3. clampNotificationHour utility behaves correctly across boundary hours', () {
      final early = DateTime(2026, 8, 20, 5, 15);
      final clampedEarly = MovementNotificationService.clampNotificationHour(early);
      expect(clampedEarly.hour, equals(8));
      expect(clampedEarly.minute, equals(0));

      final normal = DateTime(2026, 8, 20, 14, 30);
      final clampedNormal = MovementNotificationService.clampNotificationHour(normal);
      expect(clampedNormal.hour, equals(14));
      expect(clampedNormal.minute, equals(30));

      final lateTime = DateTime(2026, 8, 20, 23, 10);
      final clampedLate = MovementNotificationService.clampNotificationHour(lateTime);
      expect(clampedLate.hour, equals(21));
      expect(clampedLate.minute, equals(59));
    });
  });
}
