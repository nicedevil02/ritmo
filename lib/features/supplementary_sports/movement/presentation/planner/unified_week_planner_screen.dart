// lib/features/supplementary_sports/movement/presentation/planner/unified_week_planner_screen.dart

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/ux/ritmo_haptics.dart';
import 'package:ritmo/features/calendar/presentation/utils/calendar_tokens.dart';
import 'package:ritmo/features/supplementary_sports/movement/data/movement_campaign_repository.dart';
import 'package:ritmo/features/supplementary_sports/movement/data/unified_planner_repository.dart';
import 'package:ritmo/features/supplementary_sports/movement/domain/week_plan_item.dart';
import 'package:ritmo/features/supplementary_sports/movement/presentation/movement_plan_sheet.dart';
import 'package:ritmo/features/supplementary_sports/presentation/ss_plan_day_detail_screen.dart';

const String _fontFa = 'Vazirmatn';

/// نمای قابل‌جاسازی برنامهٔ هفته — بدون Scaffold — تا هم صفحهٔ مستقل باشد
/// هم یک تب درون «حرکت».
class UnifiedWeekPlannerView extends StatefulWidget {
	const UnifiedWeekPlannerView({super.key});

	@override
	State<UnifiedWeekPlannerView> createState() => _UnifiedWeekPlannerViewState();
}

class _UnifiedWeekPlannerViewState extends State<UnifiedWeekPlannerView> {
	late Future<UnifiedWeekPlan> _future;

	@override
	void initState() {
		super.initState();
		_future = UnifiedPlannerRepository.instance.loadWeek();
	}

	void _reload() {
		setState(() {
			_future = UnifiedPlannerRepository.instance.loadWeek();
		});
	}

	Future<void> _openNewPlan() async {
		RitmoHaptics.tap();
		await showMovementPlanSheet(context, onSaved: _reload);
	}

	Future<void> _startCampaign() async {
		RitmoHaptics.success();
		try {
			await MovementCampaignRepository.instance.createCampaign(
				goalCode: 'DAMAVAND_6W',
				titleFa: 'دماوند در ۶ هفته',
				startDate: DateTime.now(),
				weeks: 6,
			);
			_reload();
		} catch (e) {
			debugPrint('[ss] unified_week_planner_screen.dart: $e');
			if (mounted) {
				ScaffoldMessenger.of(context).showSnackBar(
					const SnackBar(
						content: Text(
							'ساخت کارزار انجام نشد. دوباره تلاش کن.',
							style: TextStyle(fontFamily: _fontFa),
						),
					),
				);
			}
		}
	}

	@override
	Widget build(BuildContext context) {
		final colors = context.colors;
		final int todaySat0 = dartWeekdayToSat0(DateTime.now().weekday);

		return FutureBuilder<UnifiedWeekPlan>(
			future: _future,
			builder: (context, snapshot) {
				if (snapshot.connectionState != ConnectionState.done) {
					return const Center(child: CircularProgressIndicator());
				}
				if (snapshot.hasError || !snapshot.hasData) {
					return _buildError();
				}
				final plan = snapshot.data!;
				return _buildList(plan, todaySat0, colors);
			},
		);
	}

