import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:ritmo/core/ai/agent/agent_budget.dart';
import 'package:ritmo/core/ai/agent/agent_event.dart';
import 'package:ritmo/core/ai/agent/agent_intent_prefetcher.dart';
import 'package:ritmo/core/ai/agent/agent_tool.dart';
import 'package:ritmo/core/ai/agent/agent_tool_call_parser.dart';
import 'package:ritmo/core/ai/agent/agent_tool_protocol.dart';
import 'package:ritmo/core/ai/agent/agent_tool_registry.dart';
import 'package:ritmo/core/ai/agent/agent_transcript.dart';
import 'package:ritmo/core/ai/ai_connection_models.dart';
import 'package:ritmo/core/ai/ai_connection_repository.dart';
import 'package:ritmo/core/ai/ai_gateway.dart';
import 'package:ritmo/core/ai/ai_prompt_engine.dart';
import 'package:ritmo/core/ai/web_bridge/chatgpt_web_bridge_manager.dart';

/// حلقهٔ واقعی ReAct ایجنت ریتمو (فاز ۱)
///
/// جریان: پیش‌واکشی → نوبت مدل → پارس tool_call → اجرای ابزار → بازگرداندن
/// نتیجه به مدل → تکرار تا پاسخ نهایی یا پایان بودجه.
///
/// در نسخهٔ قبلی فراخوانی‌های مدل فقط از متن حذف می‌شدند (یک رفت و تمام)،
/// پس ایجنت در عمل فقط یک چت بود.
class AgentLoopRunner {
  AgentLoopRunner._();

  static final AgentLoopRunner instance = AgentLoopRunner._();

  /// سقف متن خام یک نوبت (محافظ مدل‌های پرگو)
  static const int _maxRawCharsPerTurn = 20000;

  /// اگر مدل پس از بستن tool_call بیش از این مقدار نوشت، استریم قطع می‌شود
  /// تا نتیجهٔ خیالی ابزار را نسازد.
  static const int _tailCutoffAfterToolCall = 220;

