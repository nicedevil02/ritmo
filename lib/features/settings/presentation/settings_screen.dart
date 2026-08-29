import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:ritmo/core/localization/locale_repository.dart';
import 'package:ritmo/core/logging/ritmo_logger.dart';
import 'package:ritmo/core/settings/settings_registry.dart';
import 'package:ritmo/core/settings/settings_service.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/theme/theme_repository.dart';
import 'package:ritmo/core/utils/ios26_page_route.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/utils/ritmo_toast.dart';
import 'package:ritmo/core/ux/ritmo_haptics.dart';
import 'package:ritmo/features/profile/presentation/crash_reports_screen.dart';
import 'package:ritmo/features/settings/presentation/groups/appearance_group_screen.dart';
import 'package:ritmo/features/settings/presentation/groups/assistant_privacy_group_screen.dart';
import 'package:ritmo/features/settings/presentation/groups/calendar_group_screen.dart';
import 'package:ritmo/features/settings/presentation/groups/data_backup_group_screen.dart';
import 'package:ritmo/features/settings/presentation/groups/identity_group_screen.dart';
import 'package:ritmo/features/settings/presentation/groups/modules_group_screen.dart';
import 'package:ritmo/features/settings/presentation/groups/notifications_group_screen.dart';
import 'package:ritmo/features/settings/presentation/groups/security_group_screen.dart';
import 'package:ritmo/features/settings/presentation/settings_inspector_screen.dart';
import 'package:ritmo/features/settings/presentation/settings_search_delegate.dart';
import 'package:ritmo/features/settings/presentation/widgets/identity_header.dart';
import 'package:ritmo/features/settings/presentation/widgets/quick_settings_sheet.dart';
import 'package:ritmo/features/settings/presentation/widgets/settings_degraded_banner.dart';
import 'package:ritmo/features/settings/presentation/widgets/settings_group_tile.dart';
import 'package:ritmo/features/settings/presentation/widgets/settings_health_card.dart';
import 'package:ritmo/features/settings/presentation/widgets/settings_premium_card.dart';
import 'package:ritmo/features/settings/presentation/widgets/settings_ready_gate.dart';

