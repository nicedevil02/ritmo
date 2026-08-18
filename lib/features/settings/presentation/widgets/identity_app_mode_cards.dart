import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';

/// کارت‌های انتخاب حالت اپلیکیشن (جامع / ساده)
class IdentityAppModeCards extends StatelessWidget {
  const IdentityAppModeCards({
    super.key,
    required this.appMode,
    required this.onModeChanged,
  });

  final String appMode;
  final ValueChanged<String> onModeChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDark;
    final isFullSelected = appMode == 'full';
    final isSimpleSelected = appMode == 'simple';

    return Column(
      children: [
        // Card 1: Full Experience
        _buildModeSelectCard(
          isSelected: isFullSelected,
          title: 'نسخهٔ جامع و کامل',
          badge: 'پیشنهادی ریتمو',
          description:
              'دسترسی کامل به تمام ماژول‌ها، تحلیل‌های هوشمند، برنامه‌ریزی پیشرفته، روتین‌ها و ابزارهای هوش مصنوعی.',
          icon: CupertinoIcons.sparkles,
          themeColor: const Color(0xFF10B981),
          tags: ['تمامی ماژول‌ها', 'هوش مصنوعی', 'تحلیل پیشرفته'],
          onTap: () => onModeChanged('full'),
          isDark: isDark,
          colors: colors,
        ),

        const SizedBox(height: 12),

        // Card 2: Simple Experience
        _buildModeSelectCard(
          isSelected: isSimpleSelected,
          title: 'نسخهٔ ساده و مینیمال',
          badge: 'نهایت تمرکز',
          description:
              'محیطی خلوت و بدون دغدغه که تنها روتین‌ها و تایمرهای ضروری را برای آرامش ذهنی نمایش می‌دهد.',
          icon: CupertinoIcons.bolt_horizontal_circle_fill,
          themeColor: const Color(0xFF3B82F6),
          tags: ['فقط روتین‌ها', 'تایمرها', 'تمرکز خالص'],
          onTap: () => onModeChanged('simple'),
          isDark: isDark,
          colors: colors,
        ),
      ],
    );
  }

  Widget _buildModeSelectCard({
    required bool isSelected,
    required String title,
    required String badge,
    required String description,
    required IconData icon,
    required Color themeColor,
    required List<String> tags,
    required VoidCallback onTap,
    required bool isDark,
    required dynamic colors,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isSelected
              ? themeColor.withValues(alpha: isDark ? 0.12 : 0.08)
              : colors.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isSelected
                ? themeColor.withValues(alpha: isDark ? 0.7 : 0.5)
                : (isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.06)),
            width: isSelected ? 1.8 : 1,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: themeColor.withValues(alpha: isDark ? 0.2 : 0.12),
                blurRadius: 20,
                offset: const Offset(0, 6),
              )
            else if (!isDark)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Icon
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: themeColor.withValues(alpha: isSelected ? 0.22 : 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    icon,
                    color: themeColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                // Title and Badge
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? themeColor : colors.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: themeColor.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              badge,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: themeColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Selection Radio Checkmark
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? themeColor : Colors.transparent,
                    border: Border.all(
                      color: isSelected
                          ? themeColor
                          : colors.textSecondary.withValues(alpha: 0.4),
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(
                          CupertinoIcons.checkmark,
                          size: 14,
                          color: Colors.white,
                        )
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              description,
              style: TextStyle(
                fontSize: 13,
                color: colors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: tags.map((t) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.black.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '• $t',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: isSelected ? colors.textPrimary : colors.textSecondary,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
