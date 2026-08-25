// ignore_for_file: constant_identifier_names
import 'dart:convert';
import 'package:flutter/material.dart';

/// اشکال دارویی استاندارد
enum MedicationForm {
  TABLET,
  CAPSULE,
  SYRUP,
  DROPS,
  INJECTION,
  INSULIN,
  INHALER,
  SPRAY,
  TOPICAL,
  SUPPOSITORY,
  PATCH,
  SACHET,
  IV,
  OTHER;

  static MedicationForm fromString(String? value) {
    if (value == null || value.isEmpty) return MedicationForm.TABLET;
    final upper = value.trim().toUpperCase();
    for (final form in MedicationForm.values) {
      if (form.name == upper) return form;
    }
    return MedicationForm.TABLET;
  }

  static MedicationForm? fromStringOrNull(String? value) {
    if (value == null || value.isEmpty) return null;
    final upper = value.trim().toUpperCase();
    for (final form in MedicationForm.values) {
      if (form.name == upper) return form;
    }
    return null;
  }

  String get labelFa {
    switch (this) {
      case MedicationForm.TABLET:
        return 'قرص';
      case MedicationForm.CAPSULE:
        return 'کپسول';
      case MedicationForm.SYRUP:
        return 'شربت / سوسپانسیون';
      case MedicationForm.DROPS:
        return 'قطره';
      case MedicationForm.INJECTION:
        return 'آمپول / تزریقی';
      case MedicationForm.INSULIN:
        return 'انسولین';
      case MedicationForm.INHALER:
        return 'اسپری تنفسی (اینهالر)';
      case MedicationForm.SPRAY:
        return 'اسپری / افشانه';
      case MedicationForm.TOPICAL:
        return 'پماد / کرم / موضعی';
      case MedicationForm.SUPPOSITORY:
        return 'شیاف';
      case MedicationForm.PATCH:
        return 'پچ پوستی';
      case MedicationForm.SACHET:
        return 'ساشه / پودر';
      case MedicationForm.IV:
        return 'سرم / وریدی';
      case MedicationForm.OTHER:
        return 'سایر';
    }
  }

  String get labelEn {
    switch (this) {
      case MedicationForm.TABLET:
        return 'Tablet';
      case MedicationForm.CAPSULE:
        return 'Capsule';
      case MedicationForm.SYRUP:
        return 'Syrup';
      case MedicationForm.DROPS:
        return 'Drops';
      case MedicationForm.INJECTION:
        return 'Injection';
      case MedicationForm.INSULIN:
        return 'Insulin';
      case MedicationForm.INHALER:
        return 'Inhaler';
      case MedicationForm.SPRAY:
        return 'Spray';
      case MedicationForm.TOPICAL:
        return 'Topical / Ointment';
      case MedicationForm.SUPPOSITORY:
        return 'Suppository';
      case MedicationForm.PATCH:
        return 'Patch';
      case MedicationForm.SACHET:
        return 'Sachet';
      case MedicationForm.IV:
        return 'IV / Infusion';
      case MedicationForm.OTHER:
        return 'Other';
    }
  }

  IconData get icon {
    switch (this) {
      case MedicationForm.TABLET:
        return Icons.medication_rounded;
      case MedicationForm.CAPSULE:
        return Icons.medication_liquid_rounded;
      case MedicationForm.SYRUP:
        return Icons.local_drink_rounded;
      case MedicationForm.DROPS:
        return Icons.opacity_rounded;
      case MedicationForm.INJECTION:
      case MedicationForm.INSULIN:
        return Icons.vaccines_rounded;
      case MedicationForm.INHALER:
      case MedicationForm.SPRAY:
        return Icons.air_rounded;
      case MedicationForm.TOPICAL:
        return Icons.healing_rounded;
      case MedicationForm.SUPPOSITORY:
        return Icons.medical_services_rounded;
      case MedicationForm.PATCH:
        return Icons.layers_rounded;
      case MedicationForm.SACHET:
        return Icons.inventory_2_rounded;
      case MedicationForm.IV:
        return Icons.water_drop_rounded;
      case MedicationForm.OTHER:
        return Icons.medical_information_rounded;
    }
  }

