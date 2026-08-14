import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/notifications/notification_channel.dart';
import 'package:ritmo/core/notifications/notification_policy.dart';
import 'package:ritmo/core/notifications/notification_policy_engine.dart';
import 'package:ritmo/core/notifications/notification_request.dart';

void main() {
  group('N1-5 Policy Engine Quiet Hours Tests', () {
    const policy = NotificationPolicy(
      masterEnabled: true,
      quietHoursEnabled: true,
      quietHoursStart: '23:00',
      quietHoursEnd: '07:00',
      maxNonEssentialPerHour: 0,
    );

    test('routine channel during quiet hours (23:30) is deferred until 07:00 next day', () {
      final now = DateTime(2026, 8, 15, 23, 30);
      final req = NotificationRequest(
        id: 'req_routine_1',
        channel: NotificationChannelId.routine,
        scheduledAt: now,
        title: 'مطالعه شبانه',
        sourceSystem: 'routines',
      );

      final decision = NotificationPolicyEngine.decide(req, policy, now);

      expect(decision.isDeferred, isTrue);
      expect(decision.deferUntil, equals(DateTime(2026, 8, 16, 7, 0)));
    });

    test('routine channel past midnight during quiet hours (03:15) is deferred until 07:00 same day', () {
      final now = DateTime(2026, 8, 16, 3, 15);
      final req = NotificationRequest(
        id: 'req_routine_2',
        channel: NotificationChannelId.routine,
        scheduledAt: now,
        title: 'ورزش سحرگاهی',
        sourceSystem: 'routines',
      );

      final decision = NotificationPolicyEngine.decide(req, policy, now);

      expect(decision.isDeferred, isTrue);
      expect(decision.deferUntil, equals(DateTime(2026, 8, 16, 7, 0)));
    });

    test('critical channel during quiet hours (02:00) bypasses quiet hours and is allowed', () {
      final now = DateTime(2026, 8, 16, 2, 0);
      final req = NotificationRequest(
        id: 'req_critical_med',
        channel: NotificationChannelId.critical,
        scheduledAt: now,
        title: 'مصرف انسولین',
        sourceSystem: 'medical',
      );

      final decision = NotificationPolicyEngine.decide(req, policy, now);

      expect(decision.isAllowed, isTrue);
      expect(decision.type, equals(NotificationDecisionType.allow));
    });

    test('routine channel outside quiet hours (14:00) is allowed immediately', () {
      final now = DateTime(2026, 8, 16, 14, 0);
      final req = NotificationRequest(
        id: 'req_routine_day',
        channel: NotificationChannelId.routine,
        scheduledAt: now,
        title: 'نوشیدن آب',
        sourceSystem: 'routines',
      );

      final decision = NotificationPolicyEngine.decide(req, policy, now);

      expect(decision.isAllowed, isTrue);
    });
  });
}
