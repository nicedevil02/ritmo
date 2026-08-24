import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/utils/ritmo_toast.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_page_scaffold.dart';
import 'package:ritmo/core/widgets/ritmo_sheet_scaffold.dart';
import 'package:ritmo/features/notes/presentation/widgets/ritmo_shimmer.dart';
import 'package:ritmo/features/notes/data/experience_repository.dart';
import 'package:ritmo/features/notes/data/note_attachment_repository.dart';
import 'package:ritmo/features/notes/data/notes_repository.dart';
import 'package:ritmo/features/notes/domain/note_models.dart';
import 'package:ritmo/features/notes/presentation/utils/note_ui_helper.dart';
import 'package:ritmo/features/notes/presentation/widgets/note_link_tile.dart';
import 'package:shamsi_date/shamsi_date.dart';

const Duration _kAutosaveDelay = Duration(milliseconds: 1500);
const Duration _kFocusModeDelay = Duration(milliseconds: 2500);

class NoteEditorScreen extends StatefulWidget {
  final Note? note;
  final String? initialText;
  final String? initialTitle;
  final String? sourceModule;
  final String? sourceEntityId;
  final bool isExperience;
  final NoteKind? initialKind;

  const NoteEditorScreen({
    super.key,
    this.note,
    this.initialText,
    this.initialTitle,
    this.sourceModule,
    this.sourceEntityId,
    this.isExperience = false,
    this.initialKind,
  });

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  late TextEditingController _titleController;
  late TextEditingController _bodyController;
  late TextEditingController _lessonController;
  final TextEditingController _tagInputController = TextEditingController();

  final FocusNode _titleFocusNode = FocusNode();
  final FocusNode _bodyFocusNode = FocusNode();

  late NoteKind _selectedKind;
  bool _isPinned = false;
  bool _isPrivate = false;
  bool _isExperience = false;
  List<NoteAttachment> _attachments = [];
  List<NoteLink> _links = [];
  List<String> _tags = [];

  // Experience Meta
  ExperienceCategory _expCategory = ExperienceCategory.general;
  int _expImportance = 3;

  Note? _activeNote;
  Timer? _autosaveTimer;
  Timer? _focusModeTimer;
  bool _isFocusModeDimmed = false;
  bool _isSaving = false;
  String? _saveStatusText;
  int _wordCount = 0;

  @override
  void initState() {
    super.initState();
    _activeNote = widget.note;
    _titleController = TextEditingController(
      text: _activeNote?.title ?? widget.initialTitle ?? '',
    );
    _bodyController = TextEditingController(
      text:
          _activeNote?.body ??
          widget.initialText ??
          (widget.initialKind == NoteKind.gratitude
              ? 'امروز برای چه چیزهایی شکرگزارم؟\n۱. \n۲. \n۳. '
              : ''),
    );
    _lessonController = TextEditingController();
    _selectedKind =
        _activeNote?.kind ??
        widget.initialKind ??
        (widget.isExperience ? NoteKind.experience : NoteKind.note);
    _isPinned = _activeNote?.isPinned ?? false;
    _isPrivate = _activeNote?.isPrivate ?? false;
    _isExperience =
        _activeNote?.kind == NoteKind.experience ||
        widget.isExperience ||
        _selectedKind == NoteKind.experience;

    _calculateStats();

    _titleController.addListener(_onContentChanged);
    _bodyController.addListener(_onContentChanged);
    _lessonController.addListener(_onContentChanged);

    if (_activeNote != null) {
      _loadDetails();
    }
  }

  @override
  void dispose() {
    _autosaveTimer?.cancel();
    _focusModeTimer?.cancel();
    _titleController.removeListener(_onContentChanged);
    _bodyController.removeListener(_onContentChanged);
    _lessonController.removeListener(_onContentChanged);
    _titleController.dispose();
    _bodyController.dispose();
    _lessonController.dispose();
    _tagInputController.dispose();
    _titleFocusNode.dispose();
    _bodyFocusNode.dispose();
    super.dispose();
  }

  void _calculateStats() {
    final text = _bodyController.text.trim();
    if (text.isEmpty) {
      _wordCount = 0;
    } else {
      _wordCount = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    }
  }

