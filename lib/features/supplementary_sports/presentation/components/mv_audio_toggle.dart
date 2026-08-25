import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';

/// Accessible Audio Cue Toggle Button (Section 5.10 & 6.4).
class MvAudioToggle extends StatelessWidget {
  final bool isAudioEnabled;
  final ValueChanged<bool> onToggle;

  const MvAudioToggle({
    super.key,
    required this.isAudioEnabled,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.ritmoColors;
    final metrics = context.metrics;

    return IconButton(
      tooltip: isAudioEnabled
          ? 'خاموش کردن راهنمای صوتی'
          : 'روشن کردن راهنمای صوتی',
      iconSize: metrics.iconMd,
      style: IconButton.styleFrom(
        minimumSize: Size(metrics.touchTarget, metrics.touchTarget),
        backgroundColor: isAudioEnabled
            ? colors.primary.withValues(alpha: 0.12)
            : colors.surfaceElevated,
      ),
      icon: Icon(
        isAudioEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
        color: isAudioEnabled ? colors.primary : colors.textSecondary,
      ),
      onPressed: () => onToggle(!isAudioEnabled),
    );
  }
}
