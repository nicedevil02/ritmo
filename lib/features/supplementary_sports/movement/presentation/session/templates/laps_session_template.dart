// lib/features/supplementary_sports/movement/presentation/session/templates/laps_session_template.dart

import 'package:flutter/material.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/ux/ritmo_haptics.dart';
import 'package:ritmo/features/supplementary_sports/movement/domain/movement_session.dart';
import 'package:ritmo/features/supplementary_sports/movement/presentation/session/session_template.dart';
import 'package:ritmo/features/supplementary_sports/movement/presentation/session/session_widgets.dart';

const String _fontFa = 'Vazirmatn';

/// قالب ورزش‌های دور‌محور: شنا، دوی پیست، پله‌نوردی.
///
/// دکمهٔ بزرگ دایمی «یک دور ثبت شد» متریک اصلی است.
/// ثبت هر دور به‌عنوان lap event در تاریخچه می‌ماند.
class LapsSessionTemplate extends SessionTemplate {
	const LapsSessionTemplate();

	@override
	String get code => 'LAPS';

	@override
	Widget buildHero(BuildContext context, SessionTemplateContext ctx) {
		final int lapCount = ctx.intValue('laps');
		final int lapTarget = ctx.intValue('targetLaps');

		return Column(
			children: [
				Row(
					mainAxisSize: MainAxisSize.min,
					crossAxisAlignment: CrossAxisAlignment.end,
					children: [
						Text(
							toPersianDigits(lapCount.toString()),
							style: const TextStyle(
								fontFamily: _fontFa,
								color: Colors.white,
								fontSize: 72,
								fontWeight: FontWeight.w900,
								height: 1.1,
							),
						),
						if (lapTarget > 0) ...[
							const SizedBox(width: 8),
							Padding(
								padding: const EdgeInsets.only(bottom: 12),
								child: Text(
									'/ ${toPersianDigits(lapTarget.toString())}',
									style: const TextStyle(fontFamily: _fontFa, color: Colors.white38, fontSize: 28),
								),
							),
						],
					],
				),
				const Text('دور', style: TextStyle(fontFamily: _fontFa, color: Colors.white60, fontSize: 18)),
				const SizedBox(height: 4),
				Text(
					toPersianDigits(formatSessionDuration(ctx.elapsedMs)),
					style: const TextStyle(fontFamily: _fontFa, color: Colors.white70, fontSize: 16),
				),
			],
		);
	}

	@override
	List<SessionStat> buildSecondaryStats(BuildContext context, SessionTemplateContext ctx) {
		final int lapCount = ctx.intValue('laps');
		final int bestLapMs = ctx.intValue('bestLapMs');
		final int lastLapMs = ctx.intValue('lastLapMs');
		final double calories = (ctx.elapsedMs / 60000.0) * ctx.kind.baseMet;
		return <SessionStat>[
			SessionStat(
				label: 'زمان كل',
				value: toPersianDigits(formatSessionDuration(ctx.elapsedMs)),
			),
			if (lastLapMs > 0)
				SessionStat(
					label: 'آخرین دور',
					value: toPersianDigits(formatSessionDuration(lastLapMs)),
				),
			if (bestLapMs > 0)
				SessionStat(
					label: 'بهترین دور',
					value: toPersianDigits(formatSessionDuration(bestLapMs)),
				),
			if (lapCount > 0)
				SessionStat(
					label: 'میانگین دور',
					value: toPersianDigits(formatSessionDuration(ctx.elapsedMs ~/ lapCount)),
				),
			SessionStat(
				label: 'کالری تقریبی',
				value: '${toPersianDigits(calories.round().toString())} کیلوکالری',
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
							label: 'یک دور ثبت شد 🏊',
							icon: Icons.flag_rounded,
							color: Colors.teal,
							verticalPadding: 16,
							onTap: () async {
								RitmoHaptics.confirm();
								final int now = DateTime.now().millisecondsSinceEpoch;
								final int lastLapTs = ctx.intValue('lastLapTs');
								final int lapMs = lastLapTs > 0 ? now - lastLapTs : 0;
								int bestLapMs = ctx.intValue('bestLapMs');
								if (lapMs > 0 && (bestLapMs == 0 || lapMs < bestLapMs)) {
									bestLapMs = lapMs;
								}
								await ctx.logEvent(
									SessionEventType.lap,
									<String, dynamic>{'at': now, 'lapMs': lapMs},
								);
								await ctx.updateLive(<String, dynamic>{
									'laps': ctx.intValue('laps') + 1,
									'lastLapTs': now,
									'lastLapMs': lapMs,
									if (bestLapMs > 0) 'bestLapMs': bestLapMs,
								});
							},
						),
					),
				],
			),
		];
	}
}
