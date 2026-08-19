import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:ritmo/core/ai/web_bridge/bridge_response_accumulator.dart';
import 'package:ritmo/core/ai/web_bridge/bridge_trace_log.dart';
import 'package:ritmo/core/ai/web_bridge/chatgpt_bridge_timeouts.dart';
import 'package:ritmo/core/ai/web_bridge/chatgpt_js_injector.dart';
import 'package:ritmo/core/ai/web_bridge/web_bridge_event.dart';
import 'package:ritmo/core/ai/web_bridge/web_bridge_exception.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/logging/ritmo_logger.dart';
import 'package:webview_flutter/webview_flutter.dart';

enum ChatGptBridgeStatus {
  idle,
  booting,
  ready,
  generating,
  cloudflareChallenge,
  error,
}

enum PendingRequestStage {
  sending,
  awaitingFirstToken,
  streaming,
}

/// State of an in-flight prompt request used for resume and correlation.
class PendingWebBridgeRequest {
  final String requestId;
  final String promptHash;
  final String promptText;
  final DateTime sentAt;
  PendingRequestStage stage;
  int receivedLength;
  int resendAttempts;
  final String? personaTitle;
  final String? personaSystemPrompt;
  final String? contextSummary;
  final List<String>? recentHistory;

  PendingWebBridgeRequest({
    required this.requestId,
    required this.promptHash,
    required this.promptText,
    required this.sentAt,
    this.stage = PendingRequestStage.sending,
    this.receivedLength = 0,
    this.resendAttempts = 0,
    this.personaTitle,
    this.personaSystemPrompt,
    this.contextSummary,
    this.recentHistory,
  });

