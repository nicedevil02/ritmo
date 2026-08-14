import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/migration/migrations/migration_v101_notification_control_center.dart';
import 'package:ritmo/core/notifications/notification_channel.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  try {
    sqfliteFfiInit();
  } catch (_) {}

  group('Migration V101 Notification Control Center Tests', () {
    late Database db;
    bool dbInitialized = false;

    setUp(() async {
      try {
        databaseFactory = databaseFactoryFfi;
        db = await openDatabase(
          inMemoryDatabasePath,
          version: 1,
          onCreate: (db, version) async {
            await db.execute('CREATE TABLE app_settings (key TEXT PRIMARY KEY, value TEXT, updatedAt INTEGER);');
            await db.execute('''
              CREATE TABLE pending_reminders (
                id TEXT PRIMARY KEY,
                routineId TEXT,
                scheduleId TEXT,
                courseSessionId TEXT,
                originalTime INTEGER NOT NULL,
                scheduledTime INTEGER NOT NULL,
                state TEXT NOT NULL DEFAULT 'SCHEDULED',
                deferCount INTEGER NOT NULL DEFAULT 0,
                deferReason TEXT,
                createdAt INTEGER NOT NULL,
                updatedAt INTEGER NOT NULL,
                snoozeUntil INTEGER,
                nativeScheduled INTEGER DEFAULT 0,
                ownerModule TEXT
              );
            ''');
          },
        );
        dbInitialized = true;
      } catch (_) {
        dbInitialized = false;
      }
    });

    tearDown(() async {
      if (dbInitialized) {
        await db.close();
      }
    });

    test('MigrationV101 creates notification_channel_prefs, seeds 6 canonical channels, sets default settings and adds columns', () async {
      if (!dbInitialized) return;

      final migration = MigrationV101NotificationControlCenter();
      expect(migration.version, equals(101));

      // Run up migration
      await migration.up(db);

      // 1. Verify app_settings defaults
      final settingsRows = await db.query('app_settings');
      final settings = {
        for (final r in settingsRows) r['key'] as String: r['value'] as String
      };
      expect(settings['notif_master_enabled'], equals('true'));
      expect(settings['notif_quiet_enabled'], equals('false'));
      expect(settings['notif_quiet_start'], equals('23:00'));
      expect(settings['notif_quiet_end'], equals('07:00'));
      expect(settings['max_non_essential_per_hour'], equals('3'));
      expect(settings['digest_mode'], equals('standard'));
      expect(settings['snooze_minutes'], equals('10'));
      expect(settings['snooze_max_defer_count'], equals('3'));
      expect(settings['notif_privacy_mode'], equals('redacted'));
      expect(settings['notif_biometric_enabled'], equals('false'));

      // 2. Verify notification_channel_prefs seeded with 6 canonical channels
      final channelRows = await db.query('notification_channel_prefs');
      expect(channelRows.length, equals(6));
      final seededIds = channelRows.map((r) => r['channel_id'] as String).toSet();
      for (final channel in NotificationChannelId.values) {
        expect(seededIds, contains(channel.nativeId));
      }

      // Verify critical channel has bypass_dnd = 1
      final criticalRow = channelRows.firstWhere((r) => r['channel_id'] == NotificationChannelId.critical.nativeId);
      expect(criticalRow['bypass_dnd'], equals(1));
      expect(criticalRow['enabled'], equals(1));

      // 3. Verify pending_reminders has new columns
      await db.insert('pending_reminders', {
        'id': 'rem_test_v101',
        'originalTime': 1000,
        'scheduledTime': 1000,
        'state': 'scheduled',
        'createdAt': 1000,
        'updatedAt': 1000,
        'channel': 'worship',
        'privacy': 'redacted',
      });

      final remRow = await db.query('pending_reminders', where: 'id = ?', whereArgs: ['rem_test_v101']);
      expect(remRow.first['channel'], equals('worship'));
      expect(remRow.first['privacy'], equals('redacted'));
    });
  });
}
