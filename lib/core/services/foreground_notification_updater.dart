import 'package:flutter/foundation.dart';
import 'package:ritmo/core/analytics/reflection_engine.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/di/service_locator.dart';
import 'package:ritmo/core/domain/engines/ritmo_engine_bus.dart';
import 'package:ritmo/core/domain/engines/ritmo_intelligence_engine.dart';
import 'package:ritmo/core/domain/models.dart';
import 'package:ritmo/core/domain/models/reflection_context.dart';
import 'package:ritmo/core/domain/realm/active_realm_resolver.dart';
import 'package:ritmo/core/domain/realm/sessions/zone_session.dart';
import 'package:ritmo/core/domain/realm/sessions/zone_session_writer.dart';
import 'package:ritmo/core/platform/notification_platform.dart';
import 'package:ritmo/core/repositories/realm_repository.dart';

class ForegroundNotificationUpdater {
  static Future<void> update() async {
    try {
      final db = await DatabaseHelper.instance.database;

      // 1. Fetch settings to verify both master notif switch and persistent status notification switch
      final settingsMap = {
        for (final row in await db.query('app_settings'))
          row['key']! as String: row['value']! as String,
      };

      // 1. Single source of truth for active realm (B-01, B-03)
      final realmRepo = RealmRepository();
      final realmState = await realmRepo.getActiveRealmState();
      final activeZoneId = realmState.realmOrNull?.id;
      final activeZoneMode = realmModeToRaw(realmState.effectiveMode);
      final actZoneName = realmState.realmOrNull?.name ?? 'آزاد';

      // 2. Reconcile zone presence session (F-02) — Always runs regardless of notification switch state
      final sessionSource = switch (realmState) {
        ManualRealmState() => ZoneSource.manual,
        ScheduledRealmState(:final isDefaultFallback) =>
          isDefaultFallback ? ZoneSource.defaultRealm : ZoneSource.schedule,
        TriggeredRealmState(:final trigger) => switch (trigger.kind) {
            TriggerKind.wifiSsid => ZoneSource.wifi,
            TriggerKind.geofence => ZoneSource.geofence,
            TriggerKind.calendarTag => ZoneSource.calendar,
            TriggerKind.bluetooth => ZoneSource.bluetooth,
            TriggerKind.nfc => ZoneSource.nfc,
            TriggerKind.charger => ZoneSource.schedule,
          },
        FreeRealmState() => ZoneSource.schedule,
        RealmErrorState() => ZoneSource.schedule,
      };
      await ZoneSessionWriter(dbHelper: DatabaseHelper.instance).reconcile(
        realmState,
        source: sessionSource,
        executor: db,
      );

      // 3. Verify both master notif switch and persistent status notification switch
      final notifMasterEnabled = settingsMap['notif_master_enabled'] != 'false';
      final isPersistentEnabled =
          settingsMap['persistent_status_notification_enabled'] != 'false';

      if (!notifMasterEnabled || !isPersistentEnabled) {
        await sl<NotificationPlatform>().stopForegroundService();
        return;
      }

      final currentEnergyStr = settingsMap['current_energy_state'] ?? 'MEDIUM';
      final currentEnergy = EnergyLevel.values.firstWhere(
        (e) => e.name.toLowerCase() == currentEnergyStr.toLowerCase(),
        orElse: () => EnergyLevel.medium,
      );

      // Is menstruating
      final isMenstruating = await DatabaseHelper.instance.isUserMenstruating();

      // Routines list
      final List<Map<String, dynamic>> routinesMapList = await db.query(
        'routines',
        where: 'isArchived = 0',
      );
      final routineList = routinesMapList.map(Routine.fromMap).toList();

      // Reflection Context
      final nowTime = DateTime.now();
      ReflectionContext? reflectionContext;
      try {
        final reflectionMaps = await db.query(
          'daily_reflections',
          orderBy: 'date DESC',
        );
        if (reflectionMaps.isNotEmpty) {
          final checkinMaps = await db.query(
            'daily_checkins',
            orderBy: 'date DESC',
          );
          final energyLogs = await db.query('energy_logs');
          final moodLogs = await db.query('mood_logs');

          final out = await RitmoEngineBus.instance
              .execute<ReflectionEngineInput, ReflectionEngineOutput>(
                ReflectionEngine,
                ReflectionEngineInput(
                  dailyReflections: reflectionMaps,
                  dailyCheckins: checkinMaps,
                  energyLogs: energyLogs,
                  moodLogs: moodLogs,
                  today: nowTime,
                ),
              );

          if (out.entryCount > 0) {
            var direction = MoodTrendDirection.flat;
            final trend = out.moodTrend;
            if (trend.length >= 2) {
              final delta = trend.last - trend.first;
              if (delta > 0.3) {
                direction = MoodTrendDirection.up;
              } else if (delta < -0.3) {
                direction = MoodTrendDirection.down;
              }
            }

            reflectionContext = ReflectionContext(
              avgMoodScore: out.avgMoodScore,
              moodTrendDirection: direction,
              currentStreak: out.currentStreak,
              reflectionEnergyCorrelation: out.reflectionEnergyCorrelation,
            );
          }
        }
      } catch (e) {
        debugPrint('Error building reflection context in background: $e');
      }

      // Evaluate
      final engineOutput = await RitmoIntelligenceEngine.evaluate(
        routines: routineList,
        appSettings: settingsMap,
        activeZoneId: activeZoneId,
        activeZoneMode: activeZoneMode,
        currentEnergy: currentEnergy,
        isMenstruating: isMenstruating,
        now: nowTime,
        db: db,
        reflectionContext: reflectionContext,
      );

      final nextTask = engineOutput.suggestedRoutine;

      // 1. Fetch routines progress stats for today
      final todayStr = DateTime.now().toIso8601String().substring(0, 10);
      final occurrences = await db.query(
        'routine_occurrences',
        where: 'date = ?',
        whereArgs: [todayStr],
      );
      final totalRoutines = occurrences.length;
      final completedRoutines = occurrences
          .where((e) => e['status'] == 'done')
          .length;

      // 2. Fetch worship practices completion stats for today
      final activePrayers = await db.query(
        'worship_practices',
        where: 'isActive = 1',
      );
      final completedPrayersList = await db.query(
        'worship_practices',
        where: 'dailyDoneDate = ? AND dailyDone >= 1 AND isActive = 1',
        whereArgs: [todayStr],
      );
      final totalPrayers = activePrayers.length;
      final completedPrayers = completedPrayersList.length;

      // 3. Fetch list of available zones (respecting hideOtherRealms privacy F-11)
      final List<Map<String, dynamic>> zonesList;
      final activeRealm = realmState.realmOrNull;
      if (activeRealm != null && activeRealm.hideOtherRealms) {
        zonesList = await db.query(
          'zones',
          where: 'id = ?',
          whereArgs: [activeRealm.id],
        );
      } else {
        zonesList = await db.query('zones');
      }
      final zoneNames = zonesList.map((e) => e['name']! as String).toList();
      final zoneIds = zonesList.map((e) => e['id']! as String).toList();

      // Update Native notification
      await sl<NotificationPlatform>().startStatusMode(
        zone: actZoneName,
        energy: currentEnergyStr == 'LOW'
            ? 'پایین'
            : (currentEnergyStr == 'HIGH' ? 'بالا' : 'متوسط'),
        proposedTask: nextTask?.title ?? 'استراحت 🌿',
        proposedTaskId: nextTask?.id,
        completedRoutines: completedRoutines,
        totalRoutines: totalRoutines,
        completedPrayers: completedPrayers,
        totalPrayers: totalPrayers,
        zoneNames: zoneNames,
        zoneIds: zoneIds,
      );
    } catch (e, stack) {
      debugPrint(
        '[ForegroundNotificationUpdater] failed to update notification: $e\n$stack',
      );
    }
  }
}
