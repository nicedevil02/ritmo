import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/theme/ritmo_palette.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/ux/ritmo_directional_icon.dart';
import 'package:ritmo/core/ux/ritmo_skeleton.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_button.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_card.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_chip.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_hero_card.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_list_row.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_progress.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_segmented_control.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_text_field.dart';

class ComponentGalleryScreen extends StatelessWidget {
  const ComponentGalleryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(
          title: const Text('گالری کامپوننت‌های ریتمو'),
          leading: RitmoIcons.back(context),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 1. Hero Card
            RitmoHeroCard(
              moduleColor: colors.primary,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'کارت ویژه ریتمو',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'طراحی شده برای تمرکز و انسجام بصری',
                    style: TextStyle(color: colors.textSecondary, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 2. Standard Card
            RitmoCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'کارت استاندارد',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'کارت‌ها سطوح اصلی تعامل کاربر با اپ هستند.',
                    style: TextStyle(color: colors.textSecondary, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 3. Buttons
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                RitmoPrimaryButton(
                  label: 'دکمه اصلی',
                  onPressed: () {},
                  fullWidth: false,
                ),
                RitmoSecondaryButton(
                  label: 'دکمه ثانویه',
                  onPressed: () {},
                  fullWidth: false,
                ),
                const RitmoPrimaryButton(
                  label: 'دکمه غیرفعال',
                  onPressed: null,
                  isLoading: false,
                  fullWidth: false,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 4. Chips
            Wrap(
              spacing: 8,
              children: [
                RitmoChip(
                  label: 'انتخاب شده',
                  isSelected: true,
                  onTap: () {},
                ),
                RitmoChip(
                  label: 'غیرفعال / عادی',
                  isSelected: false,
                  onTap: () {},
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 5. Segmented Control
            RitmoSegmentedControl<int>(
              segments: const {
                1: 'روزانه',
                2: 'هفتگی',
                3: 'ماهانه',
              },
              selected: 1,
              onSelected: (_) {},
            ),
            const SizedBox(height: 16),

            // 6. Text Field
            const RitmoTextField(
              label: 'متن ورودی نمونه...',
              icon: Icons.search,
            ),
            const SizedBox(height: 16),

            // 7. List Row
            RitmoListRow(
              title: 'ردیف لیست استاندارد',
              subtitle: 'توضیحات تکمیلی برای آیتم',
              leading: Icon(Icons.bolt, color: colors.primary),
              trailing: RitmoIcons.forward(context),
            ),
            const SizedBox(height: 16),

            // 8. Progress
            const RitmoProgressBar(progress: 0.65),
            const SizedBox(height: 16),

            // 9. Skeleton
            const RitmoSkeleton(
              width: double.infinity,
              height: 24,
              borderRadius: 8,
            ),
          ],
        ),
      ),
    );
  }
}

void main() {
  group('Ritmo Aurora — Component Gallery Golden Matrix (30 Views)', () {
    const brightnessModes = <String, Brightness>{
      'light': Brightness.light,
      'dark': Brightness.dark,
    };

    const textScales = <String, double>{
      'scale_1_0': 1.0,
      'scale_1_3': 1.3,
    };

    for (final palette in RitmoPalette.all) {
      final paletteId = RitmoPalette.serializeId(palette.id);

      for (final modeEntry in brightnessModes.entries) {
        final modeName = modeEntry.key;
        final brightness = modeEntry.value;

        for (final scaleEntry in textScales.entries) {
          final scaleName = scaleEntry.key;
          final textScale = scaleEntry.value;

          testWidgets(
            'Gallery: ${paletteId}_${modeName}_$scaleName',
            (tester) async {
              tester.view.physicalSize = const Size(390 * 2.0, 844 * 2.0);
              tester.view.devicePixelRatio = 2.0;

              addTearDown(() {
                tester.view.resetPhysicalSize();
                tester.view.resetDevicePixelRatio();
              });

              await tester.pumpWidget(
                MaterialApp(
                  debugShowCheckedModeBanner: false,
                  theme: RitmoTheme.build(
                    palette: palette,
                    brightness: brightness,
                  ),
                  home: MediaQuery(
                    data: MediaQueryData(
                      size: const Size(390, 844),
                      textScaler: TextScaler.linear(textScale),
                    ),
                    child: const ComponentGalleryScreen(),
                  ),
                ),
              );

              await tester.pump(const Duration(milliseconds: 100));

              await expectLater(
                find.byType(MaterialApp),
                matchesGoldenFile('goldens/gallery_${paletteId}_${modeName}_$scaleName.png'),
              );
            },
          );
        }
      }

      // Also Obsidian / True Black mode at 1.0 and 1.3
      for (final scaleEntry in textScales.entries) {
        final scaleName = scaleEntry.key;
        final textScale = scaleEntry.value;

        testWidgets(
          'Gallery: ${paletteId}_true_black_$scaleName',
          (tester) async {
            tester.view.physicalSize = const Size(390 * 2.0, 844 * 2.0);
            tester.view.devicePixelRatio = 2.0;

            addTearDown(() {
              tester.view.resetPhysicalSize();
              tester.view.resetDevicePixelRatio();
            });

            await tester.pumpWidget(
              MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: RitmoTheme.build(
                  palette: palette,
                  brightness: Brightness.dark,
                  trueBlack: true,
                ),
                home: MediaQuery(
                  data: MediaQueryData(
                    size: const Size(390, 844),
                    textScaler: TextScaler.linear(textScale),
                  ),
                  child: const ComponentGalleryScreen(),
                ),
              ),
            );

            await tester.pump(const Duration(milliseconds: 100));

            await expectLater(
              find.byType(MaterialApp),
              matchesGoldenFile('goldens/gallery_${paletteId}_true_black_$scaleName.png'),
            );
          },
        );
      }
    }
  });
}
