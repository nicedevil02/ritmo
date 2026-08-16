import 'package:ritmo/core/ai/agent/agent_tool_call_parser.dart';

/// نتیجهٔ بررسی مجوز اجرای یک فراخوانی ابزار
class ToolAdmission {
  const ToolAdmission.allow()
      : allowed = true,
        reasonFa = null;

  const ToolAdmission.deny(this.reasonFa) : allowed = false;

  final bool allowed;

  /// دلیل رد شدن؛ عیناً به مدل برگردانده می‌شود تا رفتارش را اصلاح کند
  final String? reasonFa;
}

/// بودجهٔ سخت‌گیرانهٔ یک اجرای ایجنت
///
/// حلقهٔ ReAct بدون بودجه سه خطر جدی دارد: ۱) تکرار بی‌پایان یک فراخوانی،
/// ۲) مصرف توکن و هزینه، ۳) منتظر ماندن طولانی کاربر روی موبایل با
/// اینترنت ضعیف. این کلاس هر سه را مهار می‌کند.
class AgentBudget {
  AgentBudget({
    this.maxTurns = 4,
    this.maxToolCalls = 8,
    this.maxToolCallsPerTurn = 3,
    this.maxTranscriptChars = 24000,
    this.wallClock = const Duration(seconds: 100),
  });

  /// حداکثر تعداد نوبت مدل (نوبت آخر همیشه مخصوص پاسخ نهایی است)
  final int maxTurns;

  /// حداکثر فراخوانی ابزار در کل اجرا
  final int maxToolCalls;

  /// حداکثر فراخوانی ابزار در یک نوبت
  final int maxToolCallsPerTurn;

  /// سقف کاراکتر مکالمه پیش از کوتاه‌سازی
  final int maxTranscriptChars;

  /// سقف زمان کل اجرا
  final Duration wallClock;

  final DateTime _startedAt = DateTime.now();
  final Set<String> _signatures = <String>{};
  int _turns = 0;
  int _toolCalls = 0;

  int get turnsUsed => _turns;

  int get toolCallsUsed => _toolCalls;

  int get toolCallsLeft => maxToolCalls - _toolCalls;

  bool get canRunMoreTools => _toolCalls < maxToolCalls;

  Duration get elapsed => DateTime.now().difference(_startedAt);

  bool get isTimedOut => elapsed > wallClock;

  void countTurn() => _turns++;

  /// ثبت فراخوانی‌هایی که بیرون از حلقه (مثلاً پیش‌واکشی خودکار) اجرا شده‌اند
  void registerExecuted(String toolName, Map<String, dynamic> args) {
    _signatures.add(signature(toolName, args));
  }

  /// بررسی مجوز اجرا. در صورت تایید، شمارنده‌ها همان‌جا به‌روز می‌شوند.
  ToolAdmission admit(String toolName, Map<String, dynamic> args) {
    if (isTimedOut) {
      return const ToolAdmission.deny(
        'زمان مجاز پردازش تمام شد؛ با همین داده‌های موجود پاسخ نهایی را بنویس.',
      );
    }

    if (!canRunMoreTools) {
      return ToolAdmission.deny(
        'سقف $maxToolCalls فراخوانی ابزار در این گفت‌وگو پر شد؛ با داده‌های موجود پاسخ بده.',
      );
    }

    final sig = signature(toolName, args);
    if (_signatures.contains(sig)) {
      return const ToolAdmission.deny(
        'این ابزار دقیقاً با همین پارامترها پیش‌تر در این گفت‌وگو اجرا شده است؛ از نتیجهٔ قبلی استفاده کن و دوباره صدایش نزن.',
      );
    }

    _signatures.add(sig);
    _toolCalls++;
    return const ToolAdmission.allow();
  }

  /// امضای یکتای فراخوانی: نام ابزار + پارامترهای مرتب‌شده
  static String signature(String toolName, Map<String, dynamic> args) =>
      '$toolName|${AgentToolCallParser.stableArgs(args)}';
}