  Stream<AgentEvent> runAgent({
    required String prompt,
    String? personaTitle,
    String? personaSystemPrompt,
    String? contextSummary,
    List<String>? recentHistory,
    AiSlot slot = AiSlot.assistant,
  }) async* {
    final budget = AgentBudget();
    final steps = <AgentStep>[];
    final allResults = <AgentToolResult>[];

    yield AgentStatusChangedEvent(
      statusTextFa: 'در حال تحلیل نیت و بررسی ابزارهای موردنیاز...',
      isWorking: true,
    );

    // ۱. پیش‌واکشی قطعی (مستقل از تصمیم مدل) تا مدل با دادهٔ واقعی شروع کند
    final prefetch = await AgentIntentPrefetcher.prefetchForQuery(prompt);
    for (final step in prefetch.initialSteps) {
      steps.add(step);
      yield AgentStepStartedEvent(step);
      yield AgentStepCompletedEvent(step);
    }
    allResults.addAll(prefetch.toolResults);

    // ۲. پرامپت سیستمی: پرسونا + فهرست ابزار + قواعد حلقه + دادهٔ زنده
    final system = StringBuffer();
    if (personaSystemPrompt != null && personaSystemPrompt.trim().isNotEmpty) {
      system.writeln(personaSystemPrompt);
    } else {
      system.writeln(AIPromptEngine.buildChatSystemPrompt());
    }
    system.writeln(
        '\n${AgentToolRegistry.instance.generateSystemToolsPrompt()}');
    system.writeln(AgentToolProtocol.loopInstructions(
      maxTurns: budget.maxTurns,
      maxToolCallsPerTurn: budget.maxToolCallsPerTurn,
    ));
    if (prefetch.formattedContextBlock.trim().isNotEmpty) {
      system.writeln(prefetch.formattedContextBlock);
      system
          .writeln(AgentToolProtocol.prefetchedToolsNote(prefetch.toolResults));
    }
    if (contextSummary != null && contextSummary.trim().isNotEmpty) {
      system.writeln(
          '\n[خلاصه داده‌های بازیابی‌شده از پروفایل و تاریخچه کاربر]:');
      system.writeln(contextSummary.trim());
    }
    final systemPrompt = system.toString();

    // ۳. مسیر انتقال
    final config = await AiConnectionRepository.instance.load(slot: slot);
    final isChatGptWeb = config.providerPresetId == 'chatgpt_web' ||
        config.baseUrl.contains('chatgpt.com');
    final wireFormat =
        AgentToolProtocol.formatFor(supportsNativeTools: false);
    debugPrint(
        '[Agent] loop start | web=$isChatGptWeb | wire=${wireFormat.name} | tools=${AgentToolRegistry.instance.count}');

    final transcript = AgentTranscript(systemPrompt: systemPrompt);
    if (recentHistory != null && recentHistory.isNotEmpty) {
      transcript.addHistory(_historyToMessages(recentHistory));
    }
    transcript.addUser(prompt);

    // متن پاسخ‌ها با حفظ تگ‌های actions/memory_ops و بدون tool_call
    var rawBuffer = '';
    var displayed = '';
    var stopNoteFa = '';
    String? pendingFollowUp;
    Map<String, dynamic>? interactiveAction;

    for (var turn = 1; turn <= budget.maxTurns; turn++) {
      budget.countTurn();
      final noMoreTools = turn >= budget.maxTurns ||
          !budget.canRunMoreTools ||
          budget.isTimedOut;

      final followUp = pendingFollowUp ?? '';
      if (turn > 1 && followUp.trim().isEmpty) break;

      yield AgentStatusChangedEvent(
        statusTextFa: turn == 1
            ? 'در حال نگارش و تحلیل پاسخ نهایی...'
            : 'در حال تحلیل نتیجهٔ ابزارها و ادامهٔ پاسخ...',
        isWorking: true,
      );

      transcript.trimToBudget(budget.maxTranscriptChars);

      final Stream<String> stream;
      if (isChatGptWeb) {
        // پل وب آرایهٔ پیام نمی‌گیرد؛ نوبت اول پرامپت کامل و نوبت‌های بعد
        // نتیجهٔ ابزار را درون همان ترد می‌فرستند.
        stream = turn == 1
            ? ChatGptWebBridgeManager.instance.sendPrompt(
                prompt: prompt,
                personaTitle: personaTitle,
                personaSystemPrompt: systemPrompt,
                contextSummary: contextSummary,
                recentHistory: recentHistory,
              )
            : ChatGptWebBridgeManager.instance.sendPrompt(prompt: followUp);
      } else {
        stream = AIGateway.instance.sendCustomChatStream(
          messages: transcript.toMessages(),
          slot: slot,
        );
      }

      final turnRaw = StringBuffer();
      var streamErrorFa = '';
      var cutEarly = false;

      try {
        await for (final chunk in stream) {
          if (chunk.startsWith('error:')) {
            streamErrorFa = chunk.substring(6);
            break;
          }
          turnRaw.write(chunk);
          final soFar = turnRaw.toString();

          final live = soFar.contains('<')
              ? AgentToolCallParser.scan(soFar)
              : AgentToolCallScan.empty;

          final combined = AgentToolCallParser.cleanForDisplay(
            _join(rawBuffer, AgentToolCallParser.stripToolCalls(soFar)),
          );
          if (combined != displayed) {
            final delta = combined.startsWith(displayed)
                ? combined.substring(displayed.length)
                : '';
            displayed = combined;
            yield AgentTokenStreamEvent(delta: delta, accumulated: combined);
          }

          if (live.hasCalls && live.tailLength > _tailCutoffAfterToolCall) {
            cutEarly = true;
            break;
          }
          if (soFar.length > _maxRawCharsPerTurn) {
            cutEarly = true;
            break;
          }
        }
      } catch (e, st) {
        streamErrorFa = e.toString();
        debugPrint('[Agent] stream error on turn $turn: $e\n$st');
      }

      if (cutEarly) {
        debugPrint('[Agent] turn $turn stream cut early');
        if (isChatGptWeb) {
          ChatGptWebBridgeManager.instance.cancelCurrentStream();
        }
      }

      final raw = turnRaw.toString();
      final scan = AgentToolCallParser.scan(raw);
      if (scan.parseErrors.isNotEmpty) {
        debugPrint(
            '[Agent] tool_call parse issues: ${scan.parseErrors.join(' | ')}');
      }

      rawBuffer = _join(rawBuffer, AgentToolCallParser.stripToolCalls(raw));
      transcript.addAssistant(raw);

      // پاسخ نهایی: مدل دیگر ابزاری نخواسته است
      if (!scan.hasCalls) {
        if (streamErrorFa.isNotEmpty &&
            AgentToolCallParser.cleanForDisplay(rawBuffer).isEmpty) {
          if (turn == 1 && allResults.isEmpty) {
            debugPrint(
                '[Agent] turn 1 failed with no data -> plain chat fallback');
            yield AgentErrorEvent(streamErrorFa);
            return;
          }
          stopNoteFa = '⚠️ ارتباط با مدل در میانهٔ پاسخ قطع شد.';
        }
        break;
      }

      // نوبت آخر: دیگر ابزاری اجرا نمی‌شود
      if (noMoreTools) {
        stopNoteFa = budget.isTimedOut
            ? '⚠️ زمان پردازش طولانی شد و ادامهٔ فراخوانی ابزار متوقف شد.'
            : '⚠️ سقف فراخوانی ابزار در این پیام پر شد؛ اگر پاسخ کامل نیست دوباره بپرس.';
        debugPrint(
            '[Agent] ignoring ${scan.calls.length} tool call(s) on final turn $turn');
        break;
      }

      // ۴. اجرای ابزارهای درخواستی مدل
      final turnResults = <AgentToolResult>[];
      var executedThisTurn = 0;

      for (final call in scan.calls) {
        if (executedThisTurn >= budget.maxToolCallsPerTurn) {
          turnResults.add(AgentToolResult.failure(
            toolName: call.toolName,
            errorMessage:
                'در این نوبت سقف ${budget.maxToolCallsPerTurn} فراخوانی پر شد و این ابزار اجرا نشد.',
          ));
          continue;
        }

        final tool = AgentToolRegistry.instance.getTool(call.toolName);
        if (tool == null) {
          turnResults.add(AgentToolResult.failure(
            toolName: call.toolName.isEmpty ? 'نامشخص' : call.toolName,
            errorMessage:
                'ابزاری با این نام وجود ندارد. فقط از فهرست ابزارهای اعلام‌شده استفاده کن.',
          ));
          debugPrint('[Agent] unknown tool requested: ${call.toolName}');
          continue;
        }

        // دروازهٔ سیاست (نسخهٔ حداقلی فاز ۱): ابزارهای نیازمند تایید، خودکار
        // اجرا نمی‌شوند. دروازهٔ کامل + ژورنال + undo در فاز ۳.
        if (tool.policy == ToolPolicy.actionInteractive) {
          interactiveAction = <String, dynamic>{
            'type': 'tool_confirmation',
            'tool': tool.name,
            'titleFa': tool.titleFa,
            'parameters': call.parameters,
          };
          turnResults.add(AgentToolResult.failure(
            toolName: tool.name,
            errorMessage:
                'این ابزار بدون تایید صریح کاربر اجرا نمی‌شود. خلاصهٔ کاری که می‌خواهی انجام دهی را بگو و اجازه بگیر.',
          ));
          debugPrint('[Agent] interactive tool held for consent: ${tool.name}');
          continue;
        }

        final admission = budget.admit(tool.name, call.parameters);
        if (!admission.allowed) {
          turnResults.add(AgentToolResult.failure(
            toolName: tool.name,
            errorMessage: admission.reasonFa ?? 'اجرای این ابزار مجاز نبود.',
          ));
          debugPrint('[Agent] tool denied (${tool.name}): ${admission.reasonFa}');
          continue;
        }

        final stepIndex = steps.length;
        final startedAt = DateTime.now();
        final runningStep = AgentStep(
          id: 'step_${startedAt.microsecondsSinceEpoch}_${tool.name}',
          titleFa: tool.titleFa,
          descriptionFa: 'در حال اجرا...',
          toolName: tool.name,
          status: AgentStepStatus.running,
          startTime: startedAt,
        );
        steps.add(runningStep);

        yield AgentStatusChangedEvent(
          statusTextFa: 'در حال اجرای «${tool.titleFa}»...',
          isWorking: true,
          currentToolName: tool.name,
        );
        yield AgentStepStartedEvent(runningStep);

        final result = await AgentToolRegistry.instance
            .executeTool(tool.name, call.parameters);
        executedThisTurn++;
        turnResults.add(result);
        allResults.add(result);

        final doneStep = AgentStep(
          id: runningStep.id,
          titleFa: runningStep.titleFa,
          descriptionFa:
              result.isSuccess ? result.summaryFa : result.errorMessage,
          toolName: tool.name,
          status: result.isSuccess
              ? AgentStepStatus.success
              : AgentStepStatus.failed,
          startTime: startedAt,
          endTime: DateTime.now(),
          resultData: result.data,
          errorMessage: result.isSuccess ? null : result.errorMessage,
        );
        steps[stepIndex] = doneStep;
        yield AgentStepCompletedEvent(doneStep);
        debugPrint(
            '[Agent] turn $turn tool ${tool.name} -> ${result.isSuccess ? 'ok' : 'failed'}');
      }

      final nextNoMoreTools = turn + 1 >= budget.maxTurns ||
          !budget.canRunMoreTools ||
          budget.isTimedOut;
      pendingFollowUp = transcript.addToolResults(
        turnResults,
        noMoreTools: nextNoMoreTools,
      );
    }

    // ۵. جمع‌بندی
    var finalRaw = rawBuffer.trim();
    var finalAnswer = AgentToolCallParser.cleanForDisplay(finalRaw);

    if (finalAnswer.isEmpty) {
      final fallback = AgentToolProtocol.fallbackAnswerFromResults(allResults);
      finalAnswer = fallback;
      finalRaw = fallback;
      debugPrint(
          '[Agent] empty model answer -> deterministic fallback from ${allResults.length} result(s)');
    }

    if (stopNoteFa.isNotEmpty) {
      finalAnswer = '$finalAnswer\n\n$stopNoteFa';
      finalRaw = '$finalRaw\n\n$stopNoteFa';
    }

    interactiveAction ??= _parseFirstAction(finalRaw);

    yield AgentStatusChangedEvent(
      statusTextFa: 'پاسخ آماده است.',
      isWorking: false,
    );
    debugPrint(
        '[Agent] loop done | turns=${budget.turnsUsed} | tools=${budget.toolCallsUsed} | steps=${steps.length} | ${budget.elapsed.inMilliseconds}ms');

    yield AgentCompletedEvent(
      finalAnswer: finalAnswer,
      rawAnswer: finalRaw,
      steps: steps,
      interactiveAction: interactiveAction,
    );
  }

