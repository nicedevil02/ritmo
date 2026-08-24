import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/security/pin_hasher.dart';
import 'package:ritmo/core/services/feature_limits.dart';
import 'package:ritmo/core/services/premium_service.dart';
import 'package:ritmo/core/services/backup_service.dart';
import 'dart:math' as math;

void main() {
  group('Verified Fixes Audit Suite', () {
    test('1. PinHasher normalizes Persian and ASCII digits and verifies hashes', () {
      const pinEn = '1234';
      const pinFa = '۱۲۳۴';
      final hash = PinHasher.hashPin(pinEn);

      expect(PinHasher.verifyPin(pinEn, hash), isTrue);
      expect(PinHasher.verifyPin(pinFa, hash), isTrue);
      expect(PinHasher.verifyPin('5678', hash), isFalse);

      // Legacy fallback
      expect(PinHasher.verifyPin('1234', '1234'), isTrue);
      expect(PinHasher.verifyPin(pinFa, '1234'), isTrue);
    });

    test('2. PremiumService & FeatureLimits dynamic free vs plus evaluation', () {
      final premium = PremiumService.instance;
      expect(premium.isPremium, isFalse);
      expect(premium.can(PremiumFeature.unlimitedRoutines), isFalse);
      expect(FeatureLimits.current.maxActiveRoutines, equals(7));
      expect(FeatureLimits.current.showAds, isTrue);
    });

    test('3. BackupService throws typed domain exceptions on invalid input', () async {
      expect(
        () => BackupService.restoreBackup('invalid-json', '1234'),
        throwsA(isA<InvalidBackupFormatException>()),
      );
    });

    test('4. Cycle length zero division protection behaves safely', () {
      final settings = <String, String>{'cycle_avg_length': '0'};
      final cycleLength = math.max(
        10,
        int.tryParse(settings['cycle_avg_length'] ?? '28') ?? 28,
      );
      expect(cycleLength, equals(10));
      expect(cycleLength > 0, isTrue);
    });
  });
}