  DoseUnit get defaultUnit {
    switch (this) {
      case MedicationForm.TABLET:
        return DoseUnit.TABLET;
      case MedicationForm.CAPSULE:
        return DoseUnit.CAPSULE;
      case MedicationForm.SYRUP:
        return DoseUnit.ML;
      case MedicationForm.DROPS:
        return DoseUnit.DROP;
      case MedicationForm.INSULIN:
        return DoseUnit.IU;
      case MedicationForm.INHALER:
      case MedicationForm.SPRAY:
        return DoseUnit.PUFF;
      case MedicationForm.PATCH:
        return DoseUnit.PATCH;
      case MedicationForm.SACHET:
        return DoseUnit.SACHET;
      case MedicationForm.INJECTION:
      case MedicationForm.IV:
        return DoseUnit.ML;
      case MedicationForm.TOPICAL:
      case MedicationForm.SUPPOSITORY:
      case MedicationForm.OTHER:
        return DoseUnit.UNIT;
    }
  }

  MedicationRoute get defaultRoute {
    switch (this) {
      case MedicationForm.TABLET:
      case MedicationForm.CAPSULE:
      case MedicationForm.SYRUP:
      case MedicationForm.SACHET:
        return MedicationRoute.ORAL;
      case MedicationForm.DROPS:
        return MedicationRoute.OPHTHALMIC;
      case MedicationForm.INJECTION:
        return MedicationRoute.INTRAMUSCULAR;
      case MedicationForm.INSULIN:
        return MedicationRoute.SUBCUTANEOUS;
      case MedicationForm.INHALER:
        return MedicationRoute.INHALED;
      case MedicationForm.SPRAY:
        return MedicationRoute.NASAL;
      case MedicationForm.TOPICAL:
      case MedicationForm.PATCH:
        return MedicationRoute.TOPICAL;
      case MedicationForm.SUPPOSITORY:
        return MedicationRoute.RECTAL;
      case MedicationForm.IV:
        return MedicationRoute.INTRAVENOUS;
      case MedicationForm.OTHER:
        return MedicationRoute.ORAL;
    }
  }
}

/// مسیرهای مصرف دارو
enum MedicationRoute {
  ORAL,
  SUBLINGUAL,
  SUBCUTANEOUS,
  INTRAMUSCULAR,
  INTRAVENOUS,
  OPHTHALMIC,
  OTIC,
  NASAL,
  INHALED,
  TOPICAL,
  RECTAL,
  VAGINAL;

  static MedicationRoute? fromString(String? value) {
    if (value == null || value.isEmpty) return null;
    final upper = value.trim().toUpperCase();
    for (final route in MedicationRoute.values) {
      if (route.name == upper) return route;
    }
    return null;
  }

  String get labelFa {
    switch (this) {
      case MedicationRoute.ORAL:
        return 'خوراکی';
      case MedicationRoute.SUBLINGUAL:
        return 'زیرزبانی';
      case MedicationRoute.SUBCUTANEOUS:
        return 'زیرجلدی (تزریق SC)';
      case MedicationRoute.INTRAMUSCULAR:
        return 'عضلانی (تزریق IM)';
      case MedicationRoute.INTRAVENOUS:
        return 'وریدی (تزریق IV / سرم)';
      case MedicationRoute.OPHTHALMIC:
        return 'چشمی';
      case MedicationRoute.OTIC:
        return 'گوشی';
      case MedicationRoute.NASAL:
        return 'بینی / استنشاقی بینی';
      case MedicationRoute.INHALED:
        return 'تنفسی / ریوی';
      case MedicationRoute.TOPICAL:
        return 'پوستی / موضعی';
      case MedicationRoute.RECTAL:
        return 'رکتال / مقعدی';
      case MedicationRoute.VAGINAL:
        return 'واژینال';
    }
  }

  String get labelEn {
    switch (this) {
      case MedicationRoute.ORAL:
        return 'Oral';
      case MedicationRoute.SUBLINGUAL:
        return 'Sublingual';
      case MedicationRoute.SUBCUTANEOUS:
        return 'Subcutaneous';
      case MedicationRoute.INTRAMUSCULAR:
        return 'Intramuscular';
      case MedicationRoute.INTRAVENOUS:
        return 'Intravenous';
      case MedicationRoute.OPHTHALMIC:
        return 'Ophthalmic (Eye)';
      case MedicationRoute.OTIC:
        return 'Otic (Ear)';
      case MedicationRoute.NASAL:
        return 'Nasal';
      case MedicationRoute.INHALED:
        return 'Inhaled';
      case MedicationRoute.TOPICAL:
        return 'Topical';
      case MedicationRoute.RECTAL:
        return 'Rectal';
      case MedicationRoute.VAGINAL:
        return 'Vaginal';
    }
  }
}

