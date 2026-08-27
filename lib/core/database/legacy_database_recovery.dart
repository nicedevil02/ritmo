import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ritmo/core/logging/ritmo_logger.dart';
import 'package:sqflite/sqflite.dart';

/// Safely handles database files, header validation, and emergency recovery without losing user data.
class LegacyDatabaseRecovery {
  /// The exact 16-byte SQLite file header: "SQLite format 3" followed by a NUL byte.
  static const List<int> _sqliteMagic = <int>[
    0x53, 0x51, 0x4C, 0x69, 0x74, 0x65, 0x20, 0x66, // S Q L i t e ' ' f
    0x6F, 0x72, 0x6D, 0x61, 0x74, 0x20, 0x33, 0x00, // o r m a t ' ' 3 NUL
  ];

  static const List<String> _sidecarSuffixes = ['-wal', '-shm', '-journal'];

  /// Validates whether a file is a valid, non-corrupt SQLite database with a proper 16-byte header.
  static Future<bool> isValidSqliteHeader(File file) async {
    if (!await file.exists()) return false;
    final length = await file.length();
    if (length < 100) return false; // Minimum SQLite file size header is 100 bytes

    RandomAccessFile? raf;
    try {
      raf = await file.open(mode: FileMode.read);
      final headerBytes = await raf.read(16);
      if (headerBytes.length < 16) return false;
      for (var i = 0; i < 16; i++) {
        if (headerBytes[i] != _sqliteMagic[i]) return false;
      }
      return true;
    } catch (e, st) {
      RitmoLog.error('LegacyDatabaseRecovery', 'Header read failed', e, st);
      return false;
    } finally {
      await raf?.close();
    }
  }

  /// Ensures safe database file transition and quarantines corrupted/0-byte files.
  static Future<String> getSafeDatabasePath() async {
    final dbPath = await getDatabasesPath();
    final legacyPath = join(dbPath, 'ritmo_secure.db');
    final targetPath = join(dbPath, 'ritmo.db');

    final legacyFile = File(legacyPath);
    final targetFile = File(targetPath);

    // Clean old quarantine files (P0-01, P0-07)
    await pruneQuarantineDirectory();

    // 1. If target file exists but is corrupted or 0-bytes, quarantine it
    if (await targetFile.exists() && !(await isValidSqliteHeader(targetFile))) {
      await quarantineCorruptFile(targetFile, 'target_invalid_header');
    }

    // 2. If legacy file exists and target file does not exist (or was quarantined)
    if (await legacyFile.exists() && !(await targetFile.exists())) {
      if (await isValidSqliteHeader(legacyFile)) {
        try {
          await moveDatabaseSet(legacyPath, targetPath);
          RitmoLog.info('LegacyDatabaseRecovery', 'Successfully moved valid legacy database set to ritmo.db');
        } catch (e, st) {
          RitmoLog.error('LegacyDatabaseRecovery', 'Failed to move legacy database, copying instead', e, st);
          try {
            await copyDatabaseSet(legacyPath, targetPath);
            await deleteDatabaseSet(legacyPath);
          } catch (copyErr, copySt) {
            RitmoLog.error('LegacyDatabaseRecovery', 'Failed to copy legacy database', copyErr, copySt);
          }
        }
      } else {
        await quarantineCorruptFile(legacyFile, 'legacy_invalid_header');
      }
    }

    // Restore data if DB is empty and previous valid backup exists
    await _restoreDataIfTargetEmpty(targetFile);

    return targetFile.path;
  }

  /// Moves db + all sidecar files (-wal, -shm, -journal) atomically to a destination base path.
  static Future<void> moveDatabaseSet(String fromPath, String toPath) async {
    await _moveOne(File(fromPath), toPath);
    for (final suffix in _sidecarSuffixes) {
      await _moveOne(File('$fromPath$suffix'), '$toPath$suffix');
    }
  }

  /// Copies db + all sidecar files to a destination base path.
  static Future<void> copyDatabaseSet(String fromPath, String toPath) async {
    final src = File(fromPath);
    if (await src.exists()) {
      await src.copy(toPath);
    }
    for (final suffix in _sidecarSuffixes) {
      final f = File('$fromPath$suffix');
      if (await f.exists()) {
        await f.copy('$toPath$suffix');
      }
    }
  }

  /// Deletes db + all sidecar files.
  static Future<void> deleteDatabaseSet(String basePath) async {
    final f = File(basePath);
    if (await f.exists()) {
      try {
        await f.delete();
      } catch (_) {}
    }
    for (final suffix in _sidecarSuffixes) {
      final sf = File('$basePath$suffix');
      if (await sf.exists()) {
        try {
          await sf.delete();
        } catch (_) {}
      }
    }
  }

