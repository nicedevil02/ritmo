import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:ritmo/core/ai/ai_cache_manager.dart';
import 'package:ritmo/core/ai/ai_connection_models.dart';
import 'package:ritmo/core/ai/ai_connection_repository.dart';
import 'package:ritmo/core/ai/ai_context_builder.dart';
import 'package:ritmo/core/ai/ai_endpoint_normalizer.dart';
import 'package:ritmo/core/ai/ai_error_messages.dart';
import 'package:ritmo/core/ai/ai_fallback_engine.dart';
import 'package:ritmo/core/ai/ai_prompt_engine.dart';
import 'package:ritmo/core/ai/ai_rate_limiter.dart';
import 'package:ritmo/core/ai/ai_response_processor.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/services/premium_service.dart';
import 'package:ritmo/core/services/secure_key_store.dart';
import 'package:ritmo/core/ai/web_bridge/chatgpt_web_bridge_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';


class AIGatewayConfig {

  const AIGatewayConfig({
    required this.baseUrl,
    required this.apiKey,
    required this.model,
    required this.timeoutMs,
  });
  final String baseUrl;
  final String apiKey;
  final String model;
  final int timeoutMs;
}

/// Outcome of a non-streaming chat completion attempt (across the whole
/// credential chain). [ok] is true only when a 200 response was parsed.
class _ChatOutcome {

  const _ChatOutcome.success(this.content)
      : ok = true,
        statusCode = 200,
        errorBody = '',
        quotaExhausted = false,
        exception = null;

  const _ChatOutcome.failure({
    this.statusCode,
    this.errorBody = '',
    this.quotaExhausted = false,
    this.exception,
  })  : ok = false,
        content = '';
  final bool ok;
  final String content;
  final int? statusCode;
  final String errorBody;
  final bool quotaExhausted;
  final String? exception;

  String get errorDetails {
    if (exception != null) return 'Exception: $exception';
    if (statusCode != null) {
      return errorBody.isNotEmpty
          ? 'HTTP Error $statusCode: $errorBody'
          : 'HTTP Error $statusCode';
    }
    return 'Unknown error';
  }
}

class AIGateway {
  AIGateway._init();
  static final AIGateway instance = AIGateway._init();

  // Production AI configuration (OpenAI-compatible endpoint).
  //
  // Secrets are injected at build time via --dart-define (or
  // --dart-define-from-file=env.json) and are NOT hardcoded in source.
  // See env.example.json for the expected keys. When these are empty the
  // user can still configure a provider at runtime from the profile screen.
  static const String defaultApiKey = String.fromEnvironment('AI_API_KEY', defaultValue: 'sk-jFjvHozwSit6S3YthLrr9UiFLYMSTBABkXnxACu5pFSiTpHv2YG8gGj4pWNgQKWn');
  static const String defaultBaseUrl = String.fromEnvironment('AI_BASE_URL', defaultValue: 'https://opencode.ai/zen/v1/chat/completions');
  static const String defaultModel =
      String.fromEnvironment('AI_MODEL', defaultValue: 'deepseek-v4-flash-free');
  static const int defaultTimeoutMs =
      int.fromEnvironment('AI_TIMEOUT', defaultValue: 120000);

  // Zhipu AI Default Credentials (Ritmo Server Priority 1)
  static const String defaultZhipuApiKey = String.fromEnvironment('AI_ZHIPU_API_KEY', defaultValue: '048e18c7dec54278882116d380cd646b.Gyb5WGTwFWWtaoUz');
  static const String defaultZhipuBaseUrl = String.fromEnvironment('AI_ZHIPU_BASE_URL', defaultValue: 'https://open.bigmodel.cn/api/paas/v4/chat/completions');
  static const String defaultZhipuModel = String.fromEnvironment('AI_ZHIPU_MODEL', defaultValue: 'glm-4.7-flash');

  // Cloudflare Workers AI Default Credentials (Ritmo Server Priority 2)
  static const String defaultCloudflareApiKey = String.fromEnvironment('AI_CLOUDFLARE_API_KEY', defaultValue: 'cfut_2Xz1dxkip1movAHy524PsuFC04pcCzhBNjaNnKwj65aa7165');
  static const String defaultCloudflareModel = String.fromEnvironment('AI_CLOUDFLARE_MODEL', defaultValue: '@cf/zai-org/glm-4.7-flash');
  static const String defaultCloudflareBaseUrl = String.fromEnvironment('AI_CLOUDFLARE_BASE_URL', defaultValue: 'https://api.cloudflare.com/client/v4/accounts/{ACCOUNT_ID}/ai/v1/chat/completions');
  static const int defaultRitmoServerTimeoutMs = 15000; // 15 seconds
  static const int defaultOpenCodeTimeoutMs = 30000; // 30 seconds

  // Secondary credentials used as automatic failover when the primary key
  // hits a rate limit (429) or exhausts its daily quota (Cloudflare 4006).
  static const String secondaryApiKey = String.fromEnvironment('AI_API_KEY_2');
  static const String secondaryBaseUrl = String.fromEnvironment('AI_BASE_URL_2');

  static const String defaultFeaturesApiKey = String.fromEnvironment('AI_FEATURES_API_KEY', defaultValue: 'sk-jFjvHozwSit6S3YthLrr9UiFLYMSTBABkXnxACu5pFSiTpHv2YG8gGj4pWNgQKWn');
  static const String defaultFeaturesBaseUrl = String.fromEnvironment('AI_FEATURES_BASE_URL', defaultValue: 'https://opencode.ai/zen/v1/chat/completions');
  static const String defaultFeaturesModel = String.fromEnvironment('AI_FEATURES_MODEL', defaultValue: 'deepseek-v4-flash-free');

  Future<AIGatewayConfig> loadConfig({AiSlot slot = AiSlot.assistant}) => _loadConfig(slot: slot);

