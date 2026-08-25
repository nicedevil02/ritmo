import 'mv_enums.dart';

/// Single Source of Truth for Personal Records (`movement_pr`).
///
/// Stores PRs for both exercises (`EXERCISE:<exerciseId>`) and general movement activities.
class MvPersonalRecord {
  final String id;
  final String kind; // e.g. 'running', 'cycling', or 'EXERCISE:push_up'
  final MvPrType prType;
  final double value;
  final String? logId;
  final int achievedAt;

  const MvPersonalRecord({
    required this.id,
    required this.kind,
    required this.prType,
    required this.value,
    this.logId,
    required this.achievedAt,
  });

  bool get isExercisePr => kind.startsWith('EXERCISE:');
  String get exerciseId => isExercisePr ? kind.substring('EXERCISE:'.length) : '';
  String get formattedValue => '${value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 1)} ${prType.unitFa}';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'kind': kind,
      'prType': prType.code,
      'value': value,
      'logId': logId,
      'achievedAt': achievedAt,
    };
  }

  factory MvPersonalRecord.fromMap(Map<String, dynamic> map) {
    return MvPersonalRecord(
      id: map['id'] as String,
      kind: map['kind'] as String,
      prType: MvPrType.fromCode(map['prType'] as String?),
      value: (map['value'] as num).toDouble(),
      logId: map['logId'] as String?,
      achievedAt: (map['achievedAt'] as num).toInt(),
    );
  }
}
