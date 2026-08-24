import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/domain/models/reminder_state.dart';
import 'package:ritmo/core/security/pin_hasher.dart';
import 'package:ritmo/core/utils/ritmo_date.dart';

void main() {
  group('Prompt 035 - RitmoDate & Core Infrastructure Tests', () {
    test('RitmoDate formats DateTime to YYYY-MM-DD correctly', () {
      final dt = DateTime(2026, 7, 27);
      final rDate = RitmoDate(dt);
      expect(rDate.value, equals('2026-07-27'));
      expect(rDate.toString(), equals('2026-07-27'));
    });

    test('RitmoDate parses valid and ISO string dates accurately', () {
      final parsed = RitmoDate.parse('2026-07-27T01:23:01');
      expect(parsed, isNotNull);
      expect(parsed!.value, equals('2026-07-27'));
      expect(parsed.dateTime.year, equals(2026));
      expect(parsed.dateTime.month, equals(7));
      expect(parsed.dateTime.day, equals(27));
    });

    test('RitmoDate date comparison and addition helpers work', () {
      final d1 = RitmoDate(DateTime(2026, 7, 27));
      final d2 = d1.addDays(1);
      final d3 = d1.subtractDays(1);

      expect(d2.value, equals('2026-07-28'));
      expect(d3.value, equals('2026-07-26'));
      expect(d1.isBefore(d2), isTrue);
      expect(d2.isAfter(d1), isTrue);
      expect(d1.isSameDay(RitmoDate(DateTime(2026, 7, 27))), isTrue);
    });

    test('ReminderState enum parses strings cleanly', () {
      expect(ReminderState.parse('CANCELLED'), equals(ReminderState.cancelled));
      expect(ReminderState.parse('cancelled'), equals(ReminderState.cancelled));
      expect(ReminderState.parse('ACTIVE'), equals(ReminderState.active));
      expect(ReminderState.parse('delayed'), equals(ReminderState.delayed));
      expect(ReminderState.parse('expired'), equals(ReminderState.expired));
      expect(ReminderState.parse('invalid_state'), equals(ReminderState.unknown));
    });

    test('ReminderState dbValue output is consistent lowercase', () {
      expect(ReminderState.cancelled.dbValue, equals('cancelled'));
      expect(ReminderState.expired.dbValue, equals('expired'));
      expect(ReminderState.active.dbValue, equals('active'));
    });
  });

  group('T1 - PinHasher Hardening & Multi-Format Verification', () {
    test('hashPin generates valid v2 format with unique salts', () {
      final hash1 = PinHasher.hashPin('1234');
      final hash2 = PinHasher.hashPin('1234');

      expect(hash1.startsWith('v2:'), isTrue);
      expect(hash2.startsWith('v2:'), isTrue);
      expect(hash1, isNot(equals(hash2)), reason: 'Random salt ensures distinct hashes');

      final parts = hash1.split(':');
      expect(parts.length, equals(3));
      expect(parts[1].length, equals(32), reason: '16-byte hex salt');
      expect(parts[2].length, equals(64), reason: '32-byte hex derived key');
    });

    test('verifyPin correctly matches correct and incorrect pins in v2 format', () {
      final hash = PinHasher.hashPin('5678');
      expect(PinHasher.verifyPin('5678', hash), isTrue);
      expect(PinHasher.verifyPin('0000', hash), isFalse);
      expect(PinHasher.verifyPin('5679', hash), isFalse);
    });

    test('verifyPin normalizes Persian and Arabic numerals', () {
      final hash = PinHasher.hashPin('1234');
      expect(PinHasher.verifyPin('۱۲۳۴', hash), isTrue, reason: 'Persian digits');
      expect(PinHasher.verifyPin('١٢٣٤', hash), isTrue, reason: 'Arabic digits');
    });

    test('verifyPin supports legacy v1 static salt SHA-256 hashes', () {
      final legacyV1Bytes = utf8.encode('ritmo_pin_salt_v1_secure_2026:4321');
      final legacyV1Hash = sha256.convert(legacyV1Bytes).toString();
      expect(PinHasher.needsUpgrade(legacyV1Hash), isTrue);
      expect(PinHasher.verifyPin('4321', legacyV1Hash), isTrue);
      expect(PinHasher.verifyPin('۴۳۲۱', legacyV1Hash), isTrue);
      expect(PinHasher.verifyPin('1234', legacyV1Hash), isFalse);
    });

    test('verifyPin supports legacy plaintext PINs <= 6 characters', () {
      const plaintextPin = '123456';
      expect(PinHasher.needsUpgrade(plaintextPin), isTrue);
      expect(PinHasher.verifyPin('123456', plaintextPin), isTrue);
      expect(PinHasher.verifyPin('۱۲۳۴۵۶', plaintextPin), isTrue);
      expect(PinHasher.verifyPin('999999', plaintextPin), isFalse);
    });

    test('verifyAndUpgrade upgrades legacy formats to v2 while leaving v2 as is', () {
      const plaintextPin = '9876';
      final upgradeResult = PinHasher.verifyAndUpgrade('9876', plaintextPin);
      expect(upgradeResult.isValid, isTrue);
      expect(upgradeResult.upgradedHash, isNotNull);
      expect(upgradeResult.upgradedHash!.startsWith('v2:'), isTrue);
      expect(PinHasher.verifyPin('9876', upgradeResult.upgradedHash!), isTrue);

      final v2Hash = PinHasher.hashPin('9876');
      final noUpgradeResult = PinHasher.verifyAndUpgrade('9876', v2Hash);
      expect(noUpgradeResult.isValid, isTrue);
      expect(noUpgradeResult.upgradedHash, isNull, reason: 'Already on v2');
    });
  });
}
