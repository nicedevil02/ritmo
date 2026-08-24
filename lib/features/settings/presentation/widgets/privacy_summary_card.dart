import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/settings/settings_service.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/ux/ritmo_haptics.dart';

class PrivacySummaryCard extends StatelessWidget {
  const PrivacySummaryCard({super.key});

  static int calculateScore() {
    int score = 0;
    final lock = SettingsService.instance.get<bool>('app_lock_enabled') ||
        SettingsService.instance.get<bool>('app_biometric_enabled');
    if (lock) score += 25;

    final screenSec = SettingsService.instance.get<bool>('screen_security_enabled');
    if (screenSec) score += 25;

    final localAi = SettingsService.instance.get<bool>('ai_local_processing_only') ||
        !SettingsService.instance.get<bool>('assistant_can_modify_settings');
    if (localAi) score += 25;

    final purgeDays = SettingsService.instance.get<int>('ai_auto_purge_days');
    if (purgeDays > 0 && purgeDays <= 30) score += 25;

    return score;
  }

  static Future<void> applyMaxPrivacy() async {
    await SettingsService.instance.set('app_lock_enabled', true);
    await SettingsService.instance.set('app_biometric_enabled', true);
    await SettingsService.instance.set('screen_security_enabled', true);
    await SettingsService.instance.set('ai_local_processing_only', true);
    await SettingsService.instance.set('ai_auto_purge_days', 14);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return AnimatedBuilder(
      animation: SettingsService.instance.revision,
      builder: (context, _) {
        final score = calculateScore();

        final Color statusColor;
        final String statusLabel;
        final IconData statusIcon;

        if (score >= 80) {
          statusColor = const Color(0xFF10B981);
          statusLabel = 'حفاظت عالی';
          statusIcon = CupertinoIcons.shield_lefthalf_fill;
        } else if (score >= 50) {
          statusColor = const Color(0xFFF59E0B);
          statusLabel = 'حفاظت متوسط';
          statusIcon = CupertinoIcons.shield;
        } else {
          statusColor = const Color(0xFFEF4444);
          statusLabel = 'نیاز به توجه';
          statusIcon = CupertinoIcons.exclamationmark_shield_fill;
        }

        return Directionality(
          textDirection: TextDirection.rtl,
          child: Container(
            key: const ValueKey('privacy_summary_card'),
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(statusIcon, color: statusColor, size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ممیزی و وضعیت حریم خصوصی',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: colors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            statusLabel,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${toPersianDigits(score)}٪',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: score / 100.0,
                    minHeight: 6,
                    backgroundColor: colors.border,
                    valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                  ),
                ),
                if (score < 100) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      key: const ValueKey('max_privacy_button'),
                      onPressed: () async {
                        RitmoHaptics.confirm();
                        await applyMaxPrivacy();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('حداکثر سطح حفاظت حریم خصوصی فعال شد.'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: statusColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      icon: const Icon(CupertinoIcons.sparkles, size: 16),
                      label: const Text(
                        'بهبود حریم خصوصی با یک لمس',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
