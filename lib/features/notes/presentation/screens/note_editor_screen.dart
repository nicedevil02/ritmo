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
import 'package:ritmo/features/notes/domain/capture_context.dart';
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

  const NoteEditorScreen({
    super.key,
    this.note,
    this.initialText,
    this.initialTitle,
    this.sourceModule,
    this.sourceEntityId,
    this.isExperience = false,
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
  CaptureContext? _captureContext;

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
    _titleController = TextEditingController(text: _activeNote?.title ?? widget.initialTitle ?? '');
    _bodyController = TextEditingController(text: _activeNote?.body ?? widget.initialText ?? '');
    _lessonController = TextEditingController();
    _selectedKind = _activeNote?.kind ?? (widget.isExperience ? NoteKind.experience : NoteKind.note);
    _isPinned = _activeNote?.isPinned ?? false;
    _isPrivate = _activeNote?.isPrivate ?? false;
    _isExperience = _activeNote?.kind == NoteKind.experience || widget.isExperience;

    _calculateStats();

    if (_activeNote?.captureContextJson != null) {
      _captureContext = CaptureContext.fromJson(_activeNote!.captureContextJson!);
    }

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
    final atts = await NoteAttachmentRepository.instance.forNote(_activeNote!.id);
    final links = await NotesRepository.instance.listLinks(_activeNote!.id);
    final exp = await ExperienceRepository.instance.getByNoteId(_activeNote!.id);

    List<String> loadedTags = [];
    try {
      final db = await DatabaseHelper.instance.database;
      final tagRows = await db.query('note_tags', where: 'noteId = ?', whereArgs: [_activeNote!.id]);
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

    if (bodyText.isEmpty && titleText.isEmpty && (!_isExperience || lessonText.isEmpty)) {
      return;
    }

    _isSaving = true;
    final effectiveBody = bodyText.isNotEmpty ? bodyText : (_isExperience ? lessonText : '');

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
        await NotesRepository.instance.update(updated, reason: isAutosave ? 'AUTOSAVE' : 'MANUAL_SAVE');
        await NotesRepository.instance.setTags(_activeNote!.id, _tags);
      }

      // Sync experience metadata
      if (_activeNote != null) {
        if (_isExperience) {
          final effectiveLesson = lessonText.isNotEmpty ? lessonText : (titleText.isNotEmpty ? titleText : effectiveBody);
          final existingExp = await ExperienceRepository.instance.getByNoteId(_activeNote!.id);
          if (existingExp == null) {
            await ExperienceRepository.instance.createMetaForNote(
              noteId: _activeNote!.id,
              lesson: effectiveLesson,
              contextText: effectiveBody,
              category: _expCategory,
              importance: _expImportance,
            );
          } else {
            await ExperienceRepository.instance.update(existingExp.copyWith(
              lesson: effectiveLesson,
              contextText: effectiveBody,
              category: _expCategory,
              importance: _expImportance,
            ));
          }
        } else {
          await ExperienceRepository.instance.deleteByNoteId(_activeNote!.id);
        }
      }

      if (mounted) {
        setState(() {
          final now = DateTime.now();
          final hour = PersianDigits.convert(now.hour.toString().padLeft(2, '0'));
          final min = PersianDigits.convert(now.minute.toString().padLeft(2, '0'));
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
      final newText = text.replaceRange(selection.start, selection.end, '$prefix$selectedText$suffix');
      _bodyController.value = TextEditingValue(
        text: newText,
        selection: TextSelection(
          baseOffset: selection.start + prefix.length,
          extentOffset: selection.end + prefix.length,
        ),
      );
    } else {
      final cursorPosition = selection.isValid ? selection.start : text.length;
      final newText = text.replaceRange(cursorPosition, cursorPosition, '$prefix$suffix');
      _bodyController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: cursorPosition + prefix.length),
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

      if (result != null && result.files.isNotEmpty && result.files.first.path != null) {
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
    final absPath = await NoteAttachmentRepository.instance.resolveAbsolutePath(att.relativePath);
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
                child: Image.file(file, fit: BoxFit.contain),
              ),
              Container(
                color: Colors.black87,
                padding: const EdgeInsets.symmetric(horizontal: RitmoSpacing.lg, vertical: RitmoSpacing.sm),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      att.fileName,
                      style: Theme.of(ctx).textTheme.labelSmall?.copyWith(color: Colors.white),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white, size: 20),
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
    final nextReviewMs = DateTime.now().add(const Duration(days: 1)).millisecondsSinceEpoch;
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
        padding: const EdgeInsets.all(RitmoSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...NoteKind.values.map((k) {
              final kStyle = NoteUiHelper.getKindStyle(context, k);
              final isSelected = _selectedKind == k && (!_isExperience || k == NoteKind.experience);

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
                borderRadius: BorderRadius.circular(RitmoRadius.card),
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: RitmoSpacing.xs),
                  padding: const EdgeInsets.symmetric(horizontal: RitmoSpacing.md, vertical: RitmoSpacing.sm),
                  decoration: BoxDecoration(
                    color: isSelected ? kStyle.accentColor.withValues(alpha: 0.12) : Colors.transparent,
                    borderRadius: BorderRadius.circular(RitmoRadius.card),
                    border: Border.all(
                      color: isSelected ? kStyle.accentColor : colors.border.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(kStyle.icon, color: kStyle.accentColor, size: 20),
                      const SizedBox(width: RitmoSpacing.md),
                      Text(
                        '${kStyle.emoji} ${kStyle.labelFa}',
                        style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: colors.textPrimary,
                            ),
                      ),
                      const Spacer(),
                      if (isSelected)
                        Icon(Icons.check, color: kStyle.accentColor, size: 18),
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
    final currentStyle = NoteUiHelper.getKindStyle(context, _isExperience ? NoteKind.experience : _selectedKind);

    RitmoSheetScaffold.present(
      context: context,
      title: 'گزینه‌های یادداشت',
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(RitmoSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(currentStyle.icon, color: currentStyle.accentColor),
              title: Text('نوع: ${currentStyle.labelFa}', style: Theme.of(ctx).textTheme.bodyMedium),
              trailing: Icon(CupertinoIcons.chevron_left, size: 14, color: colors.textTertiary),
              onTap: () {
                Navigator.pop(ctx);
                _showKindPickerSheet();
              },
            ),
            ListTile(
              leading: Icon(_isPinned ? CupertinoIcons.pin_slash : CupertinoIcons.pin, color: colors.textPrimary),
              title: Text(_isPinned ? 'برداشتن سنجاق' : 'سنجاق کردن', style: Theme.of(ctx).textTheme.bodyMedium),
              onTap: () {
                Navigator.pop(ctx);
                setState(() => _isPinned = !_isPinned);
                _onContentChanged();
              },
            ),
            ListTile(
              leading: Icon(_isPrivate ? CupertinoIcons.lock_slash : CupertinoIcons.lock, color: colors.textPrimary),
              title: Text(_isPrivate ? 'عمومی کردن' : 'خصوصی کردن', style: Theme.of(ctx).textTheme.bodyMedium),
              onTap: () {
                Navigator.pop(ctx);
                setState(() => _isPrivate = !_isPrivate);
                _onContentChanged();
              },
            ),
            if (_activeNote != null) ...[
              ListTile(
                leading: Icon(
                  hasSrs ? CupertinoIcons.xmark_circle : Icons.psychology_outlined,
                  color: hasSrs ? colors.error : colors.success,
                ),
                title: Text(
                  hasSrs ? 'خروج از مرور فاصله‌دار' : 'افزودن به مرور فاصله‌دار',
                  style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
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
                title: Text('تاریخچه نسخه‌ها', style: Theme.of(ctx).textTheme.bodyMedium),
                trailing: Icon(CupertinoIcons.chevron_left, size: 14, color: colors.textTertiary),
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
    final isDark = context.isDark;
    final currentStyle = NoteUiHelper.getKindStyle(context, _isExperience ? NoteKind.experience : _selectedKind);
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
            preferredSize: const Size.fromHeight(kToolbarHeight),
            child: AnimatedOpacity(
              opacity: _isFocusModeDimmed ? 0.2 : 1.0,
              duration: RitmoMotion.state,
              curve: RitmoMotion.enter,
              child: AppBar(
                backgroundColor: colors.surface,
                elevation: 0,
                leading: IconButton(
                  icon: Icon(Icons.arrow_back, color: colors.textPrimary),
                  tooltip: 'ذخیره و بازگشت',
                  onPressed: () async {
                    RitmoHapticsPolicy.tap();
                    final nav = Navigator.of(context);
                    await _save();
                    if (mounted) nav.pop();
                  },
                ),
                title: const SizedBox.shrink(),
                centerTitle: false,
                actions: [
                  if (_saveStatusText != null)
                    Center(
                      child: AnimatedSwitcher(
                        duration: RitmoMotion.state,
                        child: Text(
                          _saveStatusText!,
                          key: ValueKey(_saveStatusText),
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: colors.textTertiary,
                              ),
                        ),
                      ),
                    ),
                  const SizedBox(width: RitmoSpacing.sm),
                  IconButton(
                    icon: Icon(Icons.more_horiz, color: colors.textPrimary, size: 22),
                    tooltip: 'گزینه‌های یادداشت',
                    onPressed: _showMoreActionsSheet,
                  ),
                  const SizedBox(width: RitmoSpacing.sm),
                ],
              ),
            ),
          ),
          body: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: RitmoSpacing.lg, vertical: RitmoSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_captureContext != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: RitmoSpacing.md, vertical: RitmoSpacing.xs),
                          decoration: BoxDecoration(
                            color: colors.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(RitmoRadius.badge),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(CupertinoIcons.sparkles, size: 12, color: colors.primary),
                              const SizedBox(width: RitmoSpacing.xs),
                              Text(
                                'ثبت در موقعیت: ${NoteUiHelper.timeOfDayLabelFa(_captureContext!.timeOfDay)}${_captureContext!.energy != null ? ' • انرژی ${PersianDigits.convert(_captureContext!.energy.toString())}/۱۰' : ''}',
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                      color: colors.primary,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: RitmoSpacing.md),
                      ],

                      // Note Title Field
                      TextField(
                        controller: _titleController,
                        focusNode: _titleFocusNode,
                        textDirection: TextDirection.rtl,
                        textInputAction: TextInputAction.next,
                        onSubmitted: (_) => _bodyFocusNode.requestFocus(),
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colors.textPrimary,
                              height: 1.3,
                            ),
                        decoration: InputDecoration(
                          hintText: 'عنوان یادداشت...',
                          hintStyle: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colors.textTertiary.withValues(alpha: 0.4),
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
                          padding: const EdgeInsets.all(RitmoSpacing.md),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topRight,
                              end: Alignment.bottomLeft,
                              colors: isDark
                                  ? [context.modules.insights.withValues(alpha: 0.2), colors.surfaceSunken]
                                  : [context.modules.insights.withValues(alpha: 0.12), colors.surface],
                            ),
                            borderRadius: BorderRadius.circular(RitmoRadius.card),
                            border: Border.all(color: context.modules.insights.withValues(alpha: 0.35)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.lightbulb_rounded, color: context.modules.insights, size: 16),
                                  const SizedBox(width: RitmoSpacing.xs),
                                  Text(
                                    'درس کلیدی و ماندگار تجربه',
                                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: context.modules.insights,
                                        ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: RitmoSpacing.sm),
                              TextField(
                                controller: _lessonController,
                                textDirection: TextDirection.rtl,
                                maxLines: 2,
                                minLines: 1,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: colors.textPrimary,
                                    ),
                                decoration: InputDecoration(
                                  hintText: 'یک جمله درس ماندگار (مثلاً: تصمیم‌گیری در خستگی همیشه اشتباه است)...',
                                  hintStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: colors.textTertiary,
                                      ),
                                  filled: true,
                                  fillColor: isDark ? colors.surfaceSunken.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.8),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(RitmoRadius.field),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: RitmoSpacing.md, vertical: RitmoSpacing.sm),
                                ),
                              ),
                              const SizedBox(height: RitmoSpacing.sm),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
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
                                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                              color: colors.textSecondary,
                                            ),
                                      ),
                                      ...List.generate(5, (idx) {
                                        final starVal = idx + 1;
                                        return InkWell(
                                          onTap: () {
                                            RitmoHapticsPolicy.selection();
                                            setState(() => _expImportance = starVal);
                                            _onContentChanged();
                                          },
                                          borderRadius: BorderRadius.circular(RitmoRadius.iconButton),
                                          child: SizedBox(
                                            width: 32,
                                            height: 32,
                                            child: Icon(
                                              starVal <= _expImportance ? CupertinoIcons.star_fill : CupertinoIcons.star,
                                              size: 18,
                                              color: starVal <= _expImportance ? context.modules.insights : colors.textTertiary,
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
                        const SizedBox(height: RitmoSpacing.md),
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
                          hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: colors.textTertiary.withValues(alpha: 0.4),
                              ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const SizedBox(height: RitmoSpacing.lg),

                      // Tags Bar
                      Row(
                        children: [
                          Icon(CupertinoIcons.tag, size: 13, color: currentStyle.accentColor),
                          const SizedBox(width: RitmoSpacing.xs),
                          Text(
                            'برچسب‌ها',
                            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: colors.textPrimary,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: RitmoSpacing.sm),
                      Wrap(
                        spacing: RitmoSpacing.xs + 2,
                        runSpacing: RitmoSpacing.xs + 2,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          ..._tags.map((t) => Chip(
                                label: Text(
                                  '#$t',
                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                        color: currentStyle.accentColor,
                                      ),
                                ),
                                backgroundColor: currentStyle.accentColor.withValues(alpha: 0.1),
                                onDeleted: () => _removeTag(t),
                                deleteIconColor: currentStyle.accentColor,
                              )),
                          SizedBox(
                            width: 120,
                            child: TextField(
                              controller: _tagInputController,
                              textDirection: TextDirection.rtl,
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: colors.textPrimary,
                                  ),
                              decoration: InputDecoration(
                                hintText: '+ برچسب جدید',
                                hintStyle: Theme.of(context).textTheme.labelSmall?.copyWith(
                                      color: colors.textTertiary,
                                    ),
                                border: InputBorder.none,
                                isDense: true,
                              ),
                              onSubmitted: _addTag,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: RitmoSpacing.lg),

                      // Attachments Section
                      if (_attachments.isNotEmpty) ...[
                        Text(
                          'پیوست‌ها (${PersianDigits.convert(_attachments.length.toString())})',
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colors.textPrimary,
                              ),
                        ),
                        const SizedBox(height: RitmoSpacing.sm),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: Row(
                            children: _attachments.map((att) {
                              final isImg = att.kind == 'IMAGE';
                              if (isImg) {
                                return FutureBuilder<String>(
                                  future: NoteAttachmentRepository.instance.resolveAbsolutePath(att.relativePath),
                                  builder: (context, snapshot) {
                                    final path = snapshot.data;
                                    return Container(
                                      margin: const EdgeInsets.only(left: RitmoSpacing.sm),
                                      width: 80,
                                      height: 80,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(RitmoRadius.field),
                                        border: Border.all(color: colors.border.withValues(alpha: 0.2)),
                                      ),
                                      clipBehavior: Clip.antiAlias,
                                      child: Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          if (path != null && File(path).existsSync())
                                            InkWell(
                                              onTap: () => _viewImageAttachment(att),
                                              child: Image.file(File(path), fit: BoxFit.cover),
                                            )
                                          else
                                            const Center(child: Icon(CupertinoIcons.photo, size: 24)),
                                          Positioned(
                                            top: RitmoSpacing.xs,
                                            left: RitmoSpacing.xs,
                                            child: InkWell(
                                              onTap: () async {
                                                RitmoHapticsPolicy.selection();
                                                await NoteAttachmentRepository.instance.remove(att.id);
                                                setState(() => _attachments.remove(att));
                                              },
                                              child: Container(
                                                padding: const EdgeInsets.all(3),
                                                decoration: const BoxDecoration(
                                                  color: Colors.black54,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(Icons.close, color: Colors.white, size: 12),
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
                                  margin: const EdgeInsets.only(left: RitmoSpacing.sm),
                                  child: Chip(
                                    avatar: const Icon(CupertinoIcons.doc, size: 15),
                                    label: Text(
                                      att.fileName,
                                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                            color: colors.textPrimary,
                                          ),
                                    ),
                                    onDeleted: () async {
                                      RitmoHapticsPolicy.selection();
                                      await NoteAttachmentRepository.instance.remove(att.id);
                                      setState(() => _attachments.remove(att));
                                    },
                                  ),
                                );
                              }
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: RitmoSpacing.lg),
                      ],

                      // Backlinks Section
                      if (_links.isNotEmpty) ...[
                        Text(
                          'ارتباط‌ها و پیوندها',
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colors.textPrimary,
                              ),
                        ),
                        const SizedBox(height: RitmoSpacing.xs),
                        ..._links.map((link) => NoteLinkTile(link: link)),
                      ],
                      const SizedBox(height: RitmoSpacing.xxxl),
                    ],
                  ),
                ),
              ),

              // Bottom Area: Floating Toolbar above keyboard OR One-line footer
              if (isKeyboardOpen)
                AnimatedContainer(
                  duration: RitmoMotion.press,
                  padding: const EdgeInsets.symmetric(horizontal: RitmoSpacing.lg, vertical: RitmoSpacing.sm),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    border: Border(top: BorderSide(color: colors.border.withValues(alpha: 0.15))),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, -2),
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
                    padding: const EdgeInsets.symmetric(horizontal: RitmoSpacing.lg, vertical: RitmoSpacing.sm),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      border: Border(top: BorderSide(color: colors.border.withValues(alpha: 0.1))),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${PersianDigits.convert(_wordCount.toString())} کلمه • $readingTime',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: colors.textTertiary,
                              ),
                        ),
                        if (_saveStatusText != null)
                          Text(
                            _saveStatusText!,
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
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
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.6,
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
                padding: const EdgeInsets.symmetric(horizontal: RitmoSpacing.lg, vertical: RitmoSpacing.md),
                itemCount: revisions.length,
                separatorBuilder: (_, _) => const SizedBox(height: RitmoSpacing.sm),
                itemBuilder: (context, idx) {
                  final rev = revisions[idx];
                  final j = Jalali.fromDateTime(rev.createdAt);
                  final hour = PersianDigits.convert(rev.createdAt.hour.toString().padLeft(2, '0'));
                  final min = PersianDigits.convert(rev.createdAt.minute.toString().padLeft(2, '0'));
                  final dateStr = '${PersianDigits.convert(j.day.toString())} ${NoteUiHelper.monthName(j.month)} ${PersianDigits.convert(j.year.toString())} • $hour:$min';

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
                      border: Border.all(color: colors.border.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              dateStr,
                              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: colors.textPrimary,
                                  ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: RitmoSpacing.sm, vertical: RitmoSpacing.xs / 2),
                              decoration: BoxDecoration(
                                color: reasonColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(RitmoRadius.badge),
                              ),
                              child: Text(
                                reasonLabel,
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
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
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: colors.textTertiary,
                                  ),
                            ),
                            TextButton.icon(
                              onPressed: () async {
                                Navigator.pop(ctx);
                                RitmoHapticsPolicy.tap();
                                if (_bodyController.text.trim() != rev.body.trim() && _activeNote != null) {
                                  await NotesRepository.instance.update(_activeNote!, reason: 'RESTORE');
                                }
                                _bodyController.text = rev.body;
                                _calculateStats();
                                await _save();
                                if (context.mounted) {
                                  RitmoToast.show(context, 'نسخه با موفقیت بازیابی شد 🔄');
                                }
                              },
                              icon: const Icon(CupertinoIcons.arrow_counterclockwise, size: 13),
                              label: Text(
                                'بازیابی این نسخه',
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                      color: colors.primary,
                                    ),
                              ),
                              style: TextButton.styleFrom(
                                foregroundColor: colors.primary,
                                padding: const EdgeInsets.symmetric(horizontal: RitmoSpacing.sm, vertical: RitmoSpacing.xs),
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