  /// Normalizes whitespace and returns up to the first 80 characters.
  String get promptPrefix {
    final normalized = promptText.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.length <= 80) return normalized;
    return normalized.substring(0, 80);
  }

  Map<String, dynamic> toJson() => {
        'requestId': requestId,
        'promptHash': promptHash,
        'promptPrefix': promptPrefix,
        'stage': stage.name,
        'receivedLength': receivedLength,
        'resendAttempts': resendAttempts,
        'sentAt': sentAt.toIso8601String(),
      };

  factory PendingWebBridgeRequest.fromJson(Map<String, dynamic> json) {
    final stageStr = json['stage'] as String? ?? 'sending';
    final stage = PendingRequestStage.values.firstWhere(
      (e) => e.name == stageStr,
      orElse: () => PendingRequestStage.sending,
    );
    return PendingWebBridgeRequest(
      requestId: json['requestId'] as String? ?? '',
      promptHash: json['promptHash'] as String? ?? '',
      promptText: json['promptPrefix'] as String? ?? '',
      sentAt: json['sentAt'] != null
          ? DateTime.tryParse(json['sentAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      stage: stage,
      receivedLength: json['receivedLength'] as int? ?? 0,
      resendAttempts: json['resendAttempts'] as int? ?? 0,
    );
  }
}

/// Diagnostic reason for an empty response (A-22).
class EmptyResponseReason {
  final String messageFa;
  final String technicalDetail;

  const EmptyResponseReason({
    required this.messageFa,
    required this.technicalDetail,
  });

  @override
  String toString() => '$messageFa ($technicalDetail)';
}

class ChatGptWebBridgeManager with WidgetsBindingObserver {
  static final ChatGptWebBridgeManager _instance = ChatGptWebBridgeManager._internal();
  static ChatGptWebBridgeManager get instance => _instance;

  ChatGptWebBridgeManager._internal() {
    WidgetsBinding.instance.addObserver(this);
  }

  /// Sentinel prefix emitted when response accumulator detects a non-prefix rewrite (A-12).
  static const String rewriteSentinel = '\u0000RITMO_REWRITE\u0000';

  static const String targetUrl = 'https://chatgpt.com/';
  static const Duration inactivityTimeout = ChatGptBridgeTimeouts.inactivityTimeout;

  /// Hard ceiling for a single generation.
  static const Duration generationTimeout = ChatGptBridgeTimeouts.generationTimeout;

  /// Max navigation reloads before considering it a loop (A-18).
  static const int maxNavigationReloads = 6;

  WebViewController? _controller;
  WebViewController? get controller => _controller;

  ChatGptBridgeStatus _status = ChatGptBridgeStatus.idle;
  ChatGptBridgeStatus get status => _status;

  final ValueNotifier<bool> _cloudflareNotifier = ValueNotifier<bool>(false);
  ValueListenable<bool> get cloudflareNotifier => _cloudflareNotifier;

  final ValueNotifier<ChatGptBridgeStatus> _statusNotifier =
      ValueNotifier<ChatGptBridgeStatus>(ChatGptBridgeStatus.idle);
  ValueListenable<ChatGptBridgeStatus> get statusNotifier => _statusNotifier;

  Timer? _inactivityTimer;
  Timer? _generationTimer;
  StreamController<String>? _currentStreamController;
  Completer<bool>? _bootCompleter;

  int _reqCounter = 0;
  String? _currentRequestId;
  String? get currentRequestId => _currentRequestId;

  String? _lastChunkSource;
  String? get lastChunkSource => _lastChunkSource;

  BridgeSource? _lockedSource;
  BridgeSource? get lockedSource => _lockedSource;
  DateTime? _lockedSourceLastChunkAt;
  int _lockedSourceMaxLength = 0;

  bool _lastAnswerWasPartial = false;
  bool get lastAnswerWasPartial => _lastAnswerWasPartial;

  String? _lastEmptyReasonDetail;
  String? get lastEmptyReasonDetail => _lastEmptyReasonDetail;

  final BridgeResponseAccumulator _accumulator = BridgeResponseAccumulator();
  BridgeResponseAccumulator get accumulator => _accumulator;

  bool _hasActiveSseStream = false;
  bool get hasActiveSseStream => _hasActiveSseStream;

  final ValueNotifier<bool> _isAuthenticatedNotifier = ValueNotifier<bool>(true);
  ValueNotifier<bool> get isAuthenticatedNotifier => _isAuthenticatedNotifier;
  bool get isAuthenticated => _isAuthenticatedNotifier.value;
  set _isAuthenticated(bool val) => _isAuthenticatedNotifier.value = val;

  Map<String, dynamic>? _lastSelectorHealthReport;
  Map<String, dynamic>? get lastSelectorHealthReport => _lastSelectorHealthReport;

  PendingWebBridgeRequest? _pendingRequest;
  PendingWebBridgeRequest? get pendingRequest => _pendingRequest;

  int get bridgeVersion => ChatGptJsInjector.bridgeVersion;

  void _acquireSourceLockIfNeeded(BridgeSource src) {
    if (_lockedSource == null) {
      _lockedSource = src;
      _lockedSourceLastChunkAt = DateTime.now();
      _lockedSourceMaxLength = _accumulator.length;
      BridgeTraceLog.instance.addEntry(
        type: 'source_locked',
        source: src.name,
        requestId: _currentRequestId,
        note: 'locked_to_${src.name}',
      );
    }
  }

  bool _shouldRejectForSourceLock(BridgeSource src) {
    final locked = _lockedSource;
    if (locked == null || locked == src) return false;
    if (!src.isStreamingSource) return false;

    final lastAt = _lockedSourceLastChunkAt;
    final silentFor = lastAt == null
        ? Duration.zero
        : DateTime.now().difference(lastAt);

    if (silentFor >= ChatGptBridgeTimeouts.sourceRelockSilence) {
      BridgeTraceLog.instance.addEntry(
        type: 'source_relock',
        level: BridgeTraceLevel.warn,
        source: src.name,
        requestId: _currentRequestId,
        note: 'relock_from_${locked.name}_after_${silentFor.inMilliseconds}ms',
      );
      _lockedSource = null;
      _lockedSourceMaxLength = 0;
      _lockedSourceLastChunkAt = null;
      return false;
    }
    return true;
  }

  @visibleForTesting
  void setTestPendingRequest(PendingWebBridgeRequest? req) {
    _pendingRequest = req;
  }

  @visibleForTesting
  void setTestRequestId(String? reqId) {
    _currentRequestId = reqId;
  }

  @visibleForTesting
  void setTestLastChunkSource(String? source) {
    _lastChunkSource = source;
  }

  @visibleForTesting
  void setTestAuthenticated(bool auth) {
    _isAuthenticated = auth;
  }

  @visibleForTesting
  void resetStateForTest() {
    _status = ChatGptBridgeStatus.idle;
    _currentRequestId = null;
    _pendingRequest = null;
    _lockedSource = null;
    _lockedSourceLastChunkAt = null;
    _lockedSourceMaxLength = 0;
    _lastChunkSource = null;
    _lastAnswerWasPartial = false;
    _lastEmptyReasonDetail = null;
    _accumulator.reset();
    _currentStreamController?.close();
    _currentStreamController = null;
  }

  @visibleForTesting
  void setStatusForTest(ChatGptBridgeStatus status) {
    _setStatus(status);
  }

  @visibleForTesting
  void setCurrentRequestIdForTest(String? id) {
    _currentRequestId = id;
  }

  @visibleForTesting
  void setLockedSourceForTest(BridgeSource? source) {
    _lockedSource = source;
  }

  @visibleForTesting
  void setTestAccumulator(String text) {
    _accumulator.reset();
    _accumulator.applyFull(text, source: 'test');
  }

  String _generateRequestId() {
    _reqCounter++;
    return 'req_${DateTime.now().microsecondsSinceEpoch}_$_reqCounter';
  }


  @visibleForTesting
  static WebViewController Function()? testControllerFactory;

  @visibleForTesting
  static int controllerCreationCount = 0;

  @visibleForTesting
  void setTestState({
    ChatGptBridgeStatus? status,
    WebViewController? controller,
    Completer<bool>? bootCompleter,
    StreamController<String>? streamController,
  }) {
    if (status != null) _setStatus(status);
    if (controller != null) _controller = controller;
    if (bootCompleter != null) _bootCompleter = bootCompleter;
    if (streamController != null) _currentStreamController = streamController;
  }

  void _setStatus(ChatGptBridgeStatus newStatus) {
    _status = newStatus;
    _statusNotifier.value = newStatus;
    RitmoLog.debug('ChatGptWebBridgeManager', 'Status changed to: $newStatus');
  }

  /// Ensures the WebView is booted and ready to receive prompts.
  Future<bool> ensureBooted() async {
    _resetInactivityTimer();

    // WEB-01: Never reboot or destroy controller while actively generating
    if (_status == ChatGptBridgeStatus.generating) {
      RitmoLog.debug('ChatGptWebBridgeManager', 'ensureBooted skipped: already generating (controller exists: ${_controller != null})');
      return _controller != null;
    }

    // WEB-01: Protect cloudflare challenge in progress
    if (_status == ChatGptBridgeStatus.cloudflareChallenge) {
      RitmoLog.debug('ChatGptWebBridgeManager', 'ensureBooted skipped: cloudflare challenge in progress (controller exists: ${_controller != null})');
      return _controller != null;
    }

    if (_controller != null && _status == ChatGptBridgeStatus.ready) {
      RitmoLog.debug('ChatGptWebBridgeManager', 'ensureBooted skipped: already ready');
      return true;
    }

    // WEB-01: Attach to existing boot future if booting is already in flight
    if (_bootCompleter != null && !_bootCompleter!.isCompleted) {
      RitmoLog.debug('ChatGptWebBridgeManager', 'ensureBooted attached to existing bootCompleter');
      return _bootCompleter!.future;
    }

    final bootCompleter = Completer<bool>();
    _bootCompleter = bootCompleter;
    _setStatus(ChatGptBridgeStatus.booting);

    try {
      final oldController = _controller;
      _controller = null;
      if (oldController != null) {
        unawaited(_safeDisposeController(oldController));
      }
      controllerCreationCount++;

      final controller = testControllerFactory?.call() ?? WebViewController();
      _controller = controller;

      await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      await controller.setUserAgent(
        'Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Mobile Safari/537.36',
      );

      await controller.addJavaScriptChannel(
        'RitmoChatBridge',
        onMessageReceived: _handleJsMessage,
      );

      await controller.setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            if (_controller != null && _controller != controller) return;
            RitmoLog.debug('ChatGptWebBridge', 'Page loading started: $url');
            // A-36: Early hook injection at page start
            controller.runJavaScript(ChatGptJsInjector.earlyHookScript).catchError((e) {
              RitmoLog.warning('ChatGptWebBridge', 'earlyHookScript injection warning on page start: $e');
            });
          },
          onPageFinished: (url) async {
            if (_controller != null && _controller != controller) return;
            RitmoLog.debug('ChatGptWebBridge', 'Page loading finished: $url');
            await handlePageFinished(url, controller);
          },
          onWebResourceError: (error) {
            if (_controller != null && _controller != controller) return;
            RitmoLog.warning('ChatGptWebBridge', 'Web resource error: ${error.description}');
            unawaited(handleWebResourceError(error));
          },
          onHttpError: (error) {
            if (_controller != null && _controller != controller) return;
            RitmoLog.warning('ChatGptWebBridge', 'HTTP error: ${error.response?.statusCode}');
            unawaited(handleHttpError(error));
          },
        ),
      );

      await controller.loadRequest(Uri.parse(targetUrl));

      final isReady = await _waitForReady(timeout: ChatGptBridgeTimeouts.bootTimeout);
      if (!bootCompleter.isCompleted) {
        bootCompleter.complete(isReady);
      }
      return isReady;
    } catch (e, st) {
      RitmoLog.error('ChatGptWebBridge', 'Boot error: $e', e, st);
      _setStatus(ChatGptBridgeStatus.error);
      if (!bootCompleter.isCompleted) {
        bootCompleter.complete(false);
      }
      return false;
    }
  }

  int _navigationReloadCount = 0;
  @visibleForTesting
  int get navigationReloadCount => _navigationReloadCount;

  bool get hasPendingRequest =>
      _currentStreamController != null && !_currentStreamController!.isClosed;

  /// Invoked when a WebView page finishes loading. Re-injects the bridge script,
  /// and if a generation is pending, attempts to re-attach the watcher or abort if looped.
  @visibleForTesting
  Future<void> handlePageFinished(String url, WebViewController controller) async {
    if (_controller != null && _controller != controller) {
      RitmoLog.debug('ChatGptWebBridge', 'Ignoring handlePageFinished on stale controller.');
      return;
    }
    await controller.runJavaScript(ChatGptJsInjector.setupBridgeScript);

    if (hasPendingRequest || _status == ChatGptBridgeStatus.generating) {
      _navigationReloadCount++;
      RitmoLog.debug('ChatGptWebBridge', 'Navigation finished with pending request (count: $_navigationReloadCount)');
      if (_navigationReloadCount > maxNavigationReloads) {
        RitmoLog.error('ChatGptWebBridge', 'Navigation reload loop detected (> $maxNavigationReloads times). Aborting stream.');
        final harvested = await _harvestForSalvage(reason: 'navigation_loop');
        if (!_accumulator.isEmpty || (harvested != null && harvested.isNotEmpty)) {
          RitmoLog.warning('ChatGptWebBridge',
              'Salvaging ${_accumulator.length} chars before aborting on navigation loop.');
          _finishGeneration(null, isPartial: true);
        } else {
          _failGeneration(WebBridgeException.navigationLoop());
        }
        return;
      }

      await _attemptResumePendingRequest(controller);
    }
  }

  Future<void> _attemptResumePendingRequest(WebViewController controller) async {
    RitmoLog.debug('ChatGptWebBridge', 'Attempting re-attachment / resume after navigation for req: ${_pendingRequest?.requestId}...');
    await Future.delayed(const Duration(milliseconds: 300));
    try {
      final payload = jsonEncode(_pendingRequest?.toJson() ?? {});
      await controller.runJavaScript('''
if (typeof window.__ritmo_resume === 'function') {
  window.__ritmo_resume($payload);
}
''');
    } catch (e, st) {
      RitmoLog.error('ChatGptWebBridge', 'Error calling __ritmo_resume: $e', e, st);
    }
  }

  /// Handles web resource loading errors from NavigationDelegate.
  @visibleForTesting
  Future<void> handleWebResourceError(WebResourceError error) async {
    RitmoLog.error('ChatGptWebBridge', 'Resource Error (code=${error.errorCode}, isMainFrame=${error.isForMainFrame}): ${error.description}');

    // Only close in-flight stream if the error is confirmed to affect the main frame
    final isMain = error.isForMainFrame ?? false;
    if (!isMain) {
      RitmoLog.debug('ChatGptWebBridge', 'Sub-resource error ignored for stream closure.');
      return;
    }

    if (hasPendingRequest || _status == ChatGptBridgeStatus.generating) {
      final harvested = await _harvestForSalvage(reason: 'resource_error');
      if (!_accumulator.isEmpty || (harvested != null && harvested.isNotEmpty)) {
        RitmoLog.warning('ChatGptWebBridge',
            'Salvaging ${_accumulator.length} chars before aborting on resource error.');
        _finishGeneration(null, isPartial: true);
        return;
      }

      final desc = error.description.toLowerCase();
      final code = error.errorCode;
      final isNetworkDisconnect = code == -2 || // ERROR_HOST_LOOKUP
          code == -6 || // ERROR_CONNECT
          code == -8 || // ERROR_TIMEOUT
          desc.contains('net::err_internet_disconnected') ||
          desc.contains('net::err_name_not_resolved') ||
          desc.contains('net::err_connection_refused') ||
          desc.contains('net::err_connection_timed_out') ||
          desc.contains('disconnected') ||
          desc.contains('network');

      if (isNetworkDisconnect) {
        _failGeneration('دسترسی به اینترنت برقرار نشد. لطفاً اتصال شبکه خود را بررسی کنید.');
      } else {
        _failGeneration('خطا در بارگذاری صفحهٔ ChatGPT (${error.description}).');
      }
    }
  }

  /// Handles HTTP response status errors from NavigationDelegate.
  @visibleForTesting
  Future<void> handleHttpError(HttpResponseError error) async {
    final status = error.response?.statusCode;
    RitmoLog.error('ChatGptWebBridge', 'HTTP Error: statusCode=$status');

    if (hasPendingRequest || _status == ChatGptBridgeStatus.generating) {
      final harvested = await _harvestForSalvage(reason: 'http_error');
      if (!_accumulator.isEmpty || (harvested != null && harvested.isNotEmpty)) {
        RitmoLog.warning('ChatGptWebBridge',
            'Salvaging ${_accumulator.length} chars before aborting on HTTP error.');
        _finishGeneration(null, isPartial: true);
        return;
      }

      if (status != null && status >= 500 && status <= 599) {
        _failGeneration('چت‌جی‌پی‌تی الان جواب نمی‌دهد (خطای سرور $status). لطفاً کمی بعد دوباره تلاش کنید.');
      } else if (status == 401 || status == 403) {
        _failGeneration('برای ادامه باید وارد حساب ChatGPT شوید.');
      } else if (status != null && status >= 400) {
        _failGeneration('خطای ارتباط با سرور ChatGPT ($status).');
      }
    }
  }

  /// Attaches a viewer widget without triggering a reboot.
  /// If the bridge is completely idle (and only then), initiates lazy boot in background.
  WebViewController? attachViewer() {
    if (_status == ChatGptBridgeStatus.idle) {
      unawaited(ensureBooted());
    }
    return _controller;
  }

  /// Sole authorized path for a forced reboot. Closes any in-flight stream with [reasonFa].
  Future<bool> forceReboot({required String reasonFa}) async {
    RitmoLog.debug('ChatGptWebBridgeManager', 'forceReboot requested. reason: $reasonFa');
    _generationTimer?.cancel();
    _generationTimer = null;

    final controller = _currentStreamController;
    _currentStreamController = null;
    _accumulator.reset();
    _lockedSource = null;
    _lastChunkSource = null;
    _hasActiveSseStream = false;
    if (controller != null && !controller.isClosed) {
      controller.addError(Exception(reasonFa));
      await controller.close();
    }

    _bootCompleter = null;
    final oldController = _controller;
    _controller = null;
    _cloudflareNotifier.value = false;
    _setStatus(ChatGptBridgeStatus.idle);

    if (oldController != null) {
      await _safeDisposeController(oldController);
    }

    return ensureBooted();
  }

  /// Waits until the page composer textarea is present, enabled, and ChatGPT is not generating.
  @visibleForTesting
  Future<bool> waitForComposerReady({Duration timeout = ChatGptBridgeTimeouts.composerReadyTimeout}) async {
    final start = DateTime.now();
    while (DateTime.now().difference(start) < timeout) {
      try {
        final result = await _controller?.runJavaScriptReturningResult(
          "window.__ritmo_checkComposerReady ? JSON.stringify(window.__ritmo_checkComposerReady()) : JSON.stringify({ready: false})",
        );
        if (result != null) {
          final parsed = jsonDecode(result.toString());
          final map = (parsed is String) ? jsonDecode(parsed) : parsed;
          if (map is Map && map['ready'] == true) return true;
        }
      } catch (e) {
        RitmoLog.debug('ChatGptWebBridge', 'waitForComposerReady retry after: $e');
      }
      await Future.delayed(ChatGptBridgeTimeouts.pollFastInterval);
    }
    return false;
  }

  Future<bool> _waitForReady({required Duration timeout}) async {
    final start = DateTime.now();
    while (DateTime.now().difference(start) < timeout) {
      if (_status == ChatGptBridgeStatus.ready) return true;
      if (_status == ChatGptBridgeStatus.cloudflareChallenge) return false;
      await Future.delayed(const Duration(milliseconds: 300));
    }
    return _status == ChatGptBridgeStatus.ready;
  }

  @visibleForTesting
  void handleJsMessageForTest(JavaScriptMessage message) => _handleJsMessage(message);

  void _handleJsMessage(JavaScriptMessage message) {
    try {
      final event = WebBridgeEvent.parse(message.message);
      final source = event.source;

      if (event is! BridgeChunkEvent) {
        RitmoLog.debug('ChatGptWebBridge', 'JS event received: ${event.runtimeType} (source: $source)');
      }

      // WEB-07: Drop stale events belonging to previous or mismatched requests
      if (event is! BridgeReadyEvent &&
          event is! BridgeCloudflareEvent) {
        final reqId = switch (event) {
          BridgeChunkEvent(:final requestId) => requestId,
          BridgeDoneEvent(:final requestId) => requestId,
          BridgeFirstTokenEvent(:final requestId) => requestId,
          BridgeResumedEvent(:final requestId) => requestId,
          BridgeHttpErrorEvent(:final requestId) => requestId,
          BridgeHarvestResultEvent(:final requestId) => requestId,
          BridgeNetworkConversationStartedEvent(:final requestId) => requestId,
          _ => null,
        };
        if (reqId != null && reqId.isNotEmpty && reqId != _currentRequestId) {
          RitmoLog.debug(
            'ChatGptWebBridge',
            'Dropping stale JS event: ${event.runtimeType} for reqId=$reqId (active: $_currentRequestId, source: $source)',
          );
          BridgeTraceLog.instance.addEntry(
            type: 'stale_event_dropped',
            source: source,
            requestId: reqId,
            note: 'mismatched_request_id (active: $_currentRequestId)',
            level: BridgeTraceLevel.warn,
          );
          return;
        }
      }

      switch (event) {
        case BridgeReadyEvent(:final isAuthed):
          _isAuthenticated = isAuthed;
          if (_status != ChatGptBridgeStatus.ready) {
            _setStatus(ChatGptBridgeStatus.ready);
          }
          if (_cloudflareNotifier.value) {
            _cloudflareNotifier.value = false;
          }
          BridgeTraceLog.instance.addEntry(
            type: 'ready',
            source: source,
            level: BridgeTraceLevel.info,
          );

        case BridgeNetworkConversationStartedEvent(:final requestId):
          RitmoLog.debug(
            'ChatGptWebBridge',
            'Network conversation stream endpoint intercepted in JS (reqId: $requestId)',
          );
          if (_pendingRequest != null && _pendingRequest!.stage == PendingRequestStage.sending) {
            _pendingRequest!.stage = PendingRequestStage.awaitingFirstToken;
          }
          BridgeTraceLog.instance.addEntry(
            type: 'network_conversation_started',
            source: source,
            requestId: requestId,
            level: BridgeTraceLevel.info,
          );

        case BridgeAuthRequiredEvent(:final url):
          _isAuthenticated = false;
          RitmoLog.warning(
            'ChatGptWebBridge',
            'Auth required detected on page: url=$url',
          );
          BridgeTraceLog.instance.addEntry(
            type: 'auth_required',
            source: source,
            note: 'url=$url',
            level: BridgeTraceLevel.warn,
          );
          if (_status == ChatGptBridgeStatus.generating && _accumulator.isEmpty && !_hasActiveSseStream) {
            _failGeneration(WebBridgeException.authRequired());
          }

        case BridgeCloudflareEvent(:final reason):
          if (_status != ChatGptBridgeStatus.cloudflareChallenge) {
            _setStatus(ChatGptBridgeStatus.cloudflareChallenge);
            _cloudflareNotifier.value = true;
            RitmoLog.debug('ChatGptWebBridge', 'Cloudflare challenge detected.');
          }
          BridgeTraceLog.instance.addEntry(
            type: 'cloudflare_challenge',
            source: source,
            note: reason,
            level: BridgeTraceLevel.warn,
          );

        case BridgeResumedEvent(:final stage, :final requestId, :final recoveredLength):
          RitmoLog.debug(
            'ChatGptWebBridge',
            'Resumed event received from JS bridge (stage: $stage, reqId: $requestId, recoveredLen: $recoveredLength)',
          );
          _pendingRequest?.stage = PendingRequestStage.streaming;
          BridgeTraceLog.instance.addEntry(
            type: 'resumed',
            source: source,
            requestId: requestId,
            textLength: recoveredLength,
            level: BridgeTraceLevel.info,
          );

        case BridgeFirstTokenEvent(:final requestId):
          RitmoLog.debug(
            'ChatGptWebBridge',
            'First token received (source: $source, reqId: $requestId)',
          );
          _pendingRequest?.stage = PendingRequestStage.streaming;
          BridgeTraceLog.instance.addEntry(
            type: 'first_token',
            source: source,
            requestId: requestId,
            level: BridgeTraceLevel.info,
          );

        case BridgeChunkEvent(:final fullText, :final delta):
          _emitChunk(fullText, delta, source: source);
          _resetInactivityTimer();

        case BridgeDoneEvent(:final fullText, :final requestId):
          final src = parseBridgeSource(source);
          final incoming = fullText ?? '';
          final isCompeting = _lockedSource != null && _lockedSource != src;

          if (isCompeting) {
            final current = _accumulator.text;
            final isStrictlyBetter = incoming.trim().length > current.trim().length;
            if (isStrictlyBetter) {
              // قاعدهٔ ۰-۸: متن بلندتر معتبرتر است؛ به‌عنوان برداشت وارد می‌شود.
              BridgeTraceLog.instance.addEntry(
                type: 'done_promoted',
                level: BridgeTraceLevel.warn,
                source: src.name,
                textLength: incoming.length,
                requestId: requestId ?? _currentRequestId,
                note: 'competing_done_longer_than_locked_${_lockedSource!.name}',
              );
              _emitChunk(incoming, null, source: BridgeSource.harvest.name, isHarvest: true);
              _finishGeneration(null);
              break;
            }
            BridgeTraceLog.instance.addEntry(
              type: 'done_ignored',
              level: BridgeTraceLevel.info,
              source: src.name,
              textLength: incoming.length,
              requestId: requestId ?? _currentRequestId,
              note: 'shorter_than_accumulator_${current.length}',
            );
            break;
          }
          _finishGeneration(fullText);

        case BridgeHttpErrorEvent(:final statusCode, :final message, :final requestId):
          RitmoLog.error(
            'ChatGptWebBridge',
            'HTTP error received from JS bridge: status=$statusCode, reqId=$requestId',
          );
          BridgeTraceLog.instance.addEntry(
            type: 'http_error',
            source: source,
            requestId: requestId,
            note: 'status=$statusCode message="$message"',
            level: BridgeTraceLevel.error,
          );
          final isCriticalError = statusCode == 429 || statusCode == 401 || statusCode == 403 ||
              (statusCode >= 500 && statusCode <= 599);
          final isStreamingActive = !_accumulator.isEmpty || _hasActiveSseStream;
          if (!isCriticalError && isStreamingActive) {
            RitmoLog.debug(
              'ChatGptWebBridge',
              'Suppressing non-critical http_error $statusCode — accumulator has ${_accumulator.length} chars.',
            );
            break;
          }
          if (!_accumulator.isEmpty) {
            _finishGeneration(null);
            break;
          }
          if (statusCode == 429) {
            _failGeneration(WebBridgeException.rateLimited(statusCode: statusCode));
          } else if (statusCode == 401 || statusCode == 403) {
            _failGeneration(WebBridgeException.authRequired(messageFa: 'نشست کاربری ChatGPT منقضی شده است. لطفاً پنجرهٔ ورود را باز کنید.'));
          } else if (statusCode >= 500 && statusCode <= 599) {
            _failGeneration(WebBridgeException.serverError(statusCode: statusCode));
          } else {
            _failGeneration(WebBridgeException.networkError(statusCode: statusCode));
          }

        case BridgeSelectorHealthEvent(:final issue, :final bridgeVersion, :final report):
          _lastSelectorHealthReport = report;
          BridgeTraceLog.instance.addEntry(
            type: 'selector_health',
            source: source,
            note: 'issue="$issue" v=$bridgeVersion report=$report',
            level: BridgeTraceLevel.info,
          );
          if (report != null) {
            final composerCount = report['composer'] as int? ?? 0;
            if (composerCount == 0 && _status == ChatGptBridgeStatus.ready) {
              RitmoLog.warning('ChatGptWebBridge', 'Selector self-test warning: composer element not found in DOM.');
            }
          }

        case BridgeAutoDismissEvent(:final label):
          BridgeTraceLog.instance.addEntry(
            type: 'auto_dismiss',
            source: source,
            note: 'label="$label"',
            level: BridgeTraceLevel.info,
          );

        case BridgeHarvestResultEvent(:final fullText, :final error, :final requestId, :final strategy):
          BridgeTraceLog.instance.addEntry(
            type: 'harvest_result',
            source: BridgeSource.harvest.name,
            requestId: requestId,
            textLength: fullText.length,
            note: 'strategy="$strategy" error="$error"',
            level: BridgeTraceLevel.info,
          );
          if (_harvestCompleter != null && !_harvestCompleter!.isCompleted) {
            _harvestCompleter!.complete(fullText.isNotEmpty ? fullText : null);
          }
          if (fullText.isNotEmpty && _status == ChatGptBridgeStatus.generating) {
            _emitChunk(fullText, null, source: BridgeSource.harvest.name, isHarvest: true);
          }

        case BridgeUnknownEvent(:final type, :final error, :final rawPayload):
          RitmoLog.debug('ChatGptWebBridge', 'Unhandled JS message: type=$type raw=$rawPayload');
          BridgeTraceLog.instance.addEntry(
            type: 'unknown_event',
            source: source,
            note: 'type=$type error=$error',
            level: BridgeTraceLevel.warn,
          );
      }
    } catch (e, st) {
      RitmoLog.error('ChatGptWebBridge', 'Error parsing JS message: $e', e, st);
    }
  }

  @visibleForTesting
  Future<void> handleResendRequiredForTest() => _handleResendRequired();

  Future<void> _handleResendRequired() async {
    final req = _pendingRequest;
    if (req == null) return;

    RitmoLog.debug('ChatGptWebBridge', '_handleResendRequired checking safety for req: ${req.requestId}');

    final hasNoTokens = req.receivedLength == 0 && req.stage != PendingRequestStage.streaming;
    final isFirstAttempt = req.resendAttempts == 0;
    final isWithinWindow = DateTime.now().difference(req.sentAt) < ChatGptBridgeTimeouts.resendMaxWindow;

    if (hasNoTokens && isFirstAttempt && isWithinWindow) {
      req.resendAttempts++;
      req.stage = PendingRequestStage.sending;
      RitmoLog.debug('ChatGptWebBridge', 'Triggering safe one-time resend for req: ${req.requestId}');

      String? userName;
      try {
        final db = await DatabaseHelper.instance.database;
        final rows = await db.query(
          'app_settings',
          where: 'key = ?',
          whereArgs: ['user_name'],
          limit: 1,
        );
        if (rows.isNotEmpty) {
          userName = rows.first['value'] as String?;
        }
      } catch (e, st) {
        RitmoLog.error('ChatGptWebBridge', 'Error fetching user_name for resend: $e', e, st);
      }

      final formattedPrompt = ChatGptJsInjector.formatPromptWithSystemDirective(
        userPrompt: req.promptText,
        personaTitle: req.personaTitle,
        personaSystemPrompt: req.personaSystemPrompt,
        userName: userName,
        contextSummary: req.contextSummary,
        recentHistory: req.recentHistory,
      );

      final jsCall = ChatGptJsInjector.buildSendPromptScript(
        formattedPrompt,
        requestId: req.requestId,
      );
      await _controller?.runJavaScript(jsCall);
    } else {
      RitmoLog.error('ChatGptWebBridge', 'Safe resend disallowed (hasNoTokens=$hasNoTokens, isFirstAttempt=$isFirstAttempt, isWithinWindow=$isWithinWindow). Failing generation.');
      _failGeneration('ارتباط با گفتگو قطع شد و پیام ارسال نشد. لطفاً دوباره تلاش کنید.');
    }
  }

  Completer<String?>? _harvestCompleter;
  bool _harvestInFlight = false;

  /// Harvests visible assistant text directly from ChatGPT WebView DOM (A-40, A-75).
  Future<String?> harvestVisibleAnswer() async {
    if (_harvestInFlight) {
      BridgeTraceLog.instance.addEntry(
        type: 'harvest_skipped',
        source: BridgeSource.harvest.name,
        requestId: _currentRequestId,
        note: 'already_in_flight',
        level: BridgeTraceLevel.info,
      );
      return null;
    }

    final controller = _controller;
    if (controller == null) {
      BridgeTraceLog.instance.addEntry(
        type: 'harvest_skipped',
        source: BridgeSource.harvest.name,
        requestId: _currentRequestId,
        note: 'no_controller',
        level: BridgeTraceLevel.info,
      );
      return null;
    }

    _harvestInFlight = true;

    // Complete any hanging previous completer before creating a new one
    if (_harvestCompleter != null && !_harvestCompleter!.isCompleted) {
      _harvestCompleter!.complete(null);
    }
    final completer = Completer<String?>();
    _harvestCompleter = completer;

    try {
      final reqId = _currentRequestId ?? '';
      await controller.runJavaScript('''
if (typeof window.__ritmo_forceHarvest === 'function') {
  window.__ritmo_forceHarvest('$reqId');
} else {
  var text = (typeof findLatestAssistantText === 'function') ? findLatestAssistantText() : '';
  if (typeof notifyFlutter === 'function') {
    notifyFlutter('harvest_result', { fullText: text || '', requestId: '$reqId', source: 'harvest', strategy: 'manual_fallback' });
  }
}
''');
      final result = await completer.future.timeout(
        ChatGptBridgeTimeouts.harvestTimeout,
        onTimeout: () {
          BridgeTraceLog.instance.addEntry(
            type: 'harvest_timeout',
            source: BridgeSource.harvest.name,
            requestId: _currentRequestId,
            level: BridgeTraceLevel.warn,
          );
          return null;
        },
      );

      if (result != null && result.isNotEmpty) {
        final sanitized = BridgeResponseAccumulator.sanitize(result);
        if (sanitized.length < _accumulator.length) {
          BridgeTraceLog.instance.addEntry(
            type: 'harvest_result',
            source: BridgeSource.harvest.name,
            requestId: _currentRequestId,
            textLength: sanitized.length,
            note: 'shorter_than_accumulator_${_accumulator.length}',
            level: BridgeTraceLevel.info,
          );
          return null;
        }
        _emitChunk(sanitized, null, source: BridgeSource.harvest.name, isHarvest: true);
        return sanitized;
      }
      return null;
    } catch (e, st) {
      RitmoLog.error('ChatGptWebBridge', 'harvestVisibleAnswer error: $e', e, st);
      return null;
    } finally {
      _harvestInFlight = false;
      if (_harvestCompleter == completer) {
        _harvestCompleter = null;
      }
    }
  }

  /// Automatically executes salvage harvest before failing/completing on error or timeout (A-73, A-74).
  Future<String?> _harvestForSalvage({required String reason}) async {
    final activeReqId = _currentRequestId;
    try {
      final text = await harvestVisibleAnswer();
      if (_currentRequestId != activeReqId) {
        BridgeTraceLog.instance.addEntry(
          type: 'stale_event_dropped',
          source: BridgeSource.harvest.name,
          requestId: activeReqId,
          note: 'salvage_request_id_mismatch (now: $_currentRequestId)',
          level: BridgeTraceLevel.warn,
        );
        return null;
      }
      BridgeTraceLog.instance.addEntry(
        type: 'salvage_harvest',
        level: BridgeTraceLevel.info,
        source: BridgeSource.harvest.name,
        textLength: text?.length ?? 0,
        requestId: _currentRequestId,
        note: '${reason}_${text == null || text.isEmpty ? 'empty' : 'recovered'}',
      );
      return text;
    } catch (e, st) {
      RitmoLog.warning(
        'ChatGptWebBridge',
        'برداشت نجات در مسیر $reason شکست خورد: $e',
        e,
        st,
      );
      BridgeTraceLog.instance.addEntry(
        type: 'salvage_harvest',
        level: BridgeTraceLevel.error,
        source: BridgeSource.harvest.name,
        requestId: _currentRequestId,
        note: '${reason}_threw',
      );
      return null;
    }
  }

  /// Describes the probable cause of an empty response for diagnostics and UI (A-22, A-96).
  EmptyResponseReason describeEmptyResponseReason() {
    final reason = _computeEmptyResponseReason();
    _lastEmptyReasonDetail = reason.technicalDetail;
    return reason;
  }

  EmptyResponseReason _computeEmptyResponseReason() {
    if (_status == ChatGptBridgeStatus.cloudflareChallenge) {
      return const EmptyResponseReason(
        messageFa: 'برای ادامه گفتگو، لطفاً تایید امنیتی کلودفلر را کامل کنید.',
        technicalDetail: 'status: cloudflareChallenge',
      );
    }
    if (!isAuthenticated) {
      return const EmptyResponseReason(
        messageFa: 'نشست کاربری ChatGPT منقضی شده است. لطفاً وارد حساب شوید.',
        technicalDetail: 'status: auth_required',
      );
    }

    final recent = BridgeTraceLog.instance.entries.reversed.take(15).toList();
    final hadStaleDrops = recent.any((e) => e.type == 'stale_event_dropped');
    if (hadStaleDrops) {
      return const EmptyResponseReason(
        messageFa: 'ارتباط با گفتگو قطع شد. پیام را دوباره بفرستید.',
        technicalDetail: 'stale_event_dropped (requestId mismatch)',
      );
    }

    final hadChunks = recent.any((e) => e.type == 'chunk');
    final hadWatchdog = recent.any((e) => e.type == 'suppression_watchdog_release');
    if (hadChunks || hadWatchdog) {
      return const EmptyResponseReason(
        messageFa: 'پاسخ دریافت شد ولی قابل نمایش نبود. دوباره تلاش کنید.',
        technicalDetail: 'chunks received but suppressed or discarded in UI presenter',
      );
    }

    if (_status == ChatGptBridgeStatus.ready) {
      return const EmptyResponseReason(
        messageFa: 'چت‌جی‌پی‌تی پاسخ داد، اما برنامه نتوانست متن را از صفحهٔ مرورگر بخواند. احتمالاً رابط کاربری چت‌جی‌پی‌تی تغییر کرده است.',
        technicalDetail: 'ready without chunks (DOM watcher / selectors missed text)',
      );
    }

    return const EmptyResponseReason(
      messageFa: 'پاسخ در زمان مقرر کامل نشد.',
      technicalDetail: 'generation timeout or unhandled state',
    );
  }

  void _emitChunk(
    String? full,
    String? delta, {
    required String source,
    bool isHarvest = false,
  }) {
    final src = isHarvest ? BridgeSource.harvest : parseBridgeSource(source);
    if (src == BridgeSource.sse) {
      _hasActiveSseStream = true;
    }
    _lastChunkSource = src.name;

    final controller = _currentStreamController;
    if (controller == null || controller.isClosed) {
      BridgeTraceLog.instance.addEntry(
        type: 'chunk_dropped',
        source: src.name,
        note: 'dropped_no_controller',
        level: BridgeTraceLevel.warn,
      );
      return;
    }

    // ت-۸: برداشت هرگز توسط قفل منبع رد نمی‌شود.
    if (!src.bypassesSourceLock) {
      if (_shouldRejectForSourceLock(src)) {
        BridgeTraceLog.instance.addEntry(
          type: 'chunk_dropped',
          level: BridgeTraceLevel.warn,
          source: src.name,
          textLength: (full ?? delta ?? '').length,
          requestId: _currentRequestId,
          note: 'dropped_competing_chunk_locked_to_${_lockedSource?.name}',
        );
        return;
      }
      _acquireSourceLockIfNeeded(src);
      _lockedSourceLastChunkAt = DateTime.now();
      if (full != null) {
        _lockedSourceMaxLength = max(_lockedSourceMaxLength, full.length);
      }
    } else {
      BridgeTraceLog.instance.addEntry(
        type: 'harvest_override',
        level: BridgeTraceLevel.info,
        source: src.name,
        textLength: (full ?? delta ?? '').length,
        requestId: _currentRequestId,
        note: 'harvest_bypassed_lock_${_lockedSource?.name ?? 'none'}',
      );
    }

    AccumulatorDelta? result;
    if (full != null && full.isNotEmpty) {
      result = _accumulator.applyFull(full, source: src.name);
    } else if (delta != null && delta.isNotEmpty) {
      result = _accumulator.applyDelta(delta, source: src.name);
    }

    if (result == null) return;

    if (result.isRewrite) {
      controller.add(rewriteSentinel + result.fullText);
    } else {
      controller.add(result.delta);
    }

    _pendingRequest?.stage = PendingRequestStage.streaming;
    _pendingRequest?.receivedLength = _accumulator.length;
    BridgeTraceLog.instance.addEntry(
      type: 'chunk',
      source: src.name,
      requestId: _currentRequestId,
      textLength: _accumulator.length,
      level: BridgeTraceLevel.info,
    );
  }

  /// Flushes whatever the page ended up showing, then closes the stream (A-80).
  void _finishGeneration(String? fullText, {bool isPartial = false}) {
    _generationTimer?.cancel();
    _generationTimer = null;

    if (fullText != null && fullText.isNotEmpty) {
      _emitChunk(fullText, null, source: _lockedSource?.name ?? BridgeSource.harvest.name, isHarvest: true);
    }

    _lastAnswerWasPartial = isPartial;
    if (isPartial) {
      BridgeTraceLog.instance.addEntry(
        type: 'partial_finish',
        source: _lockedSource?.name ?? 'lifecycle',
        requestId: _currentRequestId,
        textLength: _accumulator.length,
        level: BridgeTraceLevel.warn,
      );
    }

    final finalText = _accumulator.text;
    BridgeTraceLog.instance.addEntry(
      type: 'finish',
      source: _lockedSource?.name ?? 'lifecycle',
      requestId: _currentRequestId,
      textLength: finalText.length,
      note: isPartial ? 'partial_finish' : 'complete_finish',
      level: BridgeTraceLevel.info,
    );

    final controller = _currentStreamController;
    _setStatus(ChatGptBridgeStatus.ready);
    _currentStreamController = null;
    _accumulator.reset();
    _navigationReloadCount = 0;
    _currentRequestId = null;
    _pendingRequest = null;
    _lastChunkSource = null;
    _lockedSource = null;
    _lockedSourceLastChunkAt = null;
    _lockedSourceMaxLength = 0;
    _hasActiveSseStream = false;
    controller?.close();
    _resetInactivityTimer();
  }

  void _failGeneration(dynamic errorOrMessageFa) {
    _generationTimer?.cancel();
    _generationTimer = null;

    final controller = _currentStreamController;
    _currentStreamController = null;
    _accumulator.reset();
    _navigationReloadCount = 0;
    _currentRequestId = null;
    _pendingRequest = null;
    _lastChunkSource = null;
    _lockedSource = null;
    _lockedSourceLastChunkAt = null;
    _lockedSourceMaxLength = 0;
    _hasActiveSseStream = false;

    _setStatus(ChatGptBridgeStatus.ready);
    if (controller != null && !controller.isClosed) {
      final WebBridgeException err;
      if (errorOrMessageFa is WebBridgeException) {
        err = errorOrMessageFa;
      } else if (errorOrMessageFa is String) {
        err = WebBridgeException.unknown(messageFa: errorOrMessageFa);
      } else {
        err = WebBridgeException.unknown(
          messageFa: errorOrMessageFa.toString(),
          originalError: errorOrMessageFa,
        );
      }
      controller.addError(err);
      controller.close();
    }
    _resetInactivityTimer();
  }

  /// Cancels the current stream if active and stops generation in the WebView (A-26)
  void cancelCurrentStream() {
    // 1. Cancel timers
    _generationTimer?.cancel();
    _generationTimer = null;

    // 2. Instruct JS bridge to cancel active generation with error logging
    try {
      _controller?.runJavaScript(ChatGptJsInjector.cancelScript);
    } catch (e, st) {
      RitmoLog.error('ChatGptWebBridge', 'Error sending cancel script to WebView: $e', e, st);
    }

    // 3. Reset internal tracking state
    _lockedSource = null;
    _lockedSourceLastChunkAt = null;
    _lockedSourceMaxLength = 0;
    _accumulator.reset();
    _navigationReloadCount = 0;
    _currentRequestId = null;
    _pendingRequest = null;
    _lastChunkSource = null;
    _hasActiveSseStream = false;

    // 4. Close and clear stream controller
    final controller = _currentStreamController;
    _currentStreamController = null;
    controller?.close();

    // 5. Restore status to ready so next prompt can be sent immediately
    _setStatus(ChatGptBridgeStatus.ready);
    _resetInactivityTimer();
  }

  @visibleForTesting
  void cancelTimersForTesting() {
    _inactivityTimer?.cancel();
    _inactivityTimer = null;
    _generationTimer?.cancel();
    _generationTimer = null;
  }

  /// Sends a prompt and streams the assistant response back.
  Stream<String> sendPrompt({
    required String prompt,
    String? personaTitle,
    String? personaSystemPrompt,
    String? contextSummary,
    List<String>? recentHistory,
  }) async* {
    // A-13: In-flight guard — refuse concurrent sendPrompt and yield Persian error
    if (_status == ChatGptBridgeStatus.generating &&
        _currentStreamController != null &&
        !_currentStreamController!.isClosed) {
      RitmoLog.warning(
        'ChatGptWebBridgeManager',
        'sendPrompt refused: generation already in flight (reqId: $_currentRequestId)',
      );
      BridgeTraceLog.instance.addEntry(
        type: 'send_refused',
        source: 'lifecycle',
        requestId: _currentRequestId,
        note: 'already_generating',
        level: BridgeTraceLevel.warn,
      );
      yield 'error:یک پاسخ در حال دریافت است. لطفاً تا پایان آن صبر کنید یا انصراف بدهید.';
      return;
    }

    _resetInactivityTimer();
    _navigationReloadCount = 0;
    _lastChunkSource = null;
    _lockedSource = null;
    _lockedSourceLastChunkAt = null;
    _lockedSourceMaxLength = 0;
    _hasActiveSseStream = false;

    final booted = await ensureBooted();
    if (!booted && _status == ChatGptBridgeStatus.cloudflareChallenge) {
      yield 'error:برای ادامه گفتگو، لطفاً تایید امنیتی کلودفلر را در پنجره باز شده کامل کنید.';
      return;
    }

    if (!booted || _controller == null) {
      yield 'error:عدم دسترسی به وب‌سایت ChatGPT. لطفاً اتصال اینترنت خود را بررسی کنید.';
      return;
    }

    String? userName;
    try {
      final db = await DatabaseHelper.instance.database;
      final rows = await db.query(
        'app_settings',
        where: 'key = ?',
        whereArgs: ['user_name'],
        limit: 1,
      );
      if (rows.isNotEmpty) {
        userName = rows.first['value'] as String?;
      }
    } catch (e, st) {
      RitmoLog.error('ChatGptWebBridge', 'Error fetching user_name: $e', e, st);
    }

    final previous = _currentStreamController;
    _currentStreamController = null;
    if (previous != null && !previous.isClosed) {
      await previous.close();
    }

    _setStatus(ChatGptBridgeStatus.generating);
    _accumulator.reset();

    final reqId = _generateRequestId();
    _currentRequestId = reqId;
    _pendingRequest = PendingWebBridgeRequest(
      requestId: reqId,
      promptHash: prompt.hashCode.toRadixString(16),
      promptText: prompt,
      sentAt: DateTime.now(),
      stage: PendingRequestStage.sending,
      personaTitle: personaTitle,
      personaSystemPrompt: personaSystemPrompt,
      contextSummary: contextSummary,
      recentHistory: recentHistory,
    );

    final streamController = StreamController<String>(
      onCancel: () {
        RitmoLog.debug('ChatGptWebBridge', 'Stream subscriber cancelled.');
        cancelCurrentStream();
      },
    );
    _currentStreamController = streamController;

    if (!isAuthenticated) {
      _failGeneration(WebBridgeException.authRequired());
      yield* streamController.stream;
      return;
    }

    if (_status == ChatGptBridgeStatus.cloudflareChallenge) {
      _failGeneration(WebBridgeException.cloudflareChallenge());
      yield* streamController.stream;
      return;
    }

    final formattedPrompt = ChatGptJsInjector.formatPromptWithSystemDirective(
      userPrompt: prompt,
      personaTitle: personaTitle,
      personaSystemPrompt: personaSystemPrompt,
      userName: userName,
      contextSummary: contextSummary,
      recentHistory: recentHistory,
    );

    final jsCall = ChatGptJsInjector.buildSendPromptScript(
      formattedPrompt,
      requestId: reqId,
    );

    final composerReady = await waitForComposerReady();
    if (!composerReady) {
      RitmoLog.debug('ChatGptWebBridge', 'Composer not ready after wait; proceeding with optimistic injection.');
    }

    await _controller!.runJavaScript(jsCall);

    _generationTimer?.cancel();
    _generationTimer = Timer(ChatGptBridgeTimeouts.generationTimeout, () async {
      if (!identical(_currentStreamController, streamController)) return;
      RitmoLog.debug('ChatGptWebBridge', 'Generation timed out after ${ChatGptBridgeTimeouts.generationTimeout.inSeconds}s (reqId: $reqId).');
      BridgeTraceLog.instance.addEntry(
        type: 'generation_timeout',
        level: BridgeTraceLevel.warn,
        source: BridgeSource.dart.name,
        textLength: _accumulator.length,
        requestId: _currentRequestId,
        note: 'accumulator_${_accumulator.isEmpty ? 'empty' : 'partial'}_before_harvest',
      );

      final harvested = await _harvestForSalvage(reason: 'generation_timeout');
      if (!identical(_currentStreamController, streamController)) return;

      if (harvested != null && harvested.trim().isNotEmpty) {
        _finishGeneration(null, isPartial: false);
        return;
      }
      if (_accumulator.isEmpty) {
        _failGeneration(
          WebBridgeException.timeout(
            messageFa: 'پاسخی از صفحهٔ ChatGPT دریافت نشد. لطفاً پنجرهٔ مرورگر را باز کنید و وضعیت ورود یا تایید امنیتی را بررسی کنید.',
          ),
        );
      } else {
        _finishGeneration(null, isPartial: true);
      }
    });

    yield* streamController.stream;
  }

  /// Resets the inactivity countdown.
  void _resetInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(ChatGptBridgeTimeouts.inactivityTimeout, () {
      if (_status == ChatGptBridgeStatus.generating ||
          _currentStreamController != null) {
        _resetInactivityTimer();
        return;
      }
      RitmoLog.debug('ChatGptWebBridge', 'Inactivity timeout reached. Releasing WebView reference.');
      disposeWebView();
    });
  }

  /// Drops this side's references to the WebView after safely halting native background activity.
  void disposeWebView() {
    _inactivityTimer?.cancel();
    _inactivityTimer = null;
    _generationTimer?.cancel();
    _generationTimer = null;

    final controller = _currentStreamController;
    _currentStreamController = null;
    _accumulator.reset();
    _lockedSource = null;
    _lockedSourceLastChunkAt = null;
    _lockedSourceMaxLength = 0;
    _navigationReloadCount = 0;
    _currentRequestId = null;
    _pendingRequest = null;
    _lastChunkSource = null;
    _hasActiveSseStream = false;
    controller?.close();

    _bootCompleter = null;
    final oldController = _controller;
    _controller = null;
    if (oldController != null) {
      unawaited(_safeDisposeController(oldController));
    }
    _cloudflareNotifier.value = false;
    _setStatus(ChatGptBridgeStatus.idle);
    RitmoLog.debug('ChatGptWebBridge', 'WebView reference released.');
  }

  /// Safely halts any ongoing native operations (network/JS/Chromium looper) on [controllerToDispose]
  /// before releasing references, preventing Android WebChromeClient/WebViewClient
  /// `IllegalStateException: Could not find identifier for WebChromeClient` crashes in InstanceManager.
  Future<void> _safeDisposeController(WebViewController? controllerToDispose) async {
    if (controllerToDispose == null) return;
    try {
      // 1. Remove JS channel to avoid callback delivery
      await controllerToDispose.removeJavaScriptChannel('RitmoChatBridge');
    } catch (e, st) {
      RitmoLog.warning('ChatGptWebBridge', 'Could not remove channel during dispose: $e', e, st);
    }

    try {
      // 2. Load blank page to abort in-flight resource loads in native Chromium immediately
      await controllerToDispose.loadRequest(Uri.parse('about:blank'));
    } catch (e, st) {
      RitmoLog.warning('ChatGptWebBridge', 'Could not load blank page during dispose: $e', e, st);
    }
  }

  /// Reloads the current WebView page if available.
  Future<void> reloadPage() async {
    try {
      await _controller?.reload();
      RitmoLog.debug('ChatGptWebBridge', 'Page reload requested.');
    } catch (e, st) {
      RitmoLog.error('ChatGptWebBridge', 'Error reloading page: $e', e, st);
    }
  }

  /// Clears session cookies and cache from the WebView.
  Future<void> clearSessionCookies() async {
    try {
      final cookieManager = WebViewCookieManager();
      await cookieManager.clearCookies();
      _isAuthenticated = false;
      RitmoLog.debug('ChatGptWebBridge', 'Session cookies cleared.');
    } catch (e, st) {
      RitmoLog.error('ChatGptWebBridge', 'Error clearing session cookies: $e', e, st);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      if (_status != ChatGptBridgeStatus.generating) {
        RitmoLog.debug('ChatGptWebBridge', 'App paused/detached, releasing WebView.');
        disposeWebView();
      }
    }
  }
}
