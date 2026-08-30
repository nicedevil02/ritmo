import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:persian_datetime_picker/persian_datetime_picker.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/util/ritmo_date.dart';
import 'package:ritmo/core/util/ritmo_number.dart';
import 'package:ritmo/core/utils/ritmo_date_picker.dart';
import 'package:ritmo/features/study/data/study_repository.dart';
import 'package:ritmo/features/study/domain/study_models.dart';
import 'package:ritmo/features/study/domain/study_stats.dart';
import 'package:uuid/uuid.dart';

class StudyDeadlinesSection extends StatelessWidget {
  const StudyDeadlinesSection({
    super.key,
    required this.deadlines,
    required this.subjects,
    required this.onChanged,
  });

  final List<StudyDeadline> deadlines;
  final List<StudySubject> subjects;
  final VoidCallback onChanged;

  Map<String, StudySubject> get _subjectMap => {for (final s in subjects) s.id: s};

  void _showAddDeadlineSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddDeadlineSheet(
        subjects: subjects,
        onSaved: onChanged,
        initialSubjectId: subjects.length == 1 ? subjects.first.id : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final today = DateTime.now();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.event_note_rounded, size: 20, color: colors.primary),
                const SizedBox(width: 8),
                Text(
                  'امتحانات و ددلاین‌های پیش‌رو',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: colors.textPrimary,
                  ),
                ),
              ],
            ),
            TextButton.icon(
              onPressed: () => _showAddDeadlineSheet(context),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('افزودن', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (deadlines.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.border.withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle_outline_rounded, color: colors.textSecondary, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'امتحان یا تکلیف پیش‌رویی ندارید!',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: colors.textPrimary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'با دکمه افزودن، تاریخ امتحانات نهایی یا ددلاین تمرین‌ها را وارد کنید تا روزشمار هوشمند فعال شود.',
                        style: TextStyle(fontSize: 11, color: colors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        else
          SizedBox(
            height: 120,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: deadlines.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (ctx, index) {
                final d = deadlines[index];
                final sub = d.subjectId != null ? _subjectMap[d.subjectId] : null;
                final daysRem = d.daysRemaining(today);
                final isOverdue = d.isOverdue(today);
                final isToday = d.isToday(today);

                Color badgeColor;
                String badgeText;
                if (isOverdue) {
                  badgeColor = Colors.red;
                  badgeText = 'موعد گذشته';
                } else if (isToday) {
                  badgeColor = Colors.redAccent;
                  badgeText = 'امروز!';
                } else if (daysRem == 1) {
                  badgeColor = Colors.orange;
                  badgeText = 'فردا';
                } else {
                  badgeColor = daysRem <= 3 ? Colors.orange : colors.primary;
                  badgeText = '${RitmoNumber.faInt(daysRem)} روز مانده';
                }

                return Container(
                  width: 230,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: d.priority == DeadlinePriority.high
                          ? Colors.red.withValues(alpha: 0.4)
                          : colors.border.withValues(alpha: 0.6),
                      width: d.priority == DeadlinePriority.high ? 1.5 : 1.0,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: badgeColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              badgeText,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: badgeColor,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: colors.border.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              d.deadlineType.labelFa,
                              style: TextStyle(fontSize: 10, color: colors.textSecondary),
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            d.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: colors.textPrimary,
                            ),
                          ),
                          if (sub != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              '${sub.emoji ?? '📚'} ${sub.name}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 11, color: colors.textSecondary),
                            ),
                          ],
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            StudyDate.formatRelative(d.dueDateIso),
                            style: TextStyle(fontSize: 10, color: colors.textSecondary),
                          ),
                          InkWell(
                            onTap: () async {
                              await StudyRepository.instance.toggleDeadlineCompleted(d.id, true);
                              onChanged();
                            },
                            child: Row(
                              children: [
                                Icon(Icons.check_circle_outline_rounded, size: 14, color: colors.primary),
                                const SizedBox(width: 2),
                                Text(
                                  'انجام شد',
                                  style: TextStyle(fontSize: 10, color: colors.primary, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _AddDeadlineSheet extends StatefulWidget {
  const _AddDeadlineSheet({
    required this.subjects,
    required this.onSaved,
    this.initialSubjectId,
  });

  final List<StudySubject> subjects;
  final VoidCallback onSaved;
  final String? initialSubjectId;

  @override
  State<_AddDeadlineSheet> createState() => _AddDeadlineSheetState();
}

class _AddDeadlineSheetState extends State<_AddDeadlineSheet> {
  final _titleController = TextEditingController();
  final _noteController = TextEditingController();
  String? _selectedSubjectId;
  DeadlineType _selectedType = DeadlineType.exam;
  DeadlinePriority _selectedPriority = DeadlinePriority.medium;
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 7));
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedSubjectId = widget.initialSubjectId;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await RitmoDatePicker.showJalali(
      context: context,
      initialDate: Jalali.fromDateTime(_selectedDate),
      firstDate: Jalali.fromDateTime(now.subtract(const Duration(days: 30))),
      lastDate: Jalali.fromDateTime(now.add(const Duration(days: 365))),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked.toDateTime();
      });
    }
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لطفاً عنوان امتحان یا تکلیف را وارد کنید.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final deadline = StudyDeadline(
        id: const Uuid().v4(),
        subjectId: _selectedSubjectId,
        title: title,
        deadlineType: _selectedType,
        dueDateIso: RitmoDate.dayKey(_selectedDate),
        priority: _selectedPriority,
        note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
        createdAtMs: nowMs,
        updatedAtMs: nowMs,
      );

      await StudyRepository.instance.saveDeadline(deadline);
      if (mounted) {
        Navigator.pop(context);
        widget.onSaved();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا در ذخیره‌سازی: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDark;
    final jalali = Jalali.fromDateTime(_selectedDate);

    return Container(
      constraints: BoxConstraints(
        maxHeight: RitmoBreakpoints.sheetMaxHeight(context, factor: 0.94),
      ),
      decoration: BoxDecoration(
        color: isDark ? colors.surfaceElevated : colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(
          color: isDark ? colors.border.withValues(alpha: 0.35) : colors.border.withValues(alpha: 0.15),
          width: 0.85,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: colors.border.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Symmetrical Header Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Leading (Right in RTL): Circular Tactile Close (X) Button
                GestureDetector(
                  onTap: () {
                    RitmoHapticsPolicy.tap();
                    Navigator.pop(context);
                  },
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: isDark
                          ? colors.surfaceElevated.withValues(alpha: 0.85)
                          : colors.textPrimary.withValues(alpha: 0.07),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark
                            ? colors.border.withValues(alpha: 0.35)
                            : colors.border.withValues(alpha: 0.15),
                        width: 0.85,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      CupertinoIcons.xmark,
                      size: 15,
                      color: colors.textSecondary,
                    ),
                  ),
                ),

                // Center: Title
                Expanded(
                  child: Text(
                    'افزودن امتحان یا تکلیف جدید',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: colors.textPrimary,
                    ),
                  ),
                ),

                // Trailing (Left in RTL): Circular Tactile Save (✔) Button
                GestureDetector(
                  onTap: _isSaving
                      ? null
                      : () {
                          RitmoHapticsPolicy.selection();
                          _save();
                        } ,
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: colors.primary,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(
                            CupertinoIcons.checkmark,
                            size: 16,
                            color: Colors.white,
                          ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Scrollable Content
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                20,
                16,
                20,
                MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'عنوان (مثلاً: امتحان میان‌ترم فیزیک، تمرین سری ۲)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<DeadlineType>(
                    initialValue: _selectedType,
                    decoration: const InputDecoration(
                      labelText: 'نوع رویداد',
                      border: OutlineInputBorder(),
                    ),
                    items: DeadlineType.values.map((t) {
                      return DropdownMenuItem(value: t, child: Text(t.labelFa));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedType = val);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<DeadlinePriority>(
                    initialValue: _selectedPriority,
                    decoration: const InputDecoration(
                      labelText: 'اولویت',
                      border: OutlineInputBorder(),
                    ),
                    items: DeadlinePriority.values.map((p) {
                      return DropdownMenuItem(value: p, child: Text(p.labelFa));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedPriority = val);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (widget.subjects.isNotEmpty) ...[
              DropdownButtonFormField<String?>(
                initialValue: _selectedSubjectId,
                decoration: const InputDecoration(
                  labelText: 'درس مربوطه (اختیاری)',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('بدون درس خاص / عمومی')),
                  ...widget.subjects.map((s) {
                    return DropdownMenuItem(value: s.id, child: Text('${s.emoji ?? '📚'} ${s.name}'));
                  }),
                ],
                onChanged: (val) => setState(() => _selectedSubjectId = val),
              ),
              const SizedBox(height: 14),
            ],
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  border: Border.all(color: colors.border),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.calendar_today_rounded, size: 18, color: colors.primary),
                        const SizedBox(width: 8),
                        Text(
                          'تاریخ موعد:',
                          style: TextStyle(fontSize: 13, color: colors.textSecondary),
                        ),
                      ],
                    ),
                    Text(
                      '${RitmoNumber.faInt(jalali.day)} ${jalali.formatter.mN} ${RitmoNumber.faInt(jalali.year)}',
                      style: TextStyle(fontWeight: FontWeight.bold, color: colors.textPrimary),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _noteController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'توضیحات و بودجه‌بندی (اختیاری)',
                hintText: 'مثلاً: از فصل ۱ تا ۳ کتاب',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isSaving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text(
                      'ثبت امتحان / تکلیف',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                    ),
            ),
          ],
        ),
      ),
    ),
  ],
),
);
}
}
