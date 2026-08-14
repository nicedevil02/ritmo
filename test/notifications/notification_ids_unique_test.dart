import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/notifications/notification_ids.dart';

void main() {
  group('N0-6 Notification IDs Uniqueness Tests', () {
    test('all registered notification integer IDs are unique without any collision', () {
      const allIds = NotificationIds.all;
      final uniqueIds = allIds.toSet();

      expect(
        allIds.length,
        equals(uniqueIds.length),
        reason: 'Duplicate notification IDs found! All IDs must be unique across services.',
      );

      // Verify specific expected values are distinct
      expect(NotificationIds.cyclePill, isNot(equals(NotificationIds.cyclePeriod)));
      expect(NotificationIds.sleepWinddown, isNot(equals(NotificationIds.weeklyBackup)));
      expect(NotificationIds.sleepWinddown, equals(3001));
      expect(NotificationIds.weeklyBackup, equals(3002));
      expect(NotificationIds.persistentStatus, equals(7777));
      expect(NotificationIds.summaryGroup, equals(8888));
      expect(NotificationIds.testAlarm, equals(9999));
    });
  });
}