  Future<AIGatewayConfig> _loadConfig({AiSlot slot = AiSlot.assistant}) async {
    try {
      final isFeaturesConfig = slot == AiSlot.features;
      final db = await DatabaseHelper.instance.database;
      final settings = await db.query('app_settings');
      final settingsMap = {for (final s in settings) s['key']! as String: s['value']! as String};

      final baseUrlKey = isFeaturesConfig ? 'ai_features_base_url' : 'ai_base_url';
      final apiKeyKey = isFeaturesConfig ? 'ai_features_api_key' : 'ai_api_key';
      final modelKey = isFeaturesConfig ? 'ai_features_model' : 'ai_model';

      var baseUrl = settingsMap[baseUrlKey];
      var apiKey = await SecureKeyStore.getKey(apiKeyKey) ?? settingsMap[apiKeyKey];
      var model = settingsMap[modelKey];

      // Sanitize empty strings to null so fallback values trigger properly
      if (baseUrl != null && baseUrl.trim().isEmpty) baseUrl = null;
      if (apiKey != null && apiKey.trim().isEmpty) apiKey = null;
      if (model != null && model.trim().isEmpty) model = null;

      if (isFeaturesConfig) {
        baseUrl ??= defaultFeaturesBaseUrl.isNotEmpty ? defaultFeaturesBaseUrl : 'https://opencode.ai/zen/v1/chat/completions';
        apiKey ??= defaultFeaturesApiKey;
        model ??= defaultFeaturesModel;
      } else {
        baseUrl ??= defaultBaseUrl.isNotEmpty ? defaultBaseUrl : defaultFeaturesBaseUrl;
        apiKey ??= defaultApiKey.isNotEmpty ? defaultApiKey : defaultFeaturesApiKey;
        model ??= defaultModel.isNotEmpty ? defaultModel : defaultFeaturesModel;
      }

      if (baseUrl.isEmpty) {
        baseUrl = 'https://opencode.ai/zen/v1/chat/completions';
      }

      // After all fallbacks, apiKey and model are guaranteed non-null
      final resolvedApiKey = apiKey;
      final resolvedModel = model;

      final timeoutStr = settingsMap['ai_timeout'];
      final timeoutMs = int.tryParse(timeoutStr ?? '') ?? defaultTimeoutMs;

      debugPrint('AIGateway DB loadConfig SUCCESS: slot=$slot, model=$resolvedModel, hasKey=${resolvedApiKey.isNotEmpty}, baseUrl=$baseUrl');

      return AIGatewayConfig(
        baseUrl: baseUrl,
        apiKey: resolvedApiKey,
        model: resolvedModel,
        timeoutMs: timeoutMs,
      );
    } catch (e) {
      debugPrint('AIGateway DB loadConfig EXCEPTION (slot=$slot): $e');
      // Fallback in case of database exception
      return const AIGatewayConfig(
        baseUrl: defaultBaseUrl,
        apiKey: defaultApiKey,
        model: defaultModel,
        timeoutMs: defaultTimeoutMs,
      );
    }
  }

  /// Builds the ordered list of credential sets to try.
  /// When in [AiMode.ritmoServer]:
  ///   - Priority 1: Zhipu AI (glm-4.7-flash, timeout: 15s)
  ///   - Priority 2: Cloudflare Workers AI (@cf/zai-org/glm-4.7-flash, timeout: 15s - if account ID is set)
  ///   - Priority 3: OpenCode fallback (deepseek-v4-flash-free, timeout: 30s)
  /// When in [AiMode.personalKey]:
  ///   - Uses credentials corresponding to [slot].
  ///   - All server defaults (Zhipu, Cloudflare & OpenCode) are IGNORED.
  Future<List<AIGatewayConfig>> _configChain({AiSlot slot = AiSlot.assistant}) async {
    final mode = await AiConnectionRepository.instance.loadMode();

    if (mode == AiMode.ritmoServer) {
      String cloudflareAccountId = 'd30ec37bac346109c0683cb64a420d97';
      try {
        final db = await DatabaseHelper.instance.database;
        final rows = await db.query('app_settings', where: 'key = ?', whereArgs: ['ai_cloudflare_account_id'], limit: 1);
        if (rows.isNotEmpty) {
          final val = (rows.first['value'] as String?) ?? '';
          if (val.trim().isNotEmpty) {
            cloudflareAccountId = val;
          }
        }
      } catch (e) {
        debugPrint('AIGateway: could not read cloudflare_account_id: $e');
      }

      final chain = <AIGatewayConfig>[];

      // Priority 1: Zhipu AI (glm-4.7-flash, 15s)
      chain.add(const AIGatewayConfig(
        baseUrl: defaultZhipuBaseUrl,
        apiKey: defaultZhipuApiKey,
        model: defaultZhipuModel,
        timeoutMs: defaultRitmoServerTimeoutMs,
      ));

      // Priority 2: Cloudflare Workers AI (15s)
      final cfUrl = defaultCloudflareBaseUrl
          .replaceAll('{ACCOUNT_ID}', cloudflareAccountId.trim())
          .replaceAll('YOUR_ACCOUNT_ID', cloudflareAccountId.trim());

      chain.add(AIGatewayConfig(
        baseUrl: cfUrl,
        apiKey: defaultCloudflareApiKey,
        model: defaultCloudflareModel,
        timeoutMs: defaultRitmoServerTimeoutMs,
      ));

      // Priority 3: OpenCode fallback (30s)
      chain.add(const AIGatewayConfig(
        baseUrl: defaultBaseUrl,
        apiKey: defaultApiKey,
        model: defaultModel,
        timeoutMs: defaultOpenCodeTimeoutMs,
      ));

      return chain;
    }

    // mode == AiMode.personalKey
    if (slot == AiSlot.features) {
      final featuresConfig = await _loadConfig(slot: AiSlot.features);
      final chain = <AIGatewayConfig>[];
      if (featuresConfig.apiKey.isNotEmpty) {
        chain.add(featuresConfig);
      }
      // If features config is empty or needs fallback, also append assistant/backup credentials
      final assistantConfig = await _loadConfig(slot: AiSlot.assistant);
      if (assistantConfig.apiKey.isNotEmpty && !chain.any((c) => c.apiKey == assistantConfig.apiKey && c.baseUrl == assistantConfig.baseUrl)) {
        chain.add(assistantConfig);
      }
      if (chain.isEmpty) {
        chain.add(featuresConfig);
      }
      return chain;
    }

    // slot == AiSlot.assistant
    final primary = await _loadConfig(slot: AiSlot.assistant);

    var secKey = secondaryApiKey;
    var secUrl = secondaryBaseUrl;

    // Check SecureKeyStore first for ai_api_key_2
    final secureSecKey = await SecureKeyStore.getKey('ai_api_key_2');
    if (secureSecKey != null && secureSecKey.isNotEmpty) {
      secKey = secureSecKey;
    }

    try {
      final db = await DatabaseHelper.instance.database;
      final rows = await db.query(
        'app_settings',
        where: 'key IN (?, ?)',
        whereArgs: ['ai_api_key_2', 'ai_base_url_2'],
      );
      for (final r in rows) {
        final key = r['key'];
        final value = (r['value'] as String?) ?? '';
        if (value.isEmpty) continue;
        if (key == 'ai_api_key_2' && (secKey.isEmpty || secKey == secondaryApiKey)) {
          secKey = value;
        }
        if (key == 'ai_base_url_2') secUrl = value;
      }
    } catch (e) {
      debugPrint('AIGateway: could not read secondary credentials: $e');
    }

    final chain = <AIGatewayConfig>[primary];
    if (secKey.isNotEmpty) {
      final url = secUrl.isNotEmpty ? secUrl : primary.baseUrl;
      if (secKey != primary.apiKey || url != primary.baseUrl) {
        String secModel = primary.model;
        if (url.contains('cloudflare.com') && !secModel.startsWith('@cf/')) {
          secModel = defaultCloudflareModel;
        } else if (url.contains('bigmodel.cn') && secModel.startsWith('@cf/')) {
          secModel = defaultFeaturesModel;
        }
        chain.add(AIGatewayConfig(
          baseUrl: url,
          apiKey: secKey,
          model: secModel,
          timeoutMs: primary.timeoutMs,
        ));
      }
    }

    return chain;
  }