/// صفحه اصلی تنظیمات اپلیکیشن با طراحی مدرن تفکیک‌شده iOS 26 Inset Grouped
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
        '${toPersianDigits(remaining.toString())} لمس تا فعال‌سازی پنل فنی و بازرس تنظیمات',
      );
    } else if (_tapCount >= 7) {
      _tapCount = 0;
      if (kDebugMode) {
        Navigator.push(
          context,
          Ios26PageRoute(builder: (_) => const SettingsInspectorScreen()),
        );
      } else {
        Navigator.push(
          context,
          Ios26PageRoute(builder: (_) => const CrashReportsScreen()),
        );
      }
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

    // ─── دسته‌بندی منطقی گزینه‌ها در بخش‌های جزیره‌ای مجزا (iOS 26 Inset Grouped) ───
    final sections = [
      _SettingsSectionData(
        title: 'شخصی‌سازی و تجربه کاربری',
        icon: CupertinoIcons.person_crop_circle,
        items: [
          _GroupItem(
            group: SettingsGroup.identity,
            title: SettingsGroup.identity.labelFa,
            subtitle: SettingsGroup.identity.subtitleFa,
            icon: SettingsGroup.identity.icon,
            gradient: const [Color(0xFF00C9FF), Color(0xFF92FE9D)],
            pageBuilder: () => const IdentityGroupScreen(),
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
        ],
      ),
      _SettingsSectionData(
        title: 'هسته هوشمند و قابلیت‌ها',
        icon: CupertinoIcons.sparkles,
        items: [
          _GroupItem(
            group: SettingsGroup.modules,
            title: SettingsGroup.modules.labelFa,
            subtitle: SettingsGroup.modules.subtitleFa,
            icon: SettingsGroup.modules.icon,
            gradient: const [Color(0xFF6A11CB), Color(0xFF2575FC)],
            pageBuilder: () => const ModulesGroupScreen(),
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
            group: SettingsGroup.calendar,
            title: SettingsGroup.calendar.labelFa,
            subtitle: SettingsGroup.calendar.subtitleFa,
            icon: SettingsGroup.calendar.icon,
            gradient: const [Color(0xFF4568DC), Color(0xFFB06AB3)],
            pageBuilder: () => const CalendarGroupScreen(),
          ),
        ],
      ),
      _SettingsSectionData(
        title: 'ارتباطات و اعلان‌ها',
        icon: CupertinoIcons.bell,
        items: [
          _GroupItem(
            group: SettingsGroup.notifications,
            title: SettingsGroup.notifications.labelFa,
            subtitle: SettingsGroup.notifications.subtitleFa,
            icon: SettingsGroup.notifications.icon,
            gradient: const [Color(0xFFFF9966), Color(0xFFFF5E62)],
            pageBuilder: () => const NotificationsGroupScreen(),
          ),
        ],
      ),
      _SettingsSectionData(
        title: 'امنیت و مدیریت داده‌ها',
        icon: CupertinoIcons.lock_shield,
        items: [
          _GroupItem(
            group: SettingsGroup.security,
            title: SettingsGroup.security.labelFa,
            subtitle: SettingsGroup.security.subtitleFa,
            icon: SettingsGroup.security.icon,
            gradient: const [Color(0xFFFF416C), Color(0xFFFF4B2B)],
            pageBuilder: () => const SecurityGroupScreen(),
          ),
          _GroupItem(
            group: SettingsGroup.dataBackup,
            title: SettingsGroup.dataBackup.labelFa,
            subtitle: SettingsGroup.dataBackup.subtitleFa,
            icon: SettingsGroup.dataBackup.icon,
            gradient: const [Color(0xFF373B44), Color(0xFF4286F4)],
            pageBuilder: () => DataBackupGroupScreen(onFactoryReset: widget.onFactoryReset),
          ),
        ],
      ),
    ];

    return Directionality(
      textDirection: TextDirection.rtl,
      child: RitmoSingleMorphingScaffold(
        title: 'پروفایل و تنظیمات',
        subtitle: 'شخصی‌سازی، حریم خصوصی و اعلان‌ها',
        onBack: () => Navigator.maybePop(context),
        actions: [
          RitmoVibrancyActionButton(
            icon: CupertinoIcons.search,
            tooltip: 'جستجو در تنظیمات',
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
          ),
          const SizedBox(width: 6),
          RitmoVibrancyActionButton(
            icon: CupertinoIcons.slider_horizontal_3,
            tooltip: 'تنظیمات سریع',
            onTap: () {
              RitmoHaptics.selection();
              QuickSettingsSheet.show(
                context,
                themeRepository: widget.themeRepository,
              );
            },
          ),
        ],
        bodyBuilder: (context, scrollController, topPadding) {
          return SettingsReadyGate(
            showDegradedBanner: false,
            child: SingleChildScrollView(
              controller: scrollController,
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              padding: EdgeInsets.fromLTRB(14, topPadding, 14, 80),
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
                  const SizedBox(height: 18),

                  // ─── بخش‌های جزیره‌ای تنظیمات تفکیک‌شده به سبک iOS 26 ───
                  AnimatedBuilder(
                    animation: SettingsService.instance.revision,
                    builder: (context, _) {
                      final showAdvanced = SettingsService.instance.get<bool>('show_advanced_settings');

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final section in sections) ...[
                            // کارت جزیره‌ای گروه‌بندی‌شده
                            Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: colors.card,
                                borderRadius: BorderRadius.circular(18),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Column(
                                children: [
                                  for (int i = 0; i < section.items.length; i++) ...[
                                    if (i > 0)
                                      Divider(
                                        height: 1,
                                        thickness: 0.7,
                                        color: colors.divider.withValues(alpha: 0.6),
                                        indent: 64,
                                        endIndent: 14,
                                      ),
                                    Builder(
                                      builder: (context) {
                                        final g = section.items[i];
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
                            ),
                          ],
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 12),

                  // ─── بخش نسخه و کپی‌رایت ───
                  Center(
                    child: GestureDetector(
                      onTap: _onVersionTapped,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
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
          );
        },
      ),
    );
  }
}

class _SettingsSectionData {
  const _SettingsSectionData({
    required this.title,
    required this.icon,
    required this.items,
  });

  final String title;
  final IconData icon;
  final List<_GroupItem> items;
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
