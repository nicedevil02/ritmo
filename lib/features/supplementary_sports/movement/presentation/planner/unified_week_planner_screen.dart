// lib/features/supplementary_sports/movement/presentation/planner/unified_week_planner_screen.dart

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:ritmo/core/domain/engines/ritmo_event_bus.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/ux/ritmo_haptics.dart';
import 'package:ritmo/features/supplementary_sports/domain/ss_readiness_service.dart';
import 'package:ritmo/features/supplementary_sports/movement/data/movement_reminder_service.dart';
import 'package:ritmo/features/supplementary_sports/movement/data/movement_slot_override_repository.dart';
import 'package:ritmo/features/supplementary_sports/movement/data/unified_planner_repository.dart';
import 'package:ritmo/features/supplementary_sports/movement/domain/movement_slot_override.dart';
import 'package:ritmo/features/supplementary_sports/movement/domain/movement_suggester.dart';
import 'package:ritmo/features/supplementary_sports/movement/domain/week_plan_item.dart';
import 'package:ritmo/features/supplementary_sports/movement/domain/week_slot_resolver.dart';
import 'package:ritmo/features/supplementary_sports/movement/presentation/movement_plan_sheet.dart';
import 'package:ritmo/features/supplementary_sports/movement/presentation/planner/movement_slot_actions_sheet.dart';
import 'package:ritmo/features/supplementary_sports/movement/presentation/planner/week_smart_fill_sheet.dart';
import 'package:ritmo/features/supplementary_sports/presentation/ss_plan_day_detail_screen.dart';

const String _fontFa = 'Vazirmatn';
const List<String> _shortDayNames = <String>['شن', 'یک', 'دو', 'سه', 'چه', 'پن', 'جم'];

/// نمای قابل‌جاسازی برنامهٔ هفته — بدون Scaffold — تا هم صفحهٔ مستقل باشد
/// هم تب «هفته» درون بخش جدید حرکت.
class UnifiedWeekPlannerView extends StatefulWidget {
	const UnifiedWeekPlannerView({super.key});

	@override
	State<UnifiedWeekPlannerView> createState() => _UnifiedWeekPlannerViewState();
}

class _UnifiedWeekPlannerViewState extends State<UnifiedWeekPlannerView> {
	late Future<UnifiedWeekPlan> _future;
	SSReadinessVerdict? _readinessVerdict;
	List<MovementSlotOverride> _thisWeekOverrides = [];
	int? _dropHighlight;

	@override
	void initState() {
		super.initState();
		_future = UnifiedPlannerRepository.instance.loadWeek();
		_fetchReadinessAndOverrides();
	}

	void _reload() {
		setState(() {
			_future = UnifiedPlannerRepository.instance.loadWeek();
		});
		_fetchReadinessAndOverrides();
	}

	Future<void> _fetchReadinessAndOverrides() async {
		try {
			final verdict = await SSReadinessService.instance.evaluateToday();
			final now = DateTime.now();
			final start = weekStartSaturday(now);
			final end = start.add(const Duration(days: 6));
			final overrides = await MovementSlotOverrideRepository.instance.forDateRange(
				formatDateIso(start),
				formatDateIso(end),
			);
			if (mounted) {
				setState(() {
					_readinessVerdict = verdict;
					_thisWeekOverrides = overrides;
				});
			}
		} catch (e) {
			debugPrint('[ss] unified_week_planner_screen.dart: $e');
		}
	}

	Future<void> _openNewPlan() async {
		RitmoHaptics.tap();
		await showMovementPlanSheet(context, onSaved: _reload);
	}

	Future<void> _openSmartFill() async {
		RitmoHaptics.tap();
		try {
			final suggestions = await MovementSuggester.suggestWeek();
			if (!mounted) return;
			if (suggestions.isEmpty) {
				ScaffoldMessenger.of(context).showSnackBar(
					const SnackBar(
						content: Text(
							'پیشنهاد مطمئنی ندارم — خودت بچین 😊',
							style: TextStyle(),
						),
					),
				);
				return;
			}
			await showWeekSmartFillSheet(
				context,
				suggestions: suggestions,
				onApplied: _reload,
			);
		} catch (e) {
			debugPrint('[ss] unified_week_planner_screen.dart smart fill error: $e');
		}
	}