/// واحدهای دوز و موجودی
enum DoseUnit {
  MG,
  MCG,
  G,
  ML,
  IU,
  UNIT,
  DROP,
  PUFF,
  PATCH,
  SACHET,
  TABLET,
  CAPSULE,
  CC;

  static DoseUnit fromString(
    String? value, {
    DoseUnit fallback = DoseUnit.TABLET,
  }) {
    if (value == null || value.isEmpty) return fallback;
    final upper = value.trim().toUpperCase();
    for (final unit in DoseUnit.values) {
      if (unit.name == upper) return unit;
    }
    return fallback;
  }

  static DoseUnit? fromStringOrNull(String? value) {
    if (value == null || value.isEmpty) return null;
    final upper = value.trim().toUpperCase();
    for (final unit in DoseUnit.values) {
      if (unit.name == upper) return unit;
    }
    return null;
  }

  String get labelFa {
    switch (this) {
      case DoseUnit.MG:
        return 'میلی‌گرم (mg)';
      case DoseUnit.MCG:
        return 'میکروگرم (mcg)';
      case DoseUnit.G:
        return 'گرم (g)';
      case DoseUnit.ML:
        return 'میلی‌لیتر (ml)';
      case DoseUnit.IU:
        return 'واحد بین‌المللی (IU)';
      case DoseUnit.UNIT:
        return 'واحد (Unit)';
      case DoseUnit.DROP:
        return 'قطره';
      case DoseUnit.PUFF:
        return 'پاف';
      case DoseUnit.PATCH:
        return 'پچ / عدد';
      case DoseUnit.SACHET:
        return 'ساشه / بسته';
      case DoseUnit.TABLET:
        return 'قرص / عدد';
      case DoseUnit.CAPSULE:
        return 'کپسول / عدد';
      case DoseUnit.CC:
        return 'سی‌سی (cc)';
    }
  }

  String get shortLabelFa {
    switch (this) {
      case DoseUnit.MG:
        return 'mg';
      case DoseUnit.MCG:
        return 'mcg';
      case DoseUnit.G:
        return 'g';
      case DoseUnit.ML:
        return 'ml';
      case DoseUnit.IU:
        return 'واحد';
      case DoseUnit.UNIT:
        return 'واحد';
      case DoseUnit.DROP:
        return 'قطره';
      case DoseUnit.PUFF:
        return 'پاف';
      case DoseUnit.PATCH:
        return 'پچ';
      case DoseUnit.SACHET:
        return 'ساشه';
      case DoseUnit.TABLET:
        return 'قرص';
      case DoseUnit.CAPSULE:
        return 'کپسول';
      case DoseUnit.CC:
        return 'cc';
    }
  }

  String get labelEn => name;
}

/// ارتباط مصرف با وعده غذایی
enum FoodRelation {
  NONE,
  WITH_FOOD,
  BEFORE_MEAL,
  AFTER_MEAL,
  EMPTY_STOMACH;

  static FoodRelation fromString(String? value) {
    if (value == null || value.isEmpty) return FoodRelation.NONE;
    final upper = value.trim().toUpperCase();
    for (final rel in FoodRelation.values) {
      if (rel.name == upper) return rel;
    }
    return FoodRelation.NONE;
  }

  String get labelFa {
    switch (this) {
      case FoodRelation.NONE:
        return 'بدون ارتباط خاص با غذا';
      case FoodRelation.WITH_FOOD:
        return 'همراه با غذا';
      case FoodRelation.BEFORE_MEAL:
        return 'قبل از غذا (نیم ساعت قبل)';
      case FoodRelation.AFTER_MEAL:
        return 'بعد از غذا';
      case FoodRelation.EMPTY_STOMACH:
        return 'با معده خالی (ناشتا یا ۲ ساعت بعد غذا)';
    }
  }

