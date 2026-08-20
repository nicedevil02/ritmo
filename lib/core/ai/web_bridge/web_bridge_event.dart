// A-02: WebBridgeEvent — Typed event model for JavaScript-to-Dart bridge communication
import 'dart:convert';

enum BridgeSource { sse, dom, fetch, harvest, lifecycle, dart }

BridgeSource parseBridgeSource(String source) {
  switch (source.toLowerCase().trim()) {
    case 'sse':
      return BridgeSource.sse;
    case 'dom':
      return BridgeSource.dom;
    case 'fetch':
      return BridgeSource.fetch;
    case 'harvest':
      return BridgeSource.harvest;
    case 'lifecycle':
      return BridgeSource.lifecycle;
    default:
      return BridgeSource.dart;
  }
}

extension BridgeSourceX on BridgeSource {
  /// منابعی که جریان زندهٔ تدریجی تولید می‌کنند و موضوع داوری قفل هستند.
  bool get isStreamingSource =>
      this == BridgeSource.sse ||
      this == BridgeSource.dom ||
      this == BridgeSource.fetch;

  /// منابعی که عمدی و یک‌باره‌اند و از قفل منبع معاف‌اند (ت-۸).
  bool get bypassesSourceLock => this == BridgeSource.harvest;
}

sealed class WebBridgeEvent {
  const WebBridgeEvent({required this.source});
  final String source;

  static WebBridgeEvent parse(String rawJson) {
    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is! Map<String, dynamic>) {
        return BridgeUnknownEvent(
          type: 'invalid_type',
          rawPayload: {'raw': rawJson},
          source: 'unknown',
          error: 'Decoded JSON is not a Map',
        );
      }

      final type = decoded['type']?.toString().toLowerCase().trim() ?? 'unknown';
      final src = decoded['source']?.toString().toLowerCase().trim() ?? 'unknown';
      final payload = decoded['payload'] is Map<String, dynamic>
          ? decoded['payload'] as Map<String, dynamic>
          : decoded;

      String? readString(String key) {
        final val = payload[key] ?? decoded[key];
        return val?.toString();
      }

      int? readInt(String key) {
        final val = payload[key] ?? decoded[key];
        if (val is int) return val;
        if (val != null) return int.tryParse(val.toString());
        return null;
      }

      bool? readBool(String key) {
        final val = payload[key] ?? decoded[key];
        if (val is bool) return val;
        if (val != null) {
          final s = val.toString().toLowerCase();
          return s == 'true' || s == '1';
        }
        return null;
      }

