import 'package:flutter/material.dart';
import 'package:ritmo/core/services/premium_service.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/premium/presentation/premium_upgrade_sheet.dart';

/// کارت نمایش وضعیت اشتراک پرمیوم در تنظیمات
class SettingsPremiumCard extends StatelessWidget {
  const SettingsPremiumCard({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isPremium = PremiumService.instance.isPremium;

    return Container(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: (isPremium ? colors.primary : colors.warning).withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: (isPremium ? colors.primary : colors.warning).withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (isPremium ? colors.primary : colors.warning).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isPremium ? Icons.diamond_rounded : Icons.star_rounded,
              color: isPremium ? colors.primary : colors.warning,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isPremium ? 'اشتراک پرمیوم ریتمو پلاس 💎' : 'ریتمو پایه (نسخه رایگان) ⚡',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isPremium
                      ? 'دسترسی کامل به تمام امکانات هوشمند اپلیکیشن'
                      : 'سقف ۴ ماژول، ۷ روتین و ۳ هدف همزمان',
                  style: TextStyle(
                    fontSize: 11,
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {
              PremiumUpgradeSheet.show(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isPremium ? colors.primary : colors.warning,
              foregroundColor: isPremium ? colors.onPrimary : colors.background,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(
              isPremium ? 'مدیریت' : 'ارتقا 💎',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
