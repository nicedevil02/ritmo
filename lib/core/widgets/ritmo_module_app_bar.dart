// lib/core/widgets/ritmo_module_app_bar.dart

import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';

class RitmoModuleAppBar extends StatelessWidget implements PreferredSizeWidget {
  const RitmoModuleAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.statusBadge,
    this.actions,
    this.onBack,
    this.density,
    this.preferredHeight,
  });
  final String title;
  final String? subtitle;
  final Widget? statusBadge;
  final List<Widget>? actions;
  final VoidCallback? onBack;
  final RitmoDensityLevel? density;
  final double? preferredHeight;

  @override
  Size get preferredSize {
    if (preferredHeight != null) return Size.fromHeight(preferredHeight!);
    final m = RitmoMetrics.of(density ?? RitmoUiScale.defaultDensity);
    return Size.fromHeight(m.rowHeight + m.spaceSm);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final m = context.metrics;
    final effectiveHeight = m.rowHeight + m.spaceSm; // 60/64/72/78

    return Directionality(
      textDirection: TextDirection.rtl,
      child: SafeArea(
        bottom: false,
        child: Container(
          height: effectiveHeight,
          padding: EdgeInsets.symmetric(horizontal: m.spaceLg),
          decoration: BoxDecoration(
            color: Colors.transparent,
            border: Border(
              bottom: BorderSide(
                color: colors.border.withValues(alpha: 0.08),
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              // Back Button (Min touchTarget)
              Semantics(
                button: true,
                label: 'بازگشت',
                child: InkWell(
                  onTap: onBack ?? () => Navigator.maybePop(context),
                  borderRadius: BorderRadius.circular(m.touchTarget / 2),
                  child: Container(
                    width: m.touchTarget,
                    height: m.touchTarget,
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.arrow_back_rounded,
                      size: m.iconLg,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
              ),
              SizedBox(width: m.spaceSm),

              // Title and Subtitle / Status Badge
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: RitmoTextStyles.titleMedium(
                              colors.textPrimary,
                            ).copyWith(fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (statusBadge != null) ...[
                          SizedBox(width: m.spaceSm),
                          statusBadge!,
                        ],
                      ],
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: RitmoTextStyles.badge(
                          colors.textSecondary.withValues(alpha: 0.7),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),

              // Action Buttons
              ...?actions,
            ],
          ),
        ),
      ),
    );
  }
}
