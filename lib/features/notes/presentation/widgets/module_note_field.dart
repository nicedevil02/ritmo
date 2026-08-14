import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';

/// Standard note input field for module sheets and screens (M-01).
class ModuleNoteField extends StatefulWidget {
  const ModuleNoteField({
    super.key,
    required this.controller,
    this.hintFa = 'یادداشت خود را بنویسید...',
    this.maxLength = 500,
    this.onPromote,
    this.focusNode,
    this.onChanged,
  });

  final TextEditingController controller;
  final String hintFa;
  final int maxLength;
  final VoidCallback? onPromote;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;

  @override
  State<ModuleNoteField> createState() => _ModuleNoteFieldState();
}

class _ModuleNoteFieldState extends State<ModuleNoteField> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textLength = widget.controller.text.length;
    final showCounter = textLength > 200;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          children: [
            TextField(
              controller: widget.controller,
              focusNode: widget.focusNode,
              maxLines: 3,
              maxLength: widget.maxLength,
              textDirection: TextDirection.rtl,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.textPrimary,
                  ),
              onChanged: widget.onChanged,
              decoration: InputDecoration(
                hintText: widget.hintFa,
                hintStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.textSecondary.withValues(alpha: 0.6),
                    ),
                counterText: '', // Custom counter below
                filled: true,
                fillColor: colors.surfaceSunken,
                contentPadding: const EdgeInsets.fromLTRB(RitmoSpacing.xxl + 8, RitmoSpacing.md, RitmoSpacing.md, RitmoSpacing.md),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(RitmoRadius.field),
                  borderSide: BorderSide(color: colors.border.withValues(alpha: 0.2)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(RitmoRadius.field),
                  borderSide: BorderSide(color: colors.primary, width: 1.5),
                ),
              ),
            ),
            Positioned(
              top: RitmoSpacing.xs,
              left: RitmoSpacing.xs,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.controller.text.isNotEmpty)
                    IconButton(
                      icon: Icon(Icons.clear, size: 18, color: colors.textSecondary),
                      onPressed: () {
                        widget.controller.clear();
                        widget.onChanged?.call('');
                      },
                      tooltip: 'پاک کردن',
                    ),
                  if (widget.onPromote != null && widget.controller.text.trim().isNotEmpty)
                    IconButton(
                      icon: Icon(Icons.menu_book_rounded, size: 18, color: colors.primary),
                      onPressed: widget.onPromote,
                      tooltip: 'تبدیل به یادداشت دفترچه',
                    ),
                ],
              ),
            ),
          ],
        ),
        if (showCounter)
          Padding(
            padding: const EdgeInsets.only(top: RitmoSpacing.xs, left: RitmoSpacing.xs),
            child: Text(
              PersianDigits.convert('$textLength/${widget.maxLength}'),
              textAlign: TextAlign.left,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: textLength >= widget.maxLength ? colors.error : colors.textSecondary,
                  ),
            ),
          ),
      ],
    );
  }
}