      switch (type) {
        case 'ready':
          return BridgeReadyEvent(
            source: src,
            isAuthed: readBool('isAuthed') ?? readBool('hasComposer') ?? true,
            email: readString('email'),
            version: readInt('version') ?? 0,
            payload: payload,
            isWarm: readBool('isWarm') ?? false,
            currentPath: readString('currentPath') ?? readString('path'),
            hasComposer: readBool('hasComposer'),
          );
        case 'network_conversation_started':
          return BridgeNetworkConversationStartedEvent(
            source: src,
            requestId: readString('requestId'),
            url: readString('url'),
          );
        case 'chunk':
          return BridgeChunkEvent(
            source: src,
            fullText: readString('fullText'),
            delta: readString('delta'),
            requestId: readString('requestId'),
          );
        case 'done':
          return BridgeDoneEvent(
            source: src,
            fullText: readString('fullText'),
            requestId: readString('requestId'),
          );
        case 'first_token':
          return BridgeFirstTokenEvent(
            source: src,
            requestId: readString('requestId'),
          );
        case 'resumed':
          return BridgeResumedEvent(
            source: src,
            stage: readString('stage') ?? 'streaming',
            requestId: readString('requestId'),
            recoveredLength: readInt('recoveredLength') ?? 0,
          );
        case 'http_error':
          return BridgeHttpErrorEvent(
            source: src,
            statusCode: readInt('status') ?? readInt('statusCode') ?? 0,
            message: readString('message') ?? readString('error') ?? '',
            requestId: readString('requestId'),
          );
        case 'error':
          return BridgeErrorEvent(
            source: src,
            message: readString('message') ?? readString('error') ?? '',
            requestId: readString('requestId'),
          );
        case 'auth_required':
          return BridgeAuthRequiredEvent(
            source: src,
            url: readString('url'),
            isLoginModal: readBool('isLoginModal') ?? false,
            isExpired: readBool('isExpired') ?? false,
          );
        case 'cloudflare_challenge':
        case 'cloudflare':
          return BridgeCloudflareEvent(
            source: src,
            reason: readString('reason') ?? readString('message'),
          );
        case 'cloudflare_resolved':
          return BridgeCloudflareResolvedEvent(
            source: src,
          );
        case 'vpn_required':
        case 'geo_blocked':
        case 'ip_blocked':
          return BridgeVpnRequiredEvent(
            source: src,
            reason: readString('reason') ?? readString('message'),
            rayId: readString('rayId'),
            ip: readString('ip'),
          );
        case 'selector_health':
          return BridgeSelectorHealthEvent(
            source: src,
            report: payload['report'] is Map<String, dynamic>
                ? payload['report'] as Map<String, dynamic>
                : (decoded['report'] is Map<String, dynamic> ? decoded['report'] as Map<String, dynamic> : null),
            issue: readString('issue'),
            bridgeVersion: readInt('bridgeVersion'),
            phase: readString('phase'),
            requestId: readString('requestId'),
          );
        case 'prompt_typed':
          return BridgePromptTypedEvent(
            source: src,
            requestId: readString('requestId'),
            length: readInt('length') ?? 0,
          );
        case 'send_clicked':
          return BridgeSendClickedEvent(
            source: src,
            requestId: readString('requestId'),
            matchedSelector: readString('matchedSelector'),
            candidateCount: readInt('candidateCount') ?? 0,
            ariaLabel: readString('ariaLabel'),
          );
        case 'send_fallback_enter':
          return BridgeSendFallbackEnterEvent(
            source: src,
            requestId: readString('requestId'),
          );
        case 'composer_not_found':
          return BridgeComposerNotFoundEvent(
            source: src,
            requestId: readString('requestId'),
          );
        case 'watcher_tick':
          return BridgeWatcherTickEvent(
            source: src,
            requestId: readString('requestId'),
            textLength: readInt('textLength') ?? 0,
            hasStopButton: readBool('hasStopButton') ?? false,
            hasStreamingIndicator: readBool('hasStreamingIndicator') ?? false,
            assistantNodes: readInt('assistantNodes') ?? 0,
            turnCount: readInt('turnCount') ?? 0,
            markdownBodies: readInt('markdownBodies') ?? 0,
            idleMs: readInt('idleMs') ?? 0,
            elapsedMs: readInt('elapsedMs') ?? 0,
          );
        case 'watcher_steady_done':
          return BridgeWatcherSteadyDoneEvent(
            source: src,
            textLength: readInt('textLength') ?? 0,
            idleMs: readInt('idleMs') ?? 0,
            requestId: readString('requestId'),
          );
        case 'auto_dismiss':
          return BridgeAutoDismissEvent(
            source: src,
            label: readString('label') ?? '',
          );
        case 'resume_skipped_duplicate':
          return BridgeResumeSkippedDuplicateEvent(
            source: src,
            requestId: readString('requestId'),
          );
        case 'fetch_matched':
          return BridgeFetchMatchedEvent(
            source: src,
            url: readString('url') ?? '',
            method: readString('method') ?? 'GET',
            isStream: payload['isStream'] == true || decoded['isStream'] == true,
            requestId: readString('requestId'),
          );
        case 'harvest_result':
          return BridgeHarvestResultEvent(
            source: src,
            fullText: readString('fullText') ?? '',
            error: readString('error'),
            requestId: readString('requestId'),
            strategy: readString('strategy'),
          );
        default:
          return BridgeUnknownEvent(
            type: type,
            rawPayload: decoded,
            source: src,
          );
      }
    } catch (e) {
      return BridgeUnknownEvent(
        type: 'parse_error',
        rawPayload: {'raw': rawJson},
        source: 'unknown',
        error: e.toString(),
      );
    }
  }
}

class BridgeReadyEvent extends WebBridgeEvent {
  const BridgeReadyEvent({
    required super.source,
    required this.isAuthed,
    this.email,
    required this.version,
    required this.payload,
    this.isWarm = false,
    this.currentPath,
    this.hasComposer,
  });

  final bool isAuthed;
  final String? email;
  final int version;
  final Map<String, dynamic> payload;
  final bool isWarm;
  final String? currentPath;
  final bool? hasComposer;
}

class BridgeChunkEvent extends WebBridgeEvent {
  const BridgeChunkEvent({
    required super.source,
    this.fullText,
    this.delta,
    this.requestId,
  });

  final String? fullText;
  final String? delta;
  final String? requestId;
}

class BridgeDoneEvent extends WebBridgeEvent {
  const BridgeDoneEvent({
    required super.source,
    this.fullText,
    this.requestId,
  });

  final String? fullText;
  final String? requestId;
}

class BridgeFirstTokenEvent extends WebBridgeEvent {
  const BridgeFirstTokenEvent({
    required super.source,
    this.requestId,
  });

  final String? requestId;
}

class BridgeResumedEvent extends WebBridgeEvent {
  const BridgeResumedEvent({
    required super.source,
    required this.stage,
    this.requestId,
    this.recoveredLength = 0,
  });

  final String stage;
  final String? requestId;
  final int recoveredLength;
}

class BridgeHttpErrorEvent extends WebBridgeEvent {
  const BridgeHttpErrorEvent({
    required super.source,
    required this.statusCode,
    required this.message,
    this.requestId,
  });

  final int statusCode;
  final String message;
  final String? requestId;
}

