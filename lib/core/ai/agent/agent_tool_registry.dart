import 'package:flutter/foundation.dart';
import 'package:ritmo/core/ai/agent/agent_tool.dart';

/// آمار و تلمتری اجرای هر ابزار
class AgentToolMetrics {
  AgentToolMetrics({
    required this.toolName,
    this.callCount = 0,
    this.successCount = 0,
    this.failureCount = 0,
    this.totalDurationMs = 0,
  });

  final String toolName;
  int callCount;
  int successCount;
  int failureCount;
  int totalDurationMs;

  double get averageDurationMs =>
      callCount == 0 ? 0 : totalDurationMs / callCount;

  double get successRate =>
      callCount == 0 ? 1.0 : successCount / callCount;

  Map<String, dynamic> toJson() => {
        'toolName': toolName,
        'callCount': callCount,
        'successCount': successCount,
        'failureCount': failureCount,
        'totalDurationMs': totalDurationMs,
        'averageDurationMs': averageDurationMs,
        'successRate': successRate,
      };
}

/// رجیستری مرکزی و مدیریت ابزارهای هوش مصنوعی ریتمو
class AgentToolRegistry {
  AgentToolRegistry._();
  static final AgentToolRegistry instance = AgentToolRegistry._();

  final Map<String, AgentTool> _tools = {};
  final Map<String, AgentToolMetrics> _metrics = {};

  /// ثبت یک ابزار در سیستم
  void register(AgentTool tool) {
    if (_tools.containsKey(tool.name)) {
      debugPrint('[AgentToolRegistry] Warning: Overwriting tool "${tool.name}"');
    }
    _tools[tool.name] = tool;
  }

  /// ثبت دسته‌ای از ابزارها
  void registerAll(List<AgentTool> tools) {
    for (final t in tools) {
      register(t);
    }
  }

  /// دریافت یک ابزار با نام
  AgentTool? getTool(String name) => _tools[name];

  /// دریافت تمامی ابزارهای ثبت‌شده
  List<AgentTool> get allTools => _tools.values.toList();

  /// تعداد کل ابزارها
  int get count => _tools.length;

  /// بررسی وجود ابزار
  bool hasTool(String name) => _tools.containsKey(name);

  /// دریافت تلمتری یک ابزار
  AgentToolMetrics getMetrics(String toolName) =>
      _metrics.putIfAbsent(toolName, () => AgentToolMetrics(toolName: toolName));

  /// دریافت تمامی متریک‌های ثبت‌شده
  Map<String, AgentToolMetrics> get allMetrics => Map.unmodifiable(_metrics);

  /// ریست کردن آمارها
  void resetMetrics() => _metrics.clear();

  /// اجرای امن یک ابزار به همراه ثبت تلمتری
  Future<AgentToolResult> executeTool(String name, Map<String, dynamic> args) async {
    final tool = _tools[name];
    if (tool == null) {
      return AgentToolResult.failure(
        toolName: name,
        errorMessage: 'ابزار مورد نظر با نام "$name" در سیستم یافت نشد.',
      );
    }

    final stopwatch = Stopwatch()..start();
    final metric = getMetrics(name);
    metric.callCount++;

    try {
      debugPrint('[AgentToolRegistry] Executing tool: $name with args: ${_redactArgs(args)}');
      final result = await tool.execute(args);
      stopwatch.stop();
      metric.totalDurationMs += stopwatch.elapsedMilliseconds;
      if (result.isSuccess) {
        metric.successCount++;
      } else {
        metric.failureCount++;
      }
      return result;
    } catch (e, st) {
      stopwatch.stop();
      metric.totalDurationMs += stopwatch.elapsedMilliseconds;
      metric.failureCount++;
      debugPrint('[AgentToolRegistry] Error executing tool $name: $e\n$st');
      return AgentToolResult.failure(
        toolName: name,
        errorMessage: 'خطای سیستمی در اجرای ابزار $name: $e',
      );
    }
  }

  /// تولید بلوک راهنمای ابزارها برای تزریق به پرامپت مدل
  String generateSystemToolsPrompt() {
    final buffer = StringBuffer();
    buffer.writeln('=== [ابزارهای عملیاتی در دسترس دستیار ریتمو] ===');
    buffer.writeln('شما یک ایجنت خودمختار و متصل به دیتابیس ریتمو هستید. هر زمان کاربر درخواست انجام عملیات (مانند ساخت روتین، ثبت ورزش، ایجاد هدف، ثبت یادداشت، بررسی وضعیت یا تغییر تنظیمات) دارد یا با پیشنهاد قبلی شما (با کلماتی مثل «آره بساز»، «ثبت کن»، «انجام بده»، «آره»، «تایید می‌کنم») موافقت می‌کند، شما موظفید حتماً و بلافاصله تگ <tool_call> مربوطه را صادر کنید.');
    buffer.writeln('فرمت فراخوانی هر ابزار:');
    buffer.writeln('<tool_call>');
    buffer.writeln('{"tool": "نام_ابزار", "parameters": {"پارامتر۱": "مقدار"}}');
    buffer.writeln('</tool_call>');
    buffer.writeln('⚠️ دستور قطعی: هرگز بدون درج تگ <tool_call> ادعا نکنید که کاری ثبت شده یا در حال ثبت است. ثبت واقعی فقط با صدور تگ <tool_call> انجام می‌شود.');
    buffer.writeln('\nلیست ابزارهای موجود:');

    // Group by category
    final grouped = <String, List<AgentTool>>{};
    for (final t in _tools.values) {
      grouped.putIfAbsent(t.categoryFa, () => []).add(t);
    }

    grouped.forEach((category, list) {
      buffer.writeln('\n📂 دسته: $category');
      for (final tool in list) {
        buffer.writeln(tool.toPromptDescription());
      }
    });

    return buffer.toString();
  }

  static Map<String, dynamic> _redactArgs(Map<String, dynamic> args) {
    final clean = <String, dynamic>{};
    for (final entry in args.entries) {
      final k = entry.key.toLowerCase();
      if (k.contains('password') || k.contains('token') || k.contains('secret')) {
        clean[entry.key] = '***';
      } else if ((k.contains('content') || k.contains('note') || k.contains('text')) &&
          entry.value is String &&
          (entry.value as String).length > 25) {
        clean[entry.key] = '${(entry.value as String).substring(0, 25)}…';
      } else {
        clean[entry.key] = entry.value;
      }
    }
    return clean;
  }
}
