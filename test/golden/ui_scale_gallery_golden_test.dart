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

class GalleryTestPage extends StatelessWidget {
  const GalleryTestPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final m = context.metrics;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(
          title: const Text('گالری کامپوننت‌های ریتمو'),
          backgroundColor: colors.surface,
          elevation: 0,
        ),
        body: ListView(
          padding: EdgeInsets.all(m.spaceMd),
          children: [
            RitmoHeroCard(
              moduleColor: colors.primary,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'کارت ویژه ریتمو (Hero Card)',
                    style: context.t.titleMedium?.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: m.spaceSm),
                  Text(
                    'طراحی شده برای تمرکز و انسجام بصری در صفحات کلیدی.',
                    style: context.t.bodySmall?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: m.spaceMd),
            RitmoCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'کارت استاندارد',
                    style: context.t.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colors.textPrimary,
                    ),
                  ),
                  SizedBox(height: m.spaceXs),
                  Text(
                    'کارت‌ها سطوح اصلی تعامل کاربر با اپلیکیشن هستند.',
                    style: context.t.bodySmall?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: m.spaceMd),
            Row(
              children: [
                Expanded(
                  child: RitmoPrimaryButton(
                    label: 'دکمه اصلی',
                    icon: Icons.check_circle_outline,
                    onPressed: () {},
                  ),
                ),
                SizedBox(width: m.spaceSm),
                Expanded(
                  child: RitmoSecondaryButton(
                    label: 'دکمه ثانویه',
                    onPressed: () {},
                  ),
                ),
              ],
            ),
            SizedBox(height: m.spaceMd),
            RitmoSegmentedControl<int>(
              segments: const {0: 'روزانه', 1: 'هفتگی', 2: 'ماهانه'},
              selected: 0,
              onSelected: (_) {},
            ),
            SizedBox(height: m.spaceMd),
            Wrap(
              spacing: m.spaceSm,
              runSpacing: m.spaceSm,
              children: [
                RitmoChip(
                  label: 'فعال',
                  isSelected: true,
                  icon: Icons.star,
                  onTap: () {},
                ),
                RitmoChip(label: 'پیش‌فرض', isSelected: false, onTap: () {}),
              ],
            ),
            SizedBox(height: m.spaceMd),
            const RitmoTextField(
              label: 'نام کاربری',
              hint: 'یک نام کاربری وارد کنید',
              icon: Icons.person_outline,
            ),
            SizedBox(height: m.spaceMd),
            RitmoListRow(
              title: 'ردیف لیست ریتمو',
              subtitle: 'توضیحات و زیرعنوان مربوط به گزینه',
              leading: Icon(Icons.tune, color: colors.primary),
              onTap: () {},
            ),
            SizedBox(height: m.spaceMd),
            const RitmoProgressBar(progress: 0.65),
          ],
        ),
      ),
    );
  }
}

void main() {
  const configs = [
    (density: RitmoDensityLevel.compact, scale: 0.85, name: 'compact_85'),
    (
      density: RitmoDensityLevel.comfortable,
      scale: 1.00,
      name: 'comfortable_100',
    ),
    (density: RitmoDensityLevel.spacious, scale: 1.25, name: 'spacious_125'),
    (density: RitmoDensityLevel.xl, scale: 1.30, name: 'xl_130'),
  ];

  group('UI Scale Gallery Golden Tests', () {
    for (final config in configs) {
      testWidgets('Gallery: ${config.name}', (tester) async {
        tester.view.physicalSize = const Size(390 * 2.0, 844 * 2.0);
        tester.view.devicePixelRatio = 2.0;

        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final theme = RitmoTheme.build(
          palette: RitmoPalette.jadeNoir,
          brightness: Brightness.light,
          density: config.density,
        );

        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: theme,
            home: MediaQuery(
              data: MediaQueryData(
                size: const Size(390, 844),
                textScaler: TextScaler.linear(config.scale),
              ),
              child: const GalleryTestPage(),
            ),
          ),
        );

        await tester.pumpAndSettle();

        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/ui_scale_gallery_${config.name}.png'),
        );
      });
    }
  });
}
