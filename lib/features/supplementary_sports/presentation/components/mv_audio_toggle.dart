import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/l10n/app_localizations.dart';

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
    final l10n = AppLocalizations.of(context);

    return IconButton(
      tooltip: isAudioEnabled
          ? (l10n?.mv_audio_mute_tooltip ?? 'Mute audio')
          : (l10n?.mv_audio_unmute_tooltip ?? 'Enable audio'),
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
