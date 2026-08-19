import 'dart:math';

/// تک‌منبعِ حقیقت برای نام ستون‌های جدول cycle_periods.
/// هر نوشتن یا خواندنی روی این جدول باید از این ثابت‌ها استفاده کند.
/// اگر CycleTables.create عوض شد، این فایل و تست قرارداد باید با آن عوض شوند.
class CyclePeriodContract {
  const CyclePeriodContract._();

  static const String table = 'cycle_periods';

  static const String colId = 'id';
  static const String colStartDate = 'startDate';
  static const String colEndDate = 'endDate';
  static const String colFlowIntensity = 'flowIntensity';
  static const String colIsPredicted = 'isPredicted';
  static const String colNote = 'note';
  static const String colCreatedAt = 'createdAt';
  static const String colUpdatedAt = 'updatedAt';

  static const List<String> allColumns = <String>[
    colId,
    colStartDate,
    colEndDate,
    colFlowIntensity,
    colIsPredicted,
    colNote,
    colCreatedAt,
    colUpdatedAt,
  ];

  /// شناسهٔ یکتا برای ردیف جدید. تصادم دو ضربهٔ هم‌زمان را هم پوشش می‌دهد.
  static String newId() {
    final ms = DateTime.now().millisecondsSinceEpoch;
    final rnd = Random().nextInt(0x10000).toRadixString(16).padLeft(4, '0');
    return 'period_${ms}_$rnd';
  }
}
