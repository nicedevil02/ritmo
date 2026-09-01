import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ritmo/core/ai/ai_gateway.dart';
import 'package:ritmo/core/ai/chat/chat_action_parser.dart';
import 'package:ritmo/core/ai/chat/chat_models.dart';
import 'package:ritmo/core/ai/chat/chat_repository.dart';
import 'package:ritmo/core/ai/memory/assistant_memory_binding.dart';
import 'package:ritmo/core/ai/web_bridge/chatgpt_web_bridge_manager.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/markdown_parser.dart';
import 'package:ritmo/core/utils/ritmo_toast.dart';
import 'package:ritmo/features/assistant/logic/assistant_action_registry.dart';

/// Full-featured Smart AI Coach Sheet for Supplementary Sports (ورزش و حرکت).
/// Connects to AIGateway streaming, ChatRepository, Cognitive Memory,
/// and executes actionable workout modifications via AssistantActionRegistry.
class SSAiCoachSheet extends StatefulWidget {
  const SSAiCoachSheet({super.key});

  static String? prefilledMessage;

  static Future<void> show(BuildContext context, {String? prefilledMessage}) {
    SSAiCoachSheet.prefilledMessage = prefilledMessage;
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const SSAiCoachSheet(),
    );
  }

  @override
  State<SSAiCoachSheet> createState() => _SSAiCoachSheetState();
}

class _SSAiCoachSheetState extends State<SSAiCoachSheet> {
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<Map<String, dynamic>> _messages = [];
  bool _isTyping = false;
  bool _isStreaming = false;
  String _sportsContext = '';
  String? _sessionId;
  List<ChatSession> _sessions = [];
  StreamSubscription<String>? _sportsSubscription;
  final Map<String, Timer> _pendingDeleteTimers = {};
  final Map<String, Map<String, dynamic>> _pendingDeletedMsgs = {};

  @override
  void initState() {
    super.initState();
    _loadSportsContext().then((_) => _loadActiveSession()).then((_) {
      if (SSAiCoachSheet.prefilledMessage != null) {
        final msg = SSAiCoachSheet.prefilledMessage!;
        SSAiCoachSheet.prefilledMessage = null;
        _sendMessage(msg);
      }
    });
  }

