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
    this.maxWrites = 3,
    this.maxTranscriptChars = 24000,
    this.wallClock = const Duration(seconds: 100),
  });

  /// حداکثر تعداد نوبت مدل (نوبت آخر همیشه مخصوص پاسخ نهایی است)
  final int maxTurns;

  /// حداکثر فراخوانی ابزار در کل اجرا
  final int maxToolCalls;

  /// حداکثر فراخوانی ابزار در یک نوبت
  final int maxToolCallsPerTurn;

  /// حداکثر تعداد تغییر واقعی و نوشتن در دیتابیس در کل اجرا
  final int maxWrites;

  /// سقف کاراکتر مکالمه پیش از کوتاه‌سازی
  final int maxTranscriptChars;

  /// سقف زمان کل اجرا
  final Duration wallClock;

  final DateTime _startedAt = DateTime.now();
  final Set<String> _signatures = <String>{};
  final Set<String> _readSignatures = <String>{};
  final Set<String> _rejectedSignatures = <String>{};
  int _turns = 0;
  int _toolCalls = 0;

  DateTime? _pausedAt;
  Duration _pausedDuration = Duration.zero;
  int _pauseDepth = 0;

  int get turnsUsed => _turns;

  int get toolCallsUsed => _toolCalls;

  int get toolCallsLeft => maxToolCalls - _toolCalls;

  bool get canRunMoreTools => _toolCalls < maxToolCalls;

  bool wasRejected(String toolName, Map<String, dynamic> args) {
    return _rejectedSignatures.contains(signature(toolName, args));
  }

  Duration get elapsed {
    final total = DateTime.now().difference(_startedAt);
    final currentPause =
        (_pausedAt != null) ? DateTime.now().difference(_pausedAt!) : Duration.zero;
    final net = total - _pausedDuration - currentPause;
    return net.isNegative ? Duration.zero : net;
  }

  bool get isTimedOut => elapsed > wallClock;

  void countTurn() => _turns++;

  /// متوقف کردن ساعت زمان انتظار (مثلاً در زمان تایید یا پاسخ کاربر)
  void pauseClock() {
    _pauseDepth++;
    if (_pauseDepth == 1) {
      _pausedAt = DateTime.now();
    }
  }

  /// ازسرگیری ساعت زمان انتظار
  void resumeClock() {
    if (_pauseDepth > 0) {
      _pauseDepth--;
      if (_pauseDepth == 0 && _pausedAt != null) {
        _pausedDuration += DateTime.now().difference(_pausedAt!);
        _pausedAt = null;
      }
    }
  }

  /// پاک کردن امضاهای فقط‌خواندنی جهت مجاز شدن بازرسی وضعیت پس از تغییرات
  void clearReadSignatures() {
    _signatures.removeAll(_readSignatures);
    _readSignatures.clear();
  }

  /// بازگردانی بودجه در صورت انصراف کاربر، رد شدن کارت یا تایم‌اوت
  /// نکته مهم: امضا از _signatures حذف نمی‌شود و در _rejectedSignatures ثبت می‌شود
  /// تا مدل نتواند همان درخواست رد شده را مکرراً تکرار کند.
  void unadmit(String toolName, Map<String, dynamic> args) {
    final sig = signature(toolName, args);
    _rejectedSignatures.add(sig);
    if (_toolCalls > 0) _toolCalls--;
    _readSignatures.remove(sig);
  }

  /// ثبت فراخوانی‌هایی که بیرون از حلقه (مثلاً پیش‌واکشی خودکار) اجرا شده‌اند
  void registerExecuted(
    String toolName,
    Map<String, dynamic> args, {
    bool isReadOnly = false,
  }) {
    final sig = signature(toolName, args);
    _signatures.add(sig);
    if (isReadOnly) {
      _readSignatures.add(sig);
    }
  }

  /// بررسی مجوز اجرا. در صورت تایید، شمارنده‌ها همان‌جا به‌روز می‌شوند.
  ToolAdmission admit(
    String toolName,
    Map<String, dynamic> args, {
    bool isReadOnly = false,
  }) {
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
    if (isReadOnly) {
      _readSignatures.add(sig);
    }
    _toolCalls++;
    return const ToolAdmission.allow();
  }

  /// امضای یکتای فراخوانی: نام ابزار + پارامترهای مرتب‌شده
  static String signature(String toolName, Map<String, dynamic> args) =>
      '$toolName|${AgentToolCallParser.stableArgs(args)}';
}
