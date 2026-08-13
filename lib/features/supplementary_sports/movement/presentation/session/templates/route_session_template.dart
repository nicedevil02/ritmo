// lib/features/supplementary_sports/movement/presentation/session/templates/route_session_template.dart

import 'package:flutter/material.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/ux/ritmo_haptics.dart';
import 'package:ritmo/features/supplementary_sports/movement/domain/movement_session.dart';
import 'package:ritmo/features/supplementary_sports/movement/presentation/session/session_template.dart';

const String _fontFa = 'Vazirmatn';

/// چک‌لیست وسایل مسیر؛ کلید ذخیره در liveJson می‌شود: gear
const Map<String, String> _gearItems = <String, String>{
	'water': 'آب کافی',
	'layer': 'لایهٔ گرم',
	'light': 'چراغ‌قوه',
	'food': 'خوراکی انرژی‌زا',
	'sun': 'کلاه و ضدآفتاب',
	'aid': 'کمک‌های اولیه',
	'battery': 'شارژ موبایل',
};

List<String> _selectedGear(SessionTemplateContext ctx) {
	final dynamic raw = ctx.live['gear'];
	if (raw is List) return raw.map((item) => item.toString()).toList();
	return const <String>[];
}

/// قالب ورزش‌های مسیری: کوه‌نوردی، پیاده‌روی در طبیعت، دوی کوره‌راهی، رکاب‌زنی جاده‌ای.
///
/// تفاوت با قالب زمانی: متریک اصلی صعود است، نقطهٔ بازگشت دارد، چک‌لیست
/// ایمنی دارد و رویدادهای «قله» و «شروع بازگشت» را ثبت می‌کند.
class RouteSessionTemplate extends SessionTemplate {
	const RouteSessionTemplate();

	@override
	String get code => 'ROUTE';

	@override
	SessionBanner? buildBanner(BuildContext context, SessionTemplateContext ctx) {
		final int turnaroundAt = ctx.intValue('turnaroundAtMs');
		final int now = DateTime.now().millisecondsSinceEpoch;

		if (turnaroundAt > 0 && now >= turnaroundAt) {
			return const SessionBanner(
				text: 'وقت بازگشت رسیده است. ادامهٔ صعود ریسک تاریکی و خستگی دارد.',
				icon: Icons.u_turn_left_rounded,
				color: Colors.redAccent,
			);
		}
		if (turnaroundAt > 0 && (turnaroundAt - now) <= 20 * 60 * 1000) {
			final int remaining = ((turnaroundAt - now) / 60000).ceil();
			return SessionBanner(
				text: 'تا نقطهٔ بازگشت ${toPersianDigits(remaining.toString())} دقیقه مانده است.',
				icon: Icons.timelapse_rounded,
				color: Colors.amber,
			);
		}
		if (DateTime.now().hour >= 16 && !_selectedGear(ctx).contains('light')) {
			return const SessionBanner(
				text: 'عصر شده و چراغ‌قوه را تیک نزده‌ای؛ پیش از ادامهٔ مسیر مطمئن شو.',
				icon: Icons.flashlight_on_rounded,
				color: Colors.orangeAccent,
			);
		}
		return null;
	}

	@override
	Widget buildHero(BuildContext context, SessionTemplateContext ctx) {
		final double elevation = ctx.doubleValue('manualElevationMeters');
		final double distance = ctx.doubleValue('manualDistanceMeters');

		return Column(
			children: [
				Row(
					mainAxisSize: MainAxisSize.min,
					crossAxisAlignment: CrossAxisAlignment.end,
					children: [
						Text(
							toPersianDigits(elevation.round().toString()),
							style: const TextStyle(
								fontFamily: _fontFa,
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
								'متر صعود',
								style: TextStyle(fontFamily: _fontFa, color: Colors.white60, fontSize: 18),
							),
						),
					],
				),
				const SizedBox(height: 4),
				Text(
					toPersianDigits(formatSessionDuration(ctx.elapsedMs)),
					style: const TextStyle(fontFamily: _fontFa, color: Colors.white70, fontSize: 20),
				),
				const SizedBox(height: 14),
				Wrap(
					spacing: 8,
					runSpacing: 8,
					alignment: WrapAlignment.center,
					children: [
						_EditChip(
							label: 'ثبت ارتفاع',
							icon: Icons.terrain_rounded,
							onTap: () async {
								final double? value = await showSessionMetricDialog(
									context: context,
									title: 'ارتفاع صعود تا این لحظه',
									unit: 'متر',
									min: 0,
									max: 3000,
									step: 25,
									current: elevation,
								);
								if (value != null) {
									await ctx.updateLive(<String, dynamic>{'manualElevationMeters': value});
								}
							},
						),
						_EditChip(
							label: 'ثبت مسافت',
							icon: Icons.route_rounded,
							onTap: () async {
								final double? value = await showSessionMetricDialog(
									context: context,
									title: 'مسافت طی‌شده',
									unit: 'متر',
									min: 0,
									max: 40000,
									step: 250,
									current: distance,
								);
								if (value != null) {
									await ctx.updateLive(<String, dynamic>{'manualDistanceMeters': value});
								}
							},
						),
					],
				),
			],
		);
	}

