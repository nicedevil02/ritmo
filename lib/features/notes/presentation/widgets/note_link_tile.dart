import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/notes/domain/note_models.dart';

class NoteLinkTile extends StatelessWidget {
  final NoteLink link;

  const NoteLinkTile({
    super.key,
    required this.link,
  });

  IconData _getModuleIcon(String module) {
    switch (module.toLowerCase()) {
      case 'courses':
      case 'study':
        return CupertinoIcons.book_fill;
      case 'routines':
        return CupertinoIcons.repeat;
      case 'tasks':
        return CupertinoIcons.checkmark_square_fill;
      case 'sleep':
        return CupertinoIcons.moon_fill;
      case 'energy':
        return CupertinoIcons.bolt_fill;
      case 'health':
        return CupertinoIcons.heart_fill;
      default:
        return CupertinoIcons.link;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: colors.surfaceSunken,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: colors.border.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(_getModuleIcon(link.linkModule), size: 16, color: colors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'مرتبط با ${link.linkModule}: ${link.linkEntityId}',
                style: TextStyle(
                  fontFamily: 'Vazirmatn',
                  fontSize: 12,
                  color: colors.textPrimary,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                link.relation,
                style: TextStyle(
                  fontFamily: 'Vazirmatn',
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: colors.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
