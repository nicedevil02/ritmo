import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/notes/logic/promote_to_note.dart';
import 'package:ritmo/features/simple_tasks/domain/simple_task.dart';
import 'package:url_launcher/url_launcher.dart';

class TaskNoteField extends StatelessWidget {
  const TaskNoteField({
    super.key,
    required this.task,
    required this.controller,
    required this.onChanged,
  });

  final SimpleTask task;
  final TextEditingController controller;
  final VoidCallback onChanged;

  Widget _buildNoteWithLinks(String noteText, BuildContext context) {
    final colors = context.colors;
    final linkOrPhonePattern = RegExp(r'(https?:\/\/[^\s]+)|(www\.[^\s]+)|(\+?\d{10,13}|09\d{9})');
    final matches = linkOrPhonePattern.allMatches(noteText);

    if (matches.isEmpty) {
      return Text(
        noteText,
        style: TextStyle(fontSize: 13, color: colors.textPrimary, height: 1.5),
      );
    }

    final spans = <TextSpan>[];
    int lastMatchEnd = 0;

    for (final match in matches) {
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(
          text: noteText.substring(lastMatchEnd, match.start),
          style: TextStyle(color: colors.textPrimary),
        ));
      }
      final matchedText = match.group(0)!;
      final isPhone = RegExp(r'^\+?\d+$').hasMatch(matchedText);

      spans.add(TextSpan(
        text: matchedText,
        style: TextStyle(color: colors.primary, decoration: TextDecoration.underline),
        recognizer: TapGestureRecognizer()
          ..onTap = () async {
            if (isPhone) {
              final phoneUri = Uri.tryParse('tel:$matchedText');
              if (phoneUri != null) {
                await launchUrl(phoneUri, mode: LaunchMode.externalApplication);
              }
            } else {
              var urlStr = matchedText;
              if (!urlStr.startsWith('http')) urlStr = 'https://$urlStr';
              final uri = Uri.tryParse(urlStr);
              if (uri != null) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            }
          },
      ));
      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < noteText.length) {
      spans.add(TextSpan(
        text: noteText.substring(lastMatchEnd),
        style: TextStyle(color: colors.textPrimary),
      ));
    }

    return SelectableText.rich(
      TextSpan(
        style: TextStyle(fontSize: 13, height: 1.5, color: colors.textPrimary),
        children: spans,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'یادداشت',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: 3,
          style: TextStyle(fontSize: 13, color: colors.textPrimary),
          decoration: InputDecoration(
            hintText: 'توضیحات و لینک‌های مرتبط…',
            hintStyle: TextStyle(fontSize: 12, color: colors.textTertiary),
            filled: true,
            fillColor: colors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: colors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: colors.border),
            ),
          ),
          onChanged: (_) => onChanged(),
        ),
        if (controller.text.isNotEmpty) ...[
          const SizedBox(height: 6),
          _buildNoteWithLinks(controller.text, context),
          const SizedBox(height: 8),
          if (controller.text.length > 300)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: colors.primary.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'این یادداشت بلند شده — می‌خواهی به دفترچه منتقلش کنی؟',
                      style: TextStyle(fontSize: 11, color: colors.primary),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      NotePromoter.instance.promote(
                        context: context,
                        module: 'tasks',
                        entityId: task.id,
                        text: controller.text,
                        titleHint: task.title,
                      );
                    },
                    icon: const Text('📓', style: TextStyle(fontSize: 14)),
                    label: const Text('انتقال به دفترچه', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            )
          else
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () {
                  NotePromoter.instance.promote(
                    context: context,
                    module: 'tasks',
                    entityId: task.id,
                    text: controller.text,
                    titleHint: task.title,
                  );
                },
                icon: const Text('📓', style: TextStyle(fontSize: 14)),
                label: const Text('تبدیل به یادداشت دفترچه', style: TextStyle(fontSize: 11)),
              ),
            ),
        ],
      ],
    );
  }
}
