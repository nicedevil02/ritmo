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
import 'package:ritmo/features/movement/presentation/agenda/sport_agenda_renderer.dart';
import 'package:ritmo/core/services/premium_service.dart';
import 'package:ritmo/core/theme/theme_repository.dart';
import 'package:ritmo/core/time/ritmo_clock.dart';
import 'package:ritmo/features/courses/logic/courses_repository.dart';
import 'package:ritmo/features/goals/logic/goals_repository.dart';
import 'package:ritmo/features/konkur/logic/konkur_repository.dart';
import 'package:ritmo/features/supplementary_sports/data/repositories/ss_session_repository.dart';
import 'package:ritmo/features/supplementary_sports/data/repositories/ss_session_repository_impl.dart';

final sl = GetIt.instance;

class AppBootstrapper {
  AppBootstrapper._();

  static bool _initialized = false;
  static Future<void>? _initFuture;

  /// Standalone initializer that registers all core singletons.
  /// Decoupled from WidgetsFlutterBinding and runApp for isolate compatibility (BOOT-01).
  static Future<void> init() {
    if (_initialized && sl.isRegistered<ThemeRepository>()) return Future<void>.value();
    return _initFuture ??= _doInit();
  }

  static Future<void> _doInit() async {
    try {
      await sl.reset();

      // 0. Register Time Abstraction (BOOT-12)
      sl.registerSingleton<RitmoClock>(const SystemClock());

      // 1. Initialize Event Bus, Commands and Agent Tools
      registerAllRitmoCommands();
      initializeAllAgentTools();
      if (RitmoCommandBus.instance.registeredCommandIds.isEmpty) {
        throw StateError('Bootstrap invariant violated: Commands must be registered before personas (BOOT-03).');
      }

      PersonaRegistry.instance.initStandardPersonas();
      final globalPersona = PersonaRegistry.instance.getPersona('global');
      if (globalPersona == null || globalPersona.commandIds.isEmpty) {
        throw StateError('Bootstrap invariant violated: Global persona missing or has no commands (BOOT-03).');
      }

      // Agenda Renderers (BOOT-09)
      AgendaRendererRegistry.register(AgendaDomain.prayer, const PrayerAgendaRenderer());
      AgendaRendererRegistry.register(AgendaDomain.sport, const SportAgendaRenderer());

      final eventBus = RitmoEventBus();
      sl.registerSingleton<RitmoEventBus>(eventBus);

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

      sl.registerSingleton<EngineRegistry>(registry);

      RitmoEngineBus.init(registry);
      sl.registerSingleton<RitmoEngineBus>(RitmoEngineBus.instance);

      // 2. Intelligence Orchestrator
      final orchestrator = RitmoIntelligenceOrchestrator(
        engineBus: RitmoEngineBus.instance,
        eventBus: eventBus,
      );
      sl.registerSingleton<RitmoIntelligenceOrchestrator>(orchestrator);

      // 3. Register Core Services and Singletons
      sl.registerSingleton<DayAgendaService>(DayAgendaService.instance);
      sl.registerSingleton<DatabaseHelper>(DatabaseHelper.instance);
      sl.registerSingleton<PremiumService>(PremiumService.instance);
      sl.registerSingleton<DeviceService>(DeviceService.instance);

      // 4. Register Feature Repositories
      sl.registerSingleton<CoursesRepository>(CoursesRepository.instance);
      sl.registerSingleton<GoalsRepository>(GoalsRepository.instance);
      sl.registerSingleton<KonkurRepository>(KonkurRepository.instance);
      sl.registerSingleton<SSSessionRepository>(SSSessionRepositoryImpl());

      // 5. Register Repositories requiring async initialization
      final themeRepository = ThemeRepository();
      sl.registerSingleton<ThemeRepository>(themeRepository);

      final localeRepository = LocaleRepository();
      sl.registerSingleton<LocaleRepository>(localeRepository);

      // 6. Register Platform Implementations
      sl.registerSingleton<AlarmPlatform>(const MethodChannelAlarmPlatform());
      sl.registerSingleton<NotificationPlatform>(const MethodChannelNotificationPlatform());
      sl.registerSingleton<BackupPlatform>(GoogleDriveBackupService.instance);

      // 7. Register Backend Auth Services (BOOT-02: init deferred to non-critical path)
      sl.registerSingleton<AuthService>(AuthService.instance);

      _initialized = true;
    } catch (e, st) {
      await sl.reset();
      _initialized = false;
      _initFuture = null;
      RitmoLog.error('AppBootstrapper', 'init failed, resetting GetIt state (BOOT-01)', e, st);
      rethrow;
    }
  }
}
