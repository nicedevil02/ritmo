class CyclePrivacyGuard {
  static bool isVisible(Map<String, String> settings) {
    final val1 = (settings['user_gender'] ?? '').trim().toUpperCase();
    final val2 = (settings['ss_onboarding_gender'] ?? '').trim().toUpperCase();
    final val3 = (settings['profile_gender'] ?? '').trim().toUpperCase();
    final combined = '$val1 $val2 $val3';
    return combined.contains('FEMALE') ||
        combined.contains('WOMAN') ||
        combined.contains('ZAN') ||
        combined.contains('زن');
  }
}
