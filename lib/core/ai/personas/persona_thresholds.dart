/// Single source of truth for numeric thresholds used across Persona charters and logic.
class PersonaThresholds {
  const PersonaThresholds._();

  /// Sleep debt threshold in minutes to trigger recovery warnings in sleep analysis.
  static const int sleepDebtWarningMinutes = 60;

  /// Severe sleep debt threshold in minutes (e.g. sports intensity reduction).
  static const int sleepDebtSevereMinutes = 90;

  /// Sleep consistency score (0-100) below which consistency coaching activates.
  static const int sleepConsistencyThreshold = 60;

  /// Days of inactivity before a goal is considered dead/stagnant.
  static const int deadGoalInactiveDays = 14;

  /// Days of inactivity before a multi-session course is considered abandoned.
  static const int abandonedCourseInactiveDays = 21;

  /// Maximum recommended weekly sports volume increase percentage.
  static const int sportsWeeklyVolumeMaxIncreasePct = 10;

  /// Minimum number of completed cycles before predictions are considered meaningful.
  static const int minCyclesForPrediction = 3;

  /// Notes count thresholds for confidence ladders.
  static const int notesLowConfidenceCount = 5;
  static const int notesHighConfidenceCount = 20;
}
