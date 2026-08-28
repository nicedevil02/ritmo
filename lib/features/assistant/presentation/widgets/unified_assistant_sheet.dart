import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:ritmo/core/ai/ai_connection_models.dart';
import 'package:ritmo/core/logging/ritmo_logger.dart';
import 'package:ritmo/core/ai/ai_gateway.dart';
import 'package:ritmo/core/ai/chat/chat_action_parser.dart';
import 'package:ritmo/core/ai/chat/chat_models.dart';
import 'package:ritmo/core/ai/memory/ai_memory_service.dart';
import 'package:ritmo/core/ai/memory/memory_models.dart';
import 'package:ritmo/core/ai/web_bridge/chatgpt_mini_preview.dart';
import 'package:ritmo/core/ai/web_bridge/chatgpt_web_bridge_manager.dart';
import 'package:ritmo/core/ai/web_bridge/cloudflare_challenge_modal.dart';
import 'package:ritmo/core/ai/memory/assistant_memory_binding.dart';
import 'package:ritmo/core/ai/personas/persona_prompt_builder.dart';
import 'package:ritmo/core/ai/personas/persona_inference_profile.dart';
import 'package:ritmo/core/ai/personas/persona_response_validator.dart';
import 'package:ritmo/core/ai/personas/persona_skill.dart';
import 'package:ritmo/core/ai/brief/persona_context_provider.dart';
import 'package:ritmo/core/ai/brief/domain_brief.dart';
import 'package:ritmo/core/ai/brief/briefs/sleep_brief.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/domain/commands/ritmo_command.dart';
import 'package:ritmo/core/domain/commands/command_plan.dart';
import 'package:ritmo/core/domain/commands/ritmo_command_bus.dart';
import 'package:ritmo/core/domain/commands/command_manifest.dart';
import 'package:ritmo/core/domain/personas/assistant_persona.dart';
import 'package:ritmo/core/domain/personas/persona_registry.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/widgets/ritmo_sheet_scaffold.dart';
import 'package:ritmo/features/assistant/logic/assistant_action_registry.dart';
import 'package:ritmo/features/assistant/models/assistant_models.dart';
import 'package:ritmo/core/ai/agent/agent_event.dart';
import 'package:ritmo/core/ai/agent/agent_loop_runner.dart';
import 'package:ritmo/core/ai/agent/agent_policy_gate.dart';
import 'package:ritmo/core/ai/agent/ui/agent_confirmation_card.dart';
import 'package:ritmo/core/ai/agent/ui/agent_stream_presenter.dart';
import 'package:ritmo/core/ai/web_bridge/bridge_status_chip.dart';
import 'package:ritmo/features/chat/presentation/widgets/agent_timeline_visualizer.dart';
import 'package:ritmo/features/chat/presentation/widgets/streaming_message_bubble.dart';

/// Unified Assistant Sheet with iOS26 Glassmorphic Window, Speech-to-Text,
/// StreamingMessageBubble, Swipe-to-Delete, and Copy animations matching Main Assistant.
class AssistantSheet extends StatefulWidget {
  const AssistantSheet({super.key, required this.persona, this.initialQuery});

  final AssistantPersona persona;
  final String? initialQuery;

  static Future<void> show(
    BuildContext context, {
    required AssistantPersona persona,
    String? initialQuery,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.transparent,
      builder: (context) =>
          AssistantSheet(persona: persona, initialQuery: initialQuery),
    );
  }

  @override
  State<AssistantSheet> createState() => _AssistantSheetState();
}