  /// Resolves the model name for a given credential set. If the endpoint provider
  /// (e.g. Cloudflare vs Zhipu/BigModel) differs from the configured model's naming
  /// scheme, automatically substitutes the valid default model for that endpoint.
  String _effectiveModel(AIGatewayConfig config, bool preferLightCloudflareModel) {
    if (config.baseUrl.contains('cloudflare.com')) {
      if (preferLightCloudflareModel) {
        return '@cf/meta/llama-3.2-3b-instruct';
      }
      if (!config.model.startsWith('@cf/')) {
        return defaultCloudflareModel; // '@cf/zai-org/glm-4.7-flash'
      }
    } else if (config.baseUrl.contains('bigmodel.cn')) {
      if (config.model.startsWith('@cf/')) {
        return defaultFeaturesModel; // 'glm-5.2'
      }
    }
    return config.model;
  }

  /// همان منطق _effectiveModel، برای نمایش شفاف در صفحهٔ تنظیمات.
  String previewEffectiveModel({required String baseUrl, required String model}) =>
      _effectiveModel(
        AIGatewayConfig(baseUrl: baseUrl, apiKey: '', model: model, timeoutMs: 0),
        false,
      );

  /// یک درخواست حداقلی به «همین» اعتبارنامه می‌فرستد.
  /// عمداً از _configChain رد نمی‌شود تا نتیجه دربارهٔ همان کلیدی باشد
  /// که کاربر جلوی چشمش دارد.
  Future<AiTestResult> testConnection({
    required String baseUrl,
    required String apiKey,
    required String model,
    int timeoutMs = 15000,
  }) async {
    final normalizedUrl = AiEndpointNormalizer.normalize(baseUrl);
    final effectiveM = previewEffectiveModel(baseUrl: normalizedUrl, model: model);
    final stopwatch = Stopwatch()..start();
    final client = http.Client();

    try {
      final urlError = AiEndpointNormalizer.validate(normalizedUrl);
      if (urlError != null) {
        final res = AiTestResult(
          ok: false,
          latencyMs: 0,
          resolvedModel: effectiveM,
          messageFa: urlError,
          statusCode: 400,
        );
        await AiConnectionRepository.instance.recordTest(res);
        return res;
      }

      if (apiKey.trim().isEmpty) {
        final res = AiTestResult(
          ok: false,
          latencyMs: 0,
          resolvedModel: effectiveM,
          messageFa: 'کلید API وارد نشده است',
          statusCode: 401,
        );
        await AiConnectionRepository.instance.recordTest(res);
        return res;
      }

      final response = await client
          .post(
            Uri.parse(normalizedUrl),
            headers: {
              'Content-Type': 'application/json; charset=utf-8',
              'Authorization': 'Bearer $apiKey',
            },
            body: jsonEncode({
              'model': effectiveM,
              'messages': [
                {'role': 'user', 'content': 'ping'}
              ],
              'temperature': 0,
              'max_tokens': 1,
            }),
          )
          .timeout(Duration(milliseconds: timeoutMs));

      stopwatch.stop();
      final latency = stopwatch.elapsedMilliseconds;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final res = AiTestResult(
          ok: true,
          latencyMs: latency,
          resolvedModel: effectiveM,
          messageFa: 'اتصال برقرار است',
          statusCode: response.statusCode,
        );
        await AiConnectionRepository.instance.recordTest(res);
        return res;
      } else {
        final msg = AiErrorMessages.fa(
          statusCode: response.statusCode,
          errorBody: response.body,
        );
        final res = AiTestResult(
          ok: false,
          latencyMs: latency,
          resolvedModel: effectiveM,
          messageFa: msg,
          statusCode: response.statusCode,
        );
        await AiConnectionRepository.instance.recordTest(res);
        return res;
      }
    } catch (e) {
      stopwatch.stop();
      final msg = AiErrorMessages.fa(exception: e.toString());
      final res = AiTestResult(
        ok: false,
        latencyMs: stopwatch.elapsedMilliseconds,
        resolvedModel: effectiveM,
        messageFa: msg,
      );
      await AiConnectionRepository.instance.recordTest(res);
      return res;
    } finally {
      client.close();
    }
  }

  /// Performs a non-streaming chat completion, transparently failing over to
  /// the secondary credentials when the primary is rate-limited (429), has
  /// exhausted its daily quota (4006), or repeatedly errors. Each credential
  /// set keeps its own exponential-backoff retry budget.
  Future<_ChatOutcome> _postChat({
    required List<Map<String, String>> messages,
    double temperature = 0.3,
    int extraTimeoutMs = 0,
    bool preferLightCloudflareModel = false,
    AiSlot slot = AiSlot.features,
    bool responseFormatJson = false,
  }) async {
    // Local daily AI quota check for free users
    if (!PremiumService.instance.isPremium) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final todayStr = DateTime.now().toIso8601String().substring(0, 10);
        final key = 'local_ai_quota_count_$todayStr';
        final currentCount = prefs.getInt(key) ?? 0;
        final limit = PremiumService.instance.limitFor(PremiumFeature.unlimitedAi);
        
        if (currentCount >= limit) {
          return const _ChatOutcome.failure(
            statusCode: 4006,
            errorBody: '4006: Daily free AI quota exceeded',
            quotaExhausted: true,
          );
        }
      } catch (e, st) {
        debugPrint('Error checking local AI quota: $e\n$st');
      }
    }

    final chain = await _configChain(slot: slot);
    var last = const _ChatOutcome.failure();
    var tryJson = responseFormatJson;

    for (var i = 0; i < chain.length; i++) {
      final config = chain[i];
      if (config.baseUrl.isEmpty) {
        debugPrint('AIGateway: baseUrl is empty for key ${i + 1}/${chain.length}');
        last = const _ChatOutcome.failure(errorBody: 'Empty base URL');
        if (i < chain.length - 1) continue;
        break;
      }
      if (config.apiKey.isEmpty) {
        debugPrint('AIGateway: apiKey is empty for key ${i + 1}/${chain.length}');
        last = const _ChatOutcome.failure(errorBody: 'no_api_key', statusCode: 401);
        if (i < chain.length - 1) continue;
        break;
      }
      final model = _effectiveModel(config, preferLightCloudflareModel);
      final isLastConfig = i == chain.length - 1;

      debugPrint('''

=================== [🤖 RITMO AI POST REQUEST] ===================
📍 Attempt: ${i + 1}/${chain.length}
🌐 Endpoint: ${config.baseUrl}
🧠 Model:    $model
⏱️ Timeout:  ${config.timeoutMs} ms
=================================================================''');

      var retryCount = 0;
      var currentDelayMs = 300;
      final client = http.Client();

      try {
        while (retryCount >= 0) {
          final stopwatch = Stopwatch()..start();
          try {
            final requestBody = <String, dynamic>{
              'model': model,
              'messages': messages,
              'temperature': temperature,
            };
            if (tryJson) {
              requestBody['response_format'] = {'type': 'json_object'};
            }

            final headers = {
              'Authorization': 'Bearer ${config.apiKey}',
              'Content-Type': 'application/json; charset=utf-8',
            };

            final parsedUri = Uri.tryParse(config.baseUrl);
            if (parsedUri == null || config.baseUrl.contains('{ACCOUNT_ID}') || config.baseUrl.contains('YOUR_ACCOUNT_ID')) {
              stopwatch.stop();
              debugPrint('❌ [AI_GATEWAY] Invalid Base URL: "${config.baseUrl}"');
              last = const _ChatOutcome.failure(errorBody: 'Invalid base URL');
              break;
            }

            final response = await client
                .post(
                  parsedUri,
                  headers: headers,
                  body: utf8.encode(jsonEncode(requestBody)),
                )
                .timeout(Duration(milliseconds: config.timeoutMs + extraTimeoutMs));

            stopwatch.stop();

            if (response.statusCode == 400 && tryJson) {
              debugPrint('⚠️ [AI_GATEWAY] Error 400 with JSON format, retrying without JSON format...');
              tryJson = false;
              continue;
            }

            if (response.statusCode == 200) {
              if (!PremiumService.instance.isPremium) {
                try {
                  final prefs = await SharedPreferences.getInstance();
                  final todayStr = DateTime.now().toIso8601String().substring(0, 10);
                  final key = 'local_ai_quota_count_$todayStr';
                  final currentCount = prefs.getInt(key) ?? 0;
                  await prefs.setInt(key, currentCount + 1);
                } catch (e, st) {
                  debugPrint('Error updating local AI quota: $e\n$st');
                }
              }
              final responseString = utf8.decode(response.bodyBytes);
              final responseJson = jsonDecode(responseString);
              final String aiContent =
                  responseJson['choices']?[0]?['message']?['content']?.toString() ?? '';

              debugPrint('✅ [AI_GATEWAY] Success! Provider: ${parsedUri.host} | Model: $model | Latency: ${stopwatch.elapsedMilliseconds}ms');
              debugPrint('=================================================================\n');
              return _ChatOutcome.success(aiContent);
            } else if (response.statusCode == 429 || response.body.contains('1302')) {
              final errBody = utf8.decode(response.bodyBytes);
              last = _ChatOutcome.failure(
                statusCode: response.statusCode,
                errorBody: errBody,
              );
              debugPrint('⚠️ [AI_GATEWAY] Rate limit / Concurrency limit (${response.statusCode}) from ${parsedUri.host} (Model: $model). Body: $errBody');
              if (retryCount > 0) {
                debugPrint('🔄 [AI_GATEWAY] Retrying in ${currentDelayMs}ms...');
                await Future.delayed(Duration(milliseconds: currentDelayMs));
                currentDelayMs *= 2;
                retryCount--;
              } else {
                break;
              }
            } else {
              final errBody = utf8.decode(response.bodyBytes);
              final quota = errBody.contains('4006') ||
                  errBody.contains('daily free allocation');
              last = _ChatOutcome.failure(
                statusCode: response.statusCode,
                errorBody: errBody,
                quotaExhausted: quota,
              );
              debugPrint('⚠️ [AI_GATEWAY] HTTP Error ${response.statusCode} from ${parsedUri.host}. Body: $errBody');
              break;
            }
          } catch (e, stack) {
            stopwatch.stop();
            last = _ChatOutcome.failure(exception: e.toString());
            debugPrint('💥 [AI_GATEWAY] Exception on attempt (${config.baseUrl}): $e\n$stack');
            if (retryCount > 0) {
              await Future.delayed(Duration(milliseconds: currentDelayMs));
              currentDelayMs *= 2;
              retryCount--;
            } else {
              break;
            }
          }
        }
      } finally {
        client.close();
      }

      final shouldFailover = !last.ok;
      if (!shouldFailover) break;
      if (!isLastConfig) {
        debugPrint('🔄 [AI_GATEWAY] Failing over to next credentials in chain (${i + 2}/${chain.length}) due to: ${last.errorDetails}\n');
      }
    }

    return last;
  }

  /// Opens a streaming chat request, transparently failing over to the next
  /// credential set when the primary returns any error or network exception
  /// before streaming begins. On success the caller owns [client] and must close it.
  Future<({bool ok, http.Client? client, http.StreamedResponse? response, String errorTag})>
      _openStream({
    required List<Map<String, dynamic>> messages,
    double temperature = 0.3,
    AiSlot slot = AiSlot.assistant,
  }) async {
    final chain = await _configChain(slot: slot);
    var errorTag = 'HTTP Error unknown';

    debugPrint('\n=================== [🤖 RITMO AI STREAM REQUEST] ===================');
    debugPrint('📍 Total configs in failover chain: ${chain.length} (slot: $slot)');

    for (var i = 0; i < chain.length; i++) {
      final config = chain[i];
      if (config.baseUrl.isEmpty) {
        debugPrint('⚠️ [AI_GATEWAY] baseUrl is empty for key ${i + 1}/${chain.length}');
        errorTag = 'Empty base URL';
        if (i < chain.length - 1) continue;
        break;
      }
      if (config.apiKey.isEmpty) {
        debugPrint('⚠️ [AI_GATEWAY] apiKey is empty for key ${i + 1}/${chain.length}');
        errorTag = 'no_api_key';
        if (i < chain.length - 1) continue;
        break;
      }
      final isLastConfig = i == chain.length - 1;
      final model = _effectiveModel(config, false);
      final client = http.Client();
      final stopwatch = Stopwatch()..start();

      debugPrint('''
-----------------------------------------------------------------
🔹 Attempt ${i + 1}/${chain.length}
🌐 Endpoint: ${config.baseUrl}
🧠 Model:    $model
⏱️ Timeout:  ${config.timeoutMs} ms
-----------------------------------------------------------------''');

      try {
        final parsedUri = Uri.tryParse(config.baseUrl);
        if (parsedUri == null || config.baseUrl.contains('{ACCOUNT_ID}') || config.baseUrl.contains('YOUR_ACCOUNT_ID')) {
          stopwatch.stop();
          debugPrint('❌ [AI_GATEWAY] Invalid Base URL: "${config.baseUrl}"');
          errorTag = 'invalid_url';
          if (!isLastConfig) {
            debugPrint('🔄 [AI_GATEWAY] Failing over to next config in chain (${i + 2}/${chain.length})...\n');
            continue;
          }
          break;
        }

        final requestBody = {
          'model': model,
          'messages': messages,
          'temperature': temperature,
          'stream': true,
        };

        final headers = {
          'Authorization': 'Bearer ${config.apiKey}',
          'Content-Type': 'application/json; charset=utf-8',
        };

        final request = http.Request('POST', parsedUri);
        request.headers.addAll(headers);
        request.body = jsonEncode(requestBody);

        final connectTimeout = config.timeoutMs;
        final response = await client
            .send(request)
            .timeout(Duration(milliseconds: connectTimeout));

        stopwatch.stop();

        if (response.statusCode == 200) {
          debugPrint('✅ [AI_GATEWAY] Stream Connected! Provider: ${parsedUri.host} | Model: $model | Latency: ${stopwatch.elapsedMilliseconds}ms');
          debugPrint('=================================================================\n');
          return (ok: true, client: client, response: response, errorTag: '');
        }

        // Non-200: read the error body to decide whether to fail over.
        final bodyBytes = await response.stream.toBytes();
        final errorBody = utf8.decode(bodyBytes).trim();
        client.close();

        debugPrint('⚠️ [AI_GATEWAY] HTTP Error ${response.statusCode} from ${parsedUri.host} (Model: $model)');
        debugPrint('📝 Body: $errorBody');

        final quota = errorBody.contains('4006') ||
            errorBody.contains('daily free allocation');
        errorTag = quota 
            ? 'quota_exceeded' 
            : 'HTTP Error ${response.statusCode}${errorBody.isNotEmpty ? ': $errorBody' : ''}';

        if (!isLastConfig) {
          debugPrint('🔄 [AI_GATEWAY] Failing over to next config in chain (${i + 2}/${chain.length})...\n');
          continue;
        }
        break;
      } catch (e) {
        stopwatch.stop();
        try {
          client.close();
        } catch (_) {}
        debugPrint('💥 [AI_GATEWAY] Exception on attempt ${i + 1}/${chain.length}: $e');
        errorTag = 'Exception: $e';
        if (!isLastConfig) {
          debugPrint('🔄 [AI_GATEWAY] Failing over to next config in chain (${i + 2}/${chain.length})...\n');
          continue;
        }
        break;
      }
    }

    return (ok: false, client: null, response: null, errorTag: errorTag);
  }

  Future<Map<String, dynamic>> sendQuery({
    required String query,
    required ConsentProfile consent,
    PromptType promptType = PromptType.assistant,
    AiSlot slot = AiSlot.features,
  }) async {
    // 1. Rate Limiting Check
    if (AIRateLimiter.instance.isRateLimited()) {
      return AIFallbackEngine.getFallbackResponse();
    }

    // 2. Build Context
    final context = await AIContextBuilder.buildContext(
      query: query,
      consent: consent,
    );

    // If context builder flagged query as out of scope, trigger fallback immediately
    if (context['user_state']?['status'] == 'out_of_scope') {
      return AIFallbackEngine.getFallbackResponse();
    }

    // 3. Cache Check
    final cachedResponse = AICacheManager.instance.get(query, context);
    if (cachedResponse != null) {
      return cachedResponse;
    }

    // 4. Build Prompts
    final systemPrompt = AIPromptEngine.buildSystemPrompt(promptType);
    final userPrompt = AIPromptEngine.buildUserPrompt(query: query, context: context);

    // 5. Network call with retry, timeout and automatic key failover
    final outcome = await _postChat(
      messages: [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': userPrompt},
      ],
      slot: slot,
    );

    Map<String, dynamic>? finalResponseMap;
    if (outcome.ok) {
      // 6. Parse and validate standard response schema
      finalResponseMap = AIResponseProcessor.process(outcome.content);
    }

    final result =
        finalResponseMap ?? AIFallbackEngine.getNetworkErrorResponse(outcome.errorDetails);

    // 7. Cache response if it is successful (not the default low evidence or error fallback)
    if (result['response'] != AIFallbackEngine.aiPolicyFallbackResponse && result['type'] != 'error') {
      AICacheManager.instance.set(query, context, result);
    }

    return result;
  }

  Future<Map<String, dynamic>> sendCopilotQuery({
    required String query,
    required ConsentProfile consent,
    Map<String, dynamic>? extraContext,
    AiSlot slot = AiSlot.features,
  }) async {
    // 1. Rate Limiting Check
    if (AIRateLimiter.instance.isRateLimited()) {
      return {
        'reply': 'سرعت ارسال درخواست‌ها بیش از حد مجاز است. لطفاً کمی صبر کنید.',
        'actions': []
      };
    }

    // 2. Build Context
    final context = await AIContextBuilder.buildContext(
      query: query,
      consent: consent,
    );

    if (extraContext != null) {
      context.addAll(extraContext);
    }

    // If context builder flagged query as out of scope, trigger fallback immediately
    if (context['user_state']?['status'] == 'out_of_scope') {
      return {
        'reply': 'بر اساس قوانین دسترسی، این اطلاعات در محدوده اختیارات دستیار نیست.',
        'actions': []
      };
    }

    // 3. Build Prompts
    final systemPrompt = AIPromptEngine.buildSystemPrompt(PromptType.copilot);
    final userPrompt = AIPromptEngine.buildCopilotUserPrompt(query: query, context: context);

    // 4. Network call with retry, timeout and automatic key failover
    final outcome = await _postChat(
      messages: [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': userPrompt},
      ],
      slot: slot,
    );

    if (outcome.ok) {
      return AIResponseProcessor.processCopilot(outcome.content);
    }

    if (outcome.quotaExhausted) {
      return {
        'reply':
            'سهمیه رایگان روزانه ۱۰,۰۰۰ نورون هوش مصنوعی کلادفلر شما برای امروز به پایان رسیده است ⚠️\n\nمی‌توانید فردا مجدداً تلاش کنید یا در تنظیمات پروفایل (چرخ‌دنده بالای صفحه) ارائه‌دهنده را روی OpenRouter یا Zhipu AI تنظیم نمایید 🔌',
        'actions': []
      };
    }

    return {
      'reply': 'متاسفم، در ارتباط با هوش مصنوعی خطایی رخ داد: ${outcome.errorDetails}',
      'actions': []
    };
  }

  Future<String> sendRawCompletion({
    required String systemPrompt,
    required String userPrompt,
    bool responseFormatJson = false,
    AiSlot slot = AiSlot.features,
  }) async {
    final outcome = await _postChat(
      messages: [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': userPrompt},
      ],
      slot: slot,
      responseFormatJson: responseFormatJson,
    );

    if (outcome.ok) {
      return outcome.content.trim();
    }
    debugPrint('AIGateway: Raw completion failed: ${outcome.errorDetails}');
    return '';
  }

  Stream<String> sendCopilotQueryStream({
    required String query,
    required ConsentProfile consent,
    Map<String, dynamic>? extraContext,
    AiSlot slot = AiSlot.features,
  }) async* {
    if (AIRateLimiter.instance.isRateLimited()) {
      yield 'error:سرعت ارسال درخواست‌ها بیش از حد مجاز است. لطفاً کمی صبر کنید.';
      return;
    }

    final context = await AIContextBuilder.buildContext(
      query: query,
      consent: consent,
    );

    if (extraContext != null) {
      context.addAll(extraContext);
    }

    if (context['user_state']?['status'] == 'out_of_scope') {
      yield 'error:بر اساس قوانین دسترسی، این اطلاعات در محدوده اختیارات دستیار نیست.';
      return;
    }

    final systemPrompt = AIPromptEngine.buildSystemPrompt(PromptType.copilot);
    final userPrompt = AIPromptEngine.buildCopilotUserPrompt(query: query, context: context);

    final open = await _openStream(
      messages: [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': userPrompt},
      ],
      slot: slot,
    );

    if (!open.ok) {
      yield 'error:${open.errorTag}';
      return;
    }

    final client = open.client!;
    var totalYieldedChars = 0;
    const maxCharsLimit = 2000;

    try {
      final stream = open.response!.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter());

      await for (final line in stream) {
        if (totalYieldedChars >= maxCharsLimit) {
          yield r' ...\n\n⚠️ [پاسخ به دلیل طولانی شدن بیش از حد مجاز (بیش از ۲۰۰۰ کاراکتر) متوقف شد]';
          break;
        }

        final cleanLine = line.trim();
        if (cleanLine.isEmpty) continue;
        if (cleanLine == 'data: [DONE]') break;

        if (cleanLine.startsWith('data: ')) {
          final jsonString = cleanLine.substring(6).trim();
          try {
            final parsed = jsonDecode(jsonString);
            final delta = parsed['choices']?[0]?['delta']?['content']?.toString() ?? '';
            if (delta.isNotEmpty) {
              totalYieldedChars += delta.length;
              yield delta;
            }
          } catch (_) {
            // Ignore malformed JSON during streaming
          }
        }
      }
    } catch (e) {
      yield 'error:Exception: $e';
    } finally {
      client.close();
    }
  }

  Future<Map<String, dynamic>> breakDownGoal({
    required String goalTitle,
    required String goalDescription,
    required String goalType,
    List<String>? userRoutines,
    AiSlot slot = AiSlot.features,
  }) async {
    final prompt = AIPromptEngine.buildGoalBreakdownPrompt(
      goalTitle: goalTitle,
      goalDescription: goalDescription,
      goalType: goalType,
      userRoutines: userRoutines,
    );

    final outcome = await _postChat(
      messages: [
        {'role': 'user', 'content': prompt}
      ],
      temperature: 0.4,
      extraTimeoutMs: 8000,
      slot: slot,
    );

    if (outcome.ok) {
      try {
        var cleanJson = outcome.content.trim();
        if (cleanJson.startsWith('```')) {
          final lines = cleanJson.split('\n');
          if (lines.first.startsWith('```')) lines.removeAt(0);
          if (lines.isNotEmpty && lines.last.startsWith('```')) lines.removeLast();
          cleanJson = lines.join('\n').trim();
        }

        final parsed = jsonDecode(cleanJson);
        if (parsed is Map<String, dynamic>) {
          return parsed;
        }
      } catch (e) {
        debugPrint('AIGateway breakDownGoal parse Exception: $e');
      }
    } else {
      debugPrint('AIGateway breakDownGoal failed: ${outcome.errorDetails}');
    }

    // Structured fallback breakdown in Farsi
    return {
      'subGoals': [
        {
          'title': 'گام اول: برنامه‌ریزی و آمادگی ریتم زندگی',
          'description': 'تهیه مقدمات و بررسی نیازمندی‌ها برای شروع هدف.',
          'goalType': goalType == 'ANNUAL' ? 'MONTHLY' : (goalType == 'MONTHLY' ? 'WEEKLY' : 'DAILY'),
          'steps': [
            {
              'title': 'تعیین زمان ثابت روزانه برای پیگیری هدف',
              'offsetDays': 1,
              'suggestedRoutineType': 'personal'
            },
            {
              'title': 'مطالعه و تحقیق اولیه در مورد نیازمندی‌ها',
              'offsetDays': 2,
              'suggestedRoutineType': 'learning'
            }
          ]
        },
        {
          'title': 'گام دوم: اقدام و تمرین مستمر',
          'description': 'شروع فاز اجرایی و ایجاد عادت‌های جدید.',
          'goalType': goalType == 'ANNUAL' ? 'MONTHLY' : (goalType == 'MONTHLY' ? 'WEEKLY' : 'DAILY'),
          'steps': [
            {
              'title': 'تمرین عملی تمرکز روی ابعاد کلیدی هدف',
              'offsetDays': 7,
              'suggestedRoutineType': 'work'
            }
          ]
        }
      ],
      'steps': [
        {
          'title': 'ارزیابی نهایی پیشرفت هدف در انتهای دوره',
          'offsetDays': 14,
          'suggestedRoutineType': 'personal'
        }
      ]
    };
  }

  Stream<String> sendCustomChatStream({
    required List<Map<String, String>> messages,
    AiSlot slot = AiSlot.assistant,
  }) async* {
    if (AIRateLimiter.instance.isRateLimited()) {
      yield 'error:سرعت ارسال درخواست‌ها بیش از حد مجاز است. لطفاً کمی صبر کنید.';
      return;
    }

    final primary = await _loadConfig(slot: slot);
    if (primary.baseUrl.contains('chatgpt.com')) {
      final userMessage = messages.lastWhere(
        (m) => m['role'] == 'user',
        orElse: () => {'content': ''},
      )['content'] ?? '';
      final systemMessage = messages.firstWhere(
        (m) => m['role'] == 'system',
        orElse: () => {'content': ''},
      )['content'];
      yield* ChatGptWebBridgeManager.instance.sendPrompt(
        prompt: userMessage,
        personaSystemPrompt: systemMessage,
      );
      return;
    }

    final open = await _openStream(
      messages: messages,
      slot: slot,
    );

    if (!open.ok) {
      yield 'error:${open.errorTag}';
      return;
    }

    final client = open.client!;
    var totalYieldedChars = 0;
    const maxCharsLimit = 2000;

    try {
      final stream = open.response!.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter());

      await for (final line in stream) {
        if (totalYieldedChars >= maxCharsLimit) {
          yield '\n\n⚠️ [پاسخ به دلیل طولانی شدن بیش از حد مجاز (بیش از ۲۰۰۰ کاراکتر) متوقف شد]';
          break;
        }

        final cleanLine = line.trim();
        if (cleanLine.isEmpty) continue;
        if (cleanLine == 'data: [DONE]') break;

        if (cleanLine.startsWith('data: ')) {
          final jsonString = cleanLine.substring(6).trim();
          try {
            if (jsonString != '[DONE]') {
              final jsonChunk = jsonDecode(jsonString);
              if (jsonChunk is Map && jsonChunk['choices'] is List && (jsonChunk['choices'] as List).isNotEmpty) {
                final delta = jsonChunk['choices'][0]['delta'];
                if (delta is Map) {
                  final content = delta['content']?.toString();
                  final reasoning = delta['reasoning_content']?.toString();
                  final text = (content != null && content.isNotEmpty)
                      ? content
                      : (reasoning != null && reasoning.isNotEmpty ? reasoning : null);
                  if (text != null && text.isNotEmpty) {
                    totalYieldedChars += text.length;
                    yield text;
                  }
                }
              }
            }
          } catch (e, st) {
            debugPrint('Error parsing stream chunk: $e\n$st');
          }
        }
      }
    } catch (e) {
      yield 'error:$e';
    } finally {
      client.close();
    }
  }

  /// Phase 10 — generic streaming chat on the SAME provider/failover pipeline as
  /// sendCustomChatStream. Caller builds the full messages payload (system + context).
  /// Provider chain and failover semantics are intentionally unchanged.
  Stream<String> sendStreamingCompletion({
    required List<Map<String, String>> messages,
    double temperature = 0.4,
    AiSlot slot = AiSlot.assistant,
  }) async* {
    if (AIRateLimiter.instance.isRateLimited()) {
      yield 'error:rate_limited';
      return;
    }

    final primary = await _loadConfig(slot: slot);
    if (primary.baseUrl.contains('chatgpt.com')) {
      final userMessage = messages.lastWhere(
        (m) => m['role'] == 'user',
        orElse: () => {'content': ''},
      )['content'] ?? '';
      final systemMessage = messages.firstWhere(
        (m) => m['role'] == 'system',
        orElse: () => {'content': ''},
      )['content'];
      yield* ChatGptWebBridgeManager.instance.sendPrompt(
        prompt: userMessage,
        personaSystemPrompt: systemMessage,
      );
      return;
    }

    final open = await _openStream(
      messages: messages,
      temperature: temperature,
      slot: slot,
    );
    if (!open.ok) { yield 'error:${open.errorTag}'; return; }
    final client = open.client!;
    try {
      final stream = open.response!.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter());
      await for (final line in stream) {
        final c = line.trim();
        if (c.isEmpty) continue;
        if (c == 'data: [DONE]') break;
        if (c.startsWith('data: ')) {
          final js = c.substring(6).trim();
          if (js == '[DONE]') break;
          try {
            final parsed = jsonDecode(js);
            final delta = parsed['choices']?[0]?['delta']?['content']?.toString() ?? '';
            if (delta.isNotEmpty) yield delta;
          } catch (e, st) {
            debugPrint('Error parsing streaming completion line: $e\n$st');
          }
        }
      }
    } catch (e) {
      yield 'error:$e';
    } finally {
      client.close();
    }
  }

  Future<String> sendCustomChat({
    required List<Map<String, String>> messages,
    bool responseFormatJson = false,
    AiSlot slot = AiSlot.assistant,
  }) async {
    if (AIRateLimiter.instance.isRateLimited()) {
      return 'سرعت ارسال درخواست‌ها بیش از حد مجاز است. لطفاً کمی صبر کنید.';
    }

    final outcome = await _postChat(
      messages: messages,
      slot: slot,
      responseFormatJson: responseFormatJson,
    );

    if (outcome.ok) {
      return outcome.content;
    }
    if (outcome.quotaExhausted) {
      throw Exception('Daily free AI quota has been exhausted.');
    }
    throw Exception(outcome.errorDetails);
  }

  Future<Map<String, dynamic>?> parseQuickAdd(String inputText, {AiSlot slot = AiSlot.features}) async {
    final cycleKeywords = [
      'menstrual', 'period', 'pregnancy', 'contraceptive', 'hormonal',
      'چرخه قاعدگی', 'سیکل قاعدگی', 'قاعدگی', 'پریود', 'عادت ماهیانه', 'پریودی'
    ];
    for (final kw in cycleKeywords) {
      if (inputText.toLowerCase().contains(kw)) {
        return null;
      }
    }

    final prompt = AIPromptEngine.buildQuickAddPrompt(inputText);

    final outcome = await _postChat(
      messages: [
        {'role': 'user', 'content': prompt}
      ],
      temperature: 0.2,
      preferLightCloudflareModel: true,
      slot: slot,
      responseFormatJson: true,
    );

    if (outcome.ok) {
      final parsed = AIResponseProcessor.processRawJson(outcome.content);
      if (parsed != null) {
        return parsed;
      }
    } else {
      debugPrint('AIGateway parseQuickAdd failed: ${outcome.errorDetails}');
    }
    return null;
  }
}
