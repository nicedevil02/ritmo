import 'package:flutter/material.dart';
import 'package:persian_datetime_picker/persian_datetime_picker.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/util/ritmo_date.dart';
import 'package:ritmo/core/util/ritmo_number.dart';
import 'package:ritmo/core/utils/ritmo_date_picker.dart';
import 'package:ritmo/features/study/data/study_repository.dart';
import 'package:ritmo/features/study/data/study_settings_repository.dart';
import 'package:ritmo/features/study/domain/study_models.dart';
import 'package:uuid/uuid.dart';

class ManualSessionSheet extends StatefulWidget {
  const ManualSessionSheet({super.key, required this.subjects});

  final List<StudySubject> subjects;

  static Future<bool?> show(BuildContext context, {required List<StudySubject> subjects}) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => ManualSessionSheet(subjects: subjects),
    );
  }

  @override
  State<ManualSessionSheet> createState() => _ManualSessionSheetState();
}

class _ManualSessionSheetState extends State<ManualSessionSheet> {
  String? _selectedSubjectId;
  String? _selectedTopicId;
  List<StudyTopic> _availableTopics = [];
  int _durationMinutes = 45;
  DateTime _selectedDate = DateTime.now();
  StudyMode _selectedMode = StudyMode.learn;
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _testsTotalController = TextEditingController();
  final TextEditingController _testsCorrectController = TextEditingController();
  final TextEditingController _testsWrongController = TextEditingController();
  bool _includeTests = false;
  bool _isLoadingTopics = false;

