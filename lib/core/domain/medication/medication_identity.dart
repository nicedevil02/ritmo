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
class MedicationIdentity {
  const MedicationIdentity._();

  /// Canonical `routines.itemType` value for a medication.
  static const String itemType = 'MEDICINE';

  /// Prefix `MedicationSaveHelper` uses when it mints a routine id.
  static const String routineIdPrefix = 'routine_med_';

  /// `routines.routineType` value for as-needed (PRN) medication. A PRN dose
  /// has no scheduled slot, so it can never be "due" or "missed".
  static const String asNeededRoutineType = 'asNeeded';

  /// SQL fragment for a `WHERE` clause on the `routines` table.
  static const String sqlPredicate =
      "(itemType = '$itemType'"
      " OR id LIKE '$routineIdPrefix%'"
      " OR medStockCount IS NOT NULL"
      " OR medRefillThreshold IS NOT NULL"
      " OR minIntervalHours IS NOT NULL"
      " OR maxDosesPerDay IS NOT NULL)";

  /// In-memory twin of [sqlPredicate] for rows that are already loaded.
  static bool isMedicationRoutine(Map<String, dynamic> routine) {
    if (routine['itemType'] == itemType) return true;

    final id = routine['id'];
    if (id is String && id.startsWith(routineIdPrefix)) return true;

    return routine['medStockCount'] != null ||
        routine['medRefillThreshold'] != null ||
        routine['minIntervalHours'] != null ||
        routine['maxDosesPerDay'] != null;
  }

  static bool isAsNeeded(Map<String, dynamic> routine) =>
      routine['routineType'] == asNeededRoutineType;
}
