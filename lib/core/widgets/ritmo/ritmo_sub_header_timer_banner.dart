import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/util/ritmo_number.dart';

/// بنر شیشه‌ای زنده و هوشمند زیر هدر (Sub-Header Live Activity Banner)
/// متصل به سیستم متریال شیشه‌ای ریتمو (بدون هاردکد) و هاب متمرکز تایمرها
class RitmoSubHeaderTimerBanner extends StatelessWidget {
  const RitmoSubHeaderTimerBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ActiveLiveTimerSession?>(
      valueListenable: RitmoTimerHub.instance.activeSessionNotifier,
      builder: (context, session, _) {
        return AnimatedSize(
          duration: const Duration(milliseconds: 320),
          curve: Curves.fastOutSlowIn,
          child: session == null
              ? const SizedBox.shrink()
              : _LiveTimerBannerCard(session: session),
        );
      },
    );
  }
}

class _LiveTimerBannerCard extends StatelessWidget {
  const _LiveTimerBannerCard({required this.session});

  final ActiveLiveTimerSession session;

  Color _getDomainColor(BuildContext context) {
    if (session.accentColor != null) return session.accentColor!;
    final colors = context.colors;
    switch (session.domain) {
      case RitmoTimerDomain.study:
        return const Color(0xff6366F1); // Indigo / Study
      case RitmoTimerDomain.course:
        return const Color(0xff0EA5E9); // Ocean Blue / Skill
      case RitmoTimerDomain.konkur:
        return const Color(0xffF43F5E); // Ruby / Konkur
      case RitmoTimerDomain.sport:
        return const Color(0xff10B981); // Emerald / Sport
      case RitmoTimerDomain.routine:
        return colors.primary;
      case RitmoTimerDomain.custom:
        return colors.primary;
    }
  }

  IconData _getDomainIcon() {
    if (session.icon != null) return session.icon!;
    switch (session.domain) {
      case RitmoTimerDomain.study:
        return Icons.menu_book_rounded;
      case RitmoTimerDomain.course:
        return Icons.school_rounded;
      case RitmoTimerDomain.konkur:
        return Icons.auto_graph_rounded;
      case RitmoTimerDomain.sport:
        return Icons.fitness_center_rounded;
      case RitmoTimerDomain.routine:
        return Icons.alarm_rounded;
      case RitmoTimerDomain.custom:
        return Icons.timer_outlined;
    }
  }

  String _formatDuration(int totalSec) {
    final m = totalSec ~/ 60;
    final s = totalSec % 60;
    final h = m ~/ 60;
    if (h > 0) {
      final remM = m % 60;
      return '${RitmoNumber.toFa(h.toString().padLeft(2, '0'))}:${RitmoNumber.toFa(remM.toString().padLeft(2, '0'))}:${RitmoNumber.toFa(s.toString().padLeft(2, '0'))}';
    }
    return '${RitmoNumber.toFa(m.toString().padLeft(2, '0'))}:${RitmoNumber.toFa(s.toString().padLeft(2, '0'))}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDark;
    final isGlass = context.isGlassEnabled;
    final highContrast = MediaQuery.maybeOf(context)?.highContrast ?? false;
    final materialSpec = context.materials.regular;
    final isOpaque = !isGlass || highContrast;

    final accent = _getDomainColor(context);
    final blurSigma = context.glassBlurSigma.clamp(0.0, 50.0);
    final opacityAlpha = (context.glassOpacityPercent / 100.0).clamp(0.08, 0.95);

    final bannerContent = Container(
      height: 48,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: isOpaque
            ? (isDark ? colors.surfaceElevated : colors.card)
            : (isDark
                ? const Color(0xFF131722).withValues(alpha: opacityAlpha)
                : Colors.white.withValues(alpha: opacityAlpha)),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOpaque
              ? colors.border.withValues(alpha: 0.4)
              : (isDark
                  ? Colors.white.withValues(alpha: 0.15)
                  : Colors.black.withValues(alpha: 0.08)),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: accent.withValues(alpha: isDark ? 0.14 : 0.08),
            blurRadius: 12,
            spreadRadius: 0.5,
          ),
        ],
      ),
      child: Stack(
        children: [
          // بدنه اصلی محتوای بنر
          Row(
            children: [
              // دکمه پالس‌زن آیکون حوزه
              InkWell(
                onTap: () {
                  RitmoHaptics.tap();
                  RitmoTimerHub.instance.reopenActiveSession(context);
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(_getDomainIcon(), size: 16, color: accent),
                ),
              ),
              const SizedBox(width: 8),

              // متن عنوان و فاز فعال
              Expanded(
                child: InkWell(
                  onTap: () {
                    RitmoHaptics.tap();
                    RitmoTimerHub.instance.reopenActiveSession(context);
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.title,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: colors.textPrimary,
                          fontFamily: 'Vazirmatn',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (session.subtitle != null && session.subtitle!.isNotEmpty) ...[
                        const SizedBox(height: 1),
                        Text(
                          session.subtitle!,
                          style: TextStyle(
                            fontSize: 10,
                            color: accent,
                            fontFamily: 'Vazirmatn',
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // زمان زنده ثانیه‌شمار
              ValueListenableBuilder<int>(
                valueListenable: RitmoTimerHub.instance.secondsTickNotifier,
                builder: (context, currentSec, _) {
                  final displaySec = session.targetSeconds > 0
                      ? session.remainingSeconds
                      : currentSec;
                  return InkWell(
                    onTap: () {
                      RitmoHaptics.tap();
                      RitmoTimerHub.instance.reopenActiveSession(context);
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _formatDuration(displaySec),
                        style: TextStyle(
                          fontFamily: 'Vazirmatn',
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: accent,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 6),

              // دکمه کنترل سریع مکث/پخش
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                iconSize: 20,
                icon: Icon(
                  session.isRunning ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
                  color: accent,
                ),
                onPressed: () {
                  RitmoHaptics.selection();
                  if (session.isRunning) {
                    RitmoTimerHub.instance.pauseActiveSession();
                  } else {
                    RitmoTimerHub.instance.resumeActiveSession();
                  }
                },
              ),

              // دکمه بستن یا پایان نشست
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                iconSize: 17,
                icon: Icon(
                  Icons.stop_circle_outlined,
                  color: colors.textSecondary.withValues(alpha: 0.7),
                ),
                onPressed: () {
                  RitmoHaptics.warning();
                  RitmoTimerHub.instance.stopActiveSession();
                },
              ),
            ],
          ),

          // نوار باریک پیشرفت در لبه پایینی بنر برای تایمرهای تارگت‌دار
          if (session.targetSeconds > 0)
            Positioned(
              left: 10,
              right: 10,
              bottom: 1,
              child: ValueListenableBuilder<int>(
                valueListenable: RitmoTimerHub.instance.secondsTickNotifier,
                builder: (context, _, child) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: session.progress,
                      minHeight: 2.2,
                      backgroundColor: accent.withValues(alpha: 0.12),
                      valueColor: AlwaysStoppedAnimation<Color>(accent),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );

    if (isOpaque) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: bannerContent,
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: blurSigma > 0 ? blurSigma : materialSpec.sigma,
            sigmaY: blurSigma > 0 ? blurSigma : materialSpec.sigma,
          ),
          child: bannerContent,
        ),
      ),
    );
  }
}
