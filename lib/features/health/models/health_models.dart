import 'package:flutter/material.dart';
export 'medication_models.dart';

class DoctorVisit {

  DoctorVisit({
    required this.id,
    required this.doctorName,
    this.specialty,
    this.clinicName,
    this.clinicAddress,
    this.clinicPhone,
    required this.visitDateTime,
    this.visitType = 'IN_PERSON',
    this.status = 'UPCOMING',
    this.reason,
    this.doctorNotes,
    this.userNotes,
    this.followUpDate,
    this.reminderBefore = 60,
    this.attachmentPath,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DoctorVisit.fromMap(Map<String, dynamic> map) {
    return DoctorVisit(
      id: map['id'] as String,
      doctorName: map['doctorName'] as String,
      specialty: map['specialty'] as String?,
      clinicName: map['clinicName'] as String?,
      clinicAddress: map['clinicAddress'] as String?,
      clinicPhone: map['clinicPhone'] as String?,
      visitDateTime: map['visitDateTime'] as int,
      visitType: map['visitType'] as String? ?? 'IN_PERSON',
      status: map['status'] as String? ?? 'UPCOMING',
      reason: map['reason'] as String?,
      doctorNotes: map['doctorNotes'] as String?,
      userNotes: map['userNotes'] as String?,
      followUpDate: map['followUpDate'] as int?,
      reminderBefore: map['reminderBefore'] as int? ?? 60,
      attachmentPath: map['attachmentPath'] as String?,
      createdAt: map['createdAt'] as int,
      updatedAt: map['updatedAt'] as int,
    );
  }
  final String id;
  final String doctorName;
  final String? specialty;
  final String? clinicName;
  final String? clinicAddress;
  final String? clinicPhone;
  final int visitDateTime; // epoch ms
  final String visitType; // 'IN_PERSON' | 'ONLINE' | 'TELEPHONE'
  final String status; // 'UPCOMING' | 'COMPLETED' | 'CANCELLED'
  final String? reason;
  final String? doctorNotes;
  final String? userNotes;
  final int? followUpDate; // epoch ms
  final int reminderBefore; // minutes
  final String? attachmentPath;
  final int createdAt;
  final int updatedAt;

  bool get isUpcoming => visitDateTime > DateTime.now().millisecondsSinceEpoch && status == 'UPCOMING';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'doctorName': doctorName,
      'specialty': specialty,
      'clinicName': clinicName,
      'clinicAddress': clinicAddress,
      'clinicPhone': clinicPhone,
      'visitDateTime': visitDateTime,
      'visitType': visitType,
      'status': status,
      'reason': reason,
      'doctorNotes': doctorNotes,
      'userNotes': userNotes,
      'followUpDate': followUpDate,
      'reminderBefore': reminderBefore,
      'attachmentPath': attachmentPath,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }
}

class BloodSugarLog { // epoch ms

  BloodSugarLog({
    required this.id,
    required this.value,
    this.measurementType = 'FASTING',
    this.note,
    required this.loggedAt,
  });

  factory BloodSugarLog.fromMap(Map<String, dynamic> map) {
    return BloodSugarLog(
      id: map['id'] as String,
      value: map['value'] as int,
      measurementType: map['measurementType'] as String? ?? 'FASTING',
      note: map['note'] as String?,
      loggedAt: map['loggedAt'] as int,
    );
  }
  final String id;
  final int value;
  final String measurementType; // 'FASTING' | 'BEFORE_MEAL' | 'AFTER_MEAL' | 'BEDTIME' | 'RANDOM'
  final String? note;
  final int loggedAt;

  String get categoryLabel {
    switch (measurementType) {
      case 'FASTING':
        return 'ناشتا';
      case 'BEFORE_MEAL':
        return 'قبل غذا';
      case 'AFTER_MEAL':
        return 'بعد غذا';
      case 'BEDTIME':
        return 'قبل خواب';
      case 'RANDOM':
      default:
        return 'تصادفی';
    }
  }

  Color get categoryColor {
    switch (measurementType) {
      case 'FASTING':
        return const Color(0xFF06B6D4); // Cyan
      case 'BEFORE_MEAL':
        return const Color(0xFF6366F1); // Indigo
      case 'AFTER_MEAL':
        return const Color(0xFFF59E0B); // Amber/Orange
      case 'BEDTIME':
        return const Color(0xFF8B5CF6); // Purple
      case 'RANDOM':
      default:
        return const Color(0xFFEC4899); // Pink
    }
  }

