// lib/features/supplementary_sports/movement/data/unified_planner_repository.dart

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/features/supplementary_sports/movement/data/movement_campaign_repository.dart';
import 'package:ritmo/features/supplementary_sports/movement/domain/movement_campaign.dart';
import 'package:ritmo/features/supplementary_sports/movement/domain/week_plan_item.dart';

/// مخزن یکپارچهٔ برنامهٔ هفته — دو منبع داده را کنار هم می‌نشاند:
///
///   ۱. routines + routine_schedules  →  همهٔ ورزش‌ها (شامل قدرتی خانگی/باشگاه)
///   ۲. ss_workout_plan               →  روزهای برنامهٔ قدرتی ساختاریافته
///
/// وضعیت انجام از routine_completions و جلسات completed خوانده می‌شود و
/// کارزار فعال (در صورت وجود) هم لود می‌شود تا کارت آن بالای تقویم بنشیند.
/// هیچ‌کدام از جداول را تغییر نمی‌دهد؛ فقط می‌خواند و یکپارچه نمایش می‌دهد.
class UnifiedPlannerRepository {
	UnifiedPlannerRepository._();
	static final UnifiedPlannerRepository instance = UnifiedPlannerRepository._();

	Future<UnifiedWeekPlan> loadWeek() async {
		final db = await DatabaseHelper.instance.database;
		final byDay = List<List<WeekPlanItem>>.generate(7, (_) => <WeekPlanItem>[]);

		final completedRoutineKeys = await _loadRoutineCompletions(db);
		final completedStrengthDates = await _loadCompletedStrengthDates(db);
		final activeCampaign = await _loadActiveCampaign();

		await _appendMovementItems(db, byDay, completedRoutineKeys);
		await _appendStrengthItems(db, byDay, completedStrengthDates);

		// مرتب‌سازی داخل هر روز: بر اساس ساعت شروع.
		for (final day in byDay) {
			day.sort((a, b) {
				final aTime = a.timeLabel ?? '99:99';
				final bTime = b.timeLabel ?? '99:99';
				return aTime.compareTo(bTime);
			});
		}
		return UnifiedWeekPlan(byDay: byDay, activeCampaign: activeCampaign);
	}

	/// کارزار فعال — همان منطق MovementPlanTab قدیمی، این‌بار در یک جای مشترک.
	Future<MovementCampaign?> _loadActiveCampaign() async {
		try {
			final campaign = await MovementCampaignRepository.instance.getActiveCampaign();
			if (campaign != null) {
				await MovementCampaignRepository.instance.checkAndUpdateCampaignWeek(campaign.id);
				return MovementCampaignRepository.instance.getActiveCampaign();
			}
		} catch (e) {
			debugPrint('[ss] unified_planner_repository.dart: $e');
		}
		return null;
	}

	/// روتین‌های حرکتی — قرارداد daysOfWeek همان DateTime.weekday است.
	Future<void> _appendMovementItems(
		dynamic db,
		List<List<WeekPlanItem>> byDay,
		Set<String> completedRoutineKeys,
	) async {
		try {
			final routines = await db.query(
				'routines',
				where: "category = 'fitness' AND isArchived = 0 AND movementKind IS NOT NULL",
			);
			final schedules = await db.query('routine_schedules');
			final schedulesByRoutine = <String, List<Map<String, dynamic>>>{};
			for (final s in schedules) {
				final rid = s['routineId']?.toString();
				if (rid == null) continue;
				schedulesByRoutine.putIfAbsent(rid, () => <Map<String, dynamic>>[]).add(s);
			}

			for (final r in routines) {
				final routineId = r['id']?.toString();
				if (routineId == null) continue;
				final routineSchedules = schedulesByRoutine[routineId] ?? const [];
				if (routineSchedules.isEmpty) continue;

				final String title = r['title']?.toString() ?? 'فعالیت حرکتی';
				final String? timeLabel = routineSchedules.first['timeOfDay']?.toString();
				final String targetLabel = _movementTargetLabel(r);

				// هر روتین ممکن است چند روز در هفته تکرار شود.
				final Set<int> weekdays = <int>{};
				for (final s in routineSchedules) {
					final daysStr = s['daysOfWeek']?.toString() ?? '';
					for (final part in daysStr.split(',')) {
						final w = int.tryParse(part.trim());
						if (w != null) weekdays.add(w);
					}
				}

				for (final dartWeekday in weekdays) {
					final sat0 = dartWeekdayToSat0(dartWeekday);
					final dateStr = _dateOfWeekdayThisWeek(sat0);
					byDay[sat0].add(
						WeekPlanItem(
							source: WeekPlanSource.movement,
							id: routineId,
							weekdaySat0: sat0,
							title: title,
							emoji: _movementEmoji(r['movementKind']?.toString()),
							timeLabel: timeLabel,
							targetLabel: targetLabel,
							isCompleted: completedRoutineKeys.contains('$routineId:$dateStr'),
							routineRaw: Map<String, dynamic>.from(r as Map),
						),
					);
				}
			}
		} catch (e) {
			debugPrint('[ss] unified_planner_repository.dart: $e');
		}
	}

