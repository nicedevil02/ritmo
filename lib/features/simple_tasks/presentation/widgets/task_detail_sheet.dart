import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ritmo/core/logging/ritmo_logger.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/utils/ritmo_toast.dart';
import 'package:ritmo/core/ux/ritmo_haptics.dart';
import 'package:ritmo/features/simple_tasks/data/simple_task_repository.dart';
import 'package:ritmo/features/simple_tasks/data/task_preferences.dart';
import 'package:ritmo/features/simple_tasks/data/task_step_repository.dart';
import 'package:ritmo/features/simple_tasks/domain/simple_task.dart';
import 'package:ritmo/features/simple_tasks/domain/task_attachment.dart';
import 'package:ritmo/features/simple_tasks/domain/task_step.dart';
import 'package:ritmo/features/simple_tasks/presentation/widgets/detail/task_attachments_section.dart';
import 'package:ritmo/features/simple_tasks/presentation/widgets/detail/task_meta_row.dart';
import 'package:ritmo/features/simple_tasks/presentation/widgets/detail/task_note_field.dart';
import 'package:ritmo/features/simple_tasks/presentation/widgets/detail/task_schedule_row.dart';
import 'package:ritmo/features/simple_tasks/presentation/widgets/task_step_list.dart';
import 'package:shamsi_date/shamsi_date.dart';

class TaskDetailSheet extends StatefulWidget {
  const TaskDetailSheet({
    super.key,
    required this.task,
    required this.onTaskUpdated,
    required this.onTaskDeleted,
  });

  final SimpleTask task;
  final VoidCallback onTaskUpdated;
  final VoidCallback onTaskDeleted;

  static Future<void> show(
    BuildContext context, {
    required SimpleTask task,
    required VoidCallback onTaskUpdated,
    required VoidCallback onTaskDeleted,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => TaskDetailSheet(
        task: task,
        onTaskUpdated: onTaskUpdated,
        onTaskDeleted: onTaskDeleted,
      ),
    );
  }

  @override
  State<TaskDetailSheet> createState() => _TaskDetailSheetState();
}

