import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_marble_core.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_orb_clock.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_orb_dock.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_orb_eyes.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_orb_motion.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const List<RitmoOrbLife> visibleLives = [
    RitmoOrbLife.dormant,
    RitmoOrbLife.breathing,
    RitmoOrbLife.listening,
    RitmoOrbLife.thinking,
    RitmoOrbLife.writing,
    RitmoOrbLife.celebrating,
  ];

  const List<double> sizes = [19.0, 64.0, 96.0];

  group('RitmoOrb Golden Tests — 6 Lives x 2 Themes x 3 Sizes', () {
    for (final brightness in [Brightness.light, Brightness.dark]) {
      final themeName = brightness == Brightness.dark ? 'dark' : 'light';

      for (final size in sizes) {
        testWidgets('Golden: orb_matrix_${themeName}_${size.toInt()}', (tester) async {
          RitmoOrbClock.instance.debugReset();

          final double targetWidth = (size * 1.8 * visibleLives.length).clamp(500.0, 1100.0);
          final double targetHeight = (size * 2.8).clamp(160.0, 360.0);
          final surfaceSize = Size(targetWidth, targetHeight);

          await tester.binding.setSurfaceSize(surfaceSize);
          addTearDown(() => tester.binding.setSurfaceSize(null));

          final palette = brightness == Brightness.dark
              ? RitmoOrbPalette.aurora
              : RitmoOrbPalette.coral;

          await tester.pumpWidget(
            MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: RitmoTheme.build(
                palette: RitmoPalette.jadeNoir,
                brightness: brightness,
              ),
              home: Directionality(
                textDirection: TextDirection.rtl,
                child: MediaQuery(
                  data: MediaQueryData(
                    disableAnimations: true,
                    size: surfaceSize,
                  ),
                  child: Scaffold(
                    backgroundColor: brightness == Brightness.dark
                        ? const Color(0xFF0F1715)
                        : const Color(0xFFF7FAF9),
                    body: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: visibleLives.map((life) {
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              RitmoMarbleCore(
                                size: size,
                                signature: RitmoOrbSignature.of(life),
                                palette: palette,
                                seed: 42,
                                eyeMode: RitmoEyeMode.always,
                                isAnimated: false,
                                respectSettings: false,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                life.name,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: brightness == Brightness.dark
                                      ? Colors.white70
                                      : Colors.black54,
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );

          // Snap all orb eye states to deterministic open & visible
          for (final element in find.byType(RitmoMarbleCore).evaluate()) {
            final state = (element as StatefulElement).state;
            (state as dynamic).debugSnap(open: 1.0, presence: 1.0);
          }

          await tester.pump();

          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile('goldens/orb_matrix_${themeName}_${size.toInt()}.png'),
          );
        });
      }
    }

    testWidgets('Golden: orb_dock_anchor_keyboard', (tester) async {
      RitmoOrbClock.instance.debugReset();
      const surfaceSize = Size(400.0, 500.0);
      await tester.binding.setSurfaceSize(surfaceSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      const anchor = RitmoOrbDockAnchorInfo(
        rect: Rect.fromLTRB(20.0, 360.0, 380.0, 440.0),
        radius: 28.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: RitmoTheme.build(
            palette: RitmoPalette.jadeNoir,
            brightness: Brightness.dark,
          ),
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: MediaQuery(
              data: const MediaQueryData(
                disableAnimations: true,
                viewInsets: EdgeInsets.only(bottom: 240.0),
                size: surfaceSize,
              ),
              child: Scaffold(
                backgroundColor: const Color(0xFF0F1715),
                body: Stack(
                  children: [
                    // Simulated message composer box
                    Positioned(
                      left: 20,
                      top: 360,
                      width: 360,
                      height: 80,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E2825),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(color: Colors.white24),
                        ),
                      ),
                    ),
                    const RitmoOrbDockLayer(
                      debugAnchor: anchor,
                      palette: RitmoOrbPalette.aurora,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      final dockElement = find.byType(RitmoOrbDockLayer).evaluate().first;
      final dockState = (dockElement as StatefulElement).state;
      (dockState as dynamic).debugSnap(open: 1.0, presence: 1.0);
      await tester.pump();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/orb_dock_anchor.png'),
      );
    });
  });
}
