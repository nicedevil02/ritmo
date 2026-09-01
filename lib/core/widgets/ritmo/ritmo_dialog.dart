// Ritmo Dialog & Glass Dialog — دیالوگ تأیید، هشدار و مودال شیشه‌ای یکپارچه
// جایگزین رسمی AlertDialog های خام و مات

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_button.dart';

class RitmoDialog extends StatelessWidget {
  const RitmoDialog({
    super.key,
    required this.title,
    required this.content,
    this.confirmLabel = 'تأیید',
    this.cancelLabel = 'انصراف',
    this.icon,
    this.onConfirm,
    this.onCancel,
    this.isDestructive = false,
  });

  final String title;
  final String content;
  final String confirmLabel;
  final String cancelLabel;
  final IconData? icon;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;
  final bool isDestructive;

  /// متد فراخوانی دیالوگ شیشه‌ای استاندارد با انیمیشن ورود و بلور زنده
  static Future<bool?> show(
    BuildContext context, {
    required String title,
    required String content,
    String confirmLabel = 'تأیید',
    String cancelLabel = 'انصراف',
    IconData? icon,
    bool isDestructive = false,
  }) {
    if (isDestructive) {
      RitmoHaptics.warning();
    } else {
      RitmoHaptics.tap();
    }

    return showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      barrierDismissible: true,
      builder: (context) => RitmoDialog(
        title: title,
        content: content,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        icon: icon,
        isDestructive: isDestructive,
        onConfirm: () {
          RitmoHaptics.tap();
          Navigator.of(context).pop(true);
        },
        onCancel: () {
          RitmoHaptics.tap();
          Navigator.of(context).pop(false);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDark;
    final isGlass = context.isGlassEnabled;
    final highContrast = MediaQuery.maybeOf(context)?.highContrast ?? false;
    final materialSpec = context.materials.regular;

    final primaryAccent = isDestructive ? colors.error : colors.primary;
    final isOpaque = !isGlass || highContrast;

    final dialogContent = Container(
      constraints: const BoxConstraints(maxWidth: 380),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isOpaque
            ? colors.surfaceElevated
            : (isDark
                ? const Color(0xFF131722).withValues(alpha: 0.88)
                : Colors.white.withValues(alpha: 0.90)),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isOpaque
              ? (isDark ? colors.border : colors.divider)
              : (isDark
                  ? Colors.white.withValues(alpha: 0.12)
                  : Colors.white.withValues(alpha: 0.95)),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.60 : 0.18),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: primaryAccent.withValues(alpha: isDark ? 0.12 : 0.08),
            blurRadius: 20,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header with optional Icon & Title
          Row(
            children: [
              if (icon != null) ...[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primaryAccent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 20, color: primaryAccent),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: isDestructive ? colors.error : colors.textPrimary,
                    fontFamily: 'Vazirmatn',
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Content description
          Text(
            content,
            style: TextStyle(
              fontSize: 13.5,
              color: colors.textSecondary,
              height: 1.65,
              fontFamily: 'Vazirmatn',
            ),
          ),

          const SizedBox(height: 22),

          // Action Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Expanded(
                child: RitmoSecondaryButton(
                  label: cancelLabel,
                  onPressed: onCancel ?? () {
                    RitmoHaptics.tap();
                    Navigator.of(context).pop(false);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: RitmoPrimaryButton(
                  label: confirmLabel,
                  fullWidth: true,
                  onPressed: onConfirm ?? () {
                    RitmoHaptics.tap();
                    Navigator.of(context).pop(true);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );

    final Widget renderedDialog = isOpaque
        ? dialogContent
        : ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: materialSpec.sigma,
                sigmaY: materialSpec.sigma,
              ),
              child: dialogContent,
            ),
          );

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Material(
            color: Colors.transparent,
            child: renderedDialog,
          ),
        ),
      ),
    );
  }
}

/// Alias برای هماهنگی با نام‌گذاری شیشه‌ای
typedef RitmoGlassDialog = RitmoDialog;

/// دیالوگ شیشه‌ای استاندارد با محتوای سفارشی (فرم، اسلایدر، ورودی‌های اختصاصی و...)
class RitmoCustomDialog extends StatelessWidget {
  const RitmoCustomDialog({
    super.key,
    required this.title,
    required this.content,
    this.actions = const [],
    this.icon,
  });

  final String title;
  final Widget content;
  final List<Widget> actions;
  final IconData? icon;

