import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_button.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_card.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_chip.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_hero_card.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_list_row.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_progress.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_segmented_control.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_text_field.dart';
import 'package:ritmo/features/cycle/cycle_hero_card.dart';
import '../support/responsive_harness.dart';

void main() {
  const densities = RitmoDensityLevel.values;
  const textScales = [0.85, 1.0, 1.30, 1.60];
  const viewports = [
    Size(320, 568),
    Size(360, 640),
    Size(390, 844),
    Size(430, 932),
  ];

  group('64-State UI Scale & Density Matrix Test', () {
    for (final viewport in viewports) {
      for (final density in densities) {
        for (final textScale in textScales) {
          final label =
              'Viewport: ${viewport.width.toInt()}x${viewport.height.toInt()} | '
              'Density: ${density.name} | TextScale: ${(textScale * 100).toInt()}%';

          testWidgets(label, (tester) async {
            tester.view.physicalSize = Size(viewport.width, viewport.height * 2);
            tester.view.devicePixelRatio = 1.0;
            addTearDown(tester.view.resetPhysicalSize);

            final theme = RitmoTheme.build(
              palette: RitmoPalette.jadeNoir,
              brightness: Brightness.light,
              density: density,
            );

            await tester.pumpWidget(
              MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: theme,
                home: MediaQuery(
                  data: MediaQueryData(
                    size: Size(viewport.width, viewport.height * 2),
                    textScaler: TextScaler.linear(textScale),
                  ),
                  child: Directionality(
                    textDirection: TextDirection.rtl,
                    child: Scaffold(
                      body: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            RitmoPrimaryButton(
                              key: const ValueKey('primary_btn'),
                              label: 'دکمه اصلی ریتمو',
                              icon: Icons.check,
                              onPressed: () {},
                            ),
                            const SizedBox(height: 12),
                            RitmoSecondaryButton(
                              key: const ValueKey('secondary_btn'),
                              label: 'دکمه ثانویه',
                              icon: Icons.refresh,
                              onPressed: () {},
                            ),
                            const SizedBox(height: 12),
                            Center(
                              child: RitmoIconButton(
                                key: const ValueKey('icon_btn'),
                                icon: Icons.add,
                                onPressed: () {},
                              ),
                            ),
                            const SizedBox(height: 12),
                            RitmoSegmentedControl<int>(
                              key: const ValueKey('seg_ctrl'),
                              segments: const {
                                0: 'روزانه',
                                1: 'هفتگی',
                                2: 'ماهانه',
                              },
                              selected: 0,
                              onSelected: (_) {},
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                RitmoChip(
                                  key: const ValueKey('chip_1'),
                                  label: 'برچسب فعال',
                                  isSelected: true,
                                  icon: Icons.star,
                                  onTap: () {},
                                ),
                                RitmoChip(
                                  key: const ValueKey('chip_2'),
                                  label: 'برچسب عادی',
                                  isSelected: false,
                                  onTap: () {},
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const RitmoCard(
                              key: ValueKey('card'),
                              child: Text('محتوای کارت استاندارد ریتمو'),
                            ),
                            const SizedBox(height: 12),
                            const RitmoHeroCard(
                              key: ValueKey('hero_card'),
                              moduleColor: Colors.teal,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('کارت هیرو'),
                                  Text('توضیحات تکمیلی برای کارت هیرو'),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            const CycleHeroCard(
                              key: ValueKey('cycle_hero_card'),
                              currentPhase: CyclePhase.follicular,
                              currentDay: 5,
                              totalDaysInPhase: 9,
                            ),
                            const SizedBox(height: 12),
                            RitmoListRow(
                              key: const ValueKey('list_row'),
                              title: 'ردیف لیست ریتمو',
                              subtitle: 'زیرعنوان و توضیحات ردیف',
                              leading: const Icon(Icons.settings),
                              onTap: () {},
                            ),
                            const SizedBox(height: 12),
                            const RitmoTextField(
                              key: ValueKey('text_field'),
                              label: 'نام کاربری',
                              hint: 'نام خود را وارد کنید',
                              icon: Icons.person,
                            ),
                            const SizedBox(height: 12),
                            const RitmoProgressBar(
                              key: ValueKey('progress_bar'),
                              progress: 0.65,
                            ),
                            const SizedBox(height: 12),
                            const Center(
                              child: RitmoProgressRing(
                                key: ValueKey('progress_ring'),
                                value: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );

            await expectNoOverflow(tester, label: label);

            // Verify touch targets >= 48.0 (Law 38: Minimum Touch Target Floor 48dp across ALL densities)
            const expectedTouchTarget = 48.0;
            final primaryBtnSize = tester.getSize(
              find.byKey(const ValueKey('primary_btn')),
            );
            expect(
              primaryBtnSize.height,
              greaterThanOrEqualTo(expectedTouchTarget),
            );

            final secondaryBtnSize = tester.getSize(
              find.byKey(const ValueKey('secondary_btn')),
            );
            expect(
              secondaryBtnSize.height,
              greaterThanOrEqualTo(expectedTouchTarget),
            );

            final iconBtnSize = tester.getSize(
              find.byKey(const ValueKey('icon_btn')),
            );
            expect(iconBtnSize.width, greaterThanOrEqualTo(expectedTouchTarget));
            expect(iconBtnSize.height, greaterThanOrEqualTo(expectedTouchTarget));
          });
        }
      }
    }
  });
}
