// C-05..C-08: Unit tests for CycleLockService
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/services/secure_key_store.dart';
import 'package:ritmo/features/cycle/logic/cycle_lock_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  FlutterSecureStorage.setMockInitialValues({});

  final service = CycleLockService.instance;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    await service.clearPin();
  });

  tearDown(() async {
    await service.clearPin();
  });

  group('CycleLockService Security Tests', () {
    test('setPin stores hashed PIN and salt in SecureKeyStore, not plaintext (C-06)', () async {
      const pin = '1234';
      await service.setPin(pin);

      // Verify PIN hash exists
      final hasPin = await service.hasCyclePin();
      expect(hasPin, isTrue);

      // Verify stored value is not raw PIN
      final storedHash = await SecureKeyStore.getKey('cycle_lock_pin_hash');
      expect(storedHash, isNotNull);
      expect(storedHash, isNot(equals(pin)));
      expect(storedHash!.length, greaterThanOrEqualTo(32));
    });

    test('verifyPin accepts correct PIN and rejects wrong PIN (C-06, C-07)', () async {
      await service.setPin('5678');

      expect(await service.verifyPin('5678'), isTrue);
      expect(await service.verifyPin('0000'), isFalse);
      expect(await service.verifyPin('5679'), isFalse);
    });

    test('verifyPin triggers lockout after 5 failed attempts (C-08)', () async {
      await service.setPin('4321');

      // 4 wrong attempts - no lockout yet
      for (int i = 0; i < 4; i++) {
        expect(await service.verifyPin('0000'), isFalse);
        expect(await service.isLockedOut(), isFalse);
      }

      // 5th wrong attempt triggers lockout
      expect(await service.verifyPin('0000'), isFalse);
      expect(await service.isLockedOut(), isTrue);
      expect(await service.remainingLockoutSeconds(), greaterThan(0));

      // Even correct PIN is rejected during lockout
      expect(await service.verifyPin('4321'), isFalse);
    });

    test('successful verifyPin resets failed attempts counter (C-08)', () async {
      await service.setPin('9876');

      // 3 wrong attempts
      for (int i = 0; i < 3; i++) {
        await service.verifyPin('1111');
      }

      // 1 correct attempt resets counter
      expect(await service.verifyPin('9876'), isTrue);

      final failedAttempts = await SecureKeyStore.getKey('cycle_lock_failed_attempts');
      expect(failedAttempts, equals('0'));
    });

    test('clearPin completely removes hash and lockout state (C-06, C-07)', () async {
      await service.setPin('1122');
      expect(await service.hasCyclePin(), isTrue);

      await service.clearPin();
      expect(await service.hasCyclePin(), isFalse);
      expect(await service.isLockedOut(), isFalse);
    });
  });
}