	WeekPlanItem? _nextUp(UnifiedWeekPlan plan, int todaySat0) {
		for (var i = todaySat0; i < 7; i++) {
			for (final item in plan.byDay[i]) {
				if (!item.isCompleted) return item;
			}
		}
		return null;
	}

	Future<void> _applyLightToday(WeekPlanItem item) async {
		if (item.dateIso == null) return;
		try {
			await MovementSlotOverrideRepository.instance.light(
				routineId: item.id,
				dateIso: item.dateIso!,
			);
			RitmoEventBus().fire(
				RitmoEvent(
					type: 'light_accepted',
					timestamp: DateTime.now(),
					payload: {
						'routineId': item.id,
						'dateIso': item.dateIso,
					},
				),
			);
			await MovementReminderService.rescheduleWeekReminders();
			RitmoHaptics.success();
			if (mounted) {
				ScaffoldMessenger.of(context).showSnackBar(
					const SnackBar(
						content: Text(
							'امروز سبک‌تر — قالب هفته سر جایش می‌ماند 🌿',
							style: TextStyle(),
						),
					),
				);
			}
			_reload();
		} catch (e) {
			debugPrint('[ss] unified_week_planner_screen.dart: $e');
		}
	}

	Future<void> _skipToday(WeekPlanItem item) async {
		if (item.dateIso == null) return;
		try {
			await MovementSlotOverrideRepository.instance.skip(
				routineId: item.id,
				dateIso: item.dateIso!,
			);
			RitmoEventBus().fire(
				RitmoEvent(
					type: 'rest_day_accepted',
					timestamp: DateTime.now(),
					payload: {
						'routineId': item.id,
						'dateIso': item.dateIso,
					},
				),
			);
			await MovementReminderService.rescheduleWeekReminders();
			RitmoHaptics.success();
			if (mounted) {
				ScaffoldMessenger.of(context).showSnackBar(
					const SnackBar(
						content: Text(
							'جلسهٔ امروز رد شد — استراحت کن 🌿',
							style: TextStyle(),
						),
					),
				);
			}
			_reload();
		} catch (e) {
			debugPrint('[ss] unified_week_planner_screen.dart: $e');
		}
	}

