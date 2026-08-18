// A-02: WebBridgeEvent — Typed event model for JavaScript-to-Dart bridge communication
import 'dart:convert';

enum BridgeSource { sse, dom, fetch, lifecycle, dart }

BridgeSource parseBridgeSource(String source) {
  switch (source.toLowerCase().trim()) {
    case 'sse':
      return BridgeSource.sse;
    case 'dom':
      return BridgeSource.dom;
    case 'fetch':
      return BridgeSource.fetch;
    case 'lifecycle':
      return BridgeSource.lifecycle;
    default:
      return BridgeSource.dart;
  }
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
            isAuthed: readBool('isAuthed') ?? false,
            email: readString('email'),
            version: readInt('version') ?? 0,
            payload: payload,
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
        case 'selector_health':
          return BridgeSelectorHealthEvent(
            source: src,
            report: payload['report'] is Map<String, dynamic>
                ? payload['report'] as Map<String, dynamic>
                : (decoded['report'] is Map<String, dynamic> ? decoded['report'] as Map<String, dynamic> : null),
            issue: readString('issue'),
            bridgeVersion: readInt('bridgeVersion'),
          );
        case 'auto_dismiss':
          return BridgeAutoDismissEvent(
            source: src,
            label: readString('label') ?? '',
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
  });

  final bool isAuthed;
  final String? email;
  final int version;
  final Map<String, dynamic> payload;
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

class BridgeSelectorHealthEvent extends WebBridgeEvent {
  const BridgeSelectorHealthEvent({
    required super.source,
    this.report,
    this.issue,
    this.bridgeVersion,
  });

  final Map<String, dynamic>? report;
  final String? issue;
  final int? bridgeVersion;
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
