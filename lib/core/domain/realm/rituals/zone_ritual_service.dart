import 'package:ritmo/core/domain/realm/realm_state.dart';
import 'package:ritmo/core/domain/realm/rituals/zone_ritual.dart';

/// Evaluates and orchestrates transition rituals between realms (F-14).
class ZoneRitualService {
  const ZoneRitualService();

  /// Determines the active ritual to display during a realm transition (or null if none).
  ///
  /// Priority: Exit ritual of the departing realm takes precedence to prevent task bleed,
  /// followed by the Enter ritual of the arriving realm.
  ({RealmData realm, ZoneRitualConfig ritual, bool isExit})? getPendingRitual({
    RealmData? previousRealm,
    RealmData? nextRealm,
  }) {
    // 1. Check Exit Ritual of previous realm (e.g. Wrap up work before going home)
    if (previousRealm != null &&
        previousRealm.id != nextRealm?.id &&
        previousRealm.ritualOnExit != null &&
        previousRealm.ritualOnExit!.isEnabled) {
      return (
        realm: previousRealm,
        ritual: previousRealm.ritualOnExit!,
        isExit: true,
      );
    }

    // 2. Check Enter Ritual of new realm (e.g. Mindful intention when entering Study or Prayer)
    if (nextRealm != null &&
        nextRealm.id != previousRealm?.id &&
        nextRealm.ritualOnEnter != null &&
        nextRealm.ritualOnEnter!.isEnabled) {
      return (
        realm: nextRealm,
        ritual: nextRealm.ritualOnEnter!,
        isExit: false,
      );
    }

    return null;
  }
}