  String get labelEn {
    switch (this) {
      case FoodRelation.NONE:
        return 'No food relation';
      case FoodRelation.WITH_FOOD:
        return 'With food';
      case FoodRelation.BEFORE_MEAL:
        return 'Before meal';
      case FoodRelation.AFTER_MEAL:
        return 'After meal';
      case FoodRelation.EMPTY_STOMACH:
        return 'Empty stomach';
    }
  }
}

/// سطح حساسیت بالینی دارو
enum MedicationCriticality {
  NORMAL,
  HIGH,
  LIFE_CRITICAL;

  static MedicationCriticality fromString(String? value) {
    if (value == null || value.isEmpty) return MedicationCriticality.NORMAL;
    final upper = value.trim().toUpperCase();
    for (final crit in MedicationCriticality.values) {
      if (crit.name == upper) return crit;
    }
    return MedicationCriticality.NORMAL;
  }

  String get labelFa {
    switch (this) {
      case MedicationCriticality.NORMAL:
        return 'عادی';
      case MedicationCriticality.HIGH:
        return 'مهم و پرخطر';
      case MedicationCriticality.LIFE_CRITICAL:
        return 'حیاتی / بدون وقفه ⚠️';
    }
  }

  String get labelEn => name;
}

/// مدل داده پروفایل دارویی (تخصصی)
class MedicationProfile {
  const MedicationProfile({
    required this.routineId,
    this.form = MedicationForm.TABLET,
    this.route,
    this.doseAmount,
    this.doseUnit,
    this.strength,
    this.activeIngredient,
    this.foodRelation = FoodRelation.NONE,
    this.startDate,
    this.endDate,
    this.isChronic = false,
    this.durationDays,
    this.prescriberName,
    this.instructions,
    this.criticality = MedicationCriticality.NORMAL,
    this.packageSize,
    this.packageUnit,
    this.remainingAmount,
    this.refillThresholdAmount,
    this.injectionSites = const [],
    this.lastInjectionSite,
    this.needsSiteRotation = false,
  });

  final String routineId;
  final MedicationForm form;
  final MedicationRoute? route;
  final double? doseAmount;
  final DoseUnit? doseUnit;
  final String? strength;
  final String? activeIngredient;
  final FoodRelation foodRelation;
  final int? startDate;
  final int? endDate;
  final bool isChronic;
  final int? durationDays;
  final String? prescriberName;
  final String? instructions;
  final MedicationCriticality criticality;
  final double? packageSize;
  final String? packageUnit;
  final double? remainingAmount;
  final double? refillThresholdAmount;
  final List<String> injectionSites;
  final String? lastInjectionSite;
  final bool needsSiteRotation;

  bool get hasStockTracking =>
      (packageSize != null && packageSize! > 0) ||
      (remainingAmount != null && remainingAmount! > 0) ||
      (refillThresholdAmount != null && refillThresholdAmount! > 0);
  bool get isLowStock =>
      hasStockTracking &&
      remainingAmount != null &&
      refillThresholdAmount != null &&
      remainingAmount! <= refillThresholdAmount!;
  bool get isOutOfStock =>
      hasStockTracking && remainingAmount != null && remainingAmount! <= 0;

  static const Object _sentinel = Object();

  Map<String, dynamic> toMap() {
    return {
      'routineId': routineId,
      'form': form.name,
      'route': route?.name,
      'doseAmount': doseAmount,
      'doseUnit': doseUnit?.name,
      'strength': strength,
      'activeIngredient': activeIngredient,
      'foodRelation': foodRelation.name,
      'startDate': startDate,
      'endDate': endDate,
      'isChronic': isChronic ? 1 : 0,
      'durationDays': durationDays,
      'prescriberName': prescriberName,
      'instructions': instructions,
      'criticality': criticality.name,
      'packageSize': packageSize,
      'packageUnit': packageUnit,
      'remainingAmount': remainingAmount,
      'refillThresholdAmount': refillThresholdAmount,
      'injectionSites': jsonEncode(injectionSites),
      'lastInjectionSite': lastInjectionSite,
      'needsSiteRotation': needsSiteRotation ? 1 : 0,
    };
  }

