import 'package:ritmo/core/database/migration/migration_interface.dart';
import 'package:ritmo/core/notifications/notification_channel.dart';
import 'package:sqflite/sqflite.dart';

/// Database Migration V101 — Notification Control Center and Privacy Engine.
/// Adds notification settings, channel preferences table with canonical seed,
/// and channel/privacy columns to pending_reminders.
class MigrationV101NotificationControlCenter extends Migration {
  @override
  int get version => 101;

  @override
  Future<void> up(DatabaseExecutor db) async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    // 1. Seed default app_settings keys
    final defaultSettings = <String, String>{
      'notif_master_enabled': 'true',
      'notif_quiet_enabled': 'false',
      'notif_quiet_start': '23:00',
      'notif_quiet_end': '07:00',
      'max_non_essential_per_hour': '3',
      'digest_mode': 'standard',
      'snooze_minutes': '10',
      'snooze_max_defer_count': '3',
      'notif_privacy_mode': 'redacted',
      'notif_biometric_enabled': 'false',
    };

    for (final entry in defaultSettings.entries) {
      try {
        await db.execute(
          'INSERT OR IGNORE INTO app_settings (key, value, updatedAt) VALUES (?, ?, ?);',
          [entry.key, entry.value, nowMs],
        );
      } catch (_) {}
    }

    // 2. Add columns to pending_reminders
    final pendingCols = [
      "ALTER TABLE pending_reminders ADD COLUMN channel TEXT DEFAULT 'routine';",
      "ALTER TABLE pending_reminders ADD COLUMN privacy TEXT DEFAULT 'none';",
    ];
    for (final sql in pendingCols) {
      try {
        await db.execute(sql);
      } catch (_) {}
    }

    // 3. Create notification_channel_prefs table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS notification_channel_prefs (
        channel_id TEXT PRIMARY KEY,
        enabled INTEGER NOT NULL DEFAULT 1,
        sound_mode TEXT NOT NULL DEFAULT 'default',
        vibration_enabled INTEGER NOT NULL DEFAULT 1,
        bypass_dnd INTEGER NOT NULL DEFAULT 0,
        updated_at INTEGER NOT NULL
      );
    ''');

    // 4. Seed 6 canonical notification channels
    for (final channel in NotificationChannelId.values) {
      final bypassDnd = channel.bypassesQuietHours ? 1 : 0;
      try {
        await db.execute(
          '''
          INSERT OR IGNORE INTO notification_channel_prefs 
          (channel_id, enabled, sound_mode, vibration_enabled, bypass_dnd, updated_at) 
          VALUES (?, 1, 'default', 1, ?, ?);
          ''',
          [channel.nativeId, bypassDnd, nowMs],
        );
      } catch (_) {}
    }
  }

  @override
  Future<void> down(DatabaseExecutor db) async {}
}
