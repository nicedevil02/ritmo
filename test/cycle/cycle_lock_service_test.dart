// C-05..C-08: Unit tests for CycleLockService
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/services/secure_key_store.dart';
import 'package:ritmo/features/cycle/logic/cycle_lock_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;
  final service = CycleLockService.instance;

  setUp(() async {
    db = await openDatabase(
      inMemoryDatabasePath,
      version: 1,
      onCreate: (d, v) async {
        await d.execute('''
          CREATE TABLE app_settings (
            key TEXT PRIMARY KEY,
            value TEXT,
            updatedAt INTEGER NOT NULL
          )
        ''');
      },
    );
    await service.clearPin(db);
  });

  tearDown(() async {
    await service.clearPin(db);
    await db.close();
  });

  group('CycleLockService Security Tests', () {
    test('setPin stores hashed PIN and salt in SecureKeyStore, not in app_settings (C-06)', () async {
      const pin = '1234';
      await service.setPin(pin, db);

      // Verify PIN hash exists
      final hasPin = await service.hasCyclePin(db);
      expect(hasPin, isTrue);

      // Verify stored value is not raw PIN
      final storedHash = await SecureKeyStore.getKey('cycle_lock_pin_hash', db);
      expect(storedHash, isNotNull);
      expect(storedHash, isNot(equals(pin)));
      expect(storedHash!.length, greaterThanOrEqualTo(32));

      // Verify app_settings has no plaintext cycle_lock_password or cycle_lock_pin
      final rows = await db.query(
        'app_settings',
        where: "key IN ('cycle_lock_password', 'app_lock_password', 'cycle_lock_pin')",
      );
      expect(rows, isEmpty);
    });

    test('verifyPin accepts correct PIN and rejects wrong PIN (C-06, C-07)', () async {
      await service.setPin('5678', db);

      expect(await service.verifyPin('5678', db), isTrue);
      expect(await service.verifyPin('0000', db), isFalse);
      expect(await service.verifyPin('5679', db), isFalse);
    });

    test('verifyPin triggers lockout after 5 failed attempts (C-08)', () async {
      await service.setPin('4321', db);

      // 4 wrong attempts - no lockout yet
      for (int i = 0; i < 4; i++) {
        expect(await service.verifyPin('0000', db), isFalse);
        expect(await service.isLockedOut(db), isFalse);
      }

      // 5th wrong attempt triggers 30s lockout
      expect(await service.verifyPin('0000', db), isFalse);
      expect(await service.isLockedOut(db), isTrue);
      expect(await service.remainingLockoutSeconds(db), greaterThan(0));

      // Even correct PIN is rejected during lockout
      expect(await service.verifyPin('4321', db), isFalse);
    });

    test('successful verifyPin resets failed attempts counter (C-08)', () async {
      await service.setPin('9876', db);

      // 3 wrong attempts
      for (int i = 0; i < 3; i++) {
        await service.verifyPin('1111', db);
      }

      // 1 correct attempt resets counter
      expect(await service.verifyPin('9876', db), isTrue);

      final failedAttempts = await SecureKeyStore.getKey('cycle_lock_failed_attempts', db);
      expect(failedAttempts, equals('0'));
    });

    test('clearPin completely removes hash and lockout state (C-06, C-07)', () async {
      await service.setPin('1122', db);
      expect(await service.hasCyclePin(db), isTrue);

      await service.clearPin(db);
      expect(await service.hasCyclePin(db), isFalse);
      expect(await service.isLockedOut(db), isFalse);
    });
  });
}
