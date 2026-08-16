import 'dart:convert';

import 'package:ritmo/core/ai/agent/agent_tool.dart';

/// فرمت سیمی گفت‌وگوی ایجنت با مدل دربارهٔ ابزارها
enum AgentToolWireFormat {
  /// تگ متنی `<tool_call>{...}</tool_call>` داخل جریان معمولی پاسخ.
  /// تنها حالت پیاده‌سازی‌شدهٔ فاز ۱ و تنها حالتی که با پل وب ChatGPT هم کار
  /// می‌کند (چون آنجا فقط متن رد و بدل می‌شود، نه بدنهٔ JSON درخواست).
  xmlInline,

  /// فراخوانی بومی تابع (فیلد `tools` در بدنهٔ درخواست سازگار با OpenAI).
  /// فعلاً جای‌نگهدار است: AIGateway.sendCustomChatStream تنها messages را
  /// می‌فرستد، پس تا اضافه‌شدن پشتیبانی گیت‌وی، runner همیشه xmlInline را
  /// انتخاب می‌کند. با آماده‌شدن گیت‌وی فقط formatFor تغییر می‌کند، نه حلقه.
  nativeFunctionCalling,
}

/// قواعد ثابت پروتکل ابزار: چه چیزی به مدل گفته می‌شود و نتیجهٔ اجرای ابزار
/// چطور به او برگردانده می‌شود.
///
/// این کلاس عمداً هیچ وابستگی‌ای به UI، شبکه و دیتابیس ندارد تا مستقیماً
/// قابل تست واحد باشد.
class AgentToolProtocol {
  const AgentToolProtocol._();

  /// سقف طول JSON دادهٔ هر ابزار که به مدل برگردانده می‌شود
  static const int maxResultChars = 1500;

  /// انتخاب فرمت سیمی بر اساس توان مسیر انتقال
  static AgentToolWireFormat formatFor({required bool supportsNativeTools}) {
    return supportsNativeTools
        ? AgentToolWireFormat.nativeFunctionCalling
        : AgentToolWireFormat.xmlInline;
  }

  /// قواعد حلقه که در انتهای پرامپت سیستمی تزریق می‌شود.
  /// بدون این بلوک، مدل یا هیچ ابزاری صدا نمی‌زند یا بعد از فراخوانی، خودش
  /// جواب ابزار را از خودش می‌سازد.
  static String loopInstructions({
    required int maxTurns,
    required int maxToolCallsPerTurn,
  }) {
    final b = StringBuffer();
    b.writeln('\n=== [قواعد حلقهٔ اجرای ابزار] ===');
    b.writeln(
        '۱) اگر برای پاسخ دقیق به داده نیاز داری، ابزار را صدا بزن و منتظر نتیجه بمان. هیچ عدد، تاریخ، نام روتین یا آماری را از خودت نساز.');
    b.writeln(
        '۲) در هر نوبت حداکثر $maxToolCallsPerTurn فراخوانی مجاز است و کل این گفت‌وگو حداکثر $maxTurns نوبت دارد.');
    b.writeln(
        '۳) بعد از بستن تگ </tool_call> دیگر چیزی ننویس و همان‌جا پاسخ را تمام کن؛ نتیجهٔ واقعی ابزار در پیام بعدی به تو داده می‌شود و آن‌وقت پاسخ نهایی را می‌نویسی.');
    b.writeln(
        '۴) یک ابزار را با پارامترهای یکسان دو بار صدا نزن؛ از نتیجهٔ قبلی استفاده کن.');
    b.writeln(
        '۵) اگر ابزاری خطا داد یا داده‌ای نداشت، صادقانه بگو در دسترس نیست و جایگزین پیشنهاد بده. حدس زدن ممنوع است.');
    b.writeln(
        '۶) در پاسخ نهایی هیچ تگ <tool_call> و هیچ JSON خامی نگذار؛ فقط متن فارسی طبیعی و در صورت نیاز تگ‌های <actions> و <memory_ops>.');
    b.writeln(
        '۷) اگر پیش از فراخوانی ابزار جمله‌ای نوشته‌ای، آن جمله همان لحظه به کاربر نمایش داده شده است؛ در ادامه آن را تکرار نکن و از همان‌جا ادامه بده.');
    return b.toString();
  }

