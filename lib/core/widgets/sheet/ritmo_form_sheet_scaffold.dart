// =============================================================================
//  ritmo_form_sheet_scaffold.dart
//  داربست و پوستهٔ مرجع شیت‌های فرم و ورود اطلاعات در ریتمو (Ritmo Canonical Form Sheet Scaffold)
// =============================================================================

import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/ux/ritmo_sheet_scaffold.dart';

/// داربست یکپارچه و استاندارد تمام پنجره‌های فرم و ورود داده در ریتمو.
///
/// قابلیت‌ها:
/// ۱. فیزیک اسنپ هوشمند ریتمو `[0.60, 0.95]` و ژست‌های کشیدن به پایین نرم.
/// ۲. هدر مهارشده (Pinned Header) با دکمه انصراف، گارد خروج خودکار، عنوان و دکمه ذخیره.
/// ۳. هماهنگی با کیبورد (Keyboard Avoidance) بدون برش و اورفلو با `ClipRect`.
/// ۴. چیپ متحرک پیش‌نمایش آیکون و رنگ در هدر.
class RitmoFormSheetScaffold extends StatefulWidget {
  const RitmoFormSheetScaffold({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.iconBadgeColor,
    this.isEditing = false,
    this.saveLabel,
    this.cancelLabel = 'انصراف',
    this.isDirty = false,
    this.isSubmitting = false,
    this.onSave,
    this.onCancel,
    this.leadingAction,
    this.trailingAction,
    this.headerBottom,
    this.builder,
    this.contentPadding,
    this.initialChildSize = 0.60,
    this.minChildSize = 0.0,
    this.maxChildSize = 0.94,
    this.snapSizes = const [0.60, 0.94],
    this.borderRadius = const BorderRadius.vertical(top: Radius.circular(28)),
    this.controller,
    this.deckAnimation,
    this.onDiscardConfirmation,
    this.child,
  }) : assert(child != null || builder != null, 'حداقل یکی از child یا builder باید مقداردهی شود.');

  final String title;
  final String? subtitle;
  final String? icon;
  final Color? iconBadgeColor;
  final bool isEditing;
  final String? saveLabel;
  final String cancelLabel;
  final bool isDirty;
  final bool isSubmitting;
  final VoidCallback? onSave;
  final VoidCallback? onCancel;
  final Widget? leadingAction;
  final Widget? trailingAction;
  final Widget? headerBottom;
  final Widget? child;
  final Widget Function(BuildContext context, ScrollController scrollController)? builder;
  final EdgeInsetsGeometry? contentPadding;
  final double initialChildSize;
  final double minChildSize;
  final double maxChildSize;
  final List<double> snapSizes;
  final BorderRadius? borderRadius;
  final DraggableScrollableController? controller;
  final Animation<double>? deckAnimation;
  final Future<bool> Function()? onDiscardConfirmation;

  /// متد کمکی برای نمایش تمیز و استاندارد شیت فرم از هر کجای اپلیکیشن
  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    String? subtitle,
    String? icon,
    Color? iconBadgeColor,
    bool isEditing = false,
    String? saveLabel,
    String cancelLabel = 'انصراف',
    bool isDirty = false,
    bool isSubmitting = false,
    VoidCallback? onSave,
    VoidCallback? onCancel,
    Widget? leadingAction,
    Widget? trailingAction,
    Widget? headerBottom,
    Widget? child,
    Widget Function(BuildContext context, ScrollController scrollController)? builder,
    EdgeInsetsGeometry? contentPadding,
    double initialChildSize = 0.60,
    double minChildSize = 0.0,
    double maxChildSize = 0.94,
    List<double> snapSizes = const [0.60, 0.94],
    BorderRadius? borderRadius = const BorderRadius.vertical(top: Radius.circular(28)),
    DraggableScrollableController? controller,
    Animation<double>? deckAnimation,
    AnimationController? transitionAnimationController,
    bool useSafeArea = false,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: useSafeArea,
      backgroundColor: Colors.transparent,
      transitionAnimationController: transitionAnimationController,
      builder: (_) => RitmoFormSheetScaffold(
        title: title,
        subtitle: subtitle,
        icon: icon,
        iconBadgeColor: iconBadgeColor,
        isEditing: isEditing,
        saveLabel: saveLabel,
        cancelLabel: cancelLabel,
        isDirty: isDirty,
        isSubmitting: isSubmitting,
        onSave: onSave,
        onCancel: onCancel,
        leadingAction: leadingAction,
        trailingAction: trailingAction,
        headerBottom: headerBottom,
        builder: builder,
        contentPadding: contentPadding,
        initialChildSize: initialChildSize,
        minChildSize: minChildSize,
        maxChildSize: maxChildSize,
        snapSizes: snapSizes,
        borderRadius: borderRadius,
        controller: controller,
        deckAnimation: deckAnimation,
        child: child,
      ),
    );
  }

  @override
  State<RitmoFormSheetScaffold> createState() => _RitmoFormSheetScaffoldState();
}

