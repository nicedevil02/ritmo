// lib/features/supplementary_sports/movement/presentation/session/session_template.dart

import 'package:flutter/material.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/supplementary_sports/movement/domain/movement_kind.dart';
import 'package:ritmo/features/supplementary_sports/movement/domain/movement_session.dart';
import 'package:ritmo/features/supplementary_sports/movement/domain/session_mode.dart';
import 'package:ritmo/features/supplementary_sports/movement/presentation/session/movement_session_notifier.dart';


/// داده‌ها و ابزارهایی که پوستهٔ جلسه در اختیار هر قالب می‌گذارد.
///
/// قالب‌ها خودشان هیچ state ماندگاری ندارند؛ هرچه لازم دارند در `liveJson`
/// جلسه نگه داشته می‌شود، پس بسته شدن ناگهانی اپ داده را نمی‌سوزاند.
class SessionTemplateContext {
	const SessionTemplateContext({
		required this.notifier,
		required this.kind,
		required this.mode,
		required this.live,
		required this.isDetailMode,
		required this.updateLive,
		required this.logEvent,
	});

	final MovementSessionNotifier notifier;
	final MovementKind kind;
	final SessionMode mode;

	/// مقدارهای زندهٔ جلسه (liveJson دکدشده).
	final Map<String, dynamic> live;

	/// حالت حرفه‌ای در برابر ساده.
	final bool isDetailMode;

	/// نوشتن یک یا چند کلید در liveJson.
	final Future<void> Function(Map<String, dynamic> patch) updateLive;

	/// ثبت رویداد جلسه (دور، یادداشت، مرحله و مانند آن).
	final Future<void> Function(SessionEventType type, Map<String, dynamic>? data) logEvent;

	MovementSession get session => notifier.session;

	int get elapsedMs => notifier.elapsedMs;

	bool get isActive => session.status == MovementSessionStatus.active;

	double doubleValue(String key, {double fallback = 0}) =>
			(live[key] as num? ?? fallback).toDouble();

	int intValue(String key, {int fallback = 0}) => (live[key] as num? ?? fallback).toInt();

	String? stringValue(String key) => live[key] as String?;
}

/// یک کارت متریک ثانویه در حالت حرفه‌ای.
class SessionStat {
	const SessionStat({required this.label, required this.value});

	final String label;
	final String value;
}

/// هشدار یا راهنمای کوتاه بالای صفحهٔ جلسه.
class SessionBanner {
	const SessionBanner({
		required this.text,
		required this.icon,
		this.color = Colors.amber,
	});

	final String text;
	final IconData icon;
	final Color color;
}

/// قرارداد مشترک همهٔ قالب‌های جلسه.
///
/// پوسته (SessionShell) مسئول هدر، محافط خروج، نوار هدف، کنترل‌های
/// توقف/ادامه/پایان و دیالوگ پایان است؛ قالب فقط محتوای مختص همان ورزش را
/// می‌سازد. افزودن یک قالب تازه = یک کلاس جدید + یک خط در مسیریاب.
abstract class SessionTemplate {
	const SessionTemplate();

	/// کد قالب برای لاگ و تست.
	String get code;

	/// متریک اصلی وسط صفحه.
	Widget buildHero(BuildContext context, SessionTemplateContext ctx);

	/// محتوای اختیاری زیر متریک اصلی (چک‌لیست، فهرست دورها و مانند آن).
	Widget? buildBody(BuildContext context, SessionTemplateContext ctx) => null;

	/// کارت‌های متریک ثانویه؛ فقط در حالت حرفه‌ای دیده می‌شوند.
	List<SessionStat> buildSecondaryStats(BuildContext context, SessionTemplateContext ctx) =>
			const <SessionStat>[];

	/// دکمه‌های اختصاصی قالب، بالای کنترل‌های مشترک.
	List<Widget> buildActions(BuildContext context, SessionTemplateContext ctx) =>
			const <Widget>[];

	/// هشدار بالای صفحه — باید خالص باشد و عوارض جانبی نداشته باشد.
	SessionBanner? buildBanner(BuildContext context, SessionTemplateContext ctx) => null;
}

/// قالب‌بندی مدت زمان — ۱ بار نوشته می‌شود و همهٔ قالب‌ها از همین استفاده می‌کنند.
String formatSessionDuration(int ms) {
	final int totalSeconds = ms <= 0 ? 0 : (ms / 1000).floor();
	final int hours = totalSeconds ~/ 3600;
	final int minutes = (totalSeconds % 3600) ~/ 60;
	final int seconds = totalSeconds % 60;
	final String mm = minutes.toString().padLeft(2, '0');
	final String ss = seconds.toString().padLeft(2, '0');
	if (hours > 0) {
		return '${hours.toString().padLeft(2, '0')}:$mm:$ss';
	}
	return '$mm:$ss';
}

/// تمپوی هر کیلومتر بر حسب دقیقه:ثانیه.
String formatSessionPace(int ms, double meters) {
	if (meters <= 0 || ms <= 0) return '--:--';
	final double minutesPerKm = (ms / 60000.0) / (meters / 1000.0);
	final int minutes = minutesPerKm.floor();
	final int seconds = ((minutesPerKm - minutes) * 60).round();
	return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
}

/// دیالوگ مشترک ثبت دستی یک متریک؛ مقدار برگشتی null یعنی کاربر لغو کرد.
Future<double?> showSessionMetricDialog({
	required BuildContext context,
	required String title,
	required String unit,
	required double min,
	required double max,
	required double step,
	required double current,
}) {
	double value = current.clamp(min, max);
	final int divisions = ((max - min) / step).round().clamp(1, 1000);
	return showDialog<double>(
		context: context,
		builder: (dialogContext) => Directionality(
			textDirection: TextDirection.rtl,
			child: StatefulBuilder(
				builder: (builderContext, setDialogState) => AlertDialog(
					title: Text(
						title,
						style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
					),
					content: Column(
						mainAxisSize: MainAxisSize.min,
						children: [
							Text(
								'${toPersianDigits(value.round().toString())} $unit',
								style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
							),
							Slider(
								value: value,
								min: min,
								max: max,
								divisions: divisions,
								activeColor: const Color(0xFF10B981),
								label: toPersianDigits(value.round().toString()),
								onChanged: (next) => setDialogState(() => value = next),
							),
							Text(
								'هر پله ${toPersianDigits(step.round().toString())} $unit',
								style: const TextStyle(fontSize: 11, color: Colors.grey),
							),
						],
					),
					actions: [
						TextButton(
							onPressed: () => Navigator.of(dialogContext).pop(),
							child: const Text('لغو', style: TextStyle(color: Colors.grey)),
						),
						ElevatedButton(
							style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
							onPressed: () => Navigator.of(dialogContext).pop(value),
							child: const Text('ثبت', style: TextStyle(color: Colors.white)),
						),
					],
				),
			),
		),
	);
}
