import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ritmo/core/ai/chat/chat_action_parser.dart';
import 'package:ritmo/core/ai/chat/chat_models.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/markdown_parser.dart';
import 'package:ritmo/features/assistant/presentation/widgets/confidence_leaflet.dart';
import 'package:ritmo/features/chat/presentation/widgets/chat_action_chip.dart';
import 'package:ritmo/l10n/app_localizations.dart';

class StreamingMessageBubble extends StatefulWidget {
  const StreamingMessageBubble({
    super.key,
    required this.message,
    required this.isLast,
    required this.onAction,
    required this.onCopy,
  });

  final ChatMessage message;
  final bool isLast;
  final void Function(ChatAction) onAction;
  final void Function(String) onCopy;

  @override
  State<StreamingMessageBubble> createState() => _StreamingMessageBubbleState();
}

class _StreamingMessageBubbleState extends State<StreamingMessageBubble> {
  bool _isCopied = false;
  Timer? _copiedTimer;

  @override
  void dispose() {
    _copiedTimer?.cancel();
    super.dispose();
  }

  void _handleCopy() {
    final cleanText = _getDisplayContent(widget.message.content);
    Clipboard.setData(ClipboardData(text: cleanText));
    RitmoHapticsPolicy.selection();
    widget.onCopy(cleanText);

    _copiedTimer?.cancel();
    setState(() {
      _isCopied = true;
    });

    _copiedTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isCopied = false;
        });
      }
    });
  }

  String _getDisplayContent(String rawContent) {
    if (widget.message.role == ChatRole.user) {
      return rawContent;
    }
    return ChatActionParser.extractCleanReplyText(rawContent);
  }

  String _formatTime(DateTime time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isUser = widget.message.role == ChatRole.user;
    final displayContent = _getDisplayContent(widget.message.content);
    final timeStr = _formatTime(widget.message.timestamp);

    final baseStyle = TextStyle(
      fontSize: 13.8,
      height: 1.65,
      color: isUser ? Colors.white : colors.textPrimary,
      fontFamily: 'Vazirmatn',
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxBubbleWidth =
            constraints.maxWidth * RitmoBreakpoints.chatBubbleMaxWidthFactor;

        // Build Copy Button with animated icon transition
        final copyButton = GestureDetector(
          onTap: _handleCopy,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, animation) =>
                  ScaleTransition(scale: animation, child: child),
              child: Icon(
                _isCopied
                    ? CupertinoIcons.checkmark_alt
                    : CupertinoIcons.doc_on_doc,
                key: ValueKey<bool>(_isCopied),
                size: 15,
                color: _isCopied
                    ? colors.success
                    : colors.textSecondary.withValues(alpha: 0.45),
              ),
            ),
          ),
        );

        final showCopy =
            !widget.message.isStreaming && displayContent.isNotEmpty;

        if (isUser) {
          // --- 2026 User Message Bubble ---
          final userBubble = Container(
            constraints: BoxConstraints(maxWidth: maxBubbleWidth),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  colors.primary,
                  colors.primary.withValues(alpha: 0.88),
                ],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(5),
              ),
              boxShadow: [
                BoxShadow(
                  color: colors.primary.withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                RichText(
                  textDirection: TextDirection.rtl,
                  text: TextSpan(
                    style: baseStyle,
                    children: parseMarkdownText(
                      displayContent,
                      baseStyle,
                      codeBgColor: Colors.white.withValues(alpha: 0.2),
                      codeTextColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      timeStr,
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.white.withValues(alpha: 0.75),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      CupertinoIcons.checkmark_alt,
                      size: 12,
                      color: Colors.white.withValues(alpha: 0.75),
                    ),
                  ],
                ),
              ],
            ),
          );

          return Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (showCopy) copyButton else const SizedBox(width: 28),
                    userBubble,
                  ],
                ),
              ),
            ),
          );
        }

        // --- 2026 Assistant Message Bubble ---
        final assistantBubble = Container(
          constraints: BoxConstraints(maxWidth: maxBubbleWidth),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isDark ? colors.surfaceElevated : colors.surface,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
              bottomLeft: Radius.circular(5),
              bottomRight: Radius.circular(20),
            ),
            border: Border.all(
              color: isDark
                  ? colors.borderSubtle.withValues(alpha: 0.6)
                  : colors.borderSubtle,
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Message Content with Rich Markdown
              if (displayContent.isNotEmpty)
                RichText(
                  textDirection: TextDirection.rtl,
                  text: TextSpan(
                    style: baseStyle,
                    children: [
                      ...parseMarkdownText(
                        displayContent,
                        baseStyle,
                        codeBgColor: isDark
                            ? Colors.white.withValues(alpha: 0.1)
                            : Colors.black.withValues(alpha: 0.06),
                        codeTextColor: colors.primary,
                      ),
                      if (widget.message.isStreaming)
                        WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: _BlinkingCursor(color: colors.primary),
                          ),
                        ),
                    ],
                  ),
                )
              else if (widget.message.isStreaming)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 6,
                    horizontal: 8,
                  ),
                  child: _TypingIndicator(color: colors.primary),
                ),

              // Action Chips Row (Quick Executable Buttons)
              if (!widget.message.isStreaming &&
                  widget.message.actions.isNotEmpty) ...[
                const SizedBox(height: 12),
                Directionality(
                  textDirection: TextDirection.rtl,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: widget.message.actions
                        .map(
                          (act) => ChatActionChip(
                            action: act,
                            onTap: () => widget.onAction(act),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],

              // Partial Answer Warning
              if (!widget.message.isStreaming && widget.message.isPartial) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: colors.warning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: colors.warning.withValues(alpha: 0.3),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        CupertinoIcons.exclamationmark_triangle_fill,
                        size: 13,
                        color: colors.warning,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          AppLocalizations.of(
                                context,
                              )?.bridgePartialAnswerWarning ??
                              'این پاسخ کامل دریافت نشد.',
                          style: TextStyle(fontSize: 11, color: colors.warning),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Timestamp at bottom
              if (!widget.message.isStreaming && displayContent.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: Text(
                      timeStr,
                      style: TextStyle(
                        fontSize: 10,
                        color: colors.textSecondary.withValues(alpha: 0.55),
                      ),
                    ),
                  ),
                ),

              // Confidence Leaflet (PSN-47)
              if (!widget.message.isStreaming &&
                  widget.message.briefConfidence != null) ...[
                const SizedBox(height: 8),
                ConfidenceLeaflet(
                  confidence: widget.message.briefConfidence!,
                  usedFields: widget.message.usedFields,
                  annotations: widget.message.validatorAnnotations,
                ),
              ],
            ],
          ),
        );

        return Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  assistantBubble,
                  if (showCopy) copyButton else const SizedBox(width: 28),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BlinkingCursor extends StatefulWidget {
  const _BlinkingCursor({this.color});

  final Color? color;

  @override
  State<_BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<_BlinkingCursor>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final cursorColor = widget.color ?? colors.primary;

    return AnimatedOpacity(
      opacity: _controller.value > 0.5 ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 100),
      child: Container(
        width: 7,
        height: 15,
        decoration: BoxDecoration(
          color: cursorColor,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator({this.color});

  final Color? color;

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final dotColor = widget.color ?? colors.primary;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final delay = index * (2 * math.pi / 3);
            final value = math.sin((_controller.value * 2 * math.pi) - delay);
            final offsetY = ((value + 1) / 2) * -6;

            return Transform.translate(
              offset: Offset(0, offsetY),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 2.5),
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: dotColor.withValues(alpha: 0.6 + (index * 0.15)),
                  shape: BoxShape.circle,
                ),
              ),
            );
          },
        );
      }),
    );
  }
}
