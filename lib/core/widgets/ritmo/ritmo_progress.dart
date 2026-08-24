// Ritmo Progress — نوار و حلقه پیشرفت متصل به توکن‌ها
// ترک نوار از surfaceSunken و پرکردن از primary یا رنگ مادول

import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';

export '../ritmo_progress_ring.dart';

class RitmoProgressBar extends StatelessWidget {
  const RitmoProgressBar({
    super.key,
    required this.progress,
    this.color,
    this.height,
  });

  final double progress; // 0.0 to 1.0
  final Color? color;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final m = context.metrics;
    final activeColor = color ?? colors.primary;
    final effectiveHeight = height ?? (m.spaceXs + 2); // 6 in comfortable

    return ClipRRect(
      borderRadius: BorderRadius.circular(m.radiusField),
      child: LinearProgressIndicator(
        value: progress.clamp(0.0, 1.0),
        minHeight: effectiveHeight,
        backgroundColor: colors.surfaceSunken,
        valueColor: AlwaysStoppedAnimation<Color>(activeColor),
      ),
    );
  }
}

class RitmoProgressSpinner extends StatelessWidget {
  const RitmoProgressSpinner({
    super.key,
    required this.progress,
    this.color,
    this.size,
    this.strokeWidth,
  });

  final double progress; // 0.0 to 1.0
  final Color? color;
  final double? size;
  final double? strokeWidth;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final m = context.metrics;
    final activeColor = color ?? colors.primary;
    final effectiveSize = size ?? m.spaceXxxl; // 48 in comfortable
    final effectiveStroke = strokeWidth ?? m.spaceXs; // 4 in comfortable

    return SizedBox(
      width: effectiveSize,
      height: effectiveSize,
      child: CircularProgressIndicator(
        value: progress.clamp(0.0, 1.0),
        strokeWidth: effectiveStroke,
        backgroundColor: colors.surfaceSunken,
        valueColor: AlwaysStoppedAnimation<Color>(activeColor),
      ),
    );
  }
}