  @override
  void initState() {
    super.initState();
    _selectedSubjectId = widget.subjects.isNotEmpty ? widget.subjects.first.id : null;
    if (_selectedSubjectId != null) {
      _loadTopics();
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    _testsTotalController.dispose();
    _testsCorrectController.dispose();
    _testsWrongController.dispose();
    super.dispose();
  }

  Future<void> _loadTopics() async {
    if (_selectedSubjectId == null || _selectedSubjectId!.isEmpty) return;
    setState(() => _isLoadingTopics = true);
    try {
      final settings = await StudySettingsRepository.instance.load();
      final topics = await StudyRepository.instance.getTopics(
        subjectId: _selectedSubjectId,
        isKonkurMode: settings.konkurMode,
      );
      if (!mounted) return;
      setState(() {
        _availableTopics = topics;
        _selectedTopicId = null;
      });
    } finally {
      if (mounted) setState(() => _isLoadingTopics = false);
    }
  }

  Future<void> _selectDate() async {
    final picked = await RitmoDatePicker.showJalali(
      context: context,
      initialDate: Jalali.fromDateTime(_selectedDate),
      firstDate: Jalali.fromDateTime(DateTime.now().subtract(const Duration(days: 30))),
      lastDate: Jalali.fromDateTime(DateTime.now()),
    );
    if (picked != null && mounted) {
      setState(() => _selectedDate = picked.toDateTime());
    }
  }

  Future<void> _submit() async {
    if (_selectedSubjectId == null || _selectedSubjectId!.isEmpty) return;
    final dateIso = RitmoDate.dayKey(_selectedDate);
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    int total = 0;
    int correct = 0;
    int wrong = 0;
    int empty = 0;
    if (_includeTests) {
      total = int.tryParse(_testsTotalController.text.trim()) ?? 0;
      correct = int.tryParse(_testsCorrectController.text.trim()) ?? 0;
      wrong = int.tryParse(_testsWrongController.text.trim()) ?? 0;
      if (correct + wrong > total) {
        total = correct + wrong;
      }
      empty = (total - correct - wrong) > 0 ? (total - correct - wrong) : 0;
    }

    final session = StudySession(
      id: const Uuid().v4(),
      subjectId: _selectedSubjectId!,
      topicId: _selectedTopicId,
      durationMinutes: _durationMinutes,
      dateIso: dateIso,
      mode: _selectedMode,
      source: 'MANUAL',
      note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
      testsTotal: total,
      testsCorrect: correct,
      testsWrong: wrong,
      testsEmpty: empty,
      createdAtMs: nowMs,
    );

    await StudyRepository.instance.recordSession(session);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final jalali = Jalali.fromDateTime(_selectedDate);
    final dateLabel = '${RitmoNumber.faInt(jalali.day)} ${jalali.formatter.mN} ${RitmoNumber.faInt(jalali.year)}';

    final hasSubjects = widget.subjects.isNotEmpty;

    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('ثبت دستی جلسه مطالعه', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colors.textPrimary)),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ],
          ),
          const SizedBox(height: 16),
          if (!hasSubjects) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: colors.warning.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: colors.warning),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'هنوز درسی تعریف نکرده‌اید. ابتدا از صفحه اصلی یک درس اضافه کنید.',
                      style: TextStyle(fontSize: 12, color: colors.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ] else ...[
            // Subject Dropdown
            DropdownButtonFormField<String>(
              initialValue: _selectedSubjectId,
              decoration: InputDecoration(
                labelText: 'انتخاب درس',
                labelStyle: TextStyle(color: colors.textSecondary),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
              items: widget.subjects.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name, style: const TextStyle()))).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _selectedSubjectId = val);
                  _loadTopics();
                }
              },
            ),
            const SizedBox(height: 12),
            // Topic Dropdown
            DropdownButtonFormField<String?>(
              key: ValueKey('topic_dropdown_${_selectedSubjectId}_$_selectedTopicId'),
              initialValue: _selectedTopicId,
              decoration: InputDecoration(
                labelText: 'انتخاب سرفصل (اختیاری)',
                labelStyle: TextStyle(color: colors.textSecondary),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('مطالعه کل درس (بدون سرفصل خاص)', style: TextStyle(fontStyle: FontStyle.italic)),
                ),
                ..._availableTopics.map(
                  (t) => DropdownMenuItem<String?>(
                    value: t.id,
                    child: Text(t.name),
                  ),
                ),
              ],
              onChanged: _isLoadingTopics
                  ? null
                  : (val) {
                      setState(() => _selectedTopicId = val);
                    },
            ),
            const SizedBox(height: 12),
            // Study Mode Selector
            Text('حالت مطالعه:', style: TextStyle(fontSize: 12, color: colors.textSecondary)),
            const SizedBox(height: 6),
            SegmentedButton<StudyMode>(
              segments: [
                ButtonSegment(value: StudyMode.learn, label: Text(StudyMode.learn.labelFa, style: const TextStyle(fontSize: 11))),
                ButtonSegment(value: StudyMode.practice, label: Text(StudyMode.practice.labelFa, style: const TextStyle(fontSize: 11))),
                ButtonSegment(value: StudyMode.review, label: Text(StudyMode.review.labelFa, style: const TextStyle(fontSize: 11))),
              ],
              selected: {_selectedMode},
              onSelectionChanged: (set) => setState(() => _selectedMode = set.first),
            ),
            const SizedBox(height: 12),
            // Date Row
            ListTile(
              title: const Text('تاریخ جلسه', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              subtitle: Text('$dateLabel (تا ۳۰ روز گذشته قابل ثبت است)', style: TextStyle(fontSize: 11, color: colors.primary)),
              trailing: TextButton.icon(
                onPressed: _selectDate,
                icon: const Icon(Icons.calendar_today_rounded, size: 16),
                label: const Text('تغییر تاریخ', style: TextStyle(fontSize: 12)),
              ),
            ),
            const SizedBox(height: 12),
            // Duration Slider
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('مدت مطالعه (دقیقه)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                Text('${RitmoNumber.faInt(_durationMinutes)} دقیقه', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: colors.primary)),
              ],
            ),
            Slider(
              value: _durationMinutes.toDouble(),
              min: 5, max: 240, divisions: 47,
              activeColor: colors.primary,
              onChanged: (v) => setState(() => _durationMinutes = v.toInt()),
            ),
            const SizedBox(height: 12),
            // Test Tracking Collapsible
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Row(
                  children: [
                    Icon(Icons.checklist_rounded, size: 18, color: _includeTests ? colors.primary : colors.textSecondary),
                    const SizedBox(width: 8),
                    Text(
                      'ثبت عملکرد تستی (اختیاری)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: _includeTests ? colors.primary : colors.textPrimary,
                      ),
                    ),
                  ],
                ),
                trailing: Switch(
                  value: _includeTests,
                  onChanged: (val) => setState(() => _includeTests = val),
                  activeTrackColor: colors.primary.withValues(alpha: 0.5),
                ),
                children: [
                  if (_includeTests) ...[
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _testsTotalController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'تعداد کل تست',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _testsCorrectController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'درست',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _testsWrongController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'غلط',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Session Note
            TextField(
              controller: _noteController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'یادداشت یا نکات این جلسه (اختیاری)',
                hintText: 'مثلاً: حل تست‌های زوج صفحه ۵۴',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('ثبت جلسه', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ],
        ],
      ),
    );
  }
}
