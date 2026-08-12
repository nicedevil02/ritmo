// lib/features/supplementary_sports/movement/presentation/session/session_surface.dart

import 'package:flutter/material.dart';
import 'package:ritmo/features/supplementary_sports/movement/domain/movement_kind.dart';
import 'package:ritmo/features/supplementary_sports/movement/domain/session_mode.dart';
import 'package:ritmo/features/supplementary_sports/movement/presentation/session/movement_session_notifier.dart';
import 'package:ritmo/features/supplementary_sports/movement/presentation/session/movement_session_screen.dart';
import 'package:ritmo/features/supplementary_sports/movement/presentation/session/session_shell.dart';
import 'package:ritmo/features/supplementary_sports/movement/presentation/session/session_template.dart';
import 'package:ritmo/features/supplementary_sports/movement/presentation/session/session_template_router.dart';

/// تنها جایی که تصمیم می‌گیرد جلسه با پوستهٔ جدید نمایش داده شود یا مسیر قدیمی.
///
/// با این لایه، مهاجرت ورزش‌ها به پوستهٔ مشترک یکی‌یکی و بدون دست زدن به تمام
/// صفحهٔ قدیمی انجام می‌شود؛ هر حالتی که قالب ندارد دقیقاً مانند قبل کار می‌کند.
class MovementSessionSurface extends StatelessWidget {
	const MovementSessionSurface({
		super.key,
		required this.notifier,
		required this.kind,
		required this.mode,
	});

	final MovementSessionNotifier notifier;
	final MovementKind kind;
	final SessionMode mode;

	@override
	Widget build(BuildContext context) {
		final SessionTemplate? template = sessionTemplateFor(mode);
		if (template != null) {
			return SessionShell(
				notifier: notifier,
				kind: kind,
				mode: mode,
				template: template,
			);
		}
		return MovementSessionScaffold(
			notifier: notifier,
			kind: kind,
			mode: mode,
		);
	}
}