  factory MedicationProfile.fromMap(Map<String, dynamic> map) {
    List<String> parsedSites = [];
    final sitesRaw = map['injectionSites'];
    if (sitesRaw is String && sitesRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(sitesRaw);
        if (decoded is List) {
          parsedSites = decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {}
    } else if (sitesRaw is List) {
      parsedSites = sitesRaw.map((e) => e.toString()).toList();
    }

    return MedicationProfile(
      routineId: map['routineId'] as String? ?? '',
      form: MedicationForm.fromString(map['form'] as String?),
      route: MedicationRoute.fromString(map['route'] as String?),
      doseAmount: (map['doseAmount'] as num?)?.toDouble(),
      doseUnit: map['doseUnit'] != null
          ? DoseUnit.fromString(map['doseUnit'] as String?)
          : null,
      strength: map['strength'] as String?,
      activeIngredient: map['activeIngredient'] as String?,
      foodRelation: FoodRelation.fromString(map['foodRelation'] as String?),
      startDate: map['startDate'] as int?,
      endDate: map['endDate'] as int?,
      isChronic: map['isChronic'] == 1 || map['isChronic'] == true,
      durationDays: map['durationDays'] as int?,
      prescriberName: map['prescriberName'] as String?,
      instructions: map['instructions'] as String?,
      criticality: MedicationCriticality.fromString(
        map['criticality'] as String?,
      ),
      packageSize: (map['packageSize'] as num?)?.toDouble(),
      packageUnit: map['packageUnit'] as String?,
      remainingAmount: (map['remainingAmount'] as num?)?.toDouble(),
      refillThresholdAmount: (map['refillThresholdAmount'] as num?)?.toDouble(),
      injectionSites: parsedSites,
      lastInjectionSite: map['lastInjectionSite'] as String?,
      needsSiteRotation:
          map['needsSiteRotation'] == 1 || map['needsSiteRotation'] == true,
    );
  }

  MedicationProfile copyWith({
    String? routineId,
    MedicationForm? form,
    Object? route = _sentinel,
    Object? doseAmount = _sentinel,
    Object? doseUnit = _sentinel,
    Object? strength = _sentinel,
    Object? activeIngredient = _sentinel,
    FoodRelation? foodRelation,
    Object? startDate = _sentinel,
    Object? endDate = _sentinel,
    bool? isChronic,
    Object? durationDays = _sentinel,
    Object? prescriberName = _sentinel,
    Object? instructions = _sentinel,
    MedicationCriticality? criticality,
    Object? packageSize = _sentinel,
    Object? packageUnit = _sentinel,
    Object? remainingAmount = _sentinel,
    Object? refillThresholdAmount = _sentinel,
    List<String>? injectionSites,
    Object? lastInjectionSite = _sentinel,
    bool? needsSiteRotation,
  }) {
    return MedicationProfile(
      routineId: routineId ?? this.routineId,
      form: form ?? this.form,
      route: identical(route, _sentinel)
          ? this.route
          : (route as MedicationRoute?),
      doseAmount: identical(doseAmount, _sentinel)
          ? this.doseAmount
          : (doseAmount as double?),
      doseUnit: identical(doseUnit, _sentinel)
          ? this.doseUnit
          : (doseUnit as DoseUnit?),
      strength: identical(strength, _sentinel)
          ? this.strength
          : (strength as String?),
      activeIngredient: identical(activeIngredient, _sentinel)
          ? this.activeIngredient
          : (activeIngredient as String?),
      foodRelation: foodRelation ?? this.foodRelation,
      startDate: identical(startDate, _sentinel)
          ? this.startDate
          : (startDate as int?),
      endDate: identical(endDate, _sentinel) ? this.endDate : (endDate as int?),
      isChronic: isChronic ?? this.isChronic,
      durationDays: identical(durationDays, _sentinel)
          ? this.durationDays
          : (durationDays as int?),
      prescriberName: identical(prescriberName, _sentinel)
          ? this.prescriberName
          : (prescriberName as String?),
      instructions: identical(instructions, _sentinel)
          ? this.instructions
          : (instructions as String?),
      criticality: criticality ?? this.criticality,
      packageSize: identical(packageSize, _sentinel)
          ? this.packageSize
          : (packageSize as double?),
      packageUnit: identical(packageUnit, _sentinel)
          ? this.packageUnit
          : (packageUnit as String?),
      remainingAmount: identical(remainingAmount, _sentinel)
          ? this.remainingAmount
          : (remainingAmount as double?),
      refillThresholdAmount: identical(refillThresholdAmount, _sentinel)
          ? this.refillThresholdAmount
          : (refillThresholdAmount as double?),
      injectionSites: injectionSites ?? this.injectionSites,
      lastInjectionSite: identical(lastInjectionSite, _sentinel)
          ? this.lastInjectionSite
          : (lastInjectionSite as String?),
      needsSiteRotation: needsSiteRotation ?? this.needsSiteRotation,
    );
  }

  /// دوز فرمت‌شده با برچسب فارسی واحد
  String get formattedDose {
    final amount = doseAmount;
    final unit = doseUnit ?? form.defaultUnit;
    if (amount != null && amount > 0) {
      final formattedAmount = amount == amount.toInt()
          ? amount.toInt().toString()
          : amount.toString();
      return '$formattedAmount ${unit.shortLabelFa}';
    }
    return form.labelFa;
  }
}

/// موجودیت کامل و یکپارچه دارو در اپلیکیشن
class Medication {
  const Medication({
    required this.id,
    required this.name,
    this.description,
    this.category = 'medical',
    this.routineType = 'timeBased',
    this.isEssential = true,
    this.isArchived = false,
    this.isPrivate = false,
    this.minIntervalHours = 0,
    this.maxDosesPerDay = 0,
    required this.createdAt,
    required this.updatedAt,
    required this.profile,
    this.scheduleMap,
  });

