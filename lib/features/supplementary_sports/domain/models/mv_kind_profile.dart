import 'package:flutter/foundation.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/mv_enums.dart';

/// مدل مشخصات و پروفایل فیزیولوژیک ورزش (mv_kind_profile)
@immutable
class MvKindProfile {
  final String kindCode;
  final List<String> primaryMuscles;
  final int neuroCost; // 1..3
  final int recoveryHours;
  final List<String> complementFocus;
  final List<String> prehabTags;
  final MvIntensityTier recommendedTierBefore;
  final MvIntensityTier recommendedTierAfter;

  const MvKindProfile({
    required this.kindCode,
    required this.primaryMuscles,
    required this.neuroCost,
    required this.recoveryHours,
    required this.complementFocus,
    this.prehabTags = const [],
    this.recommendedTierBefore = MvIntensityTier.light,
    this.recommendedTierAfter = MvIntensityTier.light,
  });

  /// تبدیل رشتهٔ با کاما جداشده به لیست تمیز
  static List<String> _parseCsv(dynamic raw) {
    if (raw == null) return const [];
    final str = raw.toString().trim();
    if (str.isEmpty || str == 'none') return const [];
    return str
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty && s != 'none')
        .toList();
  }

  static String _joinCsv(List<String> list) {
    if (list.isEmpty) return 'none';
    return list.join(',');
  }

  static MvIntensityTier _parseTier(dynamic raw) {
    final str = raw?.toString().toLowerCase() ?? 'light';
    if (str == 'hard') return MvIntensityTier.hard;
    if (str == 'moderate') return MvIntensityTier.moderate;
    return MvIntensityTier.light;
  }

  static String _tierToString(MvIntensityTier tier) {
    switch (tier) {
      case MvIntensityTier.hard:
        return 'hard';
      case MvIntensityTier.moderate:
        return 'moderate';
      case MvIntensityTier.light:
        return 'light';
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'kindCode': kindCode,
      'primaryMuscles': _joinCsv(primaryMuscles),
      'neuroCost': neuroCost,
      'recoveryHours': recoveryHours,
      'complementFocus': _joinCsv(complementFocus),
      'prehabTags': prehabTags.isEmpty ? null : _joinCsv(prehabTags),
      'recommendedTierBefore': _tierToString(recommendedTierBefore),
      'recommendedTierAfter': _tierToString(recommendedTierAfter),
    };
  }

  factory MvKindProfile.fromMap(Map<String, dynamic> map) {
    return MvKindProfile(
      kindCode: map['kindCode'] as String,
      primaryMuscles: _parseCsv(map['primaryMuscles']),
      neuroCost: (map['neuroCost'] as num?)?.toInt() ?? 1,
      recoveryHours: (map['recoveryHours'] as num?)?.toInt() ?? 0,
      complementFocus: _parseCsv(map['complementFocus']),
      prehabTags: _parseCsv(map['prehabTags']),
      recommendedTierBefore: _parseTier(map['recommendedTierBefore']),
      recommendedTierAfter: _parseTier(map['recommendedTierAfter']),
    );
  }

  MvKindProfile copyWith({
    String? kindCode,
    List<String>? primaryMuscles,
    int? neuroCost,
    int? recoveryHours,
    List<String>? complementFocus,
    List<String>? prehabTags,
    MvIntensityTier? recommendedTierBefore,
    MvIntensityTier? recommendedTierAfter,
  }) {
    return MvKindProfile(
      kindCode: kindCode ?? this.kindCode,
      primaryMuscles: primaryMuscles ?? this.primaryMuscles,
      neuroCost: neuroCost ?? this.neuroCost,
      recoveryHours: recoveryHours ?? this.recoveryHours,
      complementFocus: complementFocus ?? this.complementFocus,
      prehabTags: prehabTags ?? this.prehabTags,
      recommendedTierBefore:
          recommendedTierBefore ?? this.recommendedTierBefore,
      recommendedTierAfter: recommendedTierAfter ?? this.recommendedTierAfter,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MvKindProfile &&
          runtimeType == other.runtimeType &&
          kindCode == other.kindCode &&
          listEquals(primaryMuscles, other.primaryMuscles) &&
          neuroCost == other.neuroCost &&
          recoveryHours == other.recoveryHours &&
          listEquals(complementFocus, other.complementFocus) &&
          listEquals(prehabTags, other.prehabTags) &&
          recommendedTierBefore == other.recommendedTierBefore &&
          recommendedTierAfter == other.recommendedTierAfter;

  @override
  int get hashCode =>
      kindCode.hashCode ^
      Object.hashAll(primaryMuscles) ^
      neuroCost.hashCode ^
      recoveryHours.hashCode ^
      Object.hashAll(complementFocus) ^
      Object.hashAll(prehabTags) ^
      recommendedTierBefore.hashCode ^
      recommendedTierAfter.hashCode;
}
