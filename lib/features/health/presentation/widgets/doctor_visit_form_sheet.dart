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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── ۱. مشخصات پزشک و تخصص ──
                RitmoCard.neumorphic(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RitmoCardHeader(
                        title: 'مشخصات پزشک',
                        icon: CupertinoIcons.person_crop_circle_fill,
                        iconColor: colors.primary,
                      ),
                      const RitmoCardDivider(),
                      TextFormField(
                        controller: _doctorNameController,
                        style: TextStyle(color: colors.textPrimary),
                        decoration: RitmoTheme.inputDecoration(
                          context,
                          label: l10n.doctorVisitsDoctorName,
                          icon: CupertinoIcons.person,
                        ),
                        validator: (val) => val == null || val.trim().isEmpty ? 'لطفاً نام پزشک را وارد کنید' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _specialtyController,
                        style: TextStyle(color: colors.textPrimary),
                        decoration: RitmoTheme.inputDecoration(
                          context,
                          label: l10n.doctorVisitsSpecialty,
                          icon: CupertinoIcons.star,
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _visitType,
                        style: TextStyle(color: colors.textPrimary),
                        decoration: RitmoTheme.inputDecoration(
                          context,
                          label: l10n.doctorVisitsType,
                          icon: CupertinoIcons.layers_alt,
                        ),
                        dropdownColor: colors.card,
                        items: [
                          DropdownMenuItem(value: 'IN_PERSON', child: Text(l10n.doctorVisitsTypeInPerson)),
                          DropdownMenuItem(value: 'ONLINE', child: Text(l10n.doctorVisitsTypeOnline)),
                          DropdownMenuItem(value: 'TELEPHONE', child: Text(l10n.doctorVisitsTypeTelephone)),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _visitType = val;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── ۲. زمان نوبت و یادآور ──
                RitmoCard.neumorphic(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RitmoCardHeader(
                        title: 'زمان‌بندی و یادآوری',
                        icon: CupertinoIcons.calendar_badge_plus,
                        iconColor: colors.accent,
                      ),
                      const RitmoCardDivider(),
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 48,
                              child: RitmoNeuButton(
                                onTap: _pickDate,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(CupertinoIcons.calendar, color: colors.primary, size: 18),
                                    const SizedBox(width: 8),
                                    Text(
                                      _toPersianDigits(
                                        '${Jalali.fromDateTime(_selectedDate).year}/${Jalali.fromDateTime(_selectedDate).month}/${Jalali.fromDateTime(_selectedDate).day}',
                                      ),
                                      style: TextStyle(
                                        color: colors.textPrimary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SizedBox(
                              height: 48,
                              child: RitmoNeuButton(
                                onTap: _pickTime,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(CupertinoIcons.time, color: colors.primary, size: 18),
                                    const SizedBox(width: 8),
                                    Text(
                                      _toPersianDigits(
                                        '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}',
                                      ),
                                      style: TextStyle(
                                        color: colors.textPrimary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<int>(
                        initialValue: _reminderBefore,
                        style: TextStyle(color: colors.textPrimary),
                        decoration: RitmoTheme.inputDecoration(
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
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── ۳. اطلاعات مرکز درمانی ──
                RitmoCard.neumorphic(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RitmoCardHeader(
                        title: 'مرکز درمانی و تماس',
                        icon: CupertinoIcons.building_2_fill,
                        iconColor: colors.warning,
                      ),
                      const RitmoCardDivider(),
                      TextFormField(
                        controller: _clinicNameController,
                        style: TextStyle(color: colors.textPrimary),
                        decoration: RitmoTheme.inputDecoration(
                          context,
                          label: l10n.doctorVisitsClinicName,
                          icon: CupertinoIcons.building_2_fill,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _clinicAddressController,
                        style: TextStyle(color: colors.textPrimary),
                        decoration: RitmoTheme.inputDecoration(
                          context,
                          label: l10n.doctorVisitsClinicAddress,
                          icon: CupertinoIcons.location_solid,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _clinicPhoneController,
                        keyboardType: TextInputType.phone,
                        style: TextStyle(color: colors.textPrimary),
                        decoration: RitmoTheme.inputDecoration(
                          context,
                          label: l10n.doctorVisitsClinicPhone,
                          icon: CupertinoIcons.phone_fill,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── ۴. علت مراجعه، یادداشت و پیوست نسخه ──
                RitmoCard.neumorphic(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RitmoCardHeader(
                        title: 'علت مراجعه و پیوست مدارک',
                        icon: CupertinoIcons.doc_text_fill,
                        iconColor: colors.success,
                      ),
                      const RitmoCardDivider(),
                      TextFormField(
                        controller: _reasonController,
                        style: TextStyle(color: colors.textPrimary),
                        decoration: RitmoTheme.inputDecoration(
                          context,
                          label: l10n.doctorVisitsReason,
                          icon: CupertinoIcons.question_circle,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _notesController,
                        style: TextStyle(color: colors.textPrimary),
                        decoration: RitmoTheme.inputDecoration(
                          context,
                          label: l10n.doctorVisitsNotes,
                          icon: CupertinoIcons.pencil_outline,
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        height: 48,
                        child: RitmoNeuButton(
                          onTap: _pickImage,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(CupertinoIcons.camera_fill, color: colors.primary, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                _attachmentPath == null ? l10n.doctorVisitsAddAttachment : 'تغییر تصویر نسخه / مدرک',
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
                        const SizedBox(height: 12),
                        Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Image.file(
                                File(_attachmentPath!),
                                height: 160,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: GestureDetector(
                                onTap: () => setState(() => _attachmentPath = null),
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
                    ],
                  ),
                ),
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
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }
}
