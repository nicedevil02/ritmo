import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/utils/ritmo_toast.dart';
import 'package:ritmo/features/simple_tasks/data/task_attachment_repository.dart';
import 'package:ritmo/features/simple_tasks/domain/task_attachment.dart';

class TaskAttachmentsSection extends StatelessWidget {
  const TaskAttachmentsSection({
    super.key,
    required this.taskId,
    required this.attachments,
    required this.onAttachmentsChanged,
  });

  final String taskId;
  final List<TaskAttachment> attachments;
  final VoidCallback onAttachmentsChanged;

  Future<void> _pickAttachment(BuildContext context) async {
    try {
      final result = await FilePickerPlatform.instance.pickFiles();
      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        await TaskAttachmentRepository.instance.add(
          taskId: taskId,
          sourceFile: file,
          fileName: result.files.single.name,
        );
        onAttachmentsChanged();
      }
    } catch (e) {
      if (context.mounted) {
        RitmoToast.show(context, e.toString().replaceAll('Exception: ', ''), icon: Icons.error_outline);
      }
    }
  }

  Future<void> _deleteAttachment(TaskAttachment att) async {
    await TaskAttachmentRepository.instance.delete(att.id);
    onAttachmentsChanged();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'پیوست‌ها (${PersianDigits.toPersian(attachments.length)})',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: colors.textPrimary,
              ),
            ),
            TextButton.icon(
              onPressed: () => _pickAttachment(context),
              icon: const Icon(CupertinoIcons.paperclip, size: 16),
              label: const Text('+ افزودن فایل', style: TextStyle(fontSize: 11)),
            ),
          ],
        ),
        if (attachments.isNotEmpty)
          ...attachments.map(
            (att) => ListTile(
              dense: true,
              leading: const Icon(CupertinoIcons.doc, size: 20),
              title: Text(att.fileName, style: TextStyle(fontSize: 12, color: colors.textPrimary)),
              trailing: IconButton(
                icon: Icon(CupertinoIcons.trash, color: colors.medicalRed, size: 18),
                onPressed: () => _deleteAttachment(att),
              ),
            ),
          ),
      ],
    );
  }
}
