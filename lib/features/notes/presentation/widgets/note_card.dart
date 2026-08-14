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

  const NoteCard({
    super.key,
    required this.note,
    required this.onChanged,
    this.isGrid = false,
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
    final style = NoteUiHelper.getKindStyle(context, widget.note.kind);
    final relativeDate = NoteUiHelper.formatRelativeDate(widget.note.updatedAt);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: AnimatedScale(
        scale: _isPressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: Container(
          margin: EdgeInsets.symmetric(
            vertical: widget.isGrid ? 4 : 5,
            horizontal: widget.isGrid ? 2 : 0,
          ),
          decoration: BoxDecoration(
            color: style.bgTint,
            borderRadius: BorderRadius.circular(RitmoRadius.card),
            border: Border.all(
              color: widget.note.isPinned
                  ? style.accentColor.withValues(alpha: 0.6)
                  : colors.border.withValues(alpha: 0.25),
              width: widget.note.isPinned ? 1.5 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
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
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header: Kind Badge, Privacy lock & Pin & Menu
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: style.accentColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(style.icon, size: 12, color: style.accentColor),
                              const SizedBox(width: 4),
                              Text(
                                style.labelFa,
                                style: TextStyle(
                                  fontFamily: 'Vazirmatn',
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: style.accentColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        if (widget.note.isPrivate) ...[
                          Icon(CupertinoIcons.lock_fill, size: 13, color: colors.textSecondary),
                          const SizedBox(width: 6),
                        ],
                        if (widget.note.isPinned) ...[
                          Icon(CupertinoIcons.pin_fill, size: 13, color: style.accentColor),
                          const SizedBox(width: 4),
                        ],
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: PopupMenuButton<String>(
                            padding: EdgeInsets.zero,
                            icon: Icon(Icons.more_horiz, size: 18, color: colors.textSecondary),
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
                                child: Text(
                                  widget.note.isPinned ? 'برداشتن سنجاق 📌' : 'سنجاق‌کردن 📌',
                                  style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 12),
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'archive',
                                child: Text('آرشیو 📦', style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 12)),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Text('حذف 🗑️', style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 12, color: Colors.redAccent)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Title
                    if (widget.note.title != null && widget.note.title!.trim().isNotEmpty) ...[
                      Text(
                        widget.note.title!,
                        maxLines: widget.isGrid ? 2 : 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Vazirmatn',
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: colors.textPrimary,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],

                    // Body Excerpt (Masked if private)
                    Text(
                      widget.note.isPrivate ? '••••••••••••' : widget.note.body,
                      maxLines: widget.isGrid ? 4 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Vazirmatn',
                        fontSize: 12,
                        color: colors.textSecondary,
                        height: 1.5,
                        letterSpacing: widget.note.isPrivate ? 2.0 : 0.0,
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
                            fontSize: 10,
                            color: colors.textTertiary,
                          ),
                        ),
                        if (widget.note.wordCount > 0)
                          Text(
                            '${PersianDigits.convert(widget.note.wordCount.toString())} کلمه',
                            style: TextStyle(
                              fontFamily: 'Vazirmatn',
                              fontSize: 10,
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
      ),
    );
  }
}
