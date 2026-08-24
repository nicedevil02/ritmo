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

  final colors = context.colors;

  // Show privacy & AI assistant consent sheet
  final granted = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) {
      return Container(
        decoration: BoxDecoration(
          color: colors.surfaceElevated,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BorderSide(color: colors.border, width: 1.5)),
        ),
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.textTertiary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              textDirection: TextDirection.rtl,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.psychology_rounded,
                    color: colors.primary,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    isPregnancyMode
                        ? 'دستیار هوشمند بارداری'
                        : 'دستیار هوشمند سیکل بانوان',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: colors.textPrimary,
                    ),
                    textDirection: TextDirection.rtl,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'دستیار هوشمند برای ارائه توصیه‌های دقیق فیزیولوژیک، علائم و تحلیل الگوی دوره‌ای شما را بررسی می‌کند. تمام داده‌ها طبق استانداردهای حفظ حریم خصوصی به صورت امن پردازش می‌شوند.',
              style: TextStyle(
                fontSize: 13,
                color: colors.textSecondary,
                height: 1.6,
              ),
              textDirection: TextDirection.rtl,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.textSecondary,
                      side: BorderSide(color: colors.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('انصراف', style: TextStyle()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.primary,
                      foregroundColor: colors.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
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
                    child: const Text(
                      'موافقم و شروع',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      );
    },
  );

  if (granted == true) {
    onConsentGranted();
  }
}