  final String id;
  final String name;
  final String? description;
  final String category;
  final String routineType; // 'timeBased' | 'asNeeded'
  final bool isEssential;
  final bool isArchived;
  final bool isPrivate;
  final int minIntervalHours;
  final int maxDosesPerDay;
  final int createdAt;
  final int updatedAt;
  final MedicationProfile profile;
  final Map<String, dynamic>? scheduleMap;

  bool get isPrn => routineType == 'asNeeded';
  bool get isPRN => isPrn;

  /// نمایش مقدار و واحد دوز
  String get displayDose {
    final amount = profile.doseAmount;
    final unit = profile.doseUnit ?? profile.form.defaultUnit;
    if (amount != null && amount > 0) {
      final formattedAmount = amount == amount.toInt()
          ? amount.toInt().toString()
          : amount.toString();
      return '$formattedAmount ${unit.shortLabelFa}';
    }
    return description ?? profile.form.labelFa;
  }

  /// نمایش کامل دوز و شکل و مسیر
  String get fullDoseDescription {
    final parts = <String>[];
    parts.add(displayDose);
    if (profile.strength != null && profile.strength!.isNotEmpty) {
      parts.add('(${profile.strength})');
    }
    if (profile.route != null) {
      parts.add(profile.route!.labelFa);
    }
    return parts.join(' — ');
  }

  /// نمایش موجودی با واحد
  String? get displayStock {
    if (!profile.hasStockTracking) return null;
    final remaining = profile.remainingAmount ?? 0;
    final formatted = remaining == remaining.toInt()
        ? remaining.toInt().toString()
        : remaining.toStringAsFixed(1);
    final unit = profile.packageUnit ?? profile.doseUnit?.shortLabelFa ?? 'عدد';
    return '$formatted $unit';
  }

  bool get isLowStock => profile.isLowStock;
  bool get isOutOfStock => profile.isOutOfStock;

