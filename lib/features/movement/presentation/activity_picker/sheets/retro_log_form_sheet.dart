import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/movement/domain/models/movement_activity_kind.dart';
import 'package:ritmo/features/movement/domain/models/movement_workout_log.dart';
import 'package:ritmo/features/movement/presentation/common/movement_layout.dart';
import 'package:ritmo/features/movement/presentation/common/movement_strings.dart';

/// شیت ثبت گذشته‌نگر فعالیت‌های ورزشی انجام‌شده
class RetroLogFormSheet extends StatefulWidget {
  const RetroLogFormSheet({
    super.key,
    required this.activityKind,
    required this.onSubmit,
    this.initialDate,
    this.matchingOccurrenceId,
  });

  final MovementActivityKind activityKind;
  final Future<MovementWorkoutLog> Function({
    required String dateIso,
    String? startTime,
    required int durationSec,
    Map<String, dynamic>? metrics,
    String? feeling,
    String? note,
    String? matchedOccurrenceId,
  }) onSubmit;

  final DateTime? initialDate;
  final String? matchingOccurrenceId;

  static Future<MovementWorkoutLog?> show(
    BuildContext context, {
    required MovementActivityKind activityKind,
    required Future<MovementWorkoutLog> Function({
      required String dateIso,
      String? startTime,
      required int durationSec,
      Map<String, dynamic>? metrics,
      String? feeling,
      String? note,
      String? matchedOccurrenceId,
    }) onSubmit,
    DateTime? initialDate,
    String? matchingOccurrenceId,
  }) {
    return showModalBottomSheet<MovementWorkoutLog>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: RetroLogFormSheet(
          activityKind: activityKind,
          initialDate: initialDate,
          matchingOccurrenceId: matchingOccurrenceId,
          onSubmit: onSubmit,
        ),
      ),
    );
  }

  @override
  State<RetroLogFormSheet> createState() => _RetroLogFormSheetState();
}

