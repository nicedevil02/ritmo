import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:path_provider/path_provider.dart';
import 'package:pointycastle/digests/sha256.dart';
import 'package:pointycastle/key_derivators/api.dart';
import 'package:pointycastle/key_derivators/pbkdf2.dart';
import 'package:pointycastle/macs/hmac.dart';

/// Local automatic backup service with user password AES encryption support (Hardened Q-04).
class LocalBackupService {
  LocalBackupService._();
  static final LocalBackupService instance = LocalBackupService._();

  static const String _backupDirName = 'ritmo_backups';

  /// Performs automatic weekly local backup keeping maximum 3 rotating copies.
  Future<void> performAutoBackup(String dbPath) async {
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final backupDir = Directory('${docDir.path}/$_backupDirName');
      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final targetFile = File('${backupDir.path}/backup_$timestamp.db');

      final dbFile = File(dbPath);
      if (await dbFile.exists()) {
        await dbFile.copy(targetFile.path);
      }

      // Rotate: keep only 3 newest backups
      final files = backupDir.listSync().whereType<File>().toList();
      files.sort((a, b) => b.path.compareTo(a.path));
      if (files.length > 3) {
        for (int i = 3; i < files.length; i++) {
          await files[i].delete();
        }
      }
    } catch (_) {}
  }

  /// Derives 32-byte AES key using standard PBKDF2 with SHA-256 and 100,000 iterations.
  static Uint8List _deriveKeyPbkdf2(String password, Uint8List salt) {
    final hmac = HMac(SHA256Digest(), 64);
    final derivator = PBKDF2KeyDerivator(hmac);
    final params = Pbkdf2Parameters(salt, 100000, 32);
    derivator.init(params);
    return derivator.process(Uint8List.fromList(utf8.encode(password)));
  }

  /// Encrypts database bytes with user-provided password using PBKDF2 + AES-CBC + random salt & IV (RITMO_ENC2).
  List<int> encryptBackup(List<int> rawBytes, String password) {
    final random = Random.secure();
    final saltBytes = Uint8List(16);
    for (var i = 0; i < 16; i++) {
      saltBytes[i] = random.nextInt(256);
    }

    final ivBytes = Uint8List(16);
    for (var i = 0; i < 16; i++) {
      ivBytes[i] = random.nextInt(256);
    }

    final keyBytes = _deriveKeyPbkdf2(password, saltBytes);
    final key = enc.Key(keyBytes);
    final iv = enc.IV(ivBytes);

    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    final encrypted = encrypter.encryptBytes(rawBytes, iv: iv);

    // Format: "RITMO_ENC2" (10 bytes) + salt (16 bytes) + IV (16 bytes) + ciphertext
    final header = utf8.encode('RITMO_ENC2');
    return [...header, ...saltBytes, ...iv.bytes, ...encrypted.bytes];
  }

  /// Decrypts encrypted backup bytes using user-provided password.
  /// Supports both new RITMO_ENC2 and legacy RITMO_ENC for backward compatibility.
  List<int> decryptBackup(List<int> encryptedBytes, String password) {
    if (encryptedBytes.length < 10) {
      throw const FormatException('Invalid encrypted backup file (too short).');
    }

    // 1. Check for modern RITMO_ENC2 header
    if (encryptedBytes.length >= 42) {
      final header10 = utf8.decode(
        encryptedBytes.sublist(0, 10),
        allowMalformed: true,
      );
      if (header10 == 'RITMO_ENC2') {
        final saltBytes = Uint8List.fromList(encryptedBytes.sublist(10, 26));
        final ivBytes = Uint8List.fromList(encryptedBytes.sublist(26, 42));
        final payloadBytes = Uint8List.fromList(encryptedBytes.sublist(42));

        final keyBytes = _deriveKeyPbkdf2(password, saltBytes);
        final key = enc.Key(keyBytes);
        final iv = enc.IV(ivBytes);

        final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
        try {
          return encrypter.decryptBytes(enc.Encrypted(payloadBytes), iv: iv);
        } catch (e) {
          throw const FormatException(
            'Incorrect password or corrupted backup file.',
          );
        }
      }
    }

    // 2. Fallback to legacy RITMO_ENC header
    if (encryptedBytes.length >= 25) {
      final header9 = utf8.decode(
        encryptedBytes.sublist(0, 9),
        allowMalformed: true,
      );
      if (header9 == 'RITMO_ENC') {
        final ivBytes = Uint8List.fromList(encryptedBytes.sublist(9, 25));
        final payloadBytes = Uint8List.fromList(encryptedBytes.sublist(25));

        final keyBytes = sha256.convert(utf8.encode(password)).bytes;
        final key = enc.Key(Uint8List.fromList(keyBytes));
        final iv = enc.IV(ivBytes);

        final encrypter = enc.Encrypter(enc.AES(key));
        try {
          return encrypter.decryptBytes(enc.Encrypted(payloadBytes), iv: iv);
        } catch (e) {
          throw const FormatException(
            'Incorrect password or corrupted backup file.',
          );
        }
      }
    }

    throw const FormatException('Invalid encrypted backup header.');
  }
}
