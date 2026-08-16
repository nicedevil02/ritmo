import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:ritmo/core/ai/agent/agent_event.dart';
import 'package:ritmo/core/ai/agent/agent_intent_prefetcher.dart';
import 'package:ritmo/core/ai/agent/agent_tool_registry.dart';
import 'package:ritmo/core/ai/ai_connection_repository.dart';
import 'package:ritmo/core/ai/ai_connection_models.dart';
import 'package:ritmo/core/ai/ai_gateway.dart';
import 'package:ritmo/core/ai/ai_prompt_engine.dart';
import 'package:ritmo/core/ai/web_bridge/chatgpt_web_bridge_manager.dart';

/// موتور اجرای چرخه چندمرحله‌ای و تعاملی ایجنت (Agent Loop Runner)
class AgentLoopRunner {
  AgentLoopRunner._();
  static final AgentLoopRunner instance = AgentLoopRunner._();

  /// اجرای درخواست کاربر در قالب چرخه ایجنت و انتشار رویدادهای زنده
  Stream<AgentEvent> runAgent({
    required String prompt,
    String? personaTitle,
    String? personaSystemPrompt,
    String? contextSummary,
    List<String>? recentHistory,
    AiSlot slot = AiSlot.assistant,
  }) async* {
    final steps = <AgentStep>[];

    // ۱. مرحله اول: پیش‌واکشی سریع داده‌ها و نیت‌شناسی
    yield const AgentStatusChangedEvent(
      statusTextFa: 'در حال تحلیل نیت و بررسی ابزارهای موردنیاز...',
      isWorking: true,
    );

    final prefetch = await AgentIntentPrefetcher.prefetchForQuery(prompt);
    if (prefetch.initialSteps.isNotEmpty) {
      for (final step in prefetch.initialSteps) {
        steps.add(step);
        yield AgentStepStartedEvent(step);
        yield AgentStepCompletedEvent(step);
      }
    }

    // ۲. آماده‌سازی پرامپت ابزارها و داده‌های زنده
    final toolsPrompt = AgentToolRegistry.instance.generateSystemToolsPrompt();
    final combinedSystemPrompt = StringBuffer();

    if (personaSystemPrompt != null && personaSystemPrompt.isNotEmpty) {
      combinedSystemPrompt.writeln(personaSystemPrompt);
    } else {
      combinedSystemPrompt.writeln(AIPromptEngine.buildChatSystemPrompt());
    }

    combinedSystemPrompt.writeln('\n$toolsPrompt');

    if (prefetch.formattedContextBlock.isNotEmpty) {
      combinedSystemPrompt.writeln(prefetch.formattedContextBlock);
    }

    // ۳. ارسال درخواست به هوش مصنوعی و پایش استریم
    yield const AgentStatusChangedEvent(
      statusTextFa: 'در حال نگارش و تحلیل پاسخ نهایی...',
      isWorking: true,
    );

    final config = await AiConnectionRepository.instance.load(slot: slot);
    final isChatGptWeb = config.providerPresetId == 'chatgpt_web' || config.baseUrl.contains('chatgpt.com');

    final Stream<String> rawStream;
    if (isChatGptWeb) {
      rawStream = ChatGptWebBridgeManager.instance.sendPrompt(
        prompt: prompt,
        personaTitle: personaTitle,
        personaSystemPrompt: combinedSystemPrompt.toString(),
        contextSummary: contextSummary,
        recentHistory: recentHistory,
      );
    } else {
      final messages = <Map<String, String>>[
        {'role': 'system', 'content': combinedSystemPrompt.toString()},
        if (recentHistory != null)
          ...recentHistory.map((h) => {'role': 'user', 'content': h}),
        {'role': 'user', 'content': prompt},
      ];
      rawStream = AIGateway.instance.sendCustomChatStream(
        messages: messages,
        slot: slot,
      );
    }

    var accumulatedText = '';
    Map<String, dynamic>? interactiveAction;

    await for (final chunk in rawStream) {
      if (chunk.startsWith('error:')) {
        yield AgentErrorEvent(chunk.substring(6));
        return;
      }

      accumulatedText += chunk;

      // فیلتر کردن تگ‌های ابزار از متن نهایی نمایشی
      final cleanDisplay = _cleanDisplayText(accumulatedText);
      yield AgentTokenStreamEvent(
        delta: chunk,
        accumulated: cleanDisplay,
      );
    }

    // ۴. بررسی وجود اکشن‌های تعاملی یا تگ‌های actions در انتهای متن
    final actionMatch = RegExp(r'<actions>([\s\S]*?)<\/actions>').firstMatch(accumulatedText);
    if (actionMatch != null) {
      try {
        final actionJson = jsonDecode(actionMatch.group(1)!.trim());
        if (actionJson is List && actionJson.isNotEmpty) {
          interactiveAction = actionJson.first as Map<String, dynamic>;
        }
      } catch (_) {}
    }

    final finalCleanAnswer = _cleanDisplayText(accumulatedText);

    yield const AgentStatusChangedEvent(
      statusTextFa: 'پاسخ آماده است.',
      isWorking: false,
    );

    yield AgentCompletedEvent(
      finalAnswer: finalCleanAnswer,
      steps: steps,
      interactiveAction: interactiveAction,
    );
  }

  String _cleanDisplayText(String raw) {
    var text = raw;
    text = text.replaceAll(RegExp(r'<tool_call>[\s\S]*?<\/tool_call>'), '');
    text = text.replaceAll(RegExp(r'<actions>[\s\S]*?<\/actions>'), '');
    text = text.replaceAll(RegExp(r'<memory_ops>[\s\S]*?<\/memory_ops>'), '');
    return text.trim();
  }
}
