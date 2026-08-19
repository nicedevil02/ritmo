import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/domain/models.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/util/ritmo_number.dart';
import 'package:ritmo/core/utils/ritmo_date_picker.dart';
import 'package:ritmo/features/health/data/medication_repository.dart';
import 'package:ritmo/features/health/models/medication_models.dart';
import 'package:shamsi_date/shamsi_date.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DATA MODEL  — pure data, no direct DB logic
// ─────────────────────────────────────────────────────────────────────────────

class MedicationFormData {
  const MedicationFormData({
    required this.name,
    required this.form,
    this.route,
    required this.doseAmount,
    required this.doseUnit,
    this.strength,
    this.activeIngredient,
    this.foodRelation = FoodRelation.NONE,
    this.isChronic = true,
    this.durationDays,
    this.endDate,
    required this.type, // 'FIXED' | 'PRN'
    required this.scheduledTimes,
    required this.repeatType, // 'WEEKDAYS' | 'INTERVAL'
    required this.selectedWeekdays,
    required this.intervalDays,
    required this.startDate,
    this.trackStock = false,
    this.packageSize,
    this.packageUnit,
    this.stockCount,
    this.warningThreshold,
    required this.minInterval,
    required this.maxDoses,
    this.prescriberName,
    this.instructions,
    this.criticality = MedicationCriticality.NORMAL,
    this.needsSiteRotation = false,
    this.injectionSites = const [],
    this.existingMedication,
    this.existingProfile,
  });

  final String name;
  final MedicationForm form;
  final MedicationRoute? route;
  final double doseAmount;
  final DoseUnit doseUnit;
  final String? strength;
  final String? activeIngredient;
  final FoodRelation foodRelation;
  final bool isChronic;
  final int? durationDays;
  final DateTime? endDate;
  final String type; // 'FIXED' | 'PRN'
  final List<TimeOfDay> scheduledTimes;
  final String repeatType; // 'WEEKDAYS' | 'INTERVAL'
  final List<int> selectedWeekdays;
  final int intervalDays;
  final DateTime startDate;
  final bool trackStock;
  final double? packageSize;
  final String? packageUnit;
  final double? stockCount;
  final double? warningThreshold;
  final int minInterval;
  final int maxDoses;
  final String? prescriberName;
  final String? instructions;
  final MedicationCriticality criticality;
  final bool needsSiteRotation;
  final List<String> injectionSites;

  /// Non-null when editing an existing medication routine row.
  final Map<String, dynamic>? existingMedication;
  final MedicationProfile? existingProfile;

  bool get isEdit => existingMedication != null;

