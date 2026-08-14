import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/utils/ritmo_toast.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_card.dart';
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
    final isDark = context.isDark;
    final style = NoteUiHelper.getKindStyle(context, note.kind);
    final relativeDate = NoteUiHelper.formatRelativeDate(note.updatedAt);
    final query = searchQuery ?? '';

    final highlightBg = colors.primary.withValues(alpha: isDark ? 0.35 : 0.22);
    final highlightColor = isDark ? colors.textPrimary : colors.textPrimary;

    final titleTextStyle = Theme.of(context).textTheme.titleSmall?.copyWith(
          color: colors.textPrimary,
          height: 1.35,
        ) ??
        TextStyle(color: colors.textPrimary, height: 1.35);

    final bodyTextStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: colors.textSecondary,
          height: 1.55,
          letterSpacing: note.isPrivate ? 2.5 : 0.0,
        ) ??
        TextStyle(color: colors.textSecondary, height: 1.55);

    final metaTextStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
          color: colors.textTertiary,
        ) ??
        TextStyle(color: colors.textTertiary);

    final int bodyMaxLines = isGrid
        ? math.min(7, math.max(3, (note.body.length / 40).round()))
        : 2;

    final card = RitmoCard(
      margin: EdgeInsets.symmetric(
        vertical: isGrid ? RitmoSpacing.xs : RitmoSpacing.xs + 1,
        horizontal: isGrid ? RitmoSpacing.xs / 2 : 0,
      ),
      padding: const EdgeInsets.all(RitmoSpacing.md),
      borderRadius: BorderRadius.circular(RitmoRadius.card),
      onTap: () async {
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
                  horizontal: RitmoSpacing.sm,
                  vertical: RitmoSpacing.xs - 1,
                ),
                decoration: BoxDecoration(
                  color: style.bgTint,
                  borderRadius: BorderRadius.circular(RitmoRadius.pill),
                  border: Border.all(
                    color: style.accentColor.withValues(alpha: isDark ? 0.3 : 0.2),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(style.icon, size: 12, color: style.accentColor),
                    const SizedBox(width: RitmoSpacing.xs),
                    Text(
                      style.labelFa,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
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
                    color: context.modules.insights,
                  ),
                ),
            ],
          ),
          const SizedBox(height: RitmoSpacing.sm),

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
            const SizedBox(height: RitmoSpacing.xs),
          ],

          // 3. Body
          if (note.isPrivate)
            Text(
              '••••••••••••••••',
              style: bodyTextStyle,
            )
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
          const SizedBox(height: RitmoSpacing.sm),

          // 4. Single-line Metadata: Date + Max 1 indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                relativeDate,
                style: metaTextStyle,
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (note.isPrivate)
                    Padding(
                      padding: const EdgeInsets.only(left: RitmoSpacing.xs),
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
