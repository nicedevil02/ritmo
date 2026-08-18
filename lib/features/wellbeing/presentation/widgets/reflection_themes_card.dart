import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/util/ritmo_number.dart';

/// کارت نمایش موضوع‌ها و کلیدواژه‌های پرتکرار در بازتاب‌ها
class ReflectionThemesCard extends StatelessWidget {
  const ReflectionThemesCard({
    super.key,
    required this.themes,
    required this.reflectionCount,
  });

  final Map<String, int> themes;
  final int reflectionCount;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final sortedEntries = themes.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topThemes = sortedEntries.take(10).toList();

    return Container(
      padding: const EdgeInsets.all(RitmoSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(RitmoRadius.card),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, color: colors.primary, size: 20),
              const SizedBox(width: 6),
              Text(
                'موضوع‌های پرتکرار',
                style: RitmoTextStyles.cardTitle(colors.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: RitmoSpacing.md),
          if (reflectionCount < 7 || topThemes.isEmpty) ...[
            Text(
              'با ثبت حداقل ۷ بازتاب، کلیدواژه‌ها و موضوع‌های پرتکرار روزمره‌تان در اینجا استخراج می‌شود.',
              style: RitmoTextStyles.caption(colors.textSecondary),
            ),
          ] else ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: topThemes.map((e) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: colors.primaryContainer.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: colors.primary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        e.key,
                        style: RitmoTextStyles.body(colors.textPrimary),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '(${RitmoNumber.faInt(e.value)})',
                        style: RitmoTextStyles.caption(colors.primary),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}