	@override
	List<SessionStat> buildSecondaryStats(BuildContext context, SessionTemplateContext ctx) {
		final double elapsedHours = ctx.elapsedMs / 3600000.0;
		final double elevation = ctx.doubleValue('manualElevationMeters');
		final double distance = ctx.doubleValue('manualDistanceMeters');
		final int ascentRate = elapsedHours > 0.02 ? (elevation / elapsedHours).round() : 0;
		final double calories = (ctx.elapsedMs / 60000.0) * ctx.kind.baseMet * 1.2;

		return <SessionStat>[
			SessionStat(
				label: 'سرعت صعود',
				value: '${toPersianDigits(ascentRate.toString())} متر/ساعت',
			),
			SessionStat(
				label: 'مسافت',
				value: '${toPersianDigits((distance / 1000).toStringAsFixed(1))} کیلومتر',
			),
			SessionStat(
				label: 'تمپوی مسیر',
				value: '${toPersianDigits(formatSessionPace(ctx.elapsedMs, distance))} بر کیلومتر',
			),
			SessionStat(
				label: 'زمان توقف',
				value: toPersianDigits(formatSessionDuration(ctx.session.pausedMs)),
			),
			SessionStat(
				label: 'کالری تقریبی',
				value: '${toPersianDigits(calories.round().toString())} کیلوکالری',
			),
		];
	}

	@override
	Widget? buildBody(BuildContext context, SessionTemplateContext ctx) {
		return Column(
			crossAxisAlignment: CrossAxisAlignment.stretch,
			children: [
				_TurnaroundCard(ctx: ctx),
				const SizedBox(height: 12),
				_GearChecklist(ctx: ctx),
			],
		);
	}

	@override
	List<Widget> buildActions(BuildContext context, SessionTemplateContext ctx) {
		if (!ctx.isActive) return const <Widget>[];
		final int summitAt = ctx.intValue('summitAtMs');
		final int descentAt = ctx.intValue('descentStartedAtMs');

		return <Widget>[
			Row(
				children: [
					Expanded(
						child: _RouteActionButton(
							label: summitAt > 0 ? 'قله ثبت شد ✅' : 'رسیدم به قله 🏔️',
							icon: Icons.flag_rounded,
							color: summitAt > 0 ? Colors.white24 : Colors.indigoAccent,
							onTap: summitAt > 0
									? null
									: () async {
											RitmoHaptics.success();
											final int now = DateTime.now().millisecondsSinceEpoch;
											await ctx.logEvent(
												SessionEventType.note,
												<String, dynamic>{'note': 'رسیدم به قله', 'at': now},
											);
											await ctx.updateLive(<String, dynamic>{'summitAtMs': now});
										},
						),
					),
					const SizedBox(width: 12),
					Expanded(
						child: _RouteActionButton(
							label: descentAt > 0 ? 'در مسیر بازگشت' : 'شروع بازگشت',
							icon: Icons.u_turn_left_rounded,
							color: descentAt > 0 ? Colors.white24 : Colors.teal,
							onTap: descentAt > 0
									? null
									: () async {
											RitmoHaptics.confirm();
											final int now = DateTime.now().millisecondsSinceEpoch;
											await ctx.logEvent(
												SessionEventType.split,
												<String, dynamic>{'phase': 'DESCENT', 'at': now},
											);
											await ctx.updateLive(<String, dynamic>{'descentStartedAtMs': now});
										},
						),
					),
				],
			),
		];
	}
}

