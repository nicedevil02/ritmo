import 'package:flutter/foundation.dart';
import 'package:ritmo/core/ai/agent/agent_tool.dart';

/// رجیستری مرکزی و مدیریت ابزارهای هوش مصنوعی ریتمو
class AgentToolRegistry {
  AgentToolRegistry._();
  static final AgentToolRegistry instance = AgentToolRegistry._();

  final Map<String, AgentTool> _tools = {};

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

  /// اجرای امن یک ابزار
  Future<AgentToolResult> executeTool(String name, Map<String, dynamic> args) async {
    final tool = _tools[name];
    if (tool == null) {
      return AgentToolResult.failure(
        toolName: name,
        errorMessage: 'ابزار مورد نظر با نام "$name" در سیستم یافت نشد.',
      );
    }

    try {
      debugPrint('[AgentToolRegistry] Executing tool: $name with args: $args');
      final result = await tool.execute(args);
      return result;
    } catch (e, st) {
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
    buffer.writeln('شما به عنوان یک ایجنت خودمختار می‌توانید برای پاسخ‌گویی دقیق یا انجام درخواست‌های کاربر از ابزارهای زیر استفاده کنید.');
    buffer.writeln('برای فراخوانی هر ابزار، از فرمت زیر در یک بلوک مشخص استفاده کنید:');
    buffer.writeln('<tool_call>');
    buffer.writeln('{"tool": "نام_ابزار", "parameters": {"پارامتر۱": "مقدار"}}');
    buffer.writeln('</tool_call>');
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
}
