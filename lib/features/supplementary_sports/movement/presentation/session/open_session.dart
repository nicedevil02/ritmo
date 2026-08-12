// lib/features/supplementary_sports/movement/presentation/session/open_session.dart

import 'package:flutter/material.dart';
import 'package:ritmo/features/supplementary_sports/movement/domain/movement_kind.dart';
import 'package:ritmo/features/supplementary_sports/movement/domain/movement_session.dart';
import 'package:ritmo/features/supplementary_sports/movement/presentation/session/movement_session_screen.dart';

/// تنها دروازهٔ ورود به صفحهٔ جلسه.
///
/// هر جای اپ که می‌خواهد جلسه‌ای را باز کند — تب حرکت، داشبورد، یادآور، برنامهٔ روز —
/// باید همین تابع را صدا بزند؛ نه مستقیم Navigator.push با صفحهٔ داخلی.
/// این‌طور انتخاب قالب و رفتار جلسه فقط یک جا تعریف می‌شود.
Future<void> openMovementSession(
	BuildContext context, {
	required MovementSession session,
	required MovementKind kind,
}) {
	return Navigator.of(context).push<void>(
		MaterialPageRoute<void>(
			builder: (_) => MovementSessionScreen(session: session, kind: kind),
		),
	);
}
