import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:ritmo/core/logging/ritmo_logger.dart';
import 'package:ritmo/core/ai/ai_connection_models.dart';
import 'package:ritmo/core/ai/ai_connection_repository.dart';
import 'package:ritmo/core/ai/ai_context_builder.dart';
import 'package:ritmo/core/ai/ai_gateway.dart';
import 'package:ritmo/core/ai/ai_prompt_engine.dart';
import 'package:ritmo/core/ai/chat/chat_action_parser.dart';
import 'package:ritmo/core/ai/chat/chat_models.dart';
import 'package:ritmo/core/ai/chat/chat_repository.dart';
import 'package:ritmo/core/ai/chat/chat_session_summarizer.dart';
import 'package:ritmo/core/ai/chat/conversation_context_builder.dart';
import 'package:ritmo/core/ai/chat/conversation_rag.dart';
import 'package:ritmo/core/ai/memory/ai_memory_service.dart';
import 'package:ritmo/core/ai/memory/memory_consolidator.dart';
import 'package:ritmo/core/ai/memory/memory_models.dart';
import 'package:ritmo/core/ai/agent/agent_event.dart';
import 'package:ritmo/core/ai/agent/agent_loop_runner.dart';
import 'package:ritmo/core/ai/web_bridge/chatgpt_web_bridge_manager.dart';

class StreamingChatService {
  /// A-25: سقف مجاز برای طول پاسخ دستیار به کاراکتر/گرافم (۳۲۰۰۰ کاراکتر)
  static const int maxAssistantResponseChars = 32000;