  Map<String, int> targetRange(bool isDiabetic) {
    return BloodSugarTargetRange.forCategory(measurementType, isDiabetic: isDiabetic).toMap();
  }

  String getStatus(bool isDiabetic) {
    final range = BloodSugarTargetRange.forCategory(measurementType, isDiabetic: isDiabetic);
    if (value < 70) return 'LOW';
    if (value > range.max) return 'HIGH';
    if (value < range.min) return 'LOW';
    return 'NORMAL';
  }

  bool isInRange(int minVal, int maxVal) {
    return value >= minVal && value <= maxVal;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'value': value,
      'measurementType': measurementType,
      'note': note,
      'loggedAt': loggedAt,
    };
  }
}

class BloodSugarTargetRange {
  const BloodSugarTargetRange({required this.min, required this.max});

  final int min;
  final int max;

  Map<String, int> toMap() => {'min': min, 'max': max};

  static BloodSugarTargetRange forCategory(String category, {required bool isDiabetic}) {
    if (isDiabetic) {
      switch (category) {
        case 'FASTING':
        case 'BEFORE_MEAL':
          return const BloodSugarTargetRange(min: 80, max: 130);
        case 'AFTER_MEAL':
          return const BloodSugarTargetRange(min: 80, max: 180);
        case 'BEDTIME':
          return const BloodSugarTargetRange(min: 100, max: 150);
        case 'RANDOM':
        default:
          return const BloodSugarTargetRange(min: 80, max: 180);
      }
    } else {
      switch (category) {
        case 'FASTING':
          return const BloodSugarTargetRange(min: 70, max: 100);
        case 'BEFORE_MEAL':
          return const BloodSugarTargetRange(min: 70, max: 110);
        case 'AFTER_MEAL':
          return const BloodSugarTargetRange(min: 70, max: 140);
        case 'BEDTIME':
          return const BloodSugarTargetRange(min: 100, max: 140);
        case 'RANDOM':
        default:
          return const BloodSugarTargetRange(min: 70, max: 140);
      }
    }
  }
}

class BloodSugarStats {
  const BloodSugarStats({
    required this.averageGlucose,
    this.averageFasting,
    required this.minGlucose,
    required this.maxGlucose,
    required this.totalCount,
    required this.inRangePercentage,
    required this.highPercentage,
    required this.lowPercentage,
    this.estimatedHbA1c,
  });

  final double averageGlucose;
  final double? averageFasting;
  final int minGlucose;
  final int maxGlucose;
  final int totalCount;
  final double inRangePercentage;
  final double highPercentage;
  final double lowPercentage;
  final double? estimatedHbA1c;

  static BloodSugarStats? compute(List<BloodSugarLog> logs, {required bool isDiabetic}) {
    if (logs.isEmpty) return null;

    int sum = 0;
    int minG = logs.first.value;
    int maxG = logs.first.value;

    int fastingSum = 0;
    int fastingCount = 0;

    int inRangeCount = 0;
    int highCount = 0;
    int lowCount = 0;

    for (final log in logs) {
      sum += log.value;
      if (log.value < minG) minG = log.value;
      if (log.value > maxG) maxG = log.value;

      if (log.measurementType == 'FASTING') {
        fastingSum += log.value;
        fastingCount++;
      }

      final status = log.getStatus(isDiabetic);
      if (status == 'NORMAL') {
        inRangeCount++;
      } else if (status == 'HIGH') {
        highCount++;
      } else {
        lowCount++;
      }
    }

    final avg = sum / logs.length;
    final avgFasting = fastingCount > 0 ? (fastingSum / fastingCount) : null;
    final inRangePct = (inRangeCount / logs.length) * 100;
    final highPct = (highCount / logs.length) * 100;
    final lowPct = (lowCount / logs.length) * 100;

    // ADA eAG to HbA1c formula: HbA1c = (eAG + 46.7) / 28.7
    final hba1c = (avg + 46.7) / 28.7;

    return BloodSugarStats(
      averageGlucose: avg,
      averageFasting: avgFasting,
      minGlucose: minG,
      maxGlucose: maxG,
      totalCount: logs.length,
      inRangePercentage: inRangePct,
      highPercentage: highPct,
      lowPercentage: lowPct,
      estimatedHbA1c: hba1c,
    );
  }
}

