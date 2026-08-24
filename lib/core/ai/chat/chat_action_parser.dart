import 'dart:convert';
import 'package:ritmo/core/ai/chat/chat_models.dart';
import 'package:ritmo/core/ai/web_bridge/bridge_response_accumulator.dart';
import 'package:ritmo/core/logging/ritmo_logger.dart';

class ParsedResponse {
  const ParsedResponse(this.cleanText, this.actions, {this.memoryOps});
  final String cleanText;
  final List<ChatAction> actions;
  final String? memoryOps;
}

class ChatActionParser {
  static final _re = RegExp(r'<actions>([\s\S]*?)</actions>', multiLine: true);
  static final _memOpsRe = RegExp(
    r'<memory_ops>([\s\S]*?)</memory_ops>',
    multiLine: true,
  );
  static final _memRe = RegExp(r'<memory>([\s\S]*?)</memory>', multiLine: true);

  /// Extracts only the human-readable Farsi text from raw model outputs,
  /// stripping JSON schemas, markdown code blocks, and legacy xml tags.
  static String extractCleanReplyText(String raw) {
    if (raw.isEmpty) return '';

    var clean = raw.trim();

    // 1. Strip markdown code fences if present (e.g. ```json ... ```)
    if (clean.startsWith('```')) {
      final lines = clean.split('\n');
      if (lines.first.startsWith('```')) lines.removeAt(0);
      if (lines.isNotEmpty && lines.last.startsWith('```')) lines.removeLast();
      clean = lines.join('\n').trim();
    }

    // 2. Clean XML tags (<memory_ops>, <memory>, <actions>)
    clean = clean
        .replaceAll(_memOpsRe, '')
        .replaceAll(_memRe, '')
        .replaceAll(_re, '')
        .trim();

    final idxMemOps = clean.indexOf('<memory_ops>');
    if (idxMemOps != -1) clean = clean.substring(0, idxMemOps).trim();
    final idxMem = clean.indexOf('<memory>');
    if (idxMem != -1) clean = clean.substring(0, idxMem).trim();
    final idxAct = clean.indexOf('<actions>');
    if (idxAct != -1) clean = clean.substring(0, idxAct).trim();

    if (clean.isEmpty) return '';

    // 3. Attempt full JSON decode to extract "reply"
    if ((clean.startsWith('{') && clean.endsWith('}')) ||
        (clean.startsWith('{') && clean.contains('"reply"'))) {
      try {
        final decoded = jsonDecode(clean);
        if (decoded is Map &&
            decoded.containsKey('reply') &&
            decoded['reply'] != null) {
          final replyVal = decoded['reply'].toString().trim();
          if (replyVal.isNotEmpty) {
            return BridgeResponseAccumulator.sanitize(replyVal);
          }
        }
      } catch (e) {
        RitmoLog.debug(
          'ChatActionParser',
          'Could not parse clean JSON reply: $e',
        );
      }
    }

    // 4. Attempt regex extraction for streaming / unclosed / partial JSON: "reply": "..."
    final replyRegex = RegExp(
      r'"reply"\s*:\s*"([^"\\]*(?:\\.[^"\\]*)*)',
      dotAll: true,
    );
    final match = replyRegex.firstMatch(clean);
    if (match != null && match.groupCount >= 1) {
      var extracted = match.group(1) ?? '';
      extracted = extracted
          .replaceAll(r'\"', '"')
          .replaceAll(r'\n', '\n')
          .replaceAll(r'\t', '\t')
          .replaceAll(r'\\', r'\');
      if (extracted.trim().isNotEmpty) {
        return BridgeResponseAccumulator.sanitize(extracted.trim());
      }
    }

    // 5. Fallback: If clean contains "reply" but regex/decode failed, string slice
    if (clean.contains('"reply"')) {
      final keyIdx = clean.indexOf('"reply"');
      final colonIdx = clean.indexOf(':', keyIdx);
      if (colonIdx != -1) {
        final quoteStart = clean.indexOf('"', colonIdx + 1);
        if (quoteStart != -1) {
          final rest = clean.substring(quoteStart + 1);
          final quoteEnd = rest.indexOf('"');
          if (quoteEnd != -1) {
            final val = rest.substring(0, quoteEnd).trim();
            if (val.isNotEmpty) {
              return BridgeResponseAccumulator.sanitize(val);
            }
          } else {
            return BridgeResponseAccumulator.sanitize(
              rest.replaceAll(r'\"', '"').replaceAll(r'\n', '\n').trim(),
            );
          }
        }
      }
    }

    return BridgeResponseAccumulator.sanitize(clean);
  }

  static ParsedResponse parse(String raw) {
    // Extract memory_ops content
    final mOps = _memOpsRe.firstMatch(raw);
    final memoryOps = mOps?.group(1)?.trim();

    final cleanText = extractCleanReplyText(raw);
    final actions = <ChatAction>[];

    // Try JSON actions/commands
    try {
      var jsonStr = raw.trim();
      if (jsonStr.startsWith('```')) {
        final lines = jsonStr.split('\n');
        if (lines.first.startsWith('```')) lines.removeAt(0);
        if (lines.isNotEmpty && lines.last.startsWith('```'))
          lines.removeLast();
        jsonStr = lines.join('\n').trim();
      }
      if (jsonStr.startsWith('{') && jsonStr.endsWith('}')) {
        final decoded = jsonDecode(jsonStr);
        if (decoded is Map) {
          final rawCmds = decoded['commands'] ?? decoded['actions'];
          if (rawCmds is List) {
            for (final item in rawCmds) {
              if (item is Map) {
                final id =
                    item['id']?.toString() ?? item['type']?.toString() ?? '';
                final label =
                    item['labelFa']?.toString() ??
                    item['label']?.toString() ??
                    item['title']?.toString() ??
                    id;
                final payload =
                    (item['payload'] as Map?)?.cast<String, dynamic>() ?? {};
                if (id.isNotEmpty) {
                  actions.add(
                    ChatAction(
                      type: id,
                      label: label,
                      payload: payload,
                      targetRoute: item['targetRoute']?.toString(),
                    ),
                  );
                }
              }
            }
          }
        }
      }
    } catch (e) {
      RitmoLog.debug(
        'ChatActionParser',
        'Could not parse actions from JSON: $e',
      );
    }

    // Fallback: Legacy <actions> tag if no JSON actions found
    if (actions.isEmpty) {
      final mAct = _re.firstMatch(raw);
      if (mAct != null) {
        try {
          final decoded = jsonDecode(mAct.group(1)!.trim());
          if (decoded is List) {
            for (final item in decoded) {
              if (item is! Map) continue;
              final a = ChatAction.fromJson(item.cast<String, dynamic>());
              if (a.type.isNotEmpty && a.label.isNotEmpty) {
                actions.add(a);
              }
            }
          }
        } catch (e) {
          RitmoLog.debug(
            'ChatActionParser',
            'Could not parse fallback actions tag: $e',
          );
        }
      }
    }

    return ParsedResponse(cleanText, actions, memoryOps: memoryOps);
  }
}