  @override
  void dispose() {
    if (_sessionId != null) {
      unawaited(
        AssistantMemoryBinding.triggerConsolidation(
          sessionId: _sessionId!,
          domain: 'sports',
        ),
      );
    }
    for (final timer in _pendingDeleteTimers.values) {
      timer.cancel();
    }
    for (final msgId in _pendingDeletedMsgs.keys) {
      unawaited(ChatRepository.instance.deleteMessage(msgId));
    }
    _pendingDeleteTimers.clear();
    _pendingDeletedMsgs.clear();
    _sportsSubscription?.cancel();
    _chatController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Builds a rich, dynamic sports context from user profile and prescriptions.
  Future<void> _loadSportsContext() async {
    try {
      final db = await DatabaseHelper.instance.database;

      // 1. Fetch user profile
      final profileRows = await db.query('ss_user_profile', limit: 1);
      final profile = profileRows.isNotEmpty ? profileRows.first : null;

      // 2. Fetch current week's prescriptions (slots)
      final prescriptions = await db.query(
        'ss_session_prescription',
        orderBy: 'dateIso ASC',
        limit: 14,
      );

      // 3. Fetch exercises map
      final exercises = await db.query('ss_exercise', limit: 50);
      final exMap = {
        for (final ex in exercises) ex['id'].toString(): ex['name']?.toString() ?? '',
      };

      // 4. Fetch legacy workout plans & crossrefs if any
      final plans = await db.query('ss_workout_plan');
      final crossRefs = await db.query('ss_workout_exercise_crossref');

      final buffer = StringBuffer();
      buffer.writeln('پرونده ورزشی کاربر:');

      if (profile != null) {
        final goal = profile['goal']?.toString() ?? 'تناسب اندام عمومی';
        final exp = profile['experienceLevel']?.toString() ?? 'مبتدی';
        final loc = profile['trainingLocation']?.toString() ?? 'خانه';
        final equip = profile['availableEquipment']?.toString() ?? 'بدون وسیله';
        final days = profile['daysPerWeek']?.toString() ?? '۳';
        final dur = profile['sessionDuration']?.toString() ?? '۳۰';
        final limits = profile['physicalLimitations']?.toString() ?? 'ندارد';
        final limitNote = profile['limitationNote']?.toString();
        final neighbor = profile['neighborFriendly'] == 1;

        buffer.writeln('- هدف فیتنس: $goal');
        buffer.writeln('- سطح تجربه: $exp');
        buffer.writeln('- محل تمرین: $loc');
        buffer.writeln('- تجهیزات در دسترس: $equip');
        buffer.writeln('- روزهای تمرین در هفته: $days');
        buffer.writeln('- مدت زمان هر جلسه: $dur دقیقه');
        buffer.writeln('- محدودیت‌های بدنی: $limits');
        if (limitNote != null && limitNote.isNotEmpty) {
          buffer.writeln('- یادداشت محدودیت: $limitNote');
        }
        buffer.writeln('- وضعیت تمرین بی‌صدا (آپارتمانی): ${neighbor ? "فعال" : "غیرفعال"}');
      }

      buffer.writeln('\nبرنامهٔ جلسات هفتهٔ جاری (اسلات‌های تجویزی):');
      if (prescriptions.isEmpty && plans.isEmpty) {
        buffer.writeln('هیچ برنامهٔ تمرینی برای این هفته ثبت نشده است.');
      } else {
        for (final p in prescriptions) {
          final dateIso = p['dateIso']?.toString() ?? '';
          final slotType = p['slotType']?.toString() ?? '';
          final headline = p['headlineFa']?.toString() ?? '';
          final targetMin = p['targetMinutes']?.toString() ?? '0';
          final isRest = slotType.toUpperCase() == 'REST';
          final status = p['status']?.toString() ?? 'PLANNED';

          if (isRest) {
            buffer.writeln('- تاریخ $dateIso: روز استراحت و ریکاوری ($status)');
          } else {
            buffer.writeln('- تاریخ $dateIso: $headline ($slotType، $targetMin دقیقه، وضعیت: $status)');
          }
        }

        if (crossRefs.isNotEmpty) {
          buffer.writeln('\nحرکات برنامه‌ریزی‌شده در جلسات:');
          for (final c in crossRefs) {
            final exId = c['exerciseId']?.toString() ?? '';
            final exName = exMap[exId] ?? exId;
            final sets = c['targetSets'] ?? 3;
            final reps = c['targetReps'] ?? 10;
            buffer.writeln('  - $exName (شناسه: $exId) - $sets ست، $reps تکرار');
          }
        }
      }

      if (mounted) {
        setState(() {
          _sportsContext = buffer.toString();
        });
      }
    } catch (e) {
      debugPrint('Error loading AI sports context: $e');
    }
  }

  Future<void> _loadActiveSession() async {
    try {
      _sessions = await ChatRepository.instance.listSessions(chatType: 'sports');
      if (_sessions.isEmpty) {
        final newSess = await ChatRepository.instance.createSession(chatType: 'sports');
        _sessions = [newSess];
        _sessionId = newSess.id;
        final initMsg = ChatMessage(
          id: 'init_${DateTime.now().millisecondsSinceEpoch}',
          sessionId: _sessionId!,
          role: ChatRole.assistant,
          content:
              'سلام! من مربی هوشمند ریتمو هستم. چطور می‌توانم در تنظیم حرکات ورزشی، بهبود برنامه تمرینی، تغذیه ورزشی یا بهینه‌سازی مدت جلسات کمکتان کنم؟ 🏃‍♂️',
          timestamp: DateTime.now(),
        );
        await ChatRepository.instance.addMessage(initMsg);
      } else {
        _sessionId = _sessions.first.id;
      }
      await _loadMessages();
    } catch (e) {
      debugPrint('Error loading active session: $e');
    }
  }

  Future<void> _loadMessages() async {
    if (_sessionId == null) return;
    final msgs = await ChatRepository.instance.getMessages(_sessionId!);
    if (!mounted) return;
    setState(() {
      _messages.clear();
      for (final m in msgs) {
        _messages.add({
          'id': m.id,
          'role': m.role.name,
          'content': m.content,
          'actions': m.actions,
        });
      }
    });
    _scrollToBottom();
  }

  Future<void> _startNewSession() async {
    try {
      final newSess = await ChatRepository.instance.createSession(chatType: 'sports');
      _sessionId = newSess.id;
      _sessions = await ChatRepository.instance.listSessions(chatType: 'sports');
      final initMsg = ChatMessage(
        id: 'init_${DateTime.now().millisecondsSinceEpoch}',
        sessionId: _sessionId!,
        role: ChatRole.assistant,
        content:
            'سلام! من مربی هوشمند ریتمو هستم. چطور می‌توانم در تنظیم حرکات ورزشی، بهبود برنامه تمرینی، تغذیه ورزشی یا بهینه‌سازی مدت جلسات کمکتان کنم؟ 🏃‍♂️',
        timestamp: DateTime.now(),
      );
      await ChatRepository.instance.addMessage(initMsg);
      await _loadMessages();
    } catch (e) {
      debugPrint('Error starting new session: $e');
    }
  }

  void _cancelStreaming() {
    ChatGptWebBridgeManager.instance.cancelCurrentStream();
    _sportsSubscription?.cancel();
    _sportsSubscription = null;
    setState(() {
      _isStreaming = false;
      _isTyping = false;
    });
  }

  Future<void> _handleAction(ChatAction action) async {
    await HapticFeedback.mediumImpact();
    if (!mounted) return;

    if (action.type == 'openPage' && action.targetRoute != null) {
      unawaited(Navigator.pushNamed(context, action.targetRoute!));
      return;
    }

    var detailText = '';
    if (action.type == 'swapExercise') {
      final oldId = action.payload['oldExerciseId']?.toString() ?? '';
      final newId = action.payload['newExerciseId']?.toString() ?? '';
      final db = await DatabaseHelper.instance.database;
      final oldEx = await db.query('ss_exercise', where: 'id = ?', whereArgs: [oldId], limit: 1);
      final newEx = await db.query('ss_exercise', where: 'id = ?', whereArgs: [newId], limit: 1);
      final oldName = oldEx.isNotEmpty ? oldEx.first['name']! as String : 'حرکت فعلی';
      final newName = newEx.isNotEmpty ? newEx.first['name']! as String : 'حرکت جدید';
      detailText = 'تعویض حرکت "$oldName" با حرکت مشابه "$newName"';
    } else if (action.type == 'adjustWorkoutIntensity') {
      final dur = action.payload['sessionDuration']?.toString();
      final intensity = action.payload['intensity']?.toString();
      final parts = <String>[];
      if (dur != null) parts.add('مدت زمان جلسه: $dur دقیقه');
      if (intensity != null) parts.add('شدت/سطح برنامه: $intensity');
      detailText = 'به‌روزرسانی تنظیمات برنامه (${parts.join(' و ')})';
    } else {
      detailText = action.label;
    }

    if (!mounted) return;

    // Canonical Ritmo Confirmation Dialog
    final confirmed = await RitmoDialog.show(
      context,
      title: 'تأیید تغییرات برنامه',
      content: 'آیا مایل به اعمال تغییرات پیشنهادی مربی هوشمند هستید؟\n\n$detailText',
      confirmLabel: 'تأیید و اعمال',
      cancelLabel: 'انصراف',
      icon: CupertinoIcons.sparkles,
      isDestructive: false,
    );

    if (!mounted || confirmed != true) return;

    await AssistantActionRegistry.executeAction(
      context,
      action.toAssistantAction(),
      _loadSportsContext,
    );
  }

  Future<void> _sendMessage([String? quickQuery]) async {
    final query = quickQuery ?? _chatController.text.trim();
    if (query.isEmpty) return;

    if (quickQuery == null) {
      _chatController.clear();
    }

    if (_sessionId == null) return;

    setState(() {
      _isTyping = true;
    });

    final userMsg = ChatMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}_u',
      sessionId: _sessionId!,
      role: ChatRole.user,
      content: query,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add({
        'id': userMsg.id,
        'role': 'user',
        'content': query,
        'actions': const [],
      });
    });

    _scrollToBottom();

    await ChatRepository.instance.addMessage(userMsg);

    try {
      final systemPrompt = '''
شما مربی هوشمند، دلسوز و مجرب ورزشی در برنامه ریتمو هستید.
وظیفه شما پاسخ‌گویی به سوالات ورزشی، تناسب اندام، تغذیه ورزشی و کمک به کاربر در بهبود و تنظیم برنامه‌های ورزشی و حرکات تکمیلی است.
لحن شما باید بسیار مشوق، گرم، باانگیزه، علمی و مثبت باشد.

قوانین سخت‌گیرانه ایمنی و سلامتی:
۱. در صورت بروز هرگونه درد حاد، سوزش، مصدومیت یا احساس ناراحتی شدید در مفاصل و عضلات، بلافاصله از کاربر بخواهید تمرین را متوقف کرده و به پزشک مراجعه کند. از ارائه هرگونه تشخیص پزشکی، تجویز دارو یا درمان‌های تخصصی خودداری فرمایید.
۲. شما اجازه تجویز رژیم‌های دارویی، استروئیدی، پپتیدها یا مکمل‌های تخصصی پزشکی را ندارید؛ صرفاً می‌توانید توصیه‌های کلی و عمومی در مورد تغذیه ورزشی (مانند پروتئین کافی، کربوهیدرات برای انرژی و هیدراتاسیون) ارائه دهید.
۳. پیشنهاد تعویض حرکات یا تنظیم سختی فقط و فقط باید روی اطلاعات واقعی کاربر انجام شود. از شناسه‌های فرضی استفاده نکنید.

عملیات هوشمند (Actions):
هر زمان کاربر از شما خواست حرکتی را تعویض کند یا سختی تمرین را افزایش/کاهش دهد، در انتهای پاسخ خود تگ <actions> حاوی یک آرایه JSON شامل عملیات مناسب را قرار دهید.

فرمت تگ <actions>:
۱. تعویض حرکت:
<actions>
[
  {
    "type": "swapExercise",
    "label": "جایگزینی حرکت شنا با شنا زانو",
    "payload": {
      "oldExerciseId": "<شناسه حرکت قدیمی>",
      "newExerciseId": "<شناسه حرکت جدید>"
    }
  }
]
</actions>

۲. تنظیم شدت و مدت جلسه:
<actions>
[
  {
    "type": "adjustWorkoutIntensity",
    "label": "تعدیل تنظیمات شدت برنامه تمرینی",
    "payload": {
      "sessionDuration": "30",
      "intensity": "LIGHT"
    }
  }
]
</actions>

۳. حالت آپارتمانی بی‌صدا:
<actions>
[
  {
    "type": "setQuietMode",
    "label": "فعال‌سازی حالت تمرین بدون صدا",
    "payload": {
      "on": true
    }
  }
]
</actions>

۴. هدایت به سایر بخش‌های ریتمو:
<actions>
[
  {
    "type": "openPage",
    "label": "مشاهده صفحه خواب",
    "targetRoute": "/sleep"
  }
]
</actions>

پرونده ورزشی کاربر:
$_sportsContext
''';

      final memorySuffix = await AssistantMemoryBinding.getSystemPromptSuffix(
        domain: 'sports',
        query: query,
      );

      final messagesToSend = <Map<String, String>>[
        {'role': 'system', 'content': systemPrompt + memorySuffix},
        ..._messages.map((m) => {'role': m['role'] as String, 'content': m['content'] as String}),
      ];

      final stream = AIGateway.instance.sendCustomChatStream(messages: messagesToSend);

      if (mounted) {
        final assistantMsgId = 'msg_${DateTime.now().millisecondsSinceEpoch}_a';
        final msgIndex = _messages.length;
        setState(() {
          _messages.add({
            'id': assistantMsgId,
            'role': 'assistant',
            'content': '',
            'actions': const [],
          });
          _isTyping = false;
          _isStreaming = true;
        });
        _scrollToBottom();

        var currentText = '';

        _sportsSubscription = stream.listen(
          (chunk) async {
            if (!mounted) return;

            if (chunk.startsWith('error:')) {
              final errorMsg = chunk.substring(6);
              setState(() {
                if (currentText.isEmpty) {
                  if (errorMsg == 'quota_exceeded') {
                    _messages[msgIndex]['content'] =
                        'سهمیهٔ روزانه هوش مصنوعی شما برای امروز به پایان رسیده است ⚠️';
                  } else {
                    _messages[msgIndex]['content'] =
                        'خطایی در برقراری ارتباط با مدل هوش مصنوعی رخ داده است. لطفاً اتصال اینترنت خود را بررسی نمایید 🔌';
                  }
                } else {
                  _messages[msgIndex]['content'] =
                      '$currentText\n\n⚠️ [اتصال موقتاً قطع شد]';
                }
              });
              _cancelStreaming();
              return;
            }

            currentText += chunk;
            final tempParsed = ChatActionParser.parse(currentText);
            setState(() {
              _messages[msgIndex]['content'] = tempParsed.cleanText;
              _messages[msgIndex]['actions'] = tempParsed.actions;
            });
            _scrollToBottom();
          },
          onError: (e) {
            _cancelStreaming();
          },
          onDone: () async {
            if (mounted) {
              final parsed = ChatActionParser.parse(currentText);

              // Process cognitive memory updates
              await AssistantMemoryBinding.processResponse(
                sessionId: _sessionId!,
                domain: 'sports',
                userText: query,
                rawResponse: currentText,
              );

              setState(() {
                _isStreaming = false;
                final idx = _messages.indexWhere((m) => m['id'] == assistantMsgId);
                if (idx != -1) {
                  _messages[idx]['content'] = parsed.cleanText;
                  _messages[idx]['actions'] = parsed.actions;
                }
              });

              final assistantMsg = ChatMessage(
                id: assistantMsgId,
                sessionId: _sessionId!,
                role: ChatRole.assistant,
                content: parsed.cleanText,
                timestamp: DateTime.now(),
                actions: parsed.actions,
              );
              await ChatRepository.instance.addMessage(assistantMsg);

              // Reload sports context to ensure next turn includes updated memories
              await _loadSportsContext();

              final updated = await ChatRepository.instance.listSessions(chatType: 'sports');
              setState(() {
                _sessions = updated;
              });
            }
          },
          cancelOnError: true,
        );
      }
    } catch (e) {
      debugPrint('Error calling AI Sports API: $e');
      if (mounted) {
        setState(() {
          _messages.add({
            'role': 'assistant',
            'content':
                'متاسفانه در حال حاضر خطایی در ارتباط با سرور هوش مصنوعی رخ داده است. لطفاً اتصال خود را بررسی کنید 🔌',
          });
          _isTyping = false;
          _isStreaming = false;
        });
      }
    }

    _scrollToBottom();
  }

  void _copyToClipboard(String content) {
    Clipboard.setData(ClipboardData(text: content));
    RitmoToast.show(
      context,
      'متن پیام کپی شد',
      icon: Icons.check_circle_rounded,
      iconColor: context.colors.primary,
    );
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

  void _showSessionSelector() {
    final colors = context.colors;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: RitmoGlassSheet(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'تاریخچهٔ گفتگوهای مربیگری',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: colors.textPrimary,
                          ),
                        ),
                        IconButton(
                          tooltip: 'گفتگوی جدید',
                          icon: Icon(CupertinoIcons.add, color: colors.primary, size: 22),
                          onPressed: () {
                            Navigator.pop(context);
                            _startNewSession();
                          },
                        ),
                      ],
                    ),
                    Divider(color: colors.border),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: RitmoBreakpoints.usableHeight(context) * 0.4,
                      ),
                      child: _sessions.isEmpty
                          ? Center(
                              child: Text(
                                'گفتگویی یافت نشد',
                                style: TextStyle(color: colors.textSecondary),
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              itemCount: _sessions.length,
                              itemBuilder: (context, index) {
                                final sess = _sessions[index];
                                final isSelected = sess.id == _sessionId;
                                return ListTile(
                                  selected: isSelected,
                                  selectedColor: colors.primary,
                                  title: Text(
                                    sess.summary ?? 'گفتگوی مربیگری',
                                    style: const TextStyle(fontSize: 13.5),
                                  ),
                                  subtitle: Text(
                                    '${sess.messageCount} پیام',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: colors.textSecondary.withValues(alpha: 0.6),
                                    ),
                                  ),
                                  trailing: IconButton(
                                    tooltip: 'حذف',
                                    icon: const Icon(
                                      CupertinoIcons.trash,
                                      size: 16,
                                      color: Colors.redAccent,
                                    ),
                                    onPressed: () async {
                                      await ChatRepository.instance.deleteSession(sess.id);
                                      final updated = await ChatRepository.instance.listSessions(
                                        chatType: 'sports',
                                      );
                                      setSheetState(() {
                                        _sessions = updated;
                                      });
                                      if (sess.id == _sessionId) {
                                        if (updated.isNotEmpty) {
                                          _sessionId = updated.first.id;
                                          await _loadMessages();
                                        } else {
                                          await _loadActiveSession();
                                        }
                                      }
                                    },
                                  ),
                                  onTap: () {
                                    Navigator.pop(context);
                                    setState(() {
                                      _sessionId = sess.id;
                                    });
                                    _loadMessages();
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: RitmoBreakpoints.sheetMaxHeight(context, factor: 0.94),
        ),
        child: RitmoGlassSheet(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          padding: EdgeInsets.fromLTRB(
            16,
            12,
            16,
            MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            children: [
              // Top Drag Handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.border.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Symmetrical Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(CupertinoIcons.sparkles, color: colors.primary, size: 22),
                      const SizedBox(width: 8),
                      Text(
                        'مربی هوشمند ریتمو',
                        style: TextStyle(
                          fontSize: 17.5,
                          fontWeight: FontWeight.bold,
                          color: colors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          CupertinoIcons.chat_bubble_2,
                          color: colors.textSecondary,
                          size: 20,
                        ),
                        tooltip: 'تاریخچه گفتگوها',
                        onPressed: _showSessionSelector,
                      ),
                      IconButton(
                        tooltip: 'بستن',
                        icon: Icon(CupertinoIcons.xmark, color: colors.textSecondary, size: 20),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ],
              ),
              Divider(color: colors.divider, height: 16),

              // Chat Messages List
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  itemCount: _messages.length,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemBuilder: (context, index) {
                    final msg = _messages[index];
                    final msgId = (msg['id'] ?? 'temp_${index}_${msg['role']}').toString();
                    return Dismissible(
                      key: ValueKey<String>(msgId),
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(CupertinoIcons.trash, color: Colors.redAccent, size: 20),
                      ),
                      secondaryBackground: Container(
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(CupertinoIcons.trash, color: Colors.redAccent, size: 20),
                      ),
                      onDismissed: (direction) {
                        final removedMsg = Map<String, dynamic>.from(msg);
                        final removedIndex = index;
                        final msgId = removedMsg['id'] as String?;

                        setState(() {
                          _messages.removeAt(removedIndex);
                        });

                        if (msgId != null) {
                          _pendingDeletedMsgs[msgId] = removedMsg;
                          final t = Timer(const Duration(seconds: 5), () async {
                            await ChatRepository.instance.deleteMessage(msgId);
                            _pendingDeleteTimers.remove(msgId);
                            _pendingDeletedMsgs.remove(msgId);
                          });
                          _pendingDeleteTimers[msgId] = t;
                        }

                        RitmoToast.show(
                          context,
                          'پیام حذف شد.',
                          icon: CupertinoIcons.trash,
                          iconColor: Colors.redAccent,
                          onUndo: msgId != null
                              ? () {
                                  _pendingDeleteTimers[msgId]?.cancel();
                                  _pendingDeleteTimers.remove(msgId);
                                  _pendingDeletedMsgs.remove(msgId);
                                  setState(() {
                                    if (removedIndex <= _messages.length) {
                                      _messages.insert(removedIndex, removedMsg);
                                    } else {
                                      _messages.add(removedMsg);
                                    }
                                  });
                                  _scrollToBottom();
                                }
                              : null,
                        );
                      },
                      child: SportsMessageBubble(
                        msg: msg,
                        isStreaming: _isStreaming,
                        colors: colors,
                        onCopy: () => _copyToClipboard(msg['content'] as String),
                        onActionPressed: _handleAction,
                      ),
                    );
                  },
                ),
              ),

              if (_isTyping)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(width: 32),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: colors.surfaceElevated,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(20),
                              topRight: Radius.circular(20),
                              bottomLeft: Radius.circular(4),
                              bottomRight: Radius.circular(20),
                            ),
                            border: Border.all(color: colors.border),
                          ),
                          child: const _TypingIndicator(),
                        ),
                      ],
                    ),
                  ),
                ),

              // Quick Action Chips (shown on welcome state)
              if (_messages.length <= 1 && !_isTyping) ...[
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  reverse: true,
                  child: Row(
                    children: [
                      _buildQuickActionChip('📉 این هفته را سبک‌تر کن'),
                      const SizedBox(width: 8),
                      _buildQuickActionChip('🔄 یک حرکت جایگزین بده'),
                      const SizedBox(width: 8),
                      _buildQuickActionChip('🍎 تغذیه بعد تمرین چی باشه؟'),
                      const SizedBox(width: 8),
                      _buildQuickActionChip('🔇 ورزش بدون پرش و بی‌صدا'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Input Row
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: colors.surfaceElevated,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: colors.border),
                        ),
                        child: TextField(
                          controller: _chatController,
                          minLines: 1,
                          maxLines: 4,
                          enabled: !_isTyping,
                          style: TextStyle(
                            fontSize: 13.5,
                            color: colors.textPrimary,
                          ),
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            border: InputBorder.none,
                            hintText: _isStreaming
                                ? 'مربی در حال تایپ است...'
                                : 'سوالی درباره ورزش بپرسید یا برنامه‌ای بخواهید...',
                            hintStyle: TextStyle(
                              fontSize: 12.5,
                              color: colors.textSecondary.withValues(alpha: 0.6),
                            ),
                          ),
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: _isStreaming ? _cancelStreaming : _sendMessage,
                      child: CircleAvatar(
                        radius: 20,
                        backgroundColor: _isStreaming ? const Color(0xffEF4444) : colors.primary,
                        child: Icon(
                          _isStreaming ? CupertinoIcons.stop_fill : CupertinoIcons.arrow_up,
                          color: Colors.white,
                          size: _isStreaming ? 14 : 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionChip(String text) {
    final colors = context.colors;
    return GestureDetector(
      onTap: () => _sendMessage(text),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: colors.surfaceElevated,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class SportsMessageBubble extends StatefulWidget {
  const SportsMessageBubble({
    super.key,
    required this.msg,
    required this.isStreaming,
    required this.colors,
    required this.onCopy,
    this.onActionPressed,
  });

  final Map<String, dynamic> msg;
  final bool isStreaming;
  final RitmoColors colors;
  final VoidCallback onCopy;
  final ValueChanged<ChatAction>? onActionPressed;

  @override
  State<SportsMessageBubble> createState() => _SportsMessageBubbleState();
}

class _SportsMessageBubbleState extends State<SportsMessageBubble> {
  bool _isCopied = false;
  Timer? _copiedTimer;

  @override
  void dispose() {
    _copiedTimer?.cancel();
    super.dispose();
  }

  void _handleCopy() {
    widget.onCopy();
    _copiedTimer?.cancel();
    setState(() {
      _isCopied = true;
    });
    _copiedTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isCopied = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isUser = widget.msg['role'] == 'user';
    final colors = widget.colors;

    final bubbleBg = isUser ? colors.primary : colors.surfaceElevated;

    final showCopy = !widget.isStreaming && widget.msg['content'].toString().isNotEmpty;

    final copyButton = GestureDetector(
      onTap: _handleCopy,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
          child: Icon(
            _isCopied ? CupertinoIcons.checkmark_alt : CupertinoIcons.doc_on_doc,
            key: ValueKey<bool>(_isCopied),
            size: 15,
            color: _isCopied
                ? const Color(0xff10B981)
                : colors.textSecondary.withValues(alpha: 0.45),
          ),
        ),
      ),
    );

    final actionsList = (widget.msg['actions'] as List?)?.cast<ChatAction>() ?? const [];

    Widget? actionsSection;
    if (actionsList.isNotEmpty) {
      actionsSection = Padding(
        padding: const EdgeInsets.only(top: 8, left: 8, right: 32),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: actionsList.map((action) {
            final assistantAction = action.toAssistantAction();
            final icon = assistantAction.type.icon;

            return ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primary.withValues(alpha: 0.1),
                foregroundColor: colors.primary,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                side: BorderSide(color: colors.primary.withValues(alpha: 0.2)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              icon: Icon(icon, size: 16),
              label: Text(
                action.label,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              onPressed: () {
                if (widget.onActionPressed != null) {
                  widget.onActionPressed!(action);
                }
              },
            );
          }).toList(),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final bubbleContainer = Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: bubbleBg,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(20),
              topRight: const Radius.circular(20),
              bottomLeft: Radius.circular(isUser ? 20 : 4),
              bottomRight: Radius.circular(isUser ? 4 : 20),
            ),
            border: isUser ? null : Border.all(color: colors.border),
          ),
          constraints: BoxConstraints(
            maxWidth: constraints.maxWidth * RitmoBreakpoints.chatBubbleMaxWidthFactor,
          ),
          child: widget.msg['content'].toString().trim().isEmpty
              ? const _TypingIndicator()
              : Text.rich(
                  TextSpan(
                    children: parseMarkdownText(
                      widget.msg['content'] as String,
                      TextStyle(
                        fontSize: 13.5,
                        color: isUser ? Colors.white : colors.textPrimary,
                        height: 1.6,
                      ),
                    ),
                  ),
                  textDirection: TextDirection.rtl,
                ),
        );

        return Align(
          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: isUser
                      ? [
                          bubbleContainer,
                          if (showCopy) copyButton else const SizedBox(width: 32),
                        ]
                      : [
                          if (showCopy) copyButton else const SizedBox(width: 32),
                          bubbleContainer,
                        ],
                ),
                ?actionsSection,
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final dotColor = colors.textSecondary.withValues(alpha: 0.6);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final delay = index * (2 * math.pi / 3);
            final value = math.sin((_controller.value * 2 * math.pi) - delay);
            final offsetY = ((value + 1) / 2) * -7;

            return Transform.translate(
              offset: Offset(0, offsetY),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 2.5),
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              ),
            );
          },
        );
      }),
    );
  }
}
