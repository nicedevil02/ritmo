import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:ritmo/core/ai/web_bridge/chatgpt_web_bridge_manager.dart';
import 'package:ritmo/core/logging/ritmo_logger.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/ritmo_toast.dart';
import 'package:ritmo/core/widgets/sheet/ritmo_full_bleed_sheet.dart';
import 'package:webview_flutter/webview_flutter.dart';

class CloudflareChallengeModal extends StatefulWidget {
  const CloudflareChallengeModal({super.key});

  static bool _isShowing = false;

  static Future<void> show(BuildContext context) async {
    if (_isShowing) return;
    _isShowing = true;
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        isDismissible: true,
        enableDrag: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => const CloudflareChallengeModal(),
      );
    } catch (e, st) {
      RitmoLog.error('CloudflareChallengeModal', 'Error showing modal: $e', e, st);
    } finally {
      _isShowing = false;
    }
  }

  @override
  State<CloudflareChallengeModal> createState() => _CloudflareChallengeModalState();
}

class _CloudflareChallengeModalState extends State<CloudflareChallengeModal> {
  @override
  void initState() {
    super.initState();
    ChatGptWebBridgeManager.instance.cloudflareNotifier.addListener(_onCloudflareStatusChanged);
    ChatGptWebBridgeManager.instance.attachViewer();
  }

  @override
  void dispose() {
    ChatGptWebBridgeManager.instance.cloudflareNotifier.removeListener(_onCloudflareStatusChanged);
    super.dispose();
  }

  void _onCloudflareStatusChanged() {
    if (!ChatGptWebBridgeManager.instance.cloudflareNotifier.value) {
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
        RitmoToast.show(
          context,
          'تایید امنیتی کلودفلر با موفقیت انجام شد ✨',
          icon: Icons.check_circle_rounded,
          iconColor: context.colors.success,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.colors;
    final isDark = context.isDark;
    final isGlass = context.isGlassEnabled;
    final blur = context.glassBlurSigma.clamp(0.0, 50.0);
    final textTheme = theme.textTheme;
    final controller = ChatGptWebBridgeManager.instance.controller;
    const sheetRadius = BorderRadius.vertical(top: Radius.circular(RitmoRadius.sheet));

    final sheetContent = Column(
      children: [
        // Header Bar
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: RitmoSpacing.md,
            vertical: RitmoSpacing.sm,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(RitmoRadius.badge),
                ),
                child: Icon(Icons.security_rounded, color: colors.primary, size: 20),
              ),
              const SizedBox(width: RitmoSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'تایید هویت امنیتی (Cloudflare)',
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colors.textPrimary,
                      ),
                    ),
                    Text(
                      'لطفاً باکس تایید «Verify you are human» را لمس کنید.',
                      style: textTheme.bodySmall?.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.refresh_rounded, color: colors.textSecondary),
                tooltip: ChatGptWebBridgeManager.instance.status == ChatGptBridgeStatus.generating
                    ? 'در حین تولید پاسخ نمی‌توان صفحه را نو کرد'
                    : 'بارگذاری مجدد',
                onPressed: ChatGptWebBridgeManager.instance.status == ChatGptBridgeStatus.generating
                    ? null
                    : () => ChatGptWebBridgeManager.instance.forceReboot(
                          reasonFa: 'بارگذاری مجدد توسط کاربر در چالش کلودفلر',
                        ),
              ),
              IconButton(
                icon: Icon(Icons.close_rounded, color: colors.textTertiary),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: isDark ? colors.border : colors.divider),

        // Interactive WebView container
        Expanded(
          child: controller != null
              ? ClipRRect(
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(RitmoRadius.sheet)),
                  child: WebViewWidget(
                    key: const ValueKey('chatgpt_cloudflare_webview'),
                    controller: controller,
                  ),
                )
              : Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: colors.primary),
                      const SizedBox(height: RitmoSpacing.md),
                      Text(
                        'در حال آماده‌سازی پنجره تایید...',
                        style: textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );

    return RitmoFullBleedSheet(
      minHeightFactor: 0.42,
      maxHeightFactor: 0.58,
      child: !isGlass
          ? Container(
              decoration: BoxDecoration(
                color: colors.surfaceElevated,
                borderRadius: sheetRadius,
                border: Border.all(
                  color: isDark ? colors.border : colors.divider,
                  width: 1.0,
                ),
              ),
              child: sheetContent,
            )
          : DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: sheetRadius,
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.35)
                        : colors.primary.withValues(alpha: 0.08),
                    offset: const Offset(0, -3),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: sheetRadius,
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.glassTint,
                      borderRadius: sheetRadius,
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.18)
                            : Colors.white.withValues(alpha: 0.70),
                        width: 1.0,
                      ),
                    ),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: sheetRadius,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withValues(
                              alpha: isDark ? 0.08 : 0.20,
                            ),
                            Colors.white.withValues(alpha: 0.0),
                          ],
                          stops: const [0.0, 0.45],
                        ),
                      ),
                      child: sheetContent,
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