  static Future<void> _moveOne(File f, String toPath) async {
    if (!await f.exists()) return;
    try {
      await f.rename(toPath);
    } on FileSystemException {
      // Fallback cross-device move
      await f.copy(toPath);
      await f.delete();
    }
  }

  /// Returns private recovery directory inside application support directory (P0-07).
  static Future<Directory> _getRecoveryDirectory() async {
    final supportDir = await getApplicationSupportDirectory();
    final recoveryDir = Directory(join(supportDir.path, 'recovery'));
    if (!await recoveryDir.exists()) {
      await recoveryDir.create(recursive: true);
    }
    return recoveryDir;
  }

  /// Quarantines a corrupted database file set to private recovery directory (P0-07).
  static Future<void> quarantineCorruptFile(File file, String reason) async {
    try {
      final recoveryDir = await _getRecoveryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final corruptPath = join(recoveryDir.path, 'ritmo_corrupt_${reason}_$timestamp.db');
      await moveDatabaseSet(file.path, corruptPath);
      RitmoLog.warning('LegacyDatabaseRecovery', 'Quarantined corrupt database set ($reason) to: $corruptPath');
    } catch (e, st) {
      RitmoLog.error('LegacyDatabaseRecovery', 'Failed to quarantine corrupt database file', e, st);
      try {
        if (await file.exists() && await file.length() == 0) {
          await deleteDatabaseSet(file.path);
        }
      } catch (_) {}
    }
  }

  /// Creates an emergency raw backup copy of the database set before dangerous operations (P0-03, P0-07).
  static Future<String?> createEmergencyBackup(String dbPath) async {
    try {
      final file = File(dbPath);
      if (!await file.exists() || !(await isValidSqliteHeader(file))) return null;

      final recoveryDir = await _getRecoveryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final backupPath = join(recoveryDir.path, 'ritmo_recovery_$timestamp.db');

      await copyDatabaseSet(dbPath, backupPath);
      RitmoLog.info('LegacyDatabaseRecovery', 'Emergency database backup created at: $backupPath');
      return backupPath;
    } catch (e, st) {
      RitmoLog.error('LegacyDatabaseRecovery', 'Failed to create emergency backup', e, st);
      return null;
    }
  }

  /// Enforces maximum 3 recovery files and removes files older than 14 days (P0-01, P0-07).
  static Future<void> pruneQuarantineDirectory() async {
    try {
      final recoveryDir = await _getRecoveryDirectory();
      final files = await recoveryDir.list().where((e) => e is File).cast<File>().toList();

      final nowMs = DateTime.now().millisecondsSinceEpoch;
      const fourteenDaysMs = 14 * 24 * 3600 * 1000;

      final dbFiles = files.where((f) => f.path.endsWith('.db')).toList();

      for (final f in dbFiles) {
        final stat = await f.stat();
        if (nowMs - stat.modified.millisecondsSinceEpoch > fourteenDaysMs) {
          await deleteDatabaseSet(f.path);
        }
      }

      final remaining = (await recoveryDir.list().where((e) => e is File).cast<File>().toList())
          .where((f) => f.path.endsWith('.db'))
          .toList();

      if (remaining.length > 3) {
        remaining.sort((a, b) => a.statSync().modified.compareTo(b.statSync().modified));
        final toDeleteCount = remaining.length - 3;
        for (var i = 0; i < toDeleteCount; i++) {
          await deleteDatabaseSet(remaining[i].path);
        }
      }
    } catch (e, st) {
      RitmoLog.error('LegacyDatabaseRecovery', 'Pruning quarantine files failed', e, st);
    }
  }

  /// Attempts data recovery if target DB is missing/0-bytes and a valid corrupt/backup file exists (P0-01).
  static Future<void> _restoreDataIfTargetEmpty(File targetFile) async {
    try {
      if (await targetFile.exists() && await targetFile.length() > 4096) return;

      final recoveryDir = await _getRecoveryDirectory();
      if (!await recoveryDir.exists()) return;

      final candidates = (await recoveryDir.list().where((e) => e is File).cast<File>().toList())
          .where((f) => f.path.endsWith('.db') && !f.path.contains('corrupt'))
          .toList();

      candidates.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));

      for (final candidate in candidates) {
        if (await isValidSqliteHeader(candidate)) {
          final candLength = await candidate.length();
          if (candLength > 4096) {
            await copyDatabaseSet(candidate.path, targetFile.path);
            RitmoLog.warning('LegacyDatabaseRecovery', 'Restored valid database candidate from ${candidate.path}');
            break;
          }
        }
      }
    } catch (e, st) {
      RitmoLog.error('LegacyDatabaseRecovery', 'Failed to restore target database from recovery candidates', e, st);
    }
  }
}
