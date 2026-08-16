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

  /// Hard ceiling for a single generation.
  ///
  /// Without this nothing on the Dart side is able to end a stream: the JS
  /// watcher only reported completion when it had already seen some text, so a
  /// page that stayed silent (login wall, selector drift, rate limit) left the
  /// chat screen waiting on a stream that never closed.
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
  ///
  /// The web page is authoritative: every `chunk` and the final `done` carry the
  /// complete visible answer, and we only push the part the chat screen has not
  /// rendered yet. Reconciling here rather than in JS means a missed delta can
  /// still be recovered at the end instead of silently disappearing.
  String _emittedText = '';

  void _setStatus(ChatGptBridgeStatus newStatus) {
    _status = newStatus;
    _statusNotifier.value = newStatus;
    debugPrint('[ChatGptWebBridgeManager] Status changed to: $newStatus');
  }

  /// Ensures the WebView is booted and ready to receive prompts.
  Future<bool> ensureBooted() async {
    _resetInactivityTimer();

    if (_controller != null && _status == ChatGptBridgeStatus.ready) {
      return true;
    }

    if (_bootCompleter != null && !_bootCompleter!.isCompleted) {
      return _bootCompleter!.future;
    }

    final bootCompleter = Completer<bool>();
    _bootCompleter = bootCompleter;
    _setStatus(ChatGptBridgeStatus.booting);

    try {
      // webview_flutter 4.x exposes no WebViewController.dispose(); the platform
      // view is released by GC once nothing references it. Dropping the previous
      // reference BEFORE allocating a new one keeps failed boots from stacking
      // native WebViews, which is a fast route back to the OOM we already fought.
      _controller = null;

      final controller = WebViewController();
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
            debugPrint('[ChatGptWebBridge] Page loading started: $url');
          },
          onPageFinished: (url) async {
            debugPrint('[ChatGptWebBridge] Page loading finished: $url');
            await controller.runJavaScript(ChatGptJsInjector.setupBridgeScript);
          },
          onWebResourceError: (error) {
            debugPrint('[ChatGptWebBridge] Resource Error (${error.errorCode}): ${error.description}');
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
      debugPrint('[ChatGptWebBridge] Boot error: $e\n$st');
      _setStatus(ChatGptBridgeStatus.error);
      if (!bootCompleter.isCompleted) {
        bootCompleter.complete(false);
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

      // The injector spreads the payload into the envelope -- it posts
      // `{ type, ...payload }` -- so every field lives at the TOP level.
      // data['payload'] was therefore always absent and the nested reads below
      // were dead code kept alive only by their fallbacks. Top level wins now;
      // the nested lookup survives only for a stale script in a warm WebView.
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

      // Chunks arrive several times per second while streaming; logging each one
      // is the kind of log volume this app has been burned by before.
      if (type != 'chunk') {
        debugPrint('[ChatGptWebBridge] JS event received: type=$type');
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
            debugPrint('[ChatGptWebBridge] Cloudflare challenge detected.');
          }
          break;

        case 'cloudflare_resolved':
          if (_status == ChatGptBridgeStatus.cloudflareChallenge) {
            _setStatus(ChatGptBridgeStatus.ready);
            _cloudflareNotifier.value = false;
            debugPrint('[ChatGptWebBridge] Cloudflare challenge resolved.');
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
          debugPrint('[ChatGptWebBridge] Unhandled JS message: ${message.message}');
      }
    } catch (e) {
      debugPrint('[ChatGptWebBridge] Error parsing JS message: $e');
    }
  }

  static final _noisePrefixRegex = RegExp(
    r'^(\s*[\u2022\u2023\u25E6\u2043\u2219\*\-\.\:]\s*)*(:?\s*ChatGPT\s*said:?|:?\s*ChatGPT:?|:?\s*You\s*said:?|:?\s*Assistant\s*said:?)\s*',
    caseSensitive: false,
  );

  static final _cssBlockRegex = RegExp(
    r'(\[data-[^\]]+\]\s*\{[^}]*\}|--[a-zA-Z0-9_-]+:[^;]+;?)',
    multiLine: true,
  );

  static bool _isSystemPromptLeak(String text) {
    return text.contains('[RITMO SYSTEM DIRECTIVE]') ||
           text.contains('[USER QUERY]') ||
           text.contains('[دستورالعمل سیستم ریتمو]') ||
           text.contains('[درخواست جدید کاربر]') ||
           text.contains('[RITMO AUTONOMOUS AGENT TOOLS]') ||
           text.contains('[AVAILABLE RITMO AUTONOMOUS AGENT TOOLS]');
  }

  static String _sanitizeResponseText(String text) {
    if (_isSystemPromptLeak(text)) {
      debugPrint('[ChatGptWebBridge] Ignored leaked user prompt');
      return '';
    }
    var cleaned = text.replaceAll(_noisePrefixRegex, '').trimLeft();
    // Clean any dangling bullet dot or colon before real text
    cleaned = cleaned.replaceFirst(RegExp(r'^[\u2022\u2023\u25E6\u2043\u2219\*\-\.\:\s]+(?=[\u0600-\u06FF\w])'), '');
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
      // Emitted as an error so StreamingChatService treats it as a failure and
      // can fall back to the API slot. Without the prefix this warning was
      // stored in ChatRepository as if ChatGPT had actually said it.
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
    } catch (e) {
      debugPrint('[ChatGptWebBridge] Error fetching user_name: $e');
    }

    // A second send must never orphan the first stream: its listener would wait
    // forever and the incoming chunks would be routed to the wrong conversation.
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
      debugPrint('[ChatGptWebBridge] Generation timed out after ${generationTimeout.inSeconds}s.');
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
      // Never tear down a live generation. This used to close the stream
      // mid-answer, which ended the await-for with an empty string and no error
      // -- persisting a blank assistant message to the chat history.
      if (_status == ChatGptBridgeStatus.generating ||
          _currentStreamController != null) {
        _resetInactivityTimer();
        return;
      }
      debugPrint('[ChatGptWebBridge] Inactivity timeout reached. Releasing WebView reference.');
      disposeWebView();
    });
  }

  /// Drops this side's references to the WebView.
  ///
  /// NOTE: webview_flutter 4.x has no WebViewController.dispose(). The native
  /// WebView is only reclaimed by GC once no WebViewWidget references it either,
  /// so this is a hint, not a guaranteed free. Do not rely on it for memory.
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
    debugPrint('[ChatGptWebBridge] WebView reference released.');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      if (_status != ChatGptBridgeStatus.generating) {
        debugPrint('[ChatGptWebBridge] App paused/detached, releasing WebView.');
        disposeWebView();
      }
    }
  }
}
