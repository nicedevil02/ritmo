import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';

class TaskInlineAddBar extends StatelessWidget {
  const TaskInlineAddBar({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border.withValues(alpha: 0.6)),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                style: TextStyle(fontSize: 14, color: colors.textPrimary),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => onSubmitted(),
                decoration: InputDecoration(
                  hintText: 'افزودن کار جدید (تگ‌ها با #)...',
                  hintStyle: TextStyle(fontSize: 13, color: colors.textSecondary.withValues(alpha: 0.6)),
                  border: InputBorder.none,
                ),
              ),
            ),
            IconButton(
              icon: Icon(CupertinoIcons.add_circled_solid, color: colors.primary, size: 28),
              onPressed: onSubmitted,
            ),
          ],
        ),
      ),
    );
  }
}