class _RitmoFormSheetScaffoldState extends State<RitmoFormSheetScaffold> {
  late DraggableScrollableController _internalController;
  DraggableScrollableController get _sheetController => widget.controller ?? _internalController;

  double _lastReportedSize = 0.60;
  bool _isConfirmationShowing = false;
  bool _isDismissing = false;

  @override
  void initState() {
    super.initState();
    if (widget.controller == null) {
      _internalController = DraggableScrollableController();
    }
    _lastReportedSize = widget.initialChildSize;
    AppleCardDeckHost.activeForegroundSheetExtent.value = widget.initialChildSize;

    _sheetController.addListener(_onExtentChanged);
  }

  void _onExtentChanged() {
    if (!_sheetController.isAttached) return;
    final currentSize = _sheetController.size;
    AppleCardDeckHost.activeForegroundSheetExtent.value = currentSize;

    if ((_lastReportedSize < 0.77 && currentSize >= 0.77) ||
        (_lastReportedSize > 0.77 && currentSize <= 0.77)) {
      RitmoHaptics.selection();
    }
    _lastReportedSize = currentSize;
  }

  @override
  void dispose() {
    _sheetController.removeListener(_onExtentChanged);
    if (widget.controller == null) {
      _internalController.dispose();
    }
    AppleCardDeckHost.activeForegroundSheetExtent.value = 0.60;
    super.dispose();
  }

