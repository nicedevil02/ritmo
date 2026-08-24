// Ritmo TextField — ویجت ورودی متنی متصل به سیستم توکن
// جایگزین InputDecoration های دستی و پراکنده

import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';

class RitmoTextField extends StatelessWidget {
  const RitmoTextField({
    super.key,
    required this.label,
    this.controller,
    this.initialValue,
    this.icon,
    this.hint,
    this.errorText,
    this.obscureText = false,
    this.keyboardType,
    this.onChanged,
    this.onSubmitted,
    this.maxLines = 1,
    this.enabled = true,
  });

  final String label;
  final TextEditingController? controller;
  final String? initialValue;
  final IconData? icon;
  final String? hint;
  final String? errorText;
  final bool obscureText;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final int maxLines;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final m = context.metrics;

    return TextFormField(
      controller: controller,
      initialValue: initialValue,
      obscureText: obscureText,
      keyboardType: keyboardType,
      onChanged: onChanged,
      onFieldSubmitted: onSubmitted,
      maxLines: maxLines,
      enabled: enabled,
      style:
          context.t.bodyLarge?.copyWith(color: colors.textPrimary) ??
          TextStyle(
            fontSize: 15,
            color: colors.textPrimary,
            fontFamily: 'Vazirmatn',
          ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle:
            context.t.bodySmall?.copyWith(color: colors.textSecondary) ??
            TextStyle(
              color: colors.textSecondary,
              fontSize: 13,
              fontFamily: 'Vazirmatn',
            ),
        hintText: hint,
        hintStyle:
            context.t.bodySmall?.copyWith(color: colors.textTertiary) ??
            TextStyle(
              color: colors.textTertiary,
              fontSize: 13,
              fontFamily: 'Vazirmatn',
            ),
        errorText: errorText,
        errorStyle:
            context.t.labelSmall?.copyWith(color: colors.error) ??
            TextStyle(
              color: colors.error,
              fontSize: 11,
              fontFamily: 'Vazirmatn',
            ),
        prefixIcon: icon != null
            ? Icon(icon, color: colors.primary, size: m.iconMd)
            : null,
        filled: true,
        fillColor: colors.surfaceSunken,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(m.radiusField),
          borderSide: BorderSide(color: colors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(m.radiusField),
          borderSide: BorderSide(color: colors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(m.radiusField),
          borderSide: BorderSide(color: colors.primary, width: 1.5),
        ),
      ),
    );
  }
}
