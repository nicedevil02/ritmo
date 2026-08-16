import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:ritmo/core/ai/web_bridge/chatgpt_js_injector.dart';
import 'package:ritmo/core/database/database_helper.dart';
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

  WebViewController? _controller;
  WebViewController? get controller => _controller;

  ChatGptBridgeStatus _status = ChatGptBridgeStatus.idle;
  ChatGptBridgeStatus get status => _status;

  final ValueNotifier<bool> _cloudflareNotifier = ValueNotifier<bool>(false);
  ValueListenable<bool> get cloudflareNotifier => _cloudflareNotifier;

  final ValueNotifier<ChatGptBridgeStatus> _statusNotifier = ValueNotifier<ChatGptBridgeStatus>(ChatGptBridgeStatus.idle);
  ValueListenable<ChatGptBridgeStatus> get statusNotifier => _statusNotifier;

  Timer? _inactivityTimer;
  StreamController<String>? _currentStreamController;
  Completer<bool>? _bootCompleter;

  void _setStatus(ChatGptBridgeStatus newStatus) {
    _status = newStatus;
    _statusNotifier.value = newStatus;
    debugPrint('[ChatGptWebBridgeManager] Status changed to: $newStatus');
  }

  /// Ensures the WebView is booted and ready to receive prompts.
  /// If it was disposed due to 5-minute inactivity, re-boots lazily.
  Future<bool> ensureBooted() async {
    _resetInactivityTimer();

    if (_controller != null && _status == ChatGptBridgeStatus.ready) {
      return true;
    }

    if (_bootCompleter != null && !_bootCompleter!.isCompleted) {
      return _bootCompleter!.future;
    }

    _bootCompleter = Completer<bool>();
    _setStatus(ChatGptBridgeStatus.booting);

    try {
      final controller = WebViewController();
      _controller = controller;

      await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      await controller.setUserAgent(
        'Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Mobile Safari/537.36',
      );

      // JavaScript Channel for two-way communication
      await controller.addJavaScriptChannel(
        'RitmoChatBridge',
        onMessageReceived: _handleJsMessage,
      );

      await controller.setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            debugPrint('[ChatGptWebBridge] Page loading started: $url');
          },
          onPageFinished: (url) async {
            debugPrint('[ChatGptWebBridge] Page loading finished: $url');
            // Inject bridge watcher and listeners
            await controller.runJavaScript(ChatGptJsInjector.setupBridgeScript);
          },
          onWebResourceError: (error) {
            debugPrint('[ChatGptWebBridge] Resource Error (${error.errorCode}): ${error.description}');
          },
        ),
      );

      await controller.loadRequest(Uri.parse(targetUrl));

      // Wait up to 20 seconds for page & bridge readiness
      final isReady = await _waitForReady(timeout: const Duration(seconds: 20));
      if (!_bootCompleter!.isCompleted) {
        _bootCompleter!.complete(isReady);
      }
      return isReady;
    } catch (e, st) {
      debugPrint('[ChatGptWebBridge] Boot error: $e\n$st');
      _setStatus(ChatGptBridgeStatus.error);
      if (!_bootCompleter!.isCompleted) {
        _bootCompleter!.complete(false);
      }
      return false;
    }
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
      final payload = (data['payload'] is Map<String, dynamic>)
          ? data['payload'] as Map<String, dynamic>
          : <String, dynamic>{};

      debugPrint('[ChatGptWebBridge] JS event received: type=$type, payload=$payload');

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
            debugPrint('[ChatGptWebBridge] ⚠️ Cloudflare Challenge Detected!');
          }
          break;

        case 'cloudflare_resolved':
          if (_status == ChatGptBridgeStatus.cloudflareChallenge) {
            _setStatus(ChatGptBridgeStatus.ready);
            _cloudflareNotifier.value = false;
            debugPrint('[ChatGptWebBridge] ✅ Cloudflare Challenge Resolved!');
          }
          break;

        case 'chunk':
          final delta = payload['delta'] as String? ?? data['delta'] as String? ?? '';
          if (delta.isNotEmpty) {
            _currentStreamController?.add(delta);
          }
          _resetInactivityTimer();
          break;

        case 'done':
          _setStatus(ChatGptBridgeStatus.ready);
          _currentStreamController?.close();
          _currentStreamController = null;
          _resetInactivityTimer();
          break;

        case 'error':
          final msg = payload['message'] as String? ?? data['message'] as String? ?? 'Unknown error';
          _setStatus(ChatGptBridgeStatus.ready);
          _currentStreamController?.addError(Exception(msg));
          _currentStreamController?.close();
          _currentStreamController = null;
          _resetInactivityTimer();
          break;

        default:
          debugPrint('[ChatGptWebBridge] Unhandled JS message: ${message.message}');
      }
    } catch (e) {
      debugPrint('[ChatGptWebBridge] Error parsing JS message: $e');
    }
  }

  /// Sends a prompt and streams the assistant response tokens back.
  Stream<String> sendPrompt({
    required String prompt,
    String? personaTitle,
    String? personaSystemPrompt,
  }) async* {
    _resetInactivityTimer();

    final booted = await ensureBooted();
    if (!booted && _status == ChatGptBridgeStatus.cloudflareChallenge) {
      yield '⚠️ برای ادامه گفتگو، لطفاً تایید امنیتی کلودفلر را در پنجره باز شده تایید نمایید...';
      return;
    }

    if (!booted || _controller == null) {
      yield 'error:عدم دسترسی به وب‌سایت ChatGPT. لطفاً اتصال اینترنت خود را بررسی کنید.';
      return;
    }

    // Retrieve user name from database if available
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
    } catch (e) {
      debugPrint('[ChatGptWebBridge] Error fetching user_name: $e');
    }

    _setStatus(ChatGptBridgeStatus.generating);

    final streamController = StreamController<String>();
    _currentStreamController = streamController;

    final formattedPrompt = ChatGptJsInjector.formatPromptWithSystemDirective(
      userPrompt: prompt,
      personaTitle: personaTitle,
      personaSystemPrompt: personaSystemPrompt,
      userName: userName,
    );

    final jsCall = ChatGptJsInjector.buildSendPromptScript(formattedPrompt);
    await _controller!.runJavaScript(jsCall);

    yield* streamController.stream;
  }

  /// Resets the 5-minute inactivity countdown.
  /// After 5 minutes without any messages, the WebView is completely disposed to free RAM.
  void _resetInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(inactivityTimeout, () {
      debugPrint('[ChatGptWebBridge] Inactivity timeout (5 min) reached. Disposing WebView to save RAM.');
      disposeWebView();
    });
  }

  /// Completely closes and disposes the WebViewController to reclaim memory.
  void disposeWebView() {
    _inactivityTimer?.cancel();
    _inactivityTimer = null;
    _currentStreamController?.close();
    _currentStreamController = null;
    _bootCompleter = null;
    _controller = null;
    _cloudflareNotifier.value = false;
    _setStatus(ChatGptBridgeStatus.idle);
    debugPrint('[ChatGptWebBridge] Headless WebView disposed.');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      // In background, dispose immediately to prevent OS killing the app for memory consumption
      if (_status != ChatGptBridgeStatus.generating) {
        debugPrint('[ChatGptWebBridge] App paused/detached, freeing WebView.');
        disposeWebView();
      }
    }
  }
}
