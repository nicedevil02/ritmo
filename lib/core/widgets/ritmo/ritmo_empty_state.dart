// Ritmo EmptyState — وضعیت‌های خالی لیست‌ها، سکشن‌ها و صفحات
// منطبق با اصل ۱۵ قانون اساسی ریتمو (Honest Empty States)

import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';

/// وضعیت خالی استاندارد ریتمو برای صفحات و لیست‌ها (Ritmo Empty State)
class RitmoEmptyState extends StatelessWidget {
  const RitmoEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.description,
    this.actionLabel,
    this.onAction,
    this.ctaLabel,
    this.onCta,
    this.secondaryCtaLabel,
    this.onSecondaryCta,
  });

  final IconData icon;
  final String title;
  final String? description;

  /// برچسب دکمه اقدام اولیه (actionLabel یا ctaLabel)
  final String? actionLabel;
  final VoidCallback? onAction;

  /// نام مستعار دکمه اقدام اولیه
  final String? ctaLabel;
  final VoidCallback? onCta;

  /// برچسب دکمه اقدام ثانویه
  final String? secondaryCtaLabel;
  final VoidCallback? onSecondaryCta;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final m = context.metrics;

    final effectivePrimaryLabel = actionLabel ?? ctaLabel;
    final effectivePrimaryAction = onAction ?? onCta;

    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: m.spaceXxxl,
          vertical: m.spaceXxl,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Soft circle with icon
            Container(
              padding: EdgeInsets.all(m.spaceXl),
              decoration: BoxDecoration(
                color: colors.primaryContainer.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 48, color: colors.primary),
            ),
            SizedBox(height: m.spaceXl),
            Text(
              title,
              style: context.t.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colors.textPrimary,
                  ) ??
                  TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colors.textPrimary,
                    fontFamily: 'Vazirmatn',
                  ),
              textAlign: TextAlign.center,
            ),
            if (description != null && description!.isNotEmpty) ...[
              SizedBox(height: m.spaceSm),
              Text(
                description!,
                style: context.t.bodyMedium?.copyWith(
                      color: colors.textSecondary,
                      height: 1.6,
                    ) ??
                    TextStyle(
                      fontSize: 13,
                      color: colors.textSecondary,
                      height: 1.6,
                      fontFamily: 'Vazirmatn',
                    ),
                textAlign: TextAlign.center,
              ),
            ],
            if (effectivePrimaryLabel != null && effectivePrimaryAction != null) ...[
              SizedBox(height: m.spaceXl),
              RitmoPrimaryButton(
                label: effectivePrimaryLabel,
                onPressed: effectivePrimaryAction,
                fullWidth: false,
              ),
            ],
            if (secondaryCtaLabel != null && onSecondaryCta != null) ...[
              SizedBox(height: m.spaceSm),
              TextButton(
                onPressed: onSecondaryCta,
                style: TextButton.styleFrom(
                  foregroundColor: colors.primary,
                  padding: EdgeInsets.symmetric(
                    horizontal: m.spaceLg,
                    vertical: m.spaceSm,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(m.radiusCard),
                  ),
                ),
                child: Text(
                  secondaryCtaLabel!,
                  style: const TextStyle(
                    fontFamily: 'Vazirmatn',
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// نام مستعار برای شفافیت بیشتر در وضعیت‌های خالی تمام‌صفحه
typedef RitmoPageEmptyState = RitmoEmptyState;

/// نام مستعار برای وضعیت‌های خالی درون‌سکشنی و تب‌ها
typedef RitmoSectionEmptyState = RitmoEmptyState;
