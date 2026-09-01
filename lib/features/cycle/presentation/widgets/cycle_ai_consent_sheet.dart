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

  final granted = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) {
      final colors = ctx.colors;

      return Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: RitmoBreakpoints.sheetMaxHeight(ctx, factor: 0.94),
            ),
            child: RitmoGlassSheet(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
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
                        color: colors.border.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Header: Glowing Icon Pod + Title + Badge
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: colors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: Icon(
                            isPregnancyMode
                                ? CupertinoIcons.heart_fill
                                : CupertinoIcons.sparkles,
                            color: colors.primary,
                            size: 24,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isPregnancyMode
                                  ? 'دستیار هوشمند بارداری'
                                  : 'دستیار هوشمند سیکل بانوان',
                              style: RitmoTextStyles.cardTitle(colors.textPrimary),
                            ),
                            const SizedBox(height: 4),
                            RitmoCardBadge(
                              label: 'دستیار تخصصی ریتمو',
                              color: colors.primary,
                              icon: CupertinoIcons.sparkles,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Privacy Card with canonical sunken style
                  RitmoCard.neumorphicSunken(
                    padding: const EdgeInsets.all(RitmoSpacing.md),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 2.0),
                          child: Icon(
                            CupertinoIcons.shield_lefthalf_fill,
                            size: 20,
                            color: colors.primary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'دستیار هوشمند برای ارائه توصیه‌های دقیق فیزیولوژیک، علائم و تحلیل الگوی دوره‌ای شما را بررسی می‌کند. تمام داده‌ها طبق استانداردهای حفظ حریم خصوصی به صورت کاملاً امن و محلی پردازش می‌شوند.',
                            style: RitmoTextStyles.caption(colors.textSecondary).copyWith(height: 1.55),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: RitmoNeuButton(
                          onTap: () => Navigator.pop(ctx, false),
                          child: Text(
                            'انصراف',
                            style: TextStyle(
                              color: colors.textSecondary,
                              fontWeight: FontWeight.w600,
                              fontSize: 13.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: RitmoPrimaryButton(
                          label: 'موافقم و شروع',
                          icon: CupertinoIcons.arrow_left,
                          onPressed: () async {
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
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );

  if (granted == true) {
    onConsentGranted();
  }
}