class _TaskDetailSheetState extends State<TaskDetailSheet> {
  late SimpleTask _task;
  late TextEditingController _titleController;
  late TextEditingController _noteController;
  List<TaskStep> _steps = [];
  List<TaskAttachment> _attachments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _task = widget.task;
    _titleController = TextEditingController(text: _task.title);
    _noteController = TextEditingController(text: _task.note ?? '');
    _loadData();
  }

  @override
  void dispose() {
    _savePendingChanges();
    _titleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _savePendingChanges() {
    final newTitle = _titleController.text.trim();
    final newNote = _noteController.text.trim();
    if ((newTitle.isNotEmpty && newTitle != _task.title) || newNote != (_task.note ?? '')) {
      final updated = _task.copyWith(
        title: newTitle.isNotEmpty ? newTitle : _task.title,
        note: newNote.isNotEmpty ? newNote : null,
      );
      SimpleTaskRepository.instance.updateTask(updated);
      widget.onTaskUpdated();
    }
  }

  Future<void> _loadData() async {
    try {
      final steps = await TaskStepRepository.instance.forTask(_task.id);
      final attachments = await TaskAttachmentRepository.instance.forTask(_task.id);
      if (mounted) setState(() { _steps = steps; _attachments = attachments; _isLoading = false; });
    } catch (e, st) {
      RitmoLog.warning('TaskDetailSheet', 'Failed to load task details', e, st);
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleDone() async {
    final newDone = !_task.isDone;
    if (newDone) {
      RitmoHaptics.tap();
      final soundEnabled = await TaskPreferences.isCompletionSoundEnabled();
      if (soundEnabled) await SystemSound.play(SystemSoundType.click);
    }
    await SimpleTaskRepository.instance.setDone(_task.id, done: newDone);
    setState(() => _task = _task.copyWith(isDone: newDone, doneAt: newDone ? DateTime.now() : null));
    widget.onTaskUpdated();
  }

  Future<void> _toggleStar() async {
    RitmoHaptics.tap();
    final newStar = !_task.isImportant;
    await SimpleTaskRepository.instance.setImportant(_task.id, important: newStar);
    setState(() => _task = _task.copyWith(isImportant: newStar, importantAt: newStar ? DateTime.now() : null));
    widget.onTaskUpdated();
  }

  Future<void> _confirmAndDeleteTask() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.colors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('حذف کار؟', style: TextStyle(color: context.colors.medicalRed, fontSize: 16, fontWeight: FontWeight.bold)),
        content: Text('کار «${_task.title}» حذف شود؟', style: TextStyle(color: context.colors.textSecondary, fontSize: 13, height: 1.5)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('انصراف', style: TextStyle(color: context.colors.textSecondary))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('حذف', style: TextStyle(color: context.colors.medicalRed, fontWeight: FontWeight.bold))),
        ],
      ),
    );
    if (confirm != true) return;

    final snapshot = await SimpleTaskRepository.instance.delete(_task.id);
    if (mounted) Navigator.pop(context);
    widget.onTaskDeleted();

    if (mounted && snapshot != null) {
      RitmoToast.show(
        context,
        'کار «${snapshot.task.title}» حذف شد',
        icon: CupertinoIcons.trash,
        actionLabel: 'برگردان',
        onAction: () async {
          await SimpleTaskRepository.instance.restoreTask(snapshot);
          widget.onTaskUpdated();
        },
      );
    }
  }

  String _formatDate(DateTime dt) {
    final j = Jalali.fromDateTime(dt);
    return '${PersianDigits.toPersian(j.year)}/${PersianDigits.toPersian(j.month.toString().padLeft(2, '0'))}/${PersianDigits.toPersian(j.day.toString().padLeft(2, '0'))}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      expand: false,
      snap: true,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: colors.border),
          ),
          child: _isLoading
              ? Center(child: CircularProgressIndicator(color: colors.primary))
              : ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4.5,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(color: colors.textTertiary.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(3)),
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(_task.isDone ? CupertinoIcons.checkmark_circle_fill : CupertinoIcons.circle, color: _task.isDone ? colors.success : colors.textTertiary, size: 26),
                          onPressed: _toggleDone,
                        ),
                        Expanded(
                          child: TextField(
                            controller: _titleController,
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _task.isDone ? colors.textTertiary : colors.textPrimary, decoration: _task.isDone ? TextDecoration.lineThrough : null),
                            decoration: const InputDecoration(border: InputBorder.none, hintText: 'عنوان کار...'),
                            onEditingComplete: () {
                              final updated = _task.copyWith(title: _titleController.text.trim());
                              SimpleTaskRepository.instance.updateTask(updated);
                              setState(() => _task = updated);
                              widget.onTaskUpdated();
                            },
                          ),
                        ),
                        IconButton(
                          icon: Icon(_task.isImportant ? CupertinoIcons.star_fill : CupertinoIcons.star, color: _task.isImportant ? colors.accent : colors.textTertiary, size: 24),
                          onPressed: _toggleStar,
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    TaskMetaRow(task: _task, onTaskChanged: (t) { setState(() => _task = t); widget.onTaskUpdated(); }),
                    const Divider(height: 24),
                    TaskScheduleRow(task: _task, onTaskChanged: (t) { setState(() => _task = t); widget.onTaskUpdated(); }),
                    const Divider(height: 24),
                    Text('زیرگام‌ها', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: colors.textPrimary)),
                    const SizedBox(height: 8),
                    TaskStepList(taskId: _task.id, steps: _steps, onStepsChanged: _loadData),
                    const Divider(height: 24),
                    TaskNoteField(
                      task: _task,
                      controller: _noteController,
                      onChanged: () {
                        final updated = _task.copyWith(note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim());
                        SimpleTaskRepository.instance.updateTask(updated);
                        setState(() => _task = updated);
                        widget.onTaskUpdated();
                      },
                    ),
                    const Divider(height: 24),
                    TaskAttachmentsSection(taskId: _task.id, attachments: _attachments, onAttachmentsChanged: _loadData),
                    const Divider(height: 24),
                    Text('ساخته‌شده: ${_formatDate(_task.createdAt)}', style: TextStyle(fontSize: 11, color: colors.textTertiary)),
                    if (_task.doneAt != null) Text('انجام‌شده: ${_formatDate(_task.doneAt!)}', style: TextStyle(fontSize: 11, color: colors.success)),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: colors.medicalRed, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                      onPressed: _confirmAndDeleteTask,
                      icon: const Icon(CupertinoIcons.trash, size: 18),
                      label: const Text('حذف کار', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
        );
      },
    );
  }
}
