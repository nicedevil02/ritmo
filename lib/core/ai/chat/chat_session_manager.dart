import 'package:flutter/foundation.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:sqflite/sqflite.dart';

/// Single source of truth for the active AI chat session across the entire app.
/// Persists the active session ID into SQLite `app_settings` for cross-restart memory.
class ChatSessionManager {
  ChatSessionManager._();

  /// Singleton instance.
  static final ChatSessionManager instance = ChatSessionManager._();

  static const String _settingKey = 'assistant_last_active_session_id';

  /// Currently selected session ID.
  final ValueNotifier<String?> activeSessionId = ValueNotifier<String?>(null);

  bool _initialized = false;

  /// Initializes the active session from persistent database storage.
  Future<void> initialize({bool force = false}) async {
    if (_initialized && !force) return;
    try {
      final db = await DatabaseHelper.instance.database;
      final rows = await db.query(
        'app_settings',
        where: 'key = ?',
        whereArgs: [_settingKey],
        limit: 1,
      );

      if (rows.isNotEmpty) {
        final savedId = rows.first['value'] as String?;
        if (savedId != null && savedId.isNotEmpty) {
          // Validate that the session actually exists in chat_sessions
          final sessionCheck = await db.query(
            'chat_sessions',
            columns: ['id'],
            where: 'id = ?',
            whereArgs: [savedId],
            limit: 1,
          );
          if (sessionCheck.isNotEmpty) {
            activeSessionId.value = savedId;
            _initialized = true;
            return;
          }
        }
      }

      // If no valid persistent session was found, check for the latest existing session
      final latestSession = await db.query(
        'chat_sessions',
        columns: ['id'],
        where: "chat_type = 'assistant'",
        orderBy: 'last_message_at DESC',
        limit: 1,
      );

      if (latestSession.isNotEmpty) {
        final firstId = latestSession.first['id'] as String;
        activeSessionId.value = firstId;
        await db.insert(
          'app_settings',
          {
            'key': _settingKey,
            'value': firstId,
            'updatedAt': DateTime.now().millisecondsSinceEpoch,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      } else {
        activeSessionId.value = null;
      }
      _initialized = true;
    } catch (e) {
      debugPrint('[ChatSessionManager] Error initializing active session: $e');
      _initialized = true;
    }
  }

  /// Sets the active session and persists it into the database immediately.
  Future<void> setActiveSession(String? sessionId) async {
    activeSessionId.value = sessionId;
    try {
      final db = await DatabaseHelper.instance.database;
      if (sessionId != null && sessionId.isNotEmpty) {
        await db.insert(
          'app_settings',
          {
            'key': _settingKey,
            'value': sessionId,
            'updatedAt': DateTime.now().millisecondsSinceEpoch,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      } else {
        await db.delete(
          'app_settings',
          where: 'key = ?',
          whereArgs: [_settingKey],
        );
      }
    } catch (e) {
      debugPrint('[ChatSessionManager] Error persisting active session: $e');
    }
  }

  /// Clears active session (resets to a fresh empty conversation).
  Future<void> clearActiveSession() async {
    await setActiveSession(null);
  }

  /// Handles session deletion: if the deleted session is active, reset to a fresh empty conversation.
  Future<void> handleSessionDeleted(String deletedSessionId) async {
    if (activeSessionId.value == deletedSessionId) {
      await clearActiveSession();
    }
  }
}
