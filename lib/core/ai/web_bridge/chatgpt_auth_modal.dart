import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ritmo/core/ai/web_bridge/chatgpt_web_bridge_manager.dart';
import 'package:ritmo/core/logging/ritmo_logger.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/ritmo_toast.dart';
import 'package:ritmo/core/widgets/sheet/ritmo_full_bleed_sheet.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Modal dialog/bottom sheet enabling users to sign into ChatGPT directly within the app.
class ChatGptAuthModal extends StatefulWidget {
  const ChatGptAuthModal({super.key});

  static bool _isShowing = false;

  /// Shows the authentication modal sheet and returns true if user became authenticated.
  static Future<bool> show(BuildContext context) async {
    if (_isShowing) return false;
    _isShowing = true;
    try {
      final result = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        isDismissible: true,
        enableDrag: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => const ChatGptAuthModal(),
      );
      return result ?? ChatGptWebBridgeManager.instance.isAuthenticated;
    } catch (e, st) {
      RitmoLog.error('ChatGptAuthModal', 'Error displaying auth modal: $e', e, st);
      return false;
    } finally {
      _isShowing = false;
    }
  }

  @override
  State<ChatGptAuthModal> createState() => _ChatGptAuthModalState();
}

class _ChatGptAuthModalState extends State<ChatGptAuthModal> {
  @override
  void initState() {
    super.initState();
    ChatGptWebBridgeManager.instance.statusNotifier.addListener(_onStatusChanged);
  }

  @override
  void dispose() {
    ChatGptWebBridgeManager.instance.statusNotifier.removeListener(_onStatusChanged);
    super.dispose();
  }

  void _onStatusChanged() {
    final mgr = ChatGptWebBridgeManager.instance;
    if (mgr.isAuthenticated && mgr.status == ChatGptBridgeStatus.ready) {
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context, true);
        RitmoToast.show(
          context,
          'ورود به حساب ChatGPT با موفقیت انجام شد ✨',
          icon: Icons.check_circle_rounded,
          iconColor: context.colors.success,
        );
      }
    }
  }

  Future<void> _copyDiagnosticSnapshot() async {
    try {
      RitmoToast.show(
        context,
        'در حال استخراج کدهای صفحه...',
        icon: Icons.hourglass_top_rounded,
      );
      final snapshot = await ChatGptWebBridgeManager.instance.captureDiagnosticSnapshot();
      await Clipboard.setData(ClipboardData(text: snapshot));
      if (mounted) {
        RitmoToast.show(
          context,
          'گزارش و کدهای HTML چت‌جی‌پی‌تی با موفقیت کپی شد 📋',
          icon: Icons.check_circle_rounded,
          iconColor: context.colors.success,
        );
      }
    } catch (e) {
      if (mounted) {
        RitmoToast.show(
          context,
          'خطا در استخراج کدهای صفحه: $e',
          icon: Icons.error_outline_rounded,
          iconColor: context.colors.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.colors;
    final textTheme = theme.textTheme;
    final controller = ChatGptWebBridgeManager.instance.controller;

    return RitmoFullBleedSheet(
      maxHeightFactor: 0.9,
      minHeightFactor: 0.6,
      child: Container(
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
                  child: Icon(Icons.account_circle_rounded, color: colors.primary, size: 22),
                ),
                const SizedBox(width: RitmoSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ورود به حساب کاربری ChatGPT',
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colors.textPrimary,
                        ),
                      ),
                      Text(
                        'پس از ورود، این پنجره به‌طور خودکار بسته خواهد شد.',
                        style: textTheme.bodySmall?.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.copy_all_rounded, color: colors.textSecondary),
                  tooltip: 'کپی گزارش تشخیصی و HTML صفحه',
                  onPressed: _copyDiagnosticSnapshot,
                ),
                IconButton(
                  icon: Icon(Icons.refresh_rounded, color: colors.textSecondary),
                  tooltip: 'بارگذاری مجدد صفحه',
                  onPressed: () => ChatGptWebBridgeManager.instance.reloadPage(),
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: colors.textTertiary),
                  tooltip: 'بستن',
                  onPressed: () => Navigator.pop(context, false),
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
                      key: const ValueKey('chatgpt_auth_modal_webview'),
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
                          'در حال آماده‌سازی صفحه ورود...',
                          style: textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    ),);
  }
}