/// کارت نقطهٔ بازگشت — قاعدهٔ ایمنی مشترک همهٔ مسیرهای طولانی.
class _TurnaroundCard extends StatelessWidget {
	const _TurnaroundCard({required this.ctx});

	final SessionTemplateContext ctx;

	@override
	Widget build(BuildContext context) {
		final int turnaroundAt = ctx.intValue('turnaroundAtMs');
		final bool hasTurnaround = turnaroundAt > 0;
		final int remainingMinutes = hasTurnaround
				? ((turnaroundAt - DateTime.now().millisecondsSinceEpoch) / 60000).ceil()
				: 0;

		String subtitle;
		if (!hasTurnaround) {
			subtitle = 'برای مسیرهای طولانی زمان بازگشت تعیین کن تا در تاریکی گیر نکنی.';
		} else if (remainingMinutes > 0) {
			subtitle = 'تا ${toPersianDigits(remainingMinutes.toString())} دقیقهٔ دیگر باید برگردی.';
		} else {
			subtitle = 'زمان بازگشت گذشته است.';
		}

		return Container(
			padding: const EdgeInsets.all(14),
			decoration: BoxDecoration(
				color: Colors.white10,
				borderRadius: BorderRadius.circular(16),
			),
			child: Row(
				children: [
					const Icon(Icons.u_turn_left_rounded, color: Colors.white70, size: 18),
					const SizedBox(width: 10),
					Expanded(
						child: Column(
							crossAxisAlignment: CrossAxisAlignment.start,
							children: [
								const Text(
									'نقطهٔ بازگشت',
									style: TextStyle(
										fontFamily: _fontFa,
										color: Colors.white,
										fontSize: 13,
										fontWeight: FontWeight.bold,
									),
								),
								const SizedBox(height: 2),
								Text(
									subtitle,
									maxLines: 2,
									overflow: TextOverflow.ellipsis,
									style: const TextStyle(fontFamily: _fontFa, color: Colors.white60, fontSize: 11),
								),
							],
						),
					),
					const SizedBox(width: 8),
					_EditChip(
						label: hasTurnaround ? 'تغییر' : 'تعیین',
						icon: Icons.schedule_rounded,
						onTap: () async {
							final double? minutes = await showSessionMetricDialog(
								context: context,
								title: 'چند دقیقهٔ دیگر باید بازگردی؟',
								unit: 'دقیقه',
								min: 15,
								max: 360,
								step: 15,
								current: remainingMinutes > 0 ? remainingMinutes.toDouble() : 90,
							);
							if (minutes != null) {
								await ctx.updateLive(<String, dynamic>{
									'turnaroundAtMs':
											DateTime.now().millisecondsSinceEpoch + (minutes * 60000).round(),
								});
							}
						},
					),
				],
			),
		);
	}
}

/// چک‌لیست وسایل؛ وضعیت در liveJson می‌ماند و با بستن اپ پاک نمی‌شود.
class _GearChecklist extends StatelessWidget {
	const _GearChecklist({required this.ctx});

	final SessionTemplateContext ctx;

	@override
	Widget build(BuildContext context) {
		final List<String> selected = _selectedGear(ctx);
		return Container(
			padding: const EdgeInsets.all(14),
			decoration: BoxDecoration(
				color: Colors.white10,
				borderRadius: BorderRadius.circular(16),
			),
			child: Column(
				crossAxisAlignment: CrossAxisAlignment.stretch,
				children: [
					Row(
						children: [
							const Icon(Icons.backpack_rounded, color: Colors.white70, size: 18),
							const SizedBox(width: 10),
							const Expanded(
								child: Text(
									'چک‌لیست وسایل',
									maxLines: 1,
									overflow: TextOverflow.ellipsis,
									style: TextStyle(
										fontFamily: _fontFa,
										color: Colors.white,
										fontSize: 13,
										fontWeight: FontWeight.bold,
									),
								),
							),
							Text(
								'${toPersianDigits(selected.length.toString())} از ${toPersianDigits(_gearItems.length.toString())}',
								style: const TextStyle(fontFamily: _fontFa, color: Colors.white54, fontSize: 11),
							),
						],
					),
					const SizedBox(height: 10),
					Wrap(
						spacing: 8,
						runSpacing: 8,
						children: _gearItems.entries.map((entry) {
							final bool isOn = selected.contains(entry.key);
							return _GearChip(
								label: entry.value,
								isOn: isOn,
								onTap: () async {
									RitmoHaptics.selection();
									final List<String> next = List<String>.from(selected);
									if (isOn) {
										next.remove(entry.key);
									} else {
										next.add(entry.key);
									}
									await ctx.updateLive(<String, dynamic>{'gear': next});
								},
							);
						}).toList(),
					),
				],
			),
		);
	}
}

