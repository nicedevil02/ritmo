import 'package:flutter/cupertino.dart';
import 'package:ritmo/core/settings/settings_service.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/ritmo_toast.dart';
import 'package:ritmo/core/ux/ritmo_haptics.dart';

class SettingsDegradedBanner extends StatefulWidget {
  const SettingsDegradedBanner({super.key});

  @override
  State<SettingsDegradedBanner> createState() => _SettingsDegradedBannerState();
}

class _SettingsDegradedBannerState extends State<SettingsDegradedBanner> {
  bool _isRetrying = false;

  Future<void> _handleRetry() async {
    RitmoHaptics.tap();
    setState(() => _isRetrying = true);
    final ok = await SettingsService.instance.retryInit();
    if (!mounted) return;
    setState(() => _isRetrying = false);
    if (ok) {
      RitmoHaptics.confirm();
      RitmoToast.show(context, 'تنظیمات با موفقیت بازیابی شدند.');
    } else {
      RitmoHaptics.error();
      RitmoToast.show(context, 'تلاش مجدد ناموفق بود.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: SettingsService.instance.revision,
      builder: (innerCtx, _) {
        if (!SettingsService.instance.isDegraded) {
          return const SizedBox.shrink();
        }

        final colors = innerCtx.colors;

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.medicalRed.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colors.medicalRed.withValues(alpha: 0.35),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    CupertinoIcons.exclamationmark_triangle_fill,
                    color: colors.medicalRed,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'خطا در بارگذاری تنظیمات',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: colors.medicalRed,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'تنظیمات شما خوانده نشد. مقادیر زیر پیش‌فرضند و تغییرشان فعلاً ذخیره نمی‌شود.',
                style: TextStyle(
                  fontSize: 13,
                  color: colors.textPrimary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: CupertinoButton(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  color: colors.medicalRed,
                  borderRadius: BorderRadius.circular(10),
                  onPressed: _isRetrying ? null : _handleRetry,
                  child: _isRetrying
                      ? CupertinoActivityIndicator(color: colors.onPrimary)
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(CupertinoIcons.arrow_clockwise, size: 16, color: colors.onPrimary),
                            const SizedBox(width: 6),
                            Text(
                              'تلاش مجدد',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: colors.onPrimary,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