  void _expandSheetToMax() {
    if (_sheetController.isAttached && _sheetController.size < widget.maxChildSize) {
      _sheetController.animateTo(
        widget.maxChildSize,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<bool> _handleDiscardConfirmation() async {
    if (!widget.isDirty || widget.isSubmitting) return true;
    if (_isConfirmationShowing) return false;

    if (widget.onDiscardConfirmation != null) {
      return await widget.onDiscardConfirmation!();
    }

    _isConfirmationShowing = true;
    final shouldDiscard = await RitmoGlassActionSheet.showDiscard(
      context: context,
      title: 'تغییرات ذخیره نشده‌اند',
      message: 'آیا از خروج و حذف اطلاعات وارد شده اطمینان دارید؟',
      discardLabel: 'حذف تغییرات',
      continueEditingLabel: 'ادامه ویرایش',
    );
    _isConfirmationShowing = false;

    return shouldDiscard ?? false;
  }

  void _onCancelPressed() async {
    if (_isDismissing) return;
    if (widget.onCancel != null) {
      widget.onCancel!();
      return;
    }

    if (!widget.isDirty) {
      _isDismissing = true;
      Navigator.of(context).pop();
      return;
    }

    final canDismiss = await _handleDiscardConfirmation();
    if (!mounted) return;
    if (canDismiss) {
      _isDismissing = true;
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDark;
    final effectiveBadgeColor = widget.iconBadgeColor ?? colors.primary;

    if (MediaQuery.of(context).viewInsets.bottom > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _expandSheetToMax();
      });
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: PopScope(
        canPop: !widget.isDirty || widget.isSubmitting,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop) return;
          final canDismiss = await _handleDiscardConfirmation();
          if (canDismiss && mounted) {
            Navigator.of(this.context).pop();
          }
        },
        child: NotificationListener<DraggableScrollableNotification>(
          onNotification: (notification) {
            AppleCardDeckHost.activeForegroundSheetExtent.value = notification.extent;
            if (notification.extent <= 0.05 && !_isDismissing) {
              if (widget.isDirty) {
                if (!_isConfirmationShowing) {
                  if (_sheetController.isAttached) {
                    unawaited(_sheetController.animateTo(
                      widget.initialChildSize,
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                    ));
                  }
                  _handleDiscardConfirmation().then((canDismiss) {
                    if (!mounted) return;
                    if (canDismiss) {
                      _isDismissing = true;
                      Navigator.of(this.context).pop();
                    }
                  });
                }
              } else {
                _isDismissing = true;
                Navigator.of(this.context).pop();
              }
            }
            return true;
          },
          child: DraggableScrollableSheet(
            controller: _sheetController,
            initialChildSize: widget.initialChildSize,
            minChildSize: widget.minChildSize,
            maxChildSize: widget.maxChildSize,
            snap: true,
            snapSizes: widget.snapSizes,
            snapAnimationDuration: const Duration(milliseconds: 250),
            expand: false,
            builder: (context, scrollController) {
              return AppleCardDeckHost(
                animation: widget.deckAnimation,
                topCornerRadius: widget.borderRadius?.topLeft.x ?? 28.0,
                child: RitmoGlassSheet(
                  borderRadius: widget.borderRadius,
                  child: Material(
                    type: MaterialType.transparency,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. Pinned Header with Drag Physics
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onVerticalDragUpdate: (details) {
                        if (_isDismissing || !_sheetController.isAttached) return;
                        final screenHeight = MediaQuery.of(context).size.height;
                        if (screenHeight <= 0) return;

                        final deltaFraction = -details.delta.dy / screenHeight;
                        final newSize = (_sheetController.size + deltaFraction).clamp(0.0, widget.maxChildSize);
                        _sheetController.jumpTo(newSize);
                        AppleCardDeckHost.activeForegroundSheetExtent.value = newSize;
                      },
                      onVerticalDragEnd: (details) async {
                        if (_isDismissing || !_sheetController.isAttached) return;
                        final currentSize = _sheetController.size;
                        final velocity = details.primaryVelocity ?? 0.0;

                        if (velocity < -300 || (velocity <= 0 && currentSize > 0.72)) {
                          unawaited(_sheetController.animateTo(
                            widget.maxChildSize,
                            duration: const Duration(milliseconds: 280),
                            curve: Curves.easeOutCubic,
                          ));
                          return;
                        }

                        if (velocity > 400 || currentSize < 0.48) {
                          if (!widget.isDirty) {
                            _isDismissing = true;
                            Navigator.of(this.context).pop();
                            return;
                          }
                          final canDismiss = await _handleDiscardConfirmation();
                          if (!mounted) return;
                          if (canDismiss) {
                            _isDismissing = true;
                            Navigator.of(this.context).pop();
                          } else if (_sheetController.isAttached) {
                            unawaited(_sheetController.animateTo(
                              widget.initialChildSize,
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeOutCubic,
                            ));
                          }
                          return;
                        }

                        unawaited(_sheetController.animateTo(
                          widget.initialChildSize,
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOutCubic,
                        ));
                      },
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Ritmo Grabber
                            Center(
                              child: Container(
                                width: 38,
                                height: 4.5,
                                decoration: BoxDecoration(
                                  color: colors.textPrimary.withValues(alpha: 0.22),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Leading (Right in RTL): Circular Tactile Cancel (X) Button
                                widget.leadingAction ??
                                    Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: _onCancelPressed,
                                        borderRadius: BorderRadius.circular(17),
                                        child: Container(
                                          width: 34,
                                          height: 34,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: isDark
                                                ? colors.surfaceElevated.withValues(alpha: 0.85)
                                                : colors.textPrimary.withValues(alpha: 0.07),
                                            border: Border.all(
                                              color: isDark
                                                  ? colors.border.withValues(alpha: 0.35)
                                                  : colors.border.withValues(alpha: 0.15),
                                              width: 0.85,
                                            ),
                                          ),
                                          alignment: Alignment.center,
                                          child: Icon(
                                            CupertinoIcons.xmark,
                                            size: 15,
                                            color: colors.textSecondary,
                                          ),
                                        ),
                                      ),
                                    ),

                                // Center: Title + Live Morphing Chip
                                Expanded(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (widget.icon != null) ...[
                                        AnimatedContainer(
                                          duration: const Duration(milliseconds: 250),
                                          curve: Curves.easeOutCubic,
                                          width: 24,
                                          height: 24,
                                          decoration: BoxDecoration(
                                            color: effectiveBadgeColor,
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                color: effectiveBadgeColor.withValues(alpha: 0.4),
                                                blurRadius: 6,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          alignment: Alignment.center,
                                          child: Text(
                                            widget.icon!,
                                            style: const TextStyle(fontSize: 13),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                      ],
                                      Flexible(
                                        child: Text(
                                          widget.title,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: colors.textPrimary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Trailing (Left in RTL): Circular Tactile Save / Confirm (✔) Button
                                widget.trailingAction ??
                                    (widget.onSave == null
                                        ? const SizedBox(width: 34, height: 34)
                                        : Material(
                                            color: Colors.transparent,
                                            child: InkWell(
                                              onTap: widget.isSubmitting ? null : widget.onSave,
                                              borderRadius: BorderRadius.circular(17),
                                              child: Container(
                                                width: 34,
                                                height: 34,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: colors.primary,
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: colors.primary.withValues(alpha: 0.35),
                                                      blurRadius: 8,
                                                      offset: const Offset(0, 2),
                                                    ),
                                                  ],
                                                ),
                                                alignment: Alignment.center,
                                                child: widget.isSubmitting
                                                    ? const SizedBox(
                                                        width: 16,
                                                        height: 16,
                                                        child: CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                          color: Colors.white,
                                                        ),
                                                      )
                                                    : const Icon(
                                                        CupertinoIcons.checkmark,
                                                        size: 16,
                                                        color: Colors.white,
                                                      ),
                                              ),
                                            ),
                                          )),
                              ],
                            ),
                            if (widget.headerBottom != null) ...[
                              const SizedBox(height: 10),
                              widget.headerBottom!,
                            ],
                          ],
                        ),
                      ),
                    ),
                    Divider(height: 1, color: isDark ? colors.border : colors.divider),

                    // 2. Scrollable Body
                    Expanded(
                      child: ClipRect(
                        child: widget.builder != null
                            ? widget.builder!(context, scrollController)
                            : SingleChildScrollView(
                                controller: scrollController,
                                physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                                padding: widget.contentPadding ??
                                    EdgeInsets.only(
                                      bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                                      top: 14,
                                      left: 16,
                                      right: 16,
                                    ),
                                child: widget.child ?? const SizedBox.shrink(),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
          ),
        ),
      ),
    );
  }
}
