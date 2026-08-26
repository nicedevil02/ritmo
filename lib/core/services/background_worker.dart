import 'dart:ui';
import 'package:flutter/widgets.dart';
import 'package:ritmo/core/app_mode/app_mode_service.dart';
import 'package:ritmo/core/di/service_locator.dart';
import 'package:ritmo/core/logging/ritmo_logger.dart';
import 'package:ritmo/core/notifications/notification_channel.dart';
import 'package:ritmo/core/notifications/notification_gateway.dart';
import 'package:ritmo/core/notifications/notification_ids.dart';
import 'package:ritmo/core/notifications/notification_request.dart';
import 'package:ritmo/core/services/alarm_scheduler_service.dart';
import 'package:ritmo/core/services/backup_passcode_manager.dart';
import 'package:ritmo/core/services/google_drive_backup_service.dart';
import 'package:ritmo/core/settings/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:workmanager/workmanager.dart';

/// Fallback timezone if device timezone preference is unavailable.
const String _defaultBackgroundTimeZone = 'Asia/Tehran';

/// Top-level callback dispatcher entry-point for background tasks (Workmanager).
@pragma('vm:entry-point')
void ritmoCallbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    // 1. Isolate Foundation & Native Plugin Registration (P0-05)
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();

    // 2. Timezone Initialization from SharedPreferences (RIT-040)
    try {
      tz.initializeTimeZones();
      final prefs = await SharedPreferences.getInstance();
      final zoneName = prefs.getString('app_timezone') ?? _defaultBackgroundTimeZone;
      tz.Location location;
      try {
        location = tz.getLocation(zoneName);
      } catch (_) {
        location = tz.getLocation(_defaultBackgroundTimeZone);
      }
      tz.setLocalLocation(location);
    } catch (e, st) {
      RitmoLog.error(
        'BgWorker',
        'Timezone init failed - aborting task "$taskName" instead of scheduling alarms in the wrong zone',
        e,
        st,
      );
      return false;
    }

    // 3. DI Core Bootstrapping & Services Registration in Background Isolate (RIT-045)
    try {
      await AppBootstrapper.initCore();
      await SettingsService.instance.init();
      await AppModeService.instance.load();
    } catch (e, st) {
      RitmoLog.error(
        'BgWorker',
        'Bootstrap failed in background isolate',
        e,
        st,
      );
      return false;
    }

    // 4. Explicit Task Handling via switch statement (P0-05)
    switch (taskName) {
      case 'weekly_backup_task':
        return await _runWeeklyBackup();

      case 'ritmo_periodic_reschedule':
      case 'ritmoRescheduleTask':
        return await _runReschedule();

      default:
        RitmoLog.warning('BgWorker', 'Unknown background task: $taskName');
        return true;
    }
  });
}

Future<bool> _runWeeklyBackup() async {
  final prefs = await SharedPreferences.getInstance();
  final nowMs = DateTime.now().millisecondsSinceEpoch;
  await prefs.setInt('last_backup_attempt_at', nowMs);

  try {
    final passcodeManager = BackupPasscodeManager();
    final hasCode = await passcodeManager.hasPasscode();
    if (!hasCode) {
      await prefs.setString('last_backup_error', 'passcode_not_set');
      await NotificationGateway.schedule(
        NotificationRequest(
          id: 'immediate_backup_${NotificationIds.weeklyBackup}',
          channel: NotificationChannelId.planning,
          scheduledAt: DateTime.now(),
          title: 'پشتیبان‌گیری خودکار ریتمو ☁️',
          body:
              'برای فعالسازی بکاپ خودکار، یک رمز عبور (passcode) در تنظیمات پروفایل خود تنظیم کنید.',
          sourceSystem: 'backup',
          entityId: 'backup_immediate',
        ),
      );
      RitmoLog.warning(
        'BgWorker',
        'Weekly backup task aborted: passcode not set.',
      );
      return true; // Handled, return true to avoid infinite retry loop
    }

    final passcode = await passcodeManager.getPasscode();
    if (passcode == null) {
      await prefs.setString('last_backup_error', 'passcode_null');
      return true;
    }

    final driveService = GoogleDriveBackupService.instance;
    final signedIn = await driveService.signIn(silentOnly: true);
    if (!signedIn) {
      await prefs.setString('last_backup_error', 'auth_expired');
      RitmoLog.warning(
        'BgWorker',
        'Weekly backup task aborted: not signed in to Google Drive (silent auth expired).',
      );
      return true; // Not signed in, return true to avoid infinite backoff retry
    }

    await driveService.uploadBackup(passcode);
    await driveService.pruneOldBackups();
    await prefs.setInt('last_backup_at', nowMs);
    await prefs.remove('last_backup_error');
    RitmoLog.info('BgWorker', 'Weekly backup completed successfully.');
    return true;
  } catch (e, st) {
    await prefs.setString('last_backup_error', e.toString());
    RitmoLog.error(
      'BgWorker',
      'Weekly backup background task execution failed',
      e,
      st,
    );
    return false; // Retry later on actual failure
  }
}

Future<bool> _runReschedule() async {
  try {
    await AlarmSchedulerService.scheduleNextAlarms();
    RitmoLog.info(
      'BgWorker',
      'Background alarm reschedule completed successfully.',
    );
    return true;
  } catch (e, st) {
    RitmoLog.error('BgWorker', 'Background alarm reschedule failed', e, st);
    return false;
  }
}
