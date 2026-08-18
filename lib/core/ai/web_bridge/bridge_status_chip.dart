import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:ritmo/core/ai/web_bridge/chatgpt_mini_preview.dart';
import 'package:ritmo/core/ai/web_bridge/chatgpt_web_bridge_manager.dart';
import 'package:ritmo/core/ai/web_bridge/cloudflare_challenge_modal.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/profile/presentation/web_bridge_diagnostics_screen.dart';

/// تراشهٔ وضعیت پل وب چت‌جی‌پی‌تی در سربرگ دستیار (A-23، A-24، A-46).
class BridgeStatusChip extends StatelessWidget {
  const BridgeStatusChip({
    super.key,
    this.forceVisible = false,
  });

  final bool forceVisible;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    return ValueListenableBuilder<ChatGptBridgeStatus>(
      valueListenable: ChatGptWebBridgeManager.instance.statusNotifier,
      builder: (context, status, _) {
        if (status == ChatGptBridgeStatus.idle && !forceVisible) {
          return const SizedBox.shrink();
        }

        final (label, iconData, chipColor, isClickable) = switch (status) {
          ChatGptBridgeStatus.booting => (
              'در حال اتصال…',
              CupertinoIcons.arrow_2_circlepath,
              colors.primary,
              false,
            ),
          ChatGptBridgeStatus.ready => (
              'متصل',
              CupertinoIcons.checkmark_circle_fill,
              colors.success,
              false,
            ),
          ChatGptBridgeStatus.generating => (
              'در حال دریافت…',
              CupertinoIcons.sparkles,
              colors.primary,
              true,
            ),
          ChatGptBridgeStatus.cloudflareChallenge => (
              'نیاز به تأیید امنیتی',
              CupertinoIcons.shield_fill,
              colors.warning,
              true,
            ),
          ChatGptBridgeStatus.error => (
              'اتصال قطع است',
              CupertinoIcons.exclamationmark_triangle_fill,
              colors.error,
              true,
            ),
          ChatGptBridgeStatus.idle => (
              'غیرفعال',
              CupertinoIcons.circle,
              colors.textSecondary,
              false,
            ),
        };

        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          child: Material(
            color: chipColor.withValues(alpha: 0.12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: chipColor.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: InkWell(
              onTap: isClickable
                  ? () {
                      if (status == ChatGptBridgeStatus.cloudflareChallenge) {
                        CloudflareChallengeModal.show(context);
                      } else if (status == ChatGptBridgeStatus.generating) {
                        ChatGptMiniPreview.show(context);
                      } else if (status == ChatGptBridgeStatus.error) {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const WebBridgeDiagnosticsScreen(),
                          ),
                        );
                      }
                    }
                  : null,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      iconData,
                      size: 13,
                      color: chipColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      label,
                      style: textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: chipColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
