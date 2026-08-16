import 'package:ritmo/core/ai/agent/intent/agent_intent_router.dart';

/// نگاهدارنده سازگاری عقب (فاز ۴)
///
/// منطق واقعی به `intent/agent_intent_router.dart` منتقل شد تا تطبیق در سطح
/// توکن و حل تاریخ یکجا انجام شود. این فایل فقط نقطه ورود قدیمی را زنده
/// نگه می‌دارد تا مصرف‌کننده‌های موجود (AgentLoopRunner) دست نخورند.
export 'package:ritmo/core/ai/agent/intent/agent_intent_router.dart'
    show PrefetchResult;

class AgentIntentPrefetcher {
  const AgentIntentPrefetcher._();

  static const int maxToolsPerTurn = AgentIntentRouter.maxToolsPerTurn;

  static Future<PrefetchResult> prefetchForQuery(String userQuery) =>
      AgentIntentRouter.instance.route(userQuery);
}
