import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:ritmo/core/ai/web_bridge/bridge_response_accumulator.dart';
import 'package:ritmo/core/ai/web_bridge/bridge_trace_log.dart';
import 'package:ritmo/core/ai/web_bridge/chatgpt_bridge_timeouts.dart';
import 'package:ritmo/core/ai/web_bridge/chatgpt_dom_inspector.dart';
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
  vpnRequired,
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

  /// فلگ کنترل استریمینگ برای انتقال پیام‌ها از ChatGPT به صفحه چت دستیار.
  /// به صورت پیش‌فرض فعال است تا تکه‌های متن به شکل زنده در UI استریم شوند (DET-34).
  static bool enableWebBridgeStreaming = true;

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

  final ValueNotifier<bool> _vpnRequiredNotifier = ValueNotifier<bool>(false);
  ValueListenable<bool> get vpnRequiredNotifier => _vpnRequiredNotifier;

  String? _lastRayId;
  String? get lastRayId => _lastRayId;

  String? _lastBlockedIp;
  String? get lastBlockedIp => _lastBlockedIp;

  final ValueNotifier<ChatGptBridgeStatus> _statusNotifier =
      ValueNotifier<ChatGptBridgeStatus>(ChatGptBridgeStatus.idle);
  ValueListenable<ChatGptBridgeStatus> get statusNotifier => _statusNotifier;

  Timer? _inactivityTimer;
  Timer? _generationTimer;
  Timer? _checkpointTimer1;
  Timer? _checkpointTimer2;
  Timer? _checkpointTimer3;
  Timer? _resumeDebounceTimer;
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

  bool _isFinishingOrFailingGeneration = false;

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

  static const int requiredBridgeVersion = ChatGptJsInjector.bridgeVersion;
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

  void _cancelResumeDebounce() {
    _resumeDebounceTimer?.cancel();
    _resumeDebounceTimer = null;
  }

  @visibleForTesting
  Timer? get resumeDebounceTimerForTest => _resumeDebounceTimer;

  @visibleForTesting
  void resetStateForTest() {
    _inactivityTimer?.cancel();
    _inactivityTimer = null;
    _generationTimer?.cancel();
    _generationTimer = null;
    _checkpointTimer1?.cancel();
    _checkpointTimer1 = null;
    _checkpointTimer2?.cancel();
    _checkpointTimer2 = null;
    _checkpointTimer3?.cancel();
    _checkpointTimer3 = null;
    _cancelResumeDebounce();
    _navigationReloadCount = 0;
    _coldNavigationCount = 0;
    _setStatus(ChatGptBridgeStatus.idle, force: true);
    _currentRequestId = null;
    _pendingRequest = null;
    _lockedSource = null;
    _lockedSourceLastChunkAt = null;
    _lockedSourceMaxLength = 0;
    _lastChunkSource = null;
    _lastAnswerWasPartial = false;
    _lastEmptyReasonDetail = null;
    _lastRayId = null;
    _lastBlockedIp = null;
    _vpnRequiredNotifier.value = false;
    _cloudflareNotifier.value = false;
    _accumulator.reset();
    _currentStreamController?.close();
    _currentStreamController = null;
  }

  @visibleForTesting
  void setStatusForTest(ChatGptBridgeStatus status, {bool force = false}) {
    _setStatus(status, force: force);
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
    bool force = true,
  }) {
    if (status != null) _setStatus(status, force: force);
    if (controller != null) _controller = controller;
    if (bootCompleter != null) _bootCompleter = bootCompleter;
    if (streamController != null) _currentStreamController = streamController;
  }

  void _setStatus(ChatGptBridgeStatus newStatus, {bool force = false}) {
    if (_status == newStatus) return;

    if (_status == ChatGptBridgeStatus.generating &&
        !force &&
        !_isFinishingOrFailingGeneration &&
        _currentStreamController != null &&
        !_currentStreamController!.isClosed) {
      if (newStatus != ChatGptBridgeStatus.error &&
          newStatus != ChatGptBridgeStatus.idle &&
          newStatus != ChatGptBridgeStatus.cloudflareChallenge &&
          newStatus != ChatGptBridgeStatus.vpnRequired) {
        RitmoLog.warning(
          'ChatGptWebBridge',
          'Blocked illegal status transition from generating to $newStatus while stream is active.',
        );
        BridgeTraceLog.instance.addEntry(
          type: 'illegal_status_transition_blocked',
          source: BridgeSource.dart.name,
          requestId: _currentRequestId,
          note: 'from_generating_to_${newStatus.name}',
          level: BridgeTraceLevel.warn,
        );
        return;
      }
    }

    _status = newStatus;
    _statusNotifier.value = newStatus;
    if (newStatus == ChatGptBridgeStatus.cloudflareChallenge) {
      _cloudflareNotifier.value = true;
    } else if (_cloudflareNotifier.value && newStatus == ChatGptBridgeStatus.ready) {
      _cloudflareNotifier.value = false;
    }
    if (newStatus == ChatGptBridgeStatus.vpnRequired) {
      _vpnRequiredNotifier.value = true;
    } else if (_vpnRequiredNotifier.value && newStatus == ChatGptBridgeStatus.ready) {
      _vpnRequiredNotifier.value = false;
    }
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

    // Protect vpnRequired in progress
    if (_status == ChatGptBridgeStatus.vpnRequired) {
      RitmoLog.debug('ChatGptWebBridgeManager', 'ensureBooted skipped: vpnRequired in progress (controller exists: ${_controller != null})');
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
            if (_status == ChatGptBridgeStatus.generating) {
              BridgeTraceLog.instance.addEntry(
                type: 'page_finished_during_generation',
                source: BridgeSource.dart.name,
                requestId: _currentRequestId,
                note: 'url=$url',
                level: BridgeTraceLevel.info,
              );
            }
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

  int _coldNavigationCount = 0;
  @visibleForTesting
  int get coldNavigationCount => _coldNavigationCount;

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
      BridgeTraceLog.instance.addEntry(
        type: 'in_flight_navigation_finished',
        source: BridgeSource.dart.name,
        requestId: _pendingRequest?.requestId ?? _currentRequestId,
        note: 'url=$url reloadCount=$_navigationReloadCount',
        level: BridgeTraceLevel.info,
      );
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

      _attemptResumePendingRequest(controller);
    } else {
      _coldNavigationCount++;
      RitmoLog.debug('ChatGptWebBridge', 'Cold navigation finished (count: $_coldNavigationCount)');
      BridgeTraceLog.instance.addEntry(
        type: 'cold_navigation_finished',
        source: BridgeSource.dart.name,
        note: 'url=$url coldCount=$_coldNavigationCount',
        level: BridgeTraceLevel.info,
      );
    }
  }

  void _attemptResumePendingRequest(WebViewController controller) {
    _cancelResumeDebounce();

    final reqId = _pendingRequest?.requestId ?? _currentRequestId;
    BridgeTraceLog.instance.addEntry(
      type: 'resume_debounced',
      source: BridgeSource.dart.name,
      requestId: reqId,
      note: 'delayMs=500',
      level: BridgeTraceLevel.info,
    );

    _resumeDebounceTimer = Timer(const Duration(milliseconds: 500), () async {
      if (!hasPendingRequest && _status != ChatGptBridgeStatus.generating) return;

      RitmoLog.debug('ChatGptWebBridge', 'Attempting re-attachment / resume after navigation for req: ${_pendingRequest?.requestId}...');
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
    });
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
    _vpnRequiredNotifier.value = false;
    _lastRayId = null;
    _lastBlockedIp = null;
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
      if (_status == ChatGptBridgeStatus.ready || _status == ChatGptBridgeStatus.generating) return true;
      if (_status == ChatGptBridgeStatus.cloudflareChallenge ||
          _status == ChatGptBridgeStatus.vpnRequired) {
        return false;
      }
      await Future.delayed(const Duration(milliseconds: 300));
    }
    return _status == ChatGptBridgeStatus.ready || _status == ChatGptBridgeStatus.generating;
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
          event is! BridgeCloudflareEvent &&
          event is! BridgeVpnRequiredEvent) {
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
        case BridgeReadyEvent(:final isAuthed, :final isWarm, :final currentPath, :final hasComposer, :final version):
          _isAuthenticated = isAuthed;
          if (_bootCompleter != null && !_bootCompleter!.isCompleted) {
            _bootCompleter!.complete(true);
          }
          if (_cloudflareNotifier.value) {
            _cloudflareNotifier.value = false;
          }

          if (_status == ChatGptBridgeStatus.generating || _pendingRequest != null) {
            BridgeTraceLog.instance.addEntry(
              type: 'ready_ignored_during_generation',
              source: source,
              requestId: _currentRequestId ?? _pendingRequest?.requestId,
              note: 'warm=$isWarm path=${currentPath ?? ""} composer=$hasComposer reqId=${_currentRequestId ?? _pendingRequest?.requestId}',
              level: BridgeTraceLevel.info,
            );
            return;
          }

          if (_status == ChatGptBridgeStatus.idle ||
              _status == ChatGptBridgeStatus.booting ||
              _status == ChatGptBridgeStatus.error ||
              _status == ChatGptBridgeStatus.cloudflareChallenge ||
              _status == ChatGptBridgeStatus.vpnRequired) {
            _setStatus(ChatGptBridgeStatus.ready);
          }

          BridgeTraceLog.instance.addEntry(
            type: 'ready',
            source: source,
            note: 'warm=$isWarm path=${currentPath ?? ""} composer=$hasComposer v=$version authed=$isAuthed',
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

        case BridgePromptTypedEvent(:final length, :final requestId):
          BridgeTraceLog.instance.addEntry(
            type: 'prompt_typed',
            source: source,
            requestId: requestId,
            textLength: length,
            level: BridgeTraceLevel.info,
          );

        case BridgeSendClickedEvent(:final matchedSelector, :final candidateCount, :final requestId):
          BridgeTraceLog.instance.addEntry(
            type: 'send_clicked',
            source: source,
            requestId: requestId,
            note: 'selector=$matchedSelector candidates=$candidateCount',
            level: BridgeTraceLevel.info,
          );

        case BridgeSendFallbackEnterEvent(:final requestId):
          BridgeTraceLog.instance.addEntry(
            type: 'send_fallback_enter',
            source: source,
            requestId: requestId,
            level: BridgeTraceLevel.warn,
          );

        case BridgeSendRetryTriggeredEvent(:final requestId):
          BridgeTraceLog.instance.addEntry(
            type: 'send_retry_triggered',
            source: source,
            requestId: requestId,
            note: 'editor_not_cleared_after_1s',
            level: BridgeTraceLevel.warn,
          );

        case BridgeComposerNotFoundEvent(:final requestId):
          BridgeTraceLog.instance.addEntry(
            type: 'composer_not_found',
            source: source,
            requestId: requestId,
            level: BridgeTraceLevel.error,
          );

        case BridgeWatcherTickEvent(:final requestId, :final textLength, :final hasStopButton, :final hasStreamingIndicator, :final assistantNodes, :final turnCount, :final markdownBodies, :final idleMs, :final elapsedMs):
          BridgeTraceLog.instance.addEntry(
            type: 'watcher_tick',
            source: source,
            requestId: requestId,
            textLength: textLength,
            note: 'stop=$hasStopButton stream=$hasStreamingIndicator assistants=$assistantNodes turns=$turnCount md=$markdownBodies idle=${idleMs}ms elapsed=${elapsedMs}ms',
            level: BridgeTraceLevel.info,
          );

        case BridgeWatcherSteadyDoneEvent(:final textLength, :final idleMs, :final requestId):
          BridgeTraceLog.instance.addEntry(
            type: 'watcher_steady_done',
            source: source,
            requestId: requestId,
            textLength: textLength,
            note: 'idleMs=${idleMs}ms',
            level: BridgeTraceLevel.info,
          );

        case BridgeStreamCompletionEvaluatedEvent(:final reason, :final idleMs, :final textLength, :final requestId):
          BridgeTraceLog.instance.addEntry(
            type: 'stream_completion_evaluated',
            source: source,
            requestId: requestId,
            textLength: textLength,
            note: 'reason=$reason idleMs=${idleMs}ms',
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

        case BridgeGuestSessionDetectedEvent(:final hasComposer, :final hasLoginButton, :final currentPath):
          _isAuthenticated = true; // Guest session allows chat without login
          RitmoLog.info(
            'ChatGptWebBridge',
            'Guest session detected: composer=$hasComposer, loginBtn=$hasLoginButton, path=$currentPath',
          );
          BridgeTraceLog.instance.addEntry(
            type: 'guest_session_detected',
            source: source,
            note: 'isGuest=true composer=$hasComposer path=$currentPath',
            level: BridgeTraceLevel.info,
          );

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

        case BridgeCloudflareResolvedEvent():
          if (_status == ChatGptBridgeStatus.cloudflareChallenge) {
            _setStatus(ChatGptBridgeStatus.ready);
          }
          _cloudflareNotifier.value = false;
          RitmoLog.info('ChatGptWebBridge', 'Cloudflare challenge resolved.');
          BridgeTraceLog.instance.addEntry(
            type: 'cloudflare_resolved',
            source: source,
            note: 'challenge_resolved',
            level: BridgeTraceLevel.info,
          );

        case BridgeVpnRequiredEvent(:final reason, :final rayId, :final ip):
          _lastRayId = rayId;
          _lastBlockedIp = ip;
          if (_status != ChatGptBridgeStatus.vpnRequired) {
            _setStatus(ChatGptBridgeStatus.vpnRequired);
            RitmoLog.warning(
              'ChatGptWebBridge',
              'VPN / Geo-block detected: reason=$reason, rayId=$rayId, ip=$ip',
            );
          }
          BridgeTraceLog.instance.addEntry(
            type: 'vpn_required',
            source: source,
            note: '$reason (rayId: $rayId, ip: $ip)',
            level: BridgeTraceLevel.error,
          );
          if (_status == ChatGptBridgeStatus.generating && _accumulator.isEmpty) {
            _failGeneration(WebBridgeException.vpnRequired(rayId: rayId, ip: ip));
          }

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

        case BridgeResumeSkippedDuplicateEvent(:final requestId):
          BridgeTraceLog.instance.addEntry(
            type: 'resume_skipped_duplicate',
            source: source,
            requestId: requestId,
            note: 'watcher_already_running',
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
            _failGeneration(WebBridgeException.rateLimited(
              statusCode: statusCode,
              messageFa: message.isNotEmpty ? message : null,
            ));
          } else if (statusCode == 401 || statusCode == 403) {
            _failGeneration(WebBridgeException.authRequired(
              messageFa: message.isNotEmpty
                  ? message
                  : 'نشست کاربری ChatGPT منقضی شده است. لطفاً پنجرهٔ ورود را باز کنید.',
            ));
          } else if (statusCode >= 500 && statusCode <= 599) {
            _failGeneration(WebBridgeException.serverError(
              statusCode: statusCode,
              messageFa: message.isNotEmpty ? message : null,
            ));
          } else {
            _failGeneration(WebBridgeException.networkError(
              statusCode: statusCode,
              messageFa: message.isNotEmpty ? message : null,
            ));
          }

        case final BridgeErrorEvent errEvent:
          final message = errEvent.message;
          final requestId = errEvent.requestId;
          final msg = message ?? 'Bridge error';
          BridgeTraceLog.instance.addEntry(
            type: 'error',
            source: source,
            requestId: requestId,
            note: 'message="$msg"',
            level: BridgeTraceLevel.error,
          );
          if (_status == ChatGptBridgeStatus.generating &&
              (requestId == null || requestId.isEmpty || requestId == _currentRequestId)) {
            _failGeneration(WebBridgeException.bridgeError(
              message: msg,
              source: source,
            ));
          }

        case BridgeSelectorHealthEvent(:final issue, :final bridgeVersion, :final report, :final phase, :final requestId):
          _lastSelectorHealthReport = report;
          BridgeTraceLog.instance.addEntry(
            type: 'selector_health',
            source: source,
            requestId: requestId,
            note: 'phase=$phase issue="$issue" v=$bridgeVersion report=$report',
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

        case BridgeFetchMatchedEvent(:final url, :final method, :final isStream, :final requestId):
          BridgeTraceLog.instance.addEntry(
            type: 'fetch_matched',
            source: source,
            requestId: requestId,
            note: 'method=$method isStream=$isStream url=$url',
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
          final ctrl = _currentStreamController;
          if (fullText.isNotEmpty) {
            if (ctrl != null && !ctrl.isClosed) {
              _emitChunk(fullText, null, source: BridgeSource.harvest.name, isHarvest: true);
              _finishGeneration(null, isPartial: false);
            } else {
              BridgeTraceLog.instance.addEntry(
                type: 'harvest_rejected_stream_closed',
                source: BridgeSource.harvest.name,
                requestId: requestId,
                textLength: fullText.length,
                note: 'stream_controller_closed_or_null',
                level: BridgeTraceLevel.warn,
              );
            }
          }

        case BridgeUnknownEvent(:final type, :final error, :final rawPayload):
          RitmoLog.error('ChatGptWebBridge', 'Unhandled JS message: type=$type raw=$rawPayload error=$error');
          BridgeTraceLog.instance.addEntry(
            type: 'unknown_event',
            source: source,
            note: 'type=$type raw=$rawPayload error=$error',
            level: BridgeTraceLevel.error,
          );
          if (type == 'error' && _status == ChatGptBridgeStatus.generating) {
            _failGeneration(WebBridgeException.unknown(
              messageFa: 'خطای ناشناخته در پل وب ChatGPT: $rawPayload',
            ));
          }
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
    if (_status == ChatGptBridgeStatus.vpnRequired) {
      return EmptyResponseReason(
        messageFa: 'دسترسی به چت‌جی‌پی‌تی از این IP مسدود است (تحریم یا فیلترینگ). لطفاً فیلترشکن یا تحریم‌شکن خود را فعال کنید.${_lastRayId != null ? ' (Ray ID: $_lastRayId)' : ''}',
        technicalDetail: 'status: vpnRequired (Ray ID: $_lastRayId, IP: $_lastBlockedIp)',
      );
    }
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
      if (src == BridgeSource.sse && _lockedSource == BridgeSource.dom) {
        RitmoLog.info('ChatGptWebBridge', 'SSE source promoted over DOM watcher.');
        BridgeTraceLog.instance.addEntry(
          type: 'source_promoted',
          source: BridgeSource.sse.name,
          requestId: _currentRequestId,
          note: 'promoted_over_dom',
          level: BridgeTraceLevel.info,
        );
        _lockedSource = BridgeSource.sse;
        _lockedSourceMaxLength = _accumulator.length;
      }

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

    if (enableWebBridgeStreaming) {
      if (result.isRewrite) {
        controller.add(rewriteSentinel + result.fullText);
      } else {
        controller.add(result.delta);
      }
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
    _isFinishingOrFailingGeneration = true;
    try {
      _cancelResumeDebounce();
      _generationTimer?.cancel();
      _generationTimer = null;
      _checkpointTimer1?.cancel();
      _checkpointTimer1 = null;
      _checkpointTimer2?.cancel();
      _checkpointTimer2 = null;
      _checkpointTimer3?.cancel();
      _checkpointTimer3 = null;

      if (fullText != null && fullText.isNotEmpty) {
        _emitChunk(fullText, null, source: _lockedSource?.name ?? BridgeSource.harvest.name, isHarvest: true);
      }

      _lastAnswerWasPartial = isPartial;
      if (isPartial) {
        BridgeTraceLog.instance.addEntry(
          type: 'partial_finish',
          source: _lockedSource?.name ?? BridgeSource.lifecycle.name,
          requestId: _currentRequestId,
          textLength: _accumulator.length,
          level: BridgeTraceLevel.warn,
        );
      }

      final finalText = _accumulator.text;
      BridgeTraceLog.instance.addEntry(
        type: 'finish',
        source: _lockedSource?.name ?? BridgeSource.lifecycle.name,
        requestId: _currentRequestId,
        textLength: finalText.length,
        note: isPartial ? 'partial_finish' : 'complete_finish',
        level: BridgeTraceLevel.info,
      );

      final controller = _currentStreamController;
      if (!enableWebBridgeStreaming && controller != null && !controller.isClosed) {
        if (finalText.isNotEmpty) {
          controller.add(finalText);
        }
      }

      _setStatus(ChatGptBridgeStatus.ready);
      _currentStreamController = null;
      _accumulator.reset();
      _navigationReloadCount = 0;
      _coldNavigationCount = 0;
      _currentRequestId = null;
      _pendingRequest = null;
      _lastChunkSource = null;
      _lockedSource = null;
      _lockedSourceLastChunkAt = null;
      _lockedSourceMaxLength = 0;
      _hasActiveSseStream = false;
      controller?.close();
      _resetInactivityTimer();
    } finally {
      _isFinishingOrFailingGeneration = false;
    }
  }

  void _failGeneration(dynamic errorOrMessageFa) {
    _isFinishingOrFailingGeneration = true;
    try {
      _cancelResumeDebounce();
      _generationTimer?.cancel();
      _generationTimer = null;
      _checkpointTimer1?.cancel();
      _checkpointTimer1 = null;
      _checkpointTimer2?.cancel();
      _checkpointTimer2 = null;
      _checkpointTimer3?.cancel();
      _checkpointTimer3 = null;

      final controller = _currentStreamController;
      _currentStreamController = null;
      _accumulator.reset();
      _navigationReloadCount = 0;
      _coldNavigationCount = 0;
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
    } finally {
      _isFinishingOrFailingGeneration = false;
    }
  }

  /// Cancels the current stream if active and stops generation in the WebView (A-26)
  void cancelCurrentStream() {
    // 1. Cancel timers
    _generationTimer?.cancel();
    _generationTimer = null;
    _checkpointTimer1?.cancel();
    _checkpointTimer1 = null;
    _checkpointTimer2?.cancel();
    _checkpointTimer2 = null;
    _checkpointTimer3?.cancel();
    _checkpointTimer3 = null;

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
    _coldNavigationCount = 0;
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
  void failGenerationForTest(dynamic error) => _failGeneration(error);

  @visibleForTesting
  void cancelTimersForTesting() {
    _inactivityTimer?.cancel();
    _inactivityTimer = null;
    _generationTimer?.cancel();
    _generationTimer = null;
    _checkpointTimer1?.cancel();
    _checkpointTimer1 = null;
    _checkpointTimer2?.cancel();
    _checkpointTimer2 = null;
    _checkpointTimer3?.cancel();
    _checkpointTimer3 = null;
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
        source: BridgeSource.lifecycle.name,
        requestId: _currentRequestId,
        note: 'already_generating',
        level: BridgeTraceLevel.warn,
      );
      yield 'error:یک پاسخ در حال دریافت است. لطفاً تا پایان آن صبر کنید یا انصراف بدهید.';
      return;
    }

    _resetInactivityTimer();
    _navigationReloadCount = 0;
    _coldNavigationCount = 0;
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

    if (!booted && _status == ChatGptBridgeStatus.vpnRequired) {
      yield 'error:دسترسی به چت‌جی‌پی‌تی از این IP مسدود است (تحریم یا فیلترینگ). لطفاً فیلترشکن یا تحریم‌شکن خود را فعال کرده و دوباره تلاش کنید.';
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

    if (_status == ChatGptBridgeStatus.vpnRequired) {
      _failGeneration(WebBridgeException.vpnRequired(rayId: _lastRayId, ip: _lastBlockedIp));
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

    _checkpointTimer1?.cancel();
    _checkpointTimer1 = Timer(ChatGptBridgeTimeouts.checkpoint1Delay, () async {
      if (!identical(_currentStreamController, streamController)) {
        BridgeTraceLog.instance.addEntry(
          type: 'checkpoint_skipped',
          source: BridgeSource.dart.name,
          requestId: reqId,
          note: 'timer1_controller_mismatch',
          level: BridgeTraceLevel.info,
        );
        return;
      }
      await _runCheckpointCheck(1, streamController, reqId);
    });

    _checkpointTimer2?.cancel();
    _checkpointTimer2 = Timer(ChatGptBridgeTimeouts.checkpoint2Delay, () async {
      if (!identical(_currentStreamController, streamController)) {
        BridgeTraceLog.instance.addEntry(
          type: 'checkpoint_skipped',
          source: BridgeSource.dart.name,
          requestId: reqId,
          note: 'timer2_controller_mismatch',
          level: BridgeTraceLevel.info,
        );
        return;
      }
      await _runCheckpointCheck(2, streamController, reqId);
    });

    _checkpointTimer3?.cancel();
    _checkpointTimer3 = Timer(ChatGptBridgeTimeouts.checkpoint3Delay, () async {
      if (!identical(_currentStreamController, streamController)) {
        BridgeTraceLog.instance.addEntry(
          type: 'checkpoint_skipped',
          source: BridgeSource.dart.name,
          requestId: reqId,
          note: 'timer3_controller_mismatch',
          level: BridgeTraceLevel.info,
        );
        return;
      }
      await _runCheckpointCheck(3, streamController, reqId);
    });

    try {
      yield* streamController.stream;
    } finally {
      if (_status == ChatGptBridgeStatus.generating &&
          identical(_currentStreamController, streamController)) {
        _finishGeneration(null, isPartial: true);
      }
    }
  }

  @visibleForTesting
  Future<void> runCheckpointCheckForTesting(
    int checkpointNumber,
    StreamController<String> streamController,
    String reqId,
  ) =>
      _runCheckpointCheck(checkpointNumber, streamController, reqId);

  /// Checks WebView DOM at intermediate checkpoints before timeout to see if ChatGPT has answered.
  Future<void> _runCheckpointCheck(
    int checkpointNumber,
    StreamController<String> streamController,
    String reqId,
  ) async {
    if (!identical(_currentStreamController, streamController)) {
      BridgeTraceLog.instance.addEntry(
        type: 'checkpoint_skipped',
        source: BridgeSource.dart.name,
        requestId: reqId,
        note: 'checkpoint_${checkpointNumber}_skipped_controller_mismatch',
        level: BridgeTraceLevel.info,
      );
      return;
    }
    if (streamController.isClosed) {
      BridgeTraceLog.instance.addEntry(
        type: 'checkpoint_skipped',
        source: BridgeSource.dart.name,
        requestId: reqId,
        note: 'checkpoint_${checkpointNumber}_skipped_controller_closed',
        level: BridgeTraceLevel.info,
      );
      return;
    }

    RitmoLog.debug('ChatGptWebBridge', 'Running checkpoint check #$checkpointNumber for reqId: $reqId');
    BridgeTraceLog.instance.addEntry(
      type: 'checkpoint_check_started',
      source: BridgeSource.dart.name,
      requestId: reqId,
      note: 'checkpoint_$checkpointNumber',
      level: BridgeTraceLevel.info,
    );

    try {
      final harvested = await harvestVisibleAnswer();
      if (!identical(_currentStreamController, streamController)) {
        BridgeTraceLog.instance.addEntry(
          type: 'checkpoint_skipped',
          source: BridgeSource.dart.name,
          requestId: reqId,
          note: 'checkpoint_${checkpointNumber}_post_harvest_controller_mismatch',
          level: BridgeTraceLevel.info,
        );
        return;
      }
      if (streamController.isClosed) {
        BridgeTraceLog.instance.addEntry(
          type: 'checkpoint_skipped',
          source: BridgeSource.dart.name,
          requestId: reqId,
          note: 'checkpoint_${checkpointNumber}_post_harvest_controller_closed',
          level: BridgeTraceLevel.info,
        );
        return;
      }

      if (harvested != null && harvested.trim().isNotEmpty) {
        // Inspect whether ChatGPT is still actively generating or completed
        bool isStillGenerating = false;
        try {
          final evalResult = await _controller?.runJavaScriptReturningResult(
            "(function() { var s = document.querySelector('button[data-testid=\"stop-button\"], button[aria-label=\"Stop generating\"], button[aria-label=\"توقف تولید\"], .result-streaming'); return !!s; })()",
          );
          if (evalResult != null) {
            isStillGenerating = evalResult.toString() == 'true' || evalResult == true;
          }
        } catch (evalErr) {
          RitmoLog.debug('ChatGptWebBridge', 'eval isGenerating check error: $evalErr');
        }

        if (!isStillGenerating) {
          RitmoLog.debug(
            'ChatGptWebBridge',
            'Checkpoint check #$checkpointNumber detected completed answer (${harvested.length} chars, reqId: $reqId). Delivering response early.',
          );
          BridgeTraceLog.instance.addEntry(
            type: 'checkpoint_check_success',
            source: BridgeSource.harvest.name,
            requestId: reqId,
            textLength: harvested.length,
            note: 'checkpoint_${checkpointNumber}_completed_early',
            level: BridgeTraceLevel.info,
          );
          _finishGeneration(null, isPartial: false);
          return;
        } else {
          RitmoLog.debug(
            'ChatGptWebBridge',
            'Checkpoint check #$checkpointNumber: response in progress (${harvested.length} chars, still generating)',
          );
          BridgeTraceLog.instance.addEntry(
            type: 'checkpoint_check_in_progress',
            source: BridgeSource.harvest.name,
            requestId: reqId,
            textLength: harvested.length,
            note: 'checkpoint_${checkpointNumber}_generating',
            level: BridgeTraceLevel.info,
          );
        }
      } else {
        RitmoLog.debug('ChatGptWebBridge', 'Checkpoint check #$checkpointNumber: no text found yet.');
        BridgeTraceLog.instance.addEntry(
          type: 'checkpoint_check_empty',
          source: BridgeSource.harvest.name,
          requestId: reqId,
          note: 'checkpoint_${checkpointNumber}_no_text',
          level: BridgeTraceLevel.info,
        );
      }
    } catch (e, st) {
      RitmoLog.warning('ChatGptWebBridge', 'Checkpoint check #$checkpointNumber error: $e', e, st);
    }
  }

  /// Resets the inactivity countdown.
  void _resetInactivityTimer() {
    _cancelResumeDebounce();
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
    _cancelResumeDebounce();
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
    _coldNavigationCount = 0;
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
  /// before releasing references, preventing Android `IllegalStateException: Could not find identifier for JavaScriptChannel`
  /// or WebChromeClient crashes in InstanceManager.
  Future<void> _safeDisposeController(WebViewController? controllerToDispose) async {
    if (controllerToDispose == null) return;
    try {
      // 0. Disable JavaScript message posting and defuse any queued callbacks in JS
      await controllerToDispose.runJavaScript('''
        window.__RITMO_DISPOSED__ = true;
        try {
          if (window.RitmoChatBridge) {
            window.RitmoChatBridge.postMessage = function() {};
          }
        } catch(_) {}
      ''');
    } catch (_) {}

    // DO NOT call removeJavaScriptChannel('RitmoChatBridge') here:
    // Calling removeJavaScriptChannel unregisters the channel from the Android InstanceManager immediately,
    // which causes a fatal crash (IllegalStateException: Could not find identifier for JavaScriptChannel)
    // if Chromium's IPC thread had already queued a postMessage callback in the Android Main Looper.
    // Instead, loading about:blank destroys the JS context safely, and GC reclaims native objects.

    try {
      // 1. Load blank page to abort in-flight resource loads and JS timers in native Chromium immediately
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

  /// Captures a full diagnostic report including DOM structure and full HTML (A-39/A-40).
  Future<String> captureDiagnosticSnapshot({bool includeFullHtml = true}) async {
    return ChatGptDomInspector.captureSnapshot(
      _controller,
      currentStatus: _status.name,
      lastError: _lastEmptyReasonDetail ?? (_lastRayId != null ? 'Cloudflare Ray ID: $_lastRayId' : null),
      includeFullHtml: includeFullHtml,
    );
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
