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
      case 'habits':
        return CupertinoIcons.repeat;
      case 'tasks':
        return CupertinoIcons.checkmark_square_fill;
      case 'sleep':
        return CupertinoIcons.moon_fill;
      case 'energy':
        return CupertinoIcons.bolt_fill;
      case 'health':
        return CupertinoIcons.heart_fill;
      case 'finance':
        return CupertinoIcons.money_dollar_circle_fill;
      default:
        return CupertinoIcons.link;
    }
  }

  String _getModuleLabel(String module) {
    switch (module.toLowerCase()) {
      case 'courses':
      case 'study':
        return 'مطالعه و درس';
      case 'routines':
      case 'habits':
        return 'روتین و عادت';
      case 'tasks':
        return 'وظایف و کارها';
      case 'sleep':
        return 'خواب و استراحت';
      case 'energy':
        return 'سطح انرژی';
      case 'health':
        return 'سلامت';
      case 'finance':
        return 'مالی و بودجه';
      default:
        return module;
    }
  }

  String _getRelationLabel(String relation) {
    switch (relation.toUpperCase()) {
      case 'SPAWNED':
        return 'انتقال‌یافته';
      case 'REFERENCE':
        return 'ارجاع';
      case 'CHILD':
        return 'زیرمجموعه';
      case 'MENTIONS':
        return 'اشاره';
      case 'ABOUT':
        return 'درباره';
      default:
        return relation;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final moduleLabel = _getModuleLabel(link.linkModule);
    final relationLabel = _getRelationLabel(link.relation);
    final shortEntityId = link.linkEntityId.length > 12 ? '${link.linkEntityId.substring(0, 12)}...' : link.linkEntityId;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: colors.border,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(_getModuleIcon(link.linkModule), size: 16, color: colors.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'مرتبط با $moduleLabel ($shortEntityId)',
                style: TextStyle(
                  fontFamily: 'Vazirmatn',
                  fontSize: 12,
                  color: colors.textPrimary,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: colors.primary.withValues(alpha: 0.35),
                  width: 0.8,
                ),
              ),
              child: Text(
                relationLabel,
                style: TextStyle(
                  fontFamily: 'Vazirmatn',
                  fontSize: 10.5,
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
