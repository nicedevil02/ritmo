import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/movement/presentation/common/movement_strings.dart';

/// توست عملیات قابل بازگشت با مدت ۶ ثانیه (۱۰ ثانیه در حالت دسترسی‌پذیری) و محدودیت یک توست فعال
class MovementUndoToast {
  static OverlayEntry? _activeEntry;
  static VoidCallback? _pendingFinalizeAction;

  static void dismissCurrent() {
    if (_activeEntry != null) {
      _pendingFinalizeAction?.call();
      _pendingFinalizeAction = null;
      _activeEntry?.remove();
      _activeEntry = null;
    }
  }

  static void show(
    BuildContext context, {
    required String message,
    VoidCallback? onUndo,
    VoidCallback? onFinalize,
    IconData icon = Icons.info_outline_rounded,
    Color? iconColor,
  }) {
    // جایگزینی توست قبلی و قطعی‌شدن عملیات قبلی
    dismissCurrent();

    _pendingFinalizeAction = onFinalize;

    final isAccessible =
        context.isLargeTextScale || MediaQuery.accessibleNavigationOf(context);
    final durationSeconds = isAccessible ? 10 : 6;

    final overlayState = Overlay.maybeOf(context, rootOverlay: true);
    if (overlayState == null) return;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => _MovementUndoToastWidget(
        message: message,
        icon: icon,
        iconColor: iconColor ?? ctx.colors.primary,
        durationSeconds: durationSeconds,
        onUndo: onUndo != null
            ? () {
                if (_activeEntry == entry) {
                  _activeEntry?.remove();
                  _activeEntry = null;
                  _pendingFinalizeAction = null;
                }
                RitmoHapticsPolicy.selection();
                onUndo();
              }
            : null,
        onDismiss: () {
          if (_activeEntry == entry) {
            _pendingFinalizeAction?.call();
            _pendingFinalizeAction = null;
            _activeEntry?.remove();
            _activeEntry = null;
          }
        },
      ),
    );

    _activeEntry = entry;
    overlayState.insert(entry);
  }
}

class _MovementUndoToastWidget extends StatefulWidget {
  const _MovementUndoToastWidget({
    required this.message,
    required this.icon,
    required this.iconColor,
    required this.durationSeconds,
    this.onUndo,
    required this.onDismiss,
  });

  final String message;
  final IconData icon;
  final Color iconColor;
  final int durationSeconds;
  final VoidCallback? onUndo;
  final VoidCallback onDismiss;

  @override
  State<_MovementUndoToastWidget> createState() =>
      _MovementUndoToastWidgetState();
}

class _MovementUndoToastWidgetState extends State<_MovementUndoToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;
  Timer? _dismissTimer;
  Timer? _countdownTimer;
  late int _secondsLeft;

  @override
  void initState() {
    super.initState();
    _secondsLeft = widget.durationSeconds;

    _controller = AnimationController(vsync: this, duration: RitmoMotion.sheet);

    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0, -1.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();

    _dismissTimer = Timer(Duration(seconds: widget.durationSeconds), () {
      if (mounted) {
        _controller.reverse().then((_) {
          widget.onDismiss();
        });
      }
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _secondsLeft--;
        });
        if (_secondsLeft <= 0) {
          timer.cancel();
        }
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _countdownTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _handleUndo() {
    _dismissTimer?.cancel();
    _countdownTimer?.cancel();
    _controller.reverse().then((_) => widget.onUndo?.call());
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final topPadding = MediaQuery.paddingOf(context).top;

    return Positioned(
      top: topPadding + RitmoSpacing.md,
      left: RitmoSpacing.lg,
      right: RitmoSpacing.lg,
      child: SlideTransition(
        position: _offsetAnimation,
        child: Material(
          color: Colors.transparent,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(RitmoRadius.card),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: RitmoSpacing.md,
                  vertical: RitmoSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: colors.surfaceElevated.withValues(alpha: 0.90),
                  borderRadius: BorderRadius.circular(RitmoRadius.card),
                  border: Border.all(
                    color: colors.border,
                    width: RitmoElevation.borderWidthDark,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(widget.icon, color: widget.iconColor, size: 18),
                    const SizedBox(width: RitmoSpacing.sm),
                    Expanded(
                      child: Text(
                        widget.message,
                        style: RitmoTextStyles.caption(colors.textPrimary),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (widget.onUndo != null) ...[
                      const SizedBox(width: RitmoSpacing.sm),
                      TextButton(
                        onPressed: _handleUndo,
                        style: TextButton.styleFrom(
                          foregroundColor: colors.primary,
                          minimumSize: const Size(48, 48),
                          padding: const EdgeInsets.symmetric(
                            horizontal: RitmoSpacing.sm,
                          ),
                        ),
                        child: Text(
                          '${MovementStrings.commonUndo} (${toPersianDigits(_secondsLeft)})',
                          style: RitmoTextStyles.label(
                            colors.primary,
                          ).copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
