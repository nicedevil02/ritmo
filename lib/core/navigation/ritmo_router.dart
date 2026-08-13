import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ritmo/core/domain/engines/ritmo_event_bus.dart';
import 'package:ritmo/features/cycle/presentation/cycle_screen.dart';
import 'package:ritmo/features/goals/presentation/goals_screen.dart';
import 'package:ritmo/features/health/presentation/health_screen.dart';
import 'package:ritmo/features/study/study_module_entry.dart';
import 'package:ritmo/features/supplementary_sports/presentation/ss_home_dashboard_screen.dart';
import 'package:ritmo/features/wellbeing/presentation/wellbeing_screen.dart';
import 'package:ritmo/features/worship/presentation/worship_screen.dart';

/// نوع مقصدِ یک مسیر.
enum RitmoRouteKind { tab, screen, moduleEntry }

/// مقصدِ حل‌شدهٔ یک مسیر — از ناوبری واقعی جداست تا بتوان آن را بدون ویجت
/// تست کرد (قدم ۳ سند «مسیر خواب»).
class RitmoRouteTarget {
  const RitmoRouteTarget._({
    required this.kind,
    this.tabIndex,
    this.builder,
    this.moduleOpener,
  });

  const RitmoRouteTarget.tab(int tabIndex)
      : this._(kind: RitmoRouteKind.tab, tabIndex: tabIndex);

  const RitmoRouteTarget.screen(WidgetBuilder builder)
      : this._(kind: RitmoRouteKind.screen, builder: builder);

  const RitmoRouteTarget.module(Future<void> Function(BuildContext) opener)
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

    // تب‌ها (حالت full: ۰ سیستم‌ها / ۱ بینش‌ها / ۲ امروز / ۳ دستیار / ۴ تقویم)
    if (r == '/' || r == '/today') {
      return const RitmoRouteTarget.tab(2);
    }
    if (r == '/systems' || r == '/system') {
      return const RitmoRouteTarget.tab(0);
    }
    if (r == '/insights' || r == '/reports') {
      return const RitmoRouteTarget.tab(1);
    }
    if (r == '/routines' || r == '/routine') {
      return const RitmoRouteTarget.tab(3);
    }
    if (r == '/calendar') {
      return const RitmoRouteTarget.tab(4);
    }

    // صفحه‌ها
    if (r == '/goals' || r == '/goal') {
      return const RitmoRouteTarget.screen(
          _ConstScreenBuilder(GoalsScreen()).call);
    }
    if (r == '/sports' || r == '/sport') {
      return const RitmoRouteTarget.screen(
          _ConstScreenBuilder(SSHomeDashboardScreen()).call);
    }
    if (r == '/health') {
      return const RitmoRouteTarget.screen(
          _ConstScreenBuilder(HealthScreen()).call);
    }
    if (r == '/worship') {
      return const RitmoRouteTarget.screen(
          _ConstScreenBuilder(WorshipScreen()).call);
    }

    // بخش خواب در «حال و تعادل» زندگی می‌کند؛ «مسیر پله‌ها» هم بلوکی درون
    // همان بخش است (اسکرول به بلوک در فاز A)، پس هر دو به یک مقصد می‌رسند.
    if (r == '/sleep' || r == '/sleep/journey') {
      return const RitmoRouteTarget.screen(_ConstScreenBuilder(
              WellbeingScreen(initialSection: WellbeingSection.sleep))
          .call);
    }

    // چرخه: کلیدواژه‌های فارسی/انگلیسی (مثل رفتار قبلی registry)
    if (r.contains('cycle') ||
        r.contains('period') ||
        r.contains('چرخه') ||
        r.contains('پریود')) {
      return const RitmoRouteTarget.screen(
          _ConstScreenBuilder(CycleScreen()).call);
    }

    // ماژول‌های با ورودی اختصاصی
    if (r == '/konkur' || r == '/study') {
      return RitmoRouteTarget.module(
        (context) async => StudyModuleEntry.open(context),
      );
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
        RitmoEventBus().fire(RitmoEvent(
          type: 'navigate_tab',
          timestamp: DateTime.now(),
          payload: {'index': target.tabIndex},
        ));
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

/// سازندهٔ constِ WidgetBuilder از یک ویجت const، تا resolve بتواند const باشد.
class _ConstScreenBuilder {
  const _ConstScreenBuilder(this._widget);
  final Widget _widget;

  Widget call(BuildContext _) => _widget;
}
