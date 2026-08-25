import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/logging/ritmo_logger.dart';
import 'package:ritmo/core/settings/settings_service.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/widgets/ritmo_module_app_bar.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_page_scaffold.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_segmented_control.dart';
import 'package:ritmo/features/settings/presentation/widgets/settings_section.dart';

/// مرکز مدیریت حریم خصوصی، متن مبدل و امنیت اعلان‌ها
class NotificationPrivacyScreen extends StatefulWidget {
  const NotificationPrivacyScreen({super.key});

  @override
  State<NotificationPrivacyScreen> createState() => _NotificationPrivacyScreenState();
}

class _NotificationPrivacyScreenState extends State<NotificationPrivacyScreen> {
  String _privacyMode = 'redacted';
  bool _biometricEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() {
    if (!mounted) return;
    setState(() {
      _privacyMode = SettingsService.instance.get<String>('notif_privacy_mode');
      _biometricEnabled = SettingsService.instance.get<bool>('notif_biometric_enabled');
    });
  }

  Future<void> _updateSetting(String key, Object val) async {
    if (!mounted) return;
    setState(() {
      if (key == 'notif_privacy_mode') _privacyMode = val.toString();
      if (key == 'notif_biometric_enabled') _biometricEnabled = val == true;
    });
    try {
      await SettingsService.instance.set(key, val);
    } catch (e, st) {
      RitmoLog.error('Settings', 'Failed to update setting: $key', e, st);
    }
    if (mounted) {
      _loadSettings();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: RitmoPageScaffold(
        padding: EdgeInsets.zero,
        appBar: RitmoModuleAppBar.fromContext(
          context: context,
          title: 'حریم خصوصی اعلان‌ها',
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 60),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Live Preview Card
              _buildLivePreviewCard(colors),
              const SizedBox(height: 16),

              // 2. Privacy Mode Selection
              SettingsSection(
                title: 'سطح پیش‌فرض اعلان‌های خصوصی',
                footer: _getPrivacyExplanation(_privacyMode),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: RitmoSegmentedControl<String>(
                      selected: _privacyMode,
                      segments: const {
                        'redacted': 'مبدل',
                        'locked': 'قفل‌شده',
                        'hidden': 'مخفی',
                        'none': 'عادی',
                      },
                      onSelected: (val) => _updateSetting('notif_privacy_mode', val),
                    ),
                  ),
                ],
              ),

              // 3. Biometric & Authentication Protection
              SettingsSection(
                title: 'امنیت و احراز هویت',
                footer: 'در صورت فعال بودن، مشاهده اعلان‌های محرمانه و یادداشت‌های خصوصی مستلزم اثرانگشت یا رمز عبور دستگاه است.',
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'قفل اثرانگشت برای صندوق محرمانه',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: colors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'حفاظت از جزئیات چرخه و یادداشت‌های شخصی',
                                style: TextStyle(fontSize: 12, color: colors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        CupertinoSwitch(
                          value: _biometricEnabled,
                          activeTrackColor: colors.primary,
                          onChanged: (val) => _updateSetting('notif_biometric_enabled', val),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // 4. Sensitive Categories Info
              SettingsSection(
                title: 'دسته‌بندی‌های تحت پوشش این سطح',
                children: [
                  _buildCategoryRow(
                    icon: CupertinoIcons.heart_fill,
                    iconColor: const Color(0xFFEC4899),
                    title: 'چرخهٔ سلامت بانوان',
                    subtitle: 'پیش‌بینی شروع دوره، یادآور علائم و مصرف دارو',
                    colors: colors,
                  ),
                  const Divider(height: 1, indent: 56),
                  _buildCategoryRow(
                    icon: CupertinoIcons.lock_shield_fill,
                    iconColor: const Color(0xFF8B5CF6),
                    title: 'یادداشت‌های محرمانه',
                    subtitle: 'متن یادداشت‌ها و کارهای علامت‌گذاری‌شده به عنوان خصوصی',
                    colors: colors,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLivePreviewCard(dynamic colors) {
    String previewTitle;
    String previewBody;
    IconData previewIcon;
    Color iconBgColor;

    switch (_privacyMode) {
      case 'hidden':
        previewTitle = 'هیچ اعلانی روی صفحه قفل ارسال نمی‌شود';
        previewBody = 'پیام فقط داخل صندوق درون‌برنامه ثبت می‌گردد.';
        previewIcon = CupertinoIcons.eye_slash_fill;
        iconBgColor = colors.textTertiary;
        break;
      case 'locked':
        previewTitle = 'ریتمو: یادآوری خصوصی 🔒';
        previewBody = 'برای مشاهده، اثرانگشت خود را تأیید کنید';
        previewIcon = CupertinoIcons.lock_fill;
        iconBgColor = const Color(0xFF8B5CF6);
        break;
      case 'redacted':
        previewTitle = 'ریتمو: یک یادآوری داری 🌸';
        previewBody = 'برای مشاهده باز کنید';
        previewIcon = CupertinoIcons.shield_lefthalf_fill;
        iconBgColor = colors.primary;
        break;
      case 'none':
      default:
        previewTitle = 'یادآوری ریتمو 🌸';
        previewBody = 'لوازم شخصیات رو چک کن 💜';
        previewIcon = CupertinoIcons.bell_fill;
        iconBgColor = const Color(0xFF10B981);
        break;
    }

    return Container(
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
              Icon(CupertinoIcons.device_phone_portrait, size: 16, color: colors.textSecondary),
              const SizedBox(width: 6),
              Text(
                'پیش‌نمایش زنده روی صفحهٔ قفل',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colors.surfaceSunken,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: iconBgColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(previewIcon, size: 20, color: iconBgColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        previewTitle,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        previewBody,
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  toPersianDigits('۱۰:۰۰'),
                  style: TextStyle(fontSize: 11, color: colors.textTertiary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required dynamic colors,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colors.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: colors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getPrivacyExplanation(String mode) {
    switch (mode) {
      case 'redacted':
        return 'متن اعلان روی صفحهٔ قفل با عنوان خنثی («ریتمو: یک یادآوری داری») جایگزین می‌شود. داخل برنامه متن اصلی نمایش می‌یابد.';
      case 'locked':
        return 'اعلان روی صفحه قفل خنثی است و حتی درون صندوق برنامه نیز تا زمان تأیید هویت بیومتریک تار خواهد ماند.';
      case 'hidden':
        return 'هیچ اعلانی به سیستم‌عامل فرستاده نمی‌شود. اطلاعات صرفاً پس از ورود به برنامه در دسترس است.';
      case 'none':
      default:
        return 'متن کامل اعلان به صورت عادی و بدون تغییر روی صفحه قفل نمایش داده می‌شود.';
    }
  }
}
