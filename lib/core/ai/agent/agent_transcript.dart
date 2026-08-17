import 'package:ritmo/core/ai/agent/agent_tool.dart';
import 'package:ritmo/core/ai/agent/agent_tool_protocol.dart';

/// انبار پیام‌های یک اجرای ایجنت (حافظهٔ حلقهٔ ReAct)
///
/// بدون این لایه، هر نوبت یک درخواست مستقل بود و مدل نمی‌دید که خودش چه
/// ابزاری را صدا زده و نتیجهٔ آن چه بوده است.
class AgentTranscript {
  AgentTranscript({required String systemPrompt}) {
    _add('system', systemPrompt);
  }

  final List<Map<String, String>> _messages = <Map<String, String>>[];

  /// نقشی که نتیجهٔ ابزار با آن به مدل بازگردانده می‌شود.
  ///
  /// چرا user و نه tool؟ نقش tool در پروتکل OpenAI فقط همراه tool_call_id
  /// معتبر پذیرفته می‌شود و در حالت XML ما چنین شناسه‌ای وجود ندارد؛
  /// رله‌های سازگار (OpenRouter، Groq، Cloudflare، سرورهای ایرانی) چنین
  /// پیامی را با خطای ۴۰۰ رد می‌کنند. نقش system در میانهٔ گفت‌وگو هم توسط
  /// بعضی مدل‌های کوچک نادیده گرفته می‌شود. نقش user در همهٔ مسیرها
  /// (شامل پل وب) قابل اعتماد است.
  static const String toolResultRole = 'user';

  void addUser(String text) => _add('user', text);

  /// پاسخ خام مدل (شامل تگ tool_call) باید دقیقاً همان‌طور که بوده ذخیره
  /// شود؛ مدل باید فراخوانی خودش را در تاریخچه ببیند.
  void addAssistant(String rawText) => _add('assistant', rawText);

  void addBlock(String text) => _add(toolResultRole, text);

  void addHistory(List<Map<String, String>> history) {
    for (final message in history) {
      final role = message['role'];
      final content = message['content'];
      if (role == null || content == null) continue;
      _add(role, content);
    }
  }

  /// نتیجهٔ ابزارها را به مکالمه اضافه می‌کند و همان متن را برمی‌گرداند
  /// تا مسیر پل وب (که آرایهٔ پیام نمی‌گیرد) هم از همین متن استفاده کند.
  String addToolResults(
    List<AgentToolResult> results, {
    required bool noMoreTools,
  }) {
    final block = AgentToolProtocol.toolResultsBlock(
      results,
      noMoreTools: noMoreTools,
    );
    addBlock(block);
    return block;
  }

  void _add(String role, String content) {
    final text = content.trim();
    if (text.isEmpty) return;
    _messages.add(<String, String>{'role': role, 'content': text});
  }

  /// کپی قابل ارسال به گیت‌وی (همان قالب `List<Map<String, String>>`)
  List<Map<String, String>> toMessages() => _messages
      .map((message) => Map<String, String>.from(message))
      .toList(growable: false);

  int get messageCount => _messages.length;

  int get charCount => _messages.fold<int>(
        0,
        (sum, message) => sum + (message['content']?.length ?? 0),
      );

  /// اگر مکالمه از سقف کاراکتر عبور کرد، پیام‌های میانی حذف می‌شوند.
  /// پیام سیستمی (ایندکس ۰) و سؤال اولیه کاربر (ایندکس ۱) غیرقابل‌حذف (pinned) هستند.
  bool trimToBudget(int maxChars, {int keepTail = 4}) {
    var trimmed = false;
    while (charCount > maxChars && _messages.length > (2 + keepTail)) {
      _messages.removeAt(2);
      trimmed = true;
    }
    return trimmed;
  }
}