  factory Medication.fromRoutineAndProfile(
    Map<String, dynamic> routine,
    Map<String, dynamic>? profileMap, {
    Map<String, dynamic>? scheduleMap,
  }) {
    final routineId = routine['id'] as String? ?? '';
    final profile = profileMap != null
        ? MedicationProfile.fromMap(profileMap)
        : MedicationProfile(
            routineId: routineId,
            form: MedicationForm.TABLET,
            route: MedicationRoute.ORAL,
            doseAmount: 1.0,
            doseUnit: DoseUnit.TABLET,
            instructions: routine['description'] as String?,
            isChronic: true,
            remainingAmount: (routine['medStockCount'] as num?)?.toDouble(),
            refillThresholdAmount: (routine['medRefillThreshold'] as num?)
                ?.toDouble(),
            startDate: routine['createdAt'] as int?,
          );

    return Medication(
      id: routineId,
      name: routine['title'] as String? ?? '',
      description: routine['description'] as String?,
      category: routine['category'] as String? ?? 'medical',
      routineType: routine['routineType'] as String? ?? 'timeBased',
      isEssential:
          routine['isEssential'] == 1 || routine['isEssential'] == true,
      isArchived: routine['isArchived'] == 1 || routine['isArchived'] == true,
      isPrivate: routine['isPrivate'] == 1 || routine['isPrivate'] == true,
      minIntervalHours: (routine['minIntervalHours'] as num?)?.toInt() ?? 0,
      maxDosesPerDay: (routine['maxDosesPerDay'] as num?)?.toInt() ?? 0,
      createdAt:
          routine['createdAt'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      updatedAt:
          routine['updatedAt'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      profile: profile,
      scheduleMap: scheduleMap,
    );
  }
}

/// انواع بالینی انسولین
enum InsulinType {
  RAPID_ACTING,
  SHORT_ACTING,
  INTERMEDIATE,
  LONG_ACTING,
  PREMIXED;

  static InsulinType? fromString(String? value) {
    if (value == null || value.isEmpty) return null;
    final upper = value.trim().toUpperCase();
    for (final type in InsulinType.values) {
      if (type.name == upper) return type;
    }
    return null;
  }

  String get labelFa {
    switch (this) {
      case InsulinType.RAPID_ACTING:
        return 'سریع‌الاثر (نوورپید / لیسپرو / آسپارت)';
      case InsulinType.SHORT_ACTING:
        return 'کوتاه‌اثر (رگولار / Regular)';
      case InsulinType.INTERMEDIATE:
        return 'متوسط‌اثر (ان‌پی‌اچ / NPH)';
      case InsulinType.LONG_ACTING:
        return 'طولانی‌اثر / پایه (لانتوس / لومیر / دگلودک)';
      case InsulinType.PREMIXED:
        return 'مخلوط (نوومیکس / مخلوط رگولار+NPH)';
    }
  }

  String get timingInstructionFa {
    switch (this) {
      case InsulinType.RAPID_ACTING:
        return 'درست قبل از شروع وعده غذایی یا بلافاصله پس از آن تزریق شود.';
      case InsulinType.SHORT_ACTING:
        return 'حدود ۳۰ دقیقه قبل از وعده غذایی تزریق شود.';
      case InsulinType.INTERMEDIATE:
        return 'معمولاً قبل از صبحانه یا شام با دوز ثابت تزریق می‌شود.';
      case InsulinType.LONG_ACTING:
        return 'یک‌بار در روز در زمان کاملاً ثابت (مثلاً هر شب ساعت ۲۲) تزریق شود.';
      case InsulinType.PREMIXED:
        return 'معمولاً ۱۵ تا ۳۰ دقیقه قبل از وعده‌های اصلی غذا تزریق شود.';
    }
  }
}

/// محل‌های استاندارد تزریق زیرجلدی (جهت چرخش دوره‌ای محل تزریق انسولین)
enum InjectionSite {
  ABDOMEN_RIGHT,
  ABDOMEN_LEFT,
  ARM_RIGHT,
  ARM_LEFT,
  THIGH_RIGHT,
  THIGH_LEFT,
  BUTTOCK_RIGHT,
  BUTTOCK_LEFT;

  static InjectionSite? fromString(String? value) {
    if (value == null || value.isEmpty) return null;
    final upper = value.trim().toUpperCase();
    for (final site in InjectionSite.values) {
      if (site.name == upper) return site;
    }
    return null;
  }

  String get labelFa {
    switch (this) {
      case InjectionSite.ABDOMEN_RIGHT:
        return 'شکم (سمت راست)';
      case InjectionSite.ABDOMEN_LEFT:
        return 'شکم (سمت چپ)';
      case InjectionSite.ARM_RIGHT:
        return 'بازوی راست (پشت بازو)';
      case InjectionSite.ARM_LEFT:
        return 'بازوی چپ (پشت بازو)';
      case InjectionSite.THIGH_RIGHT:
        return 'ران راست (بخش قدامی-خارجی)';
      case InjectionSite.THIGH_LEFT:
        return 'ران چپ (بخش قدامی-خارجی)';
      case InjectionSite.BUTTOCK_RIGHT:
        return 'باسن راست (بخش فوقانی-خارجی)';
      case InjectionSite.BUTTOCK_LEFT:
        return 'باسن چپ (بخش فوقانی-خارجی)';
    }
  }
}

/// محل‌های استاندارد استعمال قطره
enum DropApplicationSite {
  EYE_RIGHT,
  EYE_LEFT,
  EYES_BOTH,
  EAR_RIGHT,
  EAR_LEFT,
  EARS_BOTH,
  NOSE_RIGHT,
  NOSE_LEFT,
  NOSE_BOTH;

  static DropApplicationSite? fromString(String? value) {
    if (value == null || value.isEmpty) return null;
    final upper = value.trim().toUpperCase();
    for (final site in DropApplicationSite.values) {
      if (site.name == upper) return site;
    }
    return null;
  }

  String get labelFa {
    switch (this) {
      case DropApplicationSite.EYE_RIGHT:
        return 'چشم راست';
      case DropApplicationSite.EYE_LEFT:
        return 'چشم چپ';
      case DropApplicationSite.EYES_BOTH:
        return 'هر دو چشم';
      case DropApplicationSite.EAR_RIGHT:
        return 'گوش راست';
      case DropApplicationSite.EAR_LEFT:
        return 'گوش چپ';
      case DropApplicationSite.EARS_BOTH:
        return 'هر دو گوش';
      case DropApplicationSite.NOSE_RIGHT:
        return 'سوراخ راست بینی';
      case DropApplicationSite.NOSE_LEFT:
        return 'سوراخ چپ بینی';
      case DropApplicationSite.NOSE_BOTH:
        return 'هر دو سوراخ بینی';
    }
  }
}

/// راهنما و نکات بالینی ایمنی اشکال دارویی غیرقرصی
class ClinicalFormHelper {
  static String? getClinicalEducationNote(
    MedicationForm form, {
    MedicationRoute? route,
    DropApplicationSite? dropSite,
  }) {
    switch (form) {
      case MedicationForm.INSULIN:
        return 'جهت جلوگیری از لیپوهایپرتروفی (سفت شدن بافت چربی)، محل تزریق را هر بار با فاصله حداقل ۲ سانتی‌متر از محل قبلی بچرخانید و همیشه قبل از تزریق از عدم وجود حباب هوا مطمئن شوید.';
      case MedicationForm.INHALER:
        return 'در صورت استفاده از کورتیکواستروئید استنشاقی، پس از هر بار مصرف دهان و گلوی خود را با آب بشویید تا از ایجاد برفک دهانی و گرفتگی صدا پیشگیری شود.';
      case MedicationForm.SPRAY:
        if (route == MedicationRoute.INHALED) {
          return 'در صورت استفاده از کورتیکواستروئید استنشاقی، پس از هر بار مصرف دهان و گلوی خود را با آب بشویید تا از ایجاد برفک دهانی و گرفتگی صدا پیشگیری شود.';
        }
        return 'قبل از مصرف، مجرای بینی را تمیز کرده، سر را کمی به جلو متمایل کنید و سر افشانه را به سمت دیواره خارجی بینی اسپری کنید.';
      case MedicationForm.PATCH:
        return 'پچ را روی پوست تمیز، خشک، بدون مو و سالم بچسبانید. هر بار محل چسباندن پچ را تغییر دهید و حداقل تا ۷ روز روی همان نقطه قبلی نچسبانید.';
      case MedicationForm.DROPS:
        if (route == MedicationRoute.OTIC ||
            dropSite == DropApplicationSite.EAR_RIGHT ||
            dropSite == DropApplicationSite.EAR_LEFT ||
            dropSite == DropApplicationSite.EARS_BOTH) {
          return 'سر را به یک سمت خم کرده، قطره را در مجرای گوش بچکانید و ۲ تا ۳ دقیقه در همان حالت بمانید تا دارو به عمق مجرا نفوذ کند.';
        }
        if (route == MedicationRoute.NASAL ||
            dropSite == DropApplicationSite.NOSE_RIGHT ||
            dropSite == DropApplicationSite.NOSE_LEFT ||
            dropSite == DropApplicationSite.NOSE_BOTH) {
          return 'سر را به آرامی به عقب متمایل کرده و پس از چکاندن قطره در مجرای بینی، چند ثانیه از دهان نفس بکشید.';
        }
        return 'پس از چکاندن قطره چشمی، گوشه داخلی چشم (مجرای اشکی) را به مدت ۱ دقیقه به آرامی با انگشت فشار دهید تا از خروج دارو و جذب سیستمیک جلوگیری شود.';
      default:
        return null;
    }
  }
}
