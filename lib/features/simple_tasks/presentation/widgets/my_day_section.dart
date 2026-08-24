import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/simple_tasks/domain/simple_task.dart';
import 'package:ritmo/features/simple_tasks/logic/my_day_suggestions.dart';
import 'package:ritmo/features/simple_tasks/presentation/task_strings.dart';

class MyDaySection extends StatefulWidget {
  const MyDaySection({
    super.key,
    required this.tasks,
    required this.suggestions,
    required this.onToggleDone,
    required this.onToggleStar,
    required this.onTaskTap,
    required this.onAddToMyDay,
    required this.onRemoveFromMyDay,
    required this.onNewTask,
    required this.stepCounts,
    required this.attachmentCounts,
  });

  final List<SimpleTask> tasks;
  final List<MyDaySuggestion> suggestions;
  final ValueChanged<SimpleTask> onToggleDone;
  final ValueChanged<SimpleTask> onToggleStar;
  final ValueChanged<SimpleTask> onTaskTap;
  final ValueChanged<SimpleTask> onAddToMyDay;
  final ValueChanged<SimpleTask> onRemoveFromMyDay;
  final VoidCallback onNewTask;
  final Map<String, (int done, int total)> stepCounts;
  final Map<String, int> attachmentCounts;

  @override
  State<MyDaySection> createState() => _MyDaySectionState();
}

class _MyDaySectionState extends State<MyDaySection> {
  bool _suggestionsExpanded = false;

  String _reasonLabel(MyDaySuggestionReason reason) {
    switch (reason) {
      case MyDaySuggestionReason.overdue:
        return TaskStrings.suggestionReasonOverdue;
      case MyDaySuggestionReason.dueToday:
        return TaskStrings.suggestionReasonDueToday;
      case MyDaySuggestionReason.important:
        return TaskStrings.suggestionReasonImportant;
      case MyDaySuggestionReason.dueTomorrow:
        return TaskStrings.suggestionReasonDueTomorrow;
      case MyDaySuggestionReason.fromRoutine:
        return TaskStrings.suggestionReasonFromRoutine;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hasTasks = widget.tasks.isNotEmpty;
    final hasSuggestions = widget.suggestions.isNotEmpty;

    if (!hasTasks && !hasSuggestions) {
      // State C: All clear
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            Icon(CupertinoIcons.sun_max_fill, size: 20, color: colors.accent),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                TaskStrings.myDayEmptyAllClear,
                style: TextStyle(fontSize: 13, color: colors.textSecondary),
              ),
            ),
            TextButton.icon(
              onPressed: widget.onNewTask,
              icon: const Icon(CupertinoIcons.plus, size: 14),
              label: const Text(TaskStrings.newTaskAction, style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(
                foregroundColor: colors.accent,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
            ),
          ],
        ),
      );
    }

    if (!hasTasks && hasSuggestions) {
      // State A: Empty My Day with suggestions
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border.withValues(alpha: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(CupertinoIcons.sparkles, size: 18, color: colors.accent),
                const SizedBox(width: 8),
                Text(
                  TaskStrings.suggestionsTitle,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: colors.textPrimary),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...widget.suggestions.map((s) => _buildSuggestionRow(context, s)),
          ],
        ),
      );
    }

    // State B: Active My Day (has tasks)
    final doneCount = widget.tasks.where((t) => t.isDone).length;
    final totalCount = widget.tasks.length;
    final progressStr = '${PersianDigits.toPersian(doneCount)} از ${PersianDigits.toPersian(totalCount)}';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(CupertinoIcons.sun_max_fill, size: 18, color: colors.accent),
              const SizedBox(width: 8),
              Text(
                TaskStrings.myDayTitle,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: colors.textPrimary),
              ),
              const Spacer(),
              Text(
                progressStr,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...widget.tasks.map((task) => _buildMyDayTaskRow(context, task)),
          if (hasSuggestions) ...[
            const SizedBox(height: 4),
            InkWell(
              onTap: () => setState(() => _suggestionsExpanded = !_suggestionsExpanded),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                child: Row(
                  children: [
                    Icon(
                      _suggestionsExpanded ? CupertinoIcons.chevron_down : CupertinoIcons.chevron_left,
                      size: 14,
                      color: colors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${TaskStrings.suggestionsTitle} (${PersianDigits.toPersian(widget.suggestions.length)})',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colors.accent),
                    ),
                  ],
                ),
              ),
            ),
            if (_suggestionsExpanded) ...[
              const SizedBox(height: 4),
              ...widget.suggestions.map((s) => _buildSuggestionRow(context, s)),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildMyDayTaskRow(BuildContext context, SimpleTask task) {
    final colors = context.colors;
    final stepInfo = widget.stepCounts[task.id];
    final attachmentCount = widget.attachmentCounts[task.id] ?? 0;

    return Dismissible(
      key: ValueKey('my_day_${task.id}'),
      direction: DismissDirection.horizontal,
      onDismissed: (_) => widget.onRemoveFromMyDay(task),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        color: colors.background,
        child: Icon(CupertinoIcons.xmark, size: 18, color: colors.textSecondary),
      ),
      child: InkWell(
        onTap: () => widget.onTaskTap(task),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => widget.onToggleDone(task),
                child: Icon(
                  task.isDone ? CupertinoIcons.checkmark_circle_fill : CupertinoIcons.circle,
                  color: task.isDone ? colors.accent : colors.textSecondary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      task.title,
                      style: TextStyle(
                        fontSize: 13,
                        color: task.isDone ? colors.textSecondary : colors.textPrimary,
                        decoration: task.isDone ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    if ((stepInfo != null && stepInfo.$2 > 0) || attachmentCount > 0 || task.tags.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Wrap(
                        spacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (stepInfo != null && stepInfo.$2 > 0)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(CupertinoIcons.list_bullet, size: 11, color: colors.textTertiary),
                                const SizedBox(width: 2),
                                Text(
                                  '${toPersianDigits(stepInfo.$1)}/${toPersianDigits(stepInfo.$2)}',
                                  style: TextStyle(fontSize: 10, color: colors.textTertiary),
                                ),
                              ],
                            ),
                          if (attachmentCount > 0)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(CupertinoIcons.paperclip, size: 11, color: colors.textTertiary),
                                const SizedBox(width: 2),
                                Text(
                                  toPersianDigits(attachmentCount),
                                  style: TextStyle(fontSize: 10, color: colors.textTertiary),
                                ),
                              ],
                            ),
                          for (final tag in task.tags)
                            Text(
                              '#$tag',
                              style: TextStyle(fontSize: 10, color: colors.primary.withValues(alpha: 0.8)),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => widget.onToggleStar(task),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    task.isImportant ? CupertinoIcons.star_fill : CupertinoIcons.star,
                    size: 18,
                    color: task.isImportant ? const Color(0xFFFFB800) : colors.textSecondary.withValues(alpha: 0.4),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestionRow(BuildContext context, MyDaySuggestion s) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    s.task.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: colors.textPrimary),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _reasonLabel(s.reason),
                    style: TextStyle(fontSize: 10, color: colors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(CupertinoIcons.plus_circle, size: 20),
            color: colors.accent,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: () => widget.onAddToMyDay(s.task),
          ),
        ],
      ),
    );
  }
}
