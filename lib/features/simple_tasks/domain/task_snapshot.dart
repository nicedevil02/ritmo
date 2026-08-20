import 'package:ritmo/features/simple_tasks/domain/simple_task.dart';
import 'package:ritmo/features/simple_tasks/domain/task_attachment.dart';
import 'package:ritmo/features/simple_tasks/domain/task_step.dart';

class TaskSnapshot {
  final SimpleTask task;
  final List<TaskStep> steps;
  final List<TaskAttachment> attachments;

  const TaskSnapshot({
    required this.task,
    required this.steps,
    required this.attachments,
  });
}
