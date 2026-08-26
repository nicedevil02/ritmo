import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:pointycastle/export.dart';

class PinHasher {
  static const String _legacySaltV1 = 'ritmo_pin_salt_v1_secure_2026';
  static const int _pbkdf2Iterations = 100000;
  static const int _derivedKeyLength = 32;

  static String _normalize(String pin) {
    const persian = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
    const arabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    var res = pin.trim();
    for (var i = 0; i < 10; i++) {
      res = res.replaceAll(persian[i], '$i').replaceAll(arabic[i], '$i');
    }
    return res;
  }

  /// Derives key using PBKDF2-HMAC-SHA256.
  static Uint8List _pbkdf2Derive(String normalizedPin, Uint8List salt) {
    final hmac = HMac(SHA256Digest(), 64);
    final derivator = PBKDF2KeyDerivator(hmac);
    final params = Pbkdf2Parameters(salt, _pbkdf2Iterations, _derivedKeyLength);
    derivator.init(params);
    return derivator.process(Uint8List.fromList(utf8.encode(normalizedPin)));
  }

  /// Hashes a PIN using the hardened v2 format: `v2:<salt_hex>:<hash_hex>`
  static String hashPin(String pin) {
    final norm = _normalize(pin);
    final random = Random.secure();
    final saltBytes = Uint8List(16);
    for (var i = 0; i < 16; i++) {
      saltBytes[i] = random.nextInt(256);
    }

    final keyBytes = _pbkdf2Derive(norm, saltBytes);
    final saltHex = saltBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    final hashHex = keyBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return 'v2:$saltHex:$hashHex';
  }

  /// Checks whether a stored PIN hash is from a legacy format and needs upgrade to v2.
  static bool needsUpgrade(String storedHash) {
    if (storedHash.isEmpty) return false;
    return !storedHash.startsWith('v2:');
  }

  /// Compares two strings in constant time to mitigate timing side-channel attacks (RIT-032).
  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var result = 0;
    for (var i = 0; i < a.length; i++) {
      result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return result == 0;
  }

  /// Verifies a PIN against hardened v2 (PBKDF2) or legacy v1 (salted SHA-256) formats.
  /// Plaintext passwords are rejected (RIT-031).
  static bool verifyPin(String pin, String storedHash) {
    if (storedHash.isEmpty) return false;
    final norm = _normalize(pin);

    // Format 1: Hardened v2 format (PBKDF2-HMAC-SHA256)
    if (storedHash.startsWith('v2:')) {
      final parts = storedHash.split(':');
      if (parts.length != 3) return false;
      final saltHex = parts[1];
      final expectedHashHex = parts[2];

      if (saltHex.length != 32 || expectedHashHex.length != 64) return false;

      final saltBytes = Uint8List(16);
      for (var i = 0; i < 16; i++) {
        final byteStr = saltHex.substring(i * 2, i * 2 + 2);
        final byteVal = int.tryParse(byteStr, radix: 16);
        if (byteVal == null) return false;
        saltBytes[i] = byteVal;
      }

      final derivedBytes = _pbkdf2Derive(norm, saltBytes);
      final derivedHashHex = derivedBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      return _constantTimeEquals(derivedHashHex, expectedHashHex);
    }

    // Format 2: Legacy v1 SHA-256 with static salt
    if (storedHash.length == 64) {
      final legacyBytes = utf8.encode('$_legacySaltV1:$norm');
      final legacyDigest = sha256.convert(legacyBytes).toString();
      return _constantTimeEquals(legacyDigest, storedHash);
    }

    return false;
  }

  /// Verifies PIN and returns an upgraded hash if verification was successful
  /// and the stored hash is in an older format.
  static ({bool isValid, String? upgradedHash}) verifyAndUpgrade(String pin, String storedHash) {
    final valid = verifyPin(pin, storedHash);
    if (!valid) {
      return (isValid: false, upgradedHash: null);
    }
    if (needsUpgrade(storedHash)) {
      return (isValid: true, upgradedHash: hashPin(pin));
    }
    return (isValid: true, upgradedHash: null);
  }
}
