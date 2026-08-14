import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/notifications/notification_channel.dart';
import 'package:ritmo/core/notifications/notification_policy.dart';
import 'package:ritmo/core/notifications/notification_policy_engine.dart';
import 'package:ritmo/core/notifications/notification_request.dart';

void main() {
  group('N1-3 & N1-5 Policy Engine Privacy Tests', () {
    const policy = NotificationPolicy(
      masterEnabled: true,
      quietHoursEnabled: false,
      maxNonEssentialPerHour: 0,
    );

    final now = DateTime(2026, 8, 15, 12, 0);

    test('privacy = hidden produces suppress decision without OS notification', () {
      final req = NotificationRequest(
        id: 'req_hidden_cycle',
        channel: NotificationChannelId.privateChannel,
        scheduledAt: now,
        title: 'ثبت علائم چرخه',
        privacy: NotificationPrivacy.hidden,
        redactedTitle: 'ریتمو: اعلان محرمانه',
        sourceSystem: 'cycle',
      );

      final decision = NotificationPolicyEngine.decide(req, policy, now);

      expect(decision.isSuppressed, isTrue);
      expect(decision.suppressionReason, equals('privacy_hidden'));
    });

    test('privacy = redacted produces redact decision with disguised title', () {
      final req = NotificationRequest(
        id: 'req_redacted_cycle',
        channel: NotificationChannelId.privateChannel,
        scheduledAt: now,
        title: 'لوازم شخصیات رو چک کن 💜',
        privacy: NotificationPrivacy.redacted,
        redactedTitle: 'ریتمو: یک یادآوری داری 🌸',
        redactedBody: 'برای مشاهده باز کنید',
        sourceSystem: 'cycle',
      );

      final decision = NotificationPolicyEngine.decide(req, policy, now);

      expect(decision.isRedacted, isTrue);
      expect(decision.redactedTitle, equals('ریتمو: یک یادآوری داری 🌸'));
      expect(decision.redactedBody, equals('برای مشاهده باز کنید'));
    });

    test('privacy = locked produces redact decision with disguised title for lockscreen', () {
      final req = NotificationRequest(
        id: 'req_locked_note',
        channel: NotificationChannelId.privateChannel,
        scheduledAt: now,
        title: 'یادداشت شخصی محرمانه',
        privacy: NotificationPrivacy.locked,
        redactedTitle: 'ریتمو: یادآوری خصوصی',
        sourceSystem: 'notes',
      );

      final decision = NotificationPolicyEngine.decide(req, policy, now);

      expect(decision.isRedacted, isTrue);
      expect(decision.redactedTitle, equals('ریتمو: یادآوری خصوصی'));
    });
  });
}
