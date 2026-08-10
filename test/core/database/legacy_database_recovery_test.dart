import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/legacy_database_recovery.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('legacy_db_recovery_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('P0-01: Valid SQLite 16-byte header returns true', () async {
    final validFile = File('${tempDir.path}/valid.db');
    final headerBytes = [
      0x53, 0x51, 0x4C, 0x69, 0x74, 0x65, 0x20, 0x66, // SQLite f
      0x6F, 0x72, 0x6D, 0x61, 0x74, 0x20, 0x33, 0x00, // ormat 3\0
    ];
    final padding = List<int>.filled(100, 0);
    await validFile.writeAsBytes([...headerBytes, ...padding]);

    final isValid = await LegacyDatabaseRecovery.isValidSqliteHeader(validFile);
    expect(isValid, isTrue);
  });

  test('P0-01: File with SQLite format 30 (escaped nul bug) returns false', () async {
    final buggedFile = File('${tempDir.path}/bugged.db');
    // Header string "SQLite format 30" (0x30 instead of 0x00)
    final headerBytes = [
      0x53, 0x51, 0x4C, 0x69, 0x74, 0x65, 0x20, 0x66,
      0x6F, 0x72, 0x6D, 0x61, 0x74, 0x20, 0x33, 0x30, // '3', '0'
    ];
    final padding = List<int>.filled(100, 0);
    await buggedFile.writeAsBytes([...headerBytes, ...padding]);

    final isValid = await LegacyDatabaseRecovery.isValidSqliteHeader(buggedFile);
    expect(isValid, isFalse);
  });

  test('P0-01: 0-byte file returns false', () async {
    final emptyFile = File('${tempDir.path}/empty.db');
    await emptyFile.writeAsBytes([]);

    final isValid = await LegacyDatabaseRecovery.isValidSqliteHeader(emptyFile);
    expect(isValid, isFalse);
  });

  test('P0-01: 99-byte file returns false', () async {
    final shortFile = File('${tempDir.path}/short.db');
    await shortFile.writeAsBytes(List<int>.filled(99, 0));

    final isValid = await LegacyDatabaseRecovery.isValidSqliteHeader(shortFile);
    expect(isValid, isFalse);
  });
}