class BloodPressureLog { // epoch ms

  BloodPressureLog({
    required this.id,
    required this.systolic,
    required this.diastolic,
    this.pulse,
    this.arm = 'LEFT',
    this.position = 'SITTING',
    this.note,
    required this.loggedAt,
  });

  factory BloodPressureLog.fromMap(Map<String, dynamic> map) {
    return BloodPressureLog(
      id: map['id'] as String,
      systolic: map['systolic'] as int,
      diastolic: map['diastolic'] as int,
      pulse: map['pulse'] as int?,
      arm: map['arm'] as String? ?? 'LEFT',
      position: map['position'] as String? ?? 'SITTING',
      note: map['note'] as String?,
      loggedAt: map['loggedAt'] as int,
    );
  }
  final String id;
  final int systolic;
  final int diastolic;
  final int? pulse;
  final String arm; // 'LEFT' | 'RIGHT'
  final String position; // 'SITTING' | 'LYING' | 'STANDING'
  final String? note;
  final int loggedAt;

  String get stageLabel {
    if (systolic > 180 || diastolic > 120) {
      return 'بحران فشار خون';
    }
    if (systolic >= 140 || diastolic >= 90) {
      return 'فشار خون مرحله ۲';
    }
    if ((systolic >= 130 && systolic <= 139) || (diastolic >= 80 && diastolic <= 89)) {
      return 'فشار خون مرحله ۱';
    }
    if (systolic >= 120 && systolic <= 129 && diastolic < 80) {
      return 'پیش فشار خون';
    }
    return 'نرمال';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'systolic': systolic,
      'diastolic': diastolic,
      'pulse': pulse,
      'arm': arm,
      'position': position,
      'note': note,
      'loggedAt': loggedAt,
    };
  }
}

class VitalSignLog { // epoch ms

  VitalSignLog({
    required this.id,
    required this.vitalType,
    required this.value,
    required this.unit,
    this.note,
    required this.loggedAt,
  });

  factory VitalSignLog.fromMap(Map<String, dynamic> map) {
    return VitalSignLog(
      id: map['id'] as String,
      vitalType: map['vitalType'] as String,
      value: (map['value'] as num).toDouble(),
      unit: map['unit'] as String,
      note: map['note'] as String?,
      loggedAt: map['loggedAt'] as int,
    );
  }
  final String id;
  final String vitalType; // 'WEIGHT' | 'TEMPERATURE' | 'SPO2' | 'WAIST'
  final double value;
  final String unit;
  final String? note;
  final int loggedAt;

  String get formattedValue => '$value $unit';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'vitalType': vitalType,
      'value': value,
      'unit': unit,
      'note': note,
      'loggedAt': loggedAt,
    };
  }
}

class MedicalDocument {

  MedicalDocument({
    required this.id,
    required this.title,
    required this.category,
    required this.documentDate,
    this.labName,
    this.summary,
    this.doctorNotes,
    this.userNotes,
    required this.createdAt,
    required this.updatedAt,
    this.imageCount = 0,
  });

  factory MedicalDocument.fromMap(Map<String, dynamic> map) {
    return MedicalDocument(
      id: map['id'] as String,
      title: map['title'] as String,
      category: map['category'] as String,
      documentDate: map['documentDate'] as int,
      labName: map['labName'] as String?,
      summary: map['summary'] as String?,
      doctorNotes: map['doctorNotes'] as String?,
      userNotes: map['userNotes'] as String?,
      createdAt: map['createdAt'] as int,
      updatedAt: map['updatedAt'] as int,
    );
  }
  final String id;
  final String title;
  final String category; // 'BLOOD_TEST' | 'URINE_TEST' | 'IMAGING' | 'PATHOLOGY' | 'SONOGRAPHY' | 'PRESCRIPTION' | 'OTHER'
  final int documentDate; // epoch ms
  final String? labName;
  final String? summary;
  final String? doctorNotes;
  final String? userNotes;
  final int createdAt;
  final int updatedAt;
  int imageCount;

