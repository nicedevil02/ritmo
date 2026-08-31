import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/observability/ritmo_logger.dart';

/// User-friendly, graceful error widget for screen and component crash handling (R-5).
/// Supports both full-screen and compact inline error presentation to prevent layout breaks.
class RitmoFriendlyErrorPane extends StatefulWidget {
  const RitmoFriendlyErrorPane({
    super.key,
    this.details,
    this.errorMessage,
    this.onRetry,
    this.isCompact = false,
  });

  final FlutterErrorDetails? details;
  final String? errorMessage;
  final VoidCallback? onRetry;
  final bool isCompact;

  @override
  State<RitmoFriendlyErrorPane> createState() => _RitmoFriendlyErrorPaneState();
}

class _RitmoFriendlyErrorPaneState extends State<RitmoFriendlyErrorPane> {
  bool _showDebugDetails = false;

  @override
  void initState() {
    super.initState();
    try {
      final msg = widget.errorMessage ?? widget.details?.exceptionAsString() ?? 'UI Exception';
      RitmoLogger.error(
        'RitmoFriendlyErrorPane caught error',
        error: widget.details?.exception,
        stack: widget.details?.stack,
        context: {'scope': 'UI_ErrorWidget', 'userMessage': msg},
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = false;
    try {
      isDark = Theme.of(context).brightness == Brightness.dark;
    } catch (_) {}
    final backgroundColor = isDark ? const Color(0xff12111E) : const Color(0xffF8FAFC);
    final cardColor = isDark ? const Color(0xff1E1B2E) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xff0F172A);
    final subTextColor = isDark ? const Color(0xff94A3B8) : const Color(0xff64748B);

    if (widget.isCompact) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xffF43F5E).withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: const Color(0xffF43F5E).withValues(alpha: 0.30),
              width: 0.8,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: Color(0xffF43F5E),
                size: 16,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'خطا در نمایش بخش',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 11,
                    fontFamily: 'Vazirmatn',
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (widget.onRetry != null) ...[
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: widget.onRetry,
                  child: const Icon(
                    Icons.refresh_rounded,
                    color: Color(0xff6366F1),
                    size: 16,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Material(
        color: backgroundColor,
        child: Center(
          child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 480),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xffF43F5E).withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.sentiment_dissatisfied_rounded,
                          color: Color(0xffF43F5E),
                          size: 44,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'مشکلی در پردازش این بخش پیش آمد',
                        style: TextStyle(
                          color: textColor,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Vazirmatn',
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'اطلاعات و پیشرفت شما کاملاً محفوظ است. لطفاً دوباره تلاش کنید.',
                        style: TextStyle(
                          color: subTextColor,
                          fontSize: 13,
                          height: 1.5,
                          fontFamily: 'Vazirmatn',
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      if (widget.onRetry != null)
                        ElevatedButton.icon(
                          onPressed: widget.onRetry,
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text(
                            'تلاش دوباره',
                            style: TextStyle(fontFamily: 'Vazirmatn', fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xff6366F1),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      if (kDebugMode && widget.details != null) ...[
                        const SizedBox(height: 20),
                        const Divider(),
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _showDebugDetails = !_showDebugDetails;
                            });
                          },
                          icon: Icon(
                            _showDebugDetails
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.keyboard_arrow_down_rounded,
                            size: 20,
                          ),
                          label: Text(
                            _showDebugDetails ? 'مخفی‌سازی جزئیات فنی' : 'نمایش جزئیات فنی (Debug)',
                            style: const TextStyle(fontSize: 12, fontFamily: 'Vazirmatn'),
                          ),
                        ),
                        if (_showDebugDetails)
                          Container(
                            margin: const EdgeInsets.only(top: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SelectableText(
                                  widget.details!.exceptionAsString(),
                                  style: const TextStyle(
                                    color: Colors.redAccent,
                                    fontSize: 12,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                                if (widget.details!.stack != null) ...[
                                  const SizedBox(height: 8),
                                  SelectableText(
                                    widget.details!.stack.toString(),
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 10,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }
    }
