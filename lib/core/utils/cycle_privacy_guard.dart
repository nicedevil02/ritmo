// C-11, C-41: CyclePrivacyGuard with explicit CycleAudience enum and canonical user_gender matching.
enum CycleAudience { eligible, notEligible, unknown }

class CyclePrivacyGuard {
  const CyclePrivacyGuard._();

  static const Set<String> _eligibleGenders = {
    'FEMALE',
    'WOMAN',
    'ZAN',
    '\u0632\u0646',
    '\u062E\u0627\u0646\u0645',
  };

  static const Set<String> _notEligibleGenders = {
    'MALE',
    'MAN',
    'MARD',
    '\u0645\u0631\u062F',
    '\u0622\u0642\u0627',
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
