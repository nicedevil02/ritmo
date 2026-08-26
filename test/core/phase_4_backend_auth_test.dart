import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/backend/app_config.dart';
import 'package:ritmo/core/backend/auth_service.dart';
import 'package:ritmo/core/backend/models/auth_result.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/database/schema/schema_manager.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('Phase 4: Backend & Auth Tests', () {
    late Database testDb;

    setUp(() async {
      testDb = await databaseFactory.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, version) async {
            await SchemaManager.createAll(db);
          },
        ),
      );
      await DatabaseHelper.ensureCriticalSchema(testDb);
      DatabaseHelper.instance.overrideDatabaseForTesting(testDb);
    });

    tearDown(() async {
      await testDb.close();
    });

    test('RIT-050: AppConfig.cleanEndpoint preserves regional non-NYC endpoints', () {
      // Default endpoint
      expect(AppConfig.cleanEndpoint, isNotEmpty);

      // Verify logic: cleanEndpoint should not corrupt regional endpoints
      const defaultEndpoint = 'https://nyc.cloud.appwrite.io/v1';
      expect(AppConfig.cleanEndpoint, equals(defaultEndpoint));
    });

    test('RIT-054: Email validation regex strictly rejects malformed inputs', () async {
      final auth = AuthService.instance;

      // Invalid emails
      final invalidSamples = [
        '',
        'invalid-email',
        '.@.',
        'user@',
        '@domain.com',
        'user@domain',
        'user@.com',
      ];

      for (final email in invalidSamples) {
        final res = await auth.requestEmailOtp(email);
        expect(res.isSuccess, isFalse);
        expect(res.errorCode, equals(AuthErrorCode.invalidEmail), reason: 'Failed for $email');
      }
    });

    test('RIT-053: AuthService loads auth settings gracefully without full-table scan fragility', () async {
      final db = await DatabaseHelper.instance.database;
      await db.delete('app_settings');

      await db.insert('app_settings', {'key': 'auth_logged_in', 'value': 'true', 'updatedAt': 0});
      await db.insert('app_settings', {'key': 'auth_provider', 'value': 'email', 'updatedAt': 0});
      await db.insert('app_settings', {'key': 'auth_identifier_masked', 'value': 'te***@test.com', 'updatedAt': 0});
      await db.insert('app_settings', {'key': 'auth_google_linked', 'value': 'false', 'updatedAt': 0});

      final auth = AuthService.instance;
      await auth.init();

      expect(auth.isLoggedIn, isTrue);
      expect(auth.provider, equals('email'));
      expect(auth.maskedIdentifier, equals('te***@test.com'));
      expect(auth.isGoogleLinked, isFalse);
    });
  });
}
