// lib/features/supplementary_sports/movement/presentation/session/templates/distance_session_template.dart

import 'package:flutter/material.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/supplementary_sports/movement/presentation/session/session_template.dart';
import 'package:ritmo/features/supplementary_sports/movement/presentation/session/session_widgets.dart';

const String _fontFa = 'Vazirmatn';

/// قالب ورزش‌های مسافت‌محور: دویدن، پیاده‌روی تند، دوچرخه، تردمیل، الپتیکال.
///
/// متریک اصلی مسافت است. کاربر مسافت را دستی ثبت می‌کند (وقتی GPS نیست)،
/// تمپو، كالری و زمان در حالت حرفه‌ای نمایش داده می‌شوند.
class DistanceSessionTemplate extends SessionTemplate {
	const DistanceSessionTemplate();

	@override
	String get code => 'DISTANCE';

	@override
	Widget buildHero(BuildContext context, SessionTemplateContext ctx) {
		final double distM = ctx.doubleValue('manualDistanceMeters');
		final double distKm = distM / 1000.0;

		return Column(
			children: [
				Row(
					mainAxisSize: MainAxisSize.min,
					crossAxisAlignment: CrossAxisAlignment.end,
					children: [
						Text(
							toPersianDigits(distKm.toStringAsFixed(2)),
							style: const TextStyle(
								color: Colors.white,
								fontSize: 62,
								fontWeight: FontWeight.w900,
								height: 1.1,
							),
						),
						const SizedBox(width: 8),
						const Padding(
							padding: EdgeInsets.only(bottom: 10),
							child: Text(
								'کیلومتر',
								style: TextStyle(color: Colors.white60, fontSize: 18),
							),
						),
					],
				),
				const SizedBox(height: 4),
				Text(
					toPersianDigits(formatSessionDuration(ctx.elapsedMs)),
					style: const TextStyle(color: Colors.white70, fontSize: 20),
				),
				const SizedBox(height: 14),
				SessionChip(
					label: 'ثبت مسافت',
					icon: Icons.route_rounded,
					onTap: () async {
						final double? value = await showSessionMetricDialog(
							context: context,
							title: 'مسافت طی‌شده',
							unit: 'متر',
							min: 0,
							max: 60000,
							step: 100,
							current: distM,
						);
						if (value != null) {
							await ctx.updateLive(<String, dynamic>{'manualDistanceMeters': value});
						}
					},
				),
			],
		);
	}

	@override
	List<SessionStat> buildSecondaryStats(BuildContext context, SessionTemplateContext ctx) {
		final double distM = ctx.doubleValue('manualDistanceMeters');
		final double calories = (ctx.elapsedMs / 60000.0) * ctx.kind.baseMet;
		return <SessionStat>[
			SessionStat(
				label: 'تمپو',
				value: '${toPersianDigits(formatSessionPace(ctx.elapsedMs, distM))} دق/کم',
			),
			SessionStat(
				label: 'زمان',
				value: toPersianDigits(formatSessionDuration(ctx.elapsedMs)),
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
}
