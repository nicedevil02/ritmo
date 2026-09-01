import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:ritmo/core/app_mode/app_mode_service.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/domain/engines/ritmo_event_bus.dart';
import 'package:ritmo/core/localization/locale_repository.dart';
import 'package:ritmo/core/navigation/ritmo_router.dart';
import 'package:ritmo/core/navigation/shell_metrics.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/theme/theme_repository.dart';
import 'package:ritmo/core/utils/ritmo_toast.dart';
import 'package:ritmo/core/ux/ritmo_sheet_scaffold.dart';
import 'package:ritmo/features/assistant/presentation/assistant_screen.dart';
import 'package:ritmo/features/calendar/presentation/calendar_screen.dart';
import 'package:ritmo/features/profile/presentation/profile_screen.dart';
import 'package:ritmo/features/routines/presentation/universal_planner_sheet.dart';
import 'package:ritmo/features/simple_tasks/presentation/simple_tasks_screen.dart';
import 'package:ritmo/features/today/presentation/now_dashboard_screen.dart';
import 'package:ritmo/features/today/presentation/systems_hub_screen.dart';

import 'package:ritmo/features/today/presentation/widgets/ritmo_nav_bar.dart';

class HomeNavigationShell extends StatefulWidget {
  const HomeNavigationShell({
    super.key,
    required this.onLogout,
    required this.themeRepository,
    required this.localeRepository,
  });
  final VoidCallback onLogout;
  final ThemeRepository themeRepository;
  final LocaleRepository localeRepository;

  static int calendarTabIndexFor(AppMode mode) =>
      RitmoShellMetrics.calendarTabIndexFor(mode);

  @override
  State<HomeNavigationShell> createState() => _HomeNavigationShellState();
}

class _HomeNavigationShellState extends State<HomeNavigationShell> {
  late AppMode _activeMode;
  late int _currentIndex;
  late List<Widget?> _screens;
  StreamSubscription<RitmoEvent>? _eventSubscription;
  DateTime? _lastBackPressTime;
  final ValueNotifier<int> _tasksFocusTrigger = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    _activeMode = AppModeService.instance.current;
    _currentIndex = RitmoShellMetrics.defaultTabFor(_activeMode);
    _screens = List.filled(RitmoShellMetrics.tabCountFor(_activeMode), null);
    _screens[_currentIndex] = _buildScreen(_currentIndex, _activeMode);

    _eventSubscription = RitmoEventBus().onEvents.listen((event) {
      if (event.type == 'navigate_tab') {
        final index = event.payload['index'] as int?;
        final maxTabs = RitmoShellMetrics.tabCountFor(_activeMode);
        if (index != null && index >= 0 && index < maxTabs) {
          setState(() {
            _currentIndex = index;
            _screens[index] ??= _buildScreen(index, _activeMode);
          });
        }
      } else if (event.type == 'app_mode_changed') {
        _handleModeChange(AppModeService.instance.current);
      }
    });

    _requestNotificationPermissionIfNeeded();

