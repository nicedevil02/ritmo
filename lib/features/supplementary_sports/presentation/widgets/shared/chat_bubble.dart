import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';

class ChatBubble extends StatelessWidget {
  const ChatBubble({
    super.key,
    required this.message,
    required this.isFromUser,
  });

  final String message;
  final bool isFromUser;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final m = context.metrics;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Alignment
    final alignment = isFromUser ? Alignment.centerRight : Alignment.centerLeft;

    // Colors
    final userBgColor = colors.success;
    final userTextColor = isDark ? Colors.black : Colors.white;

    final aiBgColor = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.04);
    final aiBorderColor = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.08);
    final aiTextColor = colors.textPrimary;

    // Padding
    final bubblePadding = EdgeInsets.symmetric(
      horizontal: m.spaceLg,
      vertical: m.spaceMd,
    );

    // Border Radius
    final borderRadius = BorderRadius.only(
      topLeft: Radius.circular(m.radiusCard),
      topRight: Radius.circular(m.radiusCard),
      bottomLeft: Radius.circular(isFromUser ? m.radiusCard : 4),
      bottomRight: Radius.circular(isFromUser ? 4 : m.radiusCard),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        return Align(
          alignment: alignment,
          child: Container(
            margin: EdgeInsets.symmetric(vertical: m.spaceSm),
            constraints: BoxConstraints(
              maxWidth:
                  constraints.maxWidth *
                  RitmoBreakpoints.chatBubbleMaxWidthFactor,
            ),
            padding: bubblePadding,
            decoration: BoxDecoration(
              color: isFromUser ? userBgColor : aiBgColor,
              borderRadius: borderRadius,
              border: isFromUser ? null : Border.all(color: aiBorderColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Text(
              message,
              textDirection: TextDirection.rtl,
              style: RitmoTextStyles.body(
                isFromUser ? userTextColor : aiTextColor,
              ).copyWith(height: 1.5),
            ),
          ),
        );
      },
    );
  }
}