  void _onContentChanged() {
    setState(() {
      _calculateStats();
      _saveStatusText = 'در حال نوشتن...';
      _isFocusModeDimmed = true;
    });

    _focusModeTimer?.cancel();
    _focusModeTimer = Timer(_kFocusModeDelay, () {
      if (mounted) {
        setState(() => _isFocusModeDimmed = false);
      }
    });

    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(_kAutosaveDelay, () {
      if (mounted) {
        _save(isAutosave: true);
      }
    });
  }

  Future<void> _loadDetails() async {
    if (_activeNote == null) return;
    final atts = await NoteAttachmentRepository.instance.forNote(
      _activeNote!.id,
    );
    final links = await NotesRepository.instance.listLinks(_activeNote!.id);
    final exp = await ExperienceRepository.instance.getByNoteId(
      _activeNote!.id,
    );

    List<String> loadedTags = [];
    try {
      final db = await DatabaseHelper.instance.database;
      final tagRows = await db.query(
        'note_tags',
        where: 'noteId = ?',
        whereArgs: [_activeNote!.id],
      );
      loadedTags = tagRows.map((r) => r['tag'] as String).toList();
    } catch (_) {}

    if (mounted) {
      setState(() {
        _attachments = atts;
        _links = links;
        _tags = loadedTags;
        if (exp != null) {
          _isExperience = true;
          _lessonController.text = exp.lesson;
          _expCategory = exp.category;
          _expImportance = exp.importance;
        }
      });
    }
  }

  Future<void> _save({bool isAutosave = false}) async {
    if (_isSaving) return;

    final titleText = _titleController.text.trim();
    final bodyText = _bodyController.text.trim();
    final lessonText = _lessonController.text.trim();

    if (bodyText.isEmpty &&
        titleText.isEmpty &&
        (!_isExperience || lessonText.isEmpty)) {
      return;
    }

    _isSaving = true;
    final effectiveBody = bodyText.isNotEmpty
        ? bodyText
        : (_isExperience ? lessonText : '');

    try {
      if (_activeNote == null) {
        final created = await NotesRepository.instance.create(
          title: titleText.isNotEmpty ? titleText : null,
          body: effectiveBody,
          kind: _isExperience ? NoteKind.experience : _selectedKind,
          isPinned: _isPinned,
          isPrivate: _isPrivate,
          tags: _tags,
          sourceModule: widget.sourceModule,
          sourceEntityId: widget.sourceEntityId,
        );
        _activeNote = created;
      } else {
        final updated = _activeNote!.copyWith(
          title: titleText.isNotEmpty ? titleText : null,
          body: effectiveBody,
          kind: _isExperience ? NoteKind.experience : _selectedKind,
          isPinned: _isPinned,
          isPrivate: _isPrivate,
        );
        await NotesRepository.instance.update(
          updated,
          reason: isAutosave ? 'AUTOSAVE' : 'MANUAL_SAVE',
        );
        await NotesRepository.instance.setTags(_activeNote!.id, _tags);
      }

      // Sync experience metadata
      if (_activeNote != null) {
        if (_isExperience) {
          final effectiveLesson = lessonText.isNotEmpty
              ? lessonText
              : (titleText.isNotEmpty ? titleText : effectiveBody);
          final existingExp = await ExperienceRepository.instance.getByNoteId(
            _activeNote!.id,
          );
          if (existingExp == null) {
            await ExperienceRepository.instance.createMetaForNote(
              noteId: _activeNote!.id,
              lesson: effectiveLesson,
              contextText: effectiveBody,
              category: _expCategory,
              importance: _expImportance,
            );
          } else {
            await ExperienceRepository.instance.update(
              existingExp.copyWith(
                lesson: effectiveLesson,
                contextText: effectiveBody,
                category: _expCategory,
                importance: _expImportance,
              ),
            );
          }
        } else {
          await ExperienceRepository.instance.deleteByNoteId(_activeNote!.id);
        }
      }

      if (mounted) {
        setState(() {
          final now = DateTime.now();
          final hour = PersianDigits.convert(
            now.hour.toString().padLeft(2, '0'),
          );
          final min = PersianDigits.convert(
            now.minute.toString().padLeft(2, '0'),
          );
          _saveStatusText = 'ذخیره شد ✓ $hour:$min';
        });
      }
    } catch (e, st) {
      debugPrint('Save error: $e\n$st');
      if (mounted) {
        setState(() {
          _saveStatusText = 'خطا در ذخیره‌سازی';
        });
      }
    } finally {
      _isSaving = false;
    }
  }

