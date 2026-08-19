import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ritmo/core/ai/web_bridge/chatgpt_web_bridge_manager.dart';
import 'package:ritmo/core/logging/ritmo_logger.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/ritmo_toast.dart';
import 'package:webview_flutter/webview_flutter.dart';

class VpnRequiredModal extends StatefulWidget {
  const VpnRequiredModal({super.key});

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
        builder: (ctx) => const VpnRequiredModal(),
      );
    } catch (e, st) {
      RitmoLog.error('VpnRequiredModal', 'Error showing modal: $e', e, st);
    } finally {
      _isShowing = false;
    }
  }

  @override
  State<VpnRequiredModal> createState() => _VpnRequiredModalState();
}

class _VpnRequiredModalState extends State<VpnRequiredModal> {
  bool _isRebooting = false;
  bool _showLiveBrowser = false;

  @override
  void initState() {
    super.initState();
    ChatGptWebBridgeManager.instance.vpnRequiredNotifier.addListener(_onVpnStatusChanged);
  }

  @override
  void dispose() {
    ChatGptWebBridgeManager.instance.vpnRequiredNotifier.removeListener(_onVpnStatusChanged);
    super.dispose();
  }

  void _onVpnStatusChanged() {
    if (!ChatGptWebBridgeManager.instance.vpnRequiredNotifier.value) {
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
        RitmoToast.show(
          context,
          'ارتباط با وب‌سایت چت‌جی‌پی‌تی با موفقیت برقرار شد ✨',
          icon: Icons.check_circle_rounded,
          iconColor: context.colors.success,
        );
      }
    }
  }

  Future<void> _handleReload() async {
    setState(() => _isRebooting = true);
    try {
      await ChatGptWebBridgeManager.instance.forceReboot(
        reasonFa: 'تلاش مجدد کاربر پس از فعال‌سازی تحریم‌شکن/VPN',
      );
      await ChatGptWebBridgeManager.instance.ensureBooted();
      if (mounted) {
        RitmoToast.show(
          context,
          'صفحه در حال بارگذاری مجدد است...',
          icon: Icons.refresh_rounded,
          iconColor: context.colors.primary,
        );
      }
    } catch (e) {
      if (mounted) {
        RitmoToast.show(
          context,
          'خطا در بارگذاری مجدد: $e',
          icon: Icons.error_outline_rounded,
          iconColor: context.colors.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRebooting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.colors;
    final textTheme = theme.textTheme;
    final rayId = ChatGptWebBridgeManager.instance.lastRayId;
    final blockedIp = ChatGptWebBridgeManager.instance.lastBlockedIp;
    final controller = ChatGptWebBridgeManager.instance.controller;

    return Container(
      height: MediaQuery.of(context).size.height * (_showLiveBrowser ? 0.85 : 0.65),
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
                    color: colors.warning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(RitmoRadius.badge),
                  ),
                  child: Icon(Icons.vpn_lock_rounded, color: colors.warning, size: 22),
                ),
                const SizedBox(width: RitmoSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'نیاز به فعال‌سازی فیلترشکن / تحریم‌شکن',
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colors.textPrimary,
                        ),
                      ),
                      Text(
                        'سایت ChatGPT آی‌پی فعلی را مسدود کرده است (تحریم یا فیلترینگ)',
                        style: textTheme.bodySmall?.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    _showLiveBrowser ? Icons.info_outline_rounded : Icons.open_in_browser_rounded,
                    color: colors.textSecondary,
                  ),
                  tooltip: _showLiveBrowser ? 'راهنما' : 'نمایش مرورگر زنده',
                  onPressed: () => setState(() => _showLiveBrowser = !_showLiveBrowser),
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: colors.textTertiary),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: colors.borderSubtle),

          // Body Content
          Expanded(
            child: _showLiveBrowser && controller != null
                ? ClipRRect(
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(RitmoRadius.sheet)),
                    child: WebViewWidget(
                      key: const ValueKey('chatgpt_vpn_webview'),
                      controller: controller,
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(RitmoSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Alert Card
                        Container(
                          padding: const EdgeInsets.all(RitmoSpacing.md),
                          decoration: BoxDecoration(
                            color: colors.warning.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(RitmoRadius.card),
                            border: Border.all(color: colors.warning.withValues(alpha: 0.25)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.shield_outlined, color: colors.warning, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    'پیام سایت: Unable to load site',
                                    style: textTheme.labelLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: colors.warning,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'سرورهای OpenAI دسترسی از این نشانی اینترنتی را محدود کرده‌اند. برای استفاده از دستیار، لازم است مسیر اینترنت خود را تغییر دهید.',
                                style: textTheme.bodySmall?.copyWith(color: colors.textPrimary, height: 1.5),
                              ),
                              if (rayId != null || blockedIp != null) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: colors.surfaceElevated,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '${blockedIp != null ? "IP: $blockedIp  |  " : ""}${rayId != null ? "Ray ID: $rayId" : ""}',
                                    style: textTheme.bodySmall?.copyWith(
                                      fontSize: 10,
                                      color: colors.textTertiary,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),

                        const SizedBox(height: RitmoSpacing.md),

                        // Actionable Steps
                        Text(
                          '💡 راه‌های حل و ادامه گفتگو:',
                          style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),

                        _buildSolutionItem(
                          context,
                          number: '۱',
                          title: 'روشن کردن فیلترشکن (VPN)',
                          description: 'یک VPN معتبر را فعال کنید (ترجیحاً سرور اروپا مانند هلند یا آلمان). اگر VPN روشن است، کشور یا سرور آن را عوض کنید.',
                        ),
                        const SizedBox(height: 8),

                        _buildSolutionItem(
                          context,
                          number: '۲',
                          title: 'استفاده از DNS ضدتحریم (بدون نیاز به فیلترشکن)',
                          description: 'می‌توانید DNSهای شکن (Shecan) یا الکترون را در تنظیمات وای‌فای یا گوشی خود ست کنید:\n• 178.22.122.100\n• 185.51.200.2',
                          copyableText: '178.22.122.100, 185.51.200.2',
                        ),
                        const SizedBox(height: 8),

                        _buildSolutionItem(
                          context,
                          number: '۳',
                          title: 'تلاش مجدد و بارگذاری دوباره صفحه',
                          description: 'پس از اتصال VPN یا تغییر DNS، دکمه زیر را لمس کنید تا اتصال ChatGPT بازسازی شود.',
                        ),

                        const SizedBox(height: RitmoSpacing.lg),

                        // Action Buttons
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: colors.primary,
                                  foregroundColor: colors.onPrimary,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(RitmoRadius.field),
                                  ),
                                ),
                                onPressed: _isRebooting ? null : _handleReload,
                                icon: _isRebooting
                                    ? SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: colors.onPrimary,
                                        ),
                                      )
                                    : const Icon(Icons.refresh_rounded, size: 20),
                                label: Text(
                                  _isRebooting ? 'در حال اتصال دوباره...' : 'تلاش مجدد و بارگذاری دوباره',
                                  style: textTheme.labelLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: colors.onPrimary,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(RitmoRadius.field),
                                  ),
                                ),
                                onPressed: () => setState(() => _showLiveBrowser = true),
                                icon: const Icon(Icons.open_in_browser_rounded, size: 18),
                                label: const Text('مشاهده مرورگر'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSolutionItem(
    BuildContext context, {
    required String number,
    required String title,
    required String description,
    String? copyableText,
  }) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(RitmoSpacing.sm),
      decoration: BoxDecoration(
        color: colors.surfaceElevated.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(RitmoRadius.badge),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: colors.primary.withValues(alpha: 0.15),
            child: Text(
              number,
              style: textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: colors.primary,
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: textTheme.bodySmall?.copyWith(
                    color: colors.textSecondary,
                    height: 1.4,
                  ),
                ),
                if (copyableText != null) ...[
                  const SizedBox(height: 4),
                  InkWell(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: copyableText));
                      RitmoToast.show(
                        context,
                        'DNS در حافظه کپی شد',
                        icon: Icons.copy_rounded,
                      );
                    },
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.copy_rounded, size: 14, color: colors.primary),
                          const SizedBox(width: 4),
                          Text(
                            'کپی DNS',
                            style: textTheme.bodySmall?.copyWith(
                              color: colors.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
