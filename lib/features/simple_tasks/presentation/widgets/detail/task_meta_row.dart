import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_text.dart';
import 'package:ritmo/core/utils/ritmo_toast.dart';
import 'package:ritmo/features/simple_tasks/data/simple_task_repository.dart';
import 'package:ritmo/features/simple_tasks/domain/simple_task.dart';
import 'package:ritmo/features/simple_tasks/logic/my_day_service.dart';
import 'package:ritmo/features/simple_tasks/presentation/task_strings.dart';

class TaskMetaRow extends StatelessWidget {
  const TaskMetaRow({
    super.key,
    required this.task,
    required this.onTaskChanged,
  });

  final SimpleTask task;
  final ValueChanged<SimpleTask> onTaskChanged;

  Future<void> _toggleMyDay(BuildContext context) async {
    if (task.isInMyDay) {
      await MyDayService.instance.removeFromMyDay(task.id);
      final updated = task.copyWith(clearAddedToMyDayAt: true);
      onTaskChanged(updated);
      if (context.mounted) {
        RitmoToast.show(context, TaskStrings.removedFromMyDay);
      }
    } else {
      await MyDayService.instance.addToMyDay(task.id);
      final updated = task.copyWith(addedToMyDayAt: DateTime.now());
      onTaskChanged(updated);
      if (context.mounted) {
        RitmoToast.show(context, TaskStrings.addedToMyDay);
      }
    }
  }

  void _showAddTagDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => RitmoCustomDialog(
        title: 'افزودن تگ',
        icon: Icons.tag_rounded,
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'نام تگ (مثلاً: کار، کتاب)',
            prefixText: '# ',
          ),
        ),
        actions: [
          RitmoSecondaryButton(
            label: 'انصراف',
            onPressed: () => Navigator.pop(ctx),
          ),
          const SizedBox(width: 10),
          RitmoPrimaryButton(
            label: 'افزودن',
            onPressed: () async {
              final raw = controller.text.trim();
              if (raw.isNotEmpty) {
                final clean = normalizeFa(raw.replaceAll('#', '').trim());
                if (clean.isNotEmpty && !task.tags.contains(clean) && task.tags.length < 3) {
                  final newTags = [...task.tags, clean];
                  final updated = task.copyWith(tags: newTags);
                  await SimpleTaskRepository.instance.updateTask(updated);
                  onTaskChanged(updated);
                }
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // My Day Toggle
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _toggleMyDay(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: task.isInMyDay ? colors.primary.withValues(alpha: 0.12) : colors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: task.isInMyDay ? colors.primary.withValues(alpha: 0.4) : colors.border,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  CupertinoIcons.sun_max_fill,
                  size: 18,
                  color: task.isInMyDay ? colors.primary : colors.textTertiary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    task.isInMyDay ? 'در «روز من» قرار دارد' : 'افزودن به «روز من»',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: task.isInMyDay ? FontWeight.bold : FontWeight.normal,
                      color: task.isInMyDay ? colors.primary : colors.textPrimary,
                    ),
                  ),
                ),
                Icon(
                  task.isInMyDay ? CupertinoIcons.checkmark : CupertinoIcons.add,
                  size: 16,
                  color: task.isInMyDay ? colors.primary : colors.textTertiary,
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Tags Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'تگ‌ها',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: colors.textPrimary,
              ),
            ),
            if (task.tags.length < 3)
              TextButton.icon(
                onPressed: () => _showAddTagDialog(context),
                icon: const Icon(CupertinoIcons.tag, size: 14),
                label: const Text('+ افزودن تگ', style: TextStyle(fontSize: 11)),
              ),
          ],
        ),
        if (task.tags.isNotEmpty)
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: task.tags.map((tag) {
              return Chip(
                label: Text('#$tag', style: const TextStyle(fontSize: 11)),
                backgroundColor: colors.surface,
                deleteIcon: const Icon(CupertinoIcons.clear, size: 12),
                onDeleted: () async {
                  final newTags = task.tags.where((t) => t != tag).toList();
                  final updated = task.copyWith(tags: newTags);
                  await SimpleTaskRepository.instance.updateTask(updated);
                  onTaskChanged(updated);
                },
              );
            }).toList(),
          ),
      ],
    );
  }
}
