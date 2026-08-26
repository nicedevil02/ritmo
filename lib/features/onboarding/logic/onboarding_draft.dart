import 'dart:convert';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/database/upsert_helper.dart';
import 'package:ritmo/core/observability/ritmo_logger.dart';

class OnboardingDraft {
  const OnboardingDraft({
    required this.stepIndex,
    required this.state,
    required this.savedAt,
  });

  final int stepIndex;
  final Map<String, dynamic> state;
  final int savedAt;

  Map<String, dynamic> toJson() => {
        'stepIndex': stepIndex,
        'state': state,
        'savedAt': savedAt,
      };

  static OnboardingDraft? fromJson(Map<String, dynamic> json) {
    try {
      final stepIndex = json['stepIndex'] as int? ?? 0;
      final state = Map<String, dynamic>.from(json['state'] as Map? ?? {});
      final savedAt = json['savedAt'] as int? ?? 0;
      return OnboardingDraft(stepIndex: stepIndex, state: state, savedAt: savedAt);
    } catch (e, st) {
      RitmoLogger.warning(
        'OnboardingDraft.fromJson parse error: $e',
        error: e,
        stack: st,
      );
      return null;
    }
  }
}

class OnboardingDraftStore {
  const OnboardingDraftStore._();

  static const String _key = 'onboarding_draft';

  static Future<void> save(OnboardingDraft draft) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final jsonStr = jsonEncode(draft.toJson());
      await UpsertHelper.upsert(
        db,
        'app_settings',
        {
          'key': _key,
          'value': jsonStr,
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        },
        conflictColumns: const ['key'],
      );
    } catch (e, st) {
      RitmoLogger.error(
        'OnboardingDraftStore.save error: $e',
        error: e,
        stack: st,
      );
    }
  }

  static Future<OnboardingDraft?> load() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final rows = await db.query(
        'app_settings',
        where: 'key = ?',
        whereArgs: [_key],
        limit: 1,
      );
      if (rows.isNotEmpty) {
        final val = rows.first['value']! as String;
        final map = jsonDecode(val) as Map<String, dynamic>;
        final draft = OnboardingDraft.fromJson(map);

        if (draft != null) {
          final now = DateTime.now().millisecondsSinceEpoch;
          if (now - draft.savedAt < 7 * 24 * 3600 * 1000) {
            return draft;
          }
        }
      }
    } catch (e, st) {
      RitmoLogger.warning(
        'OnboardingDraftStore.load error: $e',
        error: e,
        stack: st,
      );
    }
    return null;
  }

  static Future<void> clear() async {
    try {
      final db = await DatabaseHelper.instance.database;
      await db.delete('app_settings', where: 'key = ?', whereArgs: [_key]);
    } catch (e, st) {
      RitmoLogger.warning(
        'OnboardingDraftStore.clear error: $e',
        error: e,
        stack: st,
      );
    }
  }
}