  /// اتصال متن دو نوبت با فاصلهٔ پاراگراف
  String _join(String left, String right) {
    if (left.trim().isEmpty) return right;
    if (right.trim().isEmpty) return left;
    return '${left.trimRight()}\n\n${right.trimLeft()}';
  }

  /// تبدیل تاریخچهٔ متنی به پیام‌های نقش‌دار (پ۰-۵)
  List<Map<String, String>> _historyToMessages(List<String> history) {
    const assistantPrefixes = ['دستیار:', 'assistant:', 'Assistant:'];
    const userPrefixes = ['کاربر:', 'user:', 'User:'];

    final messages = <Map<String, String>>[];
    for (final line in history) {
      final text = line.trim();
      if (text.isEmpty) continue;

      var role = 'user';
      var content = text;
      for (final prefix in assistantPrefixes) {
        if (text.startsWith(prefix)) {
          role = 'assistant';
          content = text.substring(prefix.length).trim();
          break;
        }
      }
      if (role == 'user') {
        for (final prefix in userPrefixes) {
          if (text.startsWith(prefix)) {
            content = text.substring(prefix.length).trim();
            break;
          }
        }
      }
      if (content.isEmpty) continue;
      messages.add(<String, String>{'role': role, 'content': content});
    }
    return messages;
  }

  /// اولین اکشن داخل تگ actions (برای کارت تعاملی UI)
  Map<String, dynamic>? _parseFirstAction(String raw) {
    final match = RegExp(r'<actions>([\s\S]*?)<\/actions>').firstMatch(raw);
    if (match == null) return null;
    try {
      final decoded = jsonDecode(match.group(1)!.trim());
      if (decoded is List && decoded.isNotEmpty && decoded.first is Map) {
        return (decoded.first as Map).cast<String, dynamic>();
      }
      if (decoded is Map) return decoded.cast<String, dynamic>();
    } catch (_) {
      return null;
    }
    return null;
  }
}
