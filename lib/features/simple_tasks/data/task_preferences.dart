import 'package:shared_preferences/shared_preferences.dart';
import 'package:ritmo/features/simple_tasks/domain/task_bucket.dart';

class TaskPreferences {
  static const String _soundKey = 'tasks_completion_sound_enabled';
  static String _bucketExpandedKey(TaskBucket bucket) => 'tasks_bucket_expanded_${bucket.name}';

  static Future<bool> isBucketExpanded(TaskBucket bucket) async {
    final prefs = await SharedPreferences.getInstance();
    final defaultExpanded = bucket != TaskBucket.doneToday;
    return prefs.getBool(_bucketExpandedKey(bucket)) ?? defaultExpanded;
  }

  static Future<void> setBucketExpanded(TaskBucket bucket, bool expanded) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_bucketExpandedKey(bucket), expanded);
  }

  static Future<bool> isCompletionSoundEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_soundKey) == 'true';
  }

  static Future<void> setCompletionSoundEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_soundKey, enabled ? 'true' : 'false');
  }
}
