import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:persian_datetime_picker/persian_datetime_picker.dart';
import 'package:ritmo/core/app_mode/app_mode_service.dart';
import 'package:ritmo/core/backend/auth_service.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/di/service_locator.dart';
import 'package:ritmo/core/domain/engines/ritmo_intelligence_orchestrator.dart';
import 'package:ritmo/core/localization/locale_repository.dart';
import 'package:ritmo/core/logging/ritmo_logger.dart';
import 'package:ritmo/core/navigation/ritmo_router.dart';
import 'package:ritmo/core/observability/privacy_error_sink.dart';
import 'package:ritmo/core/observability/ritmo_friendly_error_pane.dart';
import 'package:ritmo/core/security/app_lock_gate.dart';
import 'package:ritmo/core/services/background_worker.dart';
import 'package:ritmo/core/services/notification_action_dispatcher.dart';
import 'package:ritmo/core/services/sleep_winddown_reminder_service.dart';
import 'package:ritmo/core/settings/settings_service.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/theme/theme_preferences.dart';
import 'package:ritmo/core/theme/theme_repository.dart';
import 'package:ritmo/core/time/ritmo_clock.dart';
import 'package:ritmo/core/widgets/restart_widget.dart';
import 'package:ritmo/features/courses/logic/course_timer_service.dart';
import 'package:ritmo/features/onboarding/logic/onboarding_gate.dart';
import 'package:ritmo/features/onboarding/presentation/onboarding_screen.dart';
import 'package:ritmo/features/onboarding/presentation/splash_screen.dart';
import 'package:ritmo/features/simple_tasks/logic/share_target_handler.dart';
import 'package:ritmo/features/today/presentation/home_navigation_shell.dart';
import 'package:ritmo/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Memory optimization: Bound Flutter image cache to prevent RSS/VRAM bloat
  PaintingBinding.instance.imageCache.maximumSize = 100;
  PaintingBinding.instance.imageCache.maximumSizeBytes =
      30 * 1024 * 1024; // 30 MB

  RitmoLog.addSink(PrivacyErrorSink.instance);
  await PrivacyErrorSink.instance.init();

  FlutterError.onError = (details) {
    PrivacyErrorSink.instance.logError(
      'FlutterError',
      details.exceptionAsString(),
      details.exception,
      details.stack,
    );
    RitmoLog.error(
      'FlutterError',
      details.exceptionAsString(),
      details.exception,
      details.stack,
    );
    if (kDebugMode) {
      FlutterError.presentError(details);
    }
  };

  // Sliding window rate limiter for error storms (10 errors within 60s)
  final List<DateTime> errorTimestamps = [];
  bool hasShownErrorStormDialog = false;
  Timer? errorStormCooldownTimer;

  bool isTolerableAsyncError(Object error) {
    if (error is SocketException ||
        error is HttpException ||
        error is TimeoutException ||
        error is HandshakeException ||
        error is TlsException) {
      return true;
    }
    final errStr = error.toString().toLowerCase();
    return errStr.contains('socketexception') ||
        errStr.contains('httpexception') ||
        errStr.contains('handshake') ||
        errStr.contains('connection reset') ||
        errStr.contains('clientexception') ||
        errStr.contains('failed host lookup') ||
        errStr.contains('network is unreachable');
  }

  PlatformDispatcher.instance.onError = (error, stack) {
    // 1. Guaranteed logging to PrivacyErrorSink and logger
    PrivacyErrorSink.instance.logError(
      'PlatformError',
      error.toString(),
      error,
      stack,
    );
    RitmoLog.error('PlatformError', error.toString(), error, stack);

    // 2. Error storm detection
    final now = DateTime.now();
    errorTimestamps.add(now);
    errorTimestamps.removeWhere((t) => now.difference(t).inSeconds > 60);

    if (errorTimestamps.length >= 10 && !hasShownErrorStormDialog) {
      hasShownErrorStormDialog = true;
      errorStormCooldownTimer?.cancel();
      errorStormCooldownTimer = Timer(const Duration(minutes: 10), () {
        hasShownErrorStormDialog = false;
      });

      unawaited(
        SharedPreferences.getInstance().then((prefs) {
          final count = prefs.getInt('error_storm_count') ?? 0;
          prefs.setInt('error_storm_count', count + 1);
        }),
      );

      SchedulerBinding.instance.addPostFrameCallback((_) {
        final navContext = RitmoRouter.navigatorKey.currentContext;
        if (navContext != null && navContext.mounted) {
          showDialog<void>(
            context: navContext,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text(
                'مشکلی پیش آمده',
                style: TextStyle(
                  fontFamily: 'Vazirmatn',
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              content: const Text(
                'برنامه با خطاهای متوالی مواجه شده است. داده‌های شما محفوظ هستند اما در صورت تداوم مشکل، راه‌اندازی مجدد برنامه توصیه می‌شود.',
                style: TextStyle(
                  fontFamily: 'Vazirmatn',
                  fontSize: 13,
                  height: 1.6,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text(
                    'متوجه شدم',
                    style: TextStyle(
                      fontFamily: 'Vazirmatn',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          );
        }
      });
    }

    // Explicit Policy Rationale (RIT-004):
    // In release mode, only mark known tolerable network/transient async errors as handled (return true).
    // Unknown or unexpected fatal exceptions return false to be properly captured by crash reporting sinks.
    // In debug mode, always return false to surface uncaught async errors in the developer console.
    if (kReleaseMode) {
      return isTolerableAsyncError(error);
    }
    return false;
  };

  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS)) {
    unawaited(
      Future.microtask(() async {
        try {
          final prefs = await SharedPreferences.getInstance();

          // Clean up legacy single-register flag if present
          if (prefs.containsKey('wm_registered_v2')) {
            await prefs.remove('wm_registered_v2');
          }

          // Store handle before scheduling tasks (BOOT-10)
          final handle = PluginUtilities.getCallbackHandle(
            notificationActionDispatcher,
          )?.toRawHandle();
          if (handle != null) {
            await prefs.setInt('notification_action_callback_handle', handle);
          }

          // Digest count reset comparison using DayKey (BOOT-11)
          final todayStr = DayKey.from(DateTime.now()).value;
          final lastResetDate = prefs.getString('digest_notif_reset_date');
          if (lastResetDate != todayStr) {
            await prefs.setInt('digest_notif_count', 0);
            await prefs.setString('digest_notif_reset_date', todayStr);
          }

          // Workmanager initialization on every non-web mobile boot (P0-04)
          await Workmanager().initialize(ritmoCallbackDispatcher);
          await Workmanager().registerPeriodicTask(
            'ritmo_periodic_reschedule',
            'ritmoRescheduleTask',
            frequency: const Duration(hours: 6),
            existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
            constraints: Constraints(networkType: NetworkType.notRequired),
            backoffPolicy: BackoffPolicy.linear,
          );
        } catch (e, st) {
          RitmoLog.error(
            'BackgroundInit',
            'Workmanager init/register error',
            e,
            st,
          );
        }
      }),
    );
  }

  ErrorWidget.builder = (details) {
    return RitmoFriendlyErrorPane(details: details);
  };

  // 1. Initialize service locator & settings cache (AgendaRenderers registered inside AppBootstrapper.init - BOOT-09)
  await AppBootstrapper.init();
  await SettingsService.instance.init();

  // 2. Initialize database and repositories before runApp
  final themeRepository = sl<ThemeRepository>();
  await themeRepository.init();

  final localeRepository = sl<LocaleRepository>();
  await localeRepository.init();

  await AppModeService.instance.load();

  runApp(
    RestartWidget(
      child: ProviderScope(
        child: RitmoApp(
          themeRepository: themeRepository,
          localeRepository: localeRepository,
          orchestrator: sl<RitmoIntelligenceOrchestrator>(),
        ),
      ),
    ),
  );

  // Initialize OS share target listener (T-32)
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    ShareTargetHandler.init();
  }

  // Deferred non-critical Auth init after runApp (BOOT-02)
  unawaited(
    AuthService.instance.init().timeout(const Duration(seconds: 8)).catchError((
      Object e,
      StackTrace st,
    ) {
      RitmoLog.warning('AuthService', 'Deferred init failed (offline?): $e');
    }),
  );
}

class RitmoApp extends StatefulWidget {
  const RitmoApp({
    super.key,
    required this.themeRepository,
    required this.localeRepository,
    required this.orchestrator,
  });
  final ThemeRepository themeRepository;
  final LocaleRepository localeRepository;
  final RitmoIntelligenceOrchestrator orchestrator;

  @override
  State<RitmoApp> createState() => _RitmoAppState();
}

class _RitmoAppState extends State<RitmoApp> {
  bool _showSplash = true;
  bool _onboardingCompleted = false;
  Object? _initError;
  late Future<void> _initializationFuture;

  @override
  void initState() {
    super.initState();
    _initializationFuture = _initialize();
  }

  Future<void> _initialize() async {
    try {
      if (mounted) setState(() => _initError = null);

      // Check if SettingsService is in degraded state (RIT-002 fail-closed)
      if (SettingsService.instance.isDegraded) {
        throw StateError(
          'سرویس تنظیمات در حالت غیرقابل‌اتکا قرار دارد: ${SettingsService.instance.initError}',
        );
      }

      final db = await DatabaseHelper.instance.database;

      // 1. Critical DDL schema verification - blocking without timeout (RIT-003)
      await DatabaseHelper.ensureCriticalSchema(db);

      // 2. Non-critical background warmup tasks with timeout (BOOT-07)
      await DatabaseHelper.warmUp(db).timeout(
        const Duration(seconds: 5),
        onTimeout: () => RitmoLog.warning('Init', 'Database warmup timed out'),
      );

      // قدم صفر: همگام‌سازی یادآور پیش‌خواب با تنظیمات در هر شروع اپ
      unawaited(SleepWinddownReminderService.syncFromSettings());

      // Restore any in-progress course study timer safely
      try {
        await CourseTimerService.instance.initOnAppStart();
      } catch (e, st) {
        RitmoLog.warning('Init', 'Course timer init non-fatal error: $e', e, st);
      }

      // Check if onboarding is completed via OnboardingGate
      _onboardingCompleted = await OnboardingGate.isCompleted(db);
    } catch (e, st) {
      await PrivacyErrorSink.instance.logError(
        'Init',
        'Critical startup error in _initialize (BOOT-04)',
        e,
        st,
      );
      RitmoLog.error(
        'Init',
        'Critical startup error in _initialize (BOOT-04)',
        e,
        st,
      );
      if (mounted) {
        setState(() {
          _initError = e;
        });
      }
    }
  }

  void _applySystemOverlay(RitmoColors colors, Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: brightness,
        systemNavigationBarColor: colors.systemNavBar,
        systemNavigationBarIconBrightness: isDark
            ? Brightness.light
            : Brightness.dark,
      ),
    );
  }

  ThemeData? _lightCache;
  ThemeData? _darkCache;
  Object? _themeInputsKey;

  void _ensureThemes(RitmoPalette palette, ThemePreferences prefs) {
    final inputsKey =
        '${prefs.paletteId}|${prefs.mode}|${prefs.reduceTransparency}'
        '|${prefs.trueBlack}|${prefs.density}|${prefs.textScalePercent}'
        '|${prefs.followOsTextScale}|${prefs.glassBlurSigma}|${prefs.glassOpacityPercent}';
    if (_themeInputsKey == inputsKey &&
        _lightCache != null &&
        _darkCache != null) {
      return;
    }
    _themeInputsKey = inputsKey;
    _lightCache = RitmoTheme.build(
      palette: palette,
      brightness: Brightness.light,
      reduceTransparency: prefs.reduceTransparency,
      glassBlurSigma: prefs.glassBlurSigma,
      glassOpacityPercent: prefs.glassOpacityPercent,
      density: prefs.density,
    );
    _darkCache = RitmoTheme.build(
      palette: palette,
      brightness: Brightness.dark,
      reduceTransparency: prefs.reduceTransparency,
      trueBlack: prefs.trueBlack,
      glassBlurSigma: prefs.glassBlurSigma,
      glassOpacityPercent: prefs.glassOpacityPercent,
      density: prefs.density,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemePreferences>(
      valueListenable: widget.themeRepository.preferencesNotifier,
      builder: (context, prefs, _) {
        final palette = RitmoPalette.byId(prefs.paletteId);
        _ensureThemes(palette, prefs);

        return MaterialApp(
          title: 'ریتمو',
          navigatorKey: RitmoRouter.navigatorKey,
          onGenerateRoute: RitmoRouter.onGenerateRoute,
          themeMode: prefs.mode,
          theme: _lightCache,
          darkTheme: _darkCache,
          locale: const Locale('fa'),
          supportedLocales: const [Locale('fa')],
          localizationsDelegates: const [
            PersianMaterialLocalizations.delegate,
            PersianCupertinoLocalizations.delegate,
            ...AppLocalizations.localizationsDelegates,
          ],
          debugShowCheckedModeBanner: false,
          builder: (context, child) {
            final mq = MediaQuery.of(context);
            final brightness = Theme.of(context).brightness;
            final colors =
                Theme.of(context).extension<RitmoColors>() ??
                palette.forBrightness(brightness);
            _applySystemOverlay(colors, brightness);
            final effective = RitmoUiScale.effectiveTextScale(
              osScale: mq.textScaler.scale(1.0),
              appPercent: prefs.textScalePercent,
              followOs: prefs.followOsTextScale,
            );
            return MediaQuery(
              data: mq.copyWith(textScaler: TextScaler.linear(effective)),
              child: AppLockGate(child: child!),
            );
          },
          home: _initError != null
              ? Scaffold(
                  body: SafeArea(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.error_outline,
                              size: 64,
                              color: Colors.amber,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'خطا در راه‌اندازی برنامه',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'مشکلی در بارگذاری اطلاعات پیش آمده است: $_initError',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 14),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: () {
                                setState(() {
                                  _initializationFuture = _initialize();
                                });
                              },
                              icon: const Icon(Icons.refresh),
                              label: const Text('تلاش مجدد'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                )
              : AnimatedSwitcher(
                  duration: kDebugMode
                      ? const Duration(milliseconds: 100)
                      : const Duration(milliseconds: 650),
                  switchInCurve: Curves.easeInOut,
                  switchOutCurve: Curves.easeInOut,
                  child: _showSplash
                      ? SplashScreen(
                          key: const ValueKey('splash'),
                          initializationFuture: _initializationFuture,
                          onInitializationComplete: () {
                            setState(() {
                              _showSplash = false;
                            });
                          },
                        )
                      : (_onboardingCompleted
                            ? HomeNavigationShell(
                                key: const ValueKey('home'),
                                themeRepository: widget.themeRepository,
                                localeRepository: widget.localeRepository,
                                onLogout: () async {
                                  await AuthService.instance.logout();
                                },
                              )
                            : OnboardingScreen(
                                key: const ValueKey('onboarding'),
                                onFinished: () {
                                  debugPrint(
                                    '[Main] Onboarding onFinished received! Setting _onboardingCompleted = true',
                                  );
                                  setState(() {
                                    _onboardingCompleted = true;
                                  });
                                },
                              )),
                ),
        );
      },
    );
  }
}
