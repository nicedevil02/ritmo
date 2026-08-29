import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/ux/ritmo_haptics.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_card.dart';

/// بنر کپسولی هوشمند ارزیابی انرژی اول روز — متصل به سامانه مرجع کارت‌های نئومورفیک ریتمو.
class MorningCheckinPillBanner extends StatelessWidget {
  const MorningCheckinPillBanner({
    super.key,
    required this.onTap,
  });

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gold = colors.goldAccent;

    return Semantics(
      button: true,
      label: 'ارزیابی انرژی صبحگاهی، شروع بررسی',
      child: RitmoCard.neumorphic(
        onTap: () {
          RitmoHaptics.selection();
          onTap();
        },
        borderRadius: BorderRadius.circular(20),
        borderColor: gold.withValues(alpha: isDark ? 0.45 : 0.65),
        borderWidth: 1.2,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        enableSpring: true,
        child: Row(
          children: [
            // شیار فرورفته نئومورفیک با هاله طلایی خورشید
            RitmoNeuSurface(
              height: 42,
              width: 42,
              radius: 21,
              sunken: true,
              padding: EdgeInsets.zero,
              glowColor: gold.withValues(alpha: 0.45),
              child: Center(
                child: Icon(
                  CupertinoIcons.sunrise_fill,
                  size: 22,
                  color: gold,
                ),
              ),
            ),
            const SizedBox(width: 12),

            // عنوان و پیام راهنما
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        'ارزیابی انرژی صبحگاهی',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'Vazirmatn',
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        '☀️',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'ریتم روزتان را با چند پرسش کوتاه کوک کنید',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'Vazirmatn',
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),

            // دکمه کپسولی شروع
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    gold,
                    Color.lerp(gold, Colors.amber, 0.4)!,
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: gold.withValues(alpha: isDark ? 0.35 : 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'شروع',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Vazirmatn',
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(width: 3),
                  Icon(
                    CupertinoIcons.chevron_left,
                    size: 12,
                    color: Colors.black87,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
