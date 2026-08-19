import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/features/cycle/logic/cycle_privacy_text.dart';

void main() {
  group('CyclePrivacyText Privacy & Neutrality Enforcement', () {
    const forbiddenWords = [
      'پریود',
      'قاعدگی',
      'چرخه',
      'سیکل',
      'خونریزی',
      'period',
      'cycle',
      'menstrual',
      'pregnancy',
    ];

    final List<String> allTexts = [
      CyclePrivacyText.osPublicTitle,
      CyclePrivacyText.osPublicBody,
      CyclePrivacyText.osRedactedTitle,
      CyclePrivacyText.osRedactedBody,
      CyclePrivacyText.leadReminderTitle,
      CyclePrivacyText.leadReminderBody(2),
      CyclePrivacyText.startConfirmTitle,
      CyclePrivacyText.startConfirmBody,
      CyclePrivacyText.endConfirmTitle,
      CyclePrivacyText.endConfirmBody,
      CyclePrivacyText.prolongedTitle,
      CyclePrivacyText.prolongedBody,
      CyclePrivacyText.inboxMaskedTitle,
      CyclePrivacyText.inboxMaskedBody,
    ];

    for (final text in allTexts) {
      test('Text "$text" must NOT contain any explicit or forbidden words', () {
        final lower = text.toLowerCase();
        for (final forbidden in forbiddenWords) {
          expect(
            lower.contains(forbidden.toLowerCase()),
            isFalse,
            reason: 'Text "$text" contains forbidden word "$forbidden"',
          );
        }
      });
    }
  });
}
