// lib/features/routines/presentation/widgets/dedicated_builder_sheet.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/routines/presentation/planner_controller.dart';

class DedicatedBuilderSheet extends StatelessWidget {
  const DedicatedBuilderSheet({
    super.key,
    required this.title,
    required this.subtitle,
    required this.controller,
    required this.formWidget,
    required this.onSaved,
  });

  final String title;
  final String subtitle;
  final PlannerController controller;
  final Widget formWidget;
  final VoidCallback onSaved;

  static Future<void> show({
    required BuildContext context,
    required String title,
    required String subtitle,
    required PlannerController controller,
    required Widget formWidget,
    required VoidCallback onSaved,
    AnimationController? transitionAnimationController,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      transitionAnimationController: transitionAnimationController,
      builder: (sheetCtx) => DraggableScrollableSheet(
        initialChildSize: 0.60,
        minChildSize: 0.40,
        maxChildSize: 0.95,
        snap: true,
        snapSizes: const [0.60, 0.95],
        expand: false,
        builder: (context, scrollController) => DedicatedBuilderSheet(
          title: title,
          subtitle: subtitle,
          controller: controller,
          formWidget: formWidget,
          onSaved: onSaved,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final viewInsetsBottom = MediaQuery.viewInsetsOf(context).bottom;
    final hasKeyboard = viewInsetsBottom > 0;
    const sheetRadius = BorderRadius.vertical(top: Radius.circular(24));

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return Padding(
          padding: EdgeInsets.only(bottom: viewInsetsBottom),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: sheetRadius,
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.40)
                      : colors.primary.withValues(alpha: 0.08),
                  offset: const Offset(0, -3),
                  blurRadius: 16,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: sheetRadius,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.glassTint,
                    borderRadius: sheetRadius,
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.10)
                          : Colors.white.withValues(alpha: 0.70),
                      width: 1.0,
                    ),
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: sheetRadius,
                      gradient: isDark
                          ? LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.white.withValues(alpha: 0.14),
                                Colors.white.withValues(alpha: 0.04),
                                Colors.white.withValues(alpha: 0.0),
                              ],
                              stops: const [0.0, 0.03, 0.45],
                            )
                          : LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.white.withValues(alpha: 0.75),
                                Colors.white.withValues(alpha: 0.20),
                                Colors.white.withValues(alpha: 0.0),
                              ],
                              stops: const [0.0, 0.03, 0.45],
                            ),
                    ),
                    child: Directionality(
                      textDirection: TextDirection.rtl,
                      child: Material(
                        color: Colors.transparent,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Apple Grabber
                            Center(
                              child: Container(
                                margin: const EdgeInsets.only(top: 12, bottom: 8),
                                width: 38,
                                height: 4.5,
                                decoration: BoxDecoration(
                                  color: colors.textPrimary.withValues(alpha: isDark ? 0.18 : 0.22),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ),

                            // Header
                            Padding(
                              padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: Text(
                                      'انصراف',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: colors.textSecondary,
                                      ),
                                    ),
                                  ),
                                  Column(
                                    children: [
                                      Text(
                                        title,
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: colors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 1),
                                      Text(
                                        subtitle,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: colors.textSecondary.withValues(alpha: 0.75),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 48), // Balancing spacer
                                ],
                              ),
                            ),
                        const Divider(height: 1),

                        // Form Body
                        Flexible(
                          child: SingleChildScrollView(
                            keyboardDismissBehavior:
                                ScrollViewKeyboardDismissBehavior.onDrag,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 18, vertical: 8),
                            child: formWidget,
                          ),
                        ),

                        // Submit Button
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            18,
                            6,
                            18,
                            hasKeyboard ? 12 : (12 + MediaQuery.of(context).padding.bottom),
                          ),
                          child: SizedBox(
                            width: double.infinity,
                            height: 46,
                            child: ElevatedButton(
                              onPressed: controller.title.trim().isEmpty || controller.isSaving
                                  ? null
                                  : () async {
                                      final success = await controller.save(
                                        context,
                                        allowDelegation: false,
                                      );
                                      if (success) {
                                        if (context.mounted) {
                                          Navigator.pop(context);
                                        }
                                        onSaved();
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: colors.primary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: controller.isSaving
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          'ذخیره $title',
                                          style: const TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        const Icon(Icons.check_rounded,
                                            color: Colors.white, size: 16),
                                      ],
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  },
);
  }
}
