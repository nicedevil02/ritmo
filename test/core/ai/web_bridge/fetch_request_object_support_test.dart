import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/ai/web_bridge/chatgpt_js_injector.dart';

void main() {
  group('DET-17: Request Object Support in Fetch Hook', () {
    test(
      'earlyHookScript and setupBridgeScript properly handle Request object arguments',
      () {
        final early = ChatGptJsInjector.earlyHookScript;
        final setup = ChatGptJsInjector.setupBridgeScript;

        // Both scripts must inspect typeof input and input.url / input.method
        expect(early.contains('var input = args[0];'), isTrue);
        expect(early.contains('url = input.url || \'\';'), isTrue);
        expect(
          early.contains(
            'method = (init && init.method) || input.method || \'GET\';',
          ),
          isTrue,
        );

        expect(setup.contains('var input = args[0];'), isTrue);
        expect(setup.contains('url = input.url || \'\';'), isTrue);
        expect(
          setup.contains(
            'method = (init && init.method) || input.method || \'GET\';',
          ),
          isTrue,
        );
      },
    );

    test(
      'Simulated JavaScript argument extraction correctly resolves Request object',
      () {
        Map<String, String> extractUrlAndMethod(dynamic input, [dynamic init]) {
          String url = '';
          String method = 'GET';

          if (input is String) {
            url = input;
            if (init is Map && init['method'] != null) {
              method = init['method'].toString();
            }
          } else if (input is Map) {
            url = input['url']?.toString() ?? '';
            if (init is Map && init['method'] != null) {
              method = init['method'].toString();
            } else if (input['method'] != null) {
              method = input['method'].toString();
            }
          }

          return {'url': url, 'method': method};
        }

        // Case 1: Simple string URL + init dict
        final res1 = extractUrlAndMethod('/backend-api/conversation', {
          'method': 'POST',
        });
        expect(res1['url'], equals('/backend-api/conversation'));
        expect(res1['method'], equals('POST'));

        // Case 2: Request object with URL and method
        final reqObject = {
          'url': 'https://chatgpt.com/backend-api/conversation',
          'method': 'POST',
        };
        final res2 = extractUrlAndMethod(reqObject);
        expect(
          res2['url'],
          equals('https://chatgpt.com/backend-api/conversation'),
        );
        expect(res2['method'], equals('POST'));

        // Case 3: Request object with overridden init
        final res3 = extractUrlAndMethod(reqObject, {'method': 'PUT'});
        expect(
          res3['url'],
          equals('https://chatgpt.com/backend-api/conversation'),
        );
        expect(res3['method'], equals('PUT'));
      },
    );
  });
}
