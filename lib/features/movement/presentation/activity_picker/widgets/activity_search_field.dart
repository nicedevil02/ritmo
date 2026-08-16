import 'dart:async';
import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/movement/presentation/common/movement_layout.dart';
import 'package:ritmo/features/movement/presentation/common/movement_strings.dart';

/// فیلد جستجوی فعالیت با Debounce ۲۰۰ میلی‌ثانیه‌ای و پاک‌کنندهٔ سریع
class ActivitySearchField extends StatefulWidget {
  const ActivitySearchField({
    super.key,
    required this.onQueryChanged,
    this.hintText,
    this.autofocus = false,
  });

  final ValueChanged<String> onQueryChanged;
  final String? hintText;
  final bool autofocus;

  @override
  State<ActivitySearchField> createState() => _ActivitySearchFieldState();
}

class _ActivitySearchFieldState extends State<ActivitySearchField> {
  final _controller = TextEditingController();
  Timer? _debounceTimer;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String val) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 200), () {
      widget.onQueryChanged(val.trim());
    });
    setState(() {});
  }

  void _clear() {
    _controller.clear();
    _debounceTimer?.cancel();
    widget.onQueryChanged('');
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final sportsColor = context.modules.sports;

    return Semantics(
      label: MovementStrings.searchActivitiesHint,
      textField: true,
      child: Container(
        height: MovementLayout.kFieldMinHeight,
        decoration: BoxDecoration(
          color: colors.surfaceSunken,
          borderRadius: BorderRadius.circular(RitmoRadius.field),
          border: Border.all(color: colors.border),
        ),
        child: TextField(
          controller: _controller,
          autofocus: widget.autofocus,
          onChanged: _onChanged,
          textInputAction: TextInputAction.search,
          style: RitmoTextStyles.body(colors.textPrimary),
          decoration: InputDecoration(
            hintText: widget.hintText ?? MovementStrings.searchActivitiesHint,
            hintStyle: RitmoTextStyles.body(colors.textTertiary),
            prefixIcon: Icon(
              Icons.search_rounded,
              color: colors.textSecondary,
              size: 22,
            ),
            suffixIcon: _controller.text.isNotEmpty
                ? IconButton(
                    icon: Icon(
                      Icons.clear_rounded,
                      color: colors.textSecondary,
                      size: 20,
                    ),
                    onPressed: _clear,
                    tooltip: MovementStrings.searchClear,
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: RitmoSpacing.md,
              vertical: RitmoSpacing.sm,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(RitmoRadius.field),
              borderSide: BorderSide(color: sportsColor, width: 1.5),
            ),
          ),
        ),
      ),
    );
  }
}
