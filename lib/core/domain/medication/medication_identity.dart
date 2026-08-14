/// Single source of truth for "is this `routines` row a medication?".
///
/// Medications are stored in the shared `routines` table, so two different
/// agenda sources need the exact same answer: the medicine source owns them and
/// expands them into per-dose items, while the routine source must skip them or
/// every dose is rendered twice. Keeping the predicate in one place is what
/// stops those two views from drifting apart again.
///
/// `MedicationSaveHelper` still writes `itemType = 'ROUTINE'` (MED-10), so the
/// canonical `'MEDICINE'` marker alone is not enough until the backfill
/// migration lands. Until then the deterministic id prefix and the
/// medication-only columns identify existing rows.
///
/// C-FIX-5 — why the columns are compared against zero and not against null:
/// `routines` declares `medStockCount`, `medRefillThreshold`,
/// `minIntervalHours` and `maxDosesPerDay` as `INTEGER NOT NULL DEFAULT 0`.
/// A null check therefore matched *every* routine ever created, so the routine
/// agenda source classified all of them as medications and skipped them, and
/// the Calendar rendered an empty day while the routine list stayed full.
/// Absence is encoded as 0 in this schema, so only a positive value is
/// evidence of a medication.
class MedicationIdentity {
  const MedicationIdentity._();

  /// Canonical `routines.itemType` value for a medication.
  static const String itemType = 'MEDICINE';

  /// Prefix `MedicationSaveHelper` uses when it mints a routine id.
  static const String routineIdPrefix = 'routine_med_';

  /// `routines.routineType` value for as-needed (PRN) medication. A PRN dose
  /// has no scheduled slot, so it can never be "due" or "missed".
  static const String asNeededRoutineType = 'asNeeded';

  /// Columns only a medication fills in. Each defaults to 0 for plain routines.
  static const List<String> medicationColumns = <String>[
    'medStockCount',
    'medRefillThreshold',
    'minIntervalHours',
    'maxDosesPerDay',
  ];

  /// SQL fragment for a `WHERE` clause on the `routines` table.
  ///
  /// Must stay the exact twin of [isMedicationRoutine].
  static const String sqlPredicate =
      "(itemType = '$itemType'"
      " OR id LIKE '$routineIdPrefix%'"
      " OR COALESCE(medStockCount, 0) > 0"
      " OR COALESCE(medRefillThreshold, 0) > 0"
      " OR COALESCE(minIntervalHours, 0) > 0"
      " OR COALESCE(maxDosesPerDay, 0) > 0)";

  /// In-memory twin of [sqlPredicate] for rows that are already loaded.
  static bool isMedicationRoutine(Map<String, dynamic> routine) {
    if (routine['itemType'] == itemType) return true;

    final id = routine['id'];
    if (id is String && id.startsWith(routineIdPrefix)) return true;

    for (final column in medicationColumns) {
      if (_isPositive(routine[column])) return true;
    }

    return false;
  }

  /// Tolerates the int/String/bool shapes sqflite and imports can produce.
  static bool _isPositive(Object? value) {
    if (value == null) return false;
    if (value is num) return value > 0;
    if (value is bool) return value;
    final parsed = num.tryParse(value.toString().trim());
    return parsed != null && parsed > 0;
  }

  static bool isAsNeeded(Map<String, dynamic> routine) =>
      routine['routineType'] == asNeededRoutineType;
}
