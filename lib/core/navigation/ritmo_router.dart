import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ritmo/core/domain/engines/ritmo_event_bus.dart';
import 'package:ritmo/core/app_mode/app_mode_service.dart';
import 'package:ritmo/features/cycle/presentation/cycle_screen.dart';
import 'package:ritmo/features/goals/presentation/goals_screen.dart';
import 'package:ritmo/features/health/presentation/health_screen.dart';
import 'package:ritmo/features/study/study_module_entry.dart';
import 'package:ritmo/features/supplementary_sports/supplementary_sports.dart';
import 'package:ritmo/features/wellbeing/presentation/wellbeing_screen.dart';
import 'package:ritmo/features/worship/presentation/worship_screen.dart';
import 'package:ritmo/features/profile/presentation/web_bridge_diagnostics_screen.dart';

/// نوع مقصدِ یک مسیر.
enum RitmoRouteKind { tab, screen, moduleEntry }

/// مقصدِ حل‌شدهٔ یک مسیر — از ناوبری واقعی جداست تا بتوان آن را بدون ویجت
/// تست کرد (قدم ۳ سند «مسیر خواب»).
class RitmoRouteTarget {
  RitmoRouteTarget._({
    required this.kind,
    this.tabIndex,
    this.builder,
    this.moduleOpener,
  });

  RitmoRouteTarget.tab(int tabIndex)
    : this._(kind: RitmoRouteKind.tab, tabIndex: tabIndex);

  RitmoRouteTarget.screen(WidgetBuilder builder)
    : this._(kind: RitmoRouteKind.screen, builder: builder);

  RitmoRouteTarget.module(Future<void> Function(BuildContext) opener)
    : this._(kind: RitmoRouteKind.moduleEntry, moduleOpener: opener);

  final RitmoRouteKind kind;

  /// اندیس تب در HomeNavigationShell (حالت full).
  final int? tabIndex;
  final WidgetBuilder? builder;
  final Future<void> Function(BuildContext context)? moduleOpener;
}

/// روترِ رشته‌ایِ واحد برای کل اپ — قدم ۳ سند «مسیر خواب».
///
/// تا قبل از این، نگاشت مسیرها فقط داخل `assistant_action_registry` بود و
/// نه نوتیف‌ها و نه میانبرهای UI نمی‌توانستند به مقصدهای غیر-تب بروند
/// (رویداد `navigate_tab` فقط اندیس تب می‌فهمد). حالا سه مصرف‌کننده روی
/// همین یک نگاشت سوارند: دستیار، payload نوتیف، و میانبرهای داخل اپ.
class RitmoRouter {
  RitmoRouter._();

  /// روی MaterialApp نصب می‌شود تا مسیرها از بیرون درخت (مثل تپ روی نوتیف)
  /// هم قابل باز شدن باشند.
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static String? _pendingRoute;

  /// مسیر را برای مصرفِ بعدی (اولین فریم shell) نگه می‌دارد — پوشش cold start.
  static void queuePendingRoute(String route) {
    _pendingRoute = route;
  }

  static String? consumePendingRoute() {
    final route = _pendingRoute;
    _pendingRoute = null;
    return route;
  }

