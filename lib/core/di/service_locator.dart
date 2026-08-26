// lib/core/di/service_locator.dart

import 'package:get_it/get_it.dart';
import 'package:ritmo/core/analytics/assistant_engine.dart';
import 'package:ritmo/core/analytics/cognitive_routing_engine.dart';
import 'package:ritmo/core/analytics/daily_budget_engine.dart';
import 'package:ritmo/core/analytics/energy_analytics_engine.dart';
import 'package:ritmo/core/analytics/fresh_start_engine.dart';
import 'package:ritmo/core/analytics/goals_engine.dart';
import 'package:ritmo/core/analytics/health_engine.dart';
import 'package:ritmo/core/analytics/insight_generation_engine.dart';
import 'package:ritmo/core/analytics/konkur_engine.dart';
import 'package:ritmo/core/analytics/life_balance_engine.dart';
import 'package:ritmo/core/analytics/milestone_engine.dart';
import 'package:ritmo/core/analytics/mood_engine.dart';
import 'package:ritmo/core/analytics/motivation_diagnosis_engine.dart';
import 'package:ritmo/core/analytics/notes_engine.dart';
import 'package:ritmo/core/analytics/reflection_engine.dart';
import 'package:ritmo/core/analytics/sleep_engine.dart';
import 'package:ritmo/core/backend/auth_service.dart';
import 'package:ritmo/core/ai/agent/catalog/agent_tools_initializer.dart';
import 'package:ritmo/core/behavior/behavioral_intelligence_orchestrator.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/agenda/agenda_renderer_registry.dart';
import 'package:ritmo/core/domain/agenda/day_agenda_service.dart';
import 'package:ritmo/core/domain/commands/commands_registry.dart';
import 'package:ritmo/core/domain/commands/ritmo_command_bus.dart';
import 'package:ritmo/core/domain/engines/cycle_engine.dart';
import 'package:ritmo/core/domain/engines/medical_engine.dart';
import 'package:ritmo/core/domain/engines/ritmo_engine_bus.dart';
import 'package:ritmo/core/domain/engines/ritmo_event_bus.dart';
import 'package:ritmo/core/domain/engines/ritmo_intelligence_orchestrator.dart';
import 'package:ritmo/core/domain/personas/persona_registry.dart';
import 'package:ritmo/core/localization/locale_repository.dart';
import 'package:ritmo/core/logging/ritmo_logger.dart';
import 'package:ritmo/core/platform/alarm_platform.dart';
import 'package:ritmo/core/platform/backup_platform.dart';
import 'package:ritmo/core/platform/notification_platform.dart';
import 'package:ritmo/core/services/device_service.dart';
import 'package:ritmo/core/services/google_drive_backup_service.dart';
import 'package:ritmo/core/services/premium_service.dart';
import 'package:ritmo/core/theme/theme_repository.dart';
import 'package:ritmo/core/time/ritmo_clock.dart';
import 'package:ritmo/features/courses/logic/courses_repository.dart';
import 'package:ritmo/features/goals/logic/goals_repository.dart';
import 'package:ritmo/features/konkur/logic/konkur_repository.dart';
import 'package:ritmo/features/supplementary_sports/data/repositories/mv_session_repository.dart';

final sl = GetIt.instance;

class AppBootstrapper {
  AppBootstrapper._();

  static bool _initializedCore = false;
  static bool _initializedFull = false;
  static Future<void>? _initFuture;

  /// Lightweight initializer that registers only essential core singletons (BOOT-01).
  /// Safe and fast for background isolates (RIT-045).
  static Future<void> initCore() async {
    if (_initializedCore && sl.isRegistered<ThemeRepository>()) {
      return;
    }

    if (!sl.isRegistered<RitmoClock>()) {
      sl.registerSingleton<RitmoClock>(const SystemClock());
    }
    if (!sl.isRegistered<DatabaseHelper>()) {
      sl.registerSingleton<DatabaseHelper>(DatabaseHelper.instance);
    }
    if (!sl.isRegistered<PremiumService>()) {
      sl.registerSingleton<PremiumService>(PremiumService.instance);
    }
    if (!sl.isRegistered<DeviceService>()) {
      sl.registerSingleton<DeviceService>(DeviceService.instance);
    }
    if (!sl.isRegistered<AlarmPlatform>()) {
      sl.registerSingleton<AlarmPlatform>(const MethodChannelAlarmPlatform());
    }
    if (!sl.isRegistered<NotificationPlatform>()) {
      sl.registerSingleton<NotificationPlatform>(
        const MethodChannelNotificationPlatform(),
      );
    }
    if (!sl.isRegistered<BackupPlatform>()) {
      sl.registerSingleton<BackupPlatform>(GoogleDriveBackupService.instance);
    }
    if (!sl.isRegistered<ThemeRepository>()) {
      sl.registerSingleton<ThemeRepository>(ThemeRepository());
    }
    if (!sl.isRegistered<LocaleRepository>()) {
      sl.registerSingleton<LocaleRepository>(LocaleRepository());
    }
    if (!sl.isRegistered<AuthService>()) {
      sl.registerSingleton<AuthService>(AuthService.instance);
    }

    _initializedCore = true;
  }

