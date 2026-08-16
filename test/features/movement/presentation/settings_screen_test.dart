import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/movement/application/movement_preferences_service.dart';
import 'package:ritmo/features/movement/presentation/settings/movement_settings_screen.dart';
import 'package:ritmo/features/movement/presentation/settings/widgets/settings_choice_row.dart';
import 'package:ritmo/features/movement/presentation/settings/widgets/settings_group.dart';
import 'package:ritmo/features/movement/presentation/settings/widgets/settings_switch_row.dart';

class FakeMovementPreferencesService extends MovementPreferencesService {
  final Map<String, dynamic> _store = {
    'distanceUnit': 'km',
    'weightUnit': 'kg',
    'defaultReminderTime': '08:00',
    'morningReminder': true,
    'preSessionReminder': true,
    'quietMode': false,
    'keepScreenOn': true,
    'soundEnabled': true,
    'hapticEnabled': true,
    'countdownSeconds': 3,
    'smartSuggestionsEnabled': true,
    'interventionLevel': 'medium',
    'planBBehavior': 'auto_suggest',
  };

  @override
  Future<Map<String, dynamic>> getAllSettings() async {
    return Map.from(_store);
  }

  @override
  Future<void> setString(String key, String value) async {
    _store[key] = value;
  }

  @override
  Future<void> setBool(String key, bool value) async {
    _store[key] = value;
  }

  @override
  Future<void> setInt(String key, int value) async {
    _store[key] = value;
  }
}

void main() {
  Widget createTestWidget(Widget child) {
    return MaterialApp(
      theme: RitmoTheme.build(
        palette: RitmoPalette.jadeNoir,
        brightness: Brightness.dark,
      ),
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: child,
      ),
    );
  }

  group('MovementSettingsScreen Tests (Gate 5)', () {
    testWidgets('renders all 6 setting groups with switches and choices', (tester) async {
      await tester.pumpWidget(createTestWidget(
        MovementSettingsScreen(
          preferencesService: FakeMovementPreferencesService(),
        ),
      ));

      await tester.pumpAndSettle();

      expect(find.text('تنظیمات حرکت'), findsOneWidget);
      expect(find.byType(SettingsGroup), findsNWidgets(6));
      expect(find.byType(SettingsSwitchRow), findsWidgets);
      expect(find.byType(SettingsChoiceRow<String>), findsWidgets);

      // Verify medical disclaimer is present
      expect(find.text('این بخش جایگزین مربی یا پزشک نیست.'), findsOneWidget);
    });
  });
}
