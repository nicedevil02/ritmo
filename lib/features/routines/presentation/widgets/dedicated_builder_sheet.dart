// lib/features/routines/presentation/widgets/dedicated_builder_sheet.dart

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
      builder: (_) => DedicatedBuilderSheet(
        title: title,
        subtitle: subtitle,
        controller: controller,
        formWidget: formWidget,
        onSaved: onSaved,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return RitmoFormSheetScaffold(
          title: title,
          subtitle: subtitle,
          icon: '✨',
          isDirty: controller.isDirty,
          isSubmitting: controller.isSaving,
          saveLabel: 'ذخیره',
          onSave: controller.title.trim().isEmpty || controller.isSaving
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
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                top: 10,
                left: 16,
                right: 16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  formWidget,
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
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
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(Icons.check_rounded, color: Colors.white, size: 18),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