class _AssistantSheetState extends State<AssistantSheet> {
  final AgentStreamPresenter _presenter = AgentStreamPresenter();
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];

  bool _isTyping = false;
  bool _isStreaming = false;
  StreamSubscription<String>? _streamSubscription;
  StreamSubscription<AgentEvent>? _agentSubscription;
  final List<AgentStep> _agentSteps = [];
  String _agentStatusText = '';
  bool _isAgentWorking = false;

  bool _canUndoLast = false;
  String? _lastPlanId;

  DomainBrief? _primaryBrief;
  List<PersonaSkill> _relevantSkills = [];

  final Map<String, Timer> _pendingDeleteTimers = {};

  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isSpeechAvailable = false;
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _loadOpeningMove();
    _checkLastPlan();
    _initSpeech();
    ChatGptWebBridgeManager.instance.cloudflareNotifier.addListener(
      _handleCloudflarePrompt,
    );
    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _sendMessage(widget.initialQuery);
      });
    }
  }

  void _handleCloudflarePrompt() {
    if (ChatGptWebBridgeManager.instance.cloudflareNotifier.value && mounted) {
      CloudflareChallengeModal.show(context);
    }
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    _agentSubscription?.cancel();
    AgentConfirmationBroker.instance.cancelAll();
    AgentQuestionBroker.instance.cancelAll();
    ChatGptWebBridgeManager.instance.cloudflareNotifier.removeListener(
      _handleCloudflarePrompt,
    );
    for (final timer in _pendingDeleteTimers.values) {
      timer.cancel();
    }
    _chatController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initSpeech() async {
    try {
      final available = await _speech.initialize(
        onStatus: (status) {
          if (status == 'notListening' && mounted) {
            setState(() {
              _isListening = false;
            });
          }
        },
        onError: (error) {
          debugPrint('[AssistantSheet] Speech error: $error');
        },
      );
      if (mounted) {
        setState(() {
          _isSpeechAvailable = available;
        });
      }
    } catch (e) {
      debugPrint('[AssistantSheet] Speech initialization failed: $e');
    }
  }

  Future<void> _startListening() async {
    if (!_isSpeechAvailable) {
      await _initSpeech();
    }
    if (_isSpeechAvailable) {
      setState(() {
        _isListening = true;
      });
      unawaited(HapticFeedback.mediumImpact());
      try {
        await _speech.listen(
          onResult: (result) {
            if (mounted) {
              setState(() {
                _chatController.text = result.recognizedWords;
              });
            }
          },
          listenOptions: stt.SpeechListenOptions(localeId: 'fa_IR'),
        );
      } catch (e) {
        debugPrint('[AssistantSheet] Speech listen error: $e');
      }
    }
  }

  Future<void> _stopListening() async {
    if (_isListening) {
      await _speech.stop();
      setState(() {
        _isListening = false;
      });
      unawaited(HapticFeedback.lightImpact());

      final text = _chatController.text.trim();
      if (text.isNotEmpty) {
        unawaited(_sendMessage(text));
      }
    }
  }

  Future<void> _loadOpeningMove() async {
    final brief = await PersonaContextProvider.getPrimaryBrief(widget.persona);
    final skills = PersonaSkill.getSkillsForPersona(widget.persona.id, brief);
    if (mounted) {
      setState(() {
        _primaryBrief = brief;
        _relevantSkills = skills;
      });
    }
  }

  Future<void> _checkLastPlan() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final recent = await db.query(
        'assistant_plans',
        where: 'status = ?',
        whereArgs: ['applied'],
        orderBy: 'createdAt DESC',
        limit: 1,
      );
      if (recent.isNotEmpty) {
        final plan = recent.first;
        final createdAt =
            (plan['createdAt'] as int?) ?? (plan['created_at'] as int?) ?? 0;
        final settingsRows = await db.query(
          'app_settings',
          where: 'key = ?',
          whereArgs: ['ai_undo_window_hours'],
          limit: 1,
        );
        final hours = settingsRows.isNotEmpty
            ? (int.tryParse(settingsRows.first['value']?.toString() ?? '24') ??
                  24)
            : 24;
        final limit = DateTime.now()
            .subtract(Duration(hours: hours))
            .millisecondsSinceEpoch;
        if (createdAt >= limit && mounted) {
          setState(() {
            _canUndoLast = true;
            _lastPlanId = plan['id'] as String;
          });
        }
      } else if (mounted) {
        setState(() {
          _canUndoLast = false;
          _lastPlanId = null;
        });
      }
    } catch (e, st) {
      debugPrint('[AssistantSheet] failed to check last plan: $e\n$st');
      if (mounted) {
        setState(() {
          _canUndoLast = false;
          _lastPlanId = null;
        });
      }
    }
  }

  String _getTodayJalaliString() {
    final now = Jalali.now();
    return '${now.year}/${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')}';
  }

  void _copyToClipboard(String content) {
    Clipboard.setData(ClipboardData(text: content));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('متن با موفقیت کپی شد 📋', style: TextStyle()),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _handleChatAction(ChatAction action) async {
    try {
      final assistantAction = action.toAssistantAction();
      await AssistantActionRegistry.executeAction(
        context,
        assistantAction,
        () {},
      );
    } catch (e) {
      debugPrint('[AssistantSheet] Error handling action: $e');
    }
  }

  Future<void> _sendMessage([String? quickQuery]) async {
    final query = (quickQuery ?? _chatController.text).trim();
    if (query.isEmpty) return;

    if (quickQuery == null) _chatController.clear();

    final userMsg = ChatMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}_u',
      sessionId: widget.persona.id,
      role: ChatRole.user,
      content: query,
      timestamp: DateTime.now(),
    );

    setState(() {
      _isTyping = true;
      _messages.add(userMsg);
    });

    _scrollToBottom();

    try {
      final briefJson = await PersonaContextProvider.getBriefJson(
        widget.persona,
      );
      final memorySuffix = await AssistantMemoryBinding.getSystemPromptSuffix(
        domain: widget.persona.id,
        query: query,
      );

      final todayJalali = _getTodayJalaliString();
      final systemPrompt = PersonaPromptBuilder.buildPrompt(
        persona: widget.persona,
        todayJalali: todayJalali,
        briefJson: briefJson,
        memoryBlock: memorySuffix,
      );

      final profile = PersonaInferenceProfile.getProfile(widget.persona.id);
      debugPrint(
        '[AssistantSheet] Persona profile maxTokens: ${profile.maxTokens}',
      );

      final recentHistory = _messages
          .where((m) => m.content.trim().isNotEmpty)
          .toList()
          .reversed
          .take(4)
          .toList()
          .reversed
          .map(
            (m) =>
                '${m.role == ChatRole.user ? "کاربر" : "دستیار"}: ${m.content}',
          )
          .toList();

      setState(() {
        _agentSteps.clear();
        _agentStatusText = 'در حال تحلیل هوشمند و بررسی ابزارها...';
        _isAgentWorking = true;
      });

      final agentStream = AgentLoopRunner.instance.runAgent(
        prompt: query,
        personaId: widget.persona.id,
        personaTitle: widget.persona.displayName,
        personaSystemPrompt: systemPrompt,
        contextSummary: briefJson,
        recentHistory: recentHistory.isNotEmpty ? recentHistory : null,
        slot: profile.slot,
        inferenceProfile: profile,
      );

      final assistantMsgId = 'msg_${DateTime.now().millisecondsSinceEpoch}_a';
      final assistantMsg = ChatMessage(
        id: assistantMsgId,
        sessionId: widget.persona.id,
        role: ChatRole.assistant,
        content: '',
        timestamp: DateTime.now(),
        isStreaming: true,
      );

      setState(() {
        _messages.add(assistantMsg);
        _isTyping = false;
        _isStreaming = true;
      });

      _presenter.reset();
      await _agentSubscription?.cancel();
      _agentSubscription = agentStream.listen(
        (event) {
          _presenter.apply(event);
          if (mounted) {
            setState(() {
              _agentStatusText = _presenter.statusTextFa;
              _isAgentWorking = _presenter.isWorking;
              _agentSteps
                ..clear()
                ..addAll(_presenter.steps);
              if (_messages.isNotEmpty && _messages.last.id == assistantMsgId) {
                _messages[_messages.length - 1] = ChatMessage(
                  id: assistantMsgId,
                  sessionId: widget.persona.id,
                  role: ChatRole.assistant,
                  content: _presenter.visibleText,
                  timestamp: DateTime.now(),
                  isStreaming: _isStreaming,
                );
              }
            });
            _scrollToBottom();
          }

          if (event is AgentCompletedEvent && mounted) {
            setState(() {
              _isStreaming = false;
              _isAgentWorking = false;
            });
          } else if (event is AgentErrorEvent) {
            if (_presenter.visibleText.isEmpty) {
              RitmoLog.warning(
                'AssistantSheet',
                'Agent error with empty response -> fallback to gateway stream. Reason: ${event.errorMessageFa}',
              );
              unawaited(
                _runGatewayFallback(
                  assistantMsgId: assistantMsgId,
                  systemPrompt: systemPrompt,
                  briefJson: briefJson,
                  recentHistory: recentHistory,
                  query: query,
                  slot: profile.slot,
                  maxTokens: profile.maxTokens,
                  temperature: profile.temperature,
                ),
              );
            } else if (mounted) {
              setState(() {
                _isStreaming = false;
                _isAgentWorking = false;
                if (_messages.isNotEmpty &&
                    _messages.last.id == assistantMsgId) {
                  _messages[_messages.length - 1] = ChatMessage(
                    id: assistantMsgId,
                    sessionId: widget.persona.id,
                    role: ChatRole.assistant,
                    content:
                        '${_presenter.visibleText}\n\n⚠️ [خطا]: ${event.errorMessageFa}',
                    timestamp: DateTime.now(),
                    isStreaming: false,
                  );
                }
              });
            }
          } else if (event is AgentConfirmationTimedOutEvent && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  event.messageFa,
                  style: const TextStyle(color: Colors.white),
                ),
                backgroundColor: Colors.orange.shade800,
                duration: const Duration(seconds: 4),
              ),
            );
          }
        },
        onDone: () {
          if (mounted) {
            setState(() {
              _isStreaming = false;
              _isAgentWorking = false;
            });
          }
        },
        onError: (err) {
          if (_presenter.visibleText.isEmpty) {
            RitmoLog.warning(
              'AssistantSheet',
              'Agent stream onError with empty response -> fallback to gateway stream. Reason: $err',
            );
            unawaited(
              _runGatewayFallback(
                assistantMsgId: assistantMsgId,
                systemPrompt: systemPrompt,
                briefJson: briefJson,
                recentHistory: recentHistory,
                query: query,
                slot: profile.slot,
                maxTokens: profile.maxTokens,
                temperature: profile.temperature,
              ),
            );
          } else if (mounted) {
            setState(() {
              _isStreaming = false;
              _isAgentWorking = false;
            });
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isTyping = false;
          _isStreaming = false;
        });
      }
    }
  }

  void _validateAndExecute(String fullResponse) {
    final manifestCmdIds = CommandManifest.asPromptBlock(
      personaId: widget.persona.id,
    );
    final validator = PersonaResponseValidator();

    final parsedAction = ChatActionParser.parse(fullResponse);
    final parsedResp = ParsedAssistantResponse(
      reply: fullResponse,
      confidence: BriefConfidence.medium,
      commands: parsedAction.actions
          .map(
            (a) =>
                ParsedCommand(id: a.type, payload: a.payload, labelFa: a.type),
          )
          .toList(),
    );

    final validation = validator.validate(
      res: parsedResp,
      persona: widget.persona,
      brief:
          _primaryBrief ??
          SleepBrief(
            sampleSize: 0,
            computedAt: DateTime.now(),
            avgDurationMinutes: 0,
            avgQuality: 0,
            sleepDebtMinutes: 0,
            consistencyScore: 0,
          ),
      manifestCommandIds: manifestCmdIds
          .split('\n')
          .map((l) => l.split(' ').first)
          .toList(),
    );

    if (!validation.isValid && validation.retryMessage != null) {
      debugPrint(
        '[PersonaResponseValidator] Validation Warning: ${validation.reason}',
      );
    }

    unawaited(_parseAndExecuteActions(fullResponse));
  }

  void _processMemoryOps(String rawAnswer) {
    final parsed = ChatActionParser.parse(rawAnswer);
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
            unawaited(AiMemoryService.instance.applyOperations(ops));
          }
        }
      } catch (e) {
        debugPrint('[MEMORY] Error processing assistant memory_ops JSON: $e');
      }
    }
  }

  Future<void> _runGatewayFallback({
    required String assistantMsgId,
    required String systemPrompt,
    required String? briefJson,
    required List<String> recentHistory,
    required String query,
    required AiSlot slot,
    int? maxTokens,
    double? temperature,
  }) async {
    final messages = <Map<String, String>>[
      {'role': 'system', 'content': systemPrompt},
      if (briefJson != null && briefJson.isNotEmpty)
        {
          'role': 'system',
          'content': '[اطلاعات پرونده و وضعیت کاربر]:\n$briefJson',
        },
      for (final h in recentHistory)
        {
          'role': h.startsWith('کاربر:') ? 'user' : 'assistant',
          'content': h.replaceFirst(RegExp(r'^(کاربر|دستیار):\s*'), ''),
        },
      {'role': 'user', 'content': query},
    ];

    var accumulated = '';
    try {
      await for (final chunk in AIGateway.instance.sendCustomChatStream(
        messages: messages,
        slot: slot,
        temperature: temperature,
        maxTokens: maxTokens,
      )) {
        if (chunk.startsWith('error:')) {
          if (mounted && accumulated.isEmpty) {
            setState(() {
              _isStreaming = false;
              _isAgentWorking = false;
              _messages[_messages.length - 1] = ChatMessage(
                id: assistantMsgId,
                sessionId: widget.persona.id,
                role: ChatRole.assistant,
                content:
                    'متأسفانه در حال حاضر خطایی در پردازش رخ داده است: ${chunk.substring(6)}',
                timestamp: DateTime.now(),
                isStreaming: false,
              );
            });
          }
          break;
        }
        accumulated += chunk;
        if (mounted) {
          setState(() {
            _messages[_messages.length - 1] = ChatMessage(
              id: assistantMsgId,
              sessionId: widget.persona.id,
              role: ChatRole.assistant,
              content: accumulated,
              timestamp: DateTime.now(),
              isStreaming: true,
            );
          });
          _scrollToBottom();
        }
      }
    } catch (e) {
      if (mounted && accumulated.isEmpty) {
        setState(() {
          _isStreaming = false;
          _isAgentWorking = false;
          _messages[_messages.length - 1] = ChatMessage(
            id: assistantMsgId,
            sessionId: widget.persona.id,
            role: ChatRole.assistant,
            content:
                'خطا در برقراری ارتباط با سرور هوش مصنوعی. لطفاً اتصال اینترنت/فیلترشکن را بررسی کنید 🔌',
            timestamp: DateTime.now(),
            isStreaming: false,
          );
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isStreaming = false;
          _isAgentWorking = false;
          if (accumulated.isNotEmpty) {
            _messages[_messages.length - 1] = ChatMessage(
              id: assistantMsgId,
              sessionId: widget.persona.id,
              role: ChatRole.assistant,
              content: accumulated,
              timestamp: DateTime.now(),
              isStreaming: false,
            );
          }
        });
        if (accumulated.isNotEmpty && !accumulated.startsWith('error:')) {
          _validateAndExecute(accumulated);
          _processMemoryOps(accumulated);
        }
      }
    }
  }

  String? _mapActionTypeToNewCommandId(AssistantActionType type) {
    switch (type) {
      case AssistantActionType.createRoutine:
        return 'routine.create';
      case AssistantActionType.createGoal:
        return 'goal.create';
      case AssistantActionType.logSleep:
        return 'sleep.log';
      case AssistantActionType.logEnergyMood:
        return 'energy.log';
      case AssistantActionType.addKonkurItem:
        return 'konkur.createTopic';
      case AssistantActionType.createCourse:
        return 'course.create';
      case AssistantActionType.openPage:
        return 'app.openPage';
      case AssistantActionType.updateSetting:
        return 'setting.update';
      case AssistantActionType.completeRoutine:
        return 'routine.complete';
      case AssistantActionType.skipRoutine:
        return 'routine.skip';
      case AssistantActionType.editRoutine:
        return 'routine.edit';
      case AssistantActionType.deleteRoutine:
        return 'routine.delete';
      case AssistantActionType.editGoal:
        return 'goal.edit';
      case AssistantActionType.completeGoalStep:
        return 'goal.completeStep';
      case AssistantActionType.createWorshipItem:
        return 'worship.create';
      case AssistantActionType.deleteWorshipItem:
        return 'worship.delete';
      case AssistantActionType.logReflection:
        return 'reflection.log';
      case AssistantActionType.rescheduleReminder:
        return 'routine.reschedule';
      default:
        return null;
    }
  }

  Future<void> _parseAndExecuteActions(String response) async {
    final parsed = ChatActionParser.parse(response);
    if (parsed.actions.isNotEmpty) {
      try {
        final steps = <PlanStep>[];
        for (final act in parsed.actions) {
          String? commandId = act.type;
          if (!commandId.contains('.')) {
            final actionType = AssistantActionType.tryFromString(act.type);
            if (actionType != null) {
              commandId = _mapActionTypeToNewCommandId(actionType);
            }
          }
          if (commandId != null) {
            steps.add(PlanStep(commandId: commandId, payload: act.payload));
          }
        }

        if (steps.isNotEmpty) {
          final plan = CommandPlan(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            titleFa: 'برنامه پیشنهادی دستیار',
            steps: steps,
          );

          final preview = await RitmoCommandBus.instance.preview(
            plan,
            personaId: widget.persona.id,
          );

          if (preview.blockers.isNotEmpty) {
            if (mounted) {
              setState(() {
                _messages.add(
                  ChatMessage(
                    id: 'msg_err_${DateTime.now().millisecondsSinceEpoch}',
                    sessionId: widget.persona.id,
                    role: ChatRole.assistant,
                    content:
                        'تعدادی خطا مانع اجرای این اقدام شد:\n${preview.blockers.join('\n')}',
                    timestamp: DateTime.now(),
                  ),
                );
              });
            }
            return;
          }

          final db = await DatabaseHelper.instance.database;
          final settingsRows = await db.query(
            'app_settings',
            where: 'key = ?',
            whereArgs: ['ai_agent_mode'],
            limit: 1,
          );
          final agentMode = settingsRows.isNotEmpty
              ? settingsRows.first['value']?.toString()
              : 'confirm';

          if (agentMode == 'suggest' ||
              agentMode == 'confirm' ||
              preview.needsBiometric) {
            if (mounted) _showPreviewSheet(plan, preview);
          } else {
            // Auto Mode
            final result = await RitmoCommandBus.instance.execute(
              plan,
              personaId: widget.persona.id,
              source: CommandSource.assistant,
            );
            if (result.success) {
              final stepTitles = plan.steps
                  .map(
                    (s) =>
                        '- ${RitmoCommandBus.instance.getCommand(s.commandId)?.humanTitle ?? s.commandId}',
                  )
                  .join('\n');
              if (mounted) {
                setState(() {
                  _messages.add(
                    ChatMessage(
                      id: 'msg_ok_${DateTime.now().millisecondsSinceEpoch}',
                      sessionId: widget.persona.id,
                      role: ChatRole.assistant,
                      content: 'اقدامات زیر با موفقیت اجرا شد:\n$stepTitles',
                      timestamp: DateTime.now(),
                    ),
                  );
                });
              }
              unawaited(_checkLastPlan());

              for (final res in result.results) {
                if (res.commandId == 'app.openPage' &&
                    res.outputData?['route'] != null) {
                  final route = res.outputData!['route']!.toString();
                  if (mounted)
                    unawaited(Navigator.of(context).pushNamed(route));
                }
                if (res.commandId == 'assistant.handoff' &&
                    res.outputData?['personaId'] != null) {
                  final target = res.outputData!['personaId']!.toString();
                  handoffTo(target);
                }
              }
            } else if (mounted) {
              setState(() {
                _messages.add(
                  ChatMessage(
                    id: 'msg_fail_${DateTime.now().millisecondsSinceEpoch}',
                    sessionId: widget.persona.id,
                    role: ChatRole.assistant,
                    content: 'خطا در اجرای اقدام: ${result.errorMessage}',
                    timestamp: DateTime.now(),
                  ),
                );
              });
            }
          }
        }
      } catch (e) {
        debugPrint('[AssistantSheet] Action parsing/dispatch error: $e');
      }
    }
  }

  void _showPreviewSheet(CommandPlan plan, PlanPreview preview) {
    RitmoSheetScaffold.present<void>(
      context: context,
      title: 'بررسی اقدامات پیشنهادی دستیار',
      maxHeightFactor: 0.8,
      childIsScrollable: true,
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (preview.needsBiometric) ...[
            const Text(
              '🔒 این اقدام حساس است و نیاز به تایید هویت بیومتریک دارد.',
              style: TextStyle(color: Colors.redAccent, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
          ],
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    Navigator.of(context).pop();
                    final result = await RitmoCommandBus.instance.execute(
                      plan,
                      personaId: widget.persona.id,
                      source: CommandSource.assistant,
                    );
                    if (result.success) {
                      final stepTitles = plan.steps
                          .map(
                            (s) =>
                                '- ${RitmoCommandBus.instance.getCommand(s.commandId)?.humanTitle ?? s.commandId}',
                          )
                          .join('\n');
                      if (mounted) {
                        setState(() {
                          _messages.add(
                            ChatMessage(
                              id: 'msg_ok_${DateTime.now().millisecondsSinceEpoch}',
                              sessionId: widget.persona.id,
                              role: ChatRole.assistant,
                              content:
                                  'اقدامات با موفقیت اجرا شد:\n$stepTitles',
                              timestamp: DateTime.now(),
                            ),
                          );
                        });
                      }
                      unawaited(_checkLastPlan());

                      for (final res in result.results) {
                        if (res.commandId == 'app.openPage' &&
                            res.outputData?['route'] != null) {
                          final route = res.outputData!['route']!.toString();
                          if (mounted) {
                            unawaited(Navigator.of(context).pushNamed(route));
                          }
                        }
                        if (res.commandId == 'assistant.handoff' &&
                            res.outputData?['personaId'] != null) {
                          final target = res.outputData!['personaId']!
                              .toString();
                          handoffTo(target);
                        }
                      }
                    } else if (mounted) {
                      setState(() {
                        _messages.add(
                          ChatMessage(
                            id: 'msg_fail_${DateTime.now().millisecondsSinceEpoch}',
                            sessionId: widget.persona.id,
                            role: ChatRole.assistant,
                            content:
                                'خطا در اجرای اقدام: ${result.errorMessage}',
                            timestamp: DateTime.now(),
                          ),
                        );
                      });
                    }
                  },
                  child: const Text('تایید و اجرا', style: TextStyle()),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('لغو', style: TextStyle()),
                ),
              ),
            ],
          ),
        ],
      ),
      builder: (sheetCtx) {
        final colors = context.colors;
        return ListView.builder(
          shrinkWrap: true,
          physics: const ClampingScrollPhysics(),
          itemCount: preview.diffs.length,
          itemBuilder: (context, index) {
            final diff = preview.diffs[index];
            return Card(
              color: colors.surfaceElevated,
              margin: const EdgeInsets.symmetric(vertical: 6),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      diff.entityLabelFa,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    if (diff.beforeFa != null || diff.afterFa != null) ...[
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          if (diff.beforeFa != null) ...[
                            Text(
                              diff.beforeFa!,
                              style: const TextStyle(color: Colors.red),
                            ),
                            const Icon(Icons.arrow_left),
                          ],
                          if (diff.afterFa != null)
                            Text(
                              diff.afterFa!,
                              style: const TextStyle(color: Colors.green),
                            ),
                        ],
                      ),
                    ],
                    if (diff.warningFa != null) ...[
                      const SizedBox(height: 5),
                      Text(
                        '⚠️ ${diff.warningFa}',
                        style: const TextStyle(
                          color: Colors.orange,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void handoffTo(String targetPersonaId) {
    final targetPersona = PersonaRegistry.instance.getPersona(targetPersonaId);
    if (targetPersona == null) return;

    Navigator.of(context).pop();
    AssistantSheet.show(
      context,
      persona: targetPersona,
      initialQuery:
          'سلام، از دستیار ${widget.persona.displayName} به این بخش منتقل شدم.',
    );
  }

  Future<void> _undoLastAction() async {
    if (_lastPlanId == null) return;
    setState(() {
      _isTyping = true;
    });
    final result = await RitmoCommandBus.instance.undoPlan(_lastPlanId!);
    if (mounted) {
      setState(() {
        _isTyping = false;
      });
    }

    if (result.success) {
      if (mounted) {
        setState(() {
          _messages.add(
            ChatMessage(
              id: 'msg_undo_ok_${DateTime.now().millisecondsSinceEpoch}',
              sessionId: widget.persona.id,
              role: ChatRole.assistant,
              content: 'آخرین اقدام با موفقیت لغو و بازیابی شد 🔄',
              timestamp: DateTime.now(),
            ),
          );
        });
      }
      unawaited(_checkLastPlan());
    } else if (mounted) {
      setState(() {
        _messages.add(
          ChatMessage(
            id: 'msg_undo_fail_${DateTime.now().millisecondsSinceEpoch}',
            sessionId: widget.persona.id,
            role: ChatRole.assistant,
            content: 'لغو آخرین اقدام با شکست مواجه شد: ${result.errorMessage}',
            timestamp: DateTime.now(),
          ),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDark;
    final isGlass = context.isGlassEnabled;
    final blur = context.glassBlurSigma.clamp(0.0, 50.0);
    const sheetRadius = BorderRadius.vertical(top: Radius.circular(28));

    final content = Column(
      children: [
        // Header with Glass Style & Avatar
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: colors.border)),
          ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onLongPress: () {
                            HapticFeedback.mediumImpact();
                            ChatGptMiniPreview.show(context);
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: colors.primary.withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  CupertinoIcons.sparkles,
                                  color: colors.primary,
                                  size: 15,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  widget.persona.displayName,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: colors.textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Flexible(
                                child: BridgeStatusChip(),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_canUndoLast) ...[
                        const SizedBox(width: 4),
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.orange,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          icon: const Icon(
                            CupertinoIcons.arrow_counterclockwise,
                            size: 14,
                          ),
                          label: const Text(
                            'لغو اقدام',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onPressed: () => unawaited(_undoLastAction()),
                        ),
                      ],
                      const SizedBox(width: 4),
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        icon: Icon(
                          CupertinoIcons.xmark_circle_fill,
                          color: colors.textSecondary.withValues(alpha: 0.6),
                          size: 24,
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),

                // Dynamic Opening Move Banner & Skill Chips
                if (_messages.isEmpty) ...[
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: isDark ? 0.10 : 0.07),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: colors.primary.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              CupertinoIcons.chart_bar_alt_fill,
                              size: 18,
                              color: colors.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'اطلاعات کلیدی پرونده (${_primaryBrief?.confidence.name ?? 'در حال محاسبه'})',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: colors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: _relevantSkills.map((skill) {
                            return ActionChip(
                              avatar: const Icon(
                                CupertinoIcons.bolt_fill,
                                size: 14,
                                color: Colors.amber,
                              ),
                              label: Text(
                                skill.labelFa,
                                style: const TextStyle(fontSize: 12),
                              ),
                              backgroundColor: isDark
                                  ? colors.surfaceElevated
                                  : Colors.white,
                              side: BorderSide(
                                color: isDark ? colors.border : colors.divider,
                              ),
                              onPressed: () =>
                                  unawaited(_sendMessage(skill.queryPrompt)),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ],

                // Messages List with Swipe to Delete (Dismissible) & StreamingMessageBubble
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      final msgId = msg.id;

                      return Dismissible(
                        key: ValueKey<String>(msgId),
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            CupertinoIcons.trash,
                            color: Colors.redAccent,
                            size: 20,
                          ),
                        ),
                        secondaryBackground: Container(
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            CupertinoIcons.trash,
                            color: Colors.redAccent,
                            size: 20,
                          ),
                        ),
                        onDismissed: (direction) {
                          final removedMsg = msg;
                          final removedIndex = index;
                          setState(() {
                            _messages.removeAt(removedIndex);
                          });

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text(
                                'پیام حذف شد.',
                                style: TextStyle(),
                              ),
                              action: SnackBarAction(
                                label: 'بازیابی',
                                textColor: Colors.amber,
                                onPressed: () {
                                  setState(() {
                                    if (removedIndex <= _messages.length) {
                                      _messages.insert(
                                        removedIndex,
                                        removedMsg,
                                      );
                                    } else {
                                      _messages.add(removedMsg);
                                    }
                                  });
                                  _scrollToBottom();
                                },
                              ),
                              duration: const Duration(seconds: 4),
                            ),
                          );
                        },
                        child: StreamingMessageBubble(
                          message: msg,
                          isLast: index == _messages.length - 1,
                          onAction: (action) =>
                              unawaited(_handleChatAction(action)),
                          onCopy: (content) => _copyToClipboard(content),
                        ),
                      );
                    },
                  ),
                ),

                if (_isTyping && !_isStreaming)
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: CupertinoActivityIndicator(),
                  ),

                // Live Agent Activity Timeline Visualizer
                AgentTimelineVisualizer(
                  steps: _agentSteps,
                  statusText: _agentStatusText,
                  isWorking: _isAgentWorking,
                ),

                // Agent Confirmation Card Host
                const AgentConfirmationHost(),

                // Chat Input Bar matching Main Assistant (Speech-to-Text mic + Glass Input + Circular Accent Send Button)
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                    child: Row(
                      children: [
                        if (!_isStreaming) ...[
                          GestureDetector(
                            onLongPressStart: (_) =>
                                unawaited(_startListening()),
                            onLongPressEnd: (_) => unawaited(_stopListening()),
                            onLongPressCancel: () =>
                                unawaited(_stopListening()),
                            child:
                                CircleAvatar(
                                      radius: 20,
                                      backgroundColor: _isListening
                                          ? Colors.redAccent
                                          : (isDark
                                                ? Colors.white.withValues(
                                                    alpha: 0.06,
                                                  )
                                                : Colors.black.withValues(
                                                    alpha: 0.04,
                                                  )),
                                      child: Icon(
                                        _isListening
                                            ? CupertinoIcons.mic_fill
                                            : CupertinoIcons.mic,
                                        color: _isListening
                                            ? Colors.white
                                            : colors.textPrimary,
                                        size: 18,
                                      ),
                                    )
                                    .animate(target: _isListening ? 1.0 : 0.0)
                                    .scale(
                                      begin: const Offset(1, 1),
                                      end: const Offset(1.15, 1.15),
                                      duration: 150.ms,
                                    )
                                    .then()
                                    .shake(hz: 3, curve: Curves.easeInOut),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.04)
                                  : Colors.black.withValues(alpha: 0.03),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.08)
                                    : Colors.black.withValues(alpha: 0.05),
                              ),
                            ),
                            child: TextField(
                              controller: _chatController,
                              minLines: 1,
                              maxLines: 4,
                              enabled: !_isStreaming,
                              style: TextStyle(
                                fontSize: 13,
                                color: colors.textPrimary,
                              ),
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                border: InputBorder.none,
                                hintText: _isStreaming
                                    ? 'دستیار در حال نوشتن است...'
                                    : 'گفتگو با دستیار ${widget.persona.displayName}...',
                                hintStyle: TextStyle(
                                  fontSize: 12,
                                  color: colors.textSecondary.withValues(
                                    alpha: 0.6,
                                  ),
                                ),
                              ),
                              onTap: () {
                                unawaited(
                                  ChatGptWebBridgeManager.instance
                                      .ensureBooted(),
                                );
                              },
                              onChanged: (val) {
                                if (val.isNotEmpty) {
                                  unawaited(
                                    ChatGptWebBridgeManager.instance
                                        .ensureBooted(),
                                  );
                                }
                              },
                              onSubmitted: (val) {
                                if (!_isStreaming) unawaited(_sendMessage());
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: _isStreaming
                              ? () {
                                  _streamSubscription?.cancel();
                                  setState(() {
                                    _isStreaming = false;
                                  });
                                }
                              : () => unawaited(_sendMessage()),
                          child: CircleAvatar(
                            radius: 20,
                            backgroundColor: _isStreaming
                                ? const Color(0xffEF4444)
                                : const Color(0xff5B8AF5),
                            child: Icon(
                              _isStreaming
                                  ? CupertinoIcons.stop_fill
                                  : CupertinoIcons.arrow_up,
                              color: Colors.white,
                              size: _isStreaming ? 14 : 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );

    final wrappedContent = Container(
      constraints: BoxConstraints(
        maxHeight: RitmoBreakpoints.sheetMaxHeight(context, factor: 0.9),
      ),
      child: content,
    );

    if (!isGlass) {
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: colors.surfaceElevated,
            borderRadius: sheetRadius,
            border: Border.all(
              color: isDark ? colors.border : colors.divider,
              width: 1.0,
            ),
          ),
          child: wrappedContent,
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: sheetRadius,
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.35)
                  : colors.primary.withValues(alpha: 0.08),
              offset: const Offset(0, -3),
              blurRadius: 16,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: sheetRadius,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.glassTint,
                borderRadius: sheetRadius,
                border: Border.all(
                  color: isDark
                      ? colors.border
                      : Colors.white.withValues(alpha: 0.70),
                  width: 1.0,
                ),
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: sheetRadius,
                  gradient: isDark
                      ? LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withValues(alpha: 0.14),
                            Colors.white.withValues(alpha: 0.04),
                            Colors.white.withValues(alpha: 0.0),
                          ],
                          stops: const [0.0, 0.03, 0.45],
                        )
                      : LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withValues(alpha: 0.75),
                            Colors.white.withValues(alpha: 0.20),
                            Colors.white.withValues(alpha: 0.0),
                          ],
                          stops: const [0.0, 0.03, 0.45],
                        ),
                ),
                child: wrappedContent,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
