import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/domain/realm/active_realm_resolver.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/today/presentation/widgets/dashboard/realm_dashboard_card.dart';
import 'package:ritmo/features/today/presentation/widgets/dashboard/realm_24h_dial.dart';
import 'package:ritmo/l10n/app_localizations.dart';

Widget _buildWrapper({
  required Widget child,
  bool isDark = false,
  double width = 360,
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
    theme: isDark
        ? RitmoTheme.build(palette: RitmoPalette.jadeNoir, brightness: Brightness.dark)
        : RitmoTheme.build(palette: RitmoPalette.jadeNoir, brightness: Brightness.light),
    home: Scaffold(
      body: SingleChildScrollView(
        child: SizedBox(
          width: width,
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: child,
          ),
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RealmDashboardCard Compact Layout & Repositioning Tests', () {
    testWidgets('Renders properly without overflow on 360dp and 320dp screens', (tester) async {
      for (final width in [360.0, 320.0]) {
        await tester.pumpWidget(
          _buildWrapper(
            width: width,
            child: RealmDashboardCard(
              isDarkMode: false,
              realmState: const FreeRealmState(),
              activeZone: null,
              activeZoneName: null,
              activeZoneIcon: null,
              activeZoneColorHex: null,
              activeZoneRoutinesCount: 0,
              activeZoneTimeRange: null,
              onRealmChanged: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(RealmDashboardCard), findsOneWidget);
        expect(find.byType(Realm24hDial), findsOneWidget);
        expect(find.text('مدیریت قلمرو'), findsOneWidget);
        expect(find.text('قلمرو فعال'), findsOneWidget);
        expect(find.text('زمان آزاد'), findsOneWidget);
      }
    });

    testWidgets('Renders with scheduled active realm in dark mode', (tester) async {
      const workRealm = RealmData(
        id: 'work_zone',
        name: 'قلمرو کار',
        colorHex: '#3B82F6',
        icon: '💼',
        mode: RealmMode.normal,
      );
      const workSchedule = RealmScheduleData(
        id: 'work_sched',
        zoneId: 'work_zone',
        daysOfWeek: {1, 2, 3, 4, 5, 6, 7},
        startTime: '09:00',
        endTime: '17:00',
      );

      await tester.pumpWidget(
        _buildWrapper(
          isDark: true,
          width: 360,
          child: RealmDashboardCard(
            isDarkMode: true,
            realmState: ScheduledRealmState(
              realm: workRealm,
              schedule: workSchedule,
              startsAt: DateTime(2026, 1, 1, 9, 0),
              endsAt: DateTime(2026, 1, 1, 17, 0),
              remaining: const Duration(hours: 4),
              progress: 0.5,
              explanation: 'طبق زمان‌بندی',
            ),
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
            activeZoneRoutinesCount: 2,
            activeZoneTimeRange: '09:00 - 17:00',
            onRealmChanged: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('قلمرو کار'), findsNWidgets(2));
      expect(find.text('مدیریت قلمرو'), findsOneWidget);
    });

    testWidgets('FreeRealmState calculates live countdown and does not show static 04:13:00', (tester) async {
      await tester.pumpWidget(
        _buildWrapper(
          child: RealmDashboardCard(
            isDarkMode: false,
            realmState: const FreeRealmState(),
            activeZone: null,
            activeZoneName: null,
            activeZoneIcon: null,
            activeZoneColorHex: null,
            activeZoneRoutinesCount: 0,
            activeZoneTimeRange: null,
            onRealmChanged: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // Hardcoded '04:13:00' should never exist
      expect(find.text('۰۴:۱۳:۰۰'), findsNothing);
      expect(find.text('باقی‌مانده:'), findsOneWidget);
    });
  });
}