  static Future<T?> show<T>(
    BuildContext context, {
    required String title,
    required Widget content,
    List<Widget> actions = const [],
    IconData? icon,
    bool barrierDismissible = true,
  }) {
    RitmoHaptics.tap();
    return showDialog<T>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      barrierDismissible: barrierDismissible,
      builder: (context) => RitmoCustomDialog(
        title: title,
        content: content,
        actions: actions,
        icon: icon,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDark;
    final isGlass = context.isGlassEnabled;
    final highContrast = MediaQuery.maybeOf(context)?.highContrast ?? false;
    final materialSpec = context.materials.regular;
    final isOpaque = !isGlass || highContrast;

    final dialogContent = Container(
      constraints: const BoxConstraints(maxWidth: 400),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isOpaque
            ? colors.surfaceElevated
            : (isDark
                ? const Color(0xFF131722).withValues(alpha: 0.88)
                : Colors.white.withValues(alpha: 0.90)),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isOpaque
              ? (isDark ? colors.border : colors.divider)
              : (isDark
                  ? Colors.white.withValues(alpha: 0.12)
                  : Colors.white.withValues(alpha: 0.95)),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.60 : 0.18),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 20, color: colors.primary),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: colors.textPrimary,
                    fontFamily: 'Vazirmatn',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          content,
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 22),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: actions,
            ),
          ],
        ],
      ),
    );

    final Widget renderedDialog = isOpaque
        ? dialogContent
        : ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: materialSpec.sigma,
                sigmaY: materialSpec.sigma,
              ),
              child: dialogContent,
            ),
          );

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Material(
            color: Colors.transparent,
            child: renderedDialog,
          ),
        ),
      ),
    );
  }
}

/// دیالوگ شیشه‌ای استاندارد دریافت متن و ورودی از کاربر با مدیریت ایمن حافظه کنترلر
class RitmoInputDialog extends StatefulWidget {
  const RitmoInputDialog({
    super.key,
    required this.title,
    this.hintText,
    this.initialValue = '',
    this.confirmLabel = 'تأیید',
    this.cancelLabel = 'انصراف',
    this.icon,
    this.keyboardType = TextInputType.text,
  });

  final String title;
  final String? hintText;
  final String initialValue;
  final String confirmLabel;
  final String cancelLabel;
  final IconData? icon;
  final TextInputType keyboardType;

  static Future<String?> show(
    BuildContext context, {
    required String title,
    String? hintText,
    String initialValue = '',
    String confirmLabel = 'تأیید',
    String cancelLabel = 'انصراف',
    IconData? icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    RitmoHaptics.tap();
    return showDialog<String>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      barrierDismissible: true,
      builder: (context) => RitmoInputDialog(
        title: title,
        hintText: hintText,
        initialValue: initialValue,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        icon: icon,
        keyboardType: keyboardType,
      ),
    );
  }

  @override
  State<RitmoInputDialog> createState() => _RitmoInputDialogState();
}

class _RitmoInputDialogState extends State<RitmoInputDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    RitmoHaptics.selection();
    Navigator.of(context).pop(text);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDark;
    final isGlass = context.isGlassEnabled;
    final highContrast = MediaQuery.maybeOf(context)?.highContrast ?? false;
    final materialSpec = context.materials.regular;
    final isOpaque = !isGlass || highContrast;

    final dialogContent = Container(
      constraints: const BoxConstraints(maxWidth: 380),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isOpaque
            ? colors.surfaceElevated
            : (isDark
                ? const Color(0xFF131722).withValues(alpha: 0.88)
                : Colors.white.withValues(alpha: 0.90)),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isOpaque
              ? (isDark ? colors.border : colors.divider)
              : (isDark
                  ? Colors.white.withValues(alpha: 0.12)
                  : Colors.white.withValues(alpha: 0.95)),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.60 : 0.18),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: colors.primary.withValues(alpha: isDark ? 0.12 : 0.08),
            blurRadius: 20,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header with optional Icon & Title
          Row(
            children: [
              if (widget.icon != null) ...[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(widget.icon, size: 20, color: colors.primary),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  widget.title,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: colors.textPrimary,
                    fontFamily: 'Vazirmatn',
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // TextField with custom decoration
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: widget.keyboardType,
            style: TextStyle(
              fontFamily: 'Vazirmatn',
              fontSize: 14,
              color: colors.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: widget.hintText,
              hintStyle: TextStyle(
                fontFamily: 'Vazirmatn',
                fontSize: 13,
                color: colors.textSecondary.withValues(alpha: 0.6),
              ),
              filled: true,
              fillColor: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.04),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: colors.border.withValues(alpha: 0.4)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: colors.border.withValues(alpha: 0.4)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: colors.primary, width: 1.6),
              ),
            ),
            onSubmitted: (_) => _submit(),
          ),

          const SizedBox(height: 22),

          // Action Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Expanded(
                child: RitmoSecondaryButton(
                  label: widget.cancelLabel,
                  onPressed: () {
                    RitmoHaptics.tap();
                    Navigator.of(context).pop(null);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: RitmoPrimaryButton(
                  label: widget.confirmLabel,
                  fullWidth: true,
                  onPressed: _submit,
                ),
              ),
            ],
          ),
        ],
      ),
    );

    final Widget renderedDialog = isOpaque
        ? dialogContent
        : ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: materialSpec.sigma,
                sigmaY: materialSpec.sigma,
              ),
              child: dialogContent,
            ),
          );

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Material(
            color: Colors.transparent,
            child: renderedDialog,
          ),
        ),
      ),
    );
  }
}