  void _insertMarkdown(String prefix, [String suffix = '']) {
    RitmoHapticsPolicy.selection();
    final text = _bodyController.text;
    final selection = _bodyController.selection;

    if (selection.isValid && !selection.isCollapsed) {
      final selectedText = text.substring(selection.start, selection.end);
      final newText = text.replaceRange(
        selection.start,
        selection.end,
        '$prefix$selectedText$suffix',
      );
      _bodyController.value = TextEditingValue(
        text: newText,
        selection: TextSelection(
          baseOffset: selection.start + prefix.length,
          extentOffset: selection.end + prefix.length,
        ),
      );
    } else {
      final cursorPosition = selection.isValid ? selection.start : text.length;
      final newText = text.replaceRange(
        cursorPosition,
        cursorPosition,
        '$prefix$suffix',
      );
      _bodyController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(
          offset: cursorPosition + prefix.length,
        ),
      );
    }
    _onContentChanged();
  }

  void _addTag(String tag) {
    final clean = tag.trim().replaceAll('#', '');
    if (clean.isEmpty || _tags.contains(clean)) return;
    RitmoHapticsPolicy.selection();
    setState(() {
      _tags.add(clean);
      _tagInputController.clear();
    });
    _onContentChanged();
  }

  void _removeTag(String tag) {
    RitmoHapticsPolicy.selection();
    setState(() {
      _tags.remove(tag);
    });
    _onContentChanged();
  }

  Future<void> _pickAttachment() async {
    RitmoHapticsPolicy.selection();
    try {
      final result = await FilePickerPlatform.instance.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf', 'mp3', 'm4a', 'wav'],
        allowMultiple: false,
      );

      if (result != null &&
          result.files.isNotEmpty &&
          result.files.first.path != null) {
        final pickedFile = File(result.files.first.path!);

        if (_activeNote == null) {
          await _save();
        }

        if (_activeNote != null) {
          final created = await NoteAttachmentRepository.instance.add(
            noteId: _activeNote!.id,
            sourceFile: pickedFile,
            fileName: result.files.first.name,
          );
          setState(() {
            _attachments.add(created);
          });
          if (mounted) {
            RitmoToast.show(context, 'پیوست اضافه شد 📎');
          }
        }
      }
    } catch (e) {
      if (mounted) {
        RitmoToast.show(context, 'خطا در انتخاب فایل');
      }
    }
  }

  Future<void> _viewImageAttachment(NoteAttachment att) async {
    final absPath = await NoteAttachmentRepository.instance.resolveAbsolutePath(
      att.relativePath,
    );
    final file = File(absPath);
    if (!await file.exists() || !mounted) return;

    await showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(RitmoSpacing.md),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(RitmoRadius.card),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              InteractiveViewer(
                child: Image.file(file, cacheWidth: 1080, fit: BoxFit.contain),
              ),
              Container(
                color: Colors.black87,
                padding: const EdgeInsets.symmetric(
                  horizontal: RitmoSpacing.lg,
                  vertical: RitmoSpacing.sm,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      att.fileName,
                      style: Theme.of(
                        ctx,
                      ).textTheme.labelSmall?.copyWith(color: Colors.white),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 20,
                      ),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addSrs() async {
    if (_activeNote == null) return;
    final nextReviewMs = DateTime.now()
        .add(const Duration(days: 1))
        .millisecondsSinceEpoch;
    await NotesRepository.instance.setReview(_activeNote!.id, 1, nextReviewMs);
    final fresh = await NotesRepository.instance.getById(_activeNote!.id);
    if (!mounted) return;
    setState(() => _activeNote = fresh);
    RitmoToast.show(context, 'به صف مرور فاصله‌دار اضافه شد 🧠');
  }

  Future<void> _removeSrs() async {
    if (_activeNote == null) return;
    await NotesRepository.instance.setReview(_activeNote!.id, 0, null);
    final fresh = await NotesRepository.instance.getById(_activeNote!.id);
    if (!mounted) return;
    setState(() => _activeNote = fresh);
    RitmoToast.show(context, 'از صف مرور فاصله‌دار حذف شد');
  }

  void _showKindPickerSheet() {
    RitmoHapticsPolicy.selection();
    final colors = context.colors;

    RitmoSheetScaffold.present(
      context: context,
      title: 'انتخاب نوع یادداشت',
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...NoteKind.values.map((k) {
              final kStyle = NoteUiHelper.getKindStyle(context, k);
              final isSelected =
                  _selectedKind == k &&
                  (!_isExperience || k == NoteKind.experience);

              return InkWell(
                onTap: () {
                  RitmoHapticsPolicy.selection();
                  setState(() {
                    _selectedKind = k;
                    _isExperience = k == NoteKind.experience;
                  });
                  _onContentChanged();
                  Navigator.pop(ctx);
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? kStyle.accentColor.withValues(
                            alpha: context.isDark ? 0.2 : 0.12,
                          )
                        : colors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? kStyle.accentColor : colors.border,
                      width: isSelected ? 1.4 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(kStyle.icon, color: kStyle.accentColor, size: 20),
                      const SizedBox(width: 12),
                      Text(
                        '${kStyle.emoji} ${kStyle.labelFa}',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.w600,
                          color: colors.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      if (isSelected)
                        Icon(
                          Icons.check_circle_rounded,
                          color: kStyle.accentColor,
                          size: 20,
                        ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  void _showMoreActionsSheet() {
    RitmoHapticsPolicy.selection();
    final colors = context.colors;
    final hasSrs = _activeNote?.reviewAt != null;
    final currentStyle = NoteUiHelper.getKindStyle(
      context,
      _isExperience ? NoteKind.experience : _selectedKind,
    );

    RitmoSheetScaffold.present(
      context: context,
      title: 'گزینه‌های یادداشت',
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(currentStyle.icon, color: currentStyle.accentColor),
              title: Text(
                'نوع: ${currentStyle.labelFa}',
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
              trailing: Icon(
                CupertinoIcons.chevron_left,
                size: 14,
                color: colors.textTertiary,
              ),
              onTap: () {
                Navigator.pop(ctx);
                _showKindPickerSheet();
              },
            ),
            ListTile(
              leading: Icon(
                _isPinned ? CupertinoIcons.pin_slash : CupertinoIcons.pin,
                color: colors.textPrimary,
              ),
              title: Text(
                _isPinned ? 'برداشتن سنجاق' : 'سنجاق کردن',
                style: const TextStyle(fontSize: 13.5),
              ),
              onTap: () {
                Navigator.pop(ctx);
                setState(() => _isPinned = !_isPinned);
                _onContentChanged();
              },
            ),
            ListTile(
              leading: Icon(
                _isPrivate ? CupertinoIcons.lock_slash : CupertinoIcons.lock,
                color: colors.textPrimary,
              ),
              title: Text(
                _isPrivate ? 'عمومی کردن' : 'خصوصی کردن',
                style: const TextStyle(fontSize: 13.5),
              ),
              onTap: () {
                Navigator.pop(ctx);
                setState(() => _isPrivate = !_isPrivate);
                _onContentChanged();
              },
            ),
            if (_activeNote != null) ...[
              ListTile(
                leading: Icon(
                  hasSrs
                      ? CupertinoIcons.xmark_circle
                      : Icons.psychology_outlined,
                  color: hasSrs ? colors.error : colors.success,
                ),
                title: Text(
                  hasSrs
                      ? 'خروج از مرور فاصله‌دار'
                      : 'افزودن به مرور فاصله‌دار',
                  style: TextStyle(
                    fontSize: 13.5,
                    color: hasSrs ? colors.error : colors.textPrimary,
                  ),
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  if (hasSrs) {
                    await _removeSrs();
                  } else {
                    await _addSrs();
                  }
                },
              ),
              ListTile(
                leading: Icon(Icons.history_rounded, color: colors.textPrimary),
                title: const Text(
                  'تاریخچه نسخه‌ها',
                  style: TextStyle(fontSize: 13.5),
                ),
                trailing: Icon(
                  CupertinoIcons.chevron_left,
                  size: 14,
                  color: colors.textTertiary,
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _showRevisionsSheet();
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final insightsColor = context.modules.insights;
    final currentStyle = NoteUiHelper.getKindStyle(
      context,
      _isExperience ? NoteKind.experience : _selectedKind,
    );
    final readingTime = NoteUiHelper.calculateReadingTime(_wordCount);
    final keyboardHeight = MediaQuery.viewInsetsOf(context).bottom;
    final isKeyboardOpen = keyboardHeight > 0;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final nav = Navigator.of(context);
        await _save();
        if (mounted) nav.pop();
      },
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: RitmoPageScaffold(
          padding: EdgeInsets.zero,
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(60),
            child: AnimatedOpacity(
              opacity: _isFocusModeDimmed ? 0.2 : 1.0,
              duration: RitmoMotion.state,
              curve: RitmoMotion.enter,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Back Squircle
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () async {
                            RitmoHapticsPolicy.tap();
                            final nav = Navigator.of(context);
                            await _save();
                            if (mounted) nav.pop();
                          },
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: colors.surfaceSunken,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: colors.border,
                                width: 1,
                              ),
                            ),
                            child: Icon(
                              CupertinoIcons.arrow_right,
                              size: 18,
                              color: colors.textPrimary,
                            ),
                          ),
                        ),
                      ),

                      // Kind Badge Pill
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _showKindPickerSheet,
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: currentStyle.accentColor.withValues(
                                alpha: context.isDark ? 0.18 : 0.12,
                              ),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: currentStyle.accentColor.withValues(
                                  alpha: context.isDark ? 0.35 : 0.25,
                                ),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  currentStyle.icon,
                                  size: 14,
                                  color: currentStyle.accentColor,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  currentStyle.labelFa,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: currentStyle.accentColor,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  CupertinoIcons.chevron_down,
                                  size: 11,
                                  color: currentStyle.accentColor,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Right actions
                      Row(
                        children: [
                          if (_saveStatusText != null)
                            Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: Text(
                                _saveStatusText!,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: colors.textTertiary,
                                ),
                              ),
                            ),
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _showMoreActionsSheet,
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: colors.surfaceSunken,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: colors.border,
                                    width: 1,
                                  ),
                                ),
                                child: Icon(
                                  Icons.more_horiz_rounded,
                                  size: 20,
                                  color: colors.textPrimary,
                                ),
                              ),
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
          body: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(
                    14,
                    RitmoSpacing.md,
                    14,
                    RitmoSpacing.md,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Note Title Field
                      TextField(
                        controller: _titleController,
                        focusNode: _titleFocusNode,
                        textDirection: TextDirection.rtl,
                        maxLines: null,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colors.textPrimary,
                              height: 1.3,
                            ),
                        decoration: InputDecoration(
                          hintText: 'عنوان یادداشت...',
                          hintStyle: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colors.textTertiary.withValues(
                                  alpha: 0.4,
                                ),
                              ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const SizedBox(height: RitmoSpacing.lg),

                      // Golden Experience Card (if experience kind)
                      if (_isExperience) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: colors.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: insightsColor.withValues(alpha: 0.5),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: insightsColor.withValues(alpha: 0.08),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.lightbulb_rounded,
                                    color: insightsColor,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'درس کلیدی و ماندگار تجربه',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: insightsColor,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: _lessonController,
                                textDirection: TextDirection.rtl,
                                maxLines: 2,
                                minLines: 1,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: colors.textPrimary,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'یک جمله درس ماندگار...',
                                  hintStyle: TextStyle(
                                    fontSize: 12,
                                    color: colors.textTertiary.withValues(
                                      alpha: 0.6,
                                    ),
                                  ),
                                  filled: true,
                                  fillColor: colors.surfaceSunken,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(
                                      color: colors.border,
                                      width: 1,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(
                                      color: colors.border,
                                      width: 1,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(
                                      color: insightsColor,
                                      width: 1.4,
                                    ),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  DropdownButton<ExperienceCategory>(
                                    value: _expCategory,
                                    dropdownColor: colors.surfaceElevated,
                                    underline: const SizedBox.shrink(),
                                    onChanged: (cat) {
                                      if (cat != null) {
                                        setState(() => _expCategory = cat);
                                        _onContentChanged();
                                      }
                                    },
                                    items: ExperienceCategory.values.map((c) {
                                      return DropdownMenuItem(
                                        value: c,
                                        child: Text(
                                          '${c.emoji} ${c.labelFa}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: colors.textPrimary,
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                  Row(
                                    children: [
                                      Text(
                                        'اهمیت: ',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          color: colors.textSecondary,
                                        ),
                                      ),
                                      ...List.generate(5, (idx) {
                                        final starVal = idx + 1;
                                        return InkWell(
                                          onTap: () {
                                            RitmoHapticsPolicy.selection();
                                            setState(
                                              () => _expImportance = starVal,
                                            );
                                            _onContentChanged();
                                          },
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          child: Padding(
                                            padding: const EdgeInsets.all(3),
                                            child: Icon(
                                              starVal <= _expImportance
                                                  ? CupertinoIcons.star_fill
                                                  : CupertinoIcons.star,
                                              size: 16,
                                              color: starVal <= _expImportance
                                                  ? insightsColor
                                                  : colors.textTertiary
                                                        .withValues(
                                                          alpha: 0.35,
                                                        ),
                                            ),
                                          ),
                                        );
                                      }),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Note Body Field
                      TextField(
                        controller: _bodyController,
                        focusNode: _bodyFocusNode,
                        maxLines: null,
                        minLines: 12,
                        textDirection: TextDirection.rtl,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: colors.textPrimary,
                          height: 1.8,
                        ),
                        decoration: InputDecoration(
                          hintText: 'شروع به نوشتن متن یا اندیشه‌هایت کن...',
                          hintStyle: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: colors.textTertiary.withValues(
                                  alpha: 0.4,
                                ),
                              ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const SizedBox(height: RitmoSpacing.lg),

                      // Tags Bar
                      Row(
                        children: [
                          Icon(
                            CupertinoIcons.tag,
                            size: 14,
                            color: currentStyle.accentColor,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'برچسب‌ها',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: colors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          ..._tags.map(
                            (t) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: colors.primaryContainer,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: colors.primary.withValues(alpha: 0.35),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '#$t',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: currentStyle.accentColor,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  InkWell(
                                    onTap: () => _removeTag(t),
                                    child: Icon(
                                      Icons.close,
                                      size: 12,
                                      color: colors.textTertiary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Container(
                            width: 120,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: colors.surfaceSunken,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: colors.border,
                                width: 1,
                              ),
                            ),
                            child: TextField(
                              controller: _tagInputController,
                              textDirection: TextDirection.rtl,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: colors.textPrimary,
                              ),
                              decoration: InputDecoration(
                                hintText: '+ برچسب...',
                                hintStyle: TextStyle(
                                  fontSize: 11,
                                  color: colors.textTertiary.withValues(
                                    alpha: 0.7,
                                  ),
                                ),
                                border: InputBorder.none,
                                isDense: true,
                              ),
                              onSubmitted: _addTag,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Attachments Section
                      if (_attachments.isNotEmpty) ...[
                        Text(
                          'پیوست‌ها (${PersianDigits.convert(_attachments.length.toString())})',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: Row(
                            children: _attachments.map((att) {
                              final isImg = att.kind == 'IMAGE';
                              if (isImg) {
                                return FutureBuilder<String>(
                                  future: NoteAttachmentRepository.instance
                                      .resolveAbsolutePath(att.relativePath),
                                  builder: (context, snapshot) {
                                    final path = snapshot.data;
                                    return Container(
                                      margin: const EdgeInsets.only(left: 8),
                                      width: 80,
                                      height: 80,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: colors.border,
                                          width: 1,
                                        ),
                                      ),
                                      clipBehavior: Clip.antiAlias,
                                      child: Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          if (path != null &&
                                              File(path).existsSync())
                                            InkWell(
                                              onTap: () =>
                                                  _viewImageAttachment(att),
                                              child: Image.file(
                                                File(path),
                                                cacheWidth: 200,
                                                cacheHeight: 200,
                                                fit: BoxFit.cover,
                                              ),
                                            )
                                          else
                                            const Center(
                                              child: Icon(
                                                CupertinoIcons.photo,
                                                size: 24,
                                              ),
                                            ),
                                          Positioned(
                                            top: 4,
                                            left: 4,
                                            child: InkWell(
                                              onTap: () async {
                                                RitmoHapticsPolicy.selection();
                                                await NoteAttachmentRepository
                                                    .instance
                                                    .remove(att.id);
                                                setState(
                                                  () =>
                                                      _attachments.remove(att),
                                                );
                                              },
                                              child: Container(
                                                padding: const EdgeInsets.all(
                                                  3,
                                                ),
                                                decoration: const BoxDecoration(
                                                  color: Colors.black54,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(
                                                  Icons.close,
                                                  color: Colors.white,
                                                  size: 12,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                );
                              } else {
                                return Container(
                                  margin: const EdgeInsets.only(left: 8),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colors.surfaceSunken,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: colors.border,
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(CupertinoIcons.doc, size: 14),
                                      const SizedBox(width: 4),
                                      Text(
                                        att.fileName,
                                        style: const TextStyle(fontSize: 11.5),
                                      ),
                                      const SizedBox(width: 4),
                                      InkWell(
                                        onTap: () async {
                                          RitmoHapticsPolicy.selection();
                                          await NoteAttachmentRepository
                                              .instance
                                              .remove(att.id);
                                          setState(
                                            () => _attachments.remove(att),
                                          );
                                        },
                                        child: const Icon(
                                          Icons.close,
                                          size: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                      if (_links.isNotEmpty) ...[
                        Text(
                          'پیوندها (${PersianDigits.convert(_links.length.toString())})',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ..._links.map((link) => NoteLinkTile(link: link)),
                        const SizedBox(height: 20),
                      ],
                      const SizedBox(height: 48),
                    ],
                  ),
                ),
              ),

              // Bottom Area
              if (isKeyboardOpen)
                AnimatedContainer(
                  duration: RitmoMotion.press,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    border: Border(
                      top: BorderSide(color: colors.border, width: 1),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: colors.shadow.withValues(
                          alpha: context.isDark ? 0.25 : 0.06,
                        ),
                        blurRadius: 12,
                        offset: const Offset(0, -3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.format_bold, size: 20),
                        tooltip: 'Bold',
                        onPressed: () => _insertMarkdown('**', '**'),
                      ),
                      IconButton(
                        icon: const Icon(Icons.title, size: 20),
                        tooltip: 'Heading',
                        onPressed: () => _insertMarkdown('\n## '),
                      ),
                      IconButton(
                        icon: const Icon(Icons.check_box_outlined, size: 20),
                        tooltip: 'Checklist',
                        onPressed: () => _insertMarkdown('\n- [ ] '),
                      ),
                      IconButton(
                        icon: const Icon(Icons.format_list_bulleted, size: 20),
                        tooltip: 'List',
                        onPressed: () => _insertMarkdown('\n- '),
                      ),
                      IconButton(
                        icon: const Icon(CupertinoIcons.paperclip, size: 18),
                        tooltip: 'افزودن پیوست',
                        onPressed: _pickAttachment,
                      ),
                    ],
                  ),
                )
              else
                AnimatedOpacity(
                  opacity: _isFocusModeDimmed ? 0.2 : 1.0,
                  duration: RitmoMotion.state,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      border: Border(
                        top: BorderSide(color: colors.border, width: 1),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${PersianDigits.convert(_wordCount.toString())} کلمه • $readingTime',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: colors.textTertiary,
                          ),
                        ),
                        if (_saveStatusText != null)
                          Text(
                            _saveStatusText!,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: colors.textTertiary,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showRevisionsSheet() async {
    if (_activeNote == null) return;
    RitmoHapticsPolicy.selection();
    final colors = context.colors;

    await RitmoSheetScaffold.present(
      context: context,
      title: 'تاریخچه نسخه‌های یادداشت',
      maxHeightFactor: 0.75,
      childIsScrollable: true,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: RitmoBreakpoints.sheetMaxHeight(ctx, factor: 0.75),
          ),
          child: FutureBuilder<List<NoteRevision>>(
            future: NotesRepository.instance.listRevisions(_activeNote!.id),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const RitmoShimmerList(count: 3);
              }
              final revisions = snapshot.data ?? [];
              if (revisions.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(RitmoSpacing.xl),
                    child: Text(
                      'هنوز نسخه‌ای از این یادداشت ثبت نشده است.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.symmetric(
                  horizontal: RitmoSpacing.lg,
                  vertical: RitmoSpacing.md,
                ),
                itemCount: revisions.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: RitmoSpacing.sm),
                itemBuilder: (context, idx) {
                  final rev = revisions[idx];
                  final j = Jalali.fromDateTime(rev.createdAt);
                  final hour = PersianDigits.convert(
                    rev.createdAt.hour.toString().padLeft(2, '0'),
                  );
                  final min = PersianDigits.convert(
                    rev.createdAt.minute.toString().padLeft(2, '0'),
                  );
                  final dateStr =
                      '${PersianDigits.convert(j.day.toString())} ${NoteUiHelper.monthName(j.month)} ${PersianDigits.convert(j.year.toString())} • $hour:$min';

                  String reasonLabel;
                  Color reasonColor;
                  switch (rev.reason.toUpperCase()) {
                    case 'MANUAL_SAVE':
                      reasonLabel = 'ذخیره دستی';
                      reasonColor = context.modules.goals;
                      break;
                    case 'AI_EDIT':
                      reasonLabel = 'ویرایش دستیار';
                      reasonColor = context.colors.primary;
                      break;
                    case 'RESTORE':
                      reasonLabel = 'بازیابی';
                      reasonColor = context.modules.study;
                      break;
                    case 'PRE_DELETE':
                      reasonLabel = 'پیش از حذف';
                      reasonColor = context.colors.error;
                      break;
                    case 'AUTOSAVE':
                    default:
                      reasonLabel = 'ذخیره خودکار';
                      reasonColor = colors.textSecondary;
                      break;
                  }

                  return Container(
                    padding: const EdgeInsets.all(RitmoSpacing.md),
                    decoration: BoxDecoration(
                      color: colors.surfaceSunken,
                      borderRadius: BorderRadius.circular(RitmoRadius.card),
                      border: Border.all(
                        color: colors.border.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              dateStr,
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: colors.textPrimary,
                                  ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: RitmoSpacing.sm,
                                vertical: RitmoSpacing.xs / 2,
                              ),
                              decoration: BoxDecoration(
                                color: reasonColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(
                                  RitmoRadius.badge,
                                ),
                              ),
                              child: Text(
                                reasonLabel,
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: reasonColor,
                                    ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: RitmoSpacing.xs),
                        Text(
                          rev.body,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: colors.textSecondary,
                                height: 1.4,
                              ),
                        ),
                        const SizedBox(height: RitmoSpacing.sm),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${PersianDigits.convert(rev.wordCount.toString())} کلمه',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(color: colors.textTertiary),
                            ),
                            TextButton.icon(
                              onPressed: () async {
                                Navigator.pop(ctx);
                                RitmoHapticsPolicy.tap();
                                if (_bodyController.text.trim() !=
                                        rev.body.trim() &&
                                    _activeNote != null) {
                                  await NotesRepository.instance.update(
                                    _activeNote!,
                                    reason: 'RESTORE',
                                  );
                                }
                                _bodyController.text = rev.body;
                                _calculateStats();
                                await _save();
                                if (context.mounted) {
                                  RitmoToast.show(
                                    context,
                                    'نسخه با موفقیت بازیابی شد 🔄',
                                  );
                                }
                              },
                              icon: const Icon(
                                CupertinoIcons.arrow_counterclockwise,
                                size: 13,
                              ),
                              label: Text(
                                'بازیابی این نسخه',
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(color: colors.primary),
                              ),
                              style: TextButton.styleFrom(
                                foregroundColor: colors.primary,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: RitmoSpacing.sm,
                                  vertical: RitmoSpacing.xs,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
