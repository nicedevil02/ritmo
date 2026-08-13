// lib/features/supplementary_sports/movement/domain/week_plan_item.dart

/// مدل یکپارچهٔ یک آیتم برنامهٔ هفتگی — فارغ از اینکه از کدام دنیای داده آمده.
///
/// امروز دو منبع داده داریم که در UI جدا دیده می‌شوند:
///   ۱. روتین‌های حرکتی: جدول routines + routine_schedules
///      قرارداد daysOfWeek: یکشنبه=۷ ... شنبه=۶ (همان DateTime.weekday)
///   ۲. برنامهٔ قدرتی: جدول ss_workout_plan
///      قرارداد dayOfWeek: شنبه=۱ ... جمعه=۷ (شنبه‌محور)
///
/// این فایل هر دو را به یک شاخص کانونی تبدیل می‌کند تا تقویم هفتگی
/// همهٔ ورزش‌ها را کنار هم نشان دهد.
library;

import 'package:ritmo/features/supplementary_sports/movement/domain/movement_campaign.dart';

/// شاخص کانونی روز هفته: ۰=شنبه، ۱=یکشنبه، ... ۶=جمعه
typedef Sat0Weekday = int;

/// تبدیل DateTime.weekday (۱=دوشنبه ... ۷=یکشنبه) به شاخص کانونی.
Sat0Weekday dartWeekdayToSat0(int dartWeekday) => (dartWeekday + 1) % 7;

/// تبدیل dayOfWeek شنبه‌محور ss_workout_plan (۱=شنبه ... ۷=جمعه) به شاخص کانونی.
Sat0Weekday ssDayOfWeekToSat0(int ssDayOfWeek) => (ssDayOfWeek - 1).clamp(0, 6);

/// نام فارسی روزهای هفته به ترتیب کانونی (شنبه تا جمعه).
const List<String> kPersianWeekdayNames = <String>[
	'شنبه',
	'یکشنبه',
	'دوشنبه',
	'سه‌شنبه',
	'چهارشنبه',
	'پنجشنبه',
	'جمعه',
];

/// منشأ آیتم برنامه.
enum WeekPlanSource {
	/// روتین حرکتی (هر یک از ۴۹ ورزش، از جمله قدرتی خانگی/باشگاه)
	movement,

	/// روز برنامهٔ قدرتی ساختاریافته (ss_workout_plan)
	strength,
}

/// یک آیتم در یک روز مشخص از هفته.
class WeekPlanItem {
	const WeekPlanItem({
		required this.source,
		required this.id,
		required this.weekdaySat0,
		required this.title,
		this.emoji = '🏃',
		this.timeLabel,
		this.targetLabel,
		this.detailLabel,
		this.isCompleted = false,
		this.routineRaw,
		this.scheduleId,
		this.dateIso,
		this.reminderMinutes = 0,
		this.isLight = false,
		this.isOverride = false,
	});

	final WeekPlanSource source;

	/// routineId یا planId
	final String id;

	/// روز هفته به شاخص کانونی (۰=شنبه ... ۶=جمعه)
	final Sat0Weekday weekdaySat0;

	final String title;
	final String emoji;

	/// ساعت شروع، مثل «۰۷:۰۰»
	final String? timeLabel;

	/// هدف قابل‌خواندن، مثل «۴۰ دقیقه» یا «۳ کیلومتر» یا «۶۰۰ متر صعود»
	final String? targetLabel;

	/// جزئیات تکمیلی، مثل گروه‌های عضلانی روز قدرتی
	final String? detailLabel;

	/// آیا در هفتهٔ جاری انجام شده است؟
	final bool isCompleted;

	/// نقشهٔ خام روتین برای ویرایش با MovementPlanSheet (فقط منبع movement)
	final Map<String, dynamic>? routineRaw;

	/// شناسهٔ ردیف routine_schedules اگر آیتم از یک schedule مشخص آمده باشد.
	final String? scheduleId;

	/// تاریخ تقویمی این وقوع در هفتهٔ جاری (yyyy-MM-dd).
	final String? dateIso;

	/// دقیقهٔ یادآوری قبل از شروع؛ ۰ یعنی خاموش.
	final int reminderMinutes;

	/// نسخهٔ سبک فقط برای این وقوع.
	final bool isLight;

	/// این وقوع با استثنای این‌هفته عوض شده، نه با قالب.
	final bool isOverride;

	bool get isMovement => source == WeekPlanSource.movement;
	bool get isStrength => source == WeekPlanSource.strength;

	WeekPlanItem copyWith({
		Sat0Weekday? weekdaySat0,
		String? timeLabel,
		bool? isCompleted,
		String? dateIso,
		bool? isLight,
		bool? isOverride,
	}) {
		return WeekPlanItem(
			source: source,
			id: id,
			weekdaySat0: weekdaySat0 ?? this.weekdaySat0,
			title: title,
			emoji: emoji,
			timeLabel: timeLabel ?? this.timeLabel,
			targetLabel: targetLabel,
			detailLabel: detailLabel,
			isCompleted: isCompleted ?? this.isCompleted,
			routineRaw: routineRaw,
			scheduleId: scheduleId,
			dateIso: dateIso ?? this.dateIso,
			reminderMinutes: reminderMinutes,
			isLight: isLight ?? this.isLight,
			isOverride: isOverride ?? this.isOverride,
		);
	}
}

/// برنامهٔ کامل یک هفته: هفت لیست، شاخص ۰=شنبه تا ۶=جمعه.
class UnifiedWeekPlan {
	UnifiedWeekPlan({required this.byDay, this.activeCampaign});

	/// byDay[0] = شنبه ... byDay[6] = جمعه
	final List<List<WeekPlanItem>> byDay;

	/// کارزار فعال (مثل «دماوند در ۶ هفته») اگر وجود داشته باشد.
	final MovementCampaign? activeCampaign;

	factory UnifiedWeekPlan.empty() => UnifiedWeekPlan(
			byDay: List<List<WeekPlanItem>>.generate(7, (_) => <WeekPlanItem>[]),
		);

	int get totalItems => byDay.fold<int>(0, (sum, day) => sum + day.length);

	int get completedItems => byDay.fold<int>(
			0,
			(sum, day) => sum + day.where((item) => item.isCompleted).length,
		);

	int get restDayCount => byDay.where((day) => day.isEmpty).length;
}