class _GearChip extends StatelessWidget {
	const _GearChip({required this.label, required this.isOn, required this.onTap});

	final String label;
	final bool isOn;
	final Future<void> Function() onTap;

	@override
	Widget build(BuildContext context) {
		return Semantics(
			button: true,
			checked: isOn,
			label: label,
			child: Tooltip(
				message: isOn ? '$label — برداشتن تیک' : '$label — تیک زدن',
				child: InkWell(
					borderRadius: BorderRadius.circular(20),
					onTap: onTap,
					child: Container(
						padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
						decoration: BoxDecoration(
							color: isOn ? Colors.teal : Colors.white12,
							borderRadius: BorderRadius.circular(20),
							border: Border.all(color: isOn ? Colors.teal : Colors.white24),
						),
						child: Row(
							mainAxisSize: MainAxisSize.min,
							children: [
								Icon(
									isOn ? Icons.check_circle_rounded : Icons.circle_outlined,
									size: 14,
									color: isOn ? Colors.white : Colors.white54,
								),
								const SizedBox(width: 6),
								Text(
									label,
									style: TextStyle(
										fontFamily: _fontFa,
										color: isOn ? Colors.white : Colors.white70,
										fontSize: 11,
										fontWeight: isOn ? FontWeight.bold : FontWeight.normal,
									),
								),
							],
						),
					),
				),
			),
		);
	}
}

class _EditChip extends StatelessWidget {
	const _EditChip({required this.label, required this.icon, required this.onTap});

	final String label;
	final IconData icon;
	final Future<void> Function() onTap;

	@override
	Widget build(BuildContext context) {
		return Semantics(
			button: true,
			label: label,
			child: Tooltip(
				message: label,
				child: InkWell(
					borderRadius: BorderRadius.circular(20),
					onTap: onTap,
					child: Container(
						padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
						decoration: BoxDecoration(
							color: Colors.white12,
							borderRadius: BorderRadius.circular(20),
							border: Border.all(color: Colors.white24),
						),
						child: Row(
							mainAxisSize: MainAxisSize.min,
							children: [
								Icon(icon, size: 14, color: Colors.white70),
								const SizedBox(width: 6),
								Text(
									label,
									style: const TextStyle(fontFamily: _fontFa, color: Colors.white, fontSize: 11),
								),
							],
						),
					),
				),
			),
		);
	}
}

class _RouteActionButton extends StatelessWidget {
	const _RouteActionButton({
		required this.label,
		required this.icon,
		required this.color,
		required this.onTap,
	});

	final String label;
	final IconData icon;
	final Color color;
	final Future<void> Function()? onTap;

	@override
	Widget build(BuildContext context) {
		return Semantics(
			button: true,
			enabled: onTap != null,
			label: label,
			child: Tooltip(
				message: label,
				child: ElevatedButton.icon(
					onPressed: onTap,
					icon: Icon(icon, size: 18, color: Colors.white),
					label: Text(
						label,
						maxLines: 1,
						overflow: TextOverflow.ellipsis,
						style: const TextStyle(
							fontFamily: _fontFa,
							color: Colors.white,
							fontSize: 12,
							fontWeight: FontWeight.bold,
						),
					),
					style: ElevatedButton.styleFrom(
						backgroundColor: color,
						disabledBackgroundColor: Colors.white12,
						padding: const EdgeInsets.symmetric(vertical: 12),
						shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
					),
				),
			),
		);
	}
}
