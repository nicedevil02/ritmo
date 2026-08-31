import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path_utils;
import 'package:path_provider/path_provider.dart';
import 'package:persian_datetime_picker/persian_datetime_picker.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/ritmo_date_picker.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_page_scaffold.dart';
import 'package:ritmo/core/widgets/ritmo_module_app_bar.dart';
import 'package:ritmo/features/health/models/health_models.dart';
import 'package:ritmo/l10n/app_localizations.dart';

class DoctorVisitFormPage extends StatefulWidget {
  const DoctorVisitFormPage({
    super.key,
    this.visit,
    required this.onSave,
  });

  final DoctorVisit? visit;
  final void Function(DoctorVisit visit) onSave;

  @override
  State<DoctorVisitFormPage> createState() => _DoctorVisitFormPageState();
}

class _DoctorVisitFormPageState extends State<DoctorVisitFormPage> {
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

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

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

    widget.onSave(visit);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context)!;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: RitmoPageScaffold(
        appBar: RitmoModuleAppBar.fromContext(
          context: context,
          title: widget.visit == null ? l10n.doctorVisitsAddTitle : l10n.doctorVisitsEditTitle,
          showBackButton: true,
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                        icon: Icons.person,
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
                        icon: Icons.star_border,
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _visitType,
                      style: TextStyle(color: colors.textPrimary),
                      decoration: RitmoTheme.inputDecoration(
                        context,
                        label: l10n.doctorVisitsType,
                        icon: Icons.category,
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
                        const SizedBox(width: 12),
                        Expanded(
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
                      ],
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<int>(
                      initialValue: _reminderBefore,
                      style: TextStyle(color: colors.textPrimary),
                      decoration: RitmoTheme.inputDecoration(
                        context,
                        label: l10n.doctorVisitsReminder,
                        icon: Icons.notifications,
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
                        icon: Icons.business,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _clinicAddressController,
                      style: TextStyle(color: colors.textPrimary),
                      decoration: RitmoTheme.inputDecoration(
                        context,
                        label: l10n.doctorVisitsClinicAddress,
                        icon: Icons.location_on,
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
                        icon: Icons.phone,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── ۴. علت مراجعه، یادداشت و نسخه ──
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
                        icon: Icons.question_answer,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _notesController,
                      style: TextStyle(color: colors.textPrimary),
                      decoration: RitmoTheme.inputDecoration(
                        context,
                        label: l10n.doctorVisitsNotes,
                        icon: Icons.notes,
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 14),
                    RitmoNeuButton(
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
              const SizedBox(height: 100),
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: RitmoNeuButton(
              onTap: _submit,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(CupertinoIcons.checkmark_seal_fill, color: colors.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    l10n.doctorVisitsSave,
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
        ),
      ),
    );
  }
}
