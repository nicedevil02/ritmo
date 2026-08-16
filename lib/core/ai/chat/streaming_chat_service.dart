import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
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
import 'package:ritmo/core/ai/web_bridge/chatgpt_web_bridge_manager.dart';

class StreamingChatService {
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
    const cap = 2000;
    var hasError = false;
    var errorCode = '';

    final config = await AiConnectionRepository.instance.load(slot: AiSlot.assistant);
    final isChatGptWeb = config.providerPresetId == 'chatgpt_web' || config.baseUrl.contains('chatgpt.com');

    if (isChatGptWeb) {
      try {
        final contextLines = <String>[];
        if (rag.data.isNotEmpty) {
          rag.data.forEach((key, value) {
            contextLines.add('- $key: $value');
          });
        }
        final recentHistory = <String>[];
        final chatHistoryList = messages.where((msg) => msg['role'] != 'system').toList();
        for (final m in chatHistoryList.reversed.take(4).toList().reversed) {
          final role = m['role'];
          final content = m['content'] ?? '';
          final roleLabel = role == 'user' ? 'کاربر' : 'دستیار';
          recentHistory.add('$roleLabel: $content');
        }

        final systemPrompt = AIPromptEngine.buildChatSystemPrompt() + AiMemoryService.memoryInstruction();
        await for (final chunk in ChatGptWebBridgeManager.instance.sendPrompt(
          prompt: userText,
          personaSystemPrompt: systemPrompt,
          contextSummary: contextLines.isNotEmpty ? contextLines.join('\n') : null,
          recentHistory: recentHistory.isNotEmpty ? recentHistory : null,
        )) {
          if (chunk.startsWith('error:')) {
            hasError = true;
            errorCode = chunk.substring(6);
            break;
          }
          accumulated += chunk;
          if (accumulated.length > cap) {
            accumulated = accumulated.substring(0, cap);
            ChatGptWebBridgeManager.instance.cancelCurrentStream();
            yield ChatChunk('', accumulated);
            break;
          }
          yield ChatChunk(chunk, accumulated);
        }
      } catch (e) {
        hasError = true;
        errorCode = e.toString();
      }
    }

    // Fallback or Standard API Gateway Stream
    if (!isChatGptWeb || (hasError && accumulated.isEmpty)) {
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
          if (accumulated.length > cap) {
            accumulated = accumulated.substring(0, cap);
            yield ChatChunk('', accumulated);
            break;
          }
          yield ChatChunk(chunk, accumulated);
        }
      } catch (e) {
        hasError = true;
        errorCode = e.toString();
      }
    }

    if (hasError) {
      yield ChatErrorEvent(errorCode, accumulated);
      return;
    }

    if (accumulated.trim().isEmpty) {
      yield ChatErrorEvent('هیچ پاسخی از هوش مصنوعی دریافت نشد.', '');
      return;
    }

    // 6) Parse Actions & Save assistant message
    final parsed = ChatActionParser.parse(accumulated);

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
      } catch (e) {
        debugPrint('[MEMORY] Error processing assistant memory_ops JSON: $e');
      }
    }

    // Run explicit remember safety net
    await AiMemoryService.instance.processExplicitSafetyNet(
      userText: userText,
      assistantResponse: accumulated,
      domain: 'core',
      sessionId: sessionId,
    );

    final assistantMsg = ChatMessage(
      id: assistantId,
      sessionId: sessionId,
      role: ChatRole.assistant,
      content: parsed.cleanText,
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

    yield ChatComplete(assistantId, parsed.cleanText, parsed.actions);
  }
}
