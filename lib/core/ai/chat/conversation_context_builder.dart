import 'dart:convert';
import 'package:ritmo/core/logging/ritmo_logger.dart';

import 'package:ritmo/core/ai/ai_context_builder.dart';
import 'package:ritmo/core/ai/chat/chat_models.dart';
import 'package:ritmo/core/ai/chat/chat_repository.dart';
import 'package:ritmo/core/ai/memory/ai_memory_service.dart';
import 'package:ritmo/core/ai/memory/memory_models.dart';
import 'package:ritmo/core/database/database_helper.dart';

/// Context model representing a conversation turn and background memory.
class ConversationContext {
  /// Constructs a [ConversationContext].
  ConversationContext({
    required this.recentTurns,
    required this.priorSummaries,
    required this.retrievedData,
    required this.userProfile,
    required this.retrievedMemories,
  });

  /// Recent turns (up to 10 messages).
  final List<ChatMessage> recentTurns;

  /// Prior conversation summaries (up to 3).
  final List<String> priorSummaries;

  /// Retrieved data for the query.
  final Map<String, dynamic> retrievedData;

  /// User profile attributes.
  final Map<String, dynamic> userProfile;

  /// Retrieved cognitive memories.
  final List<MemoryEntry> retrievedMemories;

  /// Formats the context into a list of system/user message maps for the API.
  List<Map<String, String>> toMessages(String systemPrompt, String userText) {
    String truncate(String text) {
      return text.length > 400 ? '${text.substring(0, 400)}…' : text;
    }

    final systemParts = [systemPrompt];
    if (priorSummaries.isNotEmpty) {
      final summaryList = priorSummaries.map((s) => '- $s').join('\n');
      systemParts.add('\nخلاصه گفتگوهای قبلی:\n$summaryList');
    }
    if (userProfile.isNotEmpty) {
      final profileStr = userProfile.entries
          .map((e) => '${e.key}: ${e.value}')
          .join('\n');
      systemParts.add('\nپروفایل کاربر:\n$profileStr');
    }

    // Inject cognitive memory prompt block
    final memoryBlock = AiMemoryService.instance.buildPromptBlock(
      retrievedMemories,
    );
    if (memoryBlock.isNotEmpty) {
      systemParts.add(memoryBlock);
    }

    final messages = <Map<String, String>>[
      {'role': 'system', 'content': systemParts.join('\n')},
    ];

    for (final turn in recentTurns) {
      messages.add({
        'role': turn.role == ChatRole.user ? 'user' : 'assistant',
        'content': truncate(turn.content),
      });
    }

    final userContentParts = [userText];
    if (retrievedData.isNotEmpty) {
      // فاز ۴ · P4-3: بازهٔ داده را صریح به مدل می‌گوییم تا عدد تجمیعی را به
      // بازهٔ اشتباه (مثلا «این هفته») نسبت ندهد.
      final window = retrievedData['window'];
      if (window is Map && window['labelFa'] is String) {
        userContentParts.add(
          '\n\n[توجه: اعداد بلوک <retrieved> فقط برای بازهٔ «${window['labelFa']}» محاسبه شده‌اند؛ دربارهٔ بازه‌های دیگر عدد نساز.]',
        );
      }
      final encodedData = jsonEncode(retrievedData);
      userContentParts.add('\n\n<retrieved>$encodedData</retrieved>');
    }

    messages.add({'role': 'user', 'content': userContentParts.join('\n')});

    return messages;
  }
}

/// Builder class for creating [ConversationContext] instances.
class ConversationContextBuilder {
  /// Builds a [ConversationContext] for a given [sessionId] and [userText].
  ///
  /// [memoryDomain] دامنهٔ حافظهٔ مورد استفاده است؛ پیش‌فرض `core`. دستیارهای
  /// تخصصی می‌توانند دامنهٔ خودشان را پاس بدهند (مانند `sports` یا `goals`).
  Future<ConversationContext> build({
    required String sessionId,
    required String userText,
    required Map<String, dynamic> retrievedData,
    String memoryDomain = 'core',
    ConsentProfile? consent,
  }) async {
    final effectiveConsent = consent ?? await ConsentProfile.loadFromDb();
    // 1) Fetch recent turns (limit: 10)
    final recentTurns = await ChatRepository.instance.getRecentTurns(sessionId);

    // 2) Fetch prior summaries (limit: 4, skip current, select up to 3 non-null)
    final allSessions = await ChatRepository.instance.listSessions(limit: 4);
    final priorSummaries = allSessions
        .where((s) => s.id != sessionId && s.summary != null)
        .take(3)
        .map((s) => s.summary!)
        .toList();

    // 3) Query app_settings table for user profile settings
    final userProfile = <String, dynamic>{};
    try {
      final db = await DatabaseHelper.instance.database;
      final rows = await db.query(
        'app_settings',
        where: 'key LIKE ?',
        whereArgs: ['user_%'],
      );
      for (final row in rows) {
        final key = row['key']! as String;
        final value = row['value']! as String;
        userProfile[key] = value;
      }
    } catch (e) {
      RitmoLog.warning(
        'ConversationContextBuilder',
        'Could not query user profile settings: $e',
      );
    }

    // 4) Retrieve relevant memories from AiMemoryService
    final retrievedMemories = await AiMemoryService.instance.retrieve(
      domain: memoryDomain,
      query: userText,
      consent: effectiveConsent,
    );

    return ConversationContext(
      recentTurns: recentTurns,
      priorSummaries: priorSummaries,
      retrievedData: retrievedData,
      userProfile: userProfile,
      retrievedMemories: retrievedMemories,
    );
  }
}
