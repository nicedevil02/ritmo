import 'dart:convert';
import 'package:crypto/crypto.dart';

class PinHasher {
  static const String _salt = 'ritmo_pin_salt_v1_secure_2026';

  static String _normalize(String pin) {
    const persian = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
    const arabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    var res = pin.trim();
    for (var i = 0; i < 10; i++) {
      res = res.replaceAll(persian[i], '$i').replaceAll(arabic[i], '$i');
    }
    return res;
  }

  static String hashPin(String pin) {
    final norm = _normalize(pin);
    final bytes = utf8.encode('$_salt:$norm');
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  static bool verifyPin(String pin, String storedHash) {
    if (storedHash.isEmpty) return false;
    final norm = _normalize(pin);
    // Backward compatibility with legacy unhashed PINs
    if (storedHash.length <= 6 && (storedHash == norm || storedHash == pin)) {
      return true;
    }
    return hashPin(norm) == storedHash;
  }
}
