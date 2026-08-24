import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/settings/settings_registry.dart';
import 'package:ritmo/core/settings/settings_service.dart';
import 'package:ritmo/core/theme/theme_preferences.dart';
import 'package:ritmo/core/theme/theme_repository.dart';
import 'package:ritmo/core/theme/ui_scale.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    SettingsService.instance.resetForTesting();
    await SettingsService.instance.init();
    await SettingsService.instance.set('ui_text_scale', 100);
    await SettingsService.instance.set('ui_text_follow_os', true);
    await SettingsService.instance.set('ui_density', 'comfortable');
  });

  group('UI Scale & Density Settings Registry & Repository Tests', () {
    test('Settings descriptors for ui_scale are properly registered', () {
      final textScaleDesc = SettingsRegistry.find('ui_text_scale');
      expect(textScaleDesc, isNotNull);
      expect(textScaleDesc!.type, SettingType.integer);
      expect(textScaleDesc.defaultValue, 100);
      expect(textScaleDesc.min, 85);
      expect(textScaleDesc.max, 140);
      expect(textScaleDesc.requiresRestart, isFalse);
      expect(textScaleDesc.scope, SettingScope.db);
      expect(textScaleDesc.searchTerms, contains('اندازه متن'));

      final followOsDesc = SettingsRegistry.find('ui_text_follow_os');
      expect(followOsDesc, isNotNull);
      expect(followOsDesc!.type, SettingType.boolean);
      expect(followOsDesc.defaultValue, isTrue);
      expect(followOsDesc.requiresRestart, isFalse);
      expect(followOsDesc.scope, SettingScope.db);

      final densityDesc = SettingsRegistry.find('ui_density');
      expect(densityDesc, isNotNull);
      expect(densityDesc!.type, SettingType.enumeration);
      expect(densityDesc.defaultValue, 'comfortable');
      expect(
        densityDesc.allowed,
        containsAll(['compact', 'comfortable', 'spacious', 'xl']),
      );
      expect(densityDesc.requiresRestart, isFalse);
      expect(densityDesc.scope, SettingScope.db);
    });

    test('ThemeRepository syncs from SettingsService live updates', () async {
      final repo = ThemeRepository();
      await repo.init();

      expect(repo.preferencesNotifier.value.textScalePercent, 100);
      expect(repo.preferencesNotifier.value.followOsTextScale, isTrue);
      expect(
        repo.preferencesNotifier.value.density,
        RitmoDensityLevel.comfortable,
      );

      // Update text scale
      await repo.updateTextScalePercent(125);
      expect(SettingsService.instance.get<int>('ui_text_scale'), 125);
      expect(repo.preferencesNotifier.value.textScalePercent, 125);

      // Update follow OS
      await repo.updateFollowOsTextScale(false);
      expect(SettingsService.instance.get<bool>('ui_text_follow_os'), isFalse);
      expect(repo.preferencesNotifier.value.followOsTextScale, isFalse);

      // Update density
      await repo.updateDensity(RitmoDensityLevel.xl);
      expect(SettingsService.instance.get<String>('ui_density'), 'xl');
      expect(repo.preferencesNotifier.value.density, RitmoDensityLevel.xl);

      repo.dispose();
    });

    test(
      'ThemeRepository resetAppearance restores defaults for UI scale and density',
      () async {
        final repo = ThemeRepository();
        await repo.init();

        await repo.updateTextScalePercent(140);
        await repo.updateFollowOsTextScale(false);
        await repo.updateDensity(RitmoDensityLevel.compact);

        expect(repo.preferencesNotifier.value.textScalePercent, 140);
        expect(
          repo.preferencesNotifier.value.density,
          RitmoDensityLevel.compact,
        );

        await repo.resetAppearance();

        expect(
          repo.preferencesNotifier.value.textScalePercent,
          ThemePreferences.defaults.textScalePercent,
        );
        expect(
          repo.preferencesNotifier.value.followOsTextScale,
          ThemePreferences.defaults.followOsTextScale,
        );
        expect(
          repo.preferencesNotifier.value.density,
          ThemePreferences.defaults.density,
        );

        expect(SettingsService.instance.get<int>('ui_text_scale'), 100);
        expect(SettingsService.instance.get<bool>('ui_text_follow_os'), isTrue);
        expect(
          SettingsService.instance.get<String>('ui_density'),
          'comfortable',
        );

        repo.dispose();
      },
    );
  });
}
