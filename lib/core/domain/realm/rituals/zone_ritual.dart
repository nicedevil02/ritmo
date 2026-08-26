import 'dart:convert';
import 'package:flutter/foundation.dart';

/// Configuration for transition rituals on realm enter/exit (F-14).
@immutable
class ZoneRitualConfig {
  const ZoneRitualConfig({
    this.isEnabled = true,
    this.reviewPendingTasks = true,
    this.promptNoteForTomorrow = true,
    this.isDismissible = true,
    this.checklistItems = const [],
  });

  final bool isEnabled;
  final bool reviewPendingTasks;
  final bool promptNoteForTomorrow;
  final bool isDismissible;
  final List<String> checklistItems;

  Map<String, dynamic> toMap() => {
        'isEnabled': isEnabled,
        'reviewPendingTasks': reviewPendingTasks,
        'promptNoteForTomorrow': promptNoteForTomorrow,
        'isDismissible': isDismissible,
        'checklistItems': checklistItems,
      };

  factory ZoneRitualConfig.fromMap(Map<String, dynamic> map) {
    return ZoneRitualConfig(
      isEnabled: map['isEnabled'] as bool? ?? true,
      reviewPendingTasks: map['reviewPendingTasks'] as bool? ?? true,
      promptNoteForTomorrow: map['promptNoteForTomorrow'] as bool? ?? true,
      isDismissible: map['isDismissible'] as bool? ?? true,
      checklistItems: (map['checklistItems'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }

  String toJson() => jsonEncode(toMap());

  static ZoneRitualConfig? fromJson(String? jsonStr) {
    if (jsonStr == null || jsonStr.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is Map<String, dynamic>) {
        return ZoneRitualConfig.fromMap(decoded);
      }
    } catch (_) {}
    return null;
  }

  ZoneRitualConfig copyWith({
    bool? isEnabled,
    bool? reviewPendingTasks,
    bool? promptNoteForTomorrow,
    bool? isDismissible,
    List<String>? checklistItems,
  }) {
    return ZoneRitualConfig(
      isEnabled: isEnabled ?? this.isEnabled,
      reviewPendingTasks: reviewPendingTasks ?? this.reviewPendingTasks,
      promptNoteForTomorrow:
          promptNoteForTomorrow ?? this.promptNoteForTomorrow,
      isDismissible: isDismissible ?? this.isDismissible,
      checklistItems: checklistItems ?? this.checklistItems,
    );
  }
}