  String get categoryLabel {
    switch (category) {
      case 'BLOOD_TEST':
        return 'آزمایش خون';
      case 'URINE_TEST':
        return 'آزمایش ادرار';
      case 'IMAGING':
        return 'تصویربرداری';
      case 'PATHOLOGY':
        return 'پاتولوژی';
      case 'SONOGRAPHY':
        return 'سونوگرافی';
      case 'PRESCRIPTION':
        return 'نسخه پزشک';
      case 'OTHER':
      default:
        return 'سایر مدارک';
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'category': category,
      'documentDate': documentDate,
      'labName': labName,
      'summary': summary,
      'doctorNotes': doctorNotes,
      'userNotes': userNotes,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }
}

class MedicalDocumentImage {

  MedicalDocumentImage({
    required this.id,
    required this.documentId,
    required this.imagePath,
    this.pageNumber = 1,
    this.caption,
  });

  factory MedicalDocumentImage.fromMap(Map<String, dynamic> map) {
    return MedicalDocumentImage(
      id: map['id'] as String,
      documentId: map['documentId'] as String,
      imagePath: map['imagePath'] as String,
      pageNumber: map['pageNumber'] as int? ?? 1,
      caption: map['caption'] as String?,
    );
  }
  final String id;
  final String documentId;
  final String imagePath;
  final int pageNumber;
  final String? caption;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'documentId': documentId,
      'imagePath': imagePath,
      'pageNumber': pageNumber,
      'caption': caption,
    };
  }
}

class Vaccination {

  Vaccination({
    required this.id,
    required this.vaccineName,
    this.diseaseTarget,
    this.doseNumber = 1,
    this.totalDoses,
    this.dateAdministered,
    this.nextDoseDue,
    this.batchNumber,
    this.clinicName,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Vaccination.fromMap(Map<String, dynamic> map) {
    return Vaccination(
      id: map['id'] as String,
      vaccineName: map['vaccineName'] as String,
      diseaseTarget: map['diseaseTarget'] as String?,
      doseNumber: map['doseNumber'] as int? ?? 1,
      totalDoses: map['totalDoses'] as int?,
      dateAdministered: map['dateAdministered'] as int?,
      nextDoseDue: map['nextDoseDue'] as int?,
      batchNumber: map['batchNumber'] as String?,
      clinicName: map['clinicName'] as String?,
      notes: map['notes'] as String?,
      createdAt: map['createdAt'] as int,
      updatedAt: map['updatedAt'] as int,
    );
  }
  final String id;
  final String vaccineName;
  final String? diseaseTarget;
  final int doseNumber;
  final int? totalDoses;
  final int? dateAdministered; // epoch ms
  final int? nextDoseDue; // epoch ms
  final String? batchNumber;
  final String? clinicName;
  final String? notes;
  final int createdAt;
  final int updatedAt;

  bool get isDue => nextDoseDue != null && nextDoseDue! < DateTime.now().millisecondsSinceEpoch;

  int? get daysUntilNextDose {
    if (nextDoseDue == null) return null;
    final diffMs = nextDoseDue! - DateTime.now().millisecondsSinceEpoch;
    return (diffMs / (1000 * 60 * 60 * 24)).ceil();
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'vaccineName': vaccineName,
      'diseaseTarget': diseaseTarget,
      'doseNumber': doseNumber,
      'totalDoses': totalDoses,
      'dateAdministered': dateAdministered,
      'nextDoseDue': nextDoseDue,
      'batchNumber': batchNumber,
      'clinicName': clinicName,
      'notes': notes,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }
}

class Allergy {

  Allergy({
    required this.id,
    required this.allergen,
    required this.category,
    this.reaction,
    this.severity = 'MODERATE',
    this.diagnosedDate,
    this.notes,
    required this.createdAt,
  });

  factory Allergy.fromMap(Map<String, dynamic> map) {
    return Allergy(
      id: map['id'] as String,
      allergen: map['allergen'] as String,
      category: map['category'] as String,
      reaction: map['reaction'] as String?,
      severity: map['severity'] as String? ?? 'MODERATE',
      diagnosedDate: map['diagnosedDate'] as int?,
      notes: map['notes'] as String?,
      createdAt: map['createdAt'] as int,
    );
  }
  final String id;
  final String allergen;
  final String category; // 'FOOD' | 'DRUG' | 'ENVIRONMENT' | 'OTHER'
  final String? reaction;
  final String severity; // 'MILD' | 'MODERATE' | 'SEVERE' | 'LIFE_THREATENING'
  final int? diagnosedDate; // epoch ms
  final String? notes;
  final int createdAt;

  String get severityLabel {
    switch (severity) {
      case 'MILD':
        return 'خفیف';
      case 'SEVERE':
        return 'شدید';
      case 'LIFE_THREATENING':
        return 'تهدیدکننده حیات';
      case 'MODERATE':
      default:
        return 'متوسط';
    }
  }

  Color get severityColor {
    switch (severity) {
      case 'MILD':
        return Colors.green;
      case 'MODERATE':
        return Colors.orange;
      case 'SEVERE':
        return Colors.red;
      case 'LIFE_THREATENING':
        return const Color(0xffD85A50);
      default:
        return Colors.blue;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'allergen': allergen,
      'category': category,
      'reaction': reaction,
      'severity': severity,
      'diagnosedDate': diagnosedDate,
      'notes': notes,
      'createdAt': createdAt,
    };
  }
}

class MedicalProfile {

  MedicalProfile({
    required this.id,
    required this.profileKey,
    required this.profileValue,
    required this.updatedAt,
  });

  factory MedicalProfile.fromMap(Map<String, dynamic> map) {
    return MedicalProfile(
      id: map['id'] as String,
      profileKey: map['profileKey'] as String,
      profileValue: map['profileValue'] as String,
      updatedAt: map['updatedAt'] as int,
    );
  }
  final String id;
  final String profileKey;
  final String profileValue;
  final int updatedAt;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'profileKey': profileKey,
      'profileValue': profileValue,
      'updatedAt': updatedAt,
    };
  }
}