    // قدم ۳: اگر اپ با تپ روی نوتیف (deep link) باز شده، مسیر معلق را اجرا کن
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pending = RitmoRouter.consumePendingRoute();
      if (pending != null) {
        unawaited(RitmoRouter.open(pending));
      }
    });
  }

  void _handleModeChange(AppMode newMode) {
    if (_activeMode == newMode) return;
    setState(() {
      _activeMode = newMode;
      _currentIndex = RitmoShellMetrics.defaultTabFor(newMode);
      _screens = List.filled(RitmoShellMetrics.tabCountFor(newMode), null);
      _screens[_currentIndex] = _buildScreen(_currentIndex, newMode);
    });
  }

  Future<void> _requestNotificationPermissionIfNeeded() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final rows = await db.query(
        'app_settings',
        where: "key = 'notif_permission_asked'",
        limit: 1,
      );

      if (rows.isNotEmpty && rows.first['value'] == 'true') {
        return;
      }

      final plugin = FlutterLocalNotificationsPlugin();
      final androidImplementation = plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (androidImplementation != null) {
        final granted = await androidImplementation.areNotificationsEnabled();
        if (granted == false) {
          await androidImplementation.requestNotificationsPermission();
        }
      }
    } catch (e) {
      debugPrint(
        'Error requesting notifications permission at shell startup: $e',
      );
    }
  }

  Widget _buildScreen(int index, AppMode mode) {
    if (mode == AppMode.simple) {
      switch (index) {
        case 0:
          return SimpleTasksScreen(focusTrigger: _tasksFocusTrigger);
        case 1:
          return const CalendarScreen();
        case 2:
          return SystemsHubScreen(
            onLogout: widget.onLogout,
            themeRepository: widget.themeRepository,
            localeRepository: widget.localeRepository,
          );
        default:
          return const SizedBox.shrink();
      }
    } else {
      switch (index) {
        case 0:
          return SystemsHubScreen(
            onLogout: widget.onLogout,
            themeRepository: widget.themeRepository,
            localeRepository: widget.localeRepository,
          );
        case 1:
          return ProfileScreen(
            onLogout: widget.onLogout,
            themeRepository: widget.themeRepository,
            localeRepository: widget.localeRepository,
          );
        case 2:
          return NowDashboardScreen(
            onLogout: widget.onLogout,
            themeRepository: widget.themeRepository,
            localeRepository: widget.localeRepository,
            onNavigateToTab: (idx) {
              final maxTabs = _screens.length;
              if (idx >= 0 && idx < maxTabs) {
                setState(() {
                  _currentIndex = idx;
                  _screens[idx] ??= _buildScreen(idx, mode);
                });
              }
            },
          );
        case 3:
          return const AssistantScreen(isTab: true);
        case 4:
          return const CalendarScreen();
        default:
          return const SizedBox.shrink();
      }
    }
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    _tasksFocusTrigger.dispose();
    super.dispose();
  }

  void _refreshCurrentScreen() {
    setState(() {
      final maxTabs = RitmoShellMetrics.tabCountFor(_activeMode);
      if (_currentIndex >= 0 && _currentIndex < maxTabs) {
        _screens[_currentIndex] = _buildScreen(_currentIndex, _activeMode);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppMode>(
      valueListenable: AppModeService.instance.notifier,
      builder: (context, currentMode, _) {
        if (_activeMode != currentMode) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _handleModeChange(currentMode);
          });
        }

        final defaultTab = RitmoShellMetrics.defaultTabFor(currentMode);
        final maxTabs = RitmoShellMetrics.tabCountFor(currentMode);

        // Prevent out-of-bounds index
        if (_currentIndex >= maxTabs) {
          _currentIndex = defaultTab;
        }

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) return;

            if (_currentIndex != defaultTab) {
              setState(() {
                _currentIndex = defaultTab;
                _screens[defaultTab] ??= _buildScreen(defaultTab, currentMode);
              });
              return;
            }

            final now = DateTime.now();
            if (_lastBackPressTime == null ||
                now.difference(_lastBackPressTime!) >
                    const Duration(seconds: 2)) {
              _lastBackPressTime = now;
              RitmoToast.show(
                context,
                'برای خروج، دوباره دکمه برگشت را بزنید',
                icon: Icons.exit_to_app_rounded,
                iconColor: context.colors.warning,
              );
            } else {
              await SystemNavigator.pop();
            }
          },
          child: AppleCardDeckHost(
            child: Scaffold(
              resizeToAvoidBottomInset: false,
              extendBody: true,
              body: Stack(
              children: [
                // Background Gradient
                Positioned.fill(
                  child: RitmoTheme.buildBackgroundContainer(
                    context: context,
                    child: const SizedBox.expand(),
                  ),
                ),

                // Current Screen View
                Positioned.fill(
                  child: SafeArea(
                    bottom: false,
                    child: IndexedStack(
                      index: _currentIndex < maxTabs
                          ? _currentIndex
                          : defaultTab,
                      children: List.generate(maxTabs, (index) {
                        return (index < _screens.length
                                ? _screens[index]
                                : null) ??
                            const SizedBox.shrink();
                      }),
                    ),
                  ),
                ),

                // Bottom Navigation Bar (Always Visible)
                if (MediaQuery.of(context).viewInsets.bottom == 0)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: RitmoNavBar(
                      mode: currentMode,
                      currentIndex: _currentIndex < maxTabs
                          ? _currentIndex
                          : defaultTab,
                      onSelectTab: (index) {
                        setState(() {
                          _currentIndex = index;
                          _screens[index] ??= _buildScreen(index, currentMode);
                        });
                      },
                      onCenterTap: () {
                        if (currentMode == AppMode.simple) {
                          if (_currentIndex != 0) {
                            setState(() {
                              _currentIndex = 0;
                              _screens[0] ??= _buildScreen(0, AppMode.simple);
                            });
                          }
                          _tasksFocusTrigger.value++;
                        } else {
                          final isHomeActive =
                              _currentIndex ==
                              RitmoShellMetrics.homeTabIndexFor(AppMode.full);
                          if (isHomeActive) {
                            Navigator.push(
                              context,
                              PageRouteBuilder(
                                opaque: false,
                                barrierDismissible: true,
                                pageBuilder: (context, _, _) =>
                                    UniversalPlannerSheet(
                                      onSaved: _refreshCurrentScreen,
                                    ),
                              ),
                            );
                          } else {
                            setState(() {
                              _currentIndex = RitmoShellMetrics.homeTabIndexFor(
                                AppMode.full,
                              );
                              _screens[RitmoShellMetrics.homeTabIndexFor(
                                AppMode.full,
                              )] ??= _buildScreen(
                                RitmoShellMetrics.homeTabIndexFor(AppMode.full),
                                AppMode.full,
                              );
                            });
                          }
                        }
                      },
                      onCenterLongPress: () {
                        Navigator.push(
                          context,
                          PageRouteBuilder(
                            opaque: false,
                            barrierDismissible: true,
                            pageBuilder: (context, _, _) =>
                                UniversalPlannerSheet(
                                  onSaved: _refreshCurrentScreen,
                                ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );
  }
}
