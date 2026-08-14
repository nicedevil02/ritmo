import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/utils/ritmo_toast.dart';
import 'package:ritmo/core/ux/ritmo_haptics.dart';
import 'package:ritmo/features/notes/data/notes_repository.dart';
import 'package:ritmo/features/notes/domain/note_models.dart';
import 'package:ritmo/features/notes/presentation/screens/note_editor_screen.dart';
import 'package:ritmo/features/notes/presentation/utils/note_actions.dart';
import 'package:ritmo/features/notes/presentation/utils/note_ui_helper.dart';

class NoteCard extends StatefulWidget {
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

  @override
  State<NoteCard> createState() => _NoteCardState();
}

class _NoteCardState extends State<NoteCard> {
  bool _isPressed = false;

  void _handleDelete(BuildContext context) {
    NoteActions.confirmAndTrash(context, widget.note, widget.onChanged);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final style = NoteUiHelper.getKindStyle(context, widget.note.kind);
    final relativeDate = NoteUiHelper.formatRelativeDate(widget.note.updatedAt);
    final query = widget.searchQuery ?? '';

    final highlightBg = style.accentColor.withValues(alpha: isDark ? 0.35 : 0.22);
    final highlightColor = isDark ? Colors.white : Colors.black87;

    final titleStyle = TextStyle(
      fontFamily: 'Vazirmatn',
      fontSize: 15,
      fontWeight: FontWeight.w600,
      color: colors.textPrimary,
      height: 1.35,
    );

    final bodyStyle = TextStyle(
      fontFamily: 'Vazirmatn',
      fontSize: 13,
      color: colors.textSecondary,
      height: 1.6,
      letterSpacing: widget.note.isPrivate ? 2.5 : 0.0,
    );

    final cardContent = AnimatedScale(
      scale: _isPressed ? 0.97 : 1.0,
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOutCubic,
      child: Container(
        margin: EdgeInsets.symmetric(
          vertical: widget.isGrid ? 4 : 5,
          horizontal: widget.isGrid ? 2 : 0,
        ),
        decoration: BoxDecoration(
          color: isDark
              ? colors.surfaceSunken.withValues(alpha: 0.8)
              : (style.bgTint != colors.primary.withValues(alpha: 0.04) ? style.bgTint : colors.surface),
          borderRadius: BorderRadius.circular(RitmoRadius.card),
          border: Border.all(
            color: widget.note.isPinned
                ? style.accentColor.withValues(alpha: 0.45)
                : colors.border.withValues(alpha: isDark ? 0.18 : 0.12),
            width: widget.note.isPinned ? 1.2 : 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.04),
              blurRadius: 14,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(RitmoRadius.card),
            onTapDown: (_) => setState(() => _isPressed = true),
            onTapCancel: () => setState(() => _isPressed = false),
            onTap: () async {
              setState(() => _isPressed = false);
              RitmoHaptics.selection();
              await NotesRepository.instance.markOpened(widget.note.id);
              if (!context.mounted) return;
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => NoteEditorScreen(note: widget.note)),
              );
              widget.onChanged();
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header: Kind Badge, Privacy lock & Angled Pin & Menu
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: style.accentColor.withValues(alpha: isDark ? 0.18 : 0.12),
                          borderRadius: BorderRadius.circular(RitmoRadius.pill),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(style.icon, size: 11, color: style.accentColor),
                            const SizedBox(width: 4),
                            Text(
                              style.labelFa,
                              style: TextStyle(
                                fontFamily: 'Vazirmatn',
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: style.accentColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      if (widget.note.isPrivate) ...[
                        Icon(CupertinoIcons.lock_fill, size: 12, color: colors.textTertiary),
                        const SizedBox(width: 6),
                      ],
                      if (widget.note.isPinned) ...[
                        Transform.rotate(
                          angle: 30 * math.pi / 180,
                          child: Icon(
                            CupertinoIcons.pin_fill,
                            size: 14,
                            color: style.accentColor,
                          ),
                        ),
                        const SizedBox(width: 4),
                      ],
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: PopupMenuButton<String>(
                          padding: EdgeInsets.zero,
                          icon: Icon(Icons.more_horiz, size: 18, color: colors.textTertiary),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          onSelected: (val) async {
                            RitmoHaptics.selection();
                            if (val == 'pin') {
                              if (widget.note.isPinned) {
                                await NotesRepository.instance.unpin(widget.note.id);
                              } else {
                                await NotesRepository.instance.pin(widget.note.id);
                              }
                              widget.onChanged();
                            } else if (val == 'archive') {
                              await NotesRepository.instance.archive(widget.note.id);
                              if (context.mounted) {
                                RitmoToast.show(
                                  context,
                                  'یادداشت بایگانی شد 📦',
                                  actionLabel: 'برگردان',
                                  onAction: () async {
                                    await NotesRepository.instance.unarchive(widget.note.id);
                                    widget.onChanged();
                                  },
                                );
                              }
                              widget.onChanged();
                            } else if (val == 'delete') {
                              _handleDelete(context);
                            }
                          },
                          itemBuilder: (ctx) => [
                            PopupMenuItem(
                              value: 'pin',
                              child: Row(
                                children: [
                                  Icon(
                                    widget.note.isPinned ? CupertinoIcons.pin_slash : CupertinoIcons.pin,
                                    size: 15,
                                    color: colors.textPrimary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    widget.note.isPinned ? 'برداشتن سنجاق' : 'سنجاق کردن',
                                    style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'archive',
                              child: Row(
                                children: [
                                  Icon(CupertinoIcons.archivebox, size: 15, color: colors.textPrimary),
                                  const SizedBox(width: 8),
                                  const Text('آرشیو', style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 12)),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(CupertinoIcons.trash, size: 15, color: Colors.redAccent),
                                  SizedBox(width: 8),
                                  Text('انتقال به زباله', style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 12, color: Colors.redAccent)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Title (with highlight if search query active)
                  if (widget.note.title != null && widget.note.title!.trim().isNotEmpty) ...[
                    RichText(
                      maxLines: widget.isGrid ? 2 : 1,
                      overflow: TextOverflow.ellipsis,
                      text: TextSpan(
                        children: NoteUiHelper.buildHighlightedTextSpans(
                          text: widget.note.title!,
                          query: query,
                          baseStyle: titleStyle,
                          highlightBg: highlightBg,
                          highlightColor: highlightColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],

                  // Body Excerpt (with highlight if search query active, masked if private)
                  RichText(
                    maxLines: widget.isGrid ? 4 : 2,
                    overflow: TextOverflow.ellipsis,
                    text: TextSpan(
                      children: widget.note.isPrivate
                          ? [TextSpan(text: '••••••••••••', style: bodyStyle)]
                          : NoteUiHelper.buildHighlightedTextSpans(
                              text: widget.note.body,
                              query: query,
                              baseStyle: bodyStyle,
                              highlightBg: highlightBg,
                              highlightColor: highlightColor,
                            ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Footer: Relative date & word count
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        relativeDate,
                        style: TextStyle(
                          fontFamily: 'Vazirmatn',
                          fontSize: 10.5,
                          color: colors.textTertiary,
                        ),
                      ),
                      if (widget.note.wordCount > 0)
                        Text(
                          '${PersianDigits.convert(widget.note.wordCount.toString())} کلمه',
                          style: TextStyle(
                            fontFamily: 'Vazirmatn',
                            fontSize: 10.5,
                            color: colors.textTertiary,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dismissible(
        key: ValueKey('note_card_${widget.note.id}'),
        direction: DismissDirection.horizontal,
        confirmDismiss: (direction) async {
          if (direction == DismissDirection.startToEnd) {
            // Swipe right in RTL -> Toggle Pin
            RitmoHaptics.selection();
            if (widget.note.isPinned) {
              await NotesRepository.instance.unpin(widget.note.id);
            } else {
              await NotesRepository.instance.pin(widget.note.id);
            }
            widget.onChanged();
          } else {
            // Swipe left in RTL -> Archive
            RitmoHaptics.selection();
            await NotesRepository.instance.archive(widget.note.id);
            if (context.mounted) {
              RitmoToast.show(
                context,
                'یادداشت بایگانی شد 📦',
                actionLabel: 'برگردان',
                onAction: () async {
                  await NotesRepository.instance.unarchive(widget.note.id);
                  widget.onChanged();
                },
              );
            }
            widget.onChanged();
          }
          return false; // Snap back smoothly without removing from tree
        },
        background: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          alignment: Alignment.centerRight,
          decoration: BoxDecoration(
            color: style.accentColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(RitmoRadius.card),
          ),
          child: Icon(
            widget.note.isPinned ? CupertinoIcons.pin_slash : CupertinoIcons.pin_fill,
            color: style.accentColor,
            size: 22,
          ),
        ),
        secondaryBackground: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            color: colors.primary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(RitmoRadius.card),
          ),
          child: Icon(CupertinoIcons.archivebox_fill, color: colors.primary, size: 22),
        ),
        child: cardContent,
      ),
    );
  }
}
