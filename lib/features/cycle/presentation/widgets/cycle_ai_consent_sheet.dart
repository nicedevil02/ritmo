import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/observability/ritmo_logger.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/cycle/logic/cycle_clock.dart';

Future<void> showCycleAiConsentSheet(
  BuildContext context, {
  dynamic engineOutput,
  dynamic dayLogs,
  Map<String, String>? settings,
  bool isPregnancyMode = false,
  required VoidCallback onConsentGranted,
}) async {
  final hasConsent = settings?['cycle_consent_ai'] == 'true';
  if (hasConsent) {
    onConsentGranted();
    return;
  }

  final isDark = context.isDark;

  // Show privacy & AI assistant consent sheet connected to glass settings
  final granted = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: isDark
        ? Colors.black.withValues(alpha: 0.50)
        : Colors.black.withValues(alpha: 0.25),
    isScrollControlled: true,
    builder: (ctx) {
      final colors = ctx.colors;
      final isDark = ctx.isDark;
      final isGlass = ctx.isGlassEnabled;
      final blur = ctx.glassBlurSigma.clamp(0.0, 50.0);
      final opacity = (ctx.glassOpacityPercent / 100.0).clamp(0.05, 0.95);
      const sheetRadius = BorderRadius.vertical(top: Radius.circular(28));

      final content = Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.textTertiary.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Header: Glowing Icon Pod + Title + Badge
            Row(
              textDirection: TextDirection.rtl,
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: isDark
                        ? colors.primary.withValues(alpha: 0.18)
                        : colors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: colors.primary.withValues(
                        alpha: isDark ? 0.35 : 0.25,
                      ),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: colors.primary.withValues(
                          alpha: isDark ? 0.30 : 0.18,
                        ),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      isPregnancyMode
                          ? CupertinoIcons.heart_fill
                          : Icons.psychology_rounded,
                      color: colors.primary,
                      size: 26,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    textDirection: TextDirection.rtl,
                    children: [
                      Text(
                        isPregnancyMode
                            ? 'دستیار هوشمند بارداری'
                            : 'دستیار هوشمند سیکل بانوان',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: colors.textPrimary,
                          letterSpacing: -0.3,
                        ),
                        textDirection: TextDirection.rtl,
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: colors.primary.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'دستیار تخصصی ریتمو',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: colors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Privacy Card with subtle translucent styling
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isGlass
                    ? (isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.white.withValues(alpha: 0.50))
                    : colors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : const Color(0xFFD0D7E2).withValues(alpha: 0.8),
                  width: 1.0,
                ),
              ),
              child: Row(
                textDirection: TextDirection.rtl,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2.0),
                    child: Icon(
                      CupertinoIcons.shield_lefthalf_fill,
                      size: 18,
                      color: colors.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'دستیار هوشمند برای ارائه توصیه‌های دقیق فیزیولوژیک، علائم و تحلیل الگوی دوره‌ای شما را بررسی می‌کند. تمام داده‌ها طبق استانداردهای حفظ حریم خصوصی به صورت کاملاً امن و محلی پردازش می‌شوند.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: colors.textSecondary,
                        height: 1.6,
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: isGlass
                          ? (isDark
                              ? Colors.white.withValues(alpha: 0.06)
                              : Colors.white.withValues(alpha: 0.60))
                          : colors.surfaceElevated,
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.12)
                            : colors.border,
                        width: 1.0,
                      ),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => Navigator.pop(ctx, false),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Center(
                            child: Text(
                              'انصراف',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: colors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          colors.primary,
                          colors.primary.withValues(alpha: 0.85),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: colors.primary.withValues(
                            alpha: isDark ? 0.35 : 0.25,
                          ),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () async {
                          try {
                            final db = await DatabaseHelper.instance.database;
                            await db.insert('app_settings', {
                              'key': 'cycle_consent_ai',
                              'value': 'true',
                              'updatedAt': CycleClock.nowMillisecondsSinceEpoch,
                            });
                            if (settings != null) {
                              settings['cycle_consent_ai'] = 'true';
                            }
                          } catch (e, st) {
                            RitmoLogger.error(
                              '[CycleAiConsentSheet] error saving AI consent setting',
                              error: e,
                              stack: st,
                            );
                          }
                          if (ctx.mounted) {
                            Navigator.pop(ctx, true);
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'موافقم و شروع',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: colors.onPrimary,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Icon(
                                  CupertinoIcons.arrow_left,
                                  size: 15,
                                  color: colors.onPrimary,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );

      Widget sheetBody;
      if (!isGlass) {
        sheetBody = Container(
          decoration: BoxDecoration(
            color: colors.surfaceElevated,
            borderRadius: sheetRadius,
            border: Border.all(
              color: isDark ? colors.border : colors.divider,
              width: 1.0,
            ),
          ),
          child: content,
        );
      } else {
        sheetBody = ClipRRect(
          borderRadius: sheetRadius,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.glassTint.withValues(
                  alpha: isDark ? (opacity * 0.85).clamp(0.1, 0.95) : opacity,
                ),
                borderRadius: sheetRadius,
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.18)
                      : Colors.white.withValues(alpha: 0.70),
                  width: 1.0,
                ),
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: sheetRadius,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(
                        alpha: isDark ? 0.08 : 0.20,
                      ),
                      Colors.white.withValues(alpha: 0.0),
                    ],
                    stops: const [0.0, 0.45],
                  ),
                ),
                child: content,
              ),
            ),
          ),
        );
      }

      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(ctx).bottom,
        ),
        child: sheetBody,
      );
    },
  );

  if (granted == true) {
    onConsentGranted();
  }
}
