import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/movement/presentation/common/movement_strings.dart';

/// ویجت ورود مسافت و محاسبهٔ Pace (سرعت هر کیلومتر)
class DistanceInput extends StatelessWidget {
  const DistanceInput({
    super.key,
    required this.distanceKm,
    required this.elapsedSeconds,
    required this.onDistanceChanged,
    this.targetDistanceKm,
  });

  final double distanceKm;
  final int elapsedSeconds;
  final ValueChanged<double> onDistanceChanged;
  final double? targetDistanceKm;

  String? _calculatePace() {
    if (distanceKm <= 0.05 || elapsedSeconds <= 5) return null;
    final paceSec = (elapsedSeconds / distanceKm).round();
    final m = paceSec ~/ 60;
    final s = paceSec % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _showManualDialog(BuildContext context) async {
    final controller = TextEditingController(
      text: distanceKm > 0 ? distanceKm.toStringAsFixed(2) : '',
    );
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) {
        final colors = ctx.colors;
        return AlertDialog(
          backgroundColor: colors.surfaceElevated,
          title: Text(
            'ورود مسافت (کیلومتر)',
            style: RitmoTextStyles.cardTitle(colors.textPrimary),
          ),
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
            style: RitmoTextStyles.body(colors.textPrimary),
            decoration: InputDecoration(
              hintText: 'مثال: ۳.۵',
              suffixText: 'کیلومتر',
              filled: true,
              fillColor: colors.surfaceSunken,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text(MovementStrings.commonCancel),
            ),
            ElevatedButton(
              onPressed: () {
                final text = controller.text.replaceAll('/', '.').trim();
                final val = double.tryParse(text);
                Navigator.of(ctx).pop(val);
              },
              child: const Text(MovementStrings.commonConfirm),
            ),
          ],
        );
      },
    );

    if (result != null && result >= 0) {
      onDistanceChanged(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final sportsColor = context.modules.sports;
    final paceStr = _calculatePace();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // نمایش بزرگ مسافت
        InkWell(
          onTap: () => _showManualDialog(context),
          borderRadius: BorderRadius.circular(RitmoRadius.card),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(RitmoRadius.card),
              border: Border.all(color: sportsColor.withValues(alpha: 0.4)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      toPersianDigits(distanceKm.toStringAsFixed(2)),
                      style: RitmoTextStyles.heroNumber(colors.textPrimary),
                    ),
                    const SizedBox(width: 8),
                    Text('کیلومتر', style: RitmoTextStyles.label(sportsColor)),
                  ],
                ),
                if (targetDistanceKm != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'هدف: ${toPersianDigits(targetDistanceKm!.toStringAsFixed(1))} کیلومتر',
                    style: RitmoTextStyles.caption(colors.textSecondary),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: RitmoSpacing.md),

        // دکمه‌های سریع افزایش مسافت
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildQuickBtn(
              '+۰.۱',
              () => onDistanceChanged(distanceKm + 0.1),
              sportsColor,
            ),
            const SizedBox(width: RitmoSpacing.sm),
            _buildQuickBtn(
              '+۰.۵',
              () => onDistanceChanged(distanceKm + 0.5),
              sportsColor,
            ),
            const SizedBox(width: RitmoSpacing.sm),
            _buildQuickBtn(
              '+۱.۰',
              () => onDistanceChanged(distanceKm + 1.0),
              sportsColor,
            ),
          ],
        ),
        const SizedBox(height: RitmoSpacing.md),

        // نمایش Pace فقط در صورت وجود مسافت و زمان معتبر
        if (paceStr != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: sportsColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(RitmoRadius.pill),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.speed_rounded, size: 18, color: sportsColor),
                const SizedBox(width: 6),
                Text(
                  'سرعت (Pace): ${toPersianDigits(paceStr)} دقیقه/کیلومتر',
                  style: RitmoTextStyles.label(sportsColor),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildQuickBtn(String text, VoidCallback onTap, Color color) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 48),
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.5)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(RitmoRadius.field),
        ),
      ),
      child: Text(toPersianDigits(text), style: RitmoTextStyles.label(color)),
    );
  }
}
