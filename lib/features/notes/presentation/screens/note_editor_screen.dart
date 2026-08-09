import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/ritmo_toast.dart';
import 'package:ritmo/core/ux/ritmo_haptics.dart';
import 'package:ritmo/features/notes/data/experience_repository.dart';
import 'package:ritmo/features/notes/data/note_attachment_repository.dart';
import 'package:ritmo/features/notes/data/notes_repository.dart';
import 'package:ritmo/features/notes/domain/note_models.dart';
import 'package:ritmo/features/notes/presentation/widgets/note_link_tile.dart';

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
  late NoteKind _selectedKind;
  bool _isPinned = false;
  List<NoteAttachment> _attachments = [];
  List<NoteLink> _links = [];
  bool _isExperience = false;

  // Experience Meta
  final TextEditingController _lessonController = TextEditingController();
  ExperienceCategory _expCategory = ExperienceCategory.general;
  int _expImportance = 3;

  Note? _activeNote;

  @override
  void initState() {
    super.initState();
    _activeNote = widget.note;
    _titleController = TextEditingController(text: _activeNote?.title ?? widget.initialTitle ?? '');
    _bodyController = TextEditingController(text: _activeNote?.body ?? widget.initialText ?? '');
    _selectedKind = _activeNote?.kind ?? NoteKind.note;
    _isPinned = _activeNote?.isPinned ?? false;
    _isExperience = _activeNote?.kind == NoteKind.experience || widget.isExperience;

    if (_activeNote != null) {
      _loadDetails();
    }
  }

  Future<void> _loadDetails() async {
    if (_activeNote == null) return;
    final atts = await NoteAttachmentRepository.instance.forNote(_activeNote!.id);
    final links = await NotesRepository.instance.listLinks(_activeNote!.id);
    final exp = await ExperienceRepository.instance.getByNoteId(_activeNote!.id);

    if (mounted) {
      setState(() {
        _attachments = atts;
        _links = links;
        if (exp != null) {
          _isExperience = true;
          _lessonController.text = exp.lesson;
          _expCategory = exp.category;
          _expImportance = exp.importance;
        }
      });
    }
  }

  Future<void> _save() async {
    final titleText = _titleController.text.trim();
    final bodyText = _bodyController.text.trim();
    if (bodyText.isEmpty && titleText.isEmpty) return;

    if (_activeNote == null) {
      final created = await NotesRepository.instance.create(
        title: titleText.isNotEmpty ? titleText : null,
        body: bodyText,
        kind: _isExperience ? NoteKind.experience : _selectedKind,
        isPinned: _isPinned,
        sourceModule: widget.sourceModule,
        sourceEntityId: widget.sourceEntityId,
      );
      _activeNote = created;
    } else {
      final updated = _activeNote!.copyWith(
        title: titleText.isNotEmpty ? titleText : null,
        body: bodyText,
        kind: _isExperience ? NoteKind.experience : _selectedKind,
        isPinned: _isPinned,
      );
      await NotesRepository.instance.update(updated);
    }

    if (_isExperience && _lessonController.text.trim().isNotEmpty) {
      final existingExp = await ExperienceRepository.instance.getByNoteId(_activeNote!.id);
      if (existingExp == null) {
        await ExperienceRepository.instance.createMetaForNote(
          noteId: _activeNote!.id,
          lesson: _lessonController.text.trim(),
          contextText: bodyText,
          category: _expCategory,
          importance: _expImportance,
        );
      } else {
        await ExperienceRepository.instance.update(existingExp.copyWith(
          lesson: _lessonController.text.trim(),
          contextText: bodyText,
          category: _expCategory,
          importance: _expImportance,
        ));
      }
    }

    if (mounted) {
      RitmoToast.show(context, 'یادداشت ذخیره شد 💾');
    }
  }

  Future<void> _pickAttachment() async {
    if (_activeNote == null) {
      await _save();
      if (_activeNote == null) return;
    }
    final res = await FilePicker.pickFiles();
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


  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return PopScope(
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _save();
        if (mounted) Navigator.pop(context);
      },
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: colors.background,
          appBar: AppBar(
            backgroundColor: colors.surface,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.check, color: colors.primary),
              onPressed: () async {
                await _save();
                if (mounted) Navigator.pop(context);
              },
            ),
            title: Text(
              _activeNote == null ? 'یادداشت جدید' : 'ویرایش یادداشت',
              style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 16, fontWeight: FontWeight.bold, color: colors.textPrimary),
            ),
            actions: [
              IconButton(
                icon: Icon(_isPinned ? CupertinoIcons.pin_fill : CupertinoIcons.pin, color: _isPinned ? colors.primary : colors.textSecondary),
                onPressed: () {
                  setState(() => _isPinned = !_isPinned);
                },
              ),
              IconButton(
                icon: Icon(_isExperience ? CupertinoIcons.lightbulb_fill : CupertinoIcons.lightbulb, color: _isExperience ? Colors.amber : colors.textSecondary),
                tooltip: 'تبدیل به تجربه زندگی',
                onPressed: () {
                  setState(() => _isExperience = !_isExperience);
                },
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title Field
                TextField(
                  controller: _titleController,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 18, fontWeight: FontWeight.bold, color: colors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'عنوان یادداشت (اختیاری)...',
                    hintStyle: TextStyle(fontFamily: 'Vazirmatn', fontSize: 16, color: colors.textTertiary),
                    border: InputBorder.none,
                  ),
                ),
                const Divider(),

                // Experience Meta Section (if toggled)
                if (_isExperience) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colors.card,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text('💡', style: TextStyle(fontSize: 16)),
                            const SizedBox(width: 6),
                            Text(
                              'درس/آموزه کلیدی تجربه',
                              style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 12, fontWeight: FontWeight.bold, color: colors.primary),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _lessonController,
                          textDirection: TextDirection.rtl,
                          style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 13, color: colors.textPrimary),
                          decoration: InputDecoration(
                            hintText: 'یک جمله درس/تجربه‌ای که از این اتفاق گرفتی...',
                            hintStyle: TextStyle(fontFamily: 'Vazirmatn', fontSize: 12, color: colors.textTertiary),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            DropdownButton<ExperienceCategory>(
                              value: _expCategory,
                              dropdownColor: colors.card,
                              onChanged: (cat) {
                                if (cat != null) setState(() => _expCategory = cat);
                              },
                              items: ExperienceCategory.values.map((c) {
                                return DropdownMenuItem(
                                  value: c,
                                  child: Text('${c.emoji} ${c.labelFa}', style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 12, color: colors.textPrimary)),
                                );
                              }).toList(),
                            ),
                            Row(
                              children: [
                                Text('میزان اهمیت: ', style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 11, color: colors.textSecondary)),
                                ...List.generate(5, (idx) {
                                  final starVal = idx + 1;
                                  return IconButton(
                                    icon: Icon(
                                      starVal <= _expImportance ? CupertinoIcons.star_fill : CupertinoIcons.star,
                                      size: 16,
                                      color: starVal <= _expImportance ? Colors.amber : colors.textTertiary,
                                    ),
                                    onPressed: () => setState(() => _expImportance = starVal),
                                  );
                                }),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Body Field
                TextField(
                  controller: _bodyController,
                  maxLines: 15,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 14, color: colors.textPrimary, height: 1.5),
                  decoration: InputDecoration(
                    hintText: 'متن یادداشت، ایده‌ها یا متدهای یادگیری...',
                    hintStyle: TextStyle(fontFamily: 'Vazirmatn', fontSize: 13, color: colors.textTertiary),
                    border: InputBorder.none,
                  ),
                ),
                const SizedBox(height: 16),

                // Attachments Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'پیوست‌ها (${_attachments.length})',
                      style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 13, fontWeight: FontWeight.bold, color: colors.textPrimary),
                    ),
                    TextButton.icon(
                      onPressed: _pickAttachment,
                      icon: const Icon(CupertinoIcons.paperclip, size: 16),
                      label: const Text('افزودن فایل', style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 11)),
                    ),
                  ],
                ),
                if (_attachments.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    children: _attachments.map((att) {
                      return Chip(
                        label: Text(att.fileName, style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 11, color: colors.textPrimary)),
                        onDeleted: () async {
                          await NoteAttachmentRepository.instance.remove(att.id);
                          setState(() => _attachments.remove(att));
                        },
                      );
                    }).toList(),
                  ),

                // Backlinks Section
                if (_links.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    'ارتباط‌ها و لینک‌ها',
                    style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 13, fontWeight: FontWeight.bold, color: colors.textPrimary),
                  ),
                  const SizedBox(height: 6),
                  ..._links.map((link) => NoteLinkTile(link: link)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