  Stream<StreamingChatEvent> send({
    required String sessionId,
    required String userText,
    required ConsentProfile consent,
  }) async* {
    // 1) Retrieve RAG & Privacy check
    final rag = await ConversationRAG().retrieve(query: userText, consent: consent);

    // 2) Save user message
    final userMsg = ChatMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(99999)}',
      sessionId: sessionId,
      role: ChatRole.user,
      content: userText,
      timestamp: DateTime.now(),
    );
    await ChatRepository.instance.addMessage(userMsg);
    yield UserMessageSaved(userMsg);

    // 3) If blocked, return early with block message
    if (rag.blocked) {
      final assistantMsg = ChatMessage(
        id: 'msg_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(99999)}',
        sessionId: sessionId,
        role: ChatRole.assistant,
        content: rag.blockMessage!,
        timestamp: DateTime.now(),
      );
      await ChatRepository.instance.addMessage(assistantMsg);
      
      final dbMsgs = await ChatRepository.instance.getMessages(sessionId);
      if (dbMsgs.isNotEmpty) {
        final summary = ChatSessionSummarizer.summarize(
          firstUserMessage: dbMsgs.first.content,
          messageCount: dbMsgs.length,
        );
        await ChatRepository.instance.updateSessionSummary(sessionId, summary);
      }
      
      yield ChatComplete(assistantMsg.id, assistantMsg.content, const []);
      return;
    }

    // 4) Build Context
    final ctx = await ConversationContextBuilder().build(
      sessionId: sessionId,
      userText: userText,
      retrievedData: rag.data,
    );

    final messages = ctx.toMessages(
      AIPromptEngine.buildChatSystemPrompt() + AiMemoryService.memoryInstruction(),
      userText,
    );

    // 5) Start streaming
    final assistantId = 'msg_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(99999)}';
    yield AssistantStarted(assistantId);

    var accumulated = '';
    // متن خام مدل برای استخراج actions و memory_ops (P0-3)
    var rawAnswer = '';
    var hasError = false;
    var errorCode = '';

    final config = await AiConnectionRepository.instance.load(slot: AiSlot.assistant);
    final isChatGptWeb = config.providerPresetId == 'chatgpt_web' || config.baseUrl.contains('chatgpt.com');

    // P0-4: مسیر ایجنت برای تمام ارائه‌دهنده‌ها فعال است.
    try {
      final contextLines = <String>[];
      if (rag.data.isNotEmpty) {
        rag.data.forEach((key, value) {
          contextLines.add('- $key: $value');
        });
      }

      final nonSystem = messages.where((msg) => msg['role'] != 'system').toList();
      if (nonSystem.isNotEmpty &&
          nonSystem.last['role'] == 'user' &&
          (nonSystem.last['content'] ?? '') == userText) {
        nonSystem.removeLast();
      }

      final recentHistory = <String>[];
      for (final m in nonSystem.reversed.take(4).toList().reversed) {
        final role = m['role'];
        final content = m['content'] ?? '';
        final roleLabel = role == 'user' ? 'کاربر' : 'دستیار';
        recentHistory.add('$roleLabel: $content');
      }

      final systemPrompt = AIPromptEngine.buildChatSystemPrompt() + AiMemoryService.memoryInstruction();
      final agentStream = AgentLoopRunner.instance.runAgent(
        prompt: userText,
        personaId: 'global',
        personaSystemPrompt: systemPrompt,
        contextSummary: contextLines.isNotEmpty ? contextLines.join('\n') : null,
        recentHistory: recentHistory.isNotEmpty ? recentHistory : null,
        slot: AiSlot.assistant,
      );

      await for (final event in agentStream) {
        if (event is AgentTokenStreamEvent) {
          accumulated = event.accumulated;
          if (accumulated.characters.length > maxAssistantResponseChars) {
            accumulated = accumulated.characters.take(maxAssistantResponseChars).toString();
            if (isChatGptWeb) {
              ChatGptWebBridgeManager.instance.cancelCurrentStream();
            }
            yield ChatChunk('\n\n[پاسخ بیش از حد طولانی بود و کوتاه شد.]', accumulated);
            break;
          }
          yield ChatChunk(event.delta, accumulated);
        } else if (event is AgentCompletedEvent) {
          rawAnswer = event.rawAnswer;
          final finalText = event.finalAnswer;
          if (finalText.isNotEmpty) {
            final capped = finalText.characters.length > maxAssistantResponseChars
                ? finalText.characters.take(maxAssistantResponseChars).toString()
                : finalText;
            if (capped != accumulated) {
              accumulated = capped;
              yield ChatChunk('', accumulated);
            }
          }
          yield AgentStreamEvent(event);
        } else if (event is AgentErrorEvent) {
          hasError = true;
          errorCode = event.errorMessageFa;
          yield AgentStreamEvent(event);
          break;
        } else {
          // A-19: پیش‌فرض — هر رویداد دیگری (AgentDisplayResetEvent، AgentAwaitingQuestionEvent،
          // AgentQuestionResolvedEvent، و هر زیرکلاس جدید AgentEvent) به UI عبور داده می‌شود.
          yield AgentStreamEvent(event);
        }
      }
    } catch (e, st) {
      hasError = true;
      errorCode = e.toString();
      RitmoLog.error('StreamingChatService', 'Error in agent execution stream: $e', e, st);
    }

    // Fallback: فقط وقتی ایجنت خطا داد و هیچ متنی تولید نشد و ارائه‌دهنده پل وب نیست، مسیر مستقیم گیت‌وی.
    if (hasError && accumulated.isEmpty && !isChatGptWeb) {
      RitmoLog.warning('StreamingChatService', 'Falling back to plain gateway stream. Reason: $errorCode');
      hasError = false;
      errorCode = '';
      try {
        await for (final chunk in AIGateway.instance.sendStreamingCompletion(
          messages: messages,
          slot: AiSlot.assistant,
        )) {
          if (chunk.startsWith('error:')) {
            hasError = true;
            errorCode = chunk.substring(6);
            break;
          }
          accumulated += chunk;
          if (accumulated.characters.length > maxAssistantResponseChars) {
            accumulated = accumulated.characters.take(maxAssistantResponseChars).toString();
            yield ChatChunk('\n\n[پاسخ بیش از حد طولانی بود و کوتاه شد.]', accumulated);
            break;
          }
          yield ChatChunk(chunk, accumulated);
        }
      } catch (e, st) {
        hasError = true;
        errorCode = e.toString();
        RitmoLog.error('StreamingChatService', 'Error in gateway fallback stream: $e', e, st);
      }
    }

    if (hasError) {
      yield ChatErrorEvent(errorCode, accumulated);
      return;
    }

    // A-22: علت تشخیصی در صورت خالی بودن پاسخ
    if (accumulated.trim().isEmpty) {
      final reason = ChatGptWebBridgeManager.instance.describeEmptyResponseReason();
      RitmoLog.error('StreamingChatService', 'empty response: ${reason.technicalDetail}');
      yield ChatErrorEvent(reason.messageFa, reason.technicalDetail);
      return;
    }

    // 6) Parse Actions & Save assistant message
    // P0-3: پارس از متن خام انجام می‌شود، نه متنی که تگ‌هایش قبلاً حذف شده.
    final parseSource = rawAnswer.trim().isNotEmpty ? rawAnswer : accumulated;
    final parsed = ChatActionParser.parse(parseSource);

    // Process memory operations from AI response
    if (parsed.memoryOps != null && parsed.memoryOps!.isNotEmpty) {
      try {
        final decoded = jsonDecode(parsed.memoryOps!);
        if (decoded is List) {
          final ops = <MemoryOp>[];
          for (final item in decoded) {
            if (item is Map) {
              ops.add(MemoryOp.fromJson(item.cast<String, dynamic>()));
            }
          }
          if (ops.isNotEmpty) {
            await AiMemoryService.instance.applyOperations(ops);
          }
        }
      } catch (e, st) {
        RitmoLog.error('StreamingChatService', 'Error processing assistant memory_ops JSON: $e', e, st);
      }
    }

    var finalText =
        parsed.cleanText.trim().isNotEmpty ? parsed.cleanText : accumulated;
    if (finalText.characters.length > maxAssistantResponseChars) {
      finalText = finalText.characters.take(maxAssistantResponseChars).toString();
    }

    // Run explicit remember safety net
    await AiMemoryService.instance.processExplicitSafetyNet(
      userText: userText,
      assistantResponse: finalText,
      domain: 'core',
      sessionId: sessionId,
    );

    final assistantMsg = ChatMessage(
      id: assistantId,
      sessionId: sessionId,
      role: ChatRole.assistant,
      content: finalText,
      timestamp: DateTime.now(),
      actions: parsed.actions,
    );
    await ChatRepository.instance.addMessage(assistantMsg);

    // 7) Update summary
    final dbMsgs = await ChatRepository.instance.getMessages(sessionId);
    if (dbMsgs.isNotEmpty) {
      final summary = ChatSessionSummarizer.summarize(
        firstUserMessage: dbMsgs.first.content,
        messageCount: dbMsgs.length,
      );
      await ChatRepository.instance.updateSessionSummary(sessionId, summary);
    }

    // Trigger memory consolidation for this session (fire-and-forget)
    unawaited(MemoryConsolidator.consolidateSession(sessionId, 'core'));

    final isPartial = isChatGptWeb && ChatGptWebBridgeManager.instance.lastAnswerWasPartial;
    yield ChatComplete(assistantId, finalText, parsed.actions, isPartial: isPartial);
  }
}
