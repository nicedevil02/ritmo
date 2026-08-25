// lib/features/supplementary_sports/movement/presentation/session/templates/match_session_template.dart

import 'package:flutter/material.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/ux/ritmo_haptics.dart';
import 'package:ritmo/features/supplementary_sports/movement/domain/movement_session.dart';
import 'package:ritmo/features/supplementary_sports/movement/presentation/session/session_template.dart';
import 'package:ritmo/features/supplementary_sports/movement/presentation/session/session_widgets.dart';


/// قالب ورزش‌های تیمی / راکتی: فوتبال، فوتسال، والیبال، بسکتبال، تنیس، رزمی.
///
/// متریک اصلی تایمر بازی است. امتیاز میزبان و مهمان با دکمهٔ افزایش/کاهش
/// تنظیم می‌شود. نیمه/ست هم ثبت می‌شود و در تاریخچه می‌ماند.
class MatchSessionTemplate extends SessionTemplate {
	const MatchSessionTemplate();

	@override
	String get code => 'MATCH';

	@override
	Widget buildHero(BuildContext context, SessionTemplateContext ctx) {
		final int hostScore = ctx.intValue('hostScore');
		final int guestScore = ctx.intValue('guestScore');

		return Column(
			children: [
				Row(
					mainAxisAlignment: MainAxisAlignment.center,
					crossAxisAlignment: CrossAxisAlignment.center,
					children: [
						_ScoreBlock(
							teamLabel: 'ما',
							score: hostScore,
							onInc: ctx.isActive
									? () async {
											RitmoHaptics.tap();
											await ctx.logEvent(SessionEventType.note, <String, dynamic>{
												'event': 'goal',
												'team': 'host',
												'at': DateTime.now().millisecondsSinceEpoch,
											});
											await ctx.updateLive(<String, dynamic>{'hostScore': hostScore + 1});
										}
									: null,
							onDec: ctx.isActive && hostScore > 0
									? () async {
											RitmoHaptics.tap();
											await ctx.updateLive(<String, dynamic>{'hostScore': hostScore - 1});
										}
									: null,
						),
						const Padding(
							padding: EdgeInsets.symmetric(horizontal: 12),
							child: Text(
								'—',
								style: TextStyle(color: Colors.white38, fontSize: 30),
							),
						),
						_ScoreBlock(
							teamLabel: 'حریف',
							score: guestScore,
							onInc: ctx.isActive
									? () async {
											RitmoHaptics.tap();
											await ctx.logEvent(SessionEventType.note, <String, dynamic>{
												'event': 'goal',
												'team': 'guest',
												'at': DateTime.now().millisecondsSinceEpoch,
											});
											await ctx.updateLive(<String, dynamic>{'guestScore': guestScore + 1});
										}
									: null,
							onDec: ctx.isActive && guestScore > 0
									? () async {
											RitmoHaptics.tap();
											await ctx.updateLive(<String, dynamic>{'guestScore': guestScore - 1});
										}
									: null,
						),
					],
				),
				const SizedBox(height: 8),
				Text(
					toPersianDigits(formatSessionDuration(ctx.elapsedMs)),
					style: const TextStyle(color: Colors.white70, fontSize: 18),
				),
			],
		);
	}

	@override
	List<SessionStat> buildSecondaryStats(BuildContext context, SessionTemplateContext ctx) {
		final int half = ctx.intValue('halfCount');
		final double calories = (ctx.elapsedMs / 60000.0) * ctx.kind.baseMet * 1.1;
		return <SessionStat>[
			SessionStat(
				label: 'زمان بازی',
				value: toPersianDigits(formatSessionDuration(ctx.elapsedMs)),
			),
			if (half > 0)
				SessionStat(
					label: 'نیمه/ست',
					value: toPersianDigits(half.toString()),
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
							label: 'پایان نیمه/ست',
							icon: Icons.sports_rounded,
							color: Colors.indigo,
							onTap: () async {
								RitmoHaptics.confirm();
								await ctx.logEvent(SessionEventType.split, <String, dynamic>{
									'at': DateTime.now().millisecondsSinceEpoch,
									'hostScore': ctx.intValue('hostScore'),
									'guestScore': ctx.intValue('guestScore'),
								});
								await ctx.updateLive(
									<String, dynamic>{'halfCount': ctx.intValue('halfCount') + 1},
								);
							},
						),
					),
				],
			),
		];
	}
}

/// بلوک امتیاز یک تیم با دکمه‌های افزایش و کاهش.
class _ScoreBlock extends StatelessWidget {
	const _ScoreBlock({
		required this.teamLabel,
		required this.score,
		required this.onInc,
		required this.onDec,
	});

	final String teamLabel;
	final int score;
	final Future<void> Function()? onInc;
	final Future<void> Function()? onDec;

	@override
	Widget build(BuildContext context) {
		return Column(
			children: [
				Text(
					teamLabel,
					style: const TextStyle(color: Colors.white54, fontSize: 12),
				),
				const SizedBox(height: 4),
				Text(
					toPersianDigits(score.toString()),
					style: const TextStyle(
						color: Colors.white,
						fontSize: 60,
						fontWeight: FontWeight.w900,
						height: 1.1,
					),
				),
				const SizedBox(height: 8),
				Row(
					mainAxisSize: MainAxisSize.min,
					children: [
						SessionStepperButton(
							icon: Icons.remove,
							semanticLabel: '$teamLabel یک کم',
							onTap: onDec,
						),
						const SizedBox(width: 8),
						SessionStepperButton(
							icon: Icons.add,
							semanticLabel: '$teamLabel یک گل ثبت شد',
							color: Colors.teal,
							onTap: onInc,
						),
					],
				),
			],
		);
	}
}