	Future<void> _moveThisWeek(WeekPlanItem item, int destSat0) async {
		if (!item.isMovement || item.dateIso == null) return;
		if (item.weekdaySat0 == destSat0) return;
		final destIso = dateIsoForSat0(destSat0, DateTime.now());
		try {
			await MovementSlotOverrideRepository.instance.move(
				routineId: item.id,
				dateIso: item.dateIso!,
				newDateIso: destIso,
				newTime: item.timeLabel,
			);
			await MovementReminderService.rescheduleWeekReminders();
			RitmoHaptics.success();
			if (mounted) {
				ScaffoldMessenger.of(context).showSnackBar(
					SnackBar(
						content: Text(
							'فقط این هفته رفت به ${kPersianWeekdayNames[destSat0]}',
							style: const TextStyle(),
						),
					),
				);
			}
			_reload();
		} catch (e) {
			debugPrint('[ss] unified_week_planner_screen.dart: $e');
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
					return Center(child: CircularProgressIndicator(color: colors.primary));
				}
				if (snapshot.hasError || !snapshot.hasData) {
					return _buildError();
				}
				return _buildList(snapshot.data!, todaySat0, colors);
			},
		);
	}

	Widget _buildError() {
		final colors = context.colors;
		return Center(
			child: Padding(
				padding: const EdgeInsets.all(24),
				child: Column(
					mainAxisSize: MainAxisSize.min,
					children: [
						Icon(Icons.error_outline_rounded, color: colors.textTertiary, size: 40),
						const SizedBox(height: 12),
						Text(
							'خواندن برنامهٔ هفته ممکن نشد.',
							textAlign: TextAlign.center,
							style: TextStyle(color: colors.textSecondary, fontSize: 13),
						),
						const SizedBox(height: 12),
						ElevatedButton.icon(
							style: ElevatedButton.styleFrom(
								backgroundColor: colors.primary,
								foregroundColor: colors.onPrimary,
							),
							onPressed: _reload,
							icon: const Icon(Icons.refresh_rounded, size: 18),
							label: const Text(
								'تلاش دوباره',
								style: TextStyle(),
							),
						),
					],
				),
			),
		);
	}

	Widget _buildList(UnifiedWeekPlan plan, int todaySat0, RitmoColors colors) {
		final next = _nextUp(plan, todaySat0);
		final children = <Widget>[
			_buildHero(plan, todaySat0, next),
			const SizedBox(height: 10),
			_buildPulse(plan, next),
			const SizedBox(height: 12),
		];

		// Task 5: Friday Summary Card (کارت جمع‌بندی جمعه)
		if (todaySat0 == 6 && plan.completedItems >= 1) {
			children.add(_buildFridaySummaryCard(plan, colors));
			children.add(const SizedBox(height: 12));
		}

		children.add(_buildRhythmStrip(plan, todaySat0));
		children.add(const SizedBox(height: 12));

		if (plan.activeCampaign != null) {
			children.add(_buildActiveCampaignCard(plan));
		}
		for (int i = 0; i < 7; i++) {
			children.add(
				_buildDayCard(
					dayIndex: i,
					items: plan.byDay[i],
					isToday: i == todaySat0,
					weekHasPlan: plan.totalItems > 0,
					colors: colors,
				),
			);
		}
		return Stack(
			children: [
				ListView(
					padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
					children: children,
				),
				Positioned(
					left: 16,
					right: 16,
					bottom: 16,
					child: SizedBox(
						height: 52,
						child: ElevatedButton.icon(
							style: ElevatedButton.styleFrom(
								backgroundColor: const Color(0xFF10B981),
								foregroundColor: const Color(0xFF042116),
								elevation: 3,
								shape: RoundedRectangleBorder(
									borderRadius: BorderRadius.circular(16),
								),
							),
							onPressed: _openNewPlan,
							icon: const Icon(Icons.add_rounded, size: 22),
							label: const Text(
								'افزودن به هفته',
								style: TextStyle(
									fontSize: 15,
									fontWeight: FontWeight.bold,
								),
							),
						),
					),
				),
			],
		);
	}

	Widget _buildHero(UnifiedWeekPlan plan, int todaySat0, WeekPlanItem? next) {
		final todayEmpty = plan.byDay[todaySat0].isEmpty;

		if (plan.totalItems == 0) {
			return _heroShell(
				kicker: 'هفته هنوز خالی است',
				title: 'ریتمت را بساز',
				body: 'سه جلسهٔ واقعی کافی است. بقیه را خودت بچین یا از پر کردن هوشمند کمک بگیر.',
				actions: [
					_heroBtn('افزودن جلسه', primary: true, onTap: _openNewPlan),
					_heroBtn('✨ پر کردن هوشمند', onTap: _openSmartFill),
				],
			);
		}

		// Task 2: Readiness-aware Hero (چراغ آمادگی روی کارت قهرمان)
		final verdict = _readinessVerdict;
		if (verdict != null && verdict.hasData && next != null && next.weekdaySat0 == todaySat0 && !next.isCompleted) {
			if (verdict.tier == SSReadinessTier.light || verdict.tier == SSReadinessTier.minimal) {
				return _heroShell(
					kicker: 'آمادگی پایین امروز ${verdict.emoji}',
					title: '${next.emoji} ${next.title}',
					body: verdict.reasonFa,
					amber: true,
					actions: [
						_heroBtn(
							'⚡ نسخهٔ سبک',
							primary: true,
							customColor: const Color(0xFFF59E0B),
							onTap: () => _applyLightToday(next),
						),
						_heroBtn('جزئیات', onTap: () => _openItem(next)),
					],
				);
			}

			if (verdict.tier == SSReadinessTier.rest) {
				return _heroShell(
					kicker: 'نیاز به ریکاوری ${verdict.emoji}',
					title: 'پیشنهاد: استراحت امروز',
					body: verdict.reasonFa,
					amber: true,
					actions: [
						_heroBtn(
							'امروز نرو',
							primary: true,
							customColor: const Color(0xFFF59E0B),
							onTap: () => _skipToday(next),
						),
						_heroBtn('اگر خواستی، نسخه سبک', onTap: () => _applyLightToday(next)),
					],
				);
			}
		}

		if (next != null && next.weekdaySat0 == todaySat0) {
			final timeLabel = next.timeLabel;
			final time = timeLabel == null ? '' : toPersianDigits(timeLabel);
			return _heroShell(
				kicker: 'امروز ${kPersianWeekdayNames[todaySat0]}${time.isEmpty ? '' : ' · $time'}',
				title: '${next.emoji} ${next.title}',
				body: next.isLight
						? 'نسخهٔ سبک امروز — قالب هفته سر جایش می‌ماند'
						: (next.reminderMinutes > 0
								? 'یادآوری ${toPersianDigits(next.reminderMinutes.toString())} دقیقه قبل'
								: (next.detailLabel ?? next.targetLabel ?? 'حرکت برنامه‌ریزی‌شده')),
				actions: [
					_heroBtn('جزئیات', onTap: () => _openItem(next)),
				],
			);
		}
		if (todayEmpty) {
			return _heroShell(
				kicker: 'امروز ${kPersianWeekdayNames[todaySat0]}',
				title: 'ریکاوری محافظت‌شده',
				body: 'خالی نیست. این روز عمداً برای بازسازی کنار گذاشته شده.',
				rest: true,
				actions: [
					_heroBtn('اگر خواستی، یک حرکت سبک', onTap: _openNewPlan),
				],
			);
		}
		final nextLabel = next == null
				? 'این هفته جلسهٔ باز دیگری ندارد.'
				: 'بعدی: ${kPersianWeekdayNames[next.weekdaySat0]} · ${next.title}';
		return _heroShell(
			kicker: 'امروز ${kPersianWeekdayNames[todaySat0]}',
			title: 'جلسات امروز انجام شد',
			body: nextLabel,
			actions: [
				_heroBtn('افزودن جلسه', onTap: _openNewPlan),
			],
		);
	}

	Widget _heroShell({
		required String kicker,
		required String title,
		required String body,
		required List<Widget> actions,
		bool rest = false,
		bool amber = false,
	}) {
		final colors = context.colors;
		final isDark = Theme.of(context).brightness == Brightness.dark;
		final Color accentColor = amber
				? const Color(0xFFF59E0B)
				: (rest ? colors.primary : colors.primary);

		return Container(
			padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
			decoration: BoxDecoration(
				borderRadius: BorderRadius.circular(22),
				border: Border.all(
					color: amber
							? const Color(0xFFF59E0B).withValues(alpha: 0.6)
							: (rest
									? colors.primary.withValues(alpha: 0.3)
									: accentColor.withValues(alpha: 0.3)),
					width: amber ? 1.5 : 1.0,
				),
				gradient: LinearGradient(
					begin: Alignment.topRight,
					end: Alignment.bottomLeft,
					colors: isDark
							? (amber
									? [const Color(0xFFF59E0B).withValues(alpha: 0.20), colors.surfaceElevated]
									: (rest
											? [colors.primaryContainer.withValues(alpha: 0.25), colors.surfaceElevated]
											: [colors.primaryContainer.withValues(alpha: 0.35), colors.surfaceElevated]))
							: (amber
									? [const Color(0xFFF59E0B).withValues(alpha: 0.30), colors.surface]
									: (rest
											? [colors.primaryContainer.withValues(alpha: 0.5), colors.surface]
											: [colors.primaryContainer.withValues(alpha: 0.7), colors.surface])),
				),
			),
			child: Column(
				crossAxisAlignment: CrossAxisAlignment.stretch,
				children: [
					Text(
						kicker,
						style: TextStyle(
							fontSize: 11,
							fontWeight: FontWeight.w700,
							color: amber ? const Color(0xFFF59E0B) : (rest ? colors.primary : accentColor),
						),
					),
					const SizedBox(height: 4),
					Text(
						title,
						maxLines: 2,
						overflow: TextOverflow.ellipsis,
						style: TextStyle(
							fontSize: 20,
							fontWeight: FontWeight.w800,
							color: colors.textPrimary,
						),
					),
					const SizedBox(height: 4),
					Text(
						body,
						style: TextStyle(
							fontSize: 13,
							color: colors.textSecondary,
							height: 1.5,
						),
					),
					if (actions.isNotEmpty) ...[
						const SizedBox(height: 12),
						Wrap(spacing: 8, runSpacing: 8, children: actions),
					],
				],
			),
		);
	}

	Widget _heroBtn(
		String label, {
		required VoidCallback onTap,
		bool primary = false,
		Color? customColor,
	}) {
		final colors = context.colors;
		final btnBg = customColor ?? (primary ? colors.primary : colors.surfaceSunken);
		final btnFg = customColor != null
				? Colors.black
				: (primary ? colors.onPrimary : colors.textPrimary);

		return TextButton(
			style: TextButton.styleFrom(
				backgroundColor: btnBg,
				foregroundColor: btnFg,
				padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
				shape: RoundedRectangleBorder(
					borderRadius: BorderRadius.circular(12),
					side: (primary || customColor != null)
							? BorderSide.none
							: BorderSide(color: colors.border),
				),
			),
			onPressed: onTap,
			child: Text(
				label,
				style: const TextStyle(
					fontWeight: FontWeight.w700,
					fontSize: 12.5,
				),
			),
		);
	}

	Widget _buildPulse(UnifiedWeekPlan plan, WeekPlanItem? next) {
		return Row(
			children: [
				Expanded(
					flex: 13,
					child: _pulseCard(
						value: plan.totalItems == 0
								? '—'
								: '${toPersianDigits(plan.completedItems.toString())} از ${toPersianDigits(plan.totalItems.toString())}',
						label: 'جلسه این هفته',
						bar: plan.totalItems == 0 ? 0.0 : plan.completedItems / plan.totalItems,
					),
				),
				const SizedBox(width: 8),
				Expanded(
					flex: 7,
					child: _pulseCard(
						value: toPersianDigits(plan.restDayCount.toString()),
						label: 'روز ریکاوری',
					),
				),
				const SizedBox(width: 8),
				Expanded(
					flex: 7,
					child: _pulseCard(
						value: next?.timeLabel == null ? '—' : toPersianDigits(next!.timeLabel),
						label: 'بعدی',
					),
				),
			],
		);
	}

	Widget _pulseCard({required String value, required String label, double? bar}) {
		final colors = context.colors;
		return Container(
			padding: const EdgeInsets.fromLTRB(10, 10, 10, 9),
			decoration: BoxDecoration(
				color: colors.surface,
				borderRadius: BorderRadius.circular(14),
				border: Border.all(color: colors.border),
			),
			child: Column(
				crossAxisAlignment: CrossAxisAlignment.start,
				children: [
					Text(
						value,
						maxLines: 1,
						overflow: TextOverflow.ellipsis,
						style: TextStyle(
							fontSize: 15,
							fontWeight: FontWeight.w800,
							color: colors.textPrimary,
						),
					),
					const SizedBox(height: 2),
					Text(
						label,
						style: TextStyle(
							fontSize: 10.5,
							color: colors.textSecondary,
						),
					),
					if (bar != null) ...[
						const SizedBox(height: 8),
						ClipRRect(
							borderRadius: BorderRadius.circular(99),
							child: LinearProgressIndicator(
								value: bar.clamp(0.0, 1.0),
								minHeight: 4,
								backgroundColor: colors.surfaceSunken,
								valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
							),
						),
					],
				],
			),
		);
	}

	// Task 5: Friday summary card (جمع‌بندی جمعه)
	Widget _buildFridaySummaryCard(UnifiedWeekPlan plan, RitmoColors colors) {
		final moveRetimeOverrides = _thisWeekOverrides
				.where((o) => o.action == MovementSlotAction.move || o.action == MovementSlotAction.retime)
				.toList();

		final int completed = plan.completedItems;
		final int total = plan.totalItems;
		final int shifts = moveRetimeOverrides.length;

		final String summaryText = shifts > 0
				? 'این هفته ${toPersianDigits(completed.toString())} از ${toPersianDigits(total.toString())} جلسه رو رفتی، ${toPersianDigits(shifts.toString())} بار جابه‌جا کردی.'
				: 'این هفته ${toPersianDigits(completed.toString())} از ${toPersianDigits(total.toString())} جلسه رو کامل رفتی! ریتمت عالی بود 💚';

		return Container(
			padding: const EdgeInsets.all(14),
			decoration: BoxDecoration(
				color: colors.surfaceElevated,
				borderRadius: BorderRadius.circular(18),
				border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.5)),
			),
			child: Column(
				crossAxisAlignment: CrossAxisAlignment.stretch,
				children: [
					Row(
						children: [
							const Text('🧾', style: TextStyle(fontSize: 20)),
							const SizedBox(width: 8),
							Text(
								'جمع‌بندی جمعه',
								style: TextStyle(
									fontSize: 15,
									fontWeight: FontWeight.bold,
									color: colors.textPrimary,
								),
							),
						],
					),
					const SizedBox(height: 6),
					Text(
						summaryText,
						style: TextStyle(
							fontSize: 12.5,
							color: colors.textSecondary,
							height: 1.4,
						),
					),
					const SizedBox(height: 12),
					if (shifts > 0) ...[
						Row(
							children: [
								Expanded(
									child: ElevatedButton(
										style: ElevatedButton.styleFrom(
											backgroundColor: const Color(0xFF10B981),
											foregroundColor: const Color(0xFF042116),
											shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
											padding: const EdgeInsets.symmetric(vertical: 10),
										),
										onPressed: () async {
											RitmoHaptics.tap();
											await MovementSlotOverrideRepository.instance.permanentizeWeek(moveRetimeOverrides);
											RitmoHaptics.success();
											if (mounted) {
												ScaffoldMessenger.of(context).showSnackBar(
													const SnackBar(
														content: Text(
															'قالب هفتگی با تغییرات جدید به‌روز شد ✓',
															style: TextStyle(),
														),
													),
												);
											}
											_reload();
										},
										child: const Text(
											'این تغییرها دائمی بشه',
											style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
										),
									),
								),
								const SizedBox(width: 8),
								Expanded(
									child: OutlinedButton(
										style: OutlinedButton.styleFrom(
											shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
											padding: const EdgeInsets.symmetric(vertical: 10),
											side: BorderSide(color: colors.border),
										),
										onPressed: () {
											RitmoHaptics.tap();
											ScaffoldMessenger.of(context).showSnackBar(
												const SnackBar(
													content: Text(
														'قالب هفته سر جایش موند ✓',
														style: TextStyle(),
													),
												),
											);
										},
										child: Text(
											'فقط همین هفته بود',
											style: TextStyle(color: colors.textPrimary, fontSize: 12),
										),
									),
								),
							],
						),
					] else ...[
						ElevatedButton(
							style: ElevatedButton.styleFrom(
								backgroundColor: const Color(0xFF10B981),
								foregroundColor: const Color(0xFF042116),
								shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
								padding: const EdgeInsets.symmetric(vertical: 10),
							),
							onPressed: () {
								RitmoHaptics.tap();
								RitmoEventBus().fire(
									RitmoEvent(
										type: 'week_rhythm_confirmed',
										timestamp: DateTime.now(),
										payload: const <String, dynamic>{},
									),
								);
								ScaffoldMessenger.of(context).showSnackBar(
									const SnackBar(
										content: Text(
											'ریتم این هفته تأیید شد! آماده برای هفتهٔ بعد 🚀',
											style: TextStyle(),
										),
									),
								);
							},
							child: const Text(
								'همین ریتم برای هفتهٔ بعد 💚',
								style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
							),
						),
					],
				],
			),
		);
	}

	Widget _buildRhythmStrip(UnifiedWeekPlan plan, int todaySat0) {
		final colors = context.colors;
		return Column(
			children: [
				Row(
					mainAxisAlignment: MainAxisAlignment.spaceBetween,
					children: [
						Text('نوار ریتم', style: TextStyle(fontSize: 12, color: colors.textSecondary)),
						Text('هر ستون یک روز', style: TextStyle(fontSize: 12, color: colors.textSecondary)),
					],
				),
				const SizedBox(height: 8),
				Container(
					padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
					decoration: BoxDecoration(
						color: colors.surface,
						borderRadius: BorderRadius.circular(18),
						border: Border.all(color: colors.border),
					),
					child: Row(
						children: [
							for (var i = 0; i < 7; i++)
								Expanded(child: _beat(plan, i, todaySat0)),
						],
					),
				),
			],
		);
	}

	Widget _beat(UnifiedWeekPlan plan, int sat0, int todaySat0) {
		final colors = context.colors;
		final items = plan.byDay[sat0];
		final isToday = sat0 == todaySat0;
		final isPast = sat0 < todaySat0;
		final bool hasPlan = items.isNotEmpty;
		final bool allDone = hasPlan && items.every((e) => e.isCompleted);
		final isDark = Theme.of(context).brightness == Brightness.dark;

		Color bg;
		Color border;
		Color text;
		if (allDone) {
			bg = colors.primary;
			border = colors.primary;
			text = colors.onPrimary;
		} else if (hasPlan) {
			bg = colors.primaryContainer.withValues(alpha: isDark ? 0.35 : 0.6);
			border = isToday ? colors.primary : colors.primary.withValues(alpha: 0.4);
			text = colors.textPrimary;
		} else {
			bg = colors.surfaceSunken;
			border = isToday ? colors.primary.withValues(alpha: 0.5) : colors.border;
			text = isPast ? colors.textTertiary : colors.textSecondary;
		}

		final String label = hasPlan ? (items.first.emoji) : (isToday ? 'امروز' : '—');

		return Container(
			margin: const EdgeInsets.symmetric(horizontal: 2),
			padding: const EdgeInsets.symmetric(vertical: 6),
			decoration: BoxDecoration(
				color: bg,
				borderRadius: BorderRadius.circular(12),
				border: Border.all(color: border, width: isToday ? 1.5 : 1.0),
			),
			child: Column(
				mainAxisSize: MainAxisSize.min,
				children: [
					Text(_shortDayNames[sat0], style: TextStyle(fontSize: 11, color: text, fontWeight: FontWeight.bold)),
					const SizedBox(height: 4),
					Text(
						label,
						style: TextStyle(
							fontSize: hasPlan ? 14 : 10,
							color: text,
							fontWeight: FontWeight.w600,
						),
					),
				],
			),
		);
	}

	Widget _buildActiveCampaignCard(UnifiedWeekPlan plan) {
		final colors = context.colors;
		final campaign = plan.activeCampaign!;
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
				color: colors.surfaceElevated,
				borderRadius: BorderRadius.circular(16),
				border: Border.all(color: colors.primary.withValues(alpha: 0.5)),
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
									style: TextStyle(
										color: colors.textPrimary,
										fontSize: 13,
										fontWeight: FontWeight.bold,
									),
								),
							),
							Text(
								'هفتهٔ ${toPersianDigits(currentWeek.toString())} از ${toPersianDigits(campaign.weeks.toString())}',
								style: TextStyle(color: colors.textSecondary, fontSize: 11),
							),
						],
					),
					const SizedBox(height: 10),
					ClipRRect(
						borderRadius: BorderRadius.circular(10),
						child: LinearProgressIndicator(
							value: percent,
							backgroundColor: colors.surfaceSunken,
							valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
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
		required bool weekHasPlan,
		required RitmoColors colors,
	}) {
		final dropping = _dropHighlight == dayIndex;
		final isDark = Theme.of(context).brightness == Brightness.dark;
		return DragTarget<WeekPlanItem>(
			onWillAcceptWithDetails: (details) {
				setState(() => _dropHighlight = dayIndex);
				return details.data.isMovement && details.data.dateIso != null;
			},
			onLeave: (_) {
				if (_dropHighlight == dayIndex) setState(() => _dropHighlight = null);
			},
			onAcceptWithDetails: (details) {
				setState(() => _dropHighlight = null);
				_moveThisWeek(details.data, dayIndex);
			},
			builder: (context, candidate, rejected) {
				return Container(
					margin: const EdgeInsets.only(bottom: 10),
					padding: const EdgeInsets.all(12),
					decoration: BoxDecoration(
						color: isToday
								? colors.primaryContainer.withValues(alpha: isDark ? 0.25 : 0.45)
								: colors.surface,
						borderRadius: BorderRadius.circular(16),
						border: Border.all(
							color: dropping
									? colors.primary
									: (isToday
											? colors.primary.withValues(alpha: 0.6)
											: colors.border),
						),
					),
					child: Column(
						crossAxisAlignment: CrossAxisAlignment.stretch,
						children: [
							Row(
								children: [
									Expanded(
										child: Text(
											'${kPersianWeekdayNames[dayIndex]}${isToday ? ' · امروز' : ''}',
											maxLines: 1,
											overflow: TextOverflow.ellipsis,
											style: TextStyle(
												color: colors.textPrimary,
												fontSize: 14,
												fontWeight: FontWeight.bold,
											),
										),
									),
									Text(
										items.isEmpty
												? (weekHasPlan ? 'آرامش' : 'خالی')
												: '${toPersianDigits(items.length.toString())} جلسه',
										style: TextStyle(color: colors.textSecondary, fontSize: 11),
									),
								],
							),
							const SizedBox(height: 8),
							if (items.isEmpty)
								_emptyDayBody(weekHasPlan)
							else
								...items.map(_buildItemTile),
						],
					),
				);
			},
		);
	}

	Widget _emptyDayBody(bool weekHasPlan) {
		final colors = context.colors;
		if (!weekHasPlan) {
			return Text(
				'هنوز چیده نشده',
				style: TextStyle(color: colors.textTertiary, fontSize: 12),
			);
		}
		return Container(
			padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
			decoration: BoxDecoration(
				color: colors.primaryContainer.withValues(alpha: 0.2),
				borderRadius: BorderRadius.circular(14),
				border: Border.all(color: colors.primary.withValues(alpha: 0.3), style: BorderStyle.solid),
			),
			child: Row(
				children: [
					Expanded(
						child: Text('🌿 ریکاوری', style: TextStyle(color: colors.primary, fontSize: 12.5, fontWeight: FontWeight.w700)),
					),
					Text('محافظت‌شده', style: TextStyle(color: colors.textSecondary, fontSize: 11)),
				],
			),
		);
	}

	Widget _buildItemTile(WeekPlanItem item) {
		final colors = context.colors;
		final timeLabel = item.timeLabel;
		final targetLabel = item.targetLabel;
		final detailLabel = item.detailLabel;
		final subtitleParts = <String>[
			if (item.isLight) 'نسخه سبک',
			if (timeLabel != null) toPersianDigits(timeLabel),
			if (targetLabel != null) toPersianDigits(targetLabel),
			if (detailLabel != null && detailLabel.isNotEmpty) detailLabel,
		];
		final tile = InkWell(
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
											color: colors.textPrimary,
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
											style: TextStyle(color: colors.textSecondary, fontSize: 11),
										),
								],
							),
						),
						if (item.isMovement && item.dateIso != null)
							IconButton(
								tooltip: 'فقط این هفته',
								icon: Icon(Icons.more_horiz_rounded, color: colors.textTertiary, size: 18),
								onPressed: () async {
									final changed = await showMovementSlotActionsSheet(context, item: item);
									if (changed) _reload();
								},
							)
						else if (item.isCompleted)
							Icon(Icons.check_circle_rounded, color: colors.primary, size: 18)
						else
							Icon(Icons.chevron_left_rounded, color: colors.textTertiary, size: 18),
					],
				),
			),
		);

		if (!item.isMovement || item.dateIso == null) {
			return Semantics(button: true, label: item.title, child: tile);
		}

		return LongPressDraggable<WeekPlanItem>(
			data: item,
			hapticFeedbackOnStart: true,
			feedback: Material(
				color: Colors.transparent,
				child: Container(
					padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
					decoration: BoxDecoration(
						color: colors.surfaceElevated,
						borderRadius: BorderRadius.circular(12),
						border: Border.all(color: colors.primary),
						boxShadow: [
							BoxShadow(
								color: colors.shadow.withValues(alpha: 0.2),
								blurRadius: 10,
							),
						],
					),
					child: Text('${item.emoji} ${item.title}', style: TextStyle(color: colors.textPrimary, fontSize: 13)),
				),
			),
			childWhenDragging: Opacity(opacity: 0.35, child: tile),
			child: tile,
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
											icon: Icon(Icons.arrow_forward_rounded, color: colors.textPrimary),
											onPressed: () => Navigator.of(context).pop(),
										),
										Expanded(
											child: Text(
												'برنامهٔ هفته',
												maxLines: 1,
												overflow: TextOverflow.ellipsis,
												style: TextStyle(
													fontSize: 18,
													fontWeight: FontWeight.bold,
													color: colors.textPrimary,
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
