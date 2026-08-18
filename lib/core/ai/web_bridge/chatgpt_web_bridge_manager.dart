import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:ritmo/core/ai/web_bridge/chatgpt_js_injector.dart';
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

class ChatGptWebBridgeManager with WidgetsBindingObserver {
  static final ChatGptWebBridgeManager _instance = ChatGptWebBridgeManager._internal();
  static ChatGptWebBridgeManager get instance => _instance;

  ChatGptWebBridgeManager._internal() {
    WidgetsBinding.instance.addObserver(this);
  }

  static const String targetUrl = 'https://chatgpt.com/';
  static const Duration inactivityTimeout = Duration(minutes: 5);

  /// Hard ceiling for a single generation.
  static const Duration generationTimeout = Duration(seconds: 120);

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

  /// Text already forwarded downstream for the CURRENT generation.
  String _emittedText = '';

  @visibleForTesting
  static WebViewController Function()? testControllerFactory;

  @visibleForTesting
  static int controllerCreationCount = 0;

  @visibleForTesting
  void setTestState({
    ChatGptBridgeStatus? status,
    WebViewController? controller,
    Completer<bool>? bootCompleter,
  }) {
    if (status != null) _setStatus(status);
    if (controller != null) _controller = controller;
    if (bootCompleter != null) _bootCompleter = bootCompleter;
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
      _controller = null;
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
            RitmoLog.debug('ChatGptWebBridge', 'Page loading started: $url');
          },
          onPageFinished: (url) async {
            RitmoLog.debug('ChatGptWebBridge', 'Page loading finished: $url');
            await controller.runJavaScript(ChatGptJsInjector.setupBridgeScript);
          },
          onWebResourceError: (error) {
            RitmoLog.error('ChatGptWebBridge', 'Resource Error (${error.errorCode}): ${error.description}');
          },
        ),
      );

      await controller.loadRequest(Uri.parse(targetUrl));

      final isReady = await _waitForReady(timeout: const Duration(seconds: 20));
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
    _emittedText = '';
    if (controller != null && !controller.isClosed) {
      controller.addError(Exception(reasonFa));
      await controller.close();
    }

    _bootCompleter = null;
    _controller = null;
    _cloudflareNotifier.value = false;
    _setStatus(ChatGptBridgeStatus.idle);

    return ensureBooted();
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

  void _handleJsMessage(JavaScriptMessage message) {
    try {
      final data = jsonDecode(message.message) as Map<String, dynamic>;
      final type = data['type'] as String?;

      final nested = (data['payload'] is Map<String, dynamic>)
          ? data['payload'] as Map<String, dynamic>
          : const <String, dynamic>{};
      String? readString(String key) {
        final top = data[key];
        if (top is String) return top;
        final inner = nested[key];
        if (inner is String) return inner;
        return null;
      }

      if (type != 'chunk') {
        RitmoLog.debug('ChatGptWebBridge', 'JS event received: type=$type');
      }

      switch (type) {
        case 'ready':
          if (_status != ChatGptBridgeStatus.ready) {
            _setStatus(ChatGptBridgeStatus.ready);
          }
          if (_cloudflareNotifier.value) {
            _cloudflareNotifier.value = false;
          }
          break;

        case 'cloudflare_challenge':
          if (_status != ChatGptBridgeStatus.cloudflareChallenge) {
            _setStatus(ChatGptBridgeStatus.cloudflareChallenge);
            _cloudflareNotifier.value = true;
            RitmoLog.debug('ChatGptWebBridge', 'Cloudflare challenge detected.');
          }
          break;

        case 'cloudflare_resolved':
          if (_status == ChatGptBridgeStatus.cloudflareChallenge) {
            _setStatus(ChatGptBridgeStatus.ready);
            _cloudflareNotifier.value = false;
            RitmoLog.debug('ChatGptWebBridge', 'Cloudflare challenge resolved.');
          }
          break;

        case 'chunk':
          final full = readString('fullText');
          final delta = readString('delta');
          _emitChunk(full, delta);
          _resetInactivityTimer();
          break;

        case 'done':
          _finishGeneration(readString('fullText'));
          break;

        case 'error':
          _failGeneration(readString('message') ?? 'Unknown error');
          break;

        default:
          RitmoLog.debug('ChatGptWebBridge', 'Unhandled JS message: ${message.message}');
      }
    } catch (e, st) {
      RitmoLog.error('ChatGptWebBridge', 'Error parsing JS message: $e', e, st);
    }
  }

  static final _noisePrefixRegex = RegExp(
    r'^[•\-\*\s:]*(ChatGPT\s*said:?|:ChatGPT\s*said:?|ChatGPT:?|You\s*said:?|:You\s*said:?|Assistant\s*said:?)[\s:]*',
    caseSensitive: false,
    multiLine: true,
  );

  static final _cssBlockRegex = RegExp(
    r'(\[data-[^\]]+\]\s*\{[^}]*\}|--[a-zA-Z0-9_-]+:[^;]+;?)',
    multiLine: true,
  );

  static String _sanitizeResponseText(String text) {
    var cleaned = text;
    while (true) {
      final before = cleaned;
      cleaned = cleaned.replaceFirst(_noisePrefixRegex, '').trimLeft();
      cleaned = cleaned.replaceFirst(RegExp(r'^[•\-\*:\s]+'), '').trimLeft();
      if (cleaned == before) break;
    }
    if (cleaned.contains('[data-conversation-') || cleaned.contains('--component-')) {
      cleaned = cleaned.replaceAll(_cssBlockRegex, '').trim();
    }
    return cleaned;
  }

  void _emitChunk(String? full, String? delta) {
    final controller = _currentStreamController;
    if (controller == null || controller.isClosed) return;

    if (full != null && full.isNotEmpty) {
      final cleanFull = _sanitizeResponseText(full);
      if (cleanFull != _emittedText) {
        if (cleanFull.length > _emittedText.length) {
          final d = cleanFull.substring(_emittedText.length);
          _emittedText = cleanFull;
          controller.add(d);
        } else if (_emittedText.isEmpty) {
          _emittedText = cleanFull;
          controller.add(cleanFull);
        }
      }
      return;
    }

    if (delta != null && delta.isNotEmpty) {
      final cleanDelta = _emittedText.isEmpty ? _sanitizeResponseText(delta) : delta;
      if (cleanDelta.isNotEmpty) {
        _emittedText += cleanDelta;
        controller.add(cleanDelta);
      }
    }
  }

  /// Flushes whatever the page ended up showing, then closes the stream.
  void _finishGeneration(String? fullText) {
    _generationTimer?.cancel();
    _generationTimer = null;

    final controller = _currentStreamController;

    if (fullText != null && fullText.isNotEmpty && controller != null && !controller.isClosed) {
      final cleanFull = _sanitizeResponseText(fullText);
      if (_emittedText.isEmpty) {
        _emittedText = cleanFull;
        controller.add(cleanFull);
      } else if (cleanFull.length > _emittedText.length) {
        final remaining = cleanFull.substring(_emittedText.length);
        _emittedText = cleanFull;
        controller.add(remaining);
      }
    }

    _setStatus(ChatGptBridgeStatus.ready);
    _currentStreamController = null;
    _emittedText = '';
    controller?.close();
    _resetInactivityTimer();
  }

  void _failGeneration(String messageFa) {
    _generationTimer?.cancel();
    _generationTimer = null;

    final controller = _currentStreamController;
    _currentStreamController = null;
    _emittedText = '';

    _setStatus(ChatGptBridgeStatus.ready);
    if (controller != null && !controller.isClosed) {
      controller.addError(Exception(messageFa));
      controller.close();
    }
    _resetInactivityTimer();
  }

  /// Cancels the current stream if active
  void cancelCurrentStream() {
    _generationTimer?.cancel();
    _generationTimer = null;
    final controller = _currentStreamController;
    _currentStreamController = null;
    _emittedText = '';
    _setStatus(ChatGptBridgeStatus.ready);
    controller?.close();
    _resetInactivityTimer();
  }

  /// Sends a prompt and streams the assistant response back.
  Stream<String> sendPrompt({
    required String prompt,
    String? personaTitle,
    String? personaSystemPrompt,
    String? contextSummary,
    List<String>? recentHistory,
  }) async* {
    _resetInactivityTimer();

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

    final streamController = StreamController<String>();
    _currentStreamController = streamController;
    _emittedText = '';

    final formattedPrompt = ChatGptJsInjector.formatPromptWithSystemDirective(
      userPrompt: prompt,
      personaTitle: personaTitle,
      personaSystemPrompt: personaSystemPrompt,
      userName: userName,
      contextSummary: contextSummary,
      recentHistory: recentHistory,
    );

    final jsCall = ChatGptJsInjector.buildSendPromptScript(formattedPrompt);
    await _controller!.runJavaScript(jsCall);

    _generationTimer?.cancel();
    _generationTimer = Timer(generationTimeout, () {
      if (!identical(_currentStreamController, streamController)) return;
      RitmoLog.debug('ChatGptWebBridge', 'Generation timed out after ${generationTimeout.inSeconds}s.');
      if (_emittedText.isEmpty) {
        _failGeneration('پاسخی از صفحهٔ ChatGPT دریافت نشد. لطفاً پنجرهٔ مرورگر را باز کنید و وضعیت ورود یا تایید امنیتی را بررسی کنید.');
      } else {
        _finishGeneration(null);
      }
    });

    yield* streamController.stream;
  }

  /// Resets the inactivity countdown.
  void _resetInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(inactivityTimeout, () {
      if (_status == ChatGptBridgeStatus.generating ||
          _currentStreamController != null) {
        _resetInactivityTimer();
        return;
      }
      RitmoLog.debug('ChatGptWebBridge', 'Inactivity timeout reached. Releasing WebView reference.');
      disposeWebView();
    });
  }

  /// Drops this side's references to the WebView.
  void disposeWebView() {
    _inactivityTimer?.cancel();
    _inactivityTimer = null;
    _generationTimer?.cancel();
    _generationTimer = null;

    final controller = _currentStreamController;
    _currentStreamController = null;
    _emittedText = '';
    controller?.close();

    _bootCompleter = null;
    _controller = null;
    _cloudflareNotifier.value = false;
    _setStatus(ChatGptBridgeStatus.idle);
    RitmoLog.debug('ChatGptWebBridge', 'WebView reference released.');
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
