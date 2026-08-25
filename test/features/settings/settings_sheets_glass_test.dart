import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/settings/ai_settings_guard.dart';
import 'package:ritmo/core/settings/settings_registry.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/profile/presentation/widgets/otp_verification_sheet.dart';
import 'package:ritmo/features/settings/presentation/widgets/ai_write_history_sheet.dart';
import 'package:ritmo/features/settings/presentation/widgets/setting_explainer_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _buildTestApp({
  required Widget child,
  bool isDark = false,
  bool isGlass = true,
  double blurSigma = 20.0,
}) {
  final themeData = RitmoTheme.build(
    palette: RitmoPalette.jadeNoir,
    brightness: isDark ? Brightness.dark : Brightness.light,
    reduceTransparency: !isGlass,
    glassBlurSigma: blurSigma,
  );

  return MaterialApp(
    theme: themeData,
    home: Scaffold(
      body: child,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('Settings Registry Persian Scale Options', () {
    test('calendar_default_scale contains Persian option labels', () {
      final desc = SettingsRegistry.find('calendar_default_scale');
      expect(desc, isNotNull);
      expect(desc!.optionLabelsFa, isNotNull);
      expect(desc.optionLabelsFa!['agenda'], contains('برنامه'));
      expect(desc.optionLabelsFa!['day'], contains('روزانه'));
      expect(desc.optionLabelsFa!['week'], equals('هفتگی'));
      expect(desc.optionLabelsFa!['month'], equals('ماهانه'));
      expect(desc.optionLabelsFa!['year'], equals('سالانه'));
    });
  });

  group('SettingExplainerSheet Glassmorphism Tests', () {
    const desc = SettingDescriptor(
      key: 'test_setting',
      type: SettingType.boolean,
      scope: SettingScope.db,
      defaultValue: true,
      labelFa: 'تنظیم تستی',
      group: SettingsGroup.appearance,
      descriptionFa: 'توضیحات تستی',
      whyExplanationFa: 'علت وجود این تنظیم برای ارتقای تجربه کاربری است.',
    );

    testWidgets('renders with BackdropFilter when glass enabled', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          isGlass: true,
          blurSigma: 25.0,
          child: const SettingExplainerSheet(descriptor: desc),
        ),
      );

      expect(find.text('تنظیم تستی'), findsOneWidget);
      expect(find.text('علت وجود این تنظیم برای ارتقای تجربه کاربری است.'), findsOneWidget);
      expect(find.byType(BackdropFilter), findsWidgets);
    });

    testWidgets('renders fallback without BackdropFilter when glass disabled', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          isGlass: false,
          child: const SettingExplainerSheet(descriptor: desc),
        ),
      );

      expect(find.text('تنظیم تستی'), findsOneWidget);
      expect(find.byType(BackdropFilter), findsNothing);
    });
  });

  group('AiWriteHistorySheet Glassmorphism Tests', () {
    final mockRecords = [
      AiSettingHistoryRecord(
        id: 1,
        key: 'calendar_start_of_week',
        labelFa: 'آغاز هفته',
        reasonFa: 'تطبیق با تقویم انتخابی',
        oldValue: 'saturday',
        newValue: 'monday',
        timestamp: DateTime(2026, 8, 20, 10, 30),
      ),
    ];

    testWidgets('renders with BackdropFilter when glass enabled', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          isGlass: true,
          child: AiWriteHistorySheet(initialRecords: mockRecords),
        ),
      );
      await tester.pump();

      expect(find.text('تاریخچه تغییرات دستیار هوشمند'), findsOneWidget);
      expect(find.text('آغاز هفته'), findsOneWidget);
      expect(find.byType(BackdropFilter), findsWidgets);
    });

    testWidgets('renders fallback without BackdropFilter when glass disabled', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          isGlass: false,
          child: AiWriteHistorySheet(initialRecords: mockRecords),
        ),
      );
      await tester.pump();

      expect(find.text('تاریخچه تغییرات دستیار هوشمند'), findsOneWidget);
      expect(find.byType(BackdropFilter), findsNothing);
    });
  });

  group('OtpVerificationSheet Glassmorphism Tests', () {
    testWidgets('renders with BackdropFilter when glass enabled', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          isGlass: true,
          child: OtpVerificationSheet(
            identifier: '09123456789',
            onSuccess: () {},
          ),
        ),
      );

      expect(find.text('تأیید شماره همراه'), findsOneWidget);
      expect(find.byType(BackdropFilter), findsWidgets);
    });

    testWidgets('renders fallback without BackdropFilter when glass disabled', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          isGlass: false,
          child: OtpVerificationSheet(
            identifier: '09123456789',
            onSuccess: () {},
          ),
        ),
      );

      expect(find.text('تأیید شماره همراه'), findsOneWidget);
      expect(find.byType(BackdropFilter), findsNothing);
    });
  });
}
