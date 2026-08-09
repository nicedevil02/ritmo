/// تنها واژگان کیفیت نماز در کل پروژه.
enum PrayerLogQuality {
  onTime,   // اول وقت   → 'ON_TIME'
  inTime,   // در وقت مقرر → 'IN_TIME'
  qada;     // قضا شده  → 'QADA'

  String get code {
    switch (this) {
      case PrayerLogQuality.onTime:
        return 'ON_TIME';
      case PrayerLogQuality.inTime:
        return 'IN_TIME';
      case PrayerLogQuality.qada:
        return 'QADA';
    }
  }

  String get labelFa {
    switch (this) {
      case PrayerLogQuality.onTime:
        return 'اول وقت';
      case PrayerLogQuality.inTime:
        return 'در وقت مقرر';
      case PrayerLogQuality.qada:
        return 'قضا شده';
    }
  }

  factory PrayerLogQuality.fromCode(String? code) {
    if (code == 'ON_TIME') return PrayerLogQuality.onTime;
    if (code == 'QADA') return PrayerLogQuality.qada;
    return PrayerLogQuality.inTime;
  }
}
