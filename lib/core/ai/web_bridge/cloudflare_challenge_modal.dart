import 'package:flutter/material.dart';
import 'package:ritmo/core/ai/web_bridge/chatgpt_web_bridge_manager.dart';
import 'package:ritmo/core/logging/ritmo_logger.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/ritmo_toast.dart';
import 'package:webview_flutter/webview_flutter.dart';

class CloudflareChallengeModal extends StatefulWidget {
  const CloudflareChallengeModal({super.key});

  static bool _isShowing = false;

  static Future<void> show(BuildContext context) async {
    if (_isShowing) return;
    _isShowing = true;
    try {
      await showModalBottomSheet(
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
    final colors = context.colors;
    final controller = ChatGptWebBridgeManager.instance.controller;

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(RitmoRadius.sheet)),
        border: Border(
          top: BorderSide(color: colors.borderSubtle),
          left: BorderSide(color: colors.borderSubtle),
          right: BorderSide(color: colors.borderSubtle),
        ),
      ),
      child: Column(
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
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: colors.textPrimary,
                        ),
                      ),
                      Text(
                        'لطفاً باکس تایید «Verify you are human» را لمس کنید.',
                        style: TextStyle(
                          fontSize: 11,
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
          Divider(height: 1, color: colors.borderSubtle),

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
                          style: TextStyle(color: colors.textSecondary, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
