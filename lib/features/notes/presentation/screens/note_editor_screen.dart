import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/utils/ritmo_toast.dart';
import 'package:ritmo/core/ux/ritmo_haptics.dart';
import 'package:ritmo/features/notes/data/experience_repository.dart';
import 'package:ritmo/features/notes/data/note_attachment_repository.dart';
import 'package:ritmo/features/notes/data/notes_repository.dart';
import 'package:ritmo/features/notes/domain/capture_context.dart';
import 'package:ritmo/features/notes/domain/note_models.dart';
import 'package:ritmo/features/notes/presentation/utils/note_ui_helper.dart';
import 'package:ritmo/features/notes/presentation/widgets/note_link_tile.dart';
import 'package:shamsi_date/shamsi_date.dart';

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
    _titleController.removeListener(_onContentChanged);
    _bodyController.removeListener(_onContentChanged);
    _lessonController.removeListener(_onContentChanged);
    _titleController.dispose();
    _bodyController.dispose();
    _lessonController.dispose();
    _tagInputController.dispose();
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
    });

    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(const Duration(milliseconds: 1500), () {
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
        if (!isAutosave) {
          RitmoToast.show(context, 'یادداشت با موفقیت ذخیره شد 💾');
        }
      }
    } finally {
      _isSaving = false;
    }
  }

  void _insertMarkdown(String prefix, [String suffix = '']) {
    RitmoHaptics.selection();
    final text = _bodyController.text;
    final selection = _bodyController.selection;
    final start = selection.start >= 0 ? selection.start : text.length;
    final end = selection.end >= 0 ? selection.end : text.length;

    final selectedText = text.substring(start, end);
    final replacement = '$prefix$selectedText$suffix';

    final newText = text.replaceRange(start, end, replacement);
    _bodyController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + prefix.length + selectedText.length),
    );
  }

  void _addTag(String rawTag) {
    final clean = rawTag.replaceAll('#', '').trim();
    if (clean.isEmpty || _tags.contains(clean)) return;
    setState(() {
      _tags.add(clean);
      _tagInputController.clear();
    });
    _onContentChanged();
  }

  void _removeTag(String tag) {
    setState(() {
      _tags.remove(tag);
    });
    _onContentChanged();
  }

  Future<void> _pickAttachment() async {
    if (_activeNote == null) {
      await _save();
      if (_activeNote == null) return;
    }
    final res = await FilePickerPlatform.instance.pickFiles();
    if (res != null && res.files.single.path != null && _activeNote != null) {
      try {
        final att = await NoteAttachmentRepository.instance.add(
          noteId: _activeNote!.id,
          sourceFile: File(res.files.single.path!),
          fileName: res.files.single.name,
        );
        if (mounted) {
          setState(() => _attachments.add(att));
        }
      } catch (e) {
        if (mounted) {
          RitmoToast.show(context, e.toString());
        }
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
        insetPadding: const EdgeInsets.all(12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              InteractiveViewer(
                child: Image.file(file, fit: BoxFit.contain),
              ),
              Container(
                color: Colors.black87,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      att.fileName,
                      style: const TextStyle(color: Colors.white, fontFamily: 'Vazirmatn', fontSize: 12),
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

  void _showKindPickerSheet() {
    RitmoHaptics.selection();
    final colors = context.colors;

    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(RitmoRadius.sheet)),
      ),
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.border.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'نوع یادداشت را انتخاب کنید:',
                style: TextStyle(
                  fontFamily: 'Vazirmatn',
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 14),
              ...NoteKind.values.map((k) {
                final kStyle = NoteUiHelper.getKindStyle(context, k);
                final isSelected = _selectedKind == k && (!_isExperience || k == NoteKind.experience);

                return InkWell(
                  onTap: () {
                    RitmoHaptics.selection();
                    setState(() {
                      _selectedKind = k;
                      _isExperience = k == NoteKind.experience;
                    });
                    _onContentChanged();
                    Navigator.pop(ctx);
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? kStyle.accentColor.withValues(alpha: 0.12) : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected ? kStyle.accentColor : colors.border.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(kStyle.icon, color: kStyle.accentColor, size: 20),
                        const SizedBox(width: 10),
                        Text(
                          '${kStyle.emoji} ${kStyle.labelFa}',
                          style: TextStyle(
                            fontFamily: 'Vazirmatn',
                            fontSize: 13,
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final currentStyle = NoteUiHelper.getKindStyle(context, _isExperience ? NoteKind.experience : _selectedKind);
    final readingTime = NoteUiHelper.calculateReadingTime(_wordCount);

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
        child: Scaffold(
          backgroundColor: colors.background,
          appBar: AppBar(
            backgroundColor: colors.surface,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: colors.textPrimary),
              tooltip: 'ذخیره و بازگشت',
              onPressed: () async {
                RitmoHaptics.confirm();
                final nav = Navigator.of(context);
                await _save();
                if (mounted) nav.pop();
              },
            ),
            title: InkWell(
              onTap: _showKindPickerSheet,
              borderRadius: BorderRadius.circular(RitmoRadius.pill),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: currentStyle.accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(RitmoRadius.pill),
                  border: Border.all(color: currentStyle.accentColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(currentStyle.icon, size: 14, color: currentStyle.accentColor),
                    const SizedBox(width: 6),
                    Text(
                      currentStyle.labelFa,
                      style: TextStyle(
                        fontFamily: 'Vazirmatn',
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: currentStyle.accentColor,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.keyboard_arrow_down, size: 14, color: currentStyle.accentColor),
                  ],
                ),
              ),
            ),
            centerTitle: true,
            actions: [
              IconButton(
                icon: Icon(
                  _isPrivate ? CupertinoIcons.lock_fill : CupertinoIcons.lock,
                  color: _isPrivate ? currentStyle.accentColor : colors.textSecondary,
                  size: 20,
                ),
                tooltip: _isPrivate ? 'یادداشت خصوصی است' : 'یادداشت عمومی است',
                onPressed: () {
                  RitmoHaptics.selection();
                  setState(() => _isPrivate = !_isPrivate);
                  _onContentChanged();
                },
              ),
              if (_activeNote != null) ...[
                IconButton(
                  icon: Icon(Icons.history_rounded, color: colors.textSecondary, size: 22),
                  tooltip: 'تاریخچه نسخه‌ها',
                  onPressed: _showRevisionsSheet,
                ),
                PopupMenuButton<String>(
                  icon: Icon(
                    _activeNote?.reviewAt != null ? CupertinoIcons.bolt_horizontal_circle_fill : CupertinoIcons.bolt_horizontal_circle,
                    color: _activeNote?.reviewAt != null ? const Color(0xFF10B981) : colors.textSecondary,
                    size: 20,
                  ),
                  tooltip: 'مرور فاصله‌دار (SRS)',
                  onSelected: (action) async {
                    RitmoHaptics.selection();
                    if (action == 'add_srs') {
                      final nextReviewMs = DateTime.now().add(const Duration(days: 1)).millisecondsSinceEpoch;
                      await NotesRepository.instance.setReview(_activeNote!.id, 1, nextReviewMs);
                      final fresh = await NotesRepository.instance.getById(_activeNote!.id);
                      if (!mounted) return;
                      setState(() => _activeNote = fresh);
                      RitmoToast.show(context, 'به صف مرور فاصله‌دار اضافه شد 🧠');
                    } else if (action == 'remove_srs') {
                      await NotesRepository.instance.setReview(_activeNote!.id, 0, null);
                      final fresh = await NotesRepository.instance.getById(_activeNote!.id);
                      if (!mounted) return;
                      setState(() => _activeNote = fresh);
                      RitmoToast.show(context, 'از صف مرور فاصله‌دار حذف شد');
                    }
                  },
                  itemBuilder: (ctx) {
                    final isEnrolled = _activeNote?.reviewAt != null;
                    if (!isEnrolled) {
                      return [
                        const PopupMenuItem(
                          value: 'add_srs',
                          child: Row(
                            children: [
                              Icon(Icons.psychology_outlined, size: 16, color: Color(0xFF10B981)),
                              SizedBox(width: 8),
                              Text('افزودن به مرور فاصله‌دار', style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 12)),
                            ],
                          ),
                        ),
                      ];
                    } else {
                      final revDate = _activeNote!.reviewAt!;
                      final j = Jalali.fromDateTime(revDate);
                      final dateStr = '${PersianDigits.convert(j.day.toString())} ${NoteUiHelper.monthName(j.month)}';
                      return [
                        PopupMenuItem(
                          enabled: false,
                          child: Row(
                            children: [
                              const Icon(CupertinoIcons.calendar, size: 16, color: Color(0xFF10B981)),
                              const SizedBox(width: 8),
                              Text('مرور بعدی: $dateStr', style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 12, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'remove_srs',
                          child: Row(
                            children: [
                              Icon(CupertinoIcons.xmark_circle, size: 16, color: Colors.redAccent),
                              SizedBox(width: 8),
                              Text('حذف از مرور فاصله‌دار', style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 12, color: Colors.redAccent)),
                            ],
                          ),
                        ),
                      ];
                    }
                  },
                ),
              ],
              IconButton(
                icon: Icon(
                  _isPinned ? CupertinoIcons.pin_fill : CupertinoIcons.pin,
                  color: _isPinned ? currentStyle.accentColor : colors.textSecondary,
                  size: 20,
                ),
                tooltip: _isPinned ? 'برداشتن سنجاق' : 'سنجاق کردن',
                onPressed: () {
                  RitmoHaptics.selection();
                  setState(() => _isPinned = !_isPinned);
                  _onContentChanged();
                },
              ),
              IconButton(
                icon: Icon(Icons.check, color: colors.primary),
                tooltip: 'ذخیره فوری',
                onPressed: () async {
                  RitmoHaptics.confirm();
                  await _save();
                },
              ),
            ],
          ),
          body: Column(
            children: [
              // Canvas Area
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Context Badge (if logged with context)
                      if (_captureContext != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: colors.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(CupertinoIcons.sparkles, size: 12, color: colors.primary),
                              const SizedBox(width: 6),
                              Text(
                                'ثبت در موقعیت: ${NoteUiHelper.timeOfDayLabelFa(_captureContext!.timeOfDay)}${_captureContext!.energy != null ? ' • انرژی ${PersianDigits.convert(_captureContext!.energy.toString())}/۱۰' : ''}',
                                style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 10, color: colors.primary),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Note Title Field
                      TextField(
                        controller: _titleController,
                        textDirection: TextDirection.rtl,
                        style: TextStyle(
                          fontFamily: 'Vazirmatn',
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: colors.textPrimary,
                          height: 1.3,
                        ),
                        decoration: InputDecoration(
                          hintText: 'عنوان یادداشت...',
                          hintStyle: TextStyle(
                            fontFamily: 'Vazirmatn',
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: colors.textTertiary.withValues(alpha: 0.6),
                          ),
                          border: InputBorder.none,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Golden Wisdom Card Inspector (When isExperience is Active)
                      if (_isExperience) ...[
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFFE5A00D).withValues(alpha: 0.12),
                                colors.card,
                              ],
                              begin: Alignment.topRight,
                              end: Alignment.bottomLeft,
                            ),
                            borderRadius: BorderRadius.circular(RitmoRadius.card),
                            border: Border.all(color: const Color(0xFFE5A00D).withValues(alpha: 0.45)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Text('💡', style: TextStyle(fontSize: 16)),
                                  const SizedBox(width: 8),
                                  Text(
                                    'آموزه کلیدی و درس حاصل از این تجربه',
                                    style: TextStyle(
                                      fontFamily: 'Vazirmatn',
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFFE5A00D),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _lessonController,
                                textDirection: TextDirection.rtl,
                                style: TextStyle(
                                  fontFamily: 'Vazirmatn',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: colors.textPrimary,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'یک جمله درس ماندگار (مثلاً: تصمیم‌گیری در خستگی همیشه اشتباه است)...',
                                  hintStyle: TextStyle(fontFamily: 'Vazirmatn', fontSize: 12, color: colors.textTertiary),
                                  filled: true,
                                  fillColor: colors.surfaceSunken,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  DropdownButton<ExperienceCategory>(
                                    value: _expCategory,
                                    dropdownColor: colors.card,
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
                                          style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 11, color: colors.textPrimary),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                  Row(
                                    children: [
                                      Text('میزان اهمیت: ', style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 11, color: colors.textSecondary)),
                                      ...List.generate(5, (idx) {
                                        final starVal = idx + 1;
                                        return InkWell(
                                          onTap: () {
                                            RitmoHaptics.selection();
                                            setState(() => _expImportance = starVal);
                                            _onContentChanged();
                                          },
                                          child: Padding(
                                            padding: const EdgeInsets.all(2.0),
                                            child: Icon(
                                              starVal <= _expImportance ? CupertinoIcons.star_fill : CupertinoIcons.star,
                                              size: 16,
                                              color: starVal <= _expImportance ? Colors.amber : colors.textTertiary,
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
                        const SizedBox(height: 14),
                      ],

                      // Note Body Field
                      TextField(
                        controller: _bodyController,
                        maxLines: null,
                        minLines: 10,
                        textDirection: TextDirection.rtl,
                        style: TextStyle(
                          fontFamily: 'Vazirmatn',
                          fontSize: 14.5,
                          color: colors.textPrimary,
                          height: 1.7,
                        ),
                        decoration: InputDecoration(
                          hintText: 'شروع به نوشتن متن یا اندیشه‌هایت کن...',
                          hintStyle: TextStyle(
                            fontFamily: 'Vazirmatn',
                            fontSize: 14,
                            color: colors.textTertiary.withValues(alpha: 0.5),
                          ),
                          border: InputBorder.none,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Tags Bar
                      Row(
                        children: [
                          Icon(CupertinoIcons.tag, size: 14, color: currentStyle.accentColor),
                          const SizedBox(width: 6),
                          Text(
                            'برچسب‌ها',
                            style: TextStyle(
                              fontFamily: 'Vazirmatn',
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: colors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          ..._tags.map((t) => Chip(
                                label: Text('#$t', style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 11, color: currentStyle.accentColor)),
                                backgroundColor: currentStyle.accentColor.withValues(alpha: 0.1),
                                onDeleted: () => _removeTag(t),
                                deleteIconColor: currentStyle.accentColor,
                              )),
                          SizedBox(
                            width: 120,
                            child: TextField(
                              controller: _tagInputController,
                              textDirection: TextDirection.rtl,
                              style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 11, color: colors.textPrimary),
                              decoration: InputDecoration(
                                hintText: '+ برچسب جدید',
                                hintStyle: TextStyle(fontFamily: 'Vazirmatn', fontSize: 11, color: colors.textTertiary),
                                border: InputBorder.none,
                                isDense: true,
                              ),
                              onSubmitted: _addTag,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Attachments Section
                      if (_attachments.isNotEmpty) ...[
                        Text(
                          'پیوست‌ها (${PersianDigits.convert(_attachments.length.toString())})',
                          style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 12, fontWeight: FontWeight.bold, color: colors.textPrimary),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _attachments.map((att) {
                            final isImg = att.kind == 'IMAGE';
                            return InkWell(
                              onTap: isImg ? () => _viewImageAttachment(att) : null,
                              borderRadius: BorderRadius.circular(10),
                              child: Chip(
                                avatar: isImg
                                    ? const Icon(CupertinoIcons.photo, size: 16)
                                    : const Icon(CupertinoIcons.doc, size: 16),
                                label: Text(
                                  '${att.fileName} (${PersianDigits.convert((att.fileSizeBytes / 1024).toStringAsFixed(0))} KB)',
                                  style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 11, color: colors.textPrimary),
                                ),
                                onDeleted: () async {
                                  await NoteAttachmentRepository.instance.remove(att.id);
                                  setState(() => _attachments.remove(att));
                                },
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Backlinks Section
                      if (_links.isNotEmpty) ...[
                        Text(
                          'ارتباط‌ها و پیوندها',
                          style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 12, fontWeight: FontWeight.bold, color: colors.textPrimary),
                        ),
                        const SizedBox(height: 6),
                        ..._links.map((link) => NoteLinkTile(link: link)),
                      ],
                    ],
                  ),
                ),
              ),

              // Floating Bottom Action & Formatting Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: colors.surface,
                  border: Border(top: BorderSide(color: colors.border.withValues(alpha: 0.2))),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, -3),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: Row(
                    children: [
                      // Word count & Reading Time Indicator
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${PersianDigits.convert(_wordCount.toString())} کلمه',
                            style: TextStyle(
                              fontFamily: 'Vazirmatn',
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: colors.textPrimary,
                            ),
                          ),
                          Text(
                            _saveStatusText ?? readingTime,
                            style: TextStyle(
                              fontFamily: 'Vazirmatn',
                              fontSize: 9,
                              color: colors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),

                      // Markdown Formatting Shortcuts
                      IconButton(
                        icon: const Icon(Icons.format_bold, size: 19),
                        tooltip: 'Bold',
                        onPressed: () => _insertMarkdown('**', '**'),
                      ),
                      IconButton(
                        icon: const Icon(Icons.title, size: 19),
                        tooltip: 'Heading',
                        onPressed: () => _insertMarkdown('\n## '),
                      ),
                      IconButton(
                        icon: const Icon(Icons.check_box_outlined, size: 19),
                        tooltip: 'Checklist',
                        onPressed: () => _insertMarkdown('\n- [ ] '),
                      ),
                      IconButton(
                        icon: const Icon(Icons.format_list_bulleted, size: 19),
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
    RitmoHaptics.selection();
    final colors = context.colors;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.75),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Sheet Handle
                Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 6),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.textTertiary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  child: Row(
                    children: [
                      Icon(Icons.history_rounded, color: colors.primary, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'تاریخچه نسخه‌های یادداشت',
                        style: TextStyle(
                          fontFamily: 'Vazirmatn',
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: colors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: FutureBuilder<List<NoteRevision>>(
                    future: NotesRepository.instance.listRevisions(_activeNote!.id),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(child: CircularProgressIndicator(color: colors.primary));
                      }
                      final revisions = snapshot.data ?? [];
                      if (revisions.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              'هنوز نسخه‌ای از این یادداشت ثبت نشده است.',
                              style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 13, color: colors.textSecondary),
                            ),
                          ),
                        );
                      }

                      return ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        itemCount: revisions.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
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
                              reasonColor = const Color(0xFF10B981);
                              break;
                            case 'AI_EDIT':
                              reasonLabel = 'ویرایش دستیار';
                              reasonColor = const Color(0xFF8B5CF6);
                              break;
                            case 'RESTORE':
                              reasonLabel = 'بازیابی';
                              reasonColor = const Color(0xFF00B4D8);
                              break;
                            case 'PRE_DELETE':
                              reasonLabel = 'پیش از حذف';
                              reasonColor = Colors.redAccent;
                              break;
                            case 'AUTOSAVE':
                            default:
                              reasonLabel = 'ذخیره خودکار';
                              reasonColor = colors.textSecondary;
                              break;
                          }

                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: colors.surfaceSunken,
                              borderRadius: BorderRadius.circular(12),
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
                                      style: TextStyle(
                                        fontFamily: 'Vazirmatn',
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        color: colors.textPrimary,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: reasonColor.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        reasonLabel,
                                        style: TextStyle(
                                          fontFamily: 'Vazirmatn',
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: reasonColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  rev.body,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: 'Vazirmatn',
                                    fontSize: 12,
                                    color: colors.textSecondary,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '${PersianDigits.convert(rev.wordCount.toString())} کلمه',
                                      style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 10.5, color: colors.textTertiary),
                                    ),
                                    TextButton.icon(
                                      onPressed: () async {
                                        Navigator.pop(ctx);
                                        RitmoHaptics.confirm();
                                        // Save current state as RESTORE before overwriting if body differed
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
                                      label: const Text('بازیابی این نسخه', style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 11)),
                                      style: TextButton.styleFrom(
                                        foregroundColor: colors.primary,
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
              ],
            ),
          ),
        );
      },
    );
  }
}
