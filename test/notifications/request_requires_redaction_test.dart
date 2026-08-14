import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/notifications/notification_channel.dart';
import 'package:ritmo/core/notifications/notification_request.dart';

void main() {
  group('N1-4 NotificationRequest Redaction Assertion Tests', () {
    final now = DateTime(2026, 8, 15, 10, 0);

    test('creating a redacted request with null or empty redactedTitle throws AssertionError', () {
      expect(
        () => NotificationRequest(
          id: 'req_invalid_redacted',
          channel: NotificationChannelId.privateChannel,
          scheduledAt: now,
          title: 'یادداشت بسیار محرمانه',
          privacy: NotificationPrivacy.redacted,
          redactedTitle: null, // Invalid!
          sourceSystem: 'notes',
        ),
        throwsA(isA<AssertionError>()),
      );

      expect(
        () => NotificationRequest(
          id: 'req_invalid_empty',
          channel: NotificationChannelId.privateChannel,
          scheduledAt: now,
          title: 'یادداشت بسیار محرمانه',
          privacy: NotificationPrivacy.locked,
          redactedTitle: '   ', // Invalid!
          sourceSystem: 'notes',
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('creating a none-privacy request without redactedTitle succeeds', () {
      final req = NotificationRequest(
        id: 'req_valid_public',
        channel: NotificationChannelId.routine,
        scheduledAt: now,
        title: 'پیاده‌روی عصرگاهی',
        privacy: NotificationPrivacy.none,
        sourceSystem: 'routines',
      );

      expect(req.title, equals('پیاده‌روی عصرگاهی'));
      expect(req.privacy, equals(NotificationPrivacy.none));
    });

    test('creating a redacted request with non-empty redactedTitle succeeds', () {
      final req = NotificationRequest(
        id: 'req_valid_private',
        channel: NotificationChannelId.privateChannel,
        scheduledAt: now,
        title: 'ثبت دوره ماهانه',
        privacy: NotificationPrivacy.redacted,
        redactedTitle: 'ریتمو: یادآوری روزانه',
        sourceSystem: 'cycle',
      );

      expect(req.redactedTitle, equals('ریتمو: یادآوری روزانه'));
    });
  });
}
