import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:ritmo/core/localization/locale_repository.dart';
import 'package:ritmo/core/services/premium_service.dart';
import 'package:ritmo/core/settings/settings_registry.dart';
import 'package:ritmo/core/settings/settings_service.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/theme/theme_repository.dart';
import 'package:ritmo/features/sleep/data/sleep_program_debug_helper.dart';
import 'package:ritmo/core/utils/ios26_page_route.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/ux/ritmo_haptics.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_page_scaffold.dart';
import 'package:ritmo/core/widgets/ritmo_module_app_bar.dart';
import 'package:ritmo/features/premium/presentation/premium_upgrade_sheet.dart';
import 'package:ritmo/features/profile/presentation/crash_reports_screen.dart';
import 'package:ritmo/features/settings/presentation/groups/appearance_group_screen.dart';
import 'package:ritmo/features/settings/presentation/groups/assistant_privacy_group_screen.dart';
import 'package:ritmo/features/settings/presentation/groups/calendar_group_screen.dart';
import 'package:ritmo/features/settings/presentation/groups/data_backup_group_screen.dart';
import 'package:ritmo/features/settings/presentation/groups/identity_group_screen.dart';
import 'package:ritmo/features/settings/presentation/groups/modules_group_screen.dart';
import 'package:ritmo/features/settings/presentation/groups/notifications_group_screen.dart';
import 'package:ritmo/features/settings/presentation/groups/security_group_screen.dart';
import 'package:ritmo/features/settings/presentation/settings_search_delegate.dart';
import 'package:ritmo/features/settings/presentation/widgets/identity_header.dart';
import 'package:ritmo/features/settings/presentation/widgets/quick_settings_sheet.dart';
import 'package:ritmo/features/settings/presentation/widgets/settings_degraded_banner.dart';
import 'package:ritmo/features/settings/presentation/widgets/settings_health_card.dart';
import 'package:ritmo/features/settings/presentation/widgets/settings_ready_gate.dart';

