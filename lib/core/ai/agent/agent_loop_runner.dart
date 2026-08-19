import 'dart:async';
import 'dart:convert';

import 'package:ritmo/core/ai/agent/agent_budget.dart';
import 'package:ritmo/core/ai/agent/agent_event.dart';
import 'package:ritmo/core/ai/agent/agent_policy_gate.dart';
import 'package:ritmo/core/ai/agent/agent_tool.dart';
import 'package:ritmo/core/ai/agent/agent_tool_argument_validator.dart';
import 'package:ritmo/core/ai/agent/agent_tool_call_parser.dart';
import 'package:ritmo/core/ai/agent/agent_tool_protocol.dart';
import 'package:ritmo/core/ai/agent/agent_tool_registry.dart';
import 'package:ritmo/core/ai/agent/agent_tool_scope.dart';
import 'package:ritmo/core/ai/agent/agent_transcript.dart';
import 'package:ritmo/core/ai/agent/catalog/kernel_command_tool.dart';
import 'package:ritmo/core/ai/agent/intent/agent_intent_router.dart';
import 'package:ritmo/core/ai/ai_connection_models.dart';
import 'package:ritmo/core/ai/ai_connection_repository.dart';
import 'package:ritmo/core/ai/ai_gateway.dart';
import 'package:ritmo/core/ai/ai_prompt_engine.dart';
import 'package:ritmo/core/ai/personas/persona_inference_profile.dart';
import 'package:ritmo/core/ai/web_bridge/bridge_trace_log.dart';
import 'package:ritmo/core/ai/web_bridge/chatgpt_web_bridge_manager.dart';
import 'package:ritmo/core/logging/ritmo_logger.dart';

/// حلقه واقعی ReAct ایجنت ریتمو (فاز ۱) + دروازه سیاست و تایید (فاز ۳)
/// + محدوده اختیارات پرسونا (فاز ۵ · P5-1)
///
/// جریان: پیش‌واکشی → نوبت مدل → پارس tool_call → محدوده پرسونا → داوری گیت
/// → (تایید کاربر) → اجرای ابزار + ثبت ژورنال → بازگرداندن نتیجه به مدل → تکرار.
class AgentLoopRunner {
  AgentLoopRunner._();

  static final AgentLoopRunner instance = AgentLoopRunner._();

  /// سقف متن خام یک نوبت (محافظ مدل‌های پرگو)
  static const int _maxRawCharsPerTurn = 20000;

  /// اگر مدل پس از بستن tool_call بیش از این مقدار نوشت، استریم قطع می‌شود
  /// تا نتیجه خیالی ابزار را نسازد.
  static const int _tailCutoffAfterToolCall = 220;

  /// اگر پس از باز شدن یک تگ، بیش از این تعداد کاراکتر بدون بسته شدن آمد،
  /// تگ را متن عادی تلقی کن و رندر را آزاد کن (A-09).
  static const int _maxSuppressedChars = 600;

  /// سقف زمانی سرکوب — مستقل از طول متن (A-09).
  static const Duration _maxSuppressionWindow = Duration(seconds: 6);

