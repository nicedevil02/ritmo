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
///
/// B-FIX-EVENT-6 — چرا itemType صریح بر حدسِ ستونی مقدم است:
///
/// C-FIX-5 نیمی از مشکل را حل کرد و سمت نویسنده را دست‌نخورده گذاشت. مسیر
/// عمومی پلنر («کار جدید ← رویداد / وظیفه / یادآور / بازتاب») از
/// `GenericStrategy` رد می‌شود، و آن‌جا `minIntervalHours` و `maxDosesPerDay`
/// از `PlannerSaveContext` با مقدار پیش‌فرض ۴ نوشته می‌شوند — نه صفر. پس هر
/// رویدادی که کاربر می‌ساخت شرط «مثبت‌بودن» این ستون‌ها را داشت، دارو تشخیص
/// داده می‌شد، و این خط در `RoutineAgendaSource.itemsForDate` حذفش می‌کرد:
///
///     if (medicineOwnsDoses && MedicationIdentity.isMedicationRoutine(r))
///
/// منبع دارو هم آن را رندر نمی‌کرد، چون واقعاً دارو نبود. نتیجه دقیقاً همان
/// چیزی بود که کاربر گزارش کرد: رویداد در «مخزن روتین‌ها» دیده می‌شد — چون آن
/// نما مستقیم از جدول `routines` می‌خواند و این محمول را اصلاً ارزیابی
/// نمی‌کند — ولی در هیچ سطحی از تقویم ظاهر نمی‌شد.
///
/// وقتی کاربر صراحتاً نوع آیتم را رویداد/وظیفه/یادآور/بازتاب انتخاب کرده،
/// آن نیت قطعی است و حدسِ مبتنی بر ستون نباید نقضش کند. حدسِ ستونی فقط برای
/// ردیف‌های قدیمیِ `MedicationSaveHelper` (که itemType آن‌ها 'ROUTINE' است)
/// وجود دارد، پس خاموش‌کردنش برای این چهار نوع نمی‌تواند داروی واقعی را پنهان
/// کند. نشانگر canonical و پیشوند شناسه همچنان اول بررسی می‌شوند و برنده‌اند.
class MedicationIdentity {
  const MedicationIdentity._();

  /// Canonical `routines.itemType` value for a medication.
  static const String itemType = 'MEDICINE';

  /// Prefix `MedicationSaveHelper` uses when it mints a routine id.
  static const String routineIdPrefix = 'routine_med_';

  /// `routines.routineType` value for as-needed (PRN) medication. A PRN dose
  /// has no scheduled slot, so it can never be "due" or "missed".
  static const String asNeededRoutineType = 'asNeeded';

  /// Item types the planner writes when the user explicitly chose something
  /// that is not a medication. The column heuristic is suppressed for these
  /// rows — see B-FIX-EVENT-6 in the class doc.
  static const List<String> nonMedicationItemTypes = <String>[
    'EVENT',
    'TASK',
    'REMINDER',
    'REFLECT',
  ];

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
  /// Matches explicit itemType = 'MEDICINE', or legacy rows (itemType is NULL or empty)
  /// that have the routine_med_ prefix or positive medication columns.
  static const String sqlPredicate =
      "(itemType = '$itemType'"
      " OR ((itemType IS NULL OR itemType = '')"
      " AND (id LIKE '$routineIdPrefix%'"
      " OR COALESCE(medStockCount, 0) > 0"
      " OR COALESCE(medRefillThreshold, 0) > 0"
      " OR COALESCE(minIntervalHours, 0) > 0"
      " OR COALESCE(maxDosesPerDay, 0) > 0)))";

  /// In-memory twin of [sqlPredicate] for rows that are already loaded.
  ///
  /// Legacy-only heuristic: if [itemType] has a non-null, non-empty value,
  /// the explicit itemType is definitive and column heuristics are never evaluated.
  static bool isMedicationRoutine(Map<String, dynamic> routine) {
    final rawItemType = routine['itemType']?.toString().trim().toUpperCase();
    if (rawItemType != null && rawItemType.isNotEmpty) {
      return rawItemType == itemType;
    }

    // Legacy-only path (itemType is null or empty):
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
