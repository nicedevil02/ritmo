import 'package:flutter/foundation.dart';
import 'package:ritmo/core/notifications/notification_channel.dart';

/// Privacy levels for notifications.
enum NotificationPrivacy {
  /// Public/Normal notification, full text is visible on lockscreen.
  none,

  /// Redacted notification: disguised/sanitized text on lockscreen ('ریتمو: یک یادآوری داری'), full text inside app.
  redacted,

  /// Locked notification: blurred inside app inbox until biometric/PIN authenticated.
  locked,

  /// Hidden notification: NO OS notification is created; only visible in inbox after authentication.
  hidden;

  bool get requiresRedaction => this != none;
  bool get suppressesOsNotification => this == hidden;
}

/// An immutable request to deliver or schedule a notification through [NotificationGateway].
@immutable
class NotificationRequest {
  final String id;
  final NotificationChannelId channel;
  final DateTime scheduledAt;
  final String title;
  final String? body;
  final NotificationPrivacy privacy;
  final String? redactedTitle;
  final String? redactedBody;
  final String sourceSystem;
  final String? entityId;
  final Map<String, dynamic>? payload;

  NotificationRequest({
    required this.id,
    required this.channel,
    required this.scheduledAt,
    required this.title,
    this.body,
    this.privacy = NotificationPrivacy.none,
    this.redactedTitle,
    this.redactedBody,
    required this.sourceSystem,
    this.entityId,
    this.payload,
  }) : assert(
          privacy == NotificationPrivacy.none || (redactedTitle != null && redactedTitle.trim().isNotEmpty),
          'Private notification request (privacy: $privacy) requires a non-empty redactedTitle.',
        );

  NotificationRequest copyWith({
    String? id,
    NotificationChannelId? channel,
    DateTime? scheduledAt,
    String? title,
    String? body,
    NotificationPrivacy? privacy,
    String? redactedTitle,
    String? redactedBody,
    String? sourceSystem,
    String? entityId,
    Map<String, dynamic>? payload,
  }) {
    return NotificationRequest(
      id: id ?? this.id,
      channel: channel ?? this.channel,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      title: title ?? this.title,
      body: body ?? this.body,
      privacy: privacy ?? this.privacy,
      redactedTitle: redactedTitle ?? this.redactedTitle,
      redactedBody: redactedBody ?? this.redactedBody,
      sourceSystem: sourceSystem ?? this.sourceSystem,
      entityId: entityId ?? this.entityId,
      payload: payload ?? this.payload,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotificationRequest &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          channel == other.channel &&
          scheduledAt.millisecondsSinceEpoch == other.scheduledAt.millisecondsSinceEpoch &&
          title == other.title &&
          body == other.body &&
          privacy == other.privacy &&
          redactedTitle == other.redactedTitle &&
          redactedBody == other.redactedBody &&
          sourceSystem == other.sourceSystem &&
          entityId == other.entityId;

  @override
  int get hashCode => Object.hash(
        id,
        channel,
        scheduledAt.millisecondsSinceEpoch,
        title,
        body,
        privacy,
        redactedTitle,
        redactedBody,
        sourceSystem,
        entityId,
      );
}