  /// Backward compatible helper
  String get dose {
    final formattedAmount = doseAmount == doseAmount.toInt()
        ? doseAmount.toInt().toString()
        : doseAmount.toString();
    return '$formattedAmount ${doseUnit.shortLabelFa}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SAVE HELPER  — single place for DB write logic
// ─────────────────────────────────────────────────────────────────────────────

class MedicationSaveHelper {
  MedicationSaveHelper._();

  /// Persists [data] to the database using [MedicationRepository]. Returns the saved routineId.
  static Future<String> save(MedicationFormData data) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final routineId = data.isEdit
        ? data.existingMedication!['id'] as String
        : 'routine_med_$now';

    // Calculate effective end date if limited course
    DateTime? effectiveEndDate;
    if (!data.isChronic) {
      if (data.endDate != null) {
        effectiveEndDate = data.endDate;
      } else if (data.durationDays != null && data.durationDays! > 0) {
        effectiveEndDate = data.startDate.add(Duration(days: data.durationDays!));
      }
    }

    final firstTime = data.type == 'FIXED' && data.scheduledTimes.isNotEmpty
        ? '${data.scheduledTimes.first.hour.toString().padLeft(2, '0')}:${data.scheduledTimes.first.minute.toString().padLeft(2, '0')}'
        : '08:00';

    final String daysStr;
    final RecurrenceRule rule;

    if (data.type == 'PRN') {
      daysStr = '6,7,1,2,3,4,5';
      rule = RecurrenceRule(
        weekdays: [6, 7, 1, 2, 3, 4, 5],
        reminderTimes: const ['08:00'],
        startDate: data.startDate,
        endDate: effectiveEndDate,
      );
    } else if (data.repeatType == 'WEEKDAYS') {
      daysStr = data.selectedWeekdays.join(',');
      rule = RecurrenceRule(
        weekdays: data.selectedWeekdays,
        reminderTimes: data.scheduledTimes.map((t) {
          return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
        }).toList(),
        startDate: data.startDate,
        endDate: effectiveEndDate,
      );
    } else {
      daysStr = '6,7,1,2,3,4,5';
      rule = RecurrenceRule(
        weekdays: [],
        intervalDays: data.intervalDays,
        reminderTimes: data.scheduledTimes.map((t) {
          return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
        }).toList(),
        startDate: data.startDate,
        endDate: effectiveEndDate,
      );
    }

    final scheduleData = {
      'id': 'sched_$routineId',
      'routineId': routineId,
      'scheduleType': data.type == 'FIXED' ? 'RECURRENCE' : 'DAILY',
      'timeOfDay': firstTime,
      'daysOfWeek': daysStr,
      'recurrenceRule': jsonEncode(rule.toMap()),
      'createdAt': now,
      'updatedAt': now,
    };

    final profile = MedicationProfile(
      routineId: routineId,
      form: data.form,
      route: data.route ?? data.form.defaultRoute,
      doseAmount: data.doseAmount,
      doseUnit: data.doseUnit,
      strength: data.strength,
      activeIngredient: data.activeIngredient,
      foodRelation: data.foodRelation,
      startDate: data.startDate.millisecondsSinceEpoch,
      endDate: effectiveEndDate?.millisecondsSinceEpoch,
      isChronic: data.isChronic,
      durationDays: data.durationDays,
      prescriberName: data.prescriberName,
      instructions: data.instructions,
      criticality: data.criticality,
      packageSize: data.trackStock ? data.packageSize : null,
      packageUnit: data.trackStock ? data.packageUnit : null,
      remainingAmount: data.trackStock ? data.stockCount : null,
      refillThresholdAmount: data.trackStock ? data.warningThreshold : null,
      injectionSites: data.injectionSites,
      needsSiteRotation: data.needsSiteRotation,
    );

    final medication = Medication(
      id: routineId,
      name: data.name,
      description: data.instructions ?? data.dose,
      category: 'medical',
      routineType: data.type == 'FIXED' ? 'timeBased' : 'asNeeded',
      isEssential: true,
      isArchived: false,
      minIntervalHours: data.type == 'PRN' ? data.minInterval : 0,
      maxDosesPerDay: data.type == 'PRN' ? data.maxDoses : 0,
      createdAt: data.isEdit && data.existingMedication != null
          ? data.existingMedication!['createdAt'] as int? ?? now
          : now,
      updatedAt: now,
      profile: profile,
    );

    final savedId = await MedicationRepository.instance.saveMedication(
      medication: medication,
      scheduleData: scheduleData,
      isEdit: data.isEdit,
    );

    RitmoEvents.notifyRoutineChanged();
    return savedId;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FORM SHEET  — data collection only, no direct DB logic
// ─────────────────────────────────────────────────────────────────────────────

class MedicationFormSheet extends StatefulWidget {
  const MedicationFormSheet({
    super.key,
    this.medication,
    this.prefillData,
    required this.onFormCompleted,
  });

  final Map<String, dynamic>? medication;
  final MedicationFormData? prefillData;
  final void Function(MedicationFormData data) onFormCompleted;

  static Future<void> show(
    BuildContext context, {
    Map<String, dynamic>? medication,
    MedicationFormData? prefillData,
    required void Function(MedicationFormData data) onFormCompleted,
  }) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => MedicationFormSheet(
        medication: medication,
        prefillData: prefillData,
        onFormCompleted: onFormCompleted,
      ),
    );
  }

  @override
  State<MedicationFormSheet> createState() => _MedicationFormSheetState();
}

class _MedicationFormSheetState extends State<MedicationFormSheet> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _doseAmountController = TextEditingController(text: '1');
  final TextEditingController _strengthController = TextEditingController();
  final TextEditingController _activeIngredientController = TextEditingController();
  final TextEditingController _packageSizeController = TextEditingController(text: '30');
  final TextEditingController _stockCountController = TextEditingController(text: '30');
  final TextEditingController _warningThresholdController = TextEditingController(text: '5');
  final TextEditingController _durationDaysController = TextEditingController(text: '7');
  final TextEditingController _prescriberController = TextEditingController();
  final TextEditingController _instructionsController = TextEditingController();

  bool _isLoading = true;
  List<String> _drugAllergens = [];
  String? _matchedAllergen;

  bool _nameHasError = false;
  bool _doseHasError = false;
  bool _stockHasError = false;
  bool _warningHasError = false;

  MedicationForm _form = MedicationForm.TABLET;
  MedicationRoute? _route = MedicationRoute.ORAL;
  DoseUnit _doseUnit = DoseUnit.TABLET;
  FoodRelation _foodRelation = FoodRelation.NONE;
  MedicationCriticality _criticality = MedicationCriticality.NORMAL;

  bool _isChronic = true;
  DateTime? _endDate;

  String _type = 'FIXED';
  int _minInterval = 4;
  int _maxDoses = 4;

  bool _trackStock = false;
  bool _needsSiteRotation = false;

  List<TimeOfDay> _scheduledTimes = [const TimeOfDay(hour: 8, minute: 0)];
  String _repeatType = 'WEEKDAYS';
  List<int> _selectedWeekdays = [6, 7, 1, 2, 3, 4, 5];
  int _intervalDays = 2;
  DateTime _startDate = DateTime.now();

  MedicationProfile? _existingProfile;

  bool get _isEdit => widget.medication != null;

