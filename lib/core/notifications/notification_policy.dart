import 'package:flutter/foundation.dart';

/// Immutable configuration snapshot representing user preferences and calendar state
/// used by [NotificationPolicyEngine] to evaluate notification delivery.
@immutable
class NotificationPolicy {
  final bool masterEnabled;
  final bool quietHoursEnabled;
  final String quietHoursStart; // "HH:mm", e.g. "23:00"
  final String quietHoursEnd;   // "HH:mm", e.g. "07:00"
  final int maxNonEssentialPerHour; // 0 = unlimited
  final List<DateTime> recentNonEssentialFiredTimes;
  final String digestMode; // 'standard', 'concise', 'grouped'
  final String calendarExceptionBehavior; // 'NORMAL', 'SILENCE_ALL', 'ESSENTIAL_ONLY'

  const NotificationPolicy({
    this.masterEnabled = true,
    this.quietHoursEnabled = false,
    this.quietHoursStart = '00:00',
    this.quietHoursEnd = '07:00',
    this.maxNonEssentialPerHour = 3,
    this.recentNonEssentialFiredTimes = const [],
    this.digestMode = 'standard',
    this.calendarExceptionBehavior = 'NORMAL',
  });

  NotificationPolicy copyWith({
    bool? masterEnabled,
    bool? quietHoursEnabled,
    String? quietHoursStart,
    String? quietHoursEnd,
    int? maxNonEssentialPerHour,
    List<DateTime>? recentNonEssentialFiredTimes,
    String? digestMode,
    String? calendarExceptionBehavior,
  }) {
    return NotificationPolicy(
      masterEnabled: masterEnabled ?? this.masterEnabled,
      quietHoursEnabled: quietHoursEnabled ?? this.quietHoursEnabled,
      quietHoursStart: quietHoursStart ?? this.quietHoursStart,
      quietHoursEnd: quietHoursEnd ?? this.quietHoursEnd,
      maxNonEssentialPerHour: maxNonEssentialPerHour ?? this.maxNonEssentialPerHour,
      recentNonEssentialFiredTimes: recentNonEssentialFiredTimes ?? this.recentNonEssentialFiredTimes,
      digestMode: digestMode ?? this.digestMode,
      calendarExceptionBehavior: calendarExceptionBehavior ?? this.calendarExceptionBehavior,
    );
  }
}

/// The decision produced by [NotificationPolicyEngine] on how to handle a [NotificationRequest].
enum NotificationDecisionType {
  allow,
  defer,
  redact,
  suppress,
}

@immutable
class NotificationDecision {
  final NotificationDecisionType type;
  final DateTime? deferUntil;
  final String? redactedTitle;
  final String? redactedBody;
  final String? suppressionReason;

  const NotificationDecision.allow()
      : type = NotificationDecisionType.allow,
        deferUntil = null,
        redactedTitle = null,
        redactedBody = null,
        suppressionReason = null;

  const NotificationDecision.defer({required DateTime until})
      : type = NotificationDecisionType.defer,
        deferUntil = until,
        redactedTitle = null,
        redactedBody = null,
        suppressionReason = null;

  const NotificationDecision.redact({
    required String title,
    String? body,
  })  : type = NotificationDecisionType.redact,
        deferUntil = null,
        redactedTitle = title,
        redactedBody = body,
        suppressionReason = null;

  const NotificationDecision.suppress({required String reason})
      : type = NotificationDecisionType.suppress,
        deferUntil = null,
        redactedTitle = null,
        redactedBody = null,
        suppressionReason = reason;

  bool get isAllowed => type == NotificationDecisionType.allow || type == NotificationDecisionType.redact;
  bool get isDeferred => type == NotificationDecisionType.defer;
  bool get isSuppressed => type == NotificationDecisionType.suppress;
  bool get isRedacted => type == NotificationDecisionType.redact;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotificationDecision &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          deferUntil?.millisecondsSinceEpoch == other.deferUntil?.millisecondsSinceEpoch &&
          redactedTitle == other.redactedTitle &&
          redactedBody == other.redactedBody &&
          suppressionReason == other.suppressionReason;

  @override
  int get hashCode => Object.hash(
        type,
        deferUntil?.millisecondsSinceEpoch,
        redactedTitle,
        redactedBody,
        suppressionReason,
      );

  @override
  String toString() {
    return switch (type) {
      NotificationDecisionType.allow => 'NotificationDecision.allow()',
      NotificationDecisionType.defer => 'NotificationDecision.defer(until: $deferUntil)',
      NotificationDecisionType.redact => 'NotificationDecision.redact(title: $redactedTitle, body: $redactedBody)',
      NotificationDecisionType.suppress => 'NotificationDecision.suppress(reason: $suppressionReason)',
    };
  }
}
