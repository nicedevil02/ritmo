import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ritmo/core/ai/ai_connection_models.dart';
import 'package:ritmo/core/ai/ai_connection_repository.dart';
import 'package:ritmo/core/ai/ai_endpoint_normalizer.dart';
import 'package:ritmo/core/ai/ai_gateway.dart';
import 'package:ritmo/core/ai/web_bridge/chatgpt_web_bridge_manager.dart';
import 'package:ritmo/core/ai/web_bridge/cloudflare_challenge_modal.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/services/premium_service.dart';
import 'package:ritmo/core/services/secure_key_store.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/utils/ritmo_toast.dart';
import 'package:ritmo/core/ux/ritmo_haptics.dart';
import 'package:ritmo/core/ux/ritmo_skeleton.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_button.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_card.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_page_scaffold.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_segmented_control.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_text_field.dart';
import 'package:ritmo/core/widgets/ritmo_module_app_bar.dart';
import 'package:ritmo/features/profile/presentation/web_bridge_diagnostics_screen.dart';
import 'package:ritmo/features/profile/presentation/widgets/ai_provider_grid.dart';
import 'package:ritmo/features/profile/presentation/widgets/ai_secret_field.dart';
import 'package:ritmo/features/profile/presentation/widgets/ai_status_card.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class AiConnectionScreen extends StatefulWidget {
  const AiConnectionScreen({super.key});

  @override
  State<AiConnectionScreen> createState() => _AiConnectionScreenState();
}

class _AiConnectionScreenState extends State<AiConnectionScreen> {
  late final Future<void> _loadFuture;

  late final TextEditingController _urlController;
  late final TextEditingController _keyController;
  late final TextEditingController _modelController;
  late final TextEditingController _cloudflareAccountIdController;

  late final TextEditingController _backupUrlController;
  late final TextEditingController _backupKeyController;

  late final TextEditingController _featuresUrlController;
  late final TextEditingController _featuresKeyController;
  late final TextEditingController _featuresModelController;

  AiMode _mode = AiMode.ritmoServer;
  String _selectedPresetId = 'zhipu';
  int _timeoutMs = 60000;
  bool _separateFeaturesConfig = false;

  bool _isTesting = false;
  bool _isTestingBackup = false;
  bool _isTestingFeatures = false;

  AiTestResult? _lastTestResult;
  List<AiChainEntry> _chainEntries = [];
  bool _cloudConsentGranted = true;

  int _dailyQuotaUsed = 0;
  int _dailyQuotaLimit = 5;
  bool _showDailyQuota = false;

  String? _urlError;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController();
    _keyController = TextEditingController();
    _modelController = TextEditingController();
    _cloudflareAccountIdController = TextEditingController();

    _backupUrlController = TextEditingController();
    _backupKeyController = TextEditingController();

    _featuresUrlController = TextEditingController();
    _featuresKeyController = TextEditingController();
    _featuresModelController = TextEditingController();

