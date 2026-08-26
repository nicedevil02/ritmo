import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/today/presentation/widgets/dashboard/zone_card.dart';
import 'package:ritmo/l10n/app_localizations.dart';

Widget _buildWrapper({
  required Widget child,
  bool isDark = false,
}) {
  return MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [
      Locale('fa'),
      Locale('en'),
    ],
    locale: const Locale('fa'),
    theme: isDark ? RitmoTheme.darkTheme : RitmoTheme.lightTheme,
    home: Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: child,
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ZoneCard Visibility & Preset Templates (F-04, F-05)', () {
    testWidgets('1. Displays 1-tap preset templates when out of realm', (tester) async {
      await tester.pumpWidget(
        _buildWrapper(
          child: ZoneCard(
            isDarkMode: false,
            currentEnergyPercent: 75.0,
            currentEnergyLabel: 'متوسط',
            currentEnergyDesc: 'تعادل انرژی مناسب',
            activeZone: null,
            activeZoneName: null,
            activeZoneIcon: null,
            activeZoneColorHex: null,
            activeZoneRoutinesCount: 0,
            activeZoneTimeRange: null,
            onEnergyTap: () {},
            onRealmChanged: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check preset template chips
      expect(find.text('کار'), findsOneWidget);
      expect(find.text('خانواده'), findsOneWidget);
      expect(find.text('مطالعه'), findsOneWidget);
      expect(find.text('ورزش'), findsOneWidget);
    });

    testWidgets('2. Renders active realm details and title when in active realm', (tester) async {
      await tester.pumpWidget(
        _buildWrapper(
          child: ZoneCard(
            isDarkMode: false,
            currentEnergyPercent: 90.0,
            currentEnergyLabel: 'بالا',
            currentEnergyDesc: 'آماده برای تمرکز',
            activeZone: const {
              'id': 'work_zone',
              'name': 'قلمرو کار',
              'startTime': '09:00',
              'endTime': '17:00',
              'color': '#3B82F6',
              'icon': '💼',
            },
            activeZoneName: 'قلمرو کار',
            activeZoneIcon: '💼',
            activeZoneColorHex: '#3B82F6',
            activeZoneRoutinesCount: 3,
            activeZoneTimeRange: '09:00 - 17:00',
            onEnergyTap: () {},
            onRealmChanged: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('قلمرو کار'), findsOneWidget);
      expect(find.text('۰۹:۰۰ - ۱۷:۰۰'), findsOneWidget);
    });
  });
}
