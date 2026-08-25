import 'package:flutter/foundation.dart';

/// دسته‌بندی نسبت بار حاد به مزمن (ACWR) طبق §۴٫۳
enum MvLoadBand {
  low('mv_load_band_low', '< 0.8'),
  optimal('mv_load_band_optimal', '0.8 – 1.3'),
  watch('mv_load_band_watch', '1.3 – 1.5'),
  spike('mv_load_band_spike', '> 1.5');

  final String key;
  final String range;
  const MvLoadBand(this.key, this.range);

  static MvLoadBand fromAcwr(double acwr) {
    if (acwr < 0.8) return MvLoadBand.low;
    if (acwr <= 1.3) return MvLoadBand.optimal;
    if (acwr <= 1.5) return MvLoadBand.watch;
    return MvLoadBand.spike;
  }
}

/// مدل وضعیت بار حاد و مزمن تمرینی (S3-T4 / §۴٫۳)
@immutable
class MvLoadSnapshot {
  final double acuteLoad;
  final double chronicLoad;
  final double acwr;
  final MvLoadBand band;
  final bool hasEnoughData;

  const MvLoadSnapshot({
    required this.acuteLoad,
    required this.chronicLoad,
    required this.acwr,
    required this.band,
    this.hasEnoughData = true,
  });

  /// سقف رشد بار هفتگی (§۴٫۴): ۱۱۰٪ میانگین هفتگی مزمن
  double get plannedWeeklyLoadCap => 1.10 * chronicLoad * 7;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MvLoadSnapshot &&
          runtimeType == other.runtimeType &&
          acuteLoad == other.acuteLoad &&
          chronicLoad == other.chronicLoad &&
          acwr == other.acwr &&
          band == other.band &&
          hasEnoughData == other.hasEnoughData;

  @override
  int get hashCode =>
      acuteLoad.hashCode ^
      chronicLoad.hashCode ^
      acwr.hashCode ^
      band.hashCode ^
      hasEnoughData.hashCode;
}
