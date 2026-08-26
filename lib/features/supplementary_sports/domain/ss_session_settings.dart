import 'package:ritmo/core/database/database_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

/// Configuration settings for workout sessions.
class SSSessionSettings {
  final int defaultRestSeconds;
  final bool ttsEnabled;
  final bool ttsCountdownEnabled;
  final bool audioCuesEnabled;
  final bool unitsMetric;
  final bool neighborFriendly;
  final int defaultRir;

  const SSSessionSettings({
    this.defaultRestSeconds = 90,
    this.ttsEnabled = true,
    this.ttsCountdownEnabled = true,
    this.audioCuesEnabled = true,
    this.unitsMetric = true,
    this.neighborFriendly = false,
    this.defaultRir = 2,
  });

  /// Loads session settings from database and shared preferences.
  static Future<SSSessionSettings> load({DatabaseExecutor? executor}) async {
    final db = executor ?? await DatabaseHelper.instance.database;
    final profileRows = await db.query(
      'ss_user_profile',
      where: "id = 'default'",
    );
    final neighborFriendly =
        profileRows.isNotEmpty && (profileRows.first['neighborFriendly'] == 1);

    Map<String, String> appSettings = {};
    try {
      final rows = await db.query(
        'app_settings',
        where: "key IN ('ss_default_rest_seconds', 'ss_tts_enabled', 'ss_tts_countdown_enabled', 'ss_audio_cues_enabled', 'ss_units_metric')",
      );
      appSettings = {
        for (final r in rows) (r['key'] as String): r['value'] as String,
      };
    } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    final defaultRestSeconds = int.tryParse(appSettings['ss_default_rest_seconds'] ?? '') ??
        prefs.getInt('ss_default_rest_seconds') ?? 90;
    final ttsEnabled = appSettings['ss_tts_enabled'] != null
        ? appSettings['ss_tts_enabled'] == 'true'
        : prefs.getBool('ss_tts_enabled') ?? true;
    final ttsCountdownEnabled = appSettings['ss_tts_countdown_enabled'] != null
        ? appSettings['ss_tts_countdown_enabled'] == 'true'
        : prefs.getBool('ss_tts_countdown_enabled') ?? true;
    final audioCuesEnabled = appSettings['ss_audio_cues_enabled'] != null
        ? appSettings['ss_audio_cues_enabled'] == 'true'
        : prefs.getBool('ss_audio_cues_enabled') ?? true;
    final unitsMetric = appSettings['ss_units_metric'] != null
        ? appSettings['ss_units_metric'] == 'true'
        : prefs.getBool('ss_units_metric') ?? true;

    return SSSessionSettings(
      defaultRestSeconds: defaultRestSeconds,
      ttsEnabled: ttsEnabled,
      ttsCountdownEnabled: ttsCountdownEnabled,
      audioCuesEnabled: audioCuesEnabled,
      unitsMetric: unitsMetric,
      neighborFriendly: neighborFriendly,
      defaultRir: 2,
    );
  }
}
