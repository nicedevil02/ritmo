import 'dart:async';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:ritmo/core/ai/ai_context_builder.dart';
import 'package:ritmo/core/ai/ai_error_messages.dart';
import 'package:ritmo/core/ai/chat/chat_models.dart';
import 'package:ritmo/core/ai/chat/chat_repository.dart';
import 'package:ritmo/core/ai/chat/streaming_chat_service.dart';
import 'package:ritmo/core/ai/memory/ai_memory_service.dart';
import 'package:ritmo/core/ai/memory/memory_models.dart';
import 'package:ritmo/core/ai/web_bridge/chatgpt_mini_preview.dart';
import 'package:ritmo/core/ai/web_bridge/chatgpt_web_bridge_manager.dart';
import 'package:ritmo/core/ai/web_bridge/cloudflare_challenge_modal.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/ritmo_toast.dart';
import 'package:ritmo/core/ux/ritmo_haptics.dart';
import 'package:ritmo/features/assistant/logic/assistant_action_registry.dart';
import 'package:ritmo/features/assistant/logic/day_plan_composer.dart';
import 'package:ritmo/features/assistant/logic/day_plan_template_service.dart';
import 'package:ritmo/features/assistant/logic/day_plan_validator.dart';
import 'package:ritmo/features/assistant/logic/settings_action_guard.dart';
import 'package:ritmo/features/assistant/models/day_plan_models.dart';
import 'package:ritmo/features/assistant/presentation/widgets/ai_day_planner_preview_sheet.dart';
import 'package:ritmo/features/assistant/presentation/widgets/ai_weekly_planner_preview_sheet.dart';
import 'package:ritmo/features/chat/presentation/chat_session_list_screen.dart';
import 'package:ritmo/core/ai/agent/agent_event.dart';
import 'package:ritmo/core/ai/agent/agent_policy_gate.dart';
import 'package:ritmo/core/ai/agent/ui/agent_confirmation_card.dart';
import 'package:ritmo/core/ai/agent/ui/agent_stream_presenter.dart';
import 'package:ritmo/core/ai/web_bridge/bridge_status_chip.dart';
import 'package:ritmo/features/chat/presentation/widgets/agent_timeline_visualizer.dart';
import 'package:ritmo/features/chat/presentation/widgets/streaming_message_bubble.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:sqflite/sqflite.dart';

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key, this.sessionId, this.isTab = false});
  final String? sessionId;
  final bool isTab;

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final AgentStreamPresenter _presenter = AgentStreamPresenter();
  String? _sessionId;
  List<ChatMessage> _messages = [];
  bool _isLoading = false;

  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  StreamSubscription<StreamingChatEvent>? _sub;
  String? _streamingId;
  final List<AgentStep> _agentSteps = [];
  String _agentStatusText = '';
  bool _isAgentWorking = false;
  final Map<String, Timer> _pendingDeleteTimers = {};
  final Map<String, ChatMessage> _pendingDeletedMsgs = {};

  bool get _isStreaming => _sub != null || _isAgentWorking;

  DayPlanDraft? _pendingDayPlanDraft;
  List<String> _currentQuickReplies = [];
  bool _hasActiveDayPlanCommit = false;
  String? _dayPlanningStepMessage;

  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isSpeechAvailable = false;
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _sessionId = widget.sessionId;
    if (_sessionId != null) {
      _loadMessages();
    }
    _checkLastCommit();
    unawaited(_runLearningLoop());
    _initSpeech();
    ChatGptWebBridgeManager.instance.cloudflareNotifier.addListener(
      _handleCloudflarePrompt,
    );
  }

  void _handleCloudflarePrompt() {
    if (ChatGptWebBridgeManager.instance.cloudflareNotifier.value && mounted) {
      CloudflareChallengeModal.show(context);
    }
  }

  Future<void> _initSpeech() async {
    try {
      final available = await _speech.initialize(
        onStatus: (status) {
          debugPrint('Speech status: $status');
          if (status == 'notListening' && mounted) {
            setState(() {
              _isListening = false;
            });
          }
        },
        onError: (error) {
          debugPrint('Speech error: $error');
        },
      );
      if (mounted) {
        setState(() {
          _isSpeechAvailable = available;
        });
      }
    } catch (e) {
      debugPrint('Speech initialization failed: $e');
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
                _textController.text = result.recognizedWords;
              });
            }
          },
          listenOptions: stt.SpeechListenOptions(localeId: 'fa_IR'),
        );
      } catch (e) {
        debugPrint('Speech listen error: $e');
      }
    } else {
      if (mounted) {
        unawaited(
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('دسترسی میکروفون', textAlign: TextAlign.right),
              content: const Text(
                'تشخیص گفتار فعال نیست یا دسترسی میکروفون داده نشده است. لطفاً در تنظیمات دستگاه دسترسی را بررسی کنید.',
                textAlign: TextAlign.right,
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('فهمیدم'),
                ),
              ],
            ),
          ),
        );
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

      final text = _textController.text.trim();
      if (text.isNotEmpty) {
        unawaited(_send(text));
      }
    }
  }

  bool _isDayPlanQuery(String text) {
    final clean = text.trim().toLowerCase();
    if (clean.contains('روزم رو بچین') ||
        clean.contains('برنامه روز') ||
        clean.contains('بچین روزم را')) {
      return true;
    }

    final planningKeywords = [
      'بیدار',
      'خواب',
      'نماز',
      'صبحونه',
      'صبحانه',
      'ناهار',
      'شام',
      'کار',
      'سرکار',
      'بانک',
      'درس',
      'کتاب',
      'ورزش',
      'باشگاه',
      'پیاده',
      'دعا',
      'قرآن',
      'دوش',
      'حمام',
      'خرید',
      'کافه',
      'ملاقات',
      'جلسه',
    ];
    var count = 0;
    for (final kw in planningKeywords) {
      if (clean.contains(kw)) {
        count++;
      }
    }
    return count >= 3;
  }

  Future<void> _saveSystemConfirmationMessage(String text) async {
    if (_sessionId != null) {
      await ChatRepository.instance.addMessage(
        ChatMessage(
          id: 'dp_sys_${DateTime.now().millisecondsSinceEpoch}',
          sessionId: _sessionId!,
          role: ChatRole.assistant,
          content: text,
          timestamp: DateTime.now(),
        ),
      );
      await _loadMessages();
    }
  }

  Future<void> _checkLastCommit() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final oneDayAgo = nowMs - (24 * 3600 * 1000);
      final lastCommits = await db.query(
        'day_plan_commits',
        where: 'createdAt >= ?',
        whereArgs: [oneDayAgo],
        limit: 1,
      );
      if (mounted) {
        setState(() {
          _hasActiveDayPlanCommit = lastCommits.isNotEmpty;
        });
      }
    } catch (e) {
      debugPrint('Error checking last commit in chat screen: $e');
    }
  }

  Future<void> _runLearningLoop() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final now = DateTime.now().millisecondsSinceEpoch;
      final sevenDaysAgo = now - (7 * 24 * 3600 * 1000);

      final completions = await db.rawQuery(
        '''
        SELECT r.title, r.category, r.targetDurationMinutes, rc.durationMinutes
        FROM routine_completions rc
        JOIN routines r ON rc.routineId = r.id
        WHERE rc.createdAt >= ? AND rc.durationMinutes IS NOT NULL AND r.targetDurationMinutes IS NOT NULL
      ''',
        [sevenDaysAgo],
      );

      if (completions.isEmpty) return;

      final actualsByTitle = <String, List<int>>{};
      final targetsByTitle = <String, int>{};
      final categoryByTitle = <String, String>{};

      for (final c in completions) {
        final title = c['title']! as String;
        final target = c['targetDurationMinutes']! as int;
        final actual = c['durationMinutes']! as int;
        final category = c['category']! as String;

        if (target == 0 || actual == 0) continue;

        actualsByTitle.putIfAbsent(title, () => []).add(actual);
        targetsByTitle[title] = target;
        categoryByTitle[title] = category;
      }

      for (final title in actualsByTitle.keys) {
        final list = actualsByTitle[title]!;
        if (list.length < 3) continue;

        final avgActual = list.reduce((a, b) => a + b) ~/ list.length;
        final target = targetsByTitle[title]!;
        if ((avgActual - target).abs() >= 15) {
          final cleanTitle = title.trim();
          final fact =
              'کاربر معمولاً برای «$cleanTitle» به جای $target دقیقه، حدود $avgActual دقیقه زمان صرف می‌کند.';
          final consent = await ConsentProfile.loadFromDb();
          final existing = await AiMemoryService.instance.retrieve(
            domain: 'core',
            query: cleanTitle,
            consent: consent,
          );
          final hasFact = existing.any(
            (m) =>
                m.content.contains(cleanTitle) && m.content.contains('دقیقه'),
          );

          if (!hasFact) {
            await AiMemoryService.instance.applyOperations([
              MemoryOp(
                op: 'ADD',
                content: fact,
                type: MemoryType.preference,
                domain: 'core',
                importance: 5,
                sensitive: false,
              ),
            ]);
            debugPrint('[AI Learning Loop] Learned new fact: $fact');
          }
        }
      }
    } catch (e) {
      debugPrint('[AI Learning Loop] Error running learning loop: $e');
    }
  }

  void _showAuditLogSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (modalCtx) {
        final colors = modalCtx.colors;
        final isDark = modalCtx.isDark;
        final isGlass = modalCtx.isGlassEnabled;
        final blur = modalCtx.glassBlurSigma.clamp(0.0, 50.0);
        const sheetRadius = BorderRadius.vertical(top: Radius.circular(28));

        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return FutureBuilder<List<Map<String, dynamic>>>(
              future: DatabaseHelper.instance.database.then(
                (db) => db.query(
                  'assistant_audit_log',
                  orderBy: 'appliedAt DESC',
                  limit: 20,
                ),
              ),
              builder: (ctx, snapshot) {
                Widget innerContent;

                if (snapshot.connectionState == ConnectionState.waiting) {
                  innerContent = const SizedBox(
                    height: 200,
                    child: Center(child: CupertinoActivityIndicator()),
                  );
                } else {
                  final logs = snapshot.data ?? [];

                  innerContent = Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: colors.textSecondary.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: colors.primary.withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  CupertinoIcons.doc_text_search,
                                  color: colors.primary,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'دفتر ممیزی و تغییرات دستیار',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: colors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: Icon(
                              CupertinoIcons.xmark,
                              color: colors.textSecondary,
                              size: 20,
                            ),
                            onPressed: () => Navigator.pop(modalCtx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (logs.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          child: Center(
                            child: Text(
                              'هیچ تغییری توسط دستیار ثبت نشده است.',
                              style: TextStyle(
                                color: colors.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        )
                      else
                        Flexible(
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: logs.length,
                            separatorBuilder: (context, index) =>
                                Divider(color: colors.border, height: 1),
                            itemBuilder: (context, index) {
                              final log = logs[index];
                              final type = log['actionType']?.toString() ?? '';
                              final key = log['targetKey']?.toString() ?? '';
                              final oldValue = log['oldValue']?.toString() ?? '';
                              final newValue = log['newValue']?.toString() ?? '';
                              final appliedAt = log['appliedAt'] as int;

                              final date = DateTime.fromMillisecondsSinceEpoch(appliedAt);
                              final timeStr =
                                  '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

                              var actionLabel = type;
                              if (type == 'updateSetting') actionLabel = 'تغییر تنظیمات';
                              if (type == 'completeRoutine') actionLabel = 'انجام روتین';
                              if (type == 'skipRoutine') actionLabel = 'تعویق روتین';
                              if (type == 'editRoutine') actionLabel = 'ویرایش روتین';
                              if (type == 'deleteRoutine') actionLabel = 'حذف روتین';
                              if (type == 'editGoal') actionLabel = 'ویرایش هدف';
                              if (type == 'completeGoalStep') actionLabel = 'تکمیل گام هدف';

                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '$actionLabel - $key',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: colors.textPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            type == 'updateSetting'
                                                ? 'مقدار قبلی: $oldValue ➔ مقدار جدید: $newValue ($timeStr)'
                                                : 'تغییر: $newValue ($timeStr)',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: colors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (type == 'updateSetting' &&
                                        oldValue.isNotEmpty &&
                                        oldValue != 'null')
                                      TextButton(
                                        onPressed: () async {
                                          final success = await applySettingChange(
                                            key,
                                            oldValue,
                                          );
                                          if (success) {
                                            setModalState(() {});
                                          }
                                        },
                                        style: TextButton.styleFrom(
                                          foregroundColor: colors.primary,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 6),
                                          minimumSize: Size.zero,
                                          tapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        child: const Text(
                                          'بازگردانی',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  );
                }

                final sheetBody = Directionality(
                  textDirection: TextDirection.rtl,
                  child: Material(
                    type: MaterialType.transparency,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                      child: innerContent,
                    ),
                  ),
                );

                if (!isGlass) {
                  return Container(
                    constraints: BoxConstraints(
                      maxHeight: RitmoBreakpoints.sheetMaxHeight(
                        modalCtx,
                        factor: 0.85,
                      ),
                    ),
                    decoration: BoxDecoration(
                      color: colors.surfaceElevated,
                      borderRadius: sheetRadius,
                      border: Border.all(
                        color: isDark ? colors.border : colors.divider,
                        width: 1.0,
                      ),
                    ),
                    child: sheetBody,
                  );
                }

                return Container(
                  constraints: BoxConstraints(
                    maxHeight: RitmoBreakpoints.sheetMaxHeight(
                      modalCtx,
                      factor: 0.85,
                    ),
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
                                ? Colors.white.withValues(alpha: 0.18)
                                : Colors.white.withValues(alpha: 0.70),
                            width: 1.0,
                          ),
                        ),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: sheetRadius,
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.white.withValues(alpha: isDark ? 0.08 : 0.20),
                                Colors.white.withValues(alpha: 0.0),
                              ],
                              stops: const [0.0, 0.45],
                            ),
                          ),
                          child: sheetBody,
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    for (final timer in _pendingDeleteTimers.values) {
      timer.cancel();
    }
    for (final msgId in _pendingDeletedMsgs.keys) {
      ChatRepository.instance.deleteMessage(msgId);
    }
    _pendingDeleteTimers.clear();
    _pendingDeletedMsgs.clear();
    _cancelStreamSilent();
    AgentConfirmationBroker.instance.cancelAll();
    AgentQuestionBroker.instance.cancelAll();
    ChatGptWebBridgeManager.instance.cloudflareNotifier.removeListener(
      _handleCloudflarePrompt,
    );
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    if (_sessionId == null) return;
    setState(() => _isLoading = true);
    try {
      final list = await ChatRepository.instance.getMessages(_sessionId!);
      if (mounted) {
        setState(() {
          _messages = list;
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<bool> _ensureCloudConsent() async {
    final db = await DatabaseHelper.instance.database;
    final consentCheck = await db.query(
      'app_settings',
      where: 'key = ?',
      whereArgs: ['assistant_cloud_consent'],
    );

    if (consentCheck.isNotEmpty && consentCheck.first['value'] == 'true') {
      return true;
    }

    final genderCheck = await db.query(
      'app_settings',
      where: 'key = ?',
      whereArgs: ['user_gender'],
    );
    final gender =
        (genderCheck.isNotEmpty ? genderCheck.first['value'] : 'UNSET')
            .toString()
            .toUpperCase();
    final isMale = gender == 'MALE';

    final contentText = isMale
        ? 'دستیار هوشمند برای ارائه راهکارها و پاسخ‌های دقیق‌تر، نیاز دارد اطلاعات برنامه‌ریزی، روتین‌ها، اهداف، آمار خواب و انرژی و برخی تنظیمات رفتاری شما را به سرورهای ابری ارسال کند.\n\n'
              '🚨 توجه مهم:\n'
              '۱. اطلاعات پزشکی، داروها، دوز مصرفی و یادآورهای درمانی کاملاً ممنوع بوده و هرگز ارسال نمی‌شوند.\n'
              '۲. هر آیتمی که توسط شما به صورت «خصوصی» علامت‌گذاری شود، از دید دستیار پنهان خواهد ماند.\n\n'
              'آیا با ارسال این اطلاعات موافقید؟'
        : 'دستیار هوشمند برای ارائه راهکارها و پاسخ‌های دقیق‌تر، نیاز دارد اطلاعات برنامه‌ریزی، روتین‌ها، اهداف، آمار خواب و انرژی و برخی تنظیمات رفتاری شما را به سرورهای ابری ارسال کند.\n\n'
              '🚨 توجه مهم:\n'
              '۱. اطلاعات چرخه قاعدگی و هورمونی به هیچ وجه ارسال نمی‌شوند.\n'
              '۲. اطلاعات پزشکی، داروها، دوز مصرفی و یادآورهای درمانی کاملاً ممنوع بوده و هرگز ارسال نمی‌شوند.\n'
              '۳. هر آیتمی که توسط شما به صورت «خصوصی» علامت‌گذاری شود، از دید دستیار پنهان خواهد ماند.\n\n'
              'آیا با ارسال این اطلاعات موافقید؟';

    if (!mounted) return false;

    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final titleColor = isDark ? Colors.white : const Color(0xff1C1F2E);
        final textColor = isDark ? Colors.white70 : Colors.black87;
        final disagreeColor = isDark ? Colors.grey : Colors.black54;

        return Dialog(
          backgroundColor: Colors.transparent,
          child: RitmoTheme.glassCardLight(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'رضایت‌نامه ارسال اطلاعات به هوش مصنوعی ابری',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: titleColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      contentText,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.6,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: Text(
                            'عدم موافقت',
                            style: TextStyle(color: disagreeColor),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xff06B6D4),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'موافقت و پذیرش',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    if (accepted ?? false) {
      await db.insert('app_settings', {
        'key': 'assistant_cloud_consent',
        'value': 'true',
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      return true;
    }
    return false;
  }

  Future<void> _send(String text) async {
    if (text.trim().isEmpty || _isStreaming) return;

    final consentGranted = await _ensureCloudConsent();
    if (!consentGranted) return;

    if (_sessionId == null) {
      final s = await ChatRepository.instance.createSession();
      _sessionId = s.id;
    }

    // Intercept Day Planning query
    if (_isDayPlanQuery(text) || _pendingDayPlanDraft != null) {
      setState(() {
        _isLoading = true;
        _dayPlanningStepMessage = '🧠 در حال تحلیل و آغاز چیدمان برنامه...';
      });
      final todayStr = DateTime.now().toIso8601String().substring(0, 10);
      final tomorrowStr = DateTime.now()
          .add(const Duration(days: 1))
          .toIso8601String()
          .substring(0, 10);
      final targetDateStr = text.contains('فردا') ? tomorrowStr : todayStr;

      try {
        var queryToCompose = text;
        if (_pendingDayPlanDraft != null) {
          queryToCompose =
              'بر اساس سوال قبل که پاسخش این است: "$text"، کل برنامه روز را کامل کن و سوال دیگری نپرس.';
        }

        final result = await DayPlanComposer.compose(
          query: queryToCompose,
          targetDateStr: targetDateStr,
          onProgress: (step) {
            if (mounted) {
              setState(() {
                _dayPlanningStepMessage = step;
              });
            }
          },
        );
        if (result != null) {
          if (result.isTemplateApply) {
            final templateName = result.applyTemplateName!;
            final templateDate = result.applyTemplateDate!;
            final template = await DayPlanTemplateService.instance
                .getTemplateByName(templateName);
            if (template != null) {
              final draft = DayPlanDraft(
                planDate: templateDate,
                items: template.items,
                questions: [],
                suggestions: [],
              );
              final enriched = await DayPlanValidator.validateAndEnrich(
                draft: draft,
              );
              await DayPlanTemplateService.instance.recordTemplateUsage(
                template.id,
              );
              if (mounted) {
                AiDayPlannerPreviewSheet.show(
                  context,
                  initialDraft: enriched,
                  onSaved: () {
                    _checkLastCommit();
                    _saveSystemConfirmationMessage(
                      'برنامه روز شما با موفقیت ثبت شد ⚡',
                    );
                    _showTopToast(
                      'برنامه روز با موفقیت چیده شد 🗓',
                      CupertinoIcons.checkmark_circle,
                      context.colors.primary,
                      onUndo: () async {
                        await AssistantActionRegistry.undoLastDayPlanCommit(
                          context,
                        );
                        unawaited(_checkLastCommit());
                      },
                    );
                  },
                );
              }
            } else {
              _showTopToast(
                'قالب "$templateName" یافت نشد ❌',
                CupertinoIcons.exclamationmark_triangle,
                Colors.redAccent,
              );
            }
            setState(() {
              _isLoading = false;
              _dayPlanningStepMessage = null;
            });
            return;
          }

          if (result.isMultiDay) {
            setState(() {
              _pendingDayPlanDraft = null;
              _currentQuickReplies = [];
              _isLoading = false;
              _dayPlanningStepMessage = null;
            });

            // Save user query to session
            await ChatRepository.instance.addMessage(
              ChatMessage(
                id: 'dp_usr_multi_${DateTime.now().millisecondsSinceEpoch}',
                sessionId: _sessionId!,
                role: ChatRole.user,
                content: text,
                timestamp: DateTime.now(),
              ),
            );
            await _loadMessages();

            if (mounted) {
              AiWeeklyPlannerPreviewSheet.show(
                context,
                initialDrafts: result.multiDayDrafts!,
                onSaved: () {
                  _checkLastCommit();
                  _saveSystemConfirmationMessage(
                    'برنامه هفتگی شما با موفقیت ثبت شد ⚡',
                  );
                  _showTopToast(
                    'برنامه هفتگی با موفقیت ثبت شد 🗓',
                    CupertinoIcons.checkmark_circle,
                    context.colors.primary,
                    onUndo: () async {
                      await AssistantActionRegistry.undoLastDayPlanCommit(
                        context,
                      );
                      unawaited(_checkLastCommit());
                    },
                  );
                },
              );
            }
            return;
          }

          final draft = result.singleDraft;
          if (draft != null) {
            if (draft.questions.isNotEmpty && _pendingDayPlanDraft == null) {
              // Save query and response to session first
              await ChatRepository.instance.addMessage(
                ChatMessage(
                  id: 'dp_usr_${DateTime.now().millisecondsSinceEpoch}',
                  sessionId: _sessionId!,
                  role: ChatRole.user,
                  content: text,
                  timestamp: DateTime.now(),
                ),
              );
              final question = draft.questions.first;
              await ChatRepository.instance.addMessage(
                ChatMessage(
                  id: 'dp_ast_${DateTime.now().millisecondsSinceEpoch}',
                  sessionId: _sessionId!,
                  role: ChatRole.assistant,
                  content: question.text,
                  timestamp: DateTime.now(),
                ),
              );
              await _loadMessages();

              setState(() {
                _pendingDayPlanDraft = draft;
                _currentQuickReplies = question.quickReplies;
                _isLoading = false;
                _dayPlanningStepMessage = null;
              });
              _scrollToBottom();
              return;
            } else if (draft.items.isNotEmpty) {
              // Clear pending draft/replies
              setState(() {
                _pendingDayPlanDraft = null;
                _currentQuickReplies = [];
                _isLoading = false;
                _dayPlanningStepMessage = null;
              });

              // Save user query to session
              await ChatRepository.instance.addMessage(
                ChatMessage(
                  id: 'dp_usr2_${DateTime.now().millisecondsSinceEpoch}',
                  sessionId: _sessionId!,
                  role: ChatRole.user,
                  content: text,
                  timestamp: DateTime.now(),
                ),
              );
              await _loadMessages();

              if (mounted) {
                AiDayPlannerPreviewSheet.show(
                  context,
                  initialDraft: draft,
                  onSaved: () {
                    _checkLastCommit();
                    _saveSystemConfirmationMessage(
                      'برنامه روز شما با موفقیت ثبت شد ⚡',
                    );
                    _showTopToast(
                      'برنامه روز با موفقیت چیده شد 🗓',
                      CupertinoIcons.checkmark_circle,
                      context.colors.primary,
                      onUndo: () async {
                        await AssistantActionRegistry.undoLastDayPlanCommit(
                          context,
                        );
                        unawaited(_checkLastCommit());
                      },
                    );
                  },
                );
              }
              return;
            }
          }
        }
      } catch (e) {
        debugPrint('[AiChatScreen] DayPlanComposer error: $e');
      }

      setState(() {
        _isLoading = false;
        _dayPlanningStepMessage = null;
      });

      if (!mounted) return;

      _showTopToast(
        'برای چیدمان برنامه روز، لطفاً کارهای امروزتان را بنویسید (مثلاً: ۹ تا ۱۷ سرکارم)',
        CupertinoIcons.info,
        context.colors.primary,
      );
      return;
    }

    _textController.clear();
    final consent = await ConsentProfile.loadFromDb();

    _presenter.reset();
    setState(() {
      _agentSteps.clear();
      _agentStatusText = 'در حال تحلیل هوشمند و بررسی ابزارها...';
      _isAgentWorking = true;
    });

    _sub = StreamingChatService()
        .send(
          sessionId: _sessionId!,
          userText: text,
          consent: consent,
          personaId: 'global',
        )
        .listen(
          _onEvent,
          onError: (err) {
            _onError(err.toString());
          },
          onDone: () {
            setState(() {
              _sub = null;
              _streamingId = null;
              _isAgentWorking = false;
            });
          },
        );

    setState(() {});
  }

  void _onEvent(StreamingChatEvent e) {
    if (e is UserMessageSaved) {
      setState(() {
        _messages.add(e.message);
      });
      _scrollToBottom();
    } else if (e is AssistantStarted) {
      setState(() {
        _streamingId = e.messageId;
        _messages.add(
          ChatMessage(
            id: e.messageId,
            sessionId: _sessionId!,
            role: ChatRole.assistant,
            content: '',
            timestamp: DateTime.now(),
            isStreaming: true,
          ),
        );
      });
      _scrollToBottom();
    } else if (e is ChatChunk) {
      final idx = _messages.indexWhere((m) => m.id == _streamingId);
      if (idx != -1) {
        setState(() {
          _messages[idx] = _messages[idx].copyWith(content: e.accumulated);
        });
      }
      _scrollToBottom();
    } else if (e is AgentStreamEvent) {
      final event = e.agentEvent;
      _presenter.apply(event);
      setState(() {
        _agentStatusText = _presenter.statusTextFa;
        _isAgentWorking = _presenter.isWorking;
        _agentSteps
          ..clear()
          ..addAll(_presenter.steps);
      });

      if (event is AgentConfirmationTimedOutEvent && mounted) {
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
    } else if (e is ChatComplete) {
      final idx = _messages.indexWhere((m) => m.id == e.messageId);
      if (idx != -1) {
        setState(() {
          _messages[idx] = _messages[idx].copyWith(
            content: e.content,
            actions: e.actions,
            isStreaming: false,
            isPartial: e.isPartial,
          );
        });
      }
      setState(() {
        _sub = null;
        _streamingId = null;
        _isAgentWorking = false;
      });
      _scrollToBottom();
    } else if (e is ChatErrorEvent) {
      setState(() {
        _isAgentWorking = false;
      });
      final errText = e.code.isNotEmpty
          ? e.code
          : (e.message.isNotEmpty
                ? e.message
                : 'خطایی در ارتباط با دستیار رخ داد.');
      _onError(errText);
    } else if (e is ChatCancelled) {
      setState(() {
        _isAgentWorking = false;
      });
      _cancelStream();
    }
  }

  void _onError(String errorText) {
    final idx = _messages.indexWhere((m) => m.id == _streamingId);
    if (idx != -1) {
      setState(() {
        final currentContent = _messages[idx].content;

        String friendlySummary = AiErrorMessages.fa(exception: errorText);
        String suggestedSteps = '''
💡 **راهکار پیشنهادشده:**
۱. اتصال اینترنت و فعال بودن فیلترشکن خود را بررسی کنید.
۲. از چرخ‌دنده بالای صفحه، تنظیمات هوش مصنوعی را باز کرده و ارائه‌دهنده یا مدل دیگری (مانند OpenRouter یا Zhipu AI) انتخاب نمایید.''';

        if (errorText.contains('vpnRequired') ||
            errorText.contains('Unable to load site') ||
            errorText.contains('تحریم یا فیلترینگ') ||
            errorText.contains('مسدود است')) {
          friendlySummary =
              'دسترسی به چت‌جی‌پی‌تی از این IP مسدود است (تحریم یا فیلترینگ 🛡️).\nبرای ادامه کار، لازم است فیلترشکن (VPN) یا تحریم‌شکن (مثل شکن / الکترون) خود را فعال کنید.';
          suggestedSteps = '''
💡 **راهکار حل مشکل تحریم و فیلترینگ ChatGPT:**
۱. فیلترشکن (VPN) خود را روشن کرده و سرور اروپا (مانند هلند یا آلمان) را انتخاب کنید.
۲. یا در تنظیمات وای‌فای/شبکه گوشی، DNS ضدتحریم (شکن: 178.22.122.100 و 185.51.200.2) را تنظیم کنید.
۳. روی چیپ وضعیت بالای صفحه ضربه زده و گزینه «تلاش مجدد و بارگذاری دوباره» را بزنید.''';
        } else if (errorText.contains('no_api_key') ||
            errorText.contains('401') ||
            errorText.contains('quota_exhausted')) {
          friendlySummary =
              'کلید دسترسی (API Key) یا سهمیه هوش مصنوعی فعال نیست 🔌\nلطفاً وارد تنظیمات پروفایل (چرخ‌دنده بالای صفحه) -> «تنظیمات هوش مصنوعی (AI)» شوید و ارائه‌دهنده یا API Key خود را بررسی کنید.';
        } else if (errorText.contains('authRequired')) {
          friendlySummary =
              'نشست ورود به حساب کاربری منقضی شده است یا نیاز به ورود به چت‌جی‌پی‌تی دارید 🔑.';
        } else if (errorText.contains('cloudflareChallenge')) {
          friendlySummary = 'تأیید هویت امنیتی کلودفلر ضروری است 🛡️.';
        } else if (errorText.contains('429')) {
          friendlySummary =
              'سقف تعداد درخواست‌های لحظه‌ای پر شده است (Rate Limit). لطفاً چند لحظه دیگر دوباره تلاش کنید.';
        } else if (errorText.toLowerCase().contains('timeout')) {
          friendlySummary =
              'زمان انتظار برای پاسخ سرور هوش مصنوعی به پایان رسید (Timeout ⏱️). سرور در مهلت مقرر ۱۲۰ ثانیه پاسخ نداد.';
        }

        final cleanDetails = errorText.trim().isEmpty
            ? 'اطلاعات بیشتری از خطای شبکه یا سرور دریافت نشد.'
            : errorText;

        final formattedBox =
            '''
⚠️ **خطا در ارتباط با سرور هوش مصنوعی**

📌 **تحلیل خطا:**
$friendlySummary

🔍 **علت دقیق و جزئیات فنی خطا:**
`$cleanDetails`

$suggestedSteps''';

        final String finalContent = currentContent.isEmpty
            ? formattedBox
            : '$currentContent\n\n$formattedBox';

        _messages[idx] = _messages[idx].copyWith(
          content: finalContent,
          isStreaming: false,
        );
      });
    }
    setState(() {
      _sub = null;
      _streamingId = null;
    });
    _scrollToBottom();
  }

  Future<void> _cancelStream() async {
    if (_sub == null && !_isAgentWorking) return;

    final subToCancel = _sub;
    final streamingIdToCancel = _streamingId;

    setState(() {
      _sub = null;
      _streamingId = null;
      _isAgentWorking = false;
      _isLoading = false;
    });

    // 1. Immediately cancel the web bridge generation and stop the ChatGPT DOM in the WebView
    ChatGptWebBridgeManager.instance.cancelCurrentStream();

    try {
      await subToCancel?.cancel();
    } catch (e) {
      debugPrint('Error cancelling stream: $e');
    }

    final targetId = streamingIdToCancel;
    final idx = targetId != null
        ? _messages.indexWhere((m) => m.id == targetId)
        : _messages.indexWhere((m) => m.isStreaming);

    if (idx != -1) {
      final current = _messages[idx];
      if (current.content.trim().isNotEmpty) {
        final saved = current.copyWith(
          content: '${current.content}\n\n[پاسخ‌دهی توسط کاربر متوقف شد 🛑]',
          isStreaming: false,
        );
        await ChatRepository.instance.addMessage(saved);
        if (mounted) {
          setState(() {
            _messages[idx] = saved;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _messages.removeAt(idx);
          });
        }
      }
    }
  }

  void _cancelStreamSilent() {
    if (_sub == null && !_isAgentWorking) return;
    final subToCancel = _sub;
    final targetId = _streamingId;

    _sub = null;
    _streamingId = null;
    _isAgentWorking = false;
    _isLoading = false;

    // Immediately cancel the web bridge generation
    ChatGptWebBridgeManager.instance.cancelCurrentStream();

    subToCancel?.cancel();

    final idx = targetId != null
        ? _messages.indexWhere((m) => m.id == targetId)
        : _messages.indexWhere((m) => m.isStreaming);

    if (idx != -1) {
      final current = _messages[idx];
      if (current.content.trim().isNotEmpty) {
        final saved = current.copyWith(
          content: '${current.content}\n\n[توسط کاربر متوقف شد 🛑]',
          isStreaming: false,
        );
        ChatRepository.instance.addMessage(saved);
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _handleAction(ChatAction action) async {
    RitmoHaptics.confirm();
    final assistantAction = action.toAssistantAction();
    await AssistantActionRegistry.executeAction(
      context,
      assistantAction,
      () {},
    );
  }

  void _copyToClipboard(String content) {
    Clipboard.setData(ClipboardData(text: content));
    _showTopToast(
      'متن پیام کپی شد.',
      Icons.check_circle_rounded,
      const Color(0xff10B981),
    );
  }

  void _showTopToast(
    String message,
    IconData icon,
    Color iconColor, {
    VoidCallback? onUndo,
  }) {
    RitmoToast.show(
      context,
      message,
      icon: icon,
      iconColor: iconColor,
      onUndo: onUndo,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isKeyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final topPadding = MediaQuery.paddingOf(context).top;
    final contentTopPadding = topPadding + 76.0;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: RitmoTheme.buildBackgroundContainer(
        context: context,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            children: [
              // Layer 1: Body Content
              Positioned.fill(
                child: Column(
                  children: [
                    if (_hasActiveDayPlanCommit)
                      Container(
                        width: double.infinity,
                        color: colors.primary.withValues(alpha: 0.08),
                        margin: EdgeInsets.only(top: contentTopPadding),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                  child: Row(
                    children: [
                      Icon(
                        CupertinoIcons.info_circle,
                        size: 16,
                        color: colors.primary,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'برنامه جدید چیده شده است. مایلید تغییرات ۲۴ ساعت گذشته را بازگردانید؟',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          await AssistantActionRegistry.undoLastDayPlanCommit(
                            context,
                          );
                          unawaited(_checkLastCommit());
                        },
                        child: Text(
                          'بازگردانی (Undo)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: colors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              // Chat messages stream
              Expanded(
                child: _isLoading
                    ? _buildDayPlanningLoadingState(colors)
                    : _messages.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                CupertinoIcons.sparkles,
                                size: 44,
                                color: colors.textSecondary.withValues(
                                  alpha: 0.5,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'چگونه می‌توانم به ارتقای ریتم روزانه‌ات کمک کنم؟',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  color: colors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton.icon(
                                onPressed: () => _send('روزم رو بچین'),
                                icon: const Icon(
                                  CupertinoIcons.calendar_badge_plus,
                                  size: 18,
                                ),
                                label: const Text(
                                  'روزم رو بچین ✨',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: colors.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 0,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
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

                              // Defer DB deletion for 5s
                              _pendingDeletedMsgs[msgId] = removedMsg;
                              final t = Timer(
                                const Duration(seconds: 5),
                                () async {
                                  await ChatRepository.instance.deleteMessage(
                                    msgId,
                                  );
                                  _pendingDeleteTimers.remove(msgId);
                                  _pendingDeletedMsgs.remove(msgId);
                                },
                              );
                              _pendingDeleteTimers[msgId] = t;

                              _showTopToast(
                                'پیام حذف شد.',
                                CupertinoIcons.trash,
                                Colors.redAccent,
                                onUndo: () {
                                  _pendingDeleteTimers[msgId]?.cancel();
                                  _pendingDeleteTimers.remove(msgId);
                                  _pendingDeletedMsgs.remove(msgId);
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
                              );
                            },
                            child: StreamingMessageBubble(
                              message: msg,
                              isLast: index == _messages.length - 1,
                              onAction: _handleAction,
                              onCopy: _copyToClipboard,
                            ),
                          );
                        },
                      ),
              ),

              if (_currentQuickReplies.isNotEmpty)
                Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  margin: const EdgeInsets.only(bottom: 6),
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _currentQuickReplies.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final text = _currentQuickReplies[index];
                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            RitmoHapticsPolicy.selection();
                            _send(text);
                          },
                          borderRadius: BorderRadius.circular(RitmoRadius.pill),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: colors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(
                                RitmoRadius.pill,
                              ),
                              border: Border.all(
                                color: colors.primary.withValues(alpha: 0.25),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.bolt_rounded,
                                  size: 14,
                                  color: colors.primary,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  text,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: colors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

              // Live Agent Activity Timeline Visualizer
              AgentTimelineVisualizer(
                steps: _agentSteps,
                statusText: _agentStatusText,
                isWorking: _isAgentWorking,
              ),

              // Agent Confirmation Card Host
              const AgentConfirmationHost(),

              // 2026 Floating Chat Input Bar
              Builder(
                builder: (context) {
                  final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
                  final rawViewInset = MediaQueryData.fromView(
                    View.of(context),
                  ).viewInsets.bottom;
                  final keyboardVisible =
                      isKeyboardOpen || keyboardInset > 0 || rawViewInset > 0;
                  final bottomInset = MediaQuery.paddingOf(context).bottom;
                  final navH = context.metrics.navBarHeight;
                  final effectiveBottomPadding = keyboardVisible
                      ? 8.0
                      : (widget.isTab
                            ? (navH + bottomInset + 16.0)
                            : 16.0);

                  return SafeArea(
                    bottom: !widget.isTab && !keyboardVisible,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        16,
                        8,
                        16,
                        effectiveBottomPadding,
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? colors.surfaceElevated
                              : colors.surface,
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: isDark
                                ? colors.borderSubtle.withValues(alpha: 0.6)
                                : colors.borderSubtle,
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(
                                alpha: isDark ? 0.25 : 0.05,
                              ),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (!_isStreaming) ...[
                              GestureDetector(
                                onLongPressStart: (_) => _startListening(),
                                onLongPressEnd: (_) => _stopListening(),
                                onLongPressCancel: _stopListening,
                                child:
                                    Container(
                                          width: 40,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            color: _isListening
                                                ? colors.error
                                                : colors.primary.withValues(
                                                    alpha: 0.08,
                                                  ),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            _isListening
                                                ? CupertinoIcons.mic_fill
                                                : CupertinoIcons.mic,
                                            color: _isListening
                                                ? Colors.white
                                                : colors.primary,
                                            size: 20,
                                          ),
                                        )
                                        .animate(
                                          target: _isListening ? 1.0 : 0.0,
                                        )
                                        .scale(
                                          begin: const Offset(1, 1),
                                          end: const Offset(1.15, 1.15),
                                          duration: 150.ms,
                                        )
                                        .then()
                                        .shake(hz: 3, curve: Curves.easeInOut),
                              ),
                              const SizedBox(width: 4),
                            ],
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                child: TextField(
                                  controller: _textController,
                                  minLines: 1,
                                  maxLines: 4,
                                  enabled: !_isStreaming,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    color: colors.textPrimary,
                                  ),
                                  decoration: InputDecoration(
                                    contentPadding: const EdgeInsets.symmetric(
                                      vertical: 10,
                                    ),
                                    isDense: true,
                                    border: InputBorder.none,
                                    hintText: _isStreaming
                                        ? 'دستیار در حال نوشتن است...'
                                        : 'گفتگو با دستیار ریتمو...',
                                    hintStyle: TextStyle(
                                      fontSize: 12.5,
                                      color: colors.textSecondary.withValues(
                                        alpha: 0.55,
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
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                RitmoHapticsPolicy.tap();
                                if (_isStreaming) {
                                  _cancelStream();
                                } else {
                                  _send(_textController.text);
                                }
                              },
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: _isStreaming
                                        ? [
                                            colors.error,
                                            colors.error.withValues(
                                              alpha: 0.85,
                                            ),
                                          ]
                                        : [
                                            colors.primary,
                                            colors.primary.withValues(
                                              alpha: 0.88,
                                            ),
                                          ],
                                  ),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          (_isStreaming
                                                  ? colors.error
                                                  : colors.primary)
                                              .withValues(alpha: 0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  _isStreaming
                                      ? CupertinoIcons.stop_fill
                                      : CupertinoIcons.arrow_up,
                                  color: Colors.white,
                                  size: _isStreaming ? 15 : 20,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),

        // Layer 2: Floating Capsule Header Island
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
              child: _buildCapsuleHeader(context, isDark, colors),
            ),
          ),
        ),
      ],
    ),
  ),
),
);
}

  Widget _buildCapsuleHeader(
    BuildContext context,
    bool isDark,
    RitmoColors colors,
  ) {
    return RitmoGlassHeader(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
              children: [
                if (!widget.isTab && Navigator.canPop(context))
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 38,
                      minHeight: 38,
                    ),
                    icon: Icon(
                      CupertinoIcons.arrow_right,
                      color: isDark ? Colors.white : const Color(0xFF1D2129),
                      size: 20,
                    ),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      Navigator.pop(context);
                    },
                  )
                else
                  const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onLongPress: () {
                      HapticFeedback.mediumImpact();
                      ChatGptMiniPreview.show(context);
                    },
                    child: Row(
                      children: [
                        Text(
                          'دستیار هوشمند',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 17.5,
                            letterSpacing: -0.4,
                            color: isDark ? Colors.white : const Color(0xFF1D2129),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: colors.primary.withValues(alpha: isDark ? 0.22 : 0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: colors.primary.withValues(alpha: isDark ? 0.35 : 0.25),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                CupertinoIcons.sparkles,
                                size: 11,
                                color: colors.primary,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                'Pro',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: colors.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const BridgeStatusChip(),
                _buildHeaderActionButton(
                  icon: CupertinoIcons.clock,
                  iconColor: isDark ? const Color(0xFF9096A2) : const Color(0xFF6B7280),
                  isDark: isDark,
                  tooltip: 'تغییرات و ممیزی دستیار',
                  onTap: () => _showAuditLogSheet(context),
                ),
                _buildHeaderActionButton(
                  icon: CupertinoIcons.chat_bubble_2_fill,
                  iconColor: colors.primary,
                  isDark: isDark,
                  tooltip: 'تاریخچه گفتگوها',
                  onTap: () {
                    Navigator.push<String>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ChatSessionListScreen(),
                      ),
                    ).then((selectedId) {
                      if (selectedId != null) {
                        setState(() {
                          _sessionId = selectedId;
                        });
                        _loadMessages();
                      }
                    });
                  },
                ),
                const SizedBox(width: 2),
              ],
            ),
    );
  }

  Widget _buildHeaderActionButton({
    required IconData icon,
    required Color iconColor,
    required bool isDark,
    required VoidCallback onTap,
    String? tooltip,
    bool isAiButton = false,
  }) {
    final button = GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: _buildHeaderActionButtonContent(
        icon: icon,
        iconColor: iconColor,
        isDark: isDark,
        isAiButton: isAiButton,
      ),
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip, child: button);
    }
    return button;
  }

  Widget _buildHeaderActionButtonContent({
    required IconData icon,
    required Color iconColor,
    required bool isDark,
    bool isAiButton = false,
  }) {
    return Container(
      width: 36,
      height: 36,
      margin: const EdgeInsets.symmetric(horizontal: 3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDark
            ? (isAiButton
                ? iconColor.withValues(alpha: 0.18)
                : const Color(0xFF22262E))
            : (isAiButton
                ? iconColor.withValues(alpha: 0.12)
                : const Color(0xFFF3F5F8)),
        border: Border.all(
          color: isDark
              ? (isAiButton
                  ? iconColor.withValues(alpha: 0.40)
                  : Colors.white.withValues(alpha: 0.08))
              : (isAiButton
                  ? iconColor.withValues(alpha: 0.30)
                  : Colors.white.withValues(alpha: 0.90)),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.white.withValues(alpha: 0.04)
                : Colors.white.withValues(alpha: 0.95),
            offset: const Offset(-2, -2),
            blurRadius: 4,
          ),
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.55)
                : const Color(0xFFB5C0CD).withValues(alpha: 0.65),
            offset: const Offset(2, 2),
            blurRadius: 4,
          ),
          if (isAiButton)
            BoxShadow(
              color: iconColor.withValues(alpha: isDark ? 0.35 : 0.22),
              blurRadius: 10,
              spreadRadius: 1.0,
            ),
        ],
      ),
      child: Center(
        child: Icon(
          icon,
          size: 18,
          color: isAiButton
              ? iconColor
              : (isDark ? const Color(0xFF9096A2) : const Color(0xFF6B7280)),
        ),
      ),
    );
  }

  Widget _buildDayPlanningLoadingState(RitmoColors colors) {
    final stepMsg =
        _dayPlanningStepMessage ?? 'در حال پردازش و استخراج لایه‌ها...';
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 28),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: colors.card.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: const Color(0xff06B6D4).withValues(alpha: 0.35),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xff06B6D4).withValues(alpha: 0.15),
              blurRadius: 30,
              spreadRadius: 4,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xff06B6D4).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(
                  strokeWidth: 3.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xff06B6D4)),
                ),
              ),
            ),
            const SizedBox(height: 22),
            Text(
              'در حال تنظیم هوشمند برنامه روز',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                stepMsg,
                key: ValueKey<String>(stepMsg),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: Color(0xff06B6D4),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
