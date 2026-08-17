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
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:workmanager/workmanager.dart';

/// Timezone the background isolate schedules against.
const String _backgroundTimeZone = 'Asia/Tehran';

/// Top-level callback dispatcher entry-point for background tasks (Workmanager).
@pragma('vm:entry-point')
void ritmoCallbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    // 1. Isolate Foundation & Native Plugin Registration (P0-05)
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();

    // 2. Timezone Initialization
    // This used to be wrapped in a bare `catch (_) {}`. On failure the isolate
    // silently stays on UTC, so every alarm scheduled by this run fires hours
    // off with nothing in the logs to explain it. Scheduling nothing and
    // letting Workmanager retry is strictly better than scheduling wrong times.
    try {
      tz.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation(_backgroundTimeZone));
    } catch (e, st) {
      RitmoLog.error(
        'BgWorker',
        'Timezone init failed - aborting task "$taskName" instead of scheduling alarms in the wrong zone',
        e,
        st,
      );
      return false;
    }

    // 3. DI Bootstrapping & Services Registration in Background Isolate (P0-05)
    try {
      await AppBootstrapper.init();
      await SettingsService.instance.init();
      await AppModeService.instance.load();
    } catch (e, st) {
      RitmoLog.error('BgWorker', 'Bootstrap failed in background isolate', e, st);
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
  try {
    final passcodeManager = BackupPasscodeManager();
    final hasCode = await passcodeManager.hasPasscode();
    if (!hasCode) {
      await NotificationGateway.schedule(
        NotificationRequest(
          id: 'immediate_backup_${NotificationIds.weeklyBackup}',
          channel: NotificationChannelId.planning,
          scheduledAt: DateTime.now(),
          title: 'پشتیبان‌گیری خودکار ریتمو ☁️',
          body: 'برای فعالسازی بکاپ خودکار، یک رمز عبور (passcode) در تنظیمات پروفایل خود تنظیم کنید.',
          sourceSystem: 'backup',
          entityId: 'backup_immediate',
        ),
      );
      RitmoLog.warning('BgWorker', 'Weekly backup task aborted: passcode not set.');
      return true; // Handled, return true to avoid infinite retry loop
    }

    final passcode = await passcodeManager.getPasscode();
    if (passcode == null) return true;

    final driveService = GoogleDriveBackupService.instance;
    final signedIn = await driveService.signIn();
    if (!signedIn) {
      RitmoLog.warning('BgWorker', 'Weekly backup task aborted: not signed in to Google Drive.');
      return true; // Not signed in, return true to avoid infinite backoff retry
    }

    await driveService.uploadBackup(passcode);
    await driveService.pruneOldBackups();
    RitmoLog.info('BgWorker', 'Weekly backup completed successfully.');
    return true;
  } catch (e, st) {
    RitmoLog.error('BgWorker', 'Weekly backup background task execution failed', e, st);
    return false; // Retry later on actual failure
  }
}

Future<bool> _runReschedule() async {
  try {
    await AlarmSchedulerService.scheduleNextAlarms();
    RitmoLog.info('BgWorker', 'Background alarm reschedule completed successfully.');
    return true;
  } catch (e, st) {
    RitmoLog.error('BgWorker', 'Background alarm reschedule failed', e, st);
    return false;
  }
}
