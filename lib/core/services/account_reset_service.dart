import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/database/seed/seed_service.dart';
import 'package:ritmo/core/logging/ritmo_logger.dart';
import 'package:ritmo/core/services/premium_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Full transactional account and user data reset service.
class AccountResetService {
  static Future<void> wipeUserData() async {
    RitmoLog.info(
      'AccountResetService',
      'Starting full ordered wipe of user data',
    );

    // 0. Backup premium status
    Map<String, String>? premiumBackup;
    try {
      premiumBackup = await PremiumService.instance.exportEntitlement();
    } catch (e) {
      RitmoLog.error(
        'AccountResetService',
        'Error backing up premium state',
        e,
      );
    }

    // 1. Cancel active alarms & notifications
    try {
      final plugin = FlutterLocalNotificationsPlugin();
      await plugin.cancelAll();
    } catch (_) {}

    // 2. Open DB to get path, then close connection safely
    try {
      final db = await DatabaseHelper.instance.database;
      final dbPath = db.path;
      await DatabaseHelper.instance.close();

      // 3. Delete DB main file and WAL files
      final dbFile = File(dbPath);
      if (await dbFile.exists()) await dbFile.delete();
      final walFile = File('$dbPath-wal');
      if (await walFile.exists()) await walFile.delete();
      final shmFile = File('$dbPath-shm');
      if (await shmFile.exists()) await shmFile.delete();
    } catch (e, st) {
      RitmoLog.error(
        'AccountResetService',
        'Error resetting database files',
        e,
        st,
      );
    }

    // 4. Wipe attachment and document files directory
    try {
      final appSupportDir = await getApplicationSupportDirectory();
      if (await appSupportDir.exists()) {
        await appSupportDir.delete(recursive: true);
      }
    } catch (_) {}

    // 5. Clear SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    } catch (e, st) {
      RitmoLog.error(
        'AccountResetService',
        'Error clearing SharedPreferences',
        e,
        st,
      );
    }

    // 6. Clear Secure Storage (PIN, backup passcodes, tokens)
    try {
      const storage = FlutterSecureStorage();
      await storage.deleteAll();
    } catch (_) {}

    // Restore premium status if backup exists
    if (premiumBackup != null && premiumBackup.isNotEmpty) {
      try {
        await PremiumService.instance.restoreEntitlement(premiumBackup);
      } catch (e) {
        RitmoLog.error(
          'AccountResetService',
          'Error restoring premium state',
          e,
        );
      }
    }

    // 7. Re-initialize fresh database & seed settings
    try {
      final freshDb = await DatabaseHelper.instance.database;
      await SeedService.seedSettings(freshDb);
      await SeedService.seedWorshipPractices(freshDb);
    } catch (e, st) {
      RitmoLog.error(
        'AccountResetService',
        'Error re-seeding database after wipe',
        e,
        st,
      );
    }

    // 8. Re-load premium state
    try {
      await PremiumService.instance.loadEntitlement();
    } catch (e) {
      RitmoLog.error(
        'AccountResetService',
        'Error reloading premium state after restore',
        e,
      );
    }

    RitmoLog.info(
      'AccountResetService',
      'Full ordered reset completed successfully',
    );
  }
}
