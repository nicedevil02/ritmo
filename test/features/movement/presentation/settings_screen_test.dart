import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/movement/application/movement_preferences_service.dart';
import 'package:ritmo/features/movement/presentation/settings/movement_settings_screen.dart';
import 'package:ritmo/features/movement/presentation/settings/widgets/settings_danger_row.dart';
import 'package:ritmo/features/movement/presentation/settings/widgets/settings_group.dart';

class FakeMovementPreferencesService extends MovementPreferencesService {
  int _weeklyGoal = 3;
  List<int> _days = [0, 2, 4];
  int? _reminder = 8;

  @override
  Future<int> getWeeklyGoalSessions() async => _weeklyGoal;

  @override
  Future<void> setWeeklyGoalSessions(int count) async => _weeklyGoal = count;

  @override
  Future<List<int>> getPreferredDays() async => _days;

  @override
  Future<void> setPreferredDays(List<int> days) async => _days = days;

  @override
  Future<int?> getReminderHour() async => _reminder;

  @override
  Future<void> setReminderHour(int? hour) async => _reminder = hour;

  @override
  Future<void> deleteAllMovementData() async {
    _weeklyGoal = 3;
    _days = [0, 2, 4];
    _reminder = 8;
  }
}

void main() {
  Widget createTestWidget(Widget child) {
    return MaterialApp(
      theme: RitmoTheme.build(
        palette: RitmoPalette.jadeNoir,
        brightness: Brightness.dark,
      ),
      home: Directionality(textDirection: TextDirection.rtl, child: child),
    );
  }

  group('MovementSettingsScreen Tests (D-39)', () {
    testWidgets('renders streamlined settings screen with 3 main settings', (
      tester,
    ) async {
      await tester.pumpWidget(
        createTestWidget(
          MovementSettingsScreen(
            preferencesService: FakeMovementPreferencesService(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('تنظیمات حرکت'), findsOneWidget);
      expect(find.text('هدف هفتگی'), findsOneWidget);
      expect(find.text('روزهای ترجیحی تمرین'), findsOneWidget);
      expect(find.text('یادآور روزانه'), findsOneWidget);
      expect(find.byType(SettingsGroup), findsNWidgets(3));
      expect(find.byType(SettingsDangerRow), findsOneWidget);
    });
  });
}
