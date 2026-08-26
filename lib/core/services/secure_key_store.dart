import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/logging/ritmo_logger.dart';
import 'package:sqflite/sqflite.dart';

sealed class KeyReadResult {
  const KeyReadResult();
}

class KeyFound extends KeyReadResult {
  final String value;
  const KeyFound(this.value);
}

class KeyAbsent extends KeyReadResult {
  const KeyAbsent();
}

class KeyUnavailable extends KeyReadResult {
  final Object error;
  final StackTrace? stackTrace;
  const KeyUnavailable(this.error, [this.stackTrace]);
}

/// SecureKeyStore uses Keystore/Keychain via FlutterSecureStorage for sensitive API keys,
/// automatically migrating legacy keys out of plaintext SQLite app_settings.
class SecureKeyStore {
  SecureKeyStore._();
  static const _storage = FlutterSecureStorage();

  static DatabaseExecutor? _resolveDb(DatabaseExecutor? explicitDb) {
    if (explicitDb != null) return explicitDb;
    final raw = DatabaseHelper.rawDatabase;
    if (raw != null && raw.isOpen) return raw;
    return null;
  }

  /// Distinguishes key existence from keystore operational failures (REG-05).
  static Future<KeyReadResult> readKey(
    String keyName, [
    DatabaseExecutor? dbExecutor,
  ]) async {
    try {
      final value = await _storage.read(key: keyName);
      if (value != null && value.isNotEmpty) {
        return KeyFound(value);
      }
    } catch (e, st) {
      RitmoLog.error('Settings', 'خطا در خواندن کلید امن $keyName', e, st);
      return KeyUnavailable(e, st);
    }

    // Fallback & Auto-Migration from legacy SQLite app_settings
    try {
      final db = _resolveDb(dbExecutor);
      if (db != null) {
        final rows = await db.query(
          'app_settings',
          where: 'key = ?',
          whereArgs: [keyName],
        );
        if (rows.isNotEmpty) {
          final legacyVal = rows.first['value'] as String?;
          if (legacyVal != null && legacyVal.isNotEmpty) {
            try {
              await setKey(keyName, legacyVal, db);
              await db.delete(
                'app_settings',
                where: 'key = ?',
                whereArgs: [keyName],
              );
              return KeyFound(legacyVal);
            } catch (e, st) {
              RitmoLog.error('Settings', 'خطا در مهاجرت کلید سنتی $keyName به مخزن امن', e, st);
              return KeyUnavailable(e, st);
            }
          }
        }
      }
    } catch (_) {}

    return const KeyAbsent();
  }

  static Future<String?> getKey(
    String keyName, [
    DatabaseExecutor? dbExecutor,
  ]) async {
    final result = await readKey(keyName, dbExecutor);
    if (result is KeyFound) {
      return result.value;
    }
    return null;
  }

  static Future<bool> setKey(
    String keyName,
    String value, [
    DatabaseExecutor? dbExecutor,
  ]) async {
    try {
      await _storage.write(key: keyName, value: value);
      // Remove any legacy plaintext entry in SQLite
      try {
        final db = _resolveDb(dbExecutor);
        if (db != null) {
          await db.delete(
            'app_settings',
            where: 'key = ?',
            whereArgs: [keyName],
          );
        }
      } catch (_) {}
      return true;
    } catch (e, st) {
      RitmoLog.error('Settings', 'خطا در نوشتن کلید امن $keyName', e, st);
      rethrow;
    }
  }

  static Future<bool> deleteKey(
    String keyName, [
    DatabaseExecutor? dbExecutor,
  ]) async {
    try {
      await _storage.delete(key: keyName);
      try {
        final db = _resolveDb(dbExecutor);
        if (db != null) {
          await db.delete(
            'app_settings',
            where: 'key = ?',
            whereArgs: [keyName],
          );
        }
      } catch (_) {}
      return true;
    } catch (e, st) {
      RitmoLog.error('Settings', 'خطا در حذف کلید امن $keyName', e, st);
      rethrow;
    }
  }

  static Future<bool> clearAll([DatabaseExecutor? dbExecutor]) async {
    try {
      await _storage.deleteAll();
      try {
        final db = _resolveDb(dbExecutor);
        if (db != null) {
          await db.delete(
            'app_settings',
            where: 'key IN (?, ?, ?)',
            whereArgs: ['ai_api_key', 'app_lock_password', 'cycle_lock_password'],
          );
        }
      } catch (_) {}
      return true;
    } catch (e, st) {
      RitmoLog.error('Settings', 'خطا در پاک‌سازی کامل مخزن امن', e, st);
      rethrow;
    }
  }
}
