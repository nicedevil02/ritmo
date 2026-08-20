import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_colors.dart';
import 'package:ritmo/features/cycle/logic/cycle_lock_service.dart';
import 'package:ritmo/features/cycle/models/pregnancy_models.dart';

class PregStep4Privacy extends StatefulWidget {
  const PregStep4Privacy({
    super.key,
    required this.data,
    required this.onDataChanged,
    required this.onNext,
    required this.colors,
    required this.isDark,
  });

  final PregnancyOnboardingData data;
  final ValueChanged<PregnancyOnboardingData> onDataChanged;
  final VoidCallback onNext;
  final RitmoColors colors;
  final bool isDark;

  @override
  State<PregStep4Privacy> createState() => _PregStep4PrivacyState();
}

class _PregStep4PrivacyState extends State<PregStep4Privacy> {
  bool _hasPasscode = false;

  @override
  void initState() {
    super.initState();
    _checkPasscodeStatus();
  }

  Future<void> _checkPasscodeStatus() async {
    final hasPass = await CycleLockService.instance.hasAnyActivePin();
    if (mounted) {
      setState(() => _hasPasscode = hasPass);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final isDark = widget.isDark;
    final primaryColor = colors.primary;
    final data = widget.data;

    return SingleChildScrollView(
      key: const ValueKey('preg_step_4_privacy'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'حریم خصوصی و قفل',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'اطلاعات شما فقط در دستگاه خودتان ذخیره می‌شود.',
            style: TextStyle(
              fontSize: 12.5,
              color: colors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),

          // 1. Lock Switch
          _buildToggleRow(
            title: 'قفل ورود به بخش بارداری',
            subtitle: 'مستقل از قفل بخش چرخه است.',
            icon: CupertinoIcons.lock_fill,
            value: data.lockEnabled,
            onChanged: (val) => widget.onDataChanged(data.copyWith(lockEnabled: val)),
          ),

          // Lock helper if enabled and no password set
          if (data.lockEnabled && !_hasPasscode) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: colors.primary.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    CupertinoIcons.info_circle_fill,
                    color: primaryColor,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'رمز بعد از پایان راه‌اندازی تنظیم می‌شود.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),

          // 2. Hide from dashboard
          _buildToggleRow(
            title: 'پنهان کردن بارداری از صفحهٔ امروز',
            subtitle: 'اطلاعات بارداری در کارت امروز داشبورد اصلی نمایش داده نمی‌شود.',
            icon: CupertinoIcons.eye_slash_fill,
            value: data.hideFromDashboard,
            onChanged: (val) => widget.onDataChanged(data.copyWith(hideFromDashboard: val)),
          ),
          const SizedBox(height: 12),

          // 3. Mask notifications
          _buildToggleRow(
            title: 'پوشاندن متن یادآوری‌ها در اعلان‌ها',
            subtitle: 'متن اعلان فقط می‌نویسد یادآوری ریتمو و هیچ اشاره‌ای به بارداری ندارد.',
            icon: CupertinoIcons.bell_fill,
            value: data.maskNotifications,
            onChanged: (val) => widget.onDataChanged(data.copyWith(maskNotifications: val)),
          ),
          const SizedBox(height: 24),

          // Privacy Pill Badge
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: isDark ? 0.12 : 0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: primaryColor.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    CupertinoIcons.device_phone_portrait,
                    color: primaryColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'اطلاعات فقط روی گوشی',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'داده‌ها کاملاً آفلاین ذخیره شده و به هیچ سروری ارسال نمی‌شوند.',
                        style: TextStyle(
                          fontSize: 11,
                          color: colors.textSecondary,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleRow({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final colors = widget.colors;
    final isDark = widget.isDark;
    final primaryColor = colors.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: value
            ? primaryColor.withValues(alpha: isDark ? 0.14 : 0.06)
            : (isDark
                ? Colors.black.withValues(alpha: 0.25)
                : Colors.white.withValues(alpha: 0.6)),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: value
              ? primaryColor.withValues(alpha: 0.5)
              : colors.border.withValues(alpha: 0.4),
          width: value ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: value
                  ? primaryColor.withValues(alpha: 0.2)
                  : (isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.black.withValues(alpha: 0.04)),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: value ? primaryColor : colors.textSecondary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: value ? primaryColor : colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: colors.textSecondary,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          CupertinoSwitch(
            value: value,
            activeTrackColor: primaryColor,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
