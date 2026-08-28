import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ritmo/core/ai/web_bridge/chatgpt_web_bridge_manager.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/ritmo_toast.dart';
import 'package:webview_flutter/webview_flutter.dart';

class ChatGptMiniPreview extends StatefulWidget {
  const ChatGptMiniPreview({
    super.key,
    this.onClose,
    this.initiallyMinimized = true,
  });

  final VoidCallback? onClose;
  final bool initiallyMinimized;

  /// Displays the mini preview bottom sheet from anywhere (A-47).
  static Future<void> show(BuildContext context) async {
    if (ChatGptWebBridgeManager.instance.status == ChatGptBridgeStatus.idle) {
      unawaited(ChatGptWebBridgeManager.instance.ensureBooted());
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      enableDrag: false,
      isDismissible: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                ChatGptMiniPreview(
                  initiallyMinimized: false,
                  onClose: () => Navigator.of(ctx).pop(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  State<ChatGptMiniPreview> createState() => _ChatGptMiniPreviewState();
}

class _ChatGptMiniPreviewState extends State<ChatGptMiniPreview> {
  late bool _isMinimized;
  bool _isMaximized = false;

  @override
  void initState() {
    super.initState();
    _isMinimized = widget.initiallyMinimized;
    ChatGptWebBridgeManager.instance.attachViewer();
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
    final colors = context.colors;
    final isDark = context.isDark;
    final isGlass = context.isGlassEnabled;
    final blur = context.glassBlurSigma.clamp(0.0, 50.0);
    final textTheme = Theme.of(context).textTheme;
    final controller = ChatGptWebBridgeManager.instance.controller;
    final cardRadius = BorderRadius.circular(RitmoRadius.card);

    return ValueListenableBuilder<ChatGptBridgeStatus>(
      valueListenable: ChatGptWebBridgeManager.instance.statusNotifier,
      builder: (context, status, _) {
        final isError = status == ChatGptBridgeStatus.error;
        final isGenerating = status == ChatGptBridgeStatus.generating;

        final cardContent = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.black.withValues(alpha: 0.03),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: switch (status) {
                              ChatGptBridgeStatus.ready => colors.success,
                              ChatGptBridgeStatus.generating => colors.warning,
                              ChatGptBridgeStatus.cloudflareChallenge => colors.error,
                              ChatGptBridgeStatus.vpnRequired => colors.warning,
                              _ => colors.textTertiary,
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'مرورگر زنده چت‌جی‌پی‌تی (${_getStatusLabel(status)})',
                            style: textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colors.textPrimary,
                            ),
                          ),
                        ),
                        Tooltip(
                          message: 'کپی گزارش تشخیصی و HTML صفحه',
                          child: InkWell(
                            onTap: _copyDiagnosticSnapshot,
                            borderRadius: BorderRadius.circular(4),
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Icon(
                                Icons.copy_all_rounded,
                                size: 16,
                                color: colors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Tooltip(
                          message: isGenerating
                              ? 'در حین تولید پاسخ نمی‌توان صفحه را نو کرد'
                              : 'بارگذاری مجدد',
                          child: InkWell(
                            onTap: isGenerating
                                ? null
                                : () => ChatGptWebBridgeManager.instance.forceReboot(
                                      reasonFa: 'بارگذاری مجدد توسط کاربر از پیش‌نمایش',
                                    ),
                            borderRadius: BorderRadius.circular(4),
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Icon(
                                Icons.refresh_rounded,
                                size: 16,
                                color: isGenerating
                                    ? colors.textTertiary.withValues(alpha: 0.4)
                                    : colors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Tooltip(
                          message: 'اسکرول به بالا',
                          child: InkWell(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              ChatGptWebBridgeManager.instance.scrollToTop();
                            },
                            borderRadius: BorderRadius.circular(4),
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Icon(
                                Icons.arrow_upward_rounded,
                                size: 16,
                                color: colors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Tooltip(
                          message: 'اسکرول به پایین',
                          child: InkWell(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              ChatGptWebBridgeManager.instance.scrollToBottom();
                            },
                            borderRadius: BorderRadius.circular(4),
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Icon(
                                Icons.arrow_downward_rounded,
                                size: 16,
                                color: colors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Tooltip(
                          message: _isMaximized ? 'اندازه معمولی' : 'بزرگ‌تر کردن مرورگر',
                          child: InkWell(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() {
                                _isMaximized = !_isMaximized;
                                if (_isMinimized) _isMinimized = false;
                              });
                            },
                            borderRadius: BorderRadius.circular(4),
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Icon(
                                _isMaximized
                                    ? Icons.fullscreen_exit_rounded
                                    : Icons.fullscreen_rounded,
                                size: 18,
                                color: colors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        InkWell(
                          onTap: () {
                            setState(() {
                              _isMinimized = !_isMinimized;
                            });
                          },
                          borderRadius: BorderRadius.circular(4),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(
                              _isMinimized ? Icons.expand_more_rounded : Icons.expand_less_rounded,
                              size: 16,
                              color: colors.textSecondary,
                            ),
                          ),
                        ),
                        if (widget.onClose != null) ...[
                          const SizedBox(width: 4),
                          InkWell(
                            onTap: widget.onClose,
                            borderRadius: BorderRadius.circular(4),
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Icon(Icons.close_rounded, size: 16, color: colors.textTertiary),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // WebView Body
                  if (!_isMinimized)
                    Builder(
                      builder: (ctx) {
                        final mediaQuery = MediaQuery.of(ctx);
                        final keyboardHeight = mediaQuery.viewInsets.bottom;
                        final screenHeight = mediaQuery.size.height;
                        final availableHeight = (screenHeight - keyboardHeight - mediaQuery.padding.top - mediaQuery.padding.bottom - 100.0).clamp(160.0, 1200.0);

                        final double calculatedHeight = _isMaximized
                            ? (availableHeight * 0.95).clamp(240.0, 750.0)
                            : (keyboardHeight > 0
                                ? (availableHeight * 0.85).clamp(180.0, 320.0)
                                : (screenHeight * 0.48).clamp(280.0, 500.0));

                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOutCubic,
                          height: calculatedHeight,
                          width: double.infinity,
                          child: controller != null
                              ? WebViewWidget(
                                  key: const ValueKey(
                                      'chatgpt_mini_preview_webview'),
                                  controller: controller,
                                  gestureRecognizers: const <
                                      Factory<OneSequenceGestureRecognizer>>{
                                    Factory<VerticalDragGestureRecognizer>(
                                        VerticalDragGestureRecognizer.new),
                                    Factory<HorizontalDragGestureRecognizer>(
                                        HorizontalDragGestureRecognizer.new),
                                    Factory<PanGestureRecognizer>(
                                        PanGestureRecognizer.new),
                                    Factory<ScaleGestureRecognizer>(
                                        ScaleGestureRecognizer.new),
                                    Factory<TapGestureRecognizer>(
                                        TapGestureRecognizer.new),
                                    Factory<EagerGestureRecognizer>(
                                        EagerGestureRecognizer.new),
                                  },
                                )
                              : Center(
                                  child: InkWell(
                                    onTap: () => ChatGptWebBridgeManager.instance.attachViewer(),
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (isError) ...[
                                            Icon(Icons.error_outline_rounded, color: colors.error, size: 28),
                                            const SizedBox(height: 8),
                                            Text(
                                              'خطا در برقراری ارتباط با وب‌سایت. لمس برای تلاش مجدد',
                                              textAlign: TextAlign.center,
                                              style: textTheme.bodySmall?.copyWith(color: colors.error),
                                            ),
                                          ] else ...[
                                            const CircularProgressIndicator.adaptive(strokeWidth: 2.5),
                                            const SizedBox(height: 10),
                                            Text(
                                              'در حال اتصال به مرورگر چت‌جی‌پی‌تی...',
                                              style: textTheme.bodySmall?.copyWith(color: colors.textSecondary),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                        );
                      },
                    ),
                ],
              );

        return Material(
          type: MaterialType.transparency,
          child: Container(
            margin: const EdgeInsets.symmetric(
              horizontal: RitmoSpacing.md,
              vertical: RitmoSpacing.xs,
            ),
            child: !isGlass
                ? Container(
                    decoration: BoxDecoration(
                      color: colors.surfaceElevated,
                      borderRadius: cardRadius,
                      border: Border.all(
                        color: isDark ? colors.border : colors.divider,
                        width: 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: colors.shadow.withValues(alpha: 0.15),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(RitmoRadius.card - 1),
                      child: cardContent,
                    ),
                  )
                : DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: cardRadius,
                      boxShadow: [
                        BoxShadow(
                          color: isDark
                              ? Colors.black.withValues(alpha: 0.35)
                              : colors.primary.withValues(alpha: 0.08),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: cardRadius,
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: colors.glassTint,
                            borderRadius: cardRadius,
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.18)
                                  : Colors.white.withValues(alpha: 0.70),
                              width: 1.0,
                            ),
                          ),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: cardRadius,
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
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(RitmoRadius.card - 1),
                              child: cardContent,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
        );
      },
    );
  }

  String _getStatusLabel(ChatGptBridgeStatus status) {
    return switch (status) {
      ChatGptBridgeStatus.ready => 'آماده',
      ChatGptBridgeStatus.booting => 'در حال راه‌اندازی...',
      ChatGptBridgeStatus.generating => 'در حال تولید پاسخ...',
      ChatGptBridgeStatus.cloudflareChallenge => 'چالش کلودفلر',
      ChatGptBridgeStatus.vpnRequired => 'نیاز به تحریم‌شکن / VPN',
      ChatGptBridgeStatus.error => 'خطا',
      _ => 'غیرفعال',
    };
  }
}
