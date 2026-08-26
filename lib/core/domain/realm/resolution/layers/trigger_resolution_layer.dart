import 'package:ritmo/core/domain/realm/realm_state.dart';
import 'package:ritmo/core/domain/realm/resolution/realm_context.dart';
import 'package:ritmo/core/domain/realm/resolution/realm_resolution_layer.dart';
import 'package:ritmo/core/domain/realm/triggers/zone_trigger.dart';

/// Priority 2: Evaluates hardware & environmental triggers (WiFi, Charger, Bluetooth, NFC, Geofence) (F-09, F-10).
class TriggerResolutionLayer implements RealmResolutionLayer {
  const TriggerResolutionLayer();

  @override
  Future<ActiveRealmState?> tryResolve(RealmContext ctx) async {
    final enabledTriggers = ctx.triggers.where((t) => t.isEnabled).toList()
      ..sort((a, b) => b.priority.compareTo(a.priority));

    for (final trigger in enabledTriggers) {
      final realm = ctx.realms.where((r) => r.id == trigger.zoneId).firstOrNull;
      if (realm == null) continue;

      final isMatched = switch (trigger.kind) {
        TriggerKind.wifiSsid => _matchesWifi(ctx.activeWifiSsid, trigger.value),
        TriggerKind.charger => _matchesCharger(ctx.isCharging, ctx.now, trigger.value),
        TriggerKind.bluetooth => _matchesBluetooth(trigger.value),
        TriggerKind.nfc => _matchesNfc(trigger.value),
        TriggerKind.geofence => _matchesGeofence(trigger.value),
        TriggerKind.calendarTag => false, // Handled in CalendarTagLayer (Priority 3)
      };

      if (isMatched) {
        final explanation = switch (trigger.kind) {
          TriggerKind.wifiSsid => 'به دلیل اتصال خودکار به شبکه وای‌فای «${ctx.activeWifiSsid ?? trigger.value}».',
          TriggerKind.charger => 'به دلیل اتصال به شارژر در بازه زمانی تعیین‌شده.',
          TriggerKind.bluetooth => 'به دلیل اتصال به بلوتوث «${trigger.value}».',
          TriggerKind.nfc => 'به دلیل اسکن تگ NFC «${trigger.value}».',
          TriggerKind.geofence => 'به دلیل ورود به موقعیت مکانی «${trigger.value}».',
          TriggerKind.calendarTag => '',
        };

        return TriggeredRealmState(
          realm: realm,
          trigger: trigger,
          startsAt: ctx.now,
          explanation: explanation,
        );
      }
    }

    return null;
  }

  bool _matchesWifi(String? currentSsid, String triggerSsid) {
    if (currentSsid == null || currentSsid.isEmpty) return false;
    final current = currentSsid.replaceAll('"', '').trim().toLowerCase();
    final target = triggerSsid.replaceAll('"', '').trim().toLowerCase();
    return current == target || current.contains(target);
  }

  bool _matchesCharger(bool isCharging, DateTime now, String windowValue) {
    if (!isCharging) return false;
    final trimmed = windowValue.trim();
    if (trimmed.isEmpty || trimmed.toUpperCase() == 'ALL_DAY') return true;

    // Parses time window format e.g. "23:00-06:30" or "22:00-08:00"
    final parts = trimmed.split('-');
    if (parts.length != 2) return true;

    final startParts = parts[0].trim().split(':');
    final endParts = parts[1].trim().split(':');
    if (startParts.length != 2 || endParts.length != 2) return true;

    final startMin = (int.tryParse(startParts[0]) ?? 0) * 60 + (int.tryParse(startParts[1]) ?? 0);
    final endMin = (int.tryParse(endParts[0]) ?? 0) * 60 + (int.tryParse(endParts[1]) ?? 0);
    final nowMin = now.hour * 60 + now.minute;

    if (startMin <= endMin) {
      return nowMin >= startMin && nowMin < endMin;
    } else {
      // Cross-midnight window (e.g. 23:00 - 06:30)
      return nowMin >= startMin || nowMin < endMin;
    }
  }

  bool _matchesBluetooth(String value) => false;
  bool _matchesNfc(String value) => false;
  bool _matchesGeofence(String value) => false;
}