class BridgeAuthRequiredEvent extends WebBridgeEvent {
  const BridgeAuthRequiredEvent({
    required super.source,
    this.url,
    this.isLoginModal = false,
    this.isExpired = false,
  });

  final String? url;
  final bool isLoginModal;
  final bool isExpired;
}

class BridgeCloudflareEvent extends WebBridgeEvent {
  const BridgeCloudflareEvent({
    required super.source,
    this.reason,
  });

  final String? reason;
}

class BridgeCloudflareResolvedEvent extends WebBridgeEvent {
  const BridgeCloudflareResolvedEvent({
    required super.source,
  });
}

class BridgeVpnRequiredEvent extends WebBridgeEvent {
  const BridgeVpnRequiredEvent({
    required super.source,
    this.reason,
    this.rayId,
    this.ip,
  });

  final String? reason;
  final String? rayId;
  final String? ip;
}

class BridgeSelectorHealthEvent extends WebBridgeEvent {
  const BridgeSelectorHealthEvent({
    required super.source,
    this.report,
    this.issue,
    this.bridgeVersion,
    this.phase,
    this.requestId,
  });

  final Map<String, dynamic>? report;
  final String? issue;
  final int? bridgeVersion;
  final String? phase;
  final String? requestId;
}

class BridgeAutoDismissEvent extends WebBridgeEvent {
  const BridgeAutoDismissEvent({
    required super.source,
    required this.label,
  });

  final String label;
}

class BridgeHarvestResultEvent extends WebBridgeEvent {
  const BridgeHarvestResultEvent({
    required super.source,
    required this.fullText,
    this.error,
    this.requestId,
    this.strategy,
  });

  final String fullText;
  final String? error;
  final String? requestId;
  final String? strategy;
}

class BridgeNetworkConversationStartedEvent extends WebBridgeEvent {
  const BridgeNetworkConversationStartedEvent({
    required super.source,
    this.requestId,
    this.url,
  });

  final String? requestId;
  final String? url;
}

class BridgePromptTypedEvent extends WebBridgeEvent {
  const BridgePromptTypedEvent({
    required super.source,
    this.requestId,
    this.length = 0,
  });

  final String? requestId;
  final int length;
}

class BridgeSendClickedEvent extends WebBridgeEvent {
  const BridgeSendClickedEvent({
    required super.source,
    this.requestId,
    this.matchedSelector,
    this.candidateCount = 0,
    this.ariaLabel,
  });

  final String? requestId;
  final String? matchedSelector;
  final int candidateCount;
  final String? ariaLabel;
}

class BridgeSendFallbackEnterEvent extends WebBridgeEvent {
  const BridgeSendFallbackEnterEvent({
    required super.source,
    this.requestId,
  });

  final String? requestId;
}

class BridgeComposerNotFoundEvent extends WebBridgeEvent {
  const BridgeComposerNotFoundEvent({
    required super.source,
    this.requestId,
  });

  final String? requestId;
}

class BridgeWatcherTickEvent extends WebBridgeEvent {
  const BridgeWatcherTickEvent({
    required super.source,
    this.requestId,
    this.textLength = 0,
    this.hasStopButton = false,
    this.hasStreamingIndicator = false,
    this.assistantNodes = 0,
    this.turnCount = 0,
    this.markdownBodies = 0,
    this.idleMs = 0,
    this.elapsedMs = 0,
  });

  final String? requestId;
  final int textLength;
  final bool hasStopButton;
  final bool hasStreamingIndicator;
  final int assistantNodes;
  final int turnCount;
  final int markdownBodies;
  final int idleMs;
  final int elapsedMs;
}

class BridgeErrorEvent extends WebBridgeEvent {
  const BridgeErrorEvent({
    required super.source,
    this.message,
    this.requestId,
  });

  final String? message;
  final String? requestId;
}

class BridgeFetchMatchedEvent extends WebBridgeEvent {
  const BridgeFetchMatchedEvent({
    required super.source,
    required this.url,
    required this.method,
    required this.isStream,
    this.requestId,
  });

  final String url;
  final String method;
  final bool isStream;
  final String? requestId;
}

class BridgeWatcherSteadyDoneEvent extends WebBridgeEvent {
  const BridgeWatcherSteadyDoneEvent({
    required super.source,
    required this.textLength,
    required this.idleMs,
    this.requestId,
  });

  final int textLength;
  final int idleMs;
  final String? requestId;
}

class BridgeResumeSkippedDuplicateEvent extends WebBridgeEvent {
  const BridgeResumeSkippedDuplicateEvent({
    required super.source,
    this.requestId,
  });

  final String? requestId;
}

class BridgeUnknownEvent extends WebBridgeEvent {
  const BridgeUnknownEvent({
    required this.type,
    required this.rawPayload,
    required super.source,
    this.error,
  });

  final String type;
  final Map<String, dynamic> rawPayload;
  final String? error;
}