	Widget _buildError() {
		return Center(
			child: Padding(
				padding: const EdgeInsets.all(24),
				child: Column(
					mainAxisSize: MainAxisSize.min,
					children: [
						const Icon(Icons.error_outline_rounded, color: Colors.white38, size: 40),
						const SizedBox(height: 12),
						const Text(
							'خواندن برنامهٔ هفته ممکن نشد.',
							textAlign: TextAlign.center,
							style: TextStyle(fontFamily: _fontFa, color: Colors.white70, fontSize: 13),
						),
						const SizedBox(height: 12),
						ElevatedButton.icon(
							style: ElevatedButton.styleFrom(backgroundColor: CalendarTokens.emerald),
							onPressed: _reload,
							icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 18),
							label: const Text(
								'تلاش دوباره',
								style: TextStyle(fontFamily: _fontFa, color: Colors.white),
							),
						),
					],
				),
			),
		);
	}

	Widget _buildList(UnifiedWeekPlan plan, int todaySat0, dynamic colors) {
		final children = <Widget>[
			_buildWeekSummary(plan),
			const SizedBox(height: 10),
			_buildCampaignCard(plan),
		];
		for (int i = 0; i < 7; i++) {
			children.add(
				_buildDayCard(
					dayIndex: i,
					items: plan.byDay[i],
					isToday: i == todaySat0,
					colors: colors,
				),
			);
		}
		return ListView(
			padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
			children: children,
		);
	}

	/// ردیف بالای لیست: خلاصهٔ هفته + دکمهٔ ساخت برنامهٔ جدید.
	Widget _buildWeekSummary(UnifiedWeekPlan plan) {
		final String summary = plan.totalItems == 0
				? 'هنوز برنامه‌ای نداری'
				: '${toPersianDigits(plan.completedItems.toString())} از '
					'${toPersianDigits(plan.totalItems.toString())} انجام شده';
		return Row(
			children: [
				Expanded(
					child: Text(
						summary,
						maxLines: 1,
						overflow: TextOverflow.ellipsis,
						style: const TextStyle(fontFamily: _fontFa, color: Colors.white54, fontSize: 12),
					),
				),
				Semantics(
					button: true,
					label: 'افزودن برنامهٔ ورزشی جدید',
					child: Tooltip(
						message: 'ساخت برنامه برای هر یک از ورزش‌ها',
						child: ElevatedButton.icon(
							style: ElevatedButton.styleFrom(
								backgroundColor: CalendarTokens.emerald,
								padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
								shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
							),
							onPressed: _openNewPlan,
							icon: const Icon(Icons.add, size: 16, color: Colors.white),
							label: const Text(
								'برنامهٔ جدید',
								style: TextStyle(fontFamily: _fontFa, color: Colors.white, fontSize: 12),
							),
						),
					),
				),
			],
		);
	}

	/// کارت کارزار — اگر کارزار فعال هست پیشرفتش را نشان می‌دهد، وگرنه پیشنهاد شروع.
	Widget _buildCampaignCard(UnifiedWeekPlan plan) {
		final campaign = plan.activeCampaign;
		if (campaign == null) {
			return Container(
				margin: const EdgeInsets.only(bottom: 12),
				padding: const EdgeInsets.all(14),
				decoration: BoxDecoration(
					color: const Color(0xFF1E293B),
					borderRadius: BorderRadius.circular(16),
					border: Border.all(color: const Color(0xFF334155)),
				),
				child: Column(
					crossAxisAlignment: CrossAxisAlignment.stretch,
					children: [
						const Row(
							children: [
								Text('🏔', style: TextStyle(fontSize: 20)),
								SizedBox(width: 8),
								Expanded(
									child: Text(
										'کارزار صعود: دماوند در ۶ هفته',
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
							],
						),
						const SizedBox(height: 6),
						const Text(
							'برنامهٔ هفتگی صعود، پله‌نوردی و ریکاوری برای آماده‌سازی تدریجی.',
							maxLines: 2,
							overflow: TextOverflow.ellipsis,
							style: TextStyle(fontFamily: _fontFa, color: Colors.white60, fontSize: 11),
						),
						const SizedBox(height: 10),
						Align(
							alignment: AlignmentDirectional.centerStart,
							child: Semantics(
								button: true,
								label: 'شروع کارزار صعود دماوند',
								child: Tooltip(
									message: 'شروع کارزار صعود',
									child: TextButton.icon(
										style: TextButton.styleFrom(foregroundColor: CalendarTokens.emerald),
										onPressed: _startCampaign,
										icon: const Icon(Icons.rocket_launch_rounded, size: 16),
										label: const Text(
											'شروع کارزار',
											style: TextStyle(fontFamily: _fontFa, fontSize: 12, fontWeight: FontWeight.bold),
										),
									),
								),
							),
						),
					],
				),
			);
		}

		int currentWeek = 1;
		try {
			final decoded = jsonDecode(campaign.progressJson ?? '{}');
			if (decoded is Map) {
				currentWeek = (decoded['currentWeek'] as num? ?? 1).toInt();
			}
		} catch (e) {
			debugPrint('[ss] unified_week_planner_screen.dart: $e');
		}
		final double percent = (currentWeek / campaign.weeks).clamp(0.0, 1.0);

		return Container(
			margin: const EdgeInsets.only(bottom: 12),
			padding: const EdgeInsets.all(14),
			decoration: BoxDecoration(
				color: const Color(0xFF0F172A),
				borderRadius: BorderRadius.circular(16),
				border: Border.all(color: const Color(0xFF0EA5E9)),
			),
			child: Column(
				crossAxisAlignment: CrossAxisAlignment.stretch,
				children: [
					Row(
						children: [
							const Text('🏆', style: TextStyle(fontSize: 18)),
							const SizedBox(width: 8),
							Expanded(
								child: Text(
									campaign.titleFa,
									maxLines: 1,
									overflow: TextOverflow.ellipsis,
									style: const TextStyle(
										fontFamily: _fontFa,
										color: Colors.white,
										fontSize: 13,
										fontWeight: FontWeight.bold,
									),
								),
							),
							Text(
								'هفتهٔ ${toPersianDigits(currentWeek.toString())} از ${toPersianDigits(campaign.weeks.toString())}',
								style: const TextStyle(fontFamily: _fontFa, color: Colors.white60, fontSize: 11),
							),
						],
					),
					const SizedBox(height: 10),
					ClipRRect(
						borderRadius: BorderRadius.circular(10),
						child: LinearProgressIndicator(
							value: percent,
							backgroundColor: Colors.white12,
							valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF0EA5E9)),
							minHeight: 6,
						),
					),
				],
			),
		);
	}

	Widget _buildDayCard({
		required int dayIndex,
		required List<WeekPlanItem> items,
		required bool isToday,
		required dynamic colors,
	}) {
		return Container(
			margin: const EdgeInsets.only(bottom: 10),
			padding: const EdgeInsets.all(12),
			decoration: BoxDecoration(
				color: isToday
						? CalendarTokens.emerald.withValues(alpha: 0.10)
						: colors.card,
				borderRadius: BorderRadius.circular(16),
				border: Border.all(
					color: isToday
							? CalendarTokens.emerald.withValues(alpha: 0.5)
							: colors.border.withValues(alpha: 0.4),
				),
			),
			child: Column(
				crossAxisAlignment: CrossAxisAlignment.stretch,
				children: [
					Row(
						children: [
							Expanded(
								child: Text(
									kPersianWeekdayNames[dayIndex],
									maxLines: 1,
									overflow: TextOverflow.ellipsis,
									style: const TextStyle(
										fontFamily: _fontFa,
										color: Colors.white,
										fontSize: 14,
										fontWeight: FontWeight.bold,
									),
								),
							),
							if (isToday)
								Container(
									padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
									decoration: BoxDecoration(
										color: CalendarTokens.emerald,
										borderRadius: BorderRadius.circular(10),
									),
									child: const Text(
										'امروز',
										style: TextStyle(fontFamily: _fontFa, color: Colors.white, fontSize: 10),
									),
								),
						],
					),
					const SizedBox(height: 8),
					if (items.isEmpty)
						const Text(
							'استراحت',
							style: TextStyle(fontFamily: _fontFa, color: Colors.white38, fontSize: 12),
						)
					else
						...items.map(_buildItemTile),
				],
			),
		);
	}

	Widget _buildItemTile(WeekPlanItem item) {
		final subtitleParts = <String>[
			if (item.timeLabel != null) toPersianDigits(item.timeLabel!),
			if (item.targetLabel != null) toPersianDigits(item.targetLabel!),
			if (item.detailLabel != null && item.detailLabel!.isNotEmpty) item.detailLabel!,
		];

		return Semantics(
			button: true,
			label: '${item.title} ${subtitleParts.join('، ')}',
			child: Tooltip(
				message: item.isMovement ? 'ویرایش برنامه' : 'مشاهدهٔ روز قدرتی',
				child: InkWell(
					borderRadius: BorderRadius.circular(12),
					onTap: () => _openItem(item),
					child: Padding(
						padding: const EdgeInsets.symmetric(vertical: 6),
						child: Row(
							children: [
								Text(item.emoji, style: const TextStyle(fontSize: 20)),
								const SizedBox(width: 10),
								Expanded(
									child: Column(
										crossAxisAlignment: CrossAxisAlignment.start,
										children: [
											Text(
												item.title,
												maxLines: 1,
												overflow: TextOverflow.ellipsis,
												style: TextStyle(
													fontFamily: _fontFa,
													color: Colors.white,
													fontSize: 13,
													fontWeight: FontWeight.bold,
													decoration: item.isCompleted ? TextDecoration.lineThrough : null,
												),
											),
											if (subtitleParts.isNotEmpty)
												Text(
													subtitleParts.join(' · '),
													maxLines: 2,
													overflow: TextOverflow.ellipsis,
													style: const TextStyle(
														fontFamily: _fontFa,
														color: Colors.white54,
														fontSize: 11,
													),
												),
										],
									),
								),
								if (item.isCompleted)
									const Icon(Icons.check_circle_rounded, color: CalendarTokens.emerald, size: 18)
								else
									const Icon(Icons.chevron_left_rounded, color: Colors.white24, size: 18),
							],
						),
					),
				),
			),
		);
	}

	Future<void> _openItem(WeekPlanItem item) async {
		RitmoHaptics.tap();
		if (item.isMovement && item.routineRaw != null) {
			await showMovementPlanSheet(
				context,
				routineToEdit: item.routineRaw,
				onSaved: _reload,
			);
			return;
		}
		if (item.isStrength) {
			// قرارداد ss_workout_plan شنبه‌محور است: ۱=شنبه.
			await Navigator.of(context).push(
				MaterialPageRoute<void>(
					builder: (_) => SSPlanDayDetailScreen(
						dayOfWeek: item.weekdaySat0 + 1,
						dayName: kPersianWeekdayNames[item.weekdaySat0],
					),
				),
			);
			_reload();
		}
	}
}

/// صفحهٔ مستقل «برنامهٔ هفته» — پوستهٔ نازک دور همان نمای قابل‌جاسازی.
class UnifiedWeekPlannerScreen extends StatelessWidget {
	const UnifiedWeekPlannerScreen({super.key});

	@override
	Widget build(BuildContext context) {
		final colors = context.colors;
		return Directionality(
			textDirection: TextDirection.rtl,
			child: Scaffold(
				backgroundColor: colors.background,
				body: SafeArea(
					child: Column(
						children: [
							Padding(
								padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
								child: Row(
									children: [
										IconButton(
											tooltip: 'بازگشت',
											icon: const Icon(Icons.arrow_forward_rounded, color: Colors.white70),
											onPressed: () => Navigator.of(context).pop(),
										),
										const Expanded(
											child: Text(
												'برنامهٔ هفته',
												maxLines: 1,
												overflow: TextOverflow.ellipsis,
												style: TextStyle(
													fontFamily: _fontFa,
													fontSize: 18,
													fontWeight: FontWeight.bold,
													color: Colors.white,
												),
											),
										),
									],
								),
							),
							const Expanded(child: UnifiedWeekPlannerView()),
						],
					),
				),
			),
		);
	}
}
