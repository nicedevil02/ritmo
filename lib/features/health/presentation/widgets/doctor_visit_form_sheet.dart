// =============================================================================
//  doctor_visit_form_sheet.dart
//  پنجره شیشه‌ای مرجع ثبت و ویرایش نوبت‌های پزشک (Ritmo Doctor Visit Form Sheet)
// =============================================================================

import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path_utils;
import 'package:path_provider/path_provider.dart';
import 'package:persian_datetime_picker/persian_datetime_picker.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/ritmo_date_picker.dart';
import 'package:ritmo/features/health/models/health_models.dart';
import 'package:ritmo/l10n/app_localizations.dart';

class DoctorVisitFormSheet extends StatefulWidget {
  const DoctorVisitFormSheet({
    super.key,
    this.visit,
    required this.onSave,
  });

  final DoctorVisit? visit;
  final Future<void> Function(DoctorVisit visit) onSave;

  static Future<bool?> show(
    BuildContext context, {
    DoctorVisit? visit,
    required Future<void> Function(DoctorVisit visit) onSave,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DoctorVisitFormSheet(
        visit: visit,
        onSave: onSave,
      ),
    );
  }

  @override
  State<DoctorVisitFormSheet> createState() => _DoctorVisitFormSheetState();
}

class _DoctorVisitFormSheetState extends State<DoctorVisitFormSheet> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _doctorNameController;
  late TextEditingController _specialtyController;
  late TextEditingController _clinicNameController;
  late TextEditingController _clinicAddressController;
  late TextEditingController _clinicPhoneController;
  late TextEditingController _reasonController;
  late TextEditingController _notesController;

  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  String _visitType = 'IN_PERSON';
  int _reminderBefore = 60;
  String? _attachmentPath;

  late String _initialDoctorName;
  late String _initialSpecialty;
  late String _initialClinicName;
  late String _initialClinicAddress;
  late String _initialClinicPhone;
  late String _initialReason;
  late String _initialNotes;
  late DateTime _initialDate;
  late TimeOfDay _initialTime;
  late String _initialVisitType;
  late int _initialReminderBefore;
  late String? _initialAttachmentPath;

  bool _isSubmitting = false;

  bool get _isEditing => widget.visit != null;

  bool get _isDirty {
    if (_doctorNameController.text.trim() != _initialDoctorName) return true;
    if (_specialtyController.text.trim() != _initialSpecialty) return true;
    if (_clinicNameController.text.trim() != _initialClinicName) return true;
    if (_clinicAddressController.text.trim() != _initialClinicAddress) return true;
    if (_clinicPhoneController.text.trim() != _initialClinicPhone) return true;
    if (_reasonController.text.trim() != _initialReason) return true;
    if (_notesController.text.trim() != _initialNotes) return true;
    if (_selectedDate != _initialDate) return true;
    if (_selectedTime != _initialTime) return true;
    if (_visitType != _initialVisitType) return true;
    if (_reminderBefore != _initialReminderBefore) return true;
    if (_attachmentPath != _initialAttachmentPath) return true;
    return false;
  }

  @override
  void initState() {
    super.initState();
    final v = widget.visit;
    _doctorNameController = TextEditingController(text: v?.doctorName ?? '');
    _specialtyController = TextEditingController(text: v?.specialty ?? '');
    _clinicNameController = TextEditingController(text: v?.clinicName ?? '');
    _clinicAddressController = TextEditingController(text: v?.clinicAddress ?? '');
    _clinicPhoneController = TextEditingController(text: v?.clinicPhone ?? '');
    _reasonController = TextEditingController(text: v?.reason ?? '');
    _notesController = TextEditingController(text: v?.doctorNotes ?? '');

    if (v != null) {
      final dt = DateTime.fromMillisecondsSinceEpoch(v.visitDateTime);
      _selectedDate = DateTime(dt.year, dt.month, dt.day);
      _selectedTime = TimeOfDay(hour: dt.hour, minute: dt.minute);
      _visitType = v.visitType;
      _reminderBefore = v.reminderBefore;
      _attachmentPath = v.attachmentPath;
    } else {
      final now = DateTime.now();
      _selectedDate = DateTime(now.year, now.month, now.day);
      _selectedTime = const TimeOfDay(hour: 10, minute: 0);
    }

    _initialDoctorName = _doctorNameController.text.trim();
    _initialSpecialty = _specialtyController.text.trim();
    _initialClinicName = _clinicNameController.text.trim();
    _initialClinicAddress = _clinicAddressController.text.trim();
    _initialClinicPhone = _clinicPhoneController.text.trim();
    _initialReason = _reasonController.text.trim();
    _initialNotes = _notesController.text.trim();
    _initialDate = _selectedDate;
    _initialTime = _selectedTime;
    _initialVisitType = _visitType;
    _initialReminderBefore = _reminderBefore;
    _initialAttachmentPath = _attachmentPath;
  }

  @override
  void dispose() {
    _doctorNameController.dispose();
    _specialtyController.dispose();
    _clinicNameController.dispose();
    _clinicAddressController.dispose();
    _clinicPhoneController.dispose();
    _reasonController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String _toPersianDigits(String input) {
    const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const persian = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
    var result = input;
    for (var i = 0; i < english.length; i++) {
      result = result.replaceAll(english[i], persian[i]);
    }
    return result;
  }

  String _normalizeDigits(String input) {
    const persian = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
    const arabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    var result = input;
    for (var i = 0; i < 10; i++) {
      result = result.replaceAll(persian[i], english[i]).replaceAll(arabic[i], english[i]);
    }
    return result;
  }

  Future<void> _pickDate() async {
    final picked = await RitmoDatePicker.showJalali(
      context: context,
      initialDate: Jalali.fromDateTime(_selectedDate),
      firstDate: Jalali.fromDateTime(DateTime.now().subtract(const Duration(days: 365))),
      lastDate: Jalali.fromDateTime(DateTime.now().add(const Duration(days: 365 * 2))),
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked.toDateTime();
      });
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: context.colors.primary,
              onPrimary: Colors.white,
              surface: context.colors.card,
              onSurface: context.colors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery);
      if (picked != null) {
        final appDir = await getApplicationDocumentsDirectory();
        final fileName = 'visit_attachment_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final savedFile = await File(picked.path).copy(path_utils.join(appDir.path, fileName));
        setState(() {
          _attachmentPath = savedFile.path;
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      RitmoHaptics.error();
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final finalDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    ).millisecondsSinceEpoch;

    final cleanPhone = _normalizeDigits(_clinicPhoneController.text.trim());
    final now = DateTime.now().millisecondsSinceEpoch;

    final visit = DoctorVisit(
      id: widget.visit?.id ?? 'visit_${DateTime.now().millisecondsSinceEpoch}',
      doctorName: _doctorNameController.text.trim(),
      specialty: _specialtyController.text.trim().isEmpty ? null : _specialtyController.text.trim(),
      clinicName: _clinicNameController.text.trim().isEmpty ? null : _clinicNameController.text.trim(),
      clinicAddress: _clinicAddressController.text.trim().isEmpty ? null : _clinicAddressController.text.trim(),
      clinicPhone: cleanPhone.isEmpty ? null : cleanPhone,
      visitDateTime: finalDateTime,
      visitType: _visitType,
      status: widget.visit?.status ?? 'UPCOMING',
      reason: _reasonController.text.trim().isEmpty ? null : _reasonController.text.trim(),
      doctorNotes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      userNotes: widget.visit?.userNotes,
      followUpDate: widget.visit?.followUpDate,
      reminderBefore: _reminderBefore,
      attachmentPath: _attachmentPath,
      createdAt: widget.visit?.createdAt ?? now,
      updatedAt: now,
    );

    RitmoHaptics.confirm();

    try {
      await widget.onSave(visit);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      debugPrint('Error saving doctor visit: $e');
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Widget _buildSectionLabel(String title, IconData icon, Color color) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: colors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _sunkenInputDecoration(
    BuildContext context, {
    required String label,
    String? hint,
    IconData? icon,
  }) {
    final colors = context.colors;
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(fontSize: 13, color: colors.textSecondary),
      hintText: hint,
      hintStyle: TextStyle(fontSize: 12.5, color: colors.textTertiary),
      prefixIcon: icon != null ? Icon(icon, size: 18, color: colors.primary) : null,
      filled: true,
      fillColor: colors.textPrimary.withValues(alpha: 0.04),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colors.textPrimary.withValues(alpha: 0.08)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colors.textPrimary.withValues(alpha: 0.08)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colors.medicalRed, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colors.medicalRed, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }

  Widget _buildVisitTypeChips(RitmoColors colors, AppLocalizations l10n) {
    final options = [
      ('IN_PERSON', l10n.doctorVisitsTypeInPerson, CupertinoIcons.person_2_fill),
      ('ONLINE', l10n.doctorVisitsTypeOnline, CupertinoIcons.tv_fill),
      ('TELEPHONE', l10n.doctorVisitsTypeTelephone, CupertinoIcons.phone_fill),
    ];

    return Container(
      decoration: BoxDecoration(
        color: colors.textPrimary.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.textPrimary.withValues(alpha: 0.08)),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: options.map((opt) {
          final isSelected = _visitType == opt.$1;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                RitmoHaptics.selection();
                setState(() => _visitType = opt.$1);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: isSelected ? colors.primary.withValues(alpha: 0.18) : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: isSelected ? Border.all(color: colors.primary.withValues(alpha: 0.4)) : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      opt.$3,
                      size: 14,
                      color: isSelected ? colors.primary : colors.textSecondary,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      opt.$2,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? colors.primary : colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDateTimeTile({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
    required RitmoColors colors,
  }) {
    return Expanded(
      child: InkWell(
        onTap: () {
          RitmoHaptics.selection();
          onTap();
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: colors.textPrimary.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.textPrimary.withValues(alpha: 0.08)),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: colors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(fontSize: 10.5, color: colors.textSecondary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: colors.textPrimary,
                      ),
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

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context)!;

    return RitmoFormSheetScaffold(
      title: _isEditing ? l10n.doctorVisitsEditTitle : l10n.doctorVisitsAddTitle,
      icon: '👨‍⚕️',
      iconBadgeColor: colors.primary,
      isEditing: _isEditing,
      isDirty: _isDirty,
      isSubmitting: _isSubmitting,
      saveLabel: _isEditing ? 'ذخیره' : 'ثبت نوبت',
      onSave: _submit,
      builder: (context, scrollController) {
        return SingleChildScrollView(
          controller: scrollController,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            top: 12,
            left: 16,
            right: 16,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── ۱. مشخصات پزشک ──
                _buildSectionLabel('مشخصات پزشک', CupertinoIcons.person_crop_circle_fill, colors.primary),
                TextFormField(
                  controller: _doctorNameController,
                  style: TextStyle(color: colors.textPrimary, fontSize: 13.5),
                  decoration: _sunkenInputDecoration(
                    context,
                    label: l10n.doctorVisitsDoctorName,
                    hint: 'مثلاً: دکتر علیرضا احمدی',
                    icon: CupertinoIcons.person,
                  ),
                  validator: (val) => val == null || val.trim().isEmpty ? 'لطفاً نام پزشک را وارد کنید' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _specialtyController,
                  style: TextStyle(color: colors.textPrimary, fontSize: 13.5),
                  decoration: _sunkenInputDecoration(
                    context,
                    label: l10n.doctorVisitsSpecialty,
                    hint: 'اختیاری: قلب و عروق، ارتوپدی و...',
                    icon: CupertinoIcons.star,
                  ),
                ),
                const SizedBox(height: 10),
                _buildVisitTypeChips(colors, l10n),
                const SizedBox(height: 20),

                // ── ۲. زمان‌بندی و یادآوری ──
                _buildSectionLabel('زمان‌بندی و یادآوری', CupertinoIcons.calendar_badge_plus, colors.accent),
                Row(
                  children: [
                    _buildDateTimeTile(
                      icon: CupertinoIcons.calendar,
                      label: 'تاریخ نوبت',
                      value: _toPersianDigits(
                        '${Jalali.fromDateTime(_selectedDate).year}/${Jalali.fromDateTime(_selectedDate).month}/${Jalali.fromDateTime(_selectedDate).day}',
                      ),
                      onTap: _pickDate,
                      colors: colors,
                    ),
                    const SizedBox(width: 10),
                    _buildDateTimeTile(
                      icon: CupertinoIcons.time,
                      label: 'ساعت مراجعه',
                      value: _toPersianDigits(
                        '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}',
                      ),
                      onTap: _pickTime,
                      colors: colors,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  initialValue: _reminderBefore,
                  style: TextStyle(color: colors.textPrimary, fontSize: 13.5),
                  decoration: _sunkenInputDecoration(
                    context,
                    label: l10n.doctorVisitsReminder,
                    icon: CupertinoIcons.bell,
                  ),
                  dropdownColor: colors.card,
                  items: [
                    DropdownMenuItem(value: 0, child: Text(l10n.doctorVisitsReminderNone)),
                    DropdownMenuItem(value: 15, child: Text(l10n.doctorVisitsReminder15m)),
                    DropdownMenuItem(value: 30, child: Text(l10n.doctorVisitsReminder30m)),
                    DropdownMenuItem(value: 60, child: Text(l10n.doctorVisitsReminder1h)),
                    DropdownMenuItem(value: 120, child: Text(l10n.doctorVisitsReminder2h)),
                    DropdownMenuItem(value: 1440, child: Text(l10n.doctorVisitsReminder1d)),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _reminderBefore = val;
                      });
                    }
                  },
                ),
                const SizedBox(height: 20),

                // ── ۳. مرکز درمانی و تماس ──
                _buildSectionLabel('مرکز درمانی و تماس', CupertinoIcons.building_2_fill, colors.warning),
                TextFormField(
                  controller: _clinicNameController,
                  style: TextStyle(color: colors.textPrimary, fontSize: 13.5),
                  decoration: _sunkenInputDecoration(
                    context,
                    label: l10n.doctorVisitsClinicName,
                    hint: 'نام بیمارستان، درمانگاه یا مطب',
                    icon: CupertinoIcons.building_2_fill,
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _clinicAddressController,
                  style: TextStyle(color: colors.textPrimary, fontSize: 13.5),
                  decoration: _sunkenInputDecoration(
                    context,
                    label: l10n.doctorVisitsClinicAddress,
                    hint: 'خیابان، ساختمان، پلاک، طبقه',
                    icon: CupertinoIcons.location_solid,
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _clinicPhoneController,
                  keyboardType: TextInputType.phone,
                  style: TextStyle(color: colors.textPrimary, fontSize: 13.5),
                  decoration: _sunkenInputDecoration(
                    context,
                    label: l10n.doctorVisitsClinicPhone,
                    hint: '۰۲۱-xxxxxxxx',
                    icon: CupertinoIcons.phone_fill,
                  ),
                ),
                const SizedBox(height: 20),

                // ── ۴. علت مراجعه و پیوست مدرک ──
                _buildSectionLabel('علت مراجعه و نسخه', CupertinoIcons.doc_text_fill, colors.success),
                TextFormField(
                  controller: _reasonController,
                  style: TextStyle(color: colors.textPrimary, fontSize: 13.5),
                  decoration: _sunkenInputDecoration(
                    context,
                    label: l10n.doctorVisitsReason,
                    hint: 'چکاپ دوره‌ای، درد زانو، معاینه چشم و...',
                    icon: CupertinoIcons.question_circle,
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _notesController,
                  style: TextStyle(color: colors.textPrimary, fontSize: 13.5),
                  decoration: _sunkenInputDecoration(
                    context,
                    label: l10n.doctorVisitsNotes,
                    hint: 'توصیه‌ها، آزمایش‌های مورد نیاز و یادداشت شخصی',
                    icon: CupertinoIcons.pencil_outline,
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: _pickImage,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: colors.textPrimary.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _attachmentPath != null
                            ? colors.primary.withValues(alpha: 0.4)
                            : colors.textPrimary.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(CupertinoIcons.camera_fill, color: colors.primary, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          _attachmentPath == null ? l10n.doctorVisitsAddAttachment : 'تغییر تصویر نسخه / مدرک ثبت شده',
                          style: TextStyle(
                            color: colors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_attachmentPath != null) ...[
                  const SizedBox(height: 10),
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          File(_attachmentPath!),
                          height: 140,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: GestureDetector(
                          onTap: () {
                            RitmoHaptics.selection();
                            setState(() => _attachmentPath = null);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: colors.medicalRed,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(CupertinoIcons.trash, color: Colors.white, size: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 24),

                // ── دکمه نهایی ثبت ──
                SizedBox(
                  height: 50,
                  child: RitmoNeuButton(
                    onTap: _submit,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(CupertinoIcons.checkmark_seal_fill, color: colors.primary, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          _isEditing ? 'ذخیره تغییرات نوبت' : l10n.doctorVisitsSave,
                          style: TextStyle(
                            color: colors.primary,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }
}
