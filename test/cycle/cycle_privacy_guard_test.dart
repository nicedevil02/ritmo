// C-11: Tests for CyclePrivacyGuard and audience determination
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/utils/cycle_privacy_guard.dart';

void main() {
  group('CyclePrivacyGuard (C-11)', () {
    test('eligible female users can view cycle module', () {
      expect(CyclePrivacyGuard.isVisible({'user_gender': 'FEMALE'}), isTrue);
      expect(CyclePrivacyGuard.isVisible({'user_gender': 'WOMAN'}), isTrue);
      expect(CyclePrivacyGuard.isVisible({'user_gender': 'ZAN'}), isTrue);
      expect(CyclePrivacyGuard.isVisible({'user_gender': 'زن'}), isTrue);
      expect(CyclePrivacyGuard.isVisible({'user_gender': 'خانم'}), isTrue);
    });

    test('male users cannot view cycle module', () {
      expect(CyclePrivacyGuard.isVisible({'user_gender': 'MALE'}), isFalse);
      expect(CyclePrivacyGuard.isVisible({'user_gender': 'MAN'}), isFalse);
      expect(CyclePrivacyGuard.isVisible({'user_gender': 'MARD'}), isFalse);
      expect(CyclePrivacyGuard.isVisible({'user_gender': 'مرد'}), isFalse);
      expect(CyclePrivacyGuard.isVisible({'user_gender': 'آقا'}), isFalse);
    });

    test(
      'conflicting or stale profile keys are not substring matched over canonical key',
      () {
        // When canonical user_gender is MALE, legacy profile_gender with FEMALE must NOT leak access
        final settings = {
          'user_gender': 'MALE',
          'profile_gender': 'FEMALE',
          'ss_onboarding_gender': 'FEMALE',
        };
        expect(CyclePrivacyGuard.isVisible(settings), isFalse);
        expect(
          CyclePrivacyGuard.getAudience(settings),
          equals(CycleAudience.notEligible),
        );
      },
    );

    test('unset, unknown, or empty gender fails closed to hidden', () {
      expect(CyclePrivacyGuard.isVisible({}), isFalse);
      expect(CyclePrivacyGuard.isVisible({'user_gender': ''}), isFalse);
      expect(CyclePrivacyGuard.isVisible({'user_gender': 'UNSET'}), isFalse);
      expect(CyclePrivacyGuard.isVisible({'user_gender': 'UNKNOWN'}), isFalse);
      expect(
        CyclePrivacyGuard.getAudience({'user_gender': 'UNSET'}),
        equals(CycleAudience.unknown),
      );
    });

    test(
      'random strings containing substrings like zan or female are rejected',
      () {
        // Substring attacks (e.g. name "Suzan" or localized words)
        expect(CyclePrivacyGuard.isVisible({'user_gender': 'SUZAN'}), isFalse);
        expect(CyclePrivacyGuard.isVisible({'user_gender': 'TARZAN'}), isFalse);
        expect(CyclePrivacyGuard.isVisible({'user_gender': 'BAZAN'}), isFalse);
      },
    );
  });
}
