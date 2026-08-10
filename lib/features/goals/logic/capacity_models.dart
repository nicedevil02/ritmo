import 'package:flutter/foundation.dart';

@immutable
class DayLoad {
  const DayLoad({
    required this.dayKey,
    required this.occupiedMinutes,
    required this.fixedCount,
    required this.deepCount,
    this.isTravelDay = false,
    this.userMarkedLight = false,
  });

  final String dayKey;
  final int occupiedMinutes;
  final int fixedCount;
  final int deepCount;
  final bool isTravelDay;
  final bool userMarkedLight;
}

@immutable
class DayCapacity {
  const DayCapacity({
    required this.dayKey,
    required this.rawFreeMinutes,
    required this.usableMinutes,
    required this.committableMinutes,
  });

  final String dayKey;
  final int rawFreeMinutes;
  final int usableMinutes;
  final int committableMinutes;
}

enum ReserveProfile { light, balanced, dense }

extension ReserveProfileX on ReserveProfile {
  double get reserveRatio => switch (this) {
        ReserveProfile.light => 0.35,
        ReserveProfile.balanced => 0.25,
        ReserveProfile.dense => 0.15,
      };
}