  Stream<AgentEvent> runAgent({
    required String prompt,
    required String personaId,
    String? personaTitle,
    String? personaSystemPrompt,
    String? contextSummary,
    List<String>? recentHistory,
    AiSlot slot = AiSlot.assistant,
    PersonaInferenceProfile? inferenceProfile,
  }) async* {
    final effectiveSlot = inferenceProfile?.slot ?? slot;
    final effectiveTemperature = inferenceProfile?.temperature ?? 0.2;
    final effectiveMaxTokens = inferenceProfile?.maxTokens;
    final budget = AgentBudget();
    final steps = <AgentStep>[];
    final allResults = <AgentToolResult>[];

    /// شناسه این اجرا: کلید پیدا کردن عملیات قابل بازگشت در ژورنال
    final sessionId = 'agent_${DateTime.now().microsecondsSinceEpoch}';

    /// محدوده اختیارات این نقش (فاز ۵ · P5-1). لایه‌های دیگر مثل پیش‌واکشی
    /// همین پرسونای فعال را می‌خوانند.
    AgentToolScope.instance.setActivePersona(personaId);
    final allowedTools = AgentToolScope.instance.allowedToolNames(personaId);
    final knownToolNames = allowedTools.isNotEmpty
        ? allowedTools
        : AgentToolRegistry.instance.allTools.map((t) => t.name).toSet();

    /// کش نتیجه ابزارهای فقط‌خواندنی در همین اجرا (فاز ۴ · P4-4):
    /// یک ابزار با پارامترهای یکسان دوبار به دیتابیس نمی‌زند.
    final toolCache = <String, AgentToolResult>{};

    /// کش ابزارهای تغییردهنده برای جلوگیری از تکرار همان اکشن در یک اجرا (T20)
    final mutationCache = <String, AgentToolResult>{};

    /// تعداد تغییرات واقعی انجام‌شده در این پیام (سقف در گیت)
    var writesUsed = 0;

    yield const AgentStatusChangedEvent(
      statusTextFa: 'در حال تحلیل نیت و بررسی ابزارهای موردنیاز...',
      isWorking: true,
    );

    // ۱. پیش‌واکشی قطعی (مستقل از تصمیم مدل) تا مدل با داده واقعی شروع کند
    final prefetch = await AgentIntentRouter.instance.routeAndPrefetch(
      prompt,
      personaId: personaId,
    );
    for (final step in prefetch.initialSteps) {
      steps.add(step);
      yield AgentStepStartedEvent(step);
      yield AgentStepCompletedEvent(step);
    }
    allResults.addAll(prefetch.toolResults);
    for (final r in prefetch.toolResults) {
      if (r.isSuccess) {
        final args = prefetch.toolArgs[r.toolName] ?? const <String, dynamic>{};
        final cacheKey = _cacheKey(r.toolName, args);
        toolCache[cacheKey] = r;
        budget.admit(r.toolName, args);
      }
    }

    // ۲. پرامپت سیستمی: پرسونا + فهرست ابزار مجاز + قواعد حلقه + داده زنده
    final system = StringBuffer();
    if (personaSystemPrompt != null && personaSystemPrompt.trim().isNotEmpty) {
      system.writeln(personaSystemPrompt);
    } else {
      system.writeln(AIPromptEngine.buildChatSystemPrompt());
    }
    system.writeln('\n${AgentToolScope.instance.promptFor(personaId)}');
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
    RitmoLog.debug(
        'Agent',
        'loop start | web=$isChatGptWeb | wire=${wireFormat.name} | persona=$personaId | tools=${allowedTools.length}/${AgentToolRegistry.instance.count} | session=$sessionId');

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

      yield AgentTurnStartedEvent(turn: turn, maxTurns: budget.maxTurns);
      // T-12 / A-77: پیش‌فرض هر نوبت را پاسخ نهایی فرض می‌کنیم تا سرکوب نوبت قبل رفع شود
      yield AgentDisplayResetEvent(turnKind: AgentTurnKind.finalAnswerTurn, turn: turn);
      yield AgentStatusChangedEvent(
        statusTextFa: turn == 1
            ? 'در حال نگارش و تحلیل پاسخ نهایی...'
            : 'در حال تحلیل نتیجه ابزارها و ادامه پاسخ...',
        isWorking: true,
      );

      transcript.trimToBudget(budget.maxTranscriptChars);

      final Stream<String> stream;
      if (isChatGptWeb) {
        // پل وب آرایه پیام نمی‌گیرد؛ نوبت اول پرامپت کامل و نوبت‌های بعد
        // نتیجه ابزار را درون همان ترد می‌فرستند.
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
          slot: effectiveSlot,
          temperature: effectiveTemperature,
          maxTokens: effectiveMaxTokens,
        );
      }

      final turnRaw = StringBuffer();
      var streamErrorFa = '';
      var cutEarly = false;
      var suppressedSince = 0;
      DateTime? suppressedAt;
      var watchdogReleasedThisTurn = false;

