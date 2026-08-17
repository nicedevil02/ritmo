// C-11: CyclePrivacyGuard with explicit CycleAudience enum and canonical user_gender matching.
enum CycleAudience { eligible, notEligible, unknown }

class CyclePrivacyGuard {
  const CyclePrivacyGuard._();

  static const Set<String> _eligibleGenders = {
    'FEMALE',
    'WOMAN',
    'ZAN',
    'زن',
    'خانم',
  };

  static const Set<String> _notEligibleGenders = {
    'MALE',
    'MAN',
    'MARD',
    'مرد',
    'آقا',
  };

  /// Evaluates cycle audience eligibility strictly against canonical key `user_gender`.
  /// Exact normalized matching is used (no substring contains).
  static CycleAudience getAudience(Map<String, dynamic> settings) {
    final raw = (settings['user_gender']?.toString() ?? '')
        .trim()
        .toUpperCase();
    if (raw.isEmpty || raw == 'UNSET' || raw == 'UNKNOWN') {
      return CycleAudience.unknown;
    }
    if (_eligibleGenders.contains(raw)) {
      return CycleAudience.eligible;
    }
    if (_notEligibleGenders.contains(raw)) {
      return CycleAudience.notEligible;
    }
    return CycleAudience.unknown;
  }

  /// Returns true ONLY if audience is explicitly eligible.
  /// Fail-closed: returns false for unknown, unset, or ineligible genders.
  static bool isVisible(Map<String, dynamic> settings) {
    return getAudience(settings) == CycleAudience.eligible;
  }
}
