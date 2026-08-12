// lib/features/supplementary_sports/movement/domain/session_mode.dart

import 'package:ritmo/features/supplementary_sports/movement/domain/movement_kind.dart';

enum SessionMode {
  timed,       // زمان‌محور: یوگا، تنفس، کشش
  distance,    // مسافت و سرعت: دویدن، دوچرخه
  route,       // مسیر و ارتفاع: کوهنوردی، دوی طبیعت
  laps,        // دور و طول: شنا، دوی پیست
  structured,  // ساختاریافته: بدنسازی، HIIT
  match,       // تیمی: فوتسال، والیبال
}

extension SessionModeCode on SessionMode {
  String get code => name.toUpperCase();
}

/// استنتاج حالت اجرا از متادیتای موجود نوع حرکت.
SessionMode resolveMode(MovementKind k) {
  if (k.family == MovementFamily.strength) return SessionMode.structured;
  if (k.family == MovementFamily.sport && k.isSocial) return SessionMode.match;
  if (k.primaryMetric == MovementMetric.laps) return SessionMode.laps;
  if (k.primaryMetric == MovementMetric.elevation ||
      (k.isOutdoor && k.primaryMetric == MovementMetric.distance)) {
    return SessionMode.route;
  }
  if (k.primaryMetric == MovementMetric.distance ||
      k.primaryMetric == MovementMetric.steps) {
    return SessionMode.distance;
  }
  return SessionMode.timed;
}

SessionMode effectiveMode(MovementKind k) {
  final o = k.sessionModeOverride; // فیلد جدید در مدل
  if (o != null && o.isNotEmpty) {
    return SessionMode.values.firstWhere(
      (m) => m.code == o.toUpperCase(),
      orElse: () => resolveMode(k),
    );
  }
  return resolveMode(k);
}