  /// نگاشت مسیر به مقصد. نامشخص ⇒ null (تا caller بتواند fallback بزند).
  static RitmoRouteTarget? resolve(String route) {
    final r = route.trim().toLowerCase();
    if (r.isEmpty) return null;

    // تب‌ها بر اساس حالت فعال برنامه (AppMode.simple یا AppMode.full)
    final mode = AppModeService.instance.current;
    if (mode == AppMode.simple) {
      if (r == '/' || r == '/today' || r == '/tasks') return RitmoRouteTarget.tab(0);
      if (r == '/calendar') return RitmoRouteTarget.tab(1);
      if (r == '/systems' || r == '/system' || r == '/insights' || r == '/reports' || r == '/routines') return RitmoRouteTarget.tab(2);
    } else {
      if (r == '/' || r == '/today') return RitmoRouteTarget.tab(2);
      if (r == '/systems' || r == '/system') return RitmoRouteTarget.tab(0);
      if (r == '/insights' || r == '/reports') return RitmoRouteTarget.tab(1);
      if (r == '/routines' || r == '/routine' || r == '/assistant') return RitmoRouteTarget.tab(3);
      if (r == '/calendar') return RitmoRouteTarget.tab(4);
    }

    // صفحه‌ها
    if (r == '/goals' || r == '/goal') {
      return RitmoRouteTarget.screen((_) => const GoalsScreen());
    }
    if (r == '/sports' || r == '/sport' || r == '/movement') {
      return RitmoRouteTarget.screen((_) => const MvHubScreen());
    }
    if (r == '/health') {
      return RitmoRouteTarget.screen((_) => const HealthScreen());
    }
    if (r == '/worship') {
      return RitmoRouteTarget.screen((_) => const WorshipScreen());
    }

    // بخش خواب در «حال و تعادل» زندگی می‌کند؛ «مسیر پله‌ها» هم بلوکی درون
    // همان بخش است (اسکرول به بلوک در فاز A)، پس هر دو به یک مقصد می‌رسند.
    if (r == '/sleep' || r == '/sleep/journey') {
      return RitmoRouteTarget.screen(
        (_) => const WellbeingScreen(initialSection: WellbeingSection.trend),
      );
    }

    // چرخه: کلیدواژه‌های فارسی/انگلیسی (مثل رفتار قبلی registry)
    if (r.contains('cycle') ||
        r.contains('period') ||
        r.contains('چرخه') ||
        r.contains('پریود')) {
      return RitmoRouteTarget.screen((_) => const CycleScreen());
    }

    // ماژول‌های با ورودی اختصاصی
    if (r == '/konkur' || r == '/study') {
      return RitmoRouteTarget.module((context) async {
        await StudyModuleEntry.open(context);
      });
    }

    // صفحهٔ عیب‌یابی پل وب
    if (r == '/bridge-diagnostics' || r == '/web-bridge-diagnostics') {
      return RitmoRouteTarget.screen((_) => const WebBridgeDiagnosticsScreen());
    }

    return null;
  }

  /// تولیدکنندهٔ مسیرها برای MaterialApp.onGenerateRoute
  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    final name = settings.name;
    if (name == null) return null;

    final target = resolve(name);
    if (target == null) return null;

    if (target.kind == RitmoRouteKind.screen && target.builder != null) {
      return MaterialPageRoute<dynamic>(
        settings: settings,
        builder: target.builder!,
      );
    }

    if (target.kind == RitmoRouteKind.tab && target.tabIndex != null) {
      RitmoEventBus().fire(
        RitmoEvent(
          type: 'navigate_tab',
          timestamp: DateTime.now(),
          payload: {'index': target.tabIndex},
        ),
      );
      return null;
    }

    return null;
  }

  /// مسیر را باز می‌کند. خروجی false یعنی مسیر ناشناخته بود.
  static Future<bool> open(String route) async {
    final target = resolve(route);
    if (target == null) return false;

    final nav = navigatorKey.currentState;
    if (nav == null) {
      // اپ هنوز بالا نیامده؛ برای اولین فریم shell نگهش می‌داریم.
      queuePendingRoute(route.trim());
      return true;
    }

    if (_pendingRoute == route.trim()) _pendingRoute = null;

    switch (target.kind) {
      case RitmoRouteKind.tab:
        nav.popUntil((r) => r.isFirst);
        RitmoEventBus().fire(
          RitmoEvent(
            type: 'navigate_tab',
            timestamp: DateTime.now(),
            payload: {'index': target.tabIndex},
          ),
        );
        return true;
      case RitmoRouteKind.screen:
        unawaited(nav.push(MaterialPageRoute(builder: target.builder!)));
        return true;
      case RitmoRouteKind.moduleEntry:
        await target.moduleOpener!(nav.context);
        return true;
    }
  }
}