	/// روزهای برنامهٔ قدرتی — قرارداد dayOfWeek شنبه‌محور است (۱=شنبه).
	Future<void> _appendStrengthItems(
		dynamic db,
		List<List<WeekPlanItem>> byDay,
		Set<String> completedStrengthDates,
	) async {
		try {
			final plans = await db.query('ss_workout_plan');
			for (final p in plans) {
				final planId = p['id']?.toString();
				if (planId == null) continue;
				final int ssDay = (p['dayOfWeek'] as num? ?? 1).toInt();
				final sat0 = ssDayOfWeekToSat0(ssDay);
				final int minutes = (p['estimatedMinutes'] as num? ?? 45).toInt();
				final String muscles = _muscleGroupsLabel(p['muscleGroups']);
				final dateStr = _dateOfWeekdayThisWeek(sat0);

				byDay[sat0].add(
					WeekPlanItem(
						source: WeekPlanSource.strength,
						id: planId,
						weekdaySat0: sat0,
						title: 'تمرین قدرتی',
						emoji: '🏋️',
						targetLabel: '$minutes دقیقه',
						detailLabel: muscles,
						isCompleted: completedStrengthDates.contains(dateStr),
					),
				);
			}
		} catch (e) {
			debugPrint('[ss] unified_planner_repository.dart: $e');
		}
	}

	/// تکمیل‌های روتین در هفتهٔ جاری: کلید '<routineId>:<yyyy-MM-dd>'
	Future<Set<String>> _loadRoutineCompletions(dynamic db) async {
		final keys = <String>{};
		try {
			final rows = await db.query('routine_completions');
			for (final c in rows) {
				final rid = c['routineId']?.toString();
				final day = c['completionDate']?.toString();
				if (rid != null && day != null) keys.add('$rid:$day');
			}
		} catch (e) {
			debugPrint('[ss] unified_planner_repository.dart: $e');
		}
		return keys;
	}

	/// تاریخ‌هایی از هفتهٔ جاری که جلسهٔ قدرتی (SS_SESSION) کامل شده است.
	Future<Set<String>> _loadCompletedStrengthDates(dynamic db) async {
		final dates = <String>{};
		try {
			final rows = await db.query(
				'movement_sessions',
				columns: <String>['startedAt'],
				where: "kindCode = 'SS_SESSION' AND status = 'completed'",
			);
			for (final row in rows) {
				final startedAt = (row['startedAt'] as num?)?.toInt();
				if (startedAt == null) continue;
				dates.add(_dateStr(DateTime.fromMillisecondsSinceEpoch(startedAt)));
			}
		} catch (e) {
			debugPrint('[ss] unified_planner_repository.dart: $e');
		}
		return dates;
	}

	/// تاریخ (yyyy-MM-dd) متناظر با یک روز از هفتهٔ جاری شمسی.
	String _dateOfWeekdayThisWeek(Sat0Weekday sat0) {
		final now = DateTime.now();
		final todaySat0 = dartWeekdayToSat0(now.weekday);
		final dayDate = DateTime(now.year, now.month, now.day)
				.add(Duration(days: sat0 - todaySat0));
		return _dateStr(dayDate);
	}

	String _dateStr(DateTime d) =>
			'${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

	String _movementTargetLabel(Map<String, dynamic> routine) {
		final metric = routine['movementTargetMetric']?.toString().toUpperCase() ?? 'DURATION';
		final value = (routine['movementTargetValue'] as num?)?.toDouble() ?? 0;
		final duration = (routine['targetDurationMinutes'] as num?)?.toInt() ?? 30;
		switch (metric) {
			case 'DISTANCE':
				return '${value.toStringAsFixed(1)} کیلومتر';
			case 'LAPS':
				return '${value.round()} طول';
			case 'ELEVATION':
				return '${value.round()} متر صعود';
			case 'STEPS':
				return '${value.round()} گام';
			case 'DURATION':
			default:
				return '$duration دقیقه';
		}
	}

	String _movementEmoji(String? kindCode) {
		const emojiByKind = <String, String>{
			'WALKING': '🚶',
			'BRISK_WALKING': '🚶‍♂️',
			'RUNNING': '🏃',
			'TRAIL_RUNNING': '🏃‍♂️',
			'CYCLING': '🚴',
			'SWIMMING': '🏊',
			'HIKING': '🥾',
			'NATURE_WALK': '🌲',
			'YOGA': '🧘',
			'PILATES': '🤸',
			'STRETCHING': '🙆',
			'FOOTBALL': '⚽',
			'FUTSAL': '⚽',
			'VOLLEYBALL': '🏐',
			'BASKETBALL': '🏀',
			'TENNIS': '🎾',
			'BADMINTON': '🏸',
			'KARATE': '🥋',
			'TAEKWONDO': '🥋',
			'BOXING': '🥊',
			'STRENGTH_GYM': '🏋️',
			'STRENGTH_HOME': '🏠',
			'SS_SESSION': '🏋️',
			'SKIING': '⛷️',
			'DANCE': '💃',
		};
		return emojiByKind[kindCode] ?? '🏃';
	}

	String _muscleGroupsLabel(dynamic raw) {
		try {
			if (raw is String && raw.isNotEmpty) {
				final decoded = jsonDecode(raw);
				if (decoded is List) {
					return decoded.map((e) => e.toString()).join('، ');
				}
			}
		} catch (e) {
			debugPrint('[ss] unified_planner_repository.dart: $e');
		}
		return '';
	}
}
