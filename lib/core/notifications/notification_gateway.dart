import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/di/service_locator.dart';
import 'package:ritmo/core/domain/models/inbox_item.dart';
import 'package:ritmo/core/logging/ritmo_logger.dart';
import 'package:ritmo/core/notifications/notification_policy.dart';
import 'package:ritmo/core/notifications/notification_policy_engine.dart';
import 'package:ritmo/core/notifications/notification_request.dart';
import 'package:ritmo/core/platform/alarm_platform.dart';
import 'package:ritmo/core/services/central_inbox_service.dart';
import 'package:sqflite/sqflite.dart';

/// Single unified gateway for dispatching and scheduling all notifications across Ritmo.
/// Enforces policy evaluation, delivery logging, inbox persistence, and platform delegation.
abstract final class NotificationGateway {
  /// Evaluates policy, logs delivery, pushes to inbox, and schedules alarm on platform.
  static Future<bool> schedule(
    NotificationRequest req, {
    NotificationPolicy? overridePolicy,
    DateTime? now,
  }) async {
    final effectiveNow = now ?? DateTime.now();
    final policy = overridePolicy ?? await loadCurrentPolicy();

    // 1. Evaluate policy
    final decision = NotificationPolicyEngine.decide(req, policy, effectiveNow);
    RitmoLog.info(
      'NotificationGateway',
      'Scheduling request ${req.id} (channel: ${req.channel.name}, privacy: ${req.privacy.name}) -> Decision: $decision',
    );

    // 2. Handle suppression
    if (decision.isSuppressed) {
      if (req.privacy == NotificationPrivacy.hidden) {
        // Hidden notifications are still delivered to central inbox for locked viewing
        await CentralInboxService.push(
          category: InboxCategory.REMINDER,
          sourceSystem: req.sourceSystem,
          entityId: req.entityId ?? req.id,
          eventType: 'hidden_notification',
          title: req.title,
          body: req.body,
          priority: req.channel.isEssential ? 2 : 0,
          payload: {
            'privacy': 'hidden',
            'channel': req.channel.name,
            ...?req.payload,
          },
        );
      }
      return false;
    }

    final effectiveScheduledTime = decision.isDeferred ? decision.deferUntil! : req.scheduledAt;
    final scheduledTimeMs = effectiveScheduledTime.millisecondsSinceEpoch;
    final effectiveTitle = decision.isRedacted ? decision.redactedTitle! : req.title;
    final isEssential = req.channel.isEssential;

    // 3. Delegate to platform FIRST
    bool scheduledSuccess = false;
    try {
      final platform = sl<AlarmPlatform>();
      scheduledSuccess = await platform.scheduleExactAlarm(
        id: req.id,
        timeMsUTC: scheduledTimeMs,
        title: effectiveTitle,
        isEssential: isEssential,
      );
    } catch (e, st) {
      RitmoLog.error('NotificationGateway', 'Platform schedule failure for ${req.id}', e, st);
      scheduledSuccess = false;
    }

    // 4. Log outcome into alarm_delivery_log
    try {
      final db = await DatabaseHelper.instance.database;
      await db.insert(
        'alarm_delivery_log',
        {
          'id': 'log_${req.id}_$scheduledTimeMs',
          'reminderId': req.id,
          'routineId': req.entityId,
          'expectedAt': scheduledTimeMs,
          'firedAt': null,
          'outcome': scheduledSuccess
              ? (decision.isDeferred ? 'deferred' : 'scheduled')
              : 'failed',
          'createdAt': effectiveNow.millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('NotificationGateway: Failed to record delivery log: $e');
    }

    if (!scheduledSuccess) {
      return false;
    }

    // 5. Push to Central Inbox ONLY upon successful platform schedule (excluding background worship alarms)
    if (req.sourceSystem != 'worship') {
      try {
        await CentralInboxService.push(
          category: InboxCategory.REMINDER,
          sourceSystem: req.sourceSystem,
          entityId: req.entityId ?? req.id,
          eventType: 'routine_reminder',
          title: req.title,
          body: req.body,
          priority: req.channel.isEssential ? 2 : 0,
          linkEntityId: req.entityId,
          dateBucket: '${req.id}_$scheduledTimeMs',
          payload: {
            'channel': req.channel.name,
            'privacy': req.privacy.name,
            'isRedacted': decision.isRedacted,
            ...?req.payload,
          },
        );
      } catch (e) {
        debugPrint('NotificationGateway: Failed to push to central inbox: $e');
      }
    }

    return true;
  }

  /// Cancels a scheduled alarm by its unique [id].
  static Future<bool> cancel(String id) async {
    try {
      return await sl<AlarmPlatform>().cancelAlarm(id);
    } catch (e, st) {
      RitmoLog.error('NotificationGateway', 'Failed to cancel alarm $id', e, st);
      return false;
    }
  }

  /// Cancels all scheduled alarms for a specific entity in a subsystem.
  static Future<void> cancelForEntity(String sourceSystem, String entityId) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final pending = await db.query(
        'pending_reminders',
        where: 'routineId = ?',
        whereArgs: [entityId],
      );
      for (final p in pending) {
        final id = p['id'] as String;
        await cancel(id);
      }
      await db.update(
        'pending_reminders',
        {'state': 'CANCELLED', 'updatedAt': DateTime.now().millisecondsSinceEpoch},
        where: 'routineId = ?',
        whereArgs: [entityId],
      );
    } catch (e) {
      debugPrint('NotificationGateway: Failed to cancel alarms for entity $entityId: $e');
    }
  }

  /// Loads current [NotificationPolicy] from settings and database state.
  static Future<NotificationPolicy> loadCurrentPolicy() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final settingsList = await db.query('app_settings');
      final settings = {
        for (final s in settingsList) s['key']! as String: s['value']! as String
      };

      final todayStr = DateTime.now().toIso8601String().substring(0, 10);
      final exceptions = await db.query(
        'calendar_exceptions',
        where: 'date = ?',
        whereArgs: [todayStr],
      );
      final behavior = exceptions.isNotEmpty
          ? (exceptions.first['behavior'] as String? ?? 'NORMAL')
          : 'NORMAL';

      return NotificationPolicy(
        masterEnabled: settings['notif_master_enabled'] != 'false',
        quietHoursEnabled: settings['notif_quiet_enabled'] == 'true',
        quietHoursStart: settings['notif_quiet_start'] ?? '00:00',
        quietHoursEnd: settings['notif_quiet_end'] ?? '07:00',
        maxNonEssentialPerHour: int.tryParse(settings['max_non_essential_per_hour'] ?? '3') ?? 3,
        digestMode: settings['digest_mode'] ?? 'standard',
        calendarExceptionBehavior: behavior,
      );
    } catch (_) {
      return const NotificationPolicy();
    }
  }
}