    _loadFuture = _loadInitialData();
  }

  @override
  void dispose() {
    _urlController.dispose();
    _keyController.dispose();
    _modelController.dispose();
    _cloudflareAccountIdController.dispose();

    _backupUrlController.dispose();
    _backupKeyController.dispose();

    _featuresUrlController.dispose();
    _featuresKeyController.dispose();
    _featuresModelController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    try {
      final repo = AiConnectionRepository.instance;
      final config = await repo.load(slot: AiSlot.assistant);
      final featuresConfig = await repo.load(slot: AiSlot.features);
      final mode = await repo.loadMode();
      final lastTest = await repo.lastTest();
      final chain = await repo.describeChain();

      final prefs = await SharedPreferences.getInstance();
      final consent = prefs.getBool('assistant_cloud_consent') ?? true;

      final todayStr = DateTime.now().toIso8601String().substring(0, 10);
      final quotaUsed = prefs.getInt('local_ai_quota_count_$todayStr') ?? 0;
      final isPremium = PremiumService.instance.isPremium;
      final limit = PremiumService.instance.limitFor(PremiumFeature.unlimitedAi);

      if (!mounted) return;
      setState(() {
        _mode = mode;
        _selectedPresetId = config.providerPresetId.isNotEmpty ? config.providerPresetId : 'zhipu';
        _urlController.text = config.baseUrl;
        _keyController.text = config.apiKey;
        _modelController.text = config.model;
        _timeoutMs = config.timeoutMs;
        _backupUrlController.text = config.backupBaseUrl;
        _backupKeyController.text = config.backupApiKey;
        _cloudflareAccountIdController.text = config.cloudflareAccountId;
        _separateFeaturesConfig = config.separateFeaturesConfig;

        _featuresUrlController.text = featuresConfig.baseUrl;
        _featuresKeyController.text = featuresConfig.apiKey;
        _featuresModelController.text = featuresConfig.model;

        _lastTestResult = lastTest;
        _chainEntries = chain;
        _cloudConsentGranted = consent;

        _dailyQuotaUsed = quotaUsed;
        _dailyQuotaLimit = limit;
        _showDailyQuota = !isPremium;

        _urlError = AiEndpointNormalizer.validate(_urlController.text);
      });
    } catch (e, st) {
      debugPrint('Error in _loadInitialData: $e\n$st');
    }
  }

  String get _statusSubtitle {
    if (_mode == AiMode.ritmoServer) {
      return 'متصل · سرور ریتمو';
    }
    final preset = kAiProviderPresets.firstWhere(
      (p) => p.id == _selectedPresetId,
      orElse: () => kAiProviderPresets.first,
    );
    if (_lastTestResult != null && _lastTestResult!.ok) {
      return 'متصل · ${preset.nameFa}';
    } else if (_keyController.text.isEmpty && _urlController.text.isEmpty) {
      return 'پیکربندی نشده';
    } else if (_lastTestResult != null && !_lastTestResult!.ok) {
      return 'مشکل در اتصال';
    }
    return 'پیکربندی شده · ${preset.nameFa}';
  }

  AiHealth get _currentHealth {
    if (_mode == AiMode.ritmoServer) {
      return AiHealth.connected;
    }
    if (_keyController.text.isEmpty && _urlController.text.isEmpty) {
      return AiHealth.unconfigured;
    }
    if (_lastTestResult == null) {
      return AiHealth.untested;
    }
    return _lastTestResult!.ok ? AiHealth.connected : AiHealth.failing;
  }

  String get _currentProviderName {
    if (_mode == AiMode.ritmoServer) return 'سرور ریتمو';
    final preset = kAiProviderPresets.firstWhere(
      (p) => p.id == _selectedPresetId,
      orElse: () => kAiProviderPresets.first,
    );
    return preset.nameFa;
  }

  String get _effectiveModelPreview {
    if (_mode == AiMode.ritmoServer) return 'glm-4.7-flash (ژیپو · سرور ریتمو)';
    final normalized = AiEndpointNormalizer.normalize(_urlController.text);
    return AIGateway.instance.previewEffectiveModel(
      baseUrl: normalized,
      model: _modelController.text,
    );
  }

  Future<void> _saveConfig() async {
    final normalizedUrl = AiEndpointNormalizer.normalize(_urlController.text);
    var finalUrl = normalizedUrl;
    if (_selectedPresetId == 'cloudflare' && _cloudflareAccountIdController.text.isNotEmpty) {
      finalUrl = finalUrl.replaceAll('{ACCOUNT_ID}', _cloudflareAccountIdController.text.trim());
      finalUrl = finalUrl.replaceAll('YOUR_ACCOUNT_ID', _cloudflareAccountIdController.text.trim());
    }

    final config = AiConnectionConfig(
      slot: AiSlot.assistant,
      mode: _mode,
      providerPresetId: _selectedPresetId,
      baseUrl: finalUrl,
      apiKey: _keyController.text.trim(),
      model: _modelController.text.trim(),
      timeoutMs: _timeoutMs,
      backupBaseUrl: AiEndpointNormalizer.normalize(_backupUrlController.text),
      backupApiKey: _backupKeyController.text.trim(),
      cloudflareAccountId: _cloudflareAccountIdController.text.trim(),
      separateFeaturesConfig: _separateFeaturesConfig,
      lastTestAt: _lastTestResult?.latencyMs != null ? DateTime.now().millisecondsSinceEpoch : null,
      lastTestOk: _lastTestResult?.ok,
      lastTestLatencyMs: _lastTestResult?.latencyMs,
      lastErrorCode: _lastTestResult?.statusCode?.toString(),
    );

    await AiConnectionRepository.instance.save(config);

    if (_separateFeaturesConfig) {
      final featuresConfig = AiConnectionConfig(
        slot: AiSlot.features,
        mode: _mode,
        providerPresetId: 'custom',
        baseUrl: AiEndpointNormalizer.normalize(_featuresUrlController.text),
        apiKey: _featuresKeyController.text.trim(),
        model: _featuresModelController.text.trim(),
        timeoutMs: _timeoutMs,
      );
      await AiConnectionRepository.instance.save(featuresConfig);
    }

    final updatedChain = await AiConnectionRepository.instance.describeChain();
    if (mounted) {
      setState(() {
        _chainEntries = updatedChain;
      });
    }
  }

  Future<void> _testPrimaryConnection() async {
    setState(() {
      _isTesting = true;
    });

    await _saveConfig();

    if (_mode == AiMode.ritmoServer) {
      // Priority 1: Zhipu AI
      var result = await AIGateway.instance.testConnection(
        baseUrl: AIGateway.defaultZhipuBaseUrl,
        apiKey: AIGateway.defaultZhipuApiKey,
        model: AIGateway.defaultZhipuModel,
        timeoutMs: 15000,
      );

      // Priority 2: Cloudflare Workers AI (15s)
      if (!result.ok) {
        var cfAccountId = _cloudflareAccountIdController.text.trim();
        if (cfAccountId.isEmpty) {
          cfAccountId = 'd30ec37bac346109c0683cb64a420d97';
        }
        final cfUrl = AIGateway.defaultCloudflareBaseUrl.replaceAll('{ACCOUNT_ID}', cfAccountId);
        result = await AIGateway.instance.testConnection(
          baseUrl: cfUrl,
          apiKey: AIGateway.defaultCloudflareApiKey,
          model: AIGateway.defaultCloudflareModel,
          timeoutMs: 15000,
        );
      }

      // Priority 3: OpenCode fallback (30s)
      if (!result.ok) {
        result = await AIGateway.instance.testConnection(
          baseUrl: AIGateway.defaultBaseUrl,
          apiKey: AIGateway.defaultApiKey,
          model: AIGateway.defaultModel,
          timeoutMs: 30000,
        );
      }

      if (mounted) {
        setState(() {
          _isTesting = false;
          _lastTestResult = result;
        });

        if (result.ok) {
          RitmoHaptics.tap();
          RitmoToast.show(
            context,
            'اتصال به سرور ریتمو با موفقیت برقرار است ✨',
            icon: Icons.check_circle_rounded,
            iconColor: context.colors.success,
          );
        } else {
          RitmoToast.show(
            context,
            result.messageFa,
            icon: Icons.error_outline_rounded,
            iconColor: context.colors.warning,
          );
        }
      }
      return;
    }

    if (_selectedPresetId == 'chatgpt_web') {
      final booted = await ChatGptWebBridgeManager.instance.ensureBooted();
      if (mounted) {
        setState(() {
          _isTesting = false;
        });
        if (booted) {
          RitmoHaptics.tap();
          RitmoToast.show(
            context,
            'پل وب چت‌جی‌پی‌تی با موفقیت آماده به کار شد ✨',
            icon: Icons.check_circle_rounded,
            iconColor: context.colors.success,
          );
        } else if (ChatGptWebBridgeManager.instance.cloudflareNotifier.value) {
          unawaited(CloudflareChallengeModal.show(context));
        } else {
          RitmoToast.show(
            context,
            'خطا در برقراری ارتباط با وب‌سایت ChatGPT. اتصال اینترنت را بررسی کنید.',
            icon: Icons.error_outline_rounded,
            iconColor: context.colors.warning,
          );
        }
      }
      return;
    }

    var targetUrl = AiEndpointNormalizer.normalize(_urlController.text);
    if (_selectedPresetId == 'cloudflare' && _cloudflareAccountIdController.text.isNotEmpty) {
      targetUrl = targetUrl.replaceAll('{ACCOUNT_ID}', _cloudflareAccountIdController.text.trim());
    }

    final result = await AIGateway.instance.testConnection(
      baseUrl: targetUrl,
      apiKey: _keyController.text.trim(),
      model: _modelController.text.trim(),
      timeoutMs: _timeoutMs,
    );

    if (mounted) {
      setState(() {
        _isTesting = false;
        _lastTestResult = result;
      });

      if (result.ok) {
        RitmoHaptics.tap();
        RitmoToast.show(
          context,
          'اتصال با موفقیت برقرار است ✨',
          icon: Icons.check_circle_rounded,
          iconColor: context.colors.success,
        );
      } else {
        RitmoToast.show(
          context,
          result.messageFa,
          icon: Icons.error_outline_rounded,
          iconColor: context.colors.warning,
        );
      }
    }
  }

  Future<void> _testBackupConnection() async {
    setState(() {
      _isTestingBackup = true;
    });

    final targetUrl = AiEndpointNormalizer.normalize(_backupUrlController.text);
    final result = await AIGateway.instance.testConnection(
      baseUrl: targetUrl,
      apiKey: _backupKeyController.text.trim(),
      model: _modelController.text.trim(),
      timeoutMs: _timeoutMs,
    );

    if (mounted) {
      setState(() {
        _isTestingBackup = false;
      });

      if (result.ok) {
        RitmoHaptics.tap();
        RitmoToast.show(
          context,
          'کلید پشتیبان با موفقیت متصل شد ✨',
          icon: Icons.check_circle_rounded,
          iconColor: context.colors.success,
        );
      } else {
        RitmoToast.show(
          context,
          result.messageFa,
          icon: Icons.error_outline_rounded,
          iconColor: context.colors.warning,
        );
      }
    }
  }

  Future<void> _testFeaturesConnection() async {
    setState(() {
      _isTestingFeatures = true;
    });

    await _saveConfig();

    final targetUrl = AiEndpointNormalizer.normalize(_featuresUrlController.text);
    final result = await AIGateway.instance.testConnection(
      baseUrl: targetUrl,
      apiKey: _featuresKeyController.text.trim(),
      model: _featuresModelController.text.trim(),
      timeoutMs: _timeoutMs,
    );

    if (mounted) {
      setState(() {
        _isTestingFeatures = false;
      });

      if (result.ok) {
        RitmoHaptics.tap();
        RitmoToast.show(
          context,
          'سرویس تحلیل‌ها با موفقیت متصل شد ✨',
          icon: Icons.check_circle_rounded,
          iconColor: context.colors.success,
        );
      } else {
        RitmoToast.show(
          context,
          result.messageFa,
          icon: Icons.error_outline_rounded,
          iconColor: context.colors.warning,
        );
      }
    }
  }

  void _onPresetSelected(AiProviderPreset preset) {
    setState(() {
      _selectedPresetId = preset.id;
      if (preset.endpoint.isNotEmpty) {
        _urlController.text = preset.endpoint;
      }
      if (preset.models.isNotEmpty) {
        _modelController.text = preset.models.first;
      }
      _urlError = AiEndpointNormalizer.validate(_urlController.text);
    });
    _saveConfig();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return RitmoPageScaffold(
      padding: EdgeInsets.zero,
      appBar: RitmoModuleAppBar.fromContext(
        context: context,
        title: 'اتصال و سرور هوش مصنوعی',
        subtitle: _statusSubtitle,
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: FutureBuilder<void>(
          future: _loadFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(RitmoSpacing.md),
                child: Column(
                  children: [
                    RitmoSkeletonCard(height: 160),
                    SizedBox(height: RitmoSpacing.md),
                    RitmoSkeletonCard(height: 220),
                  ],
                ),
              );
            }

            final currentPreset = kAiProviderPresets.firstWhere(
              (p) => p.id == _selectedPresetId,
              orElse: () => kAiProviderPresets.first,
            );

            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 60),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Live Status Hero Card
                  AiStatusCard(
                    health: _currentHealth,
                    providerName: _currentProviderName,
                    effectiveModel: _effectiveModelPreview,
                    lastTestLatencyMs: _lastTestResult?.latencyMs,
                    lastTestAt: DateTime.now().millisecondsSinceEpoch,
                    errorMessage: _lastTestResult?.messageFa,
                    isTesting: _isTesting,
                    onTest: _testPrimaryConnection,
                    cloudConsentGranted: _cloudConsentGranted,
                  ),
                  const SizedBox(height: RitmoSpacing.md),

                  // 2. Mode Selector: Ritmo Server vs Personal Key
                  Row(
                    children: [
                      Expanded(
                        child: RitmoCard(
                          isSelected: _mode == AiMode.ritmoServer,
                          onTap: () async {
                            setState(() {
                              _mode = AiMode.ritmoServer;
                            });
                            await AiConnectionRepository.instance.saveMode(AiMode.ritmoServer);
                            await _saveConfig();
                          },
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: (_mode == AiMode.ritmoServer ? colors.primary : colors.textSecondary).withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.cloud_done_rounded,
                                  color: _mode == AiMode.ritmoServer ? colors.primary : colors.textSecondary,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(height: RitmoSpacing.sm),
                              Text(
                                'سرور ریتمو',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: _mode == AiMode.ritmoServer ? colors.primary : colors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'خودکار، پرسرعت و رایگان',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: colors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: RitmoSpacing.sm),
                      Expanded(
                        child: RitmoCard(
                          isSelected: _mode == AiMode.personalKey,
                          onTap: () async {
                            setState(() {
                              _mode = AiMode.personalKey;
                            });
                            await AiConnectionRepository.instance.saveMode(AiMode.personalKey);
                            await _saveConfig();
                          },
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: (_mode == AiMode.personalKey ? colors.primary : colors.textSecondary).withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.vpn_key_rounded,
                                  color: _mode == AiMode.personalKey ? colors.primary : colors.textSecondary,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(height: RitmoSpacing.sm),
                              Text(
                                'کلید شخصی',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: _mode == AiMode.personalKey ? colors.primary : colors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'سرویس‌ها و کلیدهای دلخواه',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: colors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: RitmoSpacing.md),

                  // 3. Primary Mode Views
                  if (_mode == AiMode.ritmoServer) ...[
                    // Ritmo Server Informational Card
                    RitmoCard(
                      padding: const EdgeInsets.all(RitmoSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.shield_outlined, color: colors.primary, size: 20),
                              const SizedBox(width: RitmoSpacing.xs),
                              Text(
                                'اتصال ابری امن ریتمو (۳ لایه خودکار)',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: colors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: RitmoSpacing.sm),
                          Text(
                            'ریتمو سریع‌ترین و پایدارترین مسیر هوش مصنوعی را به شکل هوشمند انتخاب می‌کند:\n'
                            '• لایه ۱: ژیپو (Zhipu AI) با مدل پرسرعت glm-4.7-flash (بدون فیلترشکن)\n'
                            '• لایه ۲: کلودفلر (Cloudflare Workers AI)\n'
                            '• لایه ۳: سرور پشتیبان OpenCode\n\n'
                            'نیازی به ثبت هیچ کلید یا تنظیمی توسط شما نیست و همه چیز آماده کار است.',
                            style: TextStyle(
                              fontSize: 12,
                              color: colors.textSecondary,
                              height: 1.6,
                            ),
                          ),
                          const SizedBox(height: RitmoSpacing.md),
                          RitmoPrimaryButton(
                            label: 'آزمایش اتصال سرور ریتمو',
                            icon: Icons.bolt_rounded,
                            isLoading: _isTesting,
                            onPressed: _testPrimaryConnection,
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    // Personal Key Mode: Provider Selector Grid
                    Text(
                      'انتخاب سرویس‌دهنده هوش مصنوعی',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: RitmoSpacing.sm),
                    AiProviderGrid(
                      presets: kAiProviderPresets,
                      selectedPresetId: _selectedPresetId,
                      onSelect: _onPresetSelected,
                    ),
                    const SizedBox(height: RitmoSpacing.md),

                    // Contextual Provider Action & Link
                    if (_selectedPresetId == 'chatgpt_web') ...[
                      RitmoCard(
                        padding: const EdgeInsets.all(RitmoSpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.public_rounded, color: colors.primary, size: 22),
                                const SizedBox(width: RitmoSpacing.sm),
                                Text(
                                  'پل وب چت‌جی‌پی‌تی (ChatGPT Web)',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: colors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: RitmoSpacing.xs),
                            Text(
                              'اتصال بدون کلید API و مستقیماً از طریق وب‌سایت chatgpt.com برقرار می‌شود.',
                              style: TextStyle(
                                fontSize: 12,
                                color: colors.textSecondary,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: RitmoSpacing.md),
                            RitmoSecondaryButton(
                              label: 'مشاهدهٔ وضعیت و تشخیص پل وب',
                              icon: Icons.monitor_heart_outlined,
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const WebBridgeDiagnosticsScreen(),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: RitmoSpacing.md),
                    ] else ...[
                      // API Key & Model Card
                      RitmoCard(
                        padding: const EdgeInsets.all(RitmoSpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'اطلاعات دسترسی · ${currentPreset.nameFa}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: colors.textPrimary,
                                    ),
                                  ),
                                ),
                                if (currentPreset.keyUrl.isNotEmpty) ...[
                                  const SizedBox(width: RitmoSpacing.xs),
                                  InkWell(
                                    onTap: () async {
                                      final uri = Uri.parse(currentPreset.keyUrl);
                                      if (await canLaunchUrl(uri)) {
                                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                                      }
                                    },
                                    borderRadius: BorderRadius.circular(RitmoRadius.chip),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.open_in_new_rounded, size: 13, color: colors.primary),
                                          const SizedBox(width: 4),
                                          Text(
                                            'دریافت کلید',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: colors.primary,
                                              decoration: TextDecoration.underline,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: RitmoSpacing.sm),

                            if (_selectedPresetId == 'custom') ...[
                              // Custom Service: Base URL, API Key, Model Name
                              RitmoTextField(
                                label: 'آدرس سرویس‌دهنده (Base URL / Endpoint)',
                                hint: 'https://api.openai.com/v1/chat/completions',
                                icon: Icons.link_rounded,
                                controller: _urlController,
                                errorText: _urlError,
                                keyboardType: TextInputType.url,
                                onChanged: (val) {
                                  setState(() {
                                    _urlError = AiEndpointNormalizer.validate(val);
                                  });
                                  _saveConfig();
                                },
                              ),
                              const SizedBox(height: RitmoSpacing.sm),
                              AiSecretField(
                                label: 'کلید دسترسی (API Key)',
                                controller: _keyController,
                                hint: 'sk-... (در صورت نیاز سرور)',
                                hasStoredKey: _keyController.text.isNotEmpty,
                                onChanged: (_) => _saveConfig(),
                                onDelete: () async {
                                  await AiConnectionRepository.instance.deleteKey(AiSlot.assistant);
                                  setState(() {
                                    _keyController.clear();
                                    _lastTestResult = null;
                                  });
                                  if (mounted && context.mounted) RitmoToast.show(context, 'کلید با موفقیت حذف شد');
                                },
                              ),
                              const SizedBox(height: RitmoSpacing.sm),
                              RitmoTextField(
                                label: 'نام مدل هوش مصنوعی (Model Name)',
                                hint: 'gpt-4o, deepseek-chat, llama3.3, ...',
                                icon: Icons.psychology_outlined,
                                controller: _modelController,
                                onChanged: (_) => _saveConfig(),
                              ),
                            ] else ...[
                              if (currentPreset.needsAccountId) ...[
                                RitmoTextField(
                                  label: 'شناسهٔ حساب Cloudflare (Account ID)',
                                  icon: Icons.account_circle_outlined,
                                  controller: _cloudflareAccountIdController,
                                  onChanged: (_) => _saveConfig(),
                                ),
                                const SizedBox(height: RitmoSpacing.sm),
                              ],

                              AiSecretField(
                                label: 'کلید دسترسی (API Key)',
                                controller: _keyController,
                                hint: 'sk-... یا کلید سرویس‌دهنده',
                                hasStoredKey: _keyController.text.isNotEmpty,
                                onChanged: (_) => _saveConfig(),
                                onDelete: () async {
                                  await AiConnectionRepository.instance.deleteKey(AiSlot.assistant);
                                  setState(() {
                                    _keyController.clear();
                                    _lastTestResult = null;
                                  });
                                  if (mounted && context.mounted) RitmoToast.show(context, 'کلید با موفقیت حذف شد');
                                },
                              ),
                              const SizedBox(height: RitmoSpacing.md),

                              // Model Selector for standard presets
                              if (currentPreset.models.isNotEmpty) ...[
                                DropdownButtonFormField<String>(
                                  isExpanded: true,
                                  initialValue: currentPreset.models.contains(_modelController.text)
                                      ? _modelController.text
                                      : currentPreset.models.first,
                                  items: [
                                    for (final m in currentPreset.models)
                                      DropdownMenuItem(
                                        value: m,
                                        child: Text(
                                          m,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 13),
                                        ),
                                      ),
                                    const DropdownMenuItem(
                                      value: '__custom__',
                                      child: Text(
                                        'مدل دلخواه...',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(fontSize: 13),
                                      ),
                                    ),
                                  ],
                                  onChanged: (val) {
                                    if (val != null && val != '__custom__') {
                                      setState(() {
                                        _modelController.text = val;
                                      });
                                      _saveConfig();
                                    }
                                  },
                                  decoration: InputDecoration(
                                    labelText: 'مدل هوش مصنوعی',
                                    filled: true,
                                    fillColor: colors.surfaceSunken,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(RitmoRadius.field),
                                      borderSide: BorderSide(color: colors.border),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(RitmoRadius.field),
                                      borderSide: BorderSide(color: colors.border),
                                    ),
                                  ),
                                ),
                                if (!currentPreset.models.contains(_modelController.text) && _modelController.text.isNotEmpty) ...[
                                  const SizedBox(height: RitmoSpacing.sm),
                                  RitmoTextField(
                                    label: 'نام مدل دلخواه',
                                    hint: 'نام مدل را وارد کنید',
                                    icon: Icons.edit_note_rounded,
                                    controller: _modelController,
                                    onChanged: (_) => _saveConfig(),
                                  ),
                                ],
                              ],
                            ],

                            const SizedBox(height: RitmoSpacing.md),
                            RitmoPrimaryButton(
                              label: 'آزمایش اتصال اختصاصی',
                              icon: Icons.bolt_rounded,
                              isLoading: _isTesting,
                              onPressed: _testPrimaryConnection,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: RitmoSpacing.md),
                    ],
                  ],

                  // 4. Progressive Disclosure: Advanced Settings Expansion
                  RitmoCard(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Theme(
                      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                      child: Material(
                        type: MaterialType.transparency,
                        child: ExpansionTile(
                          leading: Icon(Icons.tune_rounded, color: colors.primary, size: 20),
                          title: Text(
                            'تنظیمات پیشرفته و سفارشی‌سازی',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: colors.textPrimary,
                            ),
                          ),
                          subtitle: Text(
                            'ویرایش آدرس، تایم‌اوت، کلید پشتیبان و تفکیک تحلیل‌ها',
                            style: TextStyle(
                              fontSize: 11,
                              color: colors.textSecondary,
                            ),
                          ),
                          children: [
                          Padding(
                            padding: const EdgeInsets.all(RitmoSpacing.md),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Custom Base URL
                                RitmoTextField(
                                  label: 'آدرس سرویس‌دهنده (Base URL / Endpoint)',
                                  icon: Icons.link_rounded,
                                  controller: _urlController,
                                  errorText: _urlError,
                                  keyboardType: TextInputType.url,
                                  onChanged: (val) {
                                    setState(() {
                                      _urlError = AiEndpointNormalizer.validate(val);
                                    });
                                    _saveConfig();
                                  },
                                ),
                                const SizedBox(height: RitmoSpacing.md),

                                // Timeout Segmented Control
                                Text(
                                  'مهلت پاسخ سرویس‌دهنده (Timeout)',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: colors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: RitmoSpacing.xs),
                                RitmoSegmentedControl<int>(
                                  segments: const {
                                    15000: '۱۵ ثانیه',
                                    30000: '۳۰ ثانیه',
                                    60000: '۶۰ ثانیه',
                                    120000: '۲ دقیقه',
                                  },
                                  selected: _timeoutMs,
                                  onSelected: (timeout) {
                                    setState(() {
                                      _timeoutMs = timeout;
                                    });
                                    _saveConfig();
                                  },
                                ),
                                const SizedBox(height: RitmoSpacing.lg),

                                // Backup Key Failover
                                Text(
                                  'کلید پشتیبان (Failover Key)',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: colors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'در زمان اتمام سهمیه یا عدم پاسخ کلید اول، ریتمو خودکار سراغ این کلید می‌رود.',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: colors.textSecondary,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: RitmoSpacing.sm),
                                RitmoTextField(
                                  label: 'آدرس سرویس‌دهنده پشتیبان',
                                  icon: Icons.link_rounded,
                                  controller: _backupUrlController,
                                  onChanged: (_) => _saveConfig(),
                                ),
                                const SizedBox(height: RitmoSpacing.sm),
                                AiSecretField(
                                  label: 'کلید دسترسی پشتیبان (Backup API Key)',
                                  controller: _backupKeyController,
                                  hint: 'sk-...',
                                  hasStoredKey: _backupKeyController.text.isNotEmpty,
                                  onChanged: (_) => _saveConfig(),
                                  onDelete: () async {
                                    final db = await DatabaseHelper.instance.database;
                                    await SecureKeyStore.deleteKey('ai_api_key_2');
                                    await db.delete('app_settings', where: 'key = ?', whereArgs: ['ai_api_key_2']);
                                    setState(() {
                                      _backupKeyController.clear();
                                    });
                                    await _saveConfig();
                                    if (mounted && context.mounted) RitmoToast.show(context, 'کلید پشتیبان حذف شد');
                                  },
                                ),
                                const SizedBox(height: RitmoSpacing.sm),
                                RitmoPrimaryButton(
                                  label: 'آزمایش کلید پشتیبان',
                                  icon: Icons.bolt_rounded,
                                  isLoading: _isTestingBackup,
                                  onPressed: _testBackupConnection,
                                ),
                                const SizedBox(height: RitmoSpacing.lg),

                                // Features Slot Split Config
                                SwitchListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(
                                    'سرویس‌دهندهٔ جداگانه برای تحلیل‌های پس‌زمینه',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: colors.textPrimary,
                                    ),
                                  ),
                                  subtitle: Text(
                                    'تفکیک مسیر دستیار زنده از کارهای سنگین پس‌زمینه مانند تحلیل‌های هفتگی',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: colors.textSecondary,
                                    ),
                                  ),
                                  value: _separateFeaturesConfig,
                                  onChanged: (val) {
                                    setState(() {
                                      _separateFeaturesConfig = val;
                                    });
                                    _saveConfig();
                                  },
                                ),
                                if (_separateFeaturesConfig) ...[
                                  const SizedBox(height: RitmoSpacing.sm),
                                  RitmoTextField(
                                    label: 'آدرس تحلیل‌ها (Features Base URL)',
                                    controller: _featuresUrlController,
                                    onChanged: (_) => _saveConfig(),
                                  ),
                                  const SizedBox(height: RitmoSpacing.sm),
                                  AiSecretField(
                                    label: 'کلید دسترسی تحلیل‌ها (Features API Key)',
                                    controller: _featuresKeyController,
                                    onChanged: (_) => _saveConfig(),
                                  ),
                                  const SizedBox(height: RitmoSpacing.sm),
                                  RitmoTextField(
                                    label: 'مدل تحلیل‌ها (Features Model)',
                                    controller: _featuresModelController,
                                    onChanged: (_) => _saveConfig(),
                                  ),
                                  const SizedBox(height: RitmoSpacing.sm),
                                  RitmoPrimaryButton(
                                    label: 'آزمایش سرویس تحلیل‌ها',
                                    icon: Icons.bolt_rounded,
                                    isLoading: _isTestingFeatures,
                                    onPressed: _testFeaturesConnection,
                                  ),
                                ],
                              ],
                            ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: RitmoSpacing.md),

                  // 5. Connection Chain Table
                  if (_chainEntries.isNotEmpty) ...[
                    RitmoCard(
                      padding: const EdgeInsets.all(RitmoSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ترتیب تلاش زنجیره (Connection Chain)',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: colors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: RitmoSpacing.sm),
                          for (var i = 0; i < _chainEntries.length; i++) ...[
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 4,
                                    child: Text(
                                      '${toPersianDigits((i + 1).toString())} · ${_chainEntries[i].labelFa}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: colors.textPrimary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: RitmoSpacing.xs),
                                  Flexible(
                                    flex: 3,
                                    child: Text(
                                      _chainEntries[i].host,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.end,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: colors.textSecondary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: RitmoSpacing.xs),
                                  Flexible(
                                    flex: 3,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: colors.surfaceSunken,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        _chainEntries[i].model,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: colors.textTertiary,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: RitmoSpacing.md),
                  ],

                  // 6. Daily Quota Counter (for non-premium)
                  if (_showDailyQuota) ...[
                    RitmoCard(
                      padding: const EdgeInsets.all(RitmoSpacing.md),
                      child: Row(
                        children: [
                          Icon(Icons.bolt_outlined, color: colors.primary, size: 20),
                          const SizedBox(width: RitmoSpacing.sm),
                          Text(
                            'درخواست‌های امروز: ${toPersianDigits(_dailyQuotaUsed.toString())} از ${toPersianDigits(_dailyQuotaLimit.toString())}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: colors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
