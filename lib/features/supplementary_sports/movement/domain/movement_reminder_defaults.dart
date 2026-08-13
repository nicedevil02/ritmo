// lib/features/supplementary_sports/movement/domain/movement_reminder_defaults.dart

library;

import 'package:ritmo/features/supplementary_sports/movement/domain/movement_kind.dart';

/// Reminder lead time from movement context, not a single hardcoded 15 minutes.
class MovementReminderDefaults {
  const MovementReminderDefaults._();

  static const int meetupMinutes = 60;
  static const int outdoorMinutes = 90;
  static const int venueMinutes = 30;
  static const int homeMinutes = 10;

  static int minutesFor(MovementKind kind) {
    if (kind.isSocial) return meetupMinutes;
    if (kind.isOutdoor) return outdoorMinutes;
    if (kind.needsVenue) return venueMinutes;
    return homeMinutes;
  }

  static String labelFa(int minutes) {
    if (minutes <= 0) return 'بدون یادآوری';
    if (minutes >= 24 * 60) return 'شب قبل';
    return '$minutes دقیقه قبل';
  }
}
