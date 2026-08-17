import 'package:flutter/material.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/observability/ritmo_logger.dart';

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

  // Show privacy & AI assistant consent sheet
  final granted = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) {
      return Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1E293B),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BorderSide(color: Color(0xFF334155), width: 1.5)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
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
                    color: const Color(0xFFEC4899).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.psychology_rounded,
                    color: Color(0xFFEC4899),
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    isPregnancyMode
                        ? 'دستیار هوشمند بارداری'
                        : 'دستیار هوشمند سیکل بانوان',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textDirection: TextDirection.rtl,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'دستیار هوشمند برای ارائه توصیه‌های دقیق فیزیولوژیک، علائم و تحلیل الگوی دوره‌ای شما را بررسی می‌کند. تمام داده‌ها طبق استانداردهای حفظ حریم خصوصی به صورت امن پردازش می‌شوند.',
              style: TextStyle(
                fontSize: 13,
                color: Colors.white70,
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
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: Color(0xFF334155)),
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
                      backgroundColor: const Color(0xFFEC4899),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () async {
                      try {
                        final db = await DatabaseHelper.instance.database;
                        await db.insert('settings', {
                          'key': 'cycle_consent_ai',
                          'value': 'true',
                          'updatedAt': DateTime.now().millisecondsSinceEpoch,
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
                      if (ctx.mounted) Navigator.pop(ctx, true);
                    },
                    child: const Text(
                      'تایید و ورود به گفتگو',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );

  if (granted == true) {
    onConsentGranted();
  }
}
