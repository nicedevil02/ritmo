import 'package:ritmo/core/domain/engines/rie/context_snapshot.dart';
import 'package:ritmo/core/domain/models.dart';
import 'package:ritmo/core/domain/models/daily_behavior.dart';
import 'package:ritmo/core/domain/realm/realm_mode.dart';
import 'package:ritmo/core/modules/module_gate.dart';

abstract interface class RoutineFilter {
  /// Returns a filtered list of routines based on the environment rules
  /// defined in the [snapshot].
  List<Routine> filter(List<Routine> routines, ContextSnapshot snapshot);
}

/// Layer 0: Module Gate Filter
class ModuleGateFilter implements RoutineFilter {
  const ModuleGateFilter();

  @override
  List<Routine> filter(List<Routine> routines, ContextSnapshot snapshot) {
    return routines
        .where((r) => isModuleEnabled(r.category, snapshot.appSettings))
        .toList();
  }

  static bool isModuleEnabled(Category category, Map<String, String> settings) {
    switch (category) {
      case Category.religious:
        return ModuleGate.instance.isEnabledFrom(
          settings,
          'module_religion_enabled',
        );
      case Category.medical:
        return ModuleGate.instance.isEnabledFrom(
          settings,
          'module_medicine_enabled',
        );
      case Category.learning:
        return ModuleGate.instance.isEnabledFrom(
          settings,
          'module_courses_enabled',
        );
      case Category.konkur:
        return ModuleGate.instance.isEnabledFrom(
          settings,
          'module_study_enabled',
        );
      case Category.work:
      case Category.personal:
      case Category.fitness:
      case Category.free:
      case Category.custom:
        return true;
    }
  }
}

/// Layer 1: Biological Constraints Filter
class BiologicalConstraintsFilter implements RoutineFilter {
  const BiologicalConstraintsFilter();

  @override
  List<Routine> filter(List<Routine> routines, ContextSnapshot snapshot) {
    // Consent is enabled by default unless explicitly disabled with 'false'
    final worshipConsent =
        snapshot.appSettings['cycle_consent_worship'] != 'false';

    return routines.where((r) {
      // Menstruation suppresses religious routines if consent is enabled
      if (snapshot.isMenstruating &&
          r.category == Category.religious &&
          worshipConsent) {
        return false;
      }
      return true;
    }).toList();
  }
}

/// Layer 2: Zone & Essential Rules Filter (B-02, B-10, B-11, B-13)
class ZoneAndEssentialFilter implements RoutineFilter {
  const ZoneAndEssentialFilter();

  @override
  List<Routine> filter(List<Routine> routines, ContextSnapshot snapshot) {
    final mode = snapshot.activeRealmMode;
    final blockedRoutineIds = snapshot.blockedRoutineIdsInZone;

    return routines.where((r) {
      final explicitlyBlocked = blockedRoutineIds.contains(r.id);
      final isCriticalMedical = r.category == Category.medical && r.isEssential;

      // Safety exception: medical + essential always passes explicit block
      if (explicitlyBlocked) {
        return isCriticalMedical;
      }

      // Mode-based suppression for non-essential routines (B-02, B-10)
      if (mode.suppressesNonEssential && !r.isEssential) {
        return false;
      }

      // In SILENT mode, essential routines cannot bypass unless they are critical medical (B-10, allowsEssentialBypass)
      if (mode == RealmMode.silent && !isCriticalMedical) {
        return false;
      }

      // F-11: Real separation - strictly hide routines tagged with a different realm
      if (snapshot.hideOtherRealms &&
          snapshot.activeZoneId != null &&
          snapshot.activeZoneId!.isNotEmpty) {
        if (r.zoneId != null &&
            r.zoneId!.isNotEmpty &&
            r.zoneId != snapshot.activeZoneId) {
          return isCriticalMedical;
        }
      }

      return true;
    }).toList();
  }
}

/// Layer 3: Energy Engine Filter
class EnergyEngineFilter implements RoutineFilter {
  const EnergyEngineFilter();

  @override
  List<Routine> filter(List<Routine> routines, ContextSnapshot snapshot) {
    final currentEnergy = snapshot.currentEnergy;

    return routines.where((r) {
      if (currentEnergy == EnergyLevel.low && !r.isEssential) {
        if (r.energyRule == EnergyRule.skip ||
            r.energyRule == EnergyRule.highEnergyOnly) {
          return false;
        }
      }
      return true;
    }).toList();
  }
}

/// Layer 5: Context & Daily Behavior Filter
class ContextDailyBehaviorFilter implements RoutineFilter {
  const ContextDailyBehaviorFilter();

  @override
  List<Routine> filter(List<Routine> routines, ContextSnapshot snapshot) {
    final dailyBehavior = snapshot.dailyBehavior;
    final behavior = dailyBehavior.behavior;
    final context = dailyBehavior.context;

    return routines.where((r) {
      if (behavior == 'SILENCE_ALL') {
        final isCriticalMedicine =
            r.category == Category.medical && r.isEssential;
        if (!isCriticalMedicine) {
          return false;
        }
      } else if (behavior == 'ESSENTIAL_ONLY') {
        if (!r.isEssential) {
          return false;
        }
      }

      if (context == LifeContext.sick && r.category == Category.fitness) {
        return false;
      }

      return true;
    }).toList();
  }
}
