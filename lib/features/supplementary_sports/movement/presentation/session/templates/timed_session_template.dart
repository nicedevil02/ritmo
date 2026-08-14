// lib/features/supplementary_sports/movement/presentation/session/templates/timed_session_template.dart

import 'package:flutter/material.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/ux/ritmo_haptics.dart';
import 'package:ritmo/features/supplementary_sports/movement/domain/movement_session.dart';
import 'package:ritmo/features/supplementary_sports/movement/presentation/session/session_template.dart';
import 'package:ritmo/features/supplementary_sports/movement/presentation/session/session_widgets.dart';

const String _fontFa = 'Vazirmatn';

/// مراحل ثابت هر جلسهٔ زمان‌محور.
const List<_Phase> _phases = <_Phase>[
	_Phase('WARMUP', 'گرم کردن', Icons.whatshot_rounded, Colors.orange),
	_Phase('MAIN', 'تمرین اصلی', Icons.self_improvement_rounded, Colors.teal),
	_Phase('COOLDOWN', 'سرد کردن', Icons.ac_unit_rounded, Colors.lightBlue),
];

class _Phase {
	const _Phase(this.code, this.label, this.icon, this.color);
	final String code;
	final String label;
	final IconData icon;
	final Color color;
}

/// قالب ورزش‌های زمان‌محور: یوگا، پیلاتس، کشش، تای‌چی، تنفس.
///
/// متریک اصلی تایمر است. کاربر می‌تواند مرحله (گرم کردن → اصلی → سرد کردن)، هدف،
/// و کالری تقریبی را در حالت حرفه‌ای ببیند.
class TimedSessionTemplate extends SessionTemplate {
	const TimedSessionTemplate();

	@override
	String get code => 'TIMED';

	@override
	Widget buildHero(BuildContext context, SessionTemplateContext ctx) {
		return Column(
			children: [
				Text(
					toPersianDigits(formatSessionDuration(ctx.elapsedMs)),
					style: const TextStyle(
						fontFamily: _fontFa,
						color: Colors.white,
						fontSize: 62,
						fontWeight: FontWeight.w900,
						letterSpacing: 2,
						height: 1.1,
					),
				),
				const SizedBox(height: 8),
				_PhaseSelector(ctx: ctx),
			],
		);
	}

	@override
	List<SessionStat> buildSecondaryStats(BuildContext context, SessionTemplateContext ctx) {
		final double minutes = ctx.elapsedMs / 60000.0;
		final double calories = minutes * ctx.kind.baseMet;
		final int targetMinutes = ctx.intValue('targetMinutes');
		return <SessionStat>[
			SessionStat(
				label: 'مدت جلسه',
				value: '${toPersianDigits(minutes.round().toString())} دقیقه',
			),
			if (targetMinutes > 0)
				SessionStat(
					label: 'هدف',
					value: '${toPersianDigits(targetMinutes.toString())} دقیقه',
				),
			SessionStat(
				label: 'کالری تقریبی',
				value: '${toPersianDigits(calories.round().toString())} کیلوکالری',
			),
			SessionStat(
				label: 'زمان توقف',
				value: toPersianDigits(formatSessionDuration(ctx.session.pausedMs)),
			),
		];
	}

	@override
	List<Widget> buildActions(BuildContext context, SessionTemplateContext ctx) {
		if (!ctx.isActive) return const <Widget>[];
		return <Widget>[
			Row(
				children: [
					Expanded(
						child: SessionActionButton(
							label: 'ثبت نقطه',
							icon: Icons.bookmark_rounded,
							color: Colors.indigo,
							onTap: () async {
								RitmoHaptics.tap();
								await ctx.logEvent(
									SessionEventType.note,
									<String, dynamic>{'at': DateTime.now().millisecondsSinceEpoch, 'elapsed': ctx.elapsedMs},
								);
							},
						),
					),
				],
			),
		];
	}
}

/// انتخاب مرحله با لمس — گرم کردن / اصلی / سرد کردن.
class _PhaseSelector extends StatelessWidget {
	const _PhaseSelector({required this.ctx});
	final SessionTemplateContext ctx;

	@override
	Widget build(BuildContext context) {
		final String current = ctx.stringValue('phase') ?? 'MAIN';
		return Wrap(
			spacing: 8,
			runSpacing: 8,
			alignment: WrapAlignment.center,
			children: _phases.map((p) {
				final bool isActive = current == p.code;
				return Semantics(
					button: true,
					selected: isActive,
					label: p.label,
					child: Tooltip(
						message: p.label,
						child: InkWell(
							borderRadius: BorderRadius.circular(20),
							onTap: isActive
									? null
									: () async {
											RitmoHaptics.selection();
											await ctx.logEvent(
												SessionEventType.split,
												<String, dynamic>{
													'phase': p.code,
													'at': DateTime.now().millisecondsSinceEpoch,
												},
											);
											await ctx.updateLive(<String, dynamic>{'phase': p.code});
										},
							child: Container(
								padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
								decoration: BoxDecoration(
									color: isActive ? p.color : Colors.white12,
									borderRadius: BorderRadius.circular(20),
									border: Border.all(color: isActive ? p.color : Colors.white24),
								),
								child: Row(
									mainAxisSize: MainAxisSize.min,
									children: [
										Icon(p.icon, size: 14, color: Colors.white),
										const SizedBox(width: 6),
										Text(
											p.label,
											style: const TextStyle(fontFamily: _fontFa, color: Colors.white, fontSize: 12),
										),
									],
								),
							),
						),
					),
				);
			}).toList(),
		);
	}
}
