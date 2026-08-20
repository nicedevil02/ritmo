import 'package:flutter/services.dart';
import 'package:ritmo/core/logging/ritmo_logger.dart';
import 'package:ritmo/features/routines/presentation/quick_add_parser.dart';
import 'package:ritmo/features/simple_tasks/data/simple_task_repository.dart';

class SharedTextData {
  final String rawText;
  final String parsedTitle;
  final String? note;
  final int? daysOffset;
  final String? timeStr;

  const SharedTextData({
    required this.rawText,
    required this.parsedTitle,
    this.note,
    this.daysOffset,
    this.timeStr,
  });
}

class ShareTargetHandler {
  static const MethodChannel _channel = MethodChannel('com.ritmo.app/share_target');

  /// Pure parser matching specifications for T-32, T-33, and T-34
  static SharedTextData? processSharedText(String? rawText) {
    if (rawText == null || rawText.trim().isEmpty) return null;
    final trimmed = rawText.trim();

    // Rule 3: Text > 200 characters -> first 100 chars as title, full text in note
    if (trimmed.length > 200) {
      final shortTitle = trimmed.substring(0, 100).trim();
      return SharedTextData(
        rawText: trimmed,
        parsedTitle: shortTitle,
        note: trimmed,
      );
    }

    // Standard QuickAdd parsing
    final parsed = QuickAddParser.parse(trimmed);
    String? timeStr;
    if (parsed.timeOfDay != null) {
      final hh = parsed.timeOfDay!.hour.toString().padLeft(2, '0');
      final mm = parsed.timeOfDay!.minute.toString().padLeft(2, '0');
      timeStr = '$hh:$mm';
    }

    return SharedTextData(
      rawText: trimmed,
      parsedTitle: parsed.title.isNotEmpty ? parsed.title : trimmed,
      daysOffset: parsed.daysOffset,
      timeStr: timeStr,
      note: null,
    );
  }

  /// Initializes the share target receiver and automatically creates tasks if requested
  static void init({void Function(SharedTextData data)? onSharedTextReceived}) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onSharedText') {
        final text = call.arguments as String?;
        final data = processSharedText(text);
        if (data != null) {
          if (onSharedTextReceived != null) {
            onSharedTextReceived(data);
          } else {
            await _handleDefaultTaskCreation(data);
          }
        }
      }
    });

    _channel.invokeMethod<String>('getInitialSharedText').then((initialText) async {
      final data = processSharedText(initialText);
      if (data != null) {
        if (onSharedTextReceived != null) {
          onSharedTextReceived(data);
        } else {
          await _handleDefaultTaskCreation(data);
        }
      }
    }).catchError((e, st) {
      RitmoLog.warning('ShareTargetHandler', 'Failed to get initial shared text', e, st);
    });
  }

  static Future<void> _handleDefaultTaskCreation(SharedTextData data) async {
    String? dueDate;
    if (data.daysOffset != null) {
      final dt = DateTime.now().add(Duration(days: data.daysOffset!));
      dueDate = '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    }
    await SimpleTaskRepository.instance.create(
      title: data.parsedTitle,
      dueDate: dueDate,
      dueTime: data.timeStr,
      note: data.note,
    );
  }
}