/// صفحه اصلی تنظیمات اپلیکیشن با طراحی اختصاصی iOS 26 Inset Grouped
/// به همراه آیکن‌های سه‌بعدی نئونی و انیمیشن ناوبری Depth Parallax
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.onFactoryReset,
    required this.themeRepository,
    required this.localeRepository,
  });

  final VoidCallback onFactoryReset;
  final ThemeRepository themeRepository;
  final LocaleRepository localeRepository;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _version = '۱.۰.۰';
  String _buildNumber = '۱';
  int _tapCount = 0;

  @override
  void initState() {
    super.initState();
    _loadPackageInfo();
  }

  Widget _buildPremiumStatusCard(BuildContext context) {
    final isPremium = PremiumService.instance.isPremium;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isPremium
              ? [const Color(0xff1E1B4B), const Color(0xff312E81)]
              : [const Color(0xff1F2937), const Color(0xff111827)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isPremium
              ? const Color(0xff818CF8).withValues(alpha: 0.3)
              : Colors.amber.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: (isPremium ? const Color(0xff6366F1) : Colors.amber).withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (isPremium ? const Color(0xff818CF8) : Colors.amber).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isPremium ? Icons.diamond_rounded : Icons.star_rounded,
              color: isPremium ? const Color(0xffA5B4FC) : Colors.amber,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isPremium ? 'اشتراک پرمیوم ریتمو پلاس 💎' : 'ریتمو پایه (نسخه رایگان) ⚡',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isPremium
                      ? 'دسترسی کامل به تمام امکانات هوشمند اپلیکیشن'
                      : 'سقف ۴ ماژول، ۷ روتین و ۳ هدف همزمان',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {
              PremiumUpgradeSheet.show(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isPremium ? const Color(0xff6366F1) : Colors.amber,
              foregroundColor: isPremium ? Colors.white : Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(
              isPremium ? 'مدیریت' : 'ارتقا 💎',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeSwitcher(BuildContext context) {
    final colors = context.colors;

    return AnimatedBuilder(
      animation: SettingsService.instance.revision,
      builder: (context, _) {
        final showAdvanced = SettingsService.instance.get<bool>('show_advanced_settings');

        return Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  key: const ValueKey('mode_switch_simple'),
                  onTap: () async {
                    if (showAdvanced) {
                      await SettingsService.instance.set('show_advanced_settings', false);
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: !showAdvanced ? colors.primary.withValues(alpha: 0.12) : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: !showAdvanced ? Border.all(color: colors.primary.withValues(alpha: 0.3)) : null,
                    ),
                    child: Center(
                      child: Text(
                        'حالت ساده',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: !showAdvanced ? FontWeight.bold : FontWeight.w500,
                          color: !showAdvanced ? colors.primary : colors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: GestureDetector(
                  key: const ValueKey('mode_switch_advanced'),
                  onTap: () async {
                    if (!showAdvanced) {
                      await SettingsService.instance.set('show_advanced_settings', true);
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: showAdvanced ? colors.primary.withValues(alpha: 0.12) : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: showAdvanced ? Border.all(color: colors.primary.withValues(alpha: 0.3)) : null,
                    ),
                    child: Center(
                      child: Text(
                        'حالت پیشرفته',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: showAdvanced ? FontWeight.bold : FontWeight.w500,
                          color: showAdvanced ? colors.primary : colors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _loadPackageInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _version = toPersianDigits(info.version);
          _buildNumber = toPersianDigits(info.buildNumber);
        });
      }
    } catch (_) {}
  }

  void _onVersionTapped() {
    _tapCount++;
    if (_tapCount >= 7) {
      _tapCount = 0;
      Navigator.push(
        context,
        Ios26PageRoute(builder: (_) => const CrashReportsScreen()),
      );
    }
  }

  void _navigateToGroupWithHighlight(
    BuildContext context,
    SettingsGroup group,
    String highlightKey,
  ) {
    Widget page;
    switch (group) {
      case SettingsGroup.identity:
        page = IdentityGroupScreen(highlightKey: highlightKey);
        break;
      case SettingsGroup.modules:
        page = ModulesGroupScreen(highlightKey: highlightKey);
        break;
      case SettingsGroup.notifications:
        page = NotificationsGroupScreen(highlightKey: highlightKey);
        break;
      case SettingsGroup.appearance:
        page = AppearanceGroupScreen(
          themeRepository: widget.themeRepository,
          localeRepository: widget.localeRepository,
          highlightKey: highlightKey,
        );
        break;
      case SettingsGroup.assistant:
        page = AssistantPrivacyGroupScreen(highlightKey: highlightKey);
        break;
      case SettingsGroup.dataBackup:
        page = DataBackupGroupScreen(
          onFactoryReset: widget.onFactoryReset,
          highlightKey: highlightKey,
        );
        break;
      case SettingsGroup.security:
        page = SecurityGroupScreen(highlightKey: highlightKey);
        break;
      case SettingsGroup.calendar:
        page = CalendarGroupScreen(highlightKey: highlightKey);
        break;
    }

    Navigator.push(
      context,
      Ios26PageRoute(builder: (_) => page),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final groups = [
      _GroupItem(
        group: SettingsGroup.identity,
        title: SettingsGroup.identity.labelFa,
        subtitle: SettingsGroup.identity.subtitleFa,
        icon: SettingsGroup.identity.icon,
        gradient: const [Color(0xFF00C9FF), Color(0xFF92FE9D)],
        pageBuilder: () => const IdentityGroupScreen(),
      ),
      _GroupItem(
        group: SettingsGroup.modules,
        title: SettingsGroup.modules.labelFa,
        subtitle: SettingsGroup.modules.subtitleFa,
        icon: SettingsGroup.modules.icon,
        gradient: const [Color(0xFF6A11CB), Color(0xFF2575FC)],
        pageBuilder: () => const ModulesGroupScreen(),
      ),
      _GroupItem(
        group: SettingsGroup.notifications,
        title: SettingsGroup.notifications.labelFa,
        subtitle: SettingsGroup.notifications.subtitleFa,
        icon: SettingsGroup.notifications.icon,
        gradient: const [Color(0xFFFF9966), Color(0xFFFF5E62)],
        pageBuilder: () => const NotificationsGroupScreen(),
      ),
      _GroupItem(
        group: SettingsGroup.appearance,
        title: SettingsGroup.appearance.labelFa,
        subtitle: SettingsGroup.appearance.subtitleFa,
        icon: SettingsGroup.appearance.icon,
        gradient: const [Color(0xFFDA22FF), Color(0xFF9733EE)],
        pageBuilder: () => AppearanceGroupScreen(
          themeRepository: widget.themeRepository,
          localeRepository: widget.localeRepository,
        ),
      ),
      _GroupItem(
        group: SettingsGroup.assistant,
        title: SettingsGroup.assistant.labelFa,
        subtitle: SettingsGroup.assistant.subtitleFa,
        icon: SettingsGroup.assistant.icon,
        gradient: const [Color(0xFF11998E), Color(0xFF38EF7D)],
        pageBuilder: () => const AssistantPrivacyGroupScreen(),
      ),
      _GroupItem(
        group: SettingsGroup.dataBackup,
        title: SettingsGroup.dataBackup.labelFa,
        subtitle: SettingsGroup.dataBackup.subtitleFa,
        icon: SettingsGroup.dataBackup.icon,
        gradient: const [Color(0xFF373B44), Color(0xFF4286F4)],
        pageBuilder: () => DataBackupGroupScreen(onFactoryReset: widget.onFactoryReset),
      ),
      _GroupItem(
        group: SettingsGroup.security,
        title: SettingsGroup.security.labelFa,
        subtitle: SettingsGroup.security.subtitleFa,
        icon: SettingsGroup.security.icon,
        gradient: const [Color(0xFFFF416C), Color(0xFFFF4B2B)],
        pageBuilder: () => const SecurityGroupScreen(),
      ),
      _GroupItem(
        group: SettingsGroup.calendar,
        title: SettingsGroup.calendar.labelFa,
        subtitle: SettingsGroup.calendar.subtitleFa,
        icon: SettingsGroup.calendar.icon,
        gradient: const [Color(0xFF4568DC), Color(0xFFB06AB3)],
        pageBuilder: () => const CalendarGroupScreen(),
      ),
    ];

    return RitmoPageScaffold(
      appBar: RitmoModuleAppBar(
        title: 'پروفایل و تنظیمات',
        actions: [
          IconButton(
            key: const ValueKey('quick_settings_appbar_btn'),
            icon: Icon(CupertinoIcons.slider_horizontal_3, color: colors.primary, size: 20),
            tooltip: 'تنظیمات سریع',
            onPressed: () {
              RitmoHaptics.selection();
              QuickSettingsSheet.show(context);
            },
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () async {
                  final selected = await showSearch<SettingDescriptor?>(
                    context: context,
                    delegate: SettingsSearchDelegate(
                      themeRepository: widget.themeRepository,
                      localeRepository: widget.localeRepository,
                    ),
                  );
                  if (selected != null && context.mounted) {
                    _navigateToGroupWithHighlight(context, selected.group, selected.key);
                  }
                },
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: colors.primary.withValues(alpha: 0.15),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        CupertinoIcons.search,
                        size: 16,
                        color: colors.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'جست‌وجو...',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: colors.primary,
                          ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SettingsReadyGate(
        showDegradedBanner: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SettingsDegradedBanner(),
              const SettingsHealthCard(),
              // ─── هدر هویتی اختصاصی پرمیوم iOS 26 ───
              IdentityHeader(
                onTap: () {
                  Navigator.push(
                    context,
                    Ios26PageRoute(builder: (_) => const IdentityGroupScreen()),
                  );
                },
              ),
              const SizedBox(height: 16),

              // ─── کارت وضعیت اشتراک ریتمو پلاس ───
              _buildPremiumStatusCard(context),
              const SizedBox(height: 16),

              // ─── جابجایی حالت ساده / پیشرفته ───
              _buildModeSwitcher(context),
              const SizedBox(height: 24),

              // ─── عنوان بخش دسته‌بندی‌ها ───
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 16,
                      decoration: BoxDecoration(
                        color: colors.primary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'دسته‌بندی‌های تنظیمات',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: colors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // ─── فهرست گروه‌های تنظیمات به سبک iOS 26 Inset Grouped ───
              AnimatedBuilder(
                animation: SettingsService.instance.revision,
                builder: (context, _) {
                  final showAdvanced = SettingsService.instance.get<bool>('show_advanced_settings');

                  return Container(
                    decoration: BoxDecoration(
                      color: colors.card,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: colors.border,
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: colors.shadow.withValues(alpha: 0.04),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        for (int i = 0; i < groups.length; i++) ...[
                          if (i > 0)
                            Divider(
                              height: 1,
                              thickness: 1,
                              color: colors.border.withValues(alpha: 0.6),
                              indent: 64,
                              endIndent: 16,
                            ),
                          Builder(
                            builder: (context) {
                              final g = groups[i];
                              final count = SettingsRegistry.userVisibleByGroup(
                                g.group,
                                includeAdvanced: showAdvanced,
                              ).length;
                              return _Ios26SettingsTile(
                                title: g.title,
                                subtitle: g.subtitle,
                                icon: g.icon,
                                gradient: g.gradient,
                                count: count,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    Ios26PageRoute(builder: (_) => g.pageBuilder()),
                                  );
                                },
                              );
                            },
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
              if (kDebugMode) ...[
                const SizedBox(height: 16),
                Center(
                  child: TextButton.icon(
                    onPressed: () async {
                      await SleepProgramDebugHelper.seedSevenNights();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('۷ شب لاگ خواب نمونه ثبت شد (دیباگ)', style: TextStyle()),
                            backgroundColor: Color(0xff8B5CF6),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.bug_report, size: 18, color: Color(0xff8B5CF6)),
                    label: const Text('تولید ۷ شب لاگ خواب تستی (دیباگ)', style: TextStyle(fontSize: 12, color: Color(0xff8B5CF6))),
                  ),
                ),
              ],
              const SizedBox(height: 28),

              // ─── بخش نسخه و کپی‌رایت ───
              Center(
                child: GestureDetector(
                  onTap: _onVersionTapped,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      children: [
                        Text(
                          'ریتمو — سبک زندگی منظم و خودآگاه',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: colors.textSecondary,
                            ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'نسخه $_version (ساخت $_buildNumber)',
                          style: TextStyle(
                            fontSize: 11,
                            color: colors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ردیف تنظیمات به سبک اختصاصی iOS 26
class _Ios26SettingsTile extends StatefulWidget {
  const _Ios26SettingsTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradient,
    required this.count,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> gradient;
  final int count;
  final VoidCallback onTap;

  @override
  State<_Ios26SettingsTile> createState() => _Ios26SettingsTileState();
}

class _Ios26SettingsTileState extends State<_Ios26SettingsTile> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        RitmoHaptics.tap();
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _isPressed
              ? colors.primary.withValues(alpha: 0.07)
              : Colors.transparent,
        ),
        child: Row(
          children: [
            // ─── آیکن سه‌بعدی با هاله‌ی گرادیانی ───
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(13),
                gradient: LinearGradient(
                  colors: widget.gradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: widget.gradient.first.withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(
                widget.icon,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),

            // ─── متن عنوان و زیرعنوان ───
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                      ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    widget.subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: colors.textSecondary,
                      height: 1.35,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),

            // ─── بج تعداد تنظیمات و شورون ───
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: widget.gradient.first.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: widget.gradient.first.withValues(alpha: 0.16),
                  width: 1,
                ),
              ),
              child: Text(
                '${toPersianDigits(widget.count)} تنظیم',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: widget.gradient.first,
                  ),
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              CupertinoIcons.chevron_left,
              size: 16,
              color: colors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupItem {
  const _GroupItem({
    required this.group,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradient,
    required this.pageBuilder,
  });

  final SettingsGroup group;
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> gradient;
  final Widget Function() pageBuilder;
}