  /// بلوکی که نتیجهٔ اجرای ابزارها را به مدل برمی‌گرداند (نوبت بعدی حلقه)
  static String toolResultsBlock(
    List<AgentToolResult> results, {
    required bool noMoreTools,
  }) {
    final b = StringBuffer();
    b.writeln(
        '[نتیجهٔ اجرای ابزارها — این داده واقعی است و همین لحظه از دیتابیس همین کاربر خوانده شده]:');

    if (results.isEmpty) {
      b.writeln('• هیچ ابزاری اجرا نشد.');
    }

    for (final r in results) {
      if (r.isSuccess) {
        b.writeln('• ${r.toolName} ✅ ${r.summaryFa}');
        if (r.data != null) {
          b.writeln('  داده: ${encodeData(r.data)}');
        }
      } else {
        b.writeln('• ${r.toolName} ❌ خطا: ${r.errorMessage}');
      }
    }

    if (results.any((r) => !r.isSuccess)) {
      b.writeln(
          'دربارهٔ ابزارهای خطادار هیچ عدد یا واقعیتی نساز؛ صادقانه بگو این بخش داده در دسترس نیست.');
    }

    if (noMoreTools) {
      b.writeln(
          'توجه: سقف فراخوانی ابزار در این پیام تمام شد. دیگر <tool_call> نفرست و فقط با همین داده‌ها پاسخ نهایی فارسی را بنویس.');
    } else {
      b.writeln(
          'اگر داده کافی است پاسخ نهایی را بنویس؛ فقط اگر واقعاً به دادهٔ دیگری نیاز داری یک <tool_call> دیگر بفرست.');
    }

    return b.toString();
  }

  /// یادآوری ابزارهایی که پیش‌واکشی خودکار همین حالا اجرا کرده است
  static String prefetchedToolsNote(List<AgentToolResult> results) {
    if (results.isEmpty) return '';
    final names = results.map((r) => r.toolName).toSet().join('، ');
    return '\n[این ابزارها همین حالا به‌صورت خودکار اجرا شده‌اند و داده‌شان در بالا آمده است: $names. آن‌ها را با همان پارامترها دوباره صدا نزن.]';
  }

  /// پاسخ اضطراری و قطعی، ساخته‌شده تنها از خلاصهٔ ابزارهای موفق.
  ///
  /// وقتی مدل در میانهٔ حلقه قطع شود، بدون این تابع کاربر پیام «هیچ پاسخی
  /// دریافت نشد» می‌گیرد در حالی که داده‌های واقعی خوانده شده‌اند. اینجا هیچ
  /// عددی ساخته نمی‌شود؛ فقط summaryFa ابزارها بازگو می‌شود.
  static String fallbackAnswerFromResults(List<AgentToolResult> results) {
    final ok = results.where((r) => r.isSuccess).toList();
    if (ok.isEmpty) {
      return 'الان نتوانستم پاسخ را کامل کنم و ابزارهای موردنیاز هم داده‌ای برنگرداندند. ترجیح می‌دهم چیزی از خودم نسازم؛ لطفاً یک بار دیگر بپرس.';
    }

    final b = StringBuffer();
    b.writeln(
        'ارتباط با مدل زبانی در میانهٔ کار قطع شد، اما این داده‌ها را از برنامه‌ات خواندم:');
    for (final r in ok) {
      b.writeln('• ${r.summaryFa}');
    }
    b.writeln(
        '\nاگر می‌خواهی روی همین‌ها تحلیل و پیشنهاد بدهم، یک بار دیگر بپرس.');
    return b.toString();
  }

  /// سریال‌سازی دادهٔ ابزار به JSON خوانا برای مدل، با سقف طول
  static String encodeData(dynamic data, {int maxChars = maxResultChars}) {
    String text;
    try {
      text = jsonEncode(data);
    } catch (_) {
      text = data.toString();
    }
    if (text.length > maxChars) {
      return '${text.substring(0, maxChars)}… [بریده‌شده]';
    }
    return text;
  }
}
