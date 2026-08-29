import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/l10n/app_localizations.dart';

/// کارت‌های اطلاع‌رسانی و هشدارهای بحرانی صفحهٔ خانه.

/// پوستهٔ مشترک هشدارهای بحرانی — تُن رنگی، حاشیه و شعاع یکدست.
class _NoticeShell extends StatelessWidget {
  const _NoticeShell({
    required this.tone,
    required this.child,
  });

  final Color tone;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = BorderRadius.circular(RitmoRadius.cardLarge);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        color: tone.withValues(alpha: isDark ? 0.14 : 0.07),
        border: Border.all(color: tone.withValues(alpha: isDark ? 0.32 : 0.22)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(RitmoSpacing.md),
        child: child,
      ),
    );
  }
}

/// ردیف سرعنوان هشدارهای بحرانی: آیکون دایره‌ای + عنوان.
class _NoticeHeader extends StatelessWidget {
  const _NoticeHeader({
    required this.icon,
    required this.tone,
    required this.title,
  });

  final IconData icon;
  final Color tone;
  final String title;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Row(
      children: [
        Container(
          height: 36,
          width: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: tone.withValues(alpha: 0.14),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: tone, size: 18),
        ),
        const SizedBox(width: RitmoSpacing.md),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: colors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

/// هشدارهای بحرانی موتور هوشمند (تداخل دارویی، سقف دوز، اضافه‌بار و مانند آن).
class CriticalAlertsCard extends StatelessWidget {
  const CriticalAlertsCard({super.key, required this.alerts});

  final List<String> alerts;

  @override
  Widget build(BuildContext context) {
    if (alerts.isEmpty) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;
    final tone = colors.error;

    return _NoticeShell(
      tone: tone,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _NoticeHeader(
            icon: CupertinoIcons.exclamationmark_triangle_fill,
            tone: tone,
            title: l10n.criticalSystemAlerts,
          ),
          const SizedBox(height: RitmoSpacing.sm),
          for (final alert in alerts)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    height: 5,
                    width: 5,
                    decoration: BoxDecoration(color: tone, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      alert,
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.6,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}


