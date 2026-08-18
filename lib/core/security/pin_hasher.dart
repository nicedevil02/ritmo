import 'dart:convert';
import 'package:crypto/crypto.dart';

class PinHasher {
  static const String _salt = 'ritmo_pin_salt_v1_secure_2026';

  static String hashPin(String pin) {
    final bytes = utf8.encode('$_salt:$pin');
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  static bool verifyPin(String pin, String storedHash) {
    if (storedHash.isEmpty) return false;
    // Backward compatibility with legacy unhashed 4-digit PINs
    if (storedHash.length <= 6 && storedHash == pin) {
      return true;
    }
    return hashPin(pin) == storedHash;
  }
}
