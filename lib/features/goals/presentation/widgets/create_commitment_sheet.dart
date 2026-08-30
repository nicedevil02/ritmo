import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:ritmo/core/time/ritmo_clock.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/utils/ritmo_toast.dart';
import 'package:ritmo/features/goals/logic/planning_repository.dart';
import 'package:ritmo/features/goals/logic/planning_week.dart';
import 'package:ritmo/features/goals/models/planning_models.dart';

/// شیت ورود اطلاعات و ثبت تعهد جدید برای افق‌های سه‌گانه (امروز / هفته / ماه)
class CreateCommitmentSheet extends StatefulWidget {
  const CreateCommitmentSheet({
    super.key,
    this.initialHorizon = PlanningHorizon.week,
    this.initialDayKey,
    required this.onSaved,
  });

  final PlanningHorizon initialHorizon;
  final String? initialDayKey;
  final VoidCallback onSaved;

  static void show(
    BuildContext context, {
    PlanningHorizon initialHorizon = PlanningHorizon.week,
    String? initialDayKey,
    required VoidCallback onSaved,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CreateCommitmentSheet(
        initialHorizon: initialHorizon,
        initialDayKey: initialDayKey,
        onSaved: onSaved,
      ),
    );
  }

  @override
  State<CreateCommitmentSheet> createState() => _CreateCommitmentSheetState();
}

