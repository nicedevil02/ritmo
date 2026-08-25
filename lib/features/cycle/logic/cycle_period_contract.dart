import 'dart:math';
import 'package:ritmo/features/cycle/logic/cycle_clock.dart';

/// Single source of truth for column names of cycle_periods table.
class CyclePeriodContract {
  const CyclePeriodContract._();

  static const String table = 'cycle_periods';

  static const String colId = 'id';
  static const String colStartDate = 'startDate';
  static const String colEndDate = 'endDate';
  static const String colFlowIntensity = 'flowIntensity';
  static const String colIsPredicted = 'isPredicted';
  static const String colNote = 'note';
  static const String colAutoClosed = 'autoClosed';
  static const String colCreatedAt = 'createdAt';
  static const String colUpdatedAt = 'updatedAt';

  static const List<String> allColumns = <String>[
    colId,
    colStartDate,
    colEndDate,
    colFlowIntensity,
    colIsPredicted,
    colNote,
    colAutoClosed,
    colCreatedAt,
    colUpdatedAt,
  ];

  /// Generates a unique String ID for a new cycle period.
  static String newId() {
    final ms = CycleClock.now.millisecondsSinceEpoch;
    final rnd = Random().nextInt(0x10000).toRadixString(16).padLeft(4, '0');
    return 'period_${ms}_$rnd';
  }
}
