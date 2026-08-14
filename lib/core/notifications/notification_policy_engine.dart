import 'package:ritmo/core/notifications/notification_policy.dart';
import 'package:ritmo/core/notifications/notification_request.dart';

/// Pure, stateless decision engine for notification delivery, deferral, redaction, and suppression.
/// Contains ZERO database queries, ZERO DateTime.now() calls, and ZERO service locator dependencies.
abstract final class NotificationPolicyEngine {
  /// Evaluates the given [req] against the [policy] at the specified [now] point in time.
  static NotificationDecision decide(
    NotificationRequest req,
    NotificationPolicy policy,
    DateTime now,
  ) {
    // 1. Master switch check: only critical channel can bypass master disabled
    if (!policy.masterEnabled) {
      if (!req.channel.bypassesQuietHours) {
        return const NotificationDecision.suppress(reason: 'master_disabled');
      }
    }

    // 2. Calendar exception behavior check
    if (policy.calendarExceptionBehavior == 'SILENCE_ALL') {
      if (!req.channel.bypassesQuietHours) {
        return const NotificationDecision.suppress(reason: 'calendar_silence_all');
      }
    } else if (policy.calendarExceptionBehavior == 'ESSENTIAL_ONLY') {
      if (!req.channel.isEssential) {
        return const NotificationDecision.suppress(reason: 'calendar_essential_only');
      }
    }

    // 3. Quiet Hours check (bypassed by critical channel)
    if (policy.quietHoursEnabled && !req.channel.bypassesQuietHours) {
      final quietCheckTime = req.scheduledAt.isAfter(now) ? req.scheduledAt : now;
      if (isInQuietHours(quietCheckTime, policy.quietHoursStart, policy.quietHoursEnd)) {
        final exitTime = calculateQuietHoursExit(quietCheckTime, policy.quietHoursStart, policy.quietHoursEnd);
        return NotificationDecision.defer(until: exitTime);
      }
    }

    // 4. Rate limiting for non-essential notifications
    if (policy.maxNonEssentialPerHour > 0 && !req.channel.bypassesQuietHours) {
      final oneHourAgo = now.subtract(const Duration(hours: 1));
      final recentFires = policy.recentNonEssentialFiredTimes
          .where((t) => t.isAfter(oneHourAgo) && !t.isAfter(now))
          .toList()
        ..sort();

      if (recentFires.length >= policy.maxNonEssentialPerHour) {
        final earliest = recentFires.first;
        final deferUntil = earliest.add(const Duration(hours: 1));
        return NotificationDecision.defer(until: deferUntil);
      }
    }

    // 5. Privacy classification evaluation
    switch (req.privacy) {
      case NotificationPrivacy.hidden:
        return const NotificationDecision.suppress(reason: 'privacy_hidden');
      case NotificationPrivacy.redacted:
      case NotificationPrivacy.locked:
        return NotificationDecision.redact(
          title: req.redactedTitle!,
          body: req.redactedBody,
        );
      case NotificationPrivacy.none:
        return const NotificationDecision.allow();
    }
  }

  /// Determines whether [time] falls within [startStr] ("HH:mm") and [endStr] ("HH:mm").
  static bool isInQuietHours(DateTime time, String startStr, String endStr) {
    final startParts = startStr.split(':');
    final endParts = endStr.split(':');
    final startH = int.tryParse(startParts[0]) ?? 0;
    final startM = int.tryParse(startParts.length > 1 ? startParts[1] : '0') ?? 0;
    final endH = int.tryParse(endParts[0]) ?? 7;
    final endM = int.tryParse(endParts.length > 1 ? endParts[1] : '0') ?? 0;

    final timeMin = time.hour * 60 + time.minute;
    final startMin = startH * 60 + startM;
    final endMin = endH * 60 + endM;

    if (startMin == endMin) {
      return false; // Disabled when start and end are equal
    }

    if (startMin < endMin) {
      // Same-day interval (e.g. 01:00 to 06:00)
      return timeMin >= startMin && timeMin < endMin;
    } else {
      // Midnight-crossing interval (e.g. 23:00 to 07:00)
      return timeMin >= startMin || timeMin < endMin;
    }
  }

  /// Calculates the next DateTime when Quiet Hours will end for a given [time].
  static DateTime calculateQuietHoursExit(DateTime time, String startStr, String endStr) {
    final startParts = startStr.split(':');
    final endParts = endStr.split(':');
    final startH = int.tryParse(startParts[0]) ?? 0;
    final startM = int.tryParse(startParts.length > 1 ? startParts[1] : '0') ?? 0;
    final endH = int.tryParse(endParts[0]) ?? 7;
    final endM = int.tryParse(endParts.length > 1 ? endParts[1] : '0') ?? 0;

    final timeMin = time.hour * 60 + time.minute;
    final startMin = startH * 60 + startM;

    if (startMin >= endH * 60 + endM) {
      // Crosses midnight (e.g. 23:00 to 07:00)
      if (timeMin >= startMin) {
        // We are before midnight, exit is tomorrow at endH:endM
        final tomorrow = time.add(const Duration(days: 1));
        return DateTime(tomorrow.year, tomorrow.month, tomorrow.day, endH, endM);
      } else {
        // We are after midnight, exit is today at endH:endM
        return DateTime(time.year, time.month, time.day, endH, endM);
      }
    } else {
      // Same-day interval (e.g. 01:00 to 07:00)
      return DateTime(time.year, time.month, time.day, endH, endM);
    }
  }
}
