import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
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
  CommitmentImportance _importance = CommitmentImportance.must;
  WorkKind _workKind = WorkKind.deep;
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
        final draft = await repo.createDraft(
          horizon: _horizon,
          startDayKey: _horizon == PlanningHorizon.month
              ? '${now.year}-${now.month.toString().padLeft(2, '0')}-01'
              : weekDays.first,
          endDayKey: _horizon == PlanningHorizon.month
              ? '${now.year}-${now.month.toString().padLeft(2, '0')}-30'
              : weekDays.last,
          title: _horizon == PlanningHorizon.month ? 'برنامهٔ ماه' : 'برنامهٔ هفته',
          nowMs: nowMs,
        );
        cycle = await repo.activate(draft, nowMs: nowMs);
      }

      // 2. Create commitment
      final commitmentId = 'comm_${nowMs}_${title.hashCode.abs()}';
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
    final isDark = context.isDark;
    final isGlass = context.isGlassEnabled;
    final blur = context.glassBlurSigma.clamp(0.0, 50.0);
    const sheetRadius = BorderRadius.vertical(top: Radius.circular(28));
    final weekDays = PlanningWeek.dayKeysOfWeekContaining(DateTime.now());

    final content = Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: colors.textSecondary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.add_task_rounded, color: colors.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'افزودن تعهد جدید',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: colors.textPrimary,
                          ),
                        ),
                        Text(
                          'تعهدی را برای امروز، این هفته یا این ماه ثبت کنید',
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

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
                  labelText: 'عنوان تعهد یا کار',
                  labelStyle: TextStyle(
                    fontSize: 13,
                    color: colors.textSecondary,
                  ),
                  hintText: 'مثلاً: مطالعه ۳۰ صفحه کتاب، پیاده‌سازی فرم لاگین...',
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
                'مدت زمان تخمینی:',
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
                  return InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => setState(() => _effortMinutes = mins),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSel
                            ? colors.primary
                            : (isGlass ? colors.surfaceSunken.withValues(alpha: 0.5) : colors.card),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSel ? colors.primary : colors.border.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        '${PersianDigits.toPersian(mins.toString())} دقیقه',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                          color: isSel ? Colors.white : colors.textPrimary,
                        ),
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
                          'اولویت:',
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
                                  value: CommitmentImportance.must,
                                  child: Text('ضروری (Must)', style: TextStyle(fontSize: 12)),
                                ),
                                DropdownMenuItem(
                                  value: CommitmentImportance.should,
                                  child: Text('مهم (Should)', style: TextStyle(fontSize: 12)),
                                ),
                                DropdownMenuItem(
                                  value: CommitmentImportance.could,
                                  child: Text('در صورت امکان (Could)', style: TextStyle(fontSize: 12)),
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
                          'نوع کار:',
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
                                  value: WorkKind.deep,
                                  child: Text('کار عمیق (Deep)', style: TextStyle(fontSize: 12)),
                                ),
                                DropdownMenuItem(
                                  value: WorkKind.light,
                                  child: Text('کار سبک (Light)', style: TextStyle(fontSize: 12)),
                                ),
                                DropdownMenuItem(
                                  value: WorkKind.admin,
                                  child: Text('اداری (Admin)', style: TextStyle(fontSize: 12)),
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
                  'تخصیص به روز مشخص:',
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

              const SizedBox(height: 24),

              // Submit Button
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _isSaving ? null : _saveCommitment,
                child: _isSaving
                    ? const CupertinoActivityIndicator(color: Colors.white)
                    : const Text(
                        'ثبت تعهد',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );

    final sheetBody = Directionality(
      textDirection: TextDirection.rtl,
      child: Material(
        type: MaterialType.transparency,
        child: content,
      ),
    );

    if (!isGlass) {
      return Container(
        decoration: BoxDecoration(
          color: colors.surfaceElevated,
          borderRadius: sheetRadius,
          border: Border.all(
            color: isDark ? colors.border : colors.divider,
            width: 1.0,
          ),
        ),
        child: sheetBody,
      );
    }

    return ClipRRect(
      borderRadius: sheetRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.glassTint,
            borderRadius: sheetRadius,
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.18)
                  : Colors.white.withValues(alpha: 0.70),
              width: 1.0,
            ),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: sheetRadius,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withValues(alpha: isDark ? 0.08 : 0.20),
                  Colors.white.withValues(alpha: 0.0),
                ],
                stops: const [0.0, 0.45],
              ),
            ),
            child: sheetBody,
          ),
        ),
      ),
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
