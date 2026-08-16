import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/movement/presentation/session/widgets/intensity_picker.dart';
import 'package:ritmo/features/movement/presentation/session/widgets/timer_display.dart';

/// نمای مد آزاد (Free Mode) فقط با زمان، انتخاب شدت و یادداشت
class FreeSessionView extends StatelessWidget {
  const FreeSessionView({
    super.key,
    required this.elapsedSeconds,
    required this.isPaused,
    required this.selectedIntensity,
    required this.onIntensityChanged,
    required this.noteController,
  });

  final int elapsedSeconds;
  final bool isPaused;
  final int selectedIntensity;
  final ValueChanged<int> onIntensityChanged;
  final TextEditingController noteController;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // تایمر بزرگ
        TimerDisplay(
          elapsedSeconds: elapsedSeconds,
          isLarge: true,
          isPaused: isPaused,
        ),
        const SizedBox(height: RitmoSpacing.xl),

        // انتخاب شدت
        IntensityPicker(
          selectedIntensity: selectedIntensity,
          onIntensityChanged: onIntensityChanged,
        ),
        const SizedBox(height: RitmoSpacing.lg),

        // فیلد یادداشت اختیاری
        TextField(
          controller: noteController,
          maxLines: 2,
          style: RitmoTextStyles.body(colors.textPrimary),
          decoration: InputDecoration(
            hintText: 'یادداشت در جریان تمرین (اختیاری)...',
            hintStyle: RitmoTextStyles.body(colors.textTertiary),
            filled: true,
            fillColor: colors.surfaceSunken,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(RitmoRadius.field),
              borderSide: BorderSide(color: colors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(RitmoRadius.field),
              borderSide: BorderSide(color: colors.border),
            ),
          ),
        ),
      ],
    );
  }
}
