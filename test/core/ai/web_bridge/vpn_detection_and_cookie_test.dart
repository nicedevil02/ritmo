import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/ai/web_bridge/chatgpt_js_injector.dart';
import 'package:ritmo/core/ai/web_bridge/chatgpt_web_bridge_manager.dart';
import 'package:ritmo/core/ai/web_bridge/web_bridge_event.dart';
import 'package:ritmo/core/ai/web_bridge/web_bridge_exception.dart';
import 'package:webview_flutter/webview_flutter.dart';

class MockVpnTestWebViewController extends Fake implements WebViewController {
  bool channelRemoved = false;
  bool blankPageLoaded = false;

  @override
  Future<void> removeJavaScriptChannel(String javaScriptChannelName) async {
    if (javaScriptChannelName == 'RitmoChatBridge') {
      channelRemoved = true;
    }
  }

  @override
  Future<void> loadRequest(
    Uri uri, {
    LoadRequestMethod method = LoadRequestMethod.get,
    Map<String, String> headers = const <String, String>{},
    dynamic body,
  }) async {
    if (uri.toString() == 'about:blank') {
      blankPageLoaded = true;
    }
  }

  @override
  Future<void> setJavaScriptMode(JavaScriptMode javaScriptMode) async {}

  @override
  Future<void> setUserAgent(String? userAgent) async {}

  @override
  Future<void> setNavigationDelegate(NavigationDelegate delegate) async {}

  @override
  Future<void> addJavaScriptChannel(
    String javaScriptChannelName, {
    required void Function(JavaScriptMessage) onMessageReceived,
  }) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VPN Required & Geo-blocking Detection Tests', () {
    late ChatGptWebBridgeManager manager;
    late MockVpnTestWebViewController mockController;

    setUp(() {
      manager = ChatGptWebBridgeManager.instance;
      manager.resetStateForTest();
      mockController = MockVpnTestWebViewController();
      ChatGptWebBridgeManager.testControllerFactory = () => mockController;
    });

    tearDown(() {
      ChatGptWebBridgeManager.testControllerFactory = null;
    });

    test('WebBridgeEvent parses vpn_required payload correctly with Ray ID and IP', () {
      const jsonStr = '''
      {
        "type": "vpn_required",
        "source": "lifecycle",
        "reason": "unable_to_load_site",
        "rayId": "a2da88954ab84803",
        "ip": "2a03:ef43:5:f618:2c88:6dff:fe00:5f9f"
      }
      ''';

      final event = WebBridgeEvent.parse(jsonStr);
      expect(event, isA<BridgeVpnRequiredEvent>());
      final vpnEvent = event as BridgeVpnRequiredEvent;
      expect(vpnEvent.reason, equals('unable_to_load_site'));
      expect(vpnEvent.rayId, equals('a2da88954ab84803'));
      expect(vpnEvent.ip, equals('2a03:ef43:5:f618:2c88:6dff:fe00:5f9f'));
      expect(vpnEvent.source, equals('lifecycle'));
    });

    test('WebBridgeErrorKind.vpnRequired produces helpful Persian action message', () {
      final exc = WebBridgeException.vpnRequired(
        rayId: 'a2da88954ab84803',
        ip: '2a03:ef43:5:f618:2c88:6dff:fe00:5f9f',
      );

      expect(exc.kind, equals(WebBridgeErrorKind.vpnRequired));
      expect(exc.messageFa, contains('مسدود است'));
      expect(exc.messageFa, contains('فیلترشکن'));
      expect(exc.messageFa, contains('Ray ID: a2da88954ab84803'));
      expect(exc.actionTextFa, equals('فعال‌سازی فیلترشکن / تحریم‌شکن'));
    });

    test('Manager transitions to vpnRequired on vpn_required JS event', () {
      expect(manager.status, equals(ChatGptBridgeStatus.idle));
      expect(manager.vpnRequiredNotifier.value, isFalse);

      manager.handleJsMessageForTest(
        JavaScriptMessage(
          message: jsonEncode({
            'type': 'vpn_required',
            'source': 'lifecycle',
            'reason': 'unable_to_load_site',
            'rayId': 'cf-ray-987654',
            'ip': '5.200.10.20',
          }),
        ),
      );

      expect(manager.status, equals(ChatGptBridgeStatus.vpnRequired));
      expect(manager.vpnRequiredNotifier.value, isTrue);
      expect(manager.lastRayId, equals('cf-ray-987654'));
      expect(manager.lastBlockedIp, equals('5.200.10.20'));

      final reason = manager.describeEmptyResponseReason();
      expect(reason.messageFa, contains('فیلترشکن یا تحریم‌شکن'));
      expect(reason.technicalDetail, contains('vpnRequired'));
    });

    test('forceReboot clears vpnRequired state', () async {
      manager.setStatusForTest(ChatGptBridgeStatus.vpnRequired);
      expect(manager.vpnRequiredNotifier.value, isTrue);

      // Trigger forceReboot
      final _ = manager.forceReboot(reasonFa: 'تست بازنشانی');

      expect(manager.vpnRequiredNotifier.value, isFalse);
      expect(manager.lastRayId, isNull);
      expect(manager.lastBlockedIp, isNull);
    });
  });

  group('JS Injector Script Verification for VPN & Cookie Auto-Consent', () {
    test('setupBridgeScript contains checkVpnAndGeoBlockStatus and security blocker', () {
      final script = ChatGptJsInjector.setupBridgeScript;
      expect(script, contains('checkVpnAndGeoBlockStatus'));
      expect(script, contains('unable to load site'));
      expect(script, contains('if you are using a vpn'));
      expect(script, contains('not available in your country'));
      expect(script, contains('checkSecurityAndBlockStatus'));
      expect(script, contains('VPN/Geo-block detected at boot; withholding ready.'));
    });

    test('setupBridgeScript and earlyHookScript contain auto cookie dismissal and OneTrust API', () {
      final setupScript = ChatGptJsInjector.setupBridgeScript;
      final earlyScript = ChatGptJsInjector.earlyHookScript;

      expect(setupScript, contains('OneTrust.AllowAll'));
      expect(setupScript, contains('__ritmo_cookie_suppress_css'));
      expect(setupScript, contains('onetrust-banner-sdk'));
      expect(setupScript, contains('accept-cookies'));

      expect(earlyScript, contains('__ritmo_cookie_suppress_css'));
      expect(earlyScript, contains('OnetrustActiveGroups'));
    });
  });
}
