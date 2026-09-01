import 'package:flutter/material.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_marble_core.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_orb_eyes.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_orb_motion.dart';

/// حباب هوشمند آنبوردینگ ریتمو
/// یکپارچه‌شده با هستهٔ مرمرین [RitmoMarbleCore]
class RitmoOrb extends StatelessWidget {
  const RitmoOrb({
    super.key,
    this.size = 180,
    this.isDarkMode,
  });

  final double size;
  final bool? isDarkMode;

  @override
  Widget build(BuildContext context) {
    final bool isDark =
        isDarkMode ?? (Theme.of(context).brightness == Brightness.dark);
    final RitmoOrbPalette palette =
        isDark ? RitmoOrbPalette.aurora : RitmoOrbPalette.coral;

    return RepaintBoundary(
      child: Center(
        child: RitmoMarbleCore(
          size: size,
          palette: palette,
          signature: RitmoOrbSignature.of(RitmoOrbLife.breathing),
          eyeMode: RitmoEyeMode.occasional,
          glowEnabled: true,
          respectSettings: true,
        ),
      ),
    );
  }
}


