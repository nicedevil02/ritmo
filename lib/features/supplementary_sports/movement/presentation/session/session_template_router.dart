// lib/features/supplementary_sports/movement/presentation/session/session_template_router.dart

import 'package:ritmo/features/supplementary_sports/movement/domain/session_mode.dart';
import 'package:ritmo/features/supplementary_sports/movement/presentation/session/session_template.dart';
import 'package:ritmo/features/supplementary_sports/movement/presentation/session/templates/distance_session_template.dart';
import 'package:ritmo/features/supplementary_sports/movement/presentation/session/templates/laps_session_template.dart';
import 'package:ritmo/features/supplementary_sports/movement/presentation/session/templates/match_session_template.dart';
import 'package:ritmo/features/supplementary_sports/movement/presentation/session/templates/route_session_template.dart';
import 'package:ritmo/features/supplementary_sports/movement/presentation/session/templates/timed_session_template.dart';

/// مسیریاب قالب جلسه.
///
/// هر حالتی که هنوز قالب اختصاصی ندارد null برمی‌گرداند و صفحهٔ جلسه روی مسیر
/// قدیمی (MovementSessionScaffold) می‌ماند. این یعنی مهاجرت مرحله‌به‌مرحله بدون ریسک.
/// تنها حالتی که هنوز null است: structured — نیازمند بازچینی IA در دور ۴.
SessionTemplate? sessionTemplateFor(SessionMode mode) {
  switch (mode) {
    case SessionMode.route:
      return const RouteSessionTemplate();
    case SessionMode.timed:
      return const TimedSessionTemplate();
    case SessionMode.distance:
      return const DistanceSessionTemplate();
    case SessionMode.laps:
      return const LapsSessionTemplate();
    case SessionMode.match:
      return const MatchSessionTemplate();
    case SessionMode.structured:
    case SessionMode.guided:
    case SessionMode.quickLog:
      // دور ۴: بازچینی IA — فعلاً به صفحهٔ قدرتی / هدایت‌شده مستقیم دسترسی دارد.
      return null;
  }
}

/// آیا این حالت به پوستهٔ مشترک مهاجرت کرده است؟
bool isMigratedToShell(SessionMode mode) => sessionTemplateFor(mode) != null;
