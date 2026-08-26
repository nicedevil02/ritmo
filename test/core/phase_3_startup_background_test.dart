import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/di/service_locator.dart';
import 'package:ritmo/core/domain/engines/ritmo_intelligence_orchestrator.dart';
import 'package:ritmo/core/localization/locale_repository.dart';
import 'package:ritmo/core/platform/alarm_platform.dart';
import 'package:ritmo/core/theme/theme_repository.dart';
import 'package:ritmo/core/time/ritmo_clock.dart';
import 'package:ritmo/l10n/app_localizations.dart';
import 'package:ritmo/main.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Phase 3: Startup, Background & Time Tests', () {
    test('RIT-044 & RIT-045: AppBootstrapper.initCore() registers core singletons without full engine graph', () async {
      await sl.reset();

      // 1. initCore() registers light singletons
      await AppBootstrapper.initCore();

      expect(sl.isRegistered<RitmoClock>(), isTrue);
      expect(sl.isRegistered<AlarmPlatform>(), isTrue);
      expect(sl.isRegistered<ThemeRepository>(), isTrue);
      expect(sl.isRegistered<LocaleRepository>(), isTrue);

      // Heavy engines must NOT be registered by initCore
      expect(sl.isRegistered<RitmoIntelligenceOrchestrator>(), isFalse);

      // 2. Full init() registers orchestrator and engines
      await AppBootstrapper.init();
      expect(sl.isRegistered<RitmoIntelligenceOrchestrator>(), isTrue);
    });

    test('RIT-042: Supported locales include Persian and English from AppLocalizations', () {
      const supported = AppLocalizations.supportedLocales;
      expect(supported, isNotEmpty);
      expect(supported.any((l) => l.languageCode == 'fa'), isTrue);
    });

    test('RIT-047: Animation duration test override works', () {
      expect(RitmoApp.debugOverrideAnimationDuration, isNull);
      RitmoApp.debugOverrideAnimationDuration = const Duration(milliseconds: 50);
      expect(RitmoApp.debugOverrideAnimationDuration, equals(const Duration(milliseconds: 50)));
      RitmoApp.debugOverrideAnimationDuration = null;
    });
  });
}
