import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/util/ritmo_number.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_page_scaffold.dart';
import 'package:ritmo/core/widgets/ritmo_module_app_bar.dart';
import 'package:ritmo/features/health/data/medication_repository.dart';
import 'package:ritmo/features/health/models/medication_models.dart';
import 'package:ritmo/features/health/presentation/widgets/medication_form_sheet.dart';

class MedicationFormPage extends StatefulWidget {
  const MedicationFormPage({
    super.key,
    this.medication,
    this.prefillData,
    this.onFormCompleted,
  });

  final Map<String, dynamic>? medication;
  final MedicationFormData? prefillData;
  final void Function(MedicationFormData data)? onFormCompleted;

  @override
  State<MedicationFormPage> createState() => _MedicationFormPageState();
}

class _MedicationFormPageState extends State<MedicationFormPage> {
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
    }

    try {
      final db = await DatabaseHelper.instance.database;
      final allergyRows = await db.query(
        'medical_allergies',
        where: "category = 'DRUG' AND isArchived = 0",
      );
      _drugAllergens = allergyRows.map((r) => r['allergenName'] as String).toList();
    } catch (_) {}

    _nameController.addListener(_checkAllergies);

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _checkAllergies() {
    final query = _nameController.text.trim().toLowerCase();
    if (query.isEmpty) {
      if (_matchedAllergen != null) setState(() => _matchedAllergen = null);
      return;
    }
    String? found;
    for (final allergen in _drugAllergens) {
      if (allergen.toLowerCase().contains(query) || query.contains(allergen.toLowerCase())) {
        found = allergen;
        break;
      }
    }
    if (found != _matchedAllergen) {
      setState(() => _matchedAllergen = found);
    }
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

  Future<void> _onSave() async {
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

    if (widget.onFormCompleted != null) {
      widget.onFormCompleted!(formData);
    } else {
      await MedicationSaveHelper.save(formData);
    }

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Widget _buildWeekdayChip(int isoDay, String label, RitmoColors colors) {
    final isSelected = _selectedWeekdays.contains(isoDay);
    return FilterChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
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
      backgroundColor: colors.surfaceSunken,
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

    return Directionality(
      textDirection: TextDirection.rtl,
      child: RitmoPageScaffold(
        appBar: RitmoModuleAppBar.fromContext(
          context: context,
          title: _isEdit ? 'ویرایش داروی تخصصی' : 'ثبت داروی جدید',
          showBackButton: true,
        ),
        body: _isLoading
            ? Center(child: CircularProgressIndicator(color: colors.primary))
            : Form(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  children: [
                    // ── ۱. مشخصات دارویی ──
                    RitmoCard.neumorphic(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RitmoCardHeader(
                            title: 'مشخصات اصلی دارو',
                            icon: CupertinoIcons.capsule_fill,
                            iconColor: colors.primary,
                          ),
                          const RitmoCardDivider(),
                          TextFormField(
                            controller: _nameController,
                            style: TextStyle(color: colors.textPrimary),
                            decoration: RitmoTheme.inputDecoration(
                              context,
                              label: 'نام دارو *',
                              icon: _form.icon,
                            ),
                          ),
                          if (_matchedAllergen != null) ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: colors.warning.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: colors.warning.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.warning_amber_rounded, color: colors.warning, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'هشدار حساسیت: شما به «$_matchedAllergen» حساسیت ثبت کرده‌اید!',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: colors.warning,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          DropdownButtonFormField<MedicationForm>(
                            initialValue: _form,
                            style: TextStyle(color: colors.textPrimary),
                            decoration: RitmoTheme.inputDecoration(
                              context,
                              label: 'شکل دارویی',
                              icon: CupertinoIcons.circle_grid_hex_fill,
                            ),
                            dropdownColor: colors.card,
                            isExpanded: true,
                            items: MedicationForm.values.map((f) {
                              return DropdownMenuItem<MedicationForm>(
                                value: f,
                                child: Row(
                                  children: [
                                    Icon(f.icon, size: 18, color: colors.primary),
                                    const SizedBox(width: 8),
                                    Text(f.labelFa),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) _onFormChanged(val);
                            },
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: TextFormField(
                                  controller: _doseAmountController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  style: TextStyle(color: colors.textPrimary),
                                  decoration: RitmoTheme.inputDecoration(
                                    context,
                                    label: 'مقدار دوز *',
                                    icon: CupertinoIcons.number,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                flex: 2,
                                child: DropdownButtonFormField<DoseUnit>(
                                  initialValue: _doseUnit,
                                  style: TextStyle(color: colors.textPrimary),
                                  decoration: RitmoTheme.inputDecoration(
                                    context,
                                    label: 'واحد',
                                    icon: CupertinoIcons.tag,
                                  ),
                                  dropdownColor: colors.card,
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
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── ۲. زمان‌بندی و دوزهای روزانه ──
                    RitmoCard.neumorphic(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RitmoCardHeader(
                            title: 'زمان‌بندی مصرف',
                            icon: CupertinoIcons.time_solid,
                            iconColor: colors.accent,
                          ),
                          const RitmoCardDivider(),
                          Row(
                            children: [
                              Expanded(
                                child: RitmoNeuButton(
                                  onTap: () => setState(() => _type = 'FIXED'),
                                  child: Text(
                                    'زمان مشخص',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: _type == 'FIXED' ? colors.primary : colors.textSecondary,
                                      fontWeight: _type == 'FIXED' ? FontWeight.w900 : FontWeight.normal,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: RitmoNeuButton(
                                  onTap: () => setState(() => _type = 'PRN'),
                                  child: Text(
                                    'عنداللزوم (PRN)',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: _type == 'PRN' ? colors.primary : colors.textSecondary,
                                      fontWeight: _type == 'PRN' ? FontWeight.w900 : FontWeight.normal,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (_type == 'FIXED') ...[
                            const SizedBox(height: 14),
                            Text(
                              'ساعت‌های مصرف در روز:',
                              style: TextStyle(fontSize: 12, color: colors.textSecondary, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (int i = 0; i < _scheduledTimes.length; i++)
                                  Chip(
                                    backgroundColor: colors.surfaceSunken,
                                    label: Text(
                                      toPersianDigits(
                                        '${_scheduledTimes[i].hour.toString().padLeft(2, '0')}:${_scheduledTimes[i].minute.toString().padLeft(2, '0')}',
                                      ),
                                      style: TextStyle(color: colors.primary, fontWeight: FontWeight.bold),
                                    ),
                                    deleteIcon: _scheduledTimes.length > 1
                                        ? Icon(CupertinoIcons.xmark_circle_fill, size: 16, color: colors.medicalRed)
                                        : null,
                                    onDeleted: _scheduledTimes.length > 1
                                        ? () => setState(() => _scheduledTimes.removeAt(i))
                                        : null,
                                  ),
                                ActionChip(
                                  avatar: Icon(CupertinoIcons.add, size: 16, color: colors.primary),
                                  label: const Text('افزودن ساعت', style: TextStyle(fontSize: 12)),
                                  backgroundColor: colors.primary.withValues(alpha: 0.1),
                                  onPressed: () async {
                                    final t = await showTimePicker(
                                      context: context,
                                      initialTime: const TimeOfDay(hour: 12, minute: 0),
                                    );
                                    if (t != null) {
                                      setState(() => _scheduledTimes.add(t));
                                    }
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'روزهای تکرار:',
                              style: TextStyle(fontSize: 12, color: colors.textSecondary, fontWeight: FontWeight.bold),
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
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── ۳. مدیریت موجودی و انبار ──
                    RitmoCard.neumorphic(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(CupertinoIcons.archivebox_fill, color: colors.warning, size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    'ردیابی موجودی انبار دارو',
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: colors.textPrimary),
                                  ),
                                ],
                              ),
                              Switch.adaptive(
                                value: _trackStock,
                                activeTrackColor: colors.primary,
                                onChanged: (v) => setState(() => _trackStock = v),
                              ),
                            ],
                          ),
                          if (_trackStock) ...[
                            const RitmoCardDivider(),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _stockCountController,
                                    keyboardType: TextInputType.number,
                                    style: TextStyle(color: colors.textPrimary),
                                    decoration: RitmoTheme.inputDecoration(
                                      context,
                                      label: 'موجودی فعلی',
                                      icon: CupertinoIcons.number_square,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextFormField(
                                    controller: _warningThresholdController,
                                    keyboardType: TextInputType.number,
                                    style: TextStyle(color: colors.textPrimary),
                                    decoration: RitmoTheme.inputDecoration(
                                      context,
                                      label: 'هشدار اتمام',
                                      icon: CupertinoIcons.bell,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── ۴. پزشک و دستورات ──
                    RitmoCard.neumorphic(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RitmoCardHeader(
                            title: 'پزشک تجویزکننده و دستورات',
                            icon: CupertinoIcons.doc_plaintext,
                            iconColor: colors.success,
                          ),
                          const RitmoCardDivider(),
                          TextFormField(
                            controller: _prescriberController,
                            style: TextStyle(color: colors.textPrimary),
                            decoration: RitmoTheme.inputDecoration(
                              context,
                              label: 'نام پزشک معالج (اختیاری)',
                              icon: Icons.person_outline,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _instructionsController,
                            style: TextStyle(color: colors.textPrimary),
                            maxLines: 2,
                            decoration: RitmoTheme.inputDecoration(
                              context,
                              label: 'دستورات ویژه مصرف (اختیاری)',
                              icon: Icons.notes,
                            ),
                          ),
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
              onTap: _onSave,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(CupertinoIcons.checkmark_seal_fill, color: colors.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    _isEdit ? 'ذخیره تغییرات دارو' : 'ثبت داروی جدید',
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