class MedicationLog {

  MedicationLog({
    required this.id,
    required this.routineId,
    this.scheduledTime,
    this.takenTime,
    this.status = 'TAKEN',
    this.note,
    required this.createdAt,
  });

  factory MedicationLog.fromMap(Map<String, dynamic> map) {
    return MedicationLog(
      id: map['id'] as String,
      routineId: map['routineId'] as String,
      scheduledTime: map['scheduledTime'] as int?,
      takenTime: map['takenTime'] as int?,
      status: map['status'] as String? ?? 'TAKEN',
      note: map['note'] as String?,
      createdAt: map['createdAt'] as int,
    );
  }
  final String id;
  final String routineId;
  final int? scheduledTime;
  final int? takenTime;
  final String status; // 'TAKEN' | 'SKIPPED'
  final String? note;
  final int createdAt;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'routineId': routineId,
      'scheduledTime': scheduledTime,
      'takenTime': takenTime,
      'status': status,
      'note': note,
      'createdAt': createdAt,
    };
  }
}

class TrendPoint {

  TrendPoint({
    required this.dateIso,
    required this.value,
  });
  final String dateIso;
  final double value;
}

class VitalTrend {

  VitalTrend({
    required this.metric,
    required this.points,
    required this.average,
    required this.direction,
    required this.inRangePercent,
  });
  final String metric;
  final List<TrendPoint> points;
  final double average;
  final String direction; // 'up' | 'down' | 'stable'
  final double inRangePercent;
}

class AdherenceStats {

  AdherenceStats({
    required this.adherenceRate,
    required this.currentStreak,
    required this.longestStreak,
    this.missedPattern,
  });
  final double adherenceRate;
  final int currentStreak;
  final int longestStreak;
  final String? missedPattern;
}

class HealthCorrelation {

  HealthCorrelation({
    required this.metric,
    this.coefficient,
    required this.insight,
  });
  final String metric;
  final double? coefficient;
  final String insight;
}

class DoctorVisitSummary {

  DoctorVisitSummary({
    required this.generatedAtIso,
    required this.medications,
    required this.lastVitals,
    required this.trends,
    required this.allergies,
    required this.recentSymptoms,
  });
  final String generatedAtIso;
  final List<String> medications;
  final Map<String, String> lastVitals;
  final List<String> trends;
  final List<String> allergies;
  final List<String> recentSymptoms;
}

