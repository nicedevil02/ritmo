import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/utils/ritmo_toast.dart';
import 'package:ritmo/core/widgets/ritmo_swipeable_row.dart';
import 'package:ritmo/features/notes/data/notes_repository.dart';
import 'package:ritmo/features/notes/domain/note_models.dart';
import 'package:ritmo/features/notes/presentation/screens/note_editor_screen.dart';
import 'package:ritmo/features/notes/presentation/utils/note_ui_helper.dart';

class NoteCard extends StatelessWidget {
  final Note note;
  final VoidCallback onChanged;
  final bool isGrid;
  final String? searchQuery;

  const NoteCard({
    super.key,
    required this.note,
    required this.onChanged,
    this.isGrid = false,
    this.searchQuery,
  });

  Future<void> _togglePin(BuildContext context) async {
    RitmoHapticsPolicy.selection();
    final newPinned = !note.isPinned;
    if (newPinned) {
      await NotesRepository.instance.pin(note.id);
    } else {
      await NotesRepository.instance.unpin(note.id);
    }
    onChanged();
    if (context.mounted) {
      RitmoToast.show(
        context,
        newPinned ? 'یادداشت سنجاق شد 📌' : 'سنجاق برداشته شد',
      );
    }
  }

  Future<void> _archiveNote(BuildContext context) async {
    RitmoHapticsPolicy.selection();
    await NotesRepository.instance.archive(note.id);
    onChanged();
    if (context.mounted) {
      RitmoToast.show(
        context,
        'یادداشت بایگانی شد 📦',
        actionLabel: 'برگردان',
        onAction: () async {
          await NotesRepository.instance.unarchive(note.id);
          onChanged();
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final style = NoteUiHelper.getKindStyle(context, note.kind);
    final relativeDate = NoteUiHelper.formatRelativeDate(note.updatedAt);
    final query = searchQuery ?? '';

    final highlightBg = colors.accent.withValues(alpha: isDark ? 0.35 : 0.22);
    final highlightColor = isDark ? colors.accent : colors.textPrimary;

    final titleTextStyle = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w800,
      color: colors.textPrimary,
      height: 1.35,
    );

    final bodyTextStyle = TextStyle(
      fontSize: 12.5,
      fontWeight: FontWeight.w500,
      color: colors.textSecondary.withValues(alpha: 0.85),
      height: 1.5,
      letterSpacing: note.isPrivate ? 2.5 : 0.0,
    );

    final metaTextStyle = TextStyle(
      fontSize: 10.5,
      fontWeight: FontWeight.w600,
      color: colors.textTertiary.withValues(alpha: 0.7),
    );

    final int bodyMaxLines = isGrid
        ? math.min(7, math.max(3, (note.body.length / 38).round()))
        : 2;

    final card = Container(
      margin: EdgeInsets.symmetric(
        vertical: isGrid ? 4 : 5,
        horizontal: isGrid ? 2 : 0,
      ),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: isDark ? 0.22 : 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () async {
            RitmoHapticsPolicy.tap();
            await NotesRepository.instance.markOpened(note.id);
            if (!context.mounted) return;
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => NoteEditorScreen(note: note)),
            );
            onChanged();
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Kind Badge & Pinned Indicator Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: style.bgTint,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: style.accentColor.withValues(
                          alpha: isDark ? 0.35 : 0.25,
                        ),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(style.icon, size: 12, color: style.accentColor),
                        const SizedBox(width: 4),
                        Text(
                          style.labelFa,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: style.accentColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (note.isPinned)
                    Transform.rotate(
                      angle: 30 * math.pi / 180,
                      child: Icon(
                        CupertinoIcons.pin_fill,
                        size: 14,
                        color: colors.accent,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),

              // 2. Title
              if (note.title != null && note.title!.trim().isNotEmpty) ...[
                if (query.isNotEmpty)
                  RichText(
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    text: TextSpan(
                      children: NoteUiHelper.buildHighlightedTextSpans(
                        text: note.title!,
                        query: query,
                        baseStyle: titleTextStyle,
                        highlightBg: highlightBg,
                        highlightColor: highlightColor,
                      ),
                    ),
                  )
                else
                  Text(
                    note.title!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: titleTextStyle,
                  ),
                const SizedBox(height: 6),
              ],

              // 3. Body
              if (note.isPrivate)
                Text('••••••••••••••••', style: bodyTextStyle)
              else if (note.body.trim().isNotEmpty) ...[
                if (query.isNotEmpty)
                  RichText(
                    maxLines: bodyMaxLines,
                    overflow: TextOverflow.ellipsis,
                    text: TextSpan(
                      children: NoteUiHelper.buildHighlightedTextSpans(
                        text: note.body,
                        query: query,
                        baseStyle: bodyTextStyle,
                        highlightBg: highlightBg,
                        highlightColor: highlightColor,
                      ),
                    ),
                  )
                else
                  Text(
                    note.body,
                    maxLines: bodyMaxLines,
                    overflow: TextOverflow.ellipsis,
                    style: bodyTextStyle,
                  ),
              ],
              const SizedBox(height: 10),

              // 4. Single-line Metadata: Date + Word count / Lock
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(relativeDate, style: metaTextStyle),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (note.isPrivate)
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Icon(
                            CupertinoIcons.lock_fill,
                            size: 11,
                            color: colors.textTertiary,
                          ),
                        )
                      else if (note.wordCount > 0)
                        Text(
                          '${PersianDigits.convert(note.wordCount.toString())} کلمه',
                          style: metaTextStyle,
                        ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (isGrid) {
      return card;
    }

    return RitmoSwipeableRow(
      itemId: note.id,
      onSwipeComplete: () => _togglePin(context),
      onSwipeManage: () => _archiveNote(context),
      child: card,
    );
  }
}