      try {
        await for (final chunk in stream) {
          if (chunk.startsWith('error:')) {
            streamErrorFa = chunk.substring(6);
            break;
          }

          // A-12: Handle rewrite sentinel from web bridge accumulator
          if (chunk.startsWith(ChatGptWebBridgeManager.rewriteSentinel)) {
            final clean = chunk.substring(ChatGptWebBridgeManager.rewriteSentinel.length);
            turnRaw.clear();
            turnRaw.write(clean);
            displayed = '';
          } else {
            turnRaw.write(chunk);
          }
          final soFar = turnRaw.toString();

          // Stage 1: بررسی وضعیت partial token فقط در صورت وجود نشانهٔ واقعی (A-10, A-79)
          final live = AgentToolCallParser.shouldScanForToolCalls(soFar)
              ? AgentToolCallParser.scan(soFar, knownToolNames: knownToolNames)
              : AgentToolCallScan.empty;

          // Stage 2: رندر با واچ‌داگ سرکوب (A-09)
          var renderAllowed = !live.hasOpenTag || watchdogReleasedThisTurn;

          if (live.hasOpenTag && !watchdogReleasedThisTurn) {
            suppressedAt ??= DateTime.now();
            if (suppressedSince == 0) suppressedSince = soFar.length;

            final grewBy = soFar.length - suppressedSince;
            final elapsed = DateTime.now().difference(suppressedAt);

            if (grewBy > _maxSuppressedChars || elapsed > _maxSuppressionWindow) {
              renderAllowed = true;
              watchdogReleasedThisTurn = true;
              RitmoLog.warning(
                'Agent',
                'suppression watchdog released render '
                '(grewBy=$grewBy, elapsedMs=${elapsed.inMilliseconds})',
              );
              BridgeTraceLog.instance.addEntry(
                type: 'suppression_watchdog_release',
                source: 'dart',
                note: 'suppression_watchdog_release (grewBy=$grewBy, elapsedMs=${elapsed.inMilliseconds})',
                level: BridgeTraceLevel.warn,
              );
            }
          } else if (!live.hasOpenTag) {
            suppressedAt = null;
            suppressedSince = 0;
          }

          if (renderAllowed) {
            final combined = AgentToolCallParser.cleanForDisplay(
              _join(rawBuffer, AgentToolCallParser.stripToolCalls(soFar, knownToolNames: knownToolNames)),
              knownToolNames: knownToolNames,
            );
            if (combined != displayed) {
              final delta = combined.startsWith(displayed) && displayed.isNotEmpty
                  ? combined.substring(displayed.length)
                  : combined;
              displayed = combined;
              yield AgentTokenStreamEvent(delta: delta, accumulated: combined);
            }
          }
          // else: تگ باز است — متن موقتاً سرکوب می‌شود

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
        RitmoLog.error('Agent', 'stream error on turn $turn: $e', e, st);
      }

      if (cutEarly) {
        RitmoLog.debug('Agent', 'turn $turn stream cut early');
        if (isChatGptWeb) {
          ChatGptWebBridgeManager.instance.cancelCurrentStream();
        }
      }

      final raw = turnRaw.toString();
      final scan = AgentToolCallParser.scan(raw, knownToolNames: knownToolNames);
      if (scan.parseErrors.isNotEmpty) {
        RitmoLog.warning(
            'Agent',
            'tool_call parse issues: ${scan.parseErrors.join(' | ')}');
      }

      rawBuffer = _join(rawBuffer, AgentToolCallParser.stripToolCalls(raw, knownToolNames: knownToolNames));
      transcript.addAssistant(raw);

      // پاسخ نهایی: مدل دیگر ابزاری نخواسته است
      if (!scan.hasCalls) {
        if (streamErrorFa.isNotEmpty &&
            AgentToolCallParser.cleanForDisplay(rawBuffer, knownToolNames: knownToolNames).isEmpty) {
          if (turn == 1 && allResults.isEmpty) {
            RitmoLog.debug(
                'Agent',
                'turn 1 failed with no data -> plain chat fallback');
            yield AgentErrorEvent(streamErrorFa);
            return;
          }
          stopNoteFa = '⚠️ ارتباط با مدل در میانه پاسخ قطع شد.';
        }
        break;
      }

      // نوبت ابزاری تمام شد — بافر نمایش بازنشانی می‌شود (WEB-33, A-77)
      yield AgentDisplayResetEvent(turnKind: AgentTurnKind.toolCallTurn, turn: turn);
      // بافر نمایشی این نوبت دور ریخته می‌شود؛ نوبت بعدی از صفر شروع می‌کند
      displayed = '';


      // نوبت آخر: دیگر ابزاری اجرا نمی‌شود
      if (noMoreTools) {
        stopNoteFa = budget.isTimedOut
            ? '⚠️ زمان پردازش طولانی شد و ادامه فراخوانی ابزار متوقف شد.'
            : '⚠️ سقف فراخوانی ابزار در این پیام پر شد؛ اگر پاسخ کامل نیست دوباره بپرس.';
        RitmoLog.debug(
            'Agent',
            'ignoring ${scan.calls.length} tool call(s) on final turn $turn');
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
          RitmoLog.debug('Agent', 'unknown tool requested: ${call.toolName}');
          continue;
        }

        // محدوده اختیارات نقش (فاز ۵ · P5-1): پیش از هر کار دیگر
        if (!allowedTools.contains(tool.name)) {
          final reason =
              AgentToolScope.instance.refusalReasonFa(personaId, tool);
          turnResults
              .add(AgentPolicyGate.instance.refusalResult(tool, reason));
          RitmoLog.debug(
              'Agent', 'scope denied | ${tool.name} | persona=$personaId');
          continue;
        }

        // اعتبارسنجی مرکزی آرگومان‌ها (فاز ۴ · T18)
        final validation =
            AgentToolArgumentValidator.validate(tool, call.parameters);
        if (!validation.isValid) {
          final err =
              validation.errorMessageFa ?? 'پارامترهای ارسالی نامعتبر است.';
          turnResults.add(AgentToolResult.failure(
            toolName: tool.name,
            errorMessage: err,
          ));
          RitmoLog.debug('Agent', 'validation failed | ${tool.name} | $err');
          continue;
        }
        final validatedArgs = validation.sanitizedArgs;

        // کش همین اجرا: خواندن تکراری با پارامتر یکسان دوباره اجرا نمی‌شود
        final cacheKey = _cacheKey(tool.name, validatedArgs);
        if (tool.policy == ToolPolicy.readOnly) {
          final cached = toolCache[cacheKey];
          if (cached != null) {
            turnResults.add(AgentToolResult.success(
              toolName: cached.toolName,
              data: cached.data,
              summaryFa:
                  '${cached.summaryFa} (همین داده پیش‌تر در این پیام خوانده شده بود)',
            ));
            RitmoLog.debug('Agent', 'cache hit | ${tool.name}');
            continue;
          }
        } else {
          // محافظ Idempotency برای ابزارهای تغییردهنده در طول این اجرا (T20)
          final previousMutation = mutationCache[cacheKey];
          if (previousMutation != null && previousMutation.isSuccess) {
            turnResults.add(AgentToolResult.success(
              toolName: previousMutation.toolName,
              data: previousMutation.data,
              summaryFa:
                  '${previousMutation.summaryFa} (این تغییر پیش‌تر در همین گفتگو با موفقیت اعمال شده بود و تکرار نشد)',
            ));
            RitmoLog.debug('Agent', 'mutation idempotency hit | ${tool.name}');
            continue;
          }
        }

        // دروازه سیاست (فاز ۳ · P3-1)
        final decision = AgentPolicyGate.instance.evaluate(
          tool: tool,
          args: validatedArgs,
          writesUsedThisRun: writesUsed,
          maxWrites: budget.maxWrites,
        );
        if (decision.isDenied) {
          final reason = decision.reasonFa ?? 'اجرای این ابزار مجاز نبود.';
          turnResults
              .add(AgentPolicyGate.instance.refusalResult(tool, reason));
          RitmoLog.debug('Agent', 'gate denied | ${tool.name} | $reason');
          continue;
        }

        final admission = budget.admit(tool.name, validatedArgs);
        if (!admission.allowed) {
          turnResults.add(AgentToolResult.failure(
            toolName: tool.name,
            errorMessage: admission.reasonFa ?? 'اجرای این ابزار مجاز نبود.',
          ));
          RitmoLog.debug('Agent', 'tool denied (${tool.name}): ${admission.reasonFa}');
          continue;
        }

        var effectiveArgs = validatedArgs;

        // کارت تایید (فاز ۳ · P3-2): حلقه واقعا متوقف می‌شود تا کاربر پاسخ دهد
        if (decision.needsUserConfirmation) {
          final request = AgentConfirmationRequest(
            id: 'confirm_${DateTime.now().microsecondsSinceEpoch}',
            toolName: tool.name,
            titleFa: tool.titleFa,
            previewFa: decision.previewFa ?? tool.titleFa,
            parameters: call.parameters,
          );
          interactiveAction = <String, dynamic>{
            'type': 'tool_confirmation',
            'requestId': request.id,
            'tool': tool.name,
            'titleFa': tool.titleFa,
            'previewFa': request.previewFa,
            'parameters': call.parameters,
          };

          yield AgentStatusChangedEvent(
            statusTextFa: 'منتظر تایید شما برای «${tool.titleFa}»...',
            isWorking: true,
            currentToolName: tool.name,
          );
          yield AgentAwaitingConfirmationEvent(request);

          final response = await AgentConfirmationBroker.instance.ask(request);
          yield AgentConfirmationResolvedEvent(
            requestId: request.id,
            toolName: tool.name,
            approved: response.approved,
            reasonFa: response.reasonFa,
          );

          if (!response.approved) {
            if (response.timedOut) {
              yield AgentConfirmationTimedOutEvent(
                requestId: request.id,
                toolName: tool.name,
                messageFa: 'زمان تایید تمام شد، اقدام انجام نشد. اگر می‌خواهی، دوباره درخواست بده.',
              );
            }
            final reason = response.reasonFa;
            final suffix =
                (reason != null && reason.isNotEmpty) ? ' ($reason)' : '';
            final why = response.timedOut
                ? 'کارت تایید بی‌پاسخ ماند، پس این تغییر انجام نشد و هیچ داده‌ای ذخیره نشد.'
                : 'کاربر این تغییر را تایید نکرد$suffix. هیچ داده‌ای ذخیره نشد.';
            turnResults
                .add(AgentPolicyGate.instance.refusalResult(tool, why));
            RitmoLog.debug('Agent', 'confirmation rejected | ${tool.name}');
            continue;
          }

          final edited = response.editedArgs;
          if (edited != null && edited.isNotEmpty) {
            effectiveArgs = edited;
          }
          interactiveAction = null;
        }

        if (tool.name == 'ask_user') {
          final question =
              KernelCommandTool.optionalString(effectiveArgs['question']) ??
                  'پرسش دستیار';
          final optionsRaw = effectiveArgs['options'];
          final options = <String>[];
          if (optionsRaw is List) {
            for (final o in optionsRaw) {
              final s = KernelCommandTool.optionalString(o);
              if (s != null) options.add(s);
            }
          }
          final qReq = AgentQuestionRequest(
            id: 'q_${DateTime.now().microsecondsSinceEpoch}',
            sessionId: sessionId,
            question: question,
            options: options,
          );

          yield AgentStatusChangedEvent(
            statusTextFa: 'در انتظار پاسخ شما...',
            isWorking: true,
            currentToolName: tool.name,
          );
          yield AgentAwaitingQuestionEvent(qReq);

          final qRes = await AgentQuestionBroker.instance.ask(qReq);
          yield AgentQuestionResolvedEvent(
            requestId: qReq.id,
            answered: qRes.answered,
            answer: qRes.answer,
            reasonFa: qRes.reasonFa,
          );

          if (!qRes.answered) {
            turnResults.add(AgentToolResult.failure(
              toolName: tool.name,
              errorMessage: qRes.reasonFa ?? 'پاسخی از کاربر دریافت نشد.',
              summaryFa:
                  'کاربر به پرسش پاسخ نداد یا لغو کرد: ${qRes.reasonFa ?? 'لغو شد'}',
            ));
            continue;
          }

          turnResults.add(AgentToolResult.success(
            toolName: tool.name,
            data: {
              'question': question,
              'userAnswer': qRes.answer,
              'options': options,
            },
            summaryFa: 'پاسخ کاربر دریافت شد: «${qRes.answer}»',
          ));
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

        // اجرا از مسیر گیت: ابزارهای تغییردهنده در ژورنال ثبت می‌شوند
        final result = await AgentPolicyGate.instance.execute(
          tool: tool,
          args: effectiveArgs,
          sessionId: sessionId,
        );
        executedThisTurn++;
        if (tool.policy != ToolPolicy.readOnly) {
          if (result.isSuccess) {
            writesUsed++;
            final mutationKey = _cacheKey(tool.name, effectiveArgs);
            mutationCache[mutationKey] = result;
            // بی‌اعتبارسازی کش ابزارهای خواندنی برای دریافت وضعیت تازه
            toolCache.clear();
          }
        } else if (result.isSuccess) {
          toolCache[cacheKey] = result;
        }
        if (result.isSuccess &&
            result.data != null &&
            result.data!['interactiveAction'] is Map) {
          interactiveAction =
              (result.data!['interactiveAction'] as Map).cast<String, dynamic>();
        }
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
        RitmoLog.debug(
            'Agent',
            'turn $turn tool ${tool.name} -> ${result.isSuccess ? 'ok' : 'failed'}');
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
      RitmoLog.debug(
          'Agent',
          'empty model answer -> deterministic fallback from ${allResults.length} result(s)');
    }

    if (stopNoteFa.isNotEmpty) {
      finalAnswer = '$finalAnswer\n\n$stopNoteFa';
      finalRaw = '$finalRaw\n\n$stopNoteFa';
    }

    interactiveAction ??= _parseFirstAction(finalRaw);

    // A-11: تور ایمنی نهایی — اگر متن نهایی هنوز به UI نرسیده، فلاش کن
    final cleanFinalAnswer = AgentToolCallParser.cleanForDisplay(finalAnswer);
    if (cleanFinalAnswer.isNotEmpty && cleanFinalAnswer != displayed) {
      final delta = cleanFinalAnswer.startsWith(displayed) && displayed.isNotEmpty
          ? cleanFinalAnswer.substring(displayed.length)
          : cleanFinalAnswer;
      RitmoLog.debug(
        'Agent',
        'final flush: displayedLen=${displayed.length} finalLen=${cleanFinalAnswer.length}',
      );
      yield AgentTokenStreamEvent(delta: delta, accumulated: cleanFinalAnswer);
      displayed = cleanFinalAnswer;
    }

    yield const AgentStatusChangedEvent(
      statusTextFa: 'پاسخ آماده است.',
      isWorking: false,
    );
    RitmoLog.debug(
        'Agent',
        'loop done | turns=${budget.turnsUsed} | tools=${budget.toolCallsUsed} | writes=$writesUsed | steps=${steps.length} | ${budget.elapsed.inMilliseconds}ms');

    yield AgentCompletedEvent(
      finalAnswer: finalAnswer,
      rawAnswer: finalRaw,
      steps: steps,
      interactiveAction: interactiveAction,
      sessionId: sessionId,
    );
  }

  /// کلید کش نتیجه ابزار: نام ابزار + پارامترهای مرتب‌شده
  String _cacheKey(String toolName, Map<String, dynamic> args) {
    final keys = args.keys.toList()..sort();
    final normalized = <String, dynamic>{};
    for (final key in keys) {
      normalized[key] = args[key];
    }
    String encoded;
    try {
      encoded = jsonEncode(normalized);
    } catch (e) {
      encoded = normalized.toString();
      RitmoLog.debug('Agent', 'jsonEncode failed for cacheKey: $e');
    }
    return '$toolName|$encoded';
  }

  /// اتصال متن دو نوبت با فاصله پاراگراف
  String _join(String left, String right) {
    if (left.trim().isEmpty) return right;
    if (right.trim().isEmpty) return left;
    return '${left.trimRight()}\n\n${right.trimLeft()}';
  }

  /// تبدیل تاریخچه متنی به پیام‌های نقش‌دار (پ۰-۵)
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
    } catch (e) {
      RitmoLog.debug('Agent', 'Could not parse actions from raw text: $e');
      return null;
    }
    return null;
  }
}