  /// Full initializer that registers all singletons, analytical engines, personas, and command bus.
  /// Used by the main UI application (BOOT-01).
  static Future<void> init() {
    if (_initializedFull && sl.isRegistered<RitmoIntelligenceOrchestrator>()) {
      return Future<void>.value();
    }
    return _initFuture ??= _doInit().whenComplete(() {
      _initFuture = null;
    });
  }

  static void _registerIfNot<T extends Object>(T instance) {
    if (!sl.isRegistered<T>()) {
      sl.registerSingleton<T>(instance);
    }
  }

  static Future<void> _doInit() async {
    try {
      // 0. Register Core Singletons first
      await initCore();

      // 1. Initialize Event Bus, Commands and Agent Tools
      registerAllRitmoCommands();
      initializeAllAgentTools();
      if (RitmoCommandBus.instance.registeredCommandIds.isEmpty) {
        throw StateError(
          'Bootstrap invariant violated: Commands must be registered before personas (BOOT-03).',
        );
      }

      PersonaRegistry.instance.initStandardPersonas();
      final globalPersona = PersonaRegistry.instance.getPersona('global');
      if (globalPersona == null || globalPersona.commandIds.isEmpty) {
        throw StateError(
          'Bootstrap invariant violated: Global persona missing or has no commands (BOOT-03).',
        );
      }

      // Agenda Renderers (BOOT-09)
      AgendaRendererRegistry.register(
        AgendaDomain.prayer,
        const PrayerAgendaRenderer(),
      );

      final eventBus = RitmoEventBus();
      _registerIfNot<RitmoEventBus>(eventBus);

      // Analytical engines registration (BOOT-08)
      final registry = EngineRegistry()
        ..register(LifeBalanceEngine())
        ..register(EnergyAnalyticsEngine())
        ..register(MilestoneEngine())
        ..register(InsightGenerationEngine())
        ..register(MedicineEngine())
        ..register(CycleEngine())
        ..register(KonkurEngine())
        ..register(GoalsEngine())
        ..register(SleepEngine())
        ..register(MoodEngine())
        ..register(AssistantEngine())
        ..register(ReflectionEngine())
        ..register(HealthEngine())
        ..register(BehavioralIntelligenceOrchestrator())
        ..register(MotivationDiagnosisEngine())
        ..register(DailyBudgetEngine())
        ..register(CognitiveRoutingEngine())
        ..register(FreshStartEngine())
        ..register(NotesEngine());

      _registerIfNot<EngineRegistry>(registry);

      RitmoEngineBus.init(registry);
      _registerIfNot<RitmoEngineBus>(RitmoEngineBus.instance);

      // 2. Intelligence Orchestrator
      final orchestrator = RitmoIntelligenceOrchestrator(
        engineBus: RitmoEngineBus.instance,
        eventBus: eventBus,
      );
      _registerIfNot<RitmoIntelligenceOrchestrator>(orchestrator);

      // 3. Register Additional Services and Singletons
      _registerIfNot<DayAgendaService>(DayAgendaService.instance);

      // 4. Register Feature Repositories
      _registerIfNot<CoursesRepository>(CoursesRepository.instance);
      _registerIfNot<GoalsRepository>(GoalsRepository.instance);
      _registerIfNot<KonkurRepository>(KonkurRepository.instance);
      _registerIfNot<MvSessionRepository>(MvSessionRepository());

      _initializedFull = true;
    } catch (e, st) {
      await sl.reset();
      _initializedCore = false;
      _initializedFull = false;
      _initFuture = null;
      RitmoLog.error(
        'AppBootstrapper',
        'init failed, resetting GetIt state (BOOT-01)',
        e,
        st,
      );
      rethrow;
    }
  }
}
