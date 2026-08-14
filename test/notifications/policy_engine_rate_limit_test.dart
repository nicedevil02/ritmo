import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/notifications/notification_channel.dart';
import 'package:ritmo/core/notifications/notification_policy.dart';
import 'package:ritmo/core/notifications/notification_policy_engine.dart';
import 'package:ritmo/core/notifications/notification_request.dart';

void main() {
  group('N1-5 Policy Engine Rate Limit Tests', () {
    final now = DateTime(2026, 8, 15, 14, 30);

    test('with max_non_essential_per_hour = 2, 3rd non-essential request in same hour is deferred', () {
      final policy = NotificationPolicy(
        masterEnabled: true,
        quietHoursEnabled: false,
        maxNonEssentialPerHour: 2,
        recentNonEssentialFiredTimes: [
          now.subtract(const Duration(minutes: 40)), // 13:50
          now.subtract(const Duration(minutes: 20)), // 14:10
        ],
      );

      final req3 = NotificationRequest(
        id: 'req_routine_3',
        channel: NotificationChannelId.routine,
        scheduledAt: now,
        title: 'استراحت کوتاه',
        sourceSystem: 'routines',
      );

      final decision = NotificationPolicyEngine.decide(req3, policy, now);

      expect(decision.isDeferred, isTrue);
      // Defer until 1 hour after the earliest fire (13:50 + 1h = 14:50)
      expect(decision.deferUntil, equals(now.subtract(const Duration(minutes: 40)).add(const Duration(hours: 1))));
    });

    test('critical channel is NOT throttled by non-essential rate limit', () {
      final policy = NotificationPolicy(
        masterEnabled: true,
        quietHoursEnabled: false,
        maxNonEssentialPerHour: 2,
        recentNonEssentialFiredTimes: [
          now.subtract(const Duration(minutes: 40)),
          now.subtract(const Duration(minutes: 20)),
          now.subtract(const Duration(minutes: 5)),
        ],
      );

      final criticalReq = NotificationRequest(
        id: 'req_critical_urgent',
        channel: NotificationChannelId.critical,
        scheduledAt: now,
        title: 'مصرف داروی قلبی',
        sourceSystem: 'medical',
      );

      final decision = NotificationPolicyEngine.decide(criticalReq, policy, now);

      expect(decision.isAllowed, isTrue);
    });
  });
}
