import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:ritmo/core/localization/locale_repository.dart';
import 'package:ritmo/core/logging/ritmo_logger.dart';
import 'package:ritmo/core/services/premium_service.dart';
import 'package:ritmo/core/settings/settings_registry.dart';
import 'package:ritmo/core/settings/settings_service.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/theme/theme_repository.dart';
import 'package:ritmo/core/utils/ios26_page_route.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/utils/ritmo_toast.dart';
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
import 'package:ritmo/features/settings/presentation/widgets/settings_group_tile.dart';
import 'package:ritmo/features/settings/presentation/widgets/settings_health_card.dart';
import 'package:ritmo/features/settings/presentation/widgets/settings_mode_switcher.dart';
import 'package:ritmo/features/settings/presentation/widgets/settings_premium_card.dart';
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
  String _version = 'نامشخص';
  String _buildNumber = '';
  int _tapCount = 0;
  DateTime? _lastVersionTapTime;

  @override
  void initState() {
    super.initState();
    _loadPackageInfo();
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
    } catch (e, st) {
      RitmoLog.error('Settings', 'Failed to load package info', e, st);
      if (mounted) {
        setState(() {
          _version = 'نامشخص';
          _buildNumber = '';
        });
      }
    }
  }

  void _onVersionTapped() {
    final now = DateTime.now();
    if (_lastVersionTapTime != null && now.difference(_lastVersionTapTime!).inMilliseconds > 2000) {
      _tapCount = 0;
    }
    _lastVersionTapTime = now;
    _tapCount++;

    if (_tapCount >= 4 && _tapCount < 7) {
      final remaining = 7 - _tapCount;
      RitmoToast.show(
        context,
        '${toPersianDigits(remaining.toString())} لمس تا فعال‌سازی پنل فنی و گزارش خرابی',
      );
    } else if (_tapCount >= 7) {
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
              const SettingsPremiumCard(),
              const SizedBox(height: 16),

              // ─── جابجایی حالت ساده / پیشرفته ───
              const SettingsModeSwitcher(),
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
                              return SettingsGroupTile(
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
