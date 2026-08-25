import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';
import 'package:ritmo/features/supplementary_sports/presentation/screens/screens.dart';
import 'package:ritmo/l10n/app_localizations.dart';

Widget createTestApp(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('fa'),
    home: Scaffold(body: child),
  );
}

void main() {
  group('S8-T9 Campaign Entry & Creation Tests', () {
    testWidgets('Inactive campaign renders CTA card and opens creation dialog', (tester) async {
      MvCampaign? created;

      await tester.pumpWidget(
        createTestApp(
          MvProgressTab(
            activeCampaign: null,
            onCreateCampaign: (c) => created = c,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('mv_campaign_inactive_card')), findsOneWidget);
      expect(find.byKey(const ValueKey('mv_campaign_create')), findsOneWidget);

      // Open creation dialog
      await tester.tap(find.byKey(const ValueKey('mv_campaign_create')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('mv_campaign_weight_field')), findsOneWidget);
      expect(find.byKey(const ValueKey('mv_campaign_submit_btn')), findsOneWidget);

      // Submit valid campaign
      await tester.tap(find.byKey(const ValueKey('mv_campaign_submit_btn')));
      await tester.pumpAndSettle();

      expect(created, isNotNull);
      expect(created!.goalCode, equals('HIKING'));
      expect(created!.isActive, isTrue);
    });

    testWidgets('Active campaign renders active campaign card with phase and pack weight', (tester) async {
      const activeCamp = MvCampaign(
        id: 'camp_1',
        titleFa: 'دوره قله دماوند',
        goalCode: 'HIKING',
        startDate: '2026-08-01',
        weeks: 12,
        status: 'ACTIVE',
        createdAt: 100,
        updatedAt: 100,
      );

      await tester.pumpWidget(
        createTestApp(
          const MvProgressTab(
            activeCampaign: activeCamp,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('mv_active_campaign_card')), findsOneWidget);
      expect(find.text('دوره قله دماوند'), findsOneWidget);
      expect(find.byKey(const ValueKey('mv_campaign_phase_text')), findsOneWidget);
    });
  });
}