class _RetroLogFormSheetState extends State<RetroLogFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late DateTime _selectedDate;
  String _selectedTime = '18:00';
  final _durationController = TextEditingController(text: '30');
  final _metricController = TextEditingController();
  final _noteController = TextEditingController();
  String? _selectedFeeling;
  bool _isSaving = false;
  String? _errorMessage;

  final List<String> _feelings = ['عالی', 'خوب', 'معمولی', 'سخت', 'خسته'];

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate ?? DateTime.now();
  }

  @override
  void dispose() {
    _durationController.dispose();
    _metricController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  String _formatIso(DateTime d) {
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: now.subtract(const Duration(days: 90)),
      lastDate: now,
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickTime() async {
    final initial = TimeOfDay(
      hour: int.tryParse(_selectedTime.split(':').first) ?? 18,
      minute: int.tryParse(_selectedTime.split(':').last) ?? 0,
    );

    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );

    if (picked != null) {
      setState(() {
        _selectedTime =
            '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final minutes = int.tryParse(_durationController.text.trim()) ?? 30;
    final metricVal = double.tryParse(_metricController.text.trim());

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final log = await widget.onSubmit(
        dateIso: _formatIso(_selectedDate),
        startTime: _selectedTime,
        durationSec: minutes * 60,
        metrics: metricVal != null ? {'value': metricVal, 'unit': widget.activityKind.primaryMetric} : null,
        feeling: _selectedFeeling,
        note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
        matchedOccurrenceId: widget.matchingOccurrenceId,
      );

      if (mounted) {
        Navigator.of(context).pop(log);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final sportsColor = context.modules.sports;

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(RitmoRadius.sheet)),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: RitmoSpacing.lg,
        vertical: RitmoSpacing.md,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // دستگیره شیت
              Center(
                child: Container(
                  width: MovementLayout.kSheetHandleSize.width,
                  height: MovementLayout.kSheetHandleSize.height,
                  decoration: BoxDecoration(
                    color: colors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: RitmoSpacing.lg),

              Text(
                '${MovementStrings.retroLogTitle} • ${widget.activityKind.nameFa}',
                style: RitmoTextStyles.sectionHeadline(colors.textPrimary),
              ),
              const SizedBox(height: RitmoSpacing.lg),

              // پیام تطبیق با جلسهٔ برنامه‌ریزی‌شده
              if (widget.matchingOccurrenceId != null) ...[
                Container(
                  padding: const EdgeInsets.all(RitmoSpacing.sm),
                  decoration: BoxDecoration(
                    color: sportsColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(RitmoRadius.field),
                    border: Border.all(color: sportsColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.link_rounded, color: sportsColor, size: 20),
                      const SizedBox(width: RitmoSpacing.sm),
                      Expanded(
                        child: Text(
                          MovementStrings.retroLogMatchPrompt,
                          style: RitmoTextStyles.caption(sportsColor).copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: RitmoSpacing.md),
              ],

              // انتخاب تاریخ و ساعت
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: _pickDate,
                      borderRadius: BorderRadius.circular(RitmoRadius.field),
                      child: Container(
                        height: MovementLayout.kFieldMinHeight,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: colors.surfaceSunken,
                          borderRadius: BorderRadius.circular(RitmoRadius.field),
                          border: Border.all(color: colors.border),
                        ),
                        alignment: Alignment.centerRight,
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today_rounded, size: 18, color: colors.textSecondary),
                            const SizedBox(width: 8),
                            Text(
                              toPersianDigits(_formatIso(_selectedDate)),
                              style: RitmoTextStyles.body(colors.textPrimary),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: RitmoSpacing.md),
                  Expanded(
                    child: InkWell(
                      onTap: _pickTime,
                      borderRadius: BorderRadius.circular(RitmoRadius.field),
                      child: Container(
                        height: MovementLayout.kFieldMinHeight,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: colors.surfaceSunken,
                          borderRadius: BorderRadius.circular(RitmoRadius.field),
                          border: Border.all(color: colors.border),
                        ),
                        alignment: Alignment.centerRight,
                        child: Row(
                          children: [
                            Icon(Icons.access_time_rounded, size: 18, color: colors.textSecondary),
                            const SizedBox(width: 8),
                            Text(
                              toPersianDigits(_selectedTime),
                              style: RitmoTextStyles.body(colors.textPrimary),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: RitmoSpacing.md),

              // مدت زمان (دقیقه)
              Text(
                '${MovementStrings.retroLogDuration} *',
                style: RitmoTextStyles.label(colors.textSecondary),
              ),
              const SizedBox(height: RitmoSpacing.xs),
              TextFormField(
                controller: _durationController,
                keyboardType: TextInputType.number,
                style: RitmoTextStyles.body(colors.textPrimary),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: colors.surfaceSunken,
                  suffixText: 'دقیقه',
                  suffixStyle: RitmoTextStyles.label(colors.textSecondary),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(RitmoRadius.field),
                    borderSide: BorderSide(color: colors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(RitmoRadius.field),
                    borderSide: BorderSide(color: colors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(RitmoRadius.field),
                    borderSide: BorderSide(color: sportsColor, width: 2),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'وارد کردن مدت الزامی است';
                  final n = int.tryParse(val.trim());
                  if (n == null || n <= 0) return 'مدت نامعتبر است';
                  return null;
                },
              ),
              const SizedBox(height: RitmoSpacing.md),

              // حس بعد از تمرین
              Text(
                MovementStrings.retroLogFeeling,
                style: RitmoTextStyles.label(colors.textSecondary),
              ),
              const SizedBox(height: RitmoSpacing.xs),
              Wrap(
                spacing: RitmoSpacing.sm,
                children: _feelings.map((feeling) {
                  final isSelected = _selectedFeeling == feeling;
                  return ChoiceChip(
                    label: Text(
                      feeling,
                      style: RitmoTextStyles.caption(
                        isSelected ? Colors.white : colors.textPrimary,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: sportsColor,
                    onSelected: (sel) {
                      setState(() => _selectedFeeling = sel ? feeling : null);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: RitmoSpacing.md),

              // یادداشت
              Text(
                MovementStrings.retroLogNote,
                style: RitmoTextStyles.label(colors.textSecondary),
              ),
              const SizedBox(height: RitmoSpacing.xs),
              TextFormField(
                controller: _noteController,
                maxLines: 2,
                style: RitmoTextStyles.body(colors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'یادداشت کوتاه دربارهٔ شرایط یا عملکرد تمرین...',
                  hintStyle: RitmoTextStyles.body(colors.textTertiary),
                  filled: true,
                  fillColor: colors.surfaceSunken,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(RitmoRadius.field),
                    borderSide: BorderSide(color: colors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(RitmoRadius.field),
                    borderSide: BorderSide(color: colors.border),
                  ),
                ),
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: RitmoSpacing.sm),
                Text(
                  _errorMessage!,
                  style: RitmoTextStyles.caption(colors.error),
                ),
              ],
              const SizedBox(height: RitmoSpacing.xl),

              // دکمهٔ ثبت
              SizedBox(
                width: double.infinity,
                height: MovementLayout.kFieldMinHeight,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: sportsColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(RitmoRadius.field),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Text(
                          MovementStrings.retroLogSubmit,
                          style: RitmoTextStyles.label(Colors.white),
                        ),
                ),
              ),
              const SizedBox(height: RitmoSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }
}
