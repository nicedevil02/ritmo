import 'package:ritmo/core/logging/ritmo_logger.dart';

/// The behavioral operating mode for a time realm (قلمرو زمانی).
enum RealmMode {
  /// عادی: همه روتین‌ها عبور می‌کنند
  normal,

  /// تمرکز عمیق: فقط روتین‌های ضروری (isEssential) عبور می‌کنند
  focus,

  /// بی‌صدا: روتین‌های غیرضروری مسدود می‌شوند، نوتیفیکیشن‌ها خاموش مگر دارو
  silent,
}

/// Extension providing centralized behavior definitions for [RealmMode].
extension RealmModeBehavior on RealmMode {
  /// Whether non-essential routines should be suppressed in today's active list.
  bool get suppressesNonEssential => switch (this) {
    RealmMode.normal => false,
    RealmMode.focus => true,
    RealmMode.silent => true,
  };

  /// Whether active notifications are completely suppressed (silent mode).
  bool get suppressesNotifications => this == RealmMode.silent;

  /// Whether essential routines are allowed to bypass suppression.
  /// In SILENT mode, essential routines cannot bypass unless they are critical medical.
  bool get allowsEssentialBypass => this != RealmMode.silent;
}

/// Safely parses a raw database or settings string into a [RealmMode].
/// Accepts historical aliases like `'MUTE'` and normalizes unknown values with a warning.
RealmMode parseRealmMode(String? raw) {
  switch (raw?.toUpperCase().trim()) {
    case 'NORMAL':
      return RealmMode.normal;
    case 'FOCUS':
      return RealmMode.focus;
    case 'SILENT':
    case 'MUTE':
      return RealmMode.silent;
    case null:
    case '':
      return RealmMode.normal;
    default:
      RitmoLog.warning('RealmMode', 'مقدار ناشناخته «$raw» → fallback به normal');
      return RealmMode.normal;
  }
}

/// Converts a [RealmMode] into its canonical uppercase string representation.
String realmModeToRaw(RealmMode mode) {
  switch (mode) {
    case RealmMode.focus:
      return 'FOCUS';
    case RealmMode.silent:
      return 'SILENT';
    case RealmMode.normal:
      return 'NORMAL';
  }
}