  @override
  void initState() {
    super.initState();
    _initializeForm();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _doseAmountController.dispose();
    _strengthController.dispose();
    _activeIngredientController.dispose();
    _packageSizeController.dispose();
    _stockCountController.dispose();
    _warningThresholdController.dispose();
    _durationDaysController.dispose();
    _prescriberController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  Future<void> _initializeForm() async {
    if (widget.prefillData != null) {
      final p = widget.prefillData!;
      _nameController.text = p.name;
      _form = p.form;
      _route = p.route ?? p.form.defaultRoute;
      _doseAmountController.text = p.doseAmount == p.doseAmount.toInt()
          ? p.doseAmount.toInt().toString()
          : p.doseAmount.toString();
      _doseUnit = p.doseUnit;
      _strengthController.text = p.strength ?? '';
      _activeIngredientController.text = p.activeIngredient ?? '';
      _foodRelation = p.foodRelation;
      _isChronic = p.isChronic;
      if (p.durationDays != null) {
        _durationDaysController.text = p.durationDays.toString();
      }
      _endDate = p.endDate;
      _type = p.type;
      _minInterval = p.minInterval;
      _maxDoses = p.maxDoses;
      _trackStock = p.trackStock;
      if (p.packageSize != null) {
        _packageSizeController.text = p.packageSize!.toInt().toString();
      }
      if (p.stockCount != null) {
        _stockCountController.text = p.stockCount!.toInt().toString();
      }
      if (p.warningThreshold != null) {
        _warningThresholdController.text = p.warningThreshold!.toInt().toString();
      }
      _scheduledTimes = List.from(p.scheduledTimes);
      _repeatType = p.repeatType;
      _selectedWeekdays = List.from(p.selectedWeekdays);
      _intervalDays = p.intervalDays;
      _startDate = p.startDate;
      _prescriberController.text = p.prescriberName ?? '';
      _instructionsController.text = p.instructions ?? '';
      _criticality = p.criticality;
      _needsSiteRotation = p.needsSiteRotation;
      _existingProfile = p.existingProfile;
    } else if (_isEdit) {
      final med = widget.medication!;
      final routineId = med['id'] as String;
      _nameController.text = med['title'] as String? ?? '';
      _type = med['routineType'] == 'asNeeded' ? 'PRN' : 'FIXED';
      _minInterval = med['minIntervalHours'] as int? ?? 4;
      _maxDoses = med['maxDosesPerDay'] as int? ?? 4;

      final stock = (med['medStockCount'] as num?)?.toDouble() ?? 0.0;
      final threshold = (med['medRefillThreshold'] as num?)?.toDouble() ?? 0.0;
      if (stock > 0 || threshold > 0) {
        _trackStock = true;
        _stockCountController.text = stock.toInt().toString();
        _packageSizeController.text = stock.toInt().toString();
        _warningThresholdController.text = threshold.toInt().toString();
      }

      // Load profile if available
      try {
        final profile = await MedicationRepository.instance.getByRoutineId(routineId);
        if (profile != null) {
          _existingProfile = profile.profile;
          _form = profile.profile.form;
          _route = profile.profile.route ?? profile.profile.form.defaultRoute;
          _doseUnit = profile.profile.doseUnit ?? profile.profile.form.defaultUnit;
          if (profile.profile.doseAmount != null) {
            _doseAmountController.text = profile.profile.doseAmount == profile.profile.doseAmount!.toInt()
                ? profile.profile.doseAmount!.toInt().toString()
                : profile.profile.doseAmount!.toString();
          }
          _strengthController.text = profile.profile.strength ?? '';
          _activeIngredientController.text = profile.profile.activeIngredient ?? '';
          _foodRelation = profile.profile.foodRelation;
          _isChronic = profile.profile.isChronic;
          if (profile.profile.durationDays != null) {
            _durationDaysController.text = profile.profile.durationDays.toString();
          }
          if (profile.profile.endDate != null) {
            _endDate = DateTime.fromMillisecondsSinceEpoch(profile.profile.endDate!);
          }
          _prescriberController.text = profile.profile.prescriberName ?? '';
          _instructionsController.text = profile.profile.instructions ?? med['description'] as String? ?? '';
          _criticality = profile.profile.criticality;
          _needsSiteRotation = profile.profile.needsSiteRotation;
          if (profile.profile.hasStockTracking) {
            _trackStock = true;
            _packageSizeController.text = profile.profile.packageSize?.toInt().toString() ?? '30';
            _stockCountController.text = profile.profile.remainingAmount?.toInt().toString() ?? '30';
            _warningThresholdController.text = profile.profile.refillThresholdAmount?.toInt().toString() ?? '5';
          }
        }
      } catch (e) {
        debugPrint('Error loading profile: $e');
      }

      // Load schedule
      try {
        final db = await DatabaseHelper.instance.database;
        final res = await db.query(
          'routine_schedules',
          where: 'routineId = ?',
          whereArgs: [routineId],
        );
        if (res.isNotEmpty) {
          final ruleStr = res.first['recurrenceRule'] as String?;
          if (ruleStr != null && ruleStr.isNotEmpty) {
            final rule = RecurrenceRule.fromMap(
              jsonDecode(ruleStr) as Map<String, dynamic>,
            );
            if (rule.reminderTimes.isNotEmpty) {
              _scheduledTimes = rule.reminderTimes.map((t) {
                final p = t.split(':');
                return TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1]));
              }).toList();
            }
            if (rule.startDate != null) _startDate = rule.startDate!;
            if (rule.endDate != null) _endDate = rule.endDate;
            if (rule.intervalDays != null && rule.intervalDays! > 0) {
              _repeatType = 'INTERVAL';
              _intervalDays = rule.intervalDays!;
            } else {
              _repeatType = 'WEEKDAYS';
              _selectedWeekdays = rule.weekdays.isNotEmpty
                  ? List<int>.from(rule.weekdays)
                  : [6, 7, 1, 2, 3, 4, 5];
            }
          }
        }
      } catch (e) {
        debugPrint('Error loading schedule: $e');
      }
    }

    try {
      final db = await DatabaseHelper.instance.database;
      final res = await db.query('allergies', where: "category = 'DRUG'");
      _drugAllergens = res.map((r) => r['allergen']! as String).toList();
    } catch (e) {
      debugPrint('Error loading allergens: $e');
    }

    if (mounted) {
      setState(() => _isLoading = false);
      _nameController.addListener(_checkAllergy);
    }
  }

  void _checkAllergy() {
    final text = _nameController.text.trim().toLowerCase();
    if (!mounted) return;
    setState(() {
      if (text.isEmpty || _drugAllergens.isEmpty) {
        _matchedAllergen = null;
        return;
      }
      _matchedAllergen = null;
      for (final a in _drugAllergens) {
        final ca = a.toLowerCase().trim();
        if (ca.length >= 3 && (text.contains(ca) || ca.contains(text))) {
          _matchedAllergen = a;
          break;
        }
      }
    });
  }

  void _onFormChanged(MedicationForm newForm) {
    setState(() {
      _form = newForm;
      _doseUnit = newForm.defaultUnit;
      _route = newForm.defaultRoute;
      if (newForm == MedicationForm.INSULIN) {
        _doseUnit = DoseUnit.IU;
        _route = MedicationRoute.SUBCUTANEOUS;
        _needsSiteRotation = true;
      } else if (newForm == MedicationForm.DROPS) {
        _doseUnit = DoseUnit.DROP;
        _route = MedicationRoute.OPHTHALMIC;
      } else if (newForm == MedicationForm.INHALER || newForm == MedicationForm.SPRAY) {
        _doseUnit = DoseUnit.PUFF;
        _route = newForm == MedicationForm.INHALER ? MedicationRoute.INHALED : MedicationRoute.NASAL;
      } else if (newForm == MedicationForm.SYRUP) {
        _doseUnit = DoseUnit.ML;
        _route = MedicationRoute.ORAL;
      }
    });
  }

  void _onContinue() {
    final name = _nameController.text.trim();
    final normalizedDose = RitmoNumber.toEn(_doseAmountController.text.trim());
    final doseAmount = double.tryParse(normalizedDose) ?? 0.0;

    double? packageSize;
    double? stockCount;
    double? warningThreshold;

    if (_trackStock) {
      final normPkg = RitmoNumber.toEn(_packageSizeController.text.trim());
      final normStock = RitmoNumber.toEn(_stockCountController.text.trim());
      final normWarn = RitmoNumber.toEn(_warningThresholdController.text.trim());
      packageSize = double.tryParse(normPkg);
      stockCount = double.tryParse(normStock);
      warningThreshold = double.tryParse(normWarn);
    }

    int? durationDays;
    if (!_isChronic) {
      final normDays = RitmoNumber.toEn(_durationDaysController.text.trim());
      durationDays = int.tryParse(normDays);
    }

    setState(() {
      _nameHasError = name.isEmpty;
      _doseHasError = doseAmount <= 0;
      _stockHasError = _trackStock && (stockCount == null || stockCount <= 0);
      _warningHasError = _trackStock && (warningThreshold == null || warningThreshold < 0);
    });

    if (_nameHasError || _doseHasError || _stockHasError || _warningHasError) {
      return;
    }

    final formData = MedicationFormData(
      name: name,
      form: _form,
      route: _route,
      doseAmount: doseAmount,
      doseUnit: _doseUnit,
      strength: _strengthController.text.trim().isNotEmpty ? _strengthController.text.trim() : null,
      activeIngredient: _activeIngredientController.text.trim().isNotEmpty ? _activeIngredientController.text.trim() : null,
      foodRelation: _foodRelation,
      isChronic: _isChronic,
      durationDays: durationDays,
      endDate: _endDate,
      type: _type,
      scheduledTimes: List.from(_scheduledTimes),
      repeatType: _repeatType,
      selectedWeekdays: List.from(_selectedWeekdays),
      intervalDays: _intervalDays,
      startDate: _startDate,
      trackStock: _trackStock,
      packageSize: packageSize,
      packageUnit: _doseUnit.shortLabelFa,
      stockCount: stockCount,
      warningThreshold: warningThreshold,
      minInterval: _minInterval,
      maxDoses: _maxDoses,
      prescriberName: _prescriberController.text.trim().isNotEmpty ? _prescriberController.text.trim() : null,
      instructions: _instructionsController.text.trim().isNotEmpty ? _instructionsController.text.trim() : null,
      criticality: _criticality,
      needsSiteRotation: _needsSiteRotation,
      existingMedication: widget.medication,
      existingProfile: _existingProfile,
    );

    Navigator.pop(context);
    widget.onFormCompleted(formData);
  }

  Widget _buildWeekdayChip(int isoDay, String label, RitmoColors colors) {
    final isSelected = _selectedWeekdays.contains(isoDay);
    return FilterChip(
      label: Text(label, style: const TextStyle(fontSize: 13)),
      selected: isSelected,
      onSelected: (v) => setState(() {
        if (v) {
          _selectedWeekdays.add(isoDay);
        } else if (_selectedWeekdays.length > 1) {
          _selectedWeekdays.remove(isoDay);
        }
      }),
      selectedColor: colors.primary.withValues(alpha: 0.15),
      checkmarkColor: colors.primary,
      labelStyle: TextStyle(
        color: isSelected ? colors.primary : colors.textSecondary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      backgroundColor: colors.card.withValues(alpha: 0.4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      side: BorderSide(
        color: isSelected
            ? colors.primary.withValues(alpha: 0.4)
            : colors.border.withValues(alpha: 0.3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: DraggableScrollableSheet(
          initialChildSize: 0.90,
          maxChildSize: 0.96,
          minChildSize: 0.6,
          expand: false,
          snap: true,
          builder: (ctx, scrollController) => RitmoTheme.glassCardLight(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: colors.primary))
                : Container(
                    padding: const EdgeInsets.all(20),
                    child: Form(
                      child: ListView(
                        controller: scrollController,
                        children: [
                          // Handle bar
                          Center(
                            child: Container(
                              width: 40,
                              height: 5,
                              decoration: BoxDecoration(
                                color: colors.border,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _isEdit ? 'ویرایش داروی تخصصی' : 'ثبت داروی جدید',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: colors.textPrimary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20),

                          // Drug name
                          TextFormField(
                            controller: _nameController,
                            decoration: InputDecoration(
                              labelText: 'نام دارو *',
                              hintText: 'مثال: انسولین لانتوس، متفورمین، قطره بتازون',
                              prefixIcon: Icon(_form.icon, color: colors.primary),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              errorText: _nameHasError ? 'لطفاً نام دارو را وارد کنید' : null,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Allergy warning banner
                          if (_matchedAllergen != null)
                            Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.amber.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 24),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'هشدار حساسیت: شما قبلاً به «$_matchedAllergen» حساسیت ثبت کرده‌اید!',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: isDark ? Colors.amber.shade200 : Colors.amber.shade900,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          // Medication Form Selection (Dropdown)
                          DropdownButtonFormField<MedicationForm>(
                            initialValue: _form,
                            decoration: InputDecoration(
                              labelText: 'شکل دارویی',
                              prefixIcon: Icon(_form.icon, color: colors.primary),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            isExpanded: true,
                            items: MedicationForm.values.map((f) {
                              return DropdownMenuItem<MedicationForm>(
                                value: f,
                                child: Row(
                                  children: [
                                    Icon(f.icon, size: 20, color: colors.primary),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        f.labelFa,
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          color: colors.textPrimary,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) _onFormChanged(val);
                            },
                          ),
                          const SizedBox(height: 14),

                          // Dose Amount & Dose Unit
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 3,
                                child: TextFormField(
                                  controller: _doseAmountController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: InputDecoration(
                                    labelText: 'مقدار دوز *',
                                    hintText: 'مثال: ۱۰ یا ۵۰۰ یا ۲',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    errorText: _doseHasError ? 'مقدار معتبر وارد کنید' : null,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                flex: 2,
                                child: DropdownButtonFormField<DoseUnit>(
                                  initialValue: _doseUnit,
                                  decoration: InputDecoration(
                                    labelText: 'واحد',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  items: DoseUnit.values.map((u) {
                                    return DropdownMenuItem(
                                      value: u,
                                      child: Text(u.shortLabelFa, style: const TextStyle(fontSize: 13)),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) setState(() => _doseUnit = val);
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Route of Administration
                          DropdownButtonFormField<MedicationRoute>(
                            initialValue: _route,
                            decoration: InputDecoration(
                              labelText: 'مسیر مصرف',
                              prefixIcon: Icon(Icons.alt_route_rounded, color: colors.primary),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            items: MedicationRoute.values.map((r) {
                              return DropdownMenuItem(
                                value: r,
                                child: Text(r.labelFa, style: const TextStyle(fontSize: 13)),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _route = val);
                            },
                          ),
                          const SizedBox(height: 14),

                          // Food Relation
                          DropdownButtonFormField<FoodRelation>(
                            initialValue: _foodRelation,
                            decoration: InputDecoration(
                              labelText: 'ارتباط با غذا',
                              prefixIcon: Icon(Icons.restaurant_rounded, color: colors.primary),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            items: FoodRelation.values.map((rel) {
                              return DropdownMenuItem(
                                value: rel,
                                child: Text(rel.labelFa, style: const TextStyle(fontSize: 13)),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _foodRelation = val);
                            },
                          ),
                          const SizedBox(height: 20),

                          // Clinical Education & Guidance Card for Non-Pill Forms
                          if (ClinicalFormHelper.getClinicalEducationNote(_form) != null) ...[
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: colors.primary.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: colors.primary.withValues(alpha: 0.2)),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.info_outline_rounded, color: colors.primary, size: 22),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'راهنما و توصیه بالینی مصرف',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: colors.primary,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          ClinicalFormHelper.getClinicalEducationNote(_form)!,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: colors.textSecondary,
                                            height: 1.4,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                          ],

                          // Insulin / Injection / Patch Specific Settings (Site Rotation)
                          if (_form == MedicationForm.INSULIN || _form == MedicationForm.INJECTION || _form == MedicationForm.PATCH) ...[
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: colors.card.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: colors.border.withValues(alpha: 0.4)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.rotate_right_rounded, color: colors.primary),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _form == MedicationForm.PATCH
                                              ? 'ثبت و تغییر دوره‌ای محل چسباندن پچ'
                                              : 'پیشنهاد چرخش محل تزریق',
                                          style: TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.bold,
                                            color: colors.textPrimary,
                                          ),
                                        ),
                                      ),
                                      Switch(
                                        value: _needsSiteRotation,
                                        onChanged: (val) => setState(() => _needsSiteRotation = val),
                                        activeThumbColor: colors.primary,
                                      ),
                                    ],
                                  ),
                                  Text(
                                    _form == MedicationForm.PATCH
                                        ? 'جهت پیشگیری از حساسیت موضعی پوست و جذب یکنواخت'
                                        : 'جهت جلوگیری از لیپوهیپرتروفی و جذب بهینه دارو در بافت',
                                    style: TextStyle(fontSize: 12, color: colors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],

                          // Treatment Course (Chronic vs Limited)
                          Text(
                            'دوره درمان',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: colors.textPrimary),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: ChoiceChip(
                                  label: const Center(child: Text('مزمن / دائمی')),
                                  selected: _isChronic,
                                  onSelected: (sel) {
                                    if (sel) setState(() => _isChronic = true);
                                  },
                                  selectedColor: colors.primary,
                                  labelStyle: TextStyle(
                                    color: _isChronic ? Colors.white : colors.textPrimary,
                                    fontWeight: _isChronic ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ChoiceChip(
                                  label: const Center(child: Text('دوره محدود')),
                                  selected: !_isChronic,
                                  onSelected: (sel) {
                                    if (sel) setState(() => _isChronic = false);
                                  },
                                  selectedColor: colors.primary,
                                  labelStyle: TextStyle(
                                    color: !_isChronic ? Colors.white : colors.textPrimary,
                                    fontWeight: !_isChronic ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (!_isChronic) ...[
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _durationDaysController,
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      labelText: 'طول دوره (تعداد روز)',
                                      hintText: 'مثال: ۷ یا ۱۰ یا ۱۴',
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () async {
                                      final picked = await RitmoDatePicker.show(
                                        context: context,
                                        initialDate: _endDate ?? DateTime.now().add(const Duration(days: 7)),
                                        firstDate: DateTime.now(),
                                        lastDate: DateTime.now().add(const Duration(days: 365)),
                                      );
                                      if (picked != null) {
                                        setState(() {
                                          _endDate = picked;
                                          final diff = picked.difference(_startDate).inDays;
                                          if (diff > 0) {
                                            _durationDaysController.text = diff.toString();
                                          }
                                        });
                                      }
                                    },
                                    icon: const Icon(Icons.calendar_today_rounded, size: 18),
                                    label: Text(
                                      _endDate != null
                                          ? '${Jalali.fromDateTime(_endDate!).year}/${Jalali.fromDateTime(_endDate!).month.toString().padLeft(2, '0')}/${Jalali.fromDateTime(_endDate!).day.toString().padLeft(2, '0')}'
                                          : 'تاریخ پایان',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      minimumSize: const Size(double.infinity, 54),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 20),

                          // Medication Schedule Type (Fixed vs PRN)
                          Text(
                            'نوع زمان‌بندی',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: colors.textPrimary),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: ChoiceChip(
                                  label: const Center(child: Text('منظم (ساعت مشخص)')),
                                  selected: _type == 'FIXED',
                                  onSelected: (sel) {
                                    if (sel) setState(() => _type = 'FIXED');
                                  },
                                  selectedColor: colors.primary,
                                  labelStyle: TextStyle(
                                    color: _type == 'FIXED' ? Colors.white : colors.textPrimary,
                                    fontWeight: _type == 'FIXED' ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ChoiceChip(
                                  label: const Center(child: Text('در صورت نیاز (PRN)')),
                                  selected: _type == 'PRN',
                                  onSelected: (sel) {
                                    if (sel) setState(() => _type = 'PRN');
                                  },
                                  selectedColor: colors.primary,
                                  labelStyle: TextStyle(
                                    color: _type == 'PRN' ? Colors.white : colors.textPrimary,
                                    fontWeight: _type == 'PRN' ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Schedule specific inputs
                          if (_type == 'FIXED') ...[
                            Text(
                              'ساعات مصرف در روز',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: colors.textPrimary),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (var i = 0; i < _scheduledTimes.length; i++)
                                  Chip(
                                    avatar: Icon(Icons.access_time_rounded, size: 16, color: colors.primary),
                                    label: Text(
                                      '${_scheduledTimes[i].hour.toString().padLeft(2, '0')}:${_scheduledTimes[i].minute.toString().padLeft(2, '0')}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                    onDeleted: _scheduledTimes.length > 1
                                        ? () => setState(() => _scheduledTimes.removeAt(i))
                                        : null,
                                    deleteIconColor: colors.error,
                                    backgroundColor: colors.primary.withValues(alpha: 0.1),
                                  ),
                                ActionChip(
                                  avatar: const Icon(Icons.add_rounded, size: 18),
                                  label: const Text('افزودن زمان'),
                                  onPressed: () async {
                                    final picked = await showTimePicker(
                                      context: context,
                                      initialTime: const TimeOfDay(hour: 12, minute: 0),
                                    );
                                    if (picked != null) {
                                      setState(() {
                                        _scheduledTimes.add(picked);
                                        _scheduledTimes.sort((a, b) => (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute));
                                      });
                                    }
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            // Days of week
                            Text(
                              'روزهای مصرف',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: colors.textPrimary),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                _buildWeekdayChip(6, 'ش', colors),
                                _buildWeekdayChip(7, 'ی', colors),
                                _buildWeekdayChip(1, 'د', colors),
                                _buildWeekdayChip(2, 'س', colors),
                                _buildWeekdayChip(3, 'چ', colors),
                                _buildWeekdayChip(4, 'پ', colors),
                                _buildWeekdayChip(5, 'ج', colors),
                              ],
                            ),
                          ] else ...[
                            // PRN parameters
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    initialValue: _minInterval.toString(),
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      labelText: 'حداقل فاصله (ساعت)',
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    onChanged: (val) {
                                      final parsed = int.tryParse(RitmoNumber.toEn(val));
                                      if (parsed != null && parsed > 0) {
                                        _minInterval = parsed;
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextFormField(
                                    initialValue: _maxDoses.toString(),
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      labelText: 'حداکثر دوز در روز',
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    onChanged: (val) {
                                      final parsed = int.tryParse(RitmoNumber.toEn(val));
                                      if (parsed != null && parsed > 0) {
                                        _maxDoses = parsed;
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 20),

                          // Inventory / Stock Tracking (Optional)
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: colors.card.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: colors.border.withValues(alpha: 0.4)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.inventory_2_rounded, color: colors.primary),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'پیگیری موجودی و هشدار تمدید نسخه',
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.bold,
                                          color: colors.textPrimary,
                                        ),
                                      ),
                                    ),
                                    Switch(
                                      value: _trackStock,
                                      onChanged: (val) => setState(() => _trackStock = val),
                                      activeThumbColor: colors.primary,
                                    ),
                                  ],
                                ),
                                if (_trackStock) ...[
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextFormField(
                                          controller: _packageSizeController,
                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                          decoration: InputDecoration(
                                            labelText: 'اندازه بسته (${_doseUnit.shortLabelFa})',
                                            hintText: 'مثال: ۳۰',
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: TextFormField(
                                          controller: _stockCountController,
                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                          decoration: InputDecoration(
                                            labelText: 'موجودی فعلی',
                                            hintText: 'مثال: ۳۰',
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                            errorText: _stockHasError ? 'مقدار نامعتبر' : null,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: TextFormField(
                                          controller: _warningThresholdController,
                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                          decoration: InputDecoration(
                                            labelText: 'آستانه هشدار',
                                            hintText: 'مثال: ۵',
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                            errorText: _warningHasError ? 'نامعتبر' : null,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Prescriber & Instructions
                          TextFormField(
                            controller: _prescriberController,
                            decoration: InputDecoration(
                              labelText: 'پزشک تجویزکننده (اختیاری)',
                              prefixIcon: Icon(Icons.person_outline_rounded, color: colors.primary),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _instructionsController,
                            maxLines: 2,
                            decoration: InputDecoration(
                              labelText: 'دستور مصرف / توضیحات پزشک (اختیاری)',
                              prefixIcon: Icon(Icons.notes_rounded, color: colors.primary),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Clinical Importance / Criticality
                          DropdownButtonFormField<MedicationCriticality>(
                            initialValue: _criticality,
                            decoration: InputDecoration(
                              labelText: 'اهمیت بالینی',
                              prefixIcon: Icon(Icons.priority_high_rounded, color: colors.primary),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            items: MedicationCriticality.values.map((crit) {
                              return DropdownMenuItem(
                                value: crit,
                                child: Text(crit.labelFa, style: const TextStyle(fontSize: 13)),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _criticality = val);
                            },
                          ),
                          const SizedBox(height: 16),

                          // Medical disclaimer
                          Text(
                            '⚠️ این اپلیکیشن جایگزین توصیه پزشک نیست. همواره طبق تجویز پزشک معالج عمل کنید.',
                            style: TextStyle(fontSize: 11, color: colors.textSecondary),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),

                          // Continue button
                          ElevatedButton(
                            onPressed: _onContinue,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colors.primary,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(double.infinity, 48),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text(
                              'ادامه و پیش‌نمایش 👁️',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PREVIEW CARD  — shared widget used in both preview sheet & planner
// ─────────────────────────────────────────────────────────────────────────────

class MedicationPreviewCard extends StatelessWidget {
  const MedicationPreviewCard({super.key, required this.data, this.onEdit});
  final MedicationFormData data;
  final VoidCallback? onEdit;

  String _weekdayName(int iso) {
    const names = {6: 'شنبه', 7: 'یکشنبه', 1: 'دوشنبه', 2: 'سه‌شنبه', 3: 'چهارشنبه', 4: 'پنج‌شنبه', 5: 'جمعه'};
    return names[iso] ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final String scheduleLabel;
    if (data.type == 'PRN') {
      scheduleLabel = 'در صورت نیاز (PRN) · حداقل فاصله ${data.minInterval} ساعت · سقف ${data.maxDoses} دوز/روز';
    } else if (data.repeatType == 'WEEKDAYS') {
      final days = data.selectedWeekdays.map(_weekdayName).join('، ');
      final times = data.scheduledTimes.map((t) =>
          '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}').join(' و ');
      scheduleLabel = '$days · ساعت $times';
    } else {
      final j = Jalali.fromDateTime(data.startDate);
      final dateStr = '${j.year}/${j.month.toString().padLeft(2, '0')}/${j.day.toString().padLeft(2, '0')}';
      final times = data.scheduledTimes.map((t) =>
          '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}').join(' و ');
      scheduleLabel = 'هر ${data.intervalDays} روز · از $dateStr · ساعت $times';
    }

    final courseLabel = data.isChronic
        ? 'مزمن / دائمی'
        : (data.endDate != null
            ? 'دوره محدود تا ${Jalali.fromDateTime(data.endDate!).year}/${Jalali.fromDateTime(data.endDate!).month.toString().padLeft(2, '0')}/${Jalali.fromDateTime(data.endDate!).day.toString().padLeft(2, '0')}'
            : 'دوره ${data.durationDays ?? 7} روزه');

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF1A1D2E).withValues(alpha: 0.9)
              : Colors.white.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: colors.primary.withValues(alpha: 0.2), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: colors.primary.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(data.form.icon, color: colors.primary, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data.name,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: colors.textPrimary,
                        ),
                      ),
                      Text(
                        '${data.form.labelFa} · ${data.dose} · ${data.route?.labelFa ?? data.form.defaultRoute.labelFa}',
                        style: TextStyle(fontSize: 12.5, color: colors.textSecondary),
                      ),
                    ],
                  ),
                ),
                if (onEdit != null) ...[
                  IconButton(
                    onPressed: onEdit,
                    icon: Icon(Icons.edit_rounded, size: 18, color: colors.primary),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 8),
                ],
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: (data.type == 'PRN' ? colors.warning : colors.primary).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    data.type == 'PRN' ? 'PRN' : 'منظم',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: data.type == 'PRN' ? colors.warning : colors.primary,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),
            Divider(color: colors.border.withValues(alpha: 0.3)),
            const SizedBox(height: 10),

            _infoRow(Icons.repeat_rounded, 'برنامه مصرف', scheduleLabel, colors),
            const SizedBox(height: 8),
            _infoRow(Icons.timeline_rounded, 'دوره درمان', courseLabel, colors),
            if (data.foodRelation != FoodRelation.NONE) ...[
              const SizedBox(height: 8),
              _infoRow(Icons.restaurant_rounded, 'توصیه غذایی', data.foodRelation.labelFa, colors),
            ],
            if (data.needsSiteRotation) ...[
              const SizedBox(height: 8),
              _infoRow(Icons.rotate_right_rounded, 'چرخش محل مصرف', 'فعال (توصیه بالینی)', colors),
            ],
            if (data.prescriberName != null && data.prescriberName!.isNotEmpty) ...[
              const SizedBox(height: 8),
              _infoRow(Icons.person_outline_rounded, 'پزشک تجویزکننده', data.prescriberName!, colors),
            ],
            if (data.trackStock && data.stockCount != null) ...[
              const SizedBox(height: 8),
              _infoRow(
                Icons.inventory_2_outlined,
                'موجودی',
                '${data.stockCount} ${data.doseUnit.shortLabelFa} (هشدار زیر ${data.warningThreshold ?? 5})',
                colors,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value, RitmoColors colors) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: colors.textSecondary.withValues(alpha: 0.7)),
        const SizedBox(width: 8),
        Text('$label: ', style: TextStyle(fontSize: 12, color: colors.textSecondary)),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: colors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PREVIEW SHEET  — used by standalone health flow
// ─────────────────────────────────────────────────────────────────────────────

class MedicationPreviewSheet extends StatefulWidget {
  const MedicationPreviewSheet({
    super.key,
    required this.data,
    this.onSaved,
    this.onEdit,
  });

  final MedicationFormData data;
  final VoidCallback? onSaved;
  final VoidCallback? onEdit;

  static Future<void> show(
    BuildContext context, {
    required MedicationFormData data,
    VoidCallback? onSaved,
    VoidCallback? onEdit,
  }) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => MedicationPreviewSheet(
        data: data,
        onSaved: onSaved,
        onEdit: onEdit,
      ),
    );
  }

  @override
  State<MedicationPreviewSheet> createState() => _MedicationPreviewSheetState();
}

class _MedicationPreviewSheetState extends State<MedicationPreviewSheet> {
  bool _isSaving = false;

  Future<void> _save() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      await MedicationSaveHelper.save(widget.data);
      if (mounted) {
        Navigator.pop(context);
        widget.onSaved?.call();
      }
    } catch (e) {
      debugPrint('MedicationPreviewSheet save error: $e');
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: DraggableScrollableSheet(
        initialChildSize: 0.68,
        maxChildSize: 0.88,
        minChildSize: 0.5,
        expand: false,
        snap: true,
        builder: (ctx, scrollController) => RitmoTheme.glassCardLight(
          child: Container(
            padding: const EdgeInsets.all(20),
            child: ListView(
              controller: scrollController,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(color: colors.border, borderRadius: BorderRadius.circular(3)),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '👁️ پیش‌نمایش دارو',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: colors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  'اطلاعات دارو را بررسی کنید. پس از تأیید، در برنامه ذخیره می‌شود.',
                  style: TextStyle(fontSize: 12, color: colors.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),

                MedicationPreviewCard(data: widget.data),

                const SizedBox(height: 24),

                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    if (widget.onEdit != null) {
                      widget.onEdit!();
                    }
                  },
                  icon: const Icon(Icons.edit_rounded, size: 18),
                  label: const Text('ویرایش اطلاعات'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 44),
                    side: BorderSide(color: colors.border),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),

                ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          widget.data.isEdit ? '✅ ذخیره تغییرات' : '✅ ثبت دارو',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