class _CreateCommitmentSheetState extends State<CreateCommitmentSheet> {
  final TextEditingController _titleController = TextEditingController();
  late PlanningHorizon _horizon;
  int _effortMinutes = 60;
  CommitmentImportance _importance = CommitmentImportance.should;
  WorkKind _workKind = WorkKind.light;
  late String _selectedDayKey;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _horizon = widget.initialHorizon;
    final now = DateTime.now();
    _selectedDayKey = widget.initialDayKey ?? DayKey.from(now).value;
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _saveCommitment() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      RitmoToast.show(context, 'لطفاً عنوان تعهد را وارد کنید.');
      return;
    }

    setState(() => _isSaving = true);
    final repo = PlanningRepository.instance;
    final now = DateTime.now();
    final nowMs = now.millisecondsSinceEpoch;

    try {
      // 1. Find or create active cycle for this horizon
      var cycle = await repo.activeCycle(_horizon, _selectedDayKey);
      if (cycle == null) {
        final weekDays = PlanningWeek.dayKeysOfWeekContaining(now);
        final jNow = Jalali.fromDateTime(now);
        final startDayKey = _horizon == PlanningHorizon.month
            ? DayKey.from(Jalali(jNow.year, jNow.month, 1).toDateTime()).value
            : weekDays.first;
        final endDayKey = _horizon == PlanningHorizon.month
            ? DayKey.from(Jalali(jNow.year, jNow.month, jNow.monthLength).toDateTime()).value
            : weekDays.last;

        final draft = await repo.createDraft(
          horizon: _horizon,
          startDayKey: startDayKey,
          endDayKey: endDayKey,
          title: _horizon == PlanningHorizon.month ? 'برنامهٔ ماه' : 'برنامهٔ هفته',
          nowMs: nowMs,
        );
        cycle = await repo.activate(draft, nowMs: nowMs);
      }

      // 2. Create commitment
      final commitmentId = 'comm_${DateTime.now().microsecondsSinceEpoch}';
      final commitment = PlanningCommitment(
        id: commitmentId,
        cycleId: cycle.id,
        title: title,
        sourceType: CommitmentSourceType.manual,
        importance: _importance,
        effortMinutes: _effortMinutes,
        workKind: _workKind,
        status: CommitmentStatus.accepted,
        createdAt: nowMs,
        updatedAt: nowMs,
      );

      await repo.upsertCommitment(commitment);

      // 3. If horizon is Day or Week, create allocation for the target day
      if (_horizon != PlanningHorizon.month) {
        final alloc = PlanningAllocation(
          id: 'alloc_${commitmentId}_$_selectedDayKey',
          commitmentId: commitmentId,
          dayKey: _horizon == PlanningHorizon.day ? DayKey.from(now).value : _selectedDayKey,
          plannedMinutes: _effortMinutes,
          idempotencyKey: 'idmp_${commitmentId}_$_selectedDayKey',
          status: AllocationStatus.planned,
          createdAt: nowMs,
          updatedAt: nowMs,
        );
        await repo.insertAllocation(alloc);
      }

      if (!mounted) return;
      Navigator.pop(context);
      widget.onSaved();
      RitmoToast.show(context, 'تعهد با موفقیت اضافه شد ✨');
    } catch (e) {
      debugPrint('[CreateCommitmentSheet] error: $e');
      if (mounted) RitmoToast.show(context, 'خطا در ثبت تعهد ❌');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isGlass = context.isGlassEnabled;
    final weekDays = PlanningWeek.dayKeysOfWeekContaining(DateTime.now());

    return RitmoFormSheetScaffold(
      title: 'کار یا برنامهٔ جدید',
      subtitle: 'برای امروز، این هفته یا این ماه برنامه‌ریزی کنید',
      icon: '🎯',
      isDirty: _titleController.text.trim().isNotEmpty,
      isSubmitting: _isSaving,
      initialChildSize: 0.94,
      maxChildSize: 0.94,
      snapSizes: const [0.0, 0.94],
      saveLabel: 'ثبت',
      onSave: _saveCommitment,
      builder: (context, scrollController) {
        return SingleChildScrollView(
          controller: scrollController,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            top: 14,
            left: 16,
            right: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Horizon Picker
              CupertinoSlidingSegmentedControl<PlanningHorizon>(
                groupValue: _horizon,
                thumbColor: colors.primary,
                backgroundColor: isGlass
                    ? colors.surfaceSunken.withValues(alpha: 0.5)
                    : colors.card,
                children: {
                  PlanningHorizon.day: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      'امروز',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: _horizon == PlanningHorizon.day ? FontWeight.bold : FontWeight.normal,
                        color: _horizon == PlanningHorizon.day ? Colors.white : colors.textPrimary,
                      ),
                    ),
                  ),
                  PlanningHorizon.week: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      'این هفته',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: _horizon == PlanningHorizon.week ? FontWeight.bold : FontWeight.normal,
                        color: _horizon == PlanningHorizon.week ? Colors.white : colors.textPrimary,
                      ),
                    ),
                  ),
                  PlanningHorizon.month: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      'این ماه',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: _horizon == PlanningHorizon.month ? FontWeight.bold : FontWeight.normal,
                        color: _horizon == PlanningHorizon.month ? Colors.white : colors.textPrimary,
                      ),
                    ),
                  ),
                },
                onValueChanged: (val) {
                  if (val != null) setState(() => _horizon = val);
                },
              ),

              const SizedBox(height: 16),

              // 2. Title Field
              TextField(
                controller: _titleController,
                autofocus: true,
                style: TextStyle(
                  fontSize: 14,
                  color: colors.textPrimary,
                ),
                decoration: InputDecoration(
                  labelText: 'چه کاری می‌خواهی انجام دهی؟',
                  labelStyle: TextStyle(
                    fontSize: 13,
                    color: colors.textSecondary,
                  ),
                  hintText: 'مثلاً: مطالعهٔ فصل ۳، ورزش، پیگیری کار اداری...',
                  hintStyle: TextStyle(
                    fontSize: 12,
                    color: colors.textSecondary.withValues(alpha: 0.5),
                  ),
                  filled: true,
                  fillColor: isGlass
                      ? colors.surfaceSunken.withValues(alpha: 0.4)
                      : colors.card,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: colors.border.withValues(alpha: 0.3)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: colors.border.withValues(alpha: 0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: colors.primary),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // 3. Duration Selector
              Text(
                'چقدر وقت می‌برد؟',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [15, 30, 45, 60, 90, 120].map((mins) {
                  final isSel = _effortMinutes == mins;
                  return RitmoCard.neumorphic(
                    isSelected: isSel,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    onTap: () {
                      RitmoHaptics.selection();
                      setState(() => _effortMinutes = mins);
                    },
                    child: Text(
                      '${toPersianDigits(mins.toString())} دقیقه',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSel ? FontWeight.w900 : FontWeight.w600,
                        fontFamily: 'Vazirmatn',
                        color: isSel ? colors.primary : colors.textPrimary,
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 16),

              // 4. Importance & Work Kind Row
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ضرورت:',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: isGlass
                                ? colors.surfaceSunken.withValues(alpha: 0.5)
                                : colors.card,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: colors.border.withValues(alpha: 0.2)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<CommitmentImportance>(
                              value: _importance,
                              isExpanded: true,
                              dropdownColor: colors.surfaceElevated,
                              items: const [
                                DropdownMenuItem(
                                  value: CommitmentImportance.should,
                                  child: Text('بهتر است انجام شود', style: TextStyle(fontSize: 12)),
                                ),
                                DropdownMenuItem(
                                  value: CommitmentImportance.must,
                                  child: Text('حتماً انجام شود', style: TextStyle(fontSize: 12)),
                                ),
                                DropdownMenuItem(
                                  value: CommitmentImportance.could,
                                  child: Text('اگر وقت شد', style: TextStyle(fontSize: 12)),
                                ),
                              ],
                              onChanged: (val) {
                                if (val != null) setState(() => _importance = val);
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'نوع فعالیت:',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: isGlass
                                ? colors.surfaceSunken.withValues(alpha: 0.5)
                                : colors.card,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: colors.border.withValues(alpha: 0.2)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<WorkKind>(
                              value: _workKind,
                              isExpanded: true,
                              dropdownColor: colors.surfaceElevated,
                              items: const [
                                DropdownMenuItem(
                                  value: WorkKind.light,
                                  child: Text('کار سبک', style: TextStyle(fontSize: 12)),
                                ),
                                DropdownMenuItem(
                                  value: WorkKind.deep,
                                  child: Text('تمرکز عمیق', style: TextStyle(fontSize: 12)),
                                ),
                                DropdownMenuItem(
                                  value: WorkKind.social,
                                  child: Text('دیدار و روابط', style: TextStyle(fontSize: 12)),
                                ),
                                DropdownMenuItem(
                                  value: WorkKind.recovery,
                                  child: Text('استراحت و بازیابی', style: TextStyle(fontSize: 12)),
                                ),
                                DropdownMenuItem(
                                  value: WorkKind.admin,
                                  child: Text('پیگیری اداری', style: TextStyle(fontSize: 12)),
                                ),
                              ],
                              onChanged: (val) {
                                if (val != null) setState(() => _workKind = val);
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              if (_horizon == PlanningHorizon.week) ...[
                const SizedBox(height: 16),
                Text(
                  'روز مشخص (اختیاری):',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: weekDays.map((dk) {
                    final isSel = _selectedDayKey == dk;
                    return InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => setState(() => _selectedDayKey = dk),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSel
                              ? colors.primary.withValues(alpha: 0.2)
                              : (isGlass ? colors.surfaceSunken.withValues(alpha: 0.5) : colors.card),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSel ? colors.primary : colors.border.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          _getDayNameShort(dk),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                            color: isSel ? colors.primary : colors.textPrimary,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  String _getDayNameShort(String dayKey) {
    final dt = DateTime.tryParse(dayKey) ?? DateTime.now();
    switch (dt.weekday) {
      case DateTime.saturday: return 'شنبه';
      case DateTime.sunday: return '۱شنبه';
      case DateTime.monday: return '۲شنبه';
      case DateTime.tuesday: return '۳شنبه';
      case DateTime.wednesday: return '۴شنبه';
      case DateTime.thursday: return '۵شنبه';
      case DateTime.friday: return 'جمعه';
      default: return '';
    }
  }
}
