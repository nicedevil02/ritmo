// lib/features/supplementary_sports/movement/presentation/session/session_shell.dart

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/ux/ritmo_haptics.dart';
import 'package:ritmo/features/calendar/presentation/utils/calendar_tokens.dart';
import 'package:ritmo/features/supplementary_sports/domain/sports_detail_mode.dart';
import 'package:ritmo/features/supplementary_sports/movement/data/movement_session_repository.dart';
import 'package:ritmo/features/supplementary_sports/movement/domain/movement_kind.dart';
import 'package:ritmo/features/supplementary_sports/movement/domain/movement_session.dart';
import 'package:ritmo/features/supplementary_sports/movement/domain/session_mode.dart';
import 'package:ritmo/features/supplementary_sports/movement/presentation/session/movement_session_notifier.dart';
import 'package:ritmo/features/supplementary_sports/movement/presentation/session/session_template.dart';

const String _fontFa = 'Vazirmatn';

/// اسکلت مشترک همهٔ جلسات فعالیت — قدرتی، پیاده‌روی، کوه، شنا، بازی.
///
/// هر چیز مشترک یک جا زندگی می‌کند: محافط خروج، هدر ورزش، نوار هدف، ناحیهٔ
/// اسکرول‌شوندهٔ متریک‌ها، کنترل توقف/ادامه/پایان و دیالوگ ثبت پایان.
/// تفاوت ورزش‌ها فقط در قالب (SessionTemplate) است.
class SessionShell extends StatefulWidget {
	const SessionShell({
		super.key,
		required this.notifier,
		required this.kind,
		required this.mode,
		required this.template,
	});

	final MovementSessionNotifier notifier;
	final MovementKind kind;
	final SessionMode mode;
	final SessionTemplate template;

	@override
	State<SessionShell> createState() => _SessionShellState();
}

class _SessionShellState extends State<SessionShell> {
	bool _isBusy = false;

	Map<String, dynamic> _readLive() {
		final String? raw = widget.notifier.session.liveJson;
		if (raw == null || raw.isEmpty) return <String, dynamic>{};
		try {
			final dynamic decoded = jsonDecode(raw);
			if (decoded is Map) return Map<String, dynamic>.from(decoded);
		} catch (e) {
			debugPrint('[ss] session_shell.dart: $e');
		}
		return <String, dynamic>{};
	}

	Future<void> _updateLive(Map<String, dynamic> patch) async {
		try {
			final Map<String, dynamic> live = _readLive();
			live.addAll(patch);
			final db = await DatabaseHelper.instance.database;
			await db.update(
				'movement_sessions',
				{
					'liveJson': jsonEncode(live),
					'updatedAt': DateTime.now().millisecondsSinceEpoch,
				},
				where: 'id = ?',
				whereArgs: [widget.notifier.session.id],
			);
			final updated = await MovementSessionRepository.instance.getActiveSession();
			if (updated != null && updated.id == widget.notifier.session.id) {
				widget.notifier.session = updated;
			}
			if (mounted) setState(() {});
			widget.notifier.notifyListeners();
		} catch (e) {
			debugPrint('[ss] session_shell.dart: $e');
			_showMessage('ثبت مقدار انجام نشد. دوباره تلاش کن.');
		}
	}

	Future<void> _logEvent(SessionEventType type, Map<String, dynamic>? data) async {
		try {
			await MovementSessionRepository.instance.logSessionEvent(
				widget.notifier.session.id,
				type,
				data,
			);
		} catch (e) {
			debugPrint('[ss] session_shell.dart: $e');
			_showMessage('ثبت رویداد انجام نشد.');
		}
	}

	void _showMessage(String text) {
		if (!mounted) return;
		ScaffoldMessenger.of(context).showSnackBar(
			SnackBar(content: Text(text, style: const TextStyle(fontFamily: _fontFa))),
		);
	}

	/// پیشرفت هدف — برای همهٔ قالب‌ها یکجا محاسبه می‌شود.
	double _targetProgress(Map<String, dynamic> live) {
		final String? raw = widget.notifier.session.targetJson;
		if (raw == null || raw.isEmpty) return 0.0;
		try {
			final dynamic decoded = jsonDecode(raw);
			if (decoded is! Map) return 0.0;
			final Map<String, dynamic> target = Map<String, dynamic>.from(decoded);

			final num? minutes = target['minutes'] as num?;
			if (minutes != null && minutes > 0) {
				return (widget.notifier.elapsedMs / (minutes.toDouble() * 60000.0)).clamp(0.0, 1.0);
			}
			final num? distance = target['distanceMeters'] as num?;
			if (distance != null && distance > 0) {
				final double current = (live['manualDistanceMeters'] as num? ?? 0).toDouble();
				return (current / distance.toDouble()).clamp(0.0, 1.0);
			}
			final num? elevation = target['elevationMeters'] as num?;
			if (elevation != null && elevation > 0) {
				final double current = (live['manualElevationMeters'] as num? ?? 0).toDouble();
				return (current / elevation.toDouble()).clamp(0.0, 1.0);
			}
			final num? laps = target['laps'] as num?;
			if (laps != null && laps > 0) {
				final double current = (live['laps'] as num? ?? 0).toDouble();
				return (current / laps.toDouble()).clamp(0.0, 1.0);
			}
		} catch (e) {
			debugPrint('[ss] session_shell.dart: $e');
		}
		return 0.0;
	}

	/// خروج با دکمهٔ بازگشت دیگر جلسه را بی‌سروصدا رها نمی‌کند.
	Future<void> _handleExitRequest() async {
		if (_isBusy) return;
		if (!widget.notifier.session.isLive) {
			if (mounted) Navigator.of(context).pop();
			return;
		}
		RitmoHaptics.tap();
		final String? choice = await showDialog<String>(
			context: context,
			builder: (dialogContext) => Directionality(
				textDirection: TextDirection.rtl,
				child: AlertDialog(
					title: const Text(
						'جلسه هنوز در جریان است',
						style: TextStyle(fontFamily: _fontFa, fontWeight: FontWeight.bold, fontSize: 15),
					),
					content: const Text(
						'تا وقتی جلسه متوقف یا ثبت نشود، زمان شمرده می‌شود. چه کار کنیم؟',
						style: TextStyle(fontFamily: _fontFa, fontSize: 13),
					),
					actions: [
						TextButton(
							onPressed: () => Navigator.of(dialogContext).pop('continue'),
							child: const Text('ادامهٔ تمرین', style: TextStyle(fontFamily: _fontFa)),
						),
						TextButton(
							onPressed: () => Navigator.of(dialogContext).pop('pause'),
							child: const Text(
								'توقف موقت و خروج',
								style: TextStyle(fontFamily: _fontFa, color: Colors.amber),
							),
						),
						ElevatedButton(
							style: ElevatedButton.styleFrom(backgroundColor: CalendarTokens.emerald),
							onPressed: () => Navigator.of(dialogContext).pop('finish'),
							child: const Text(
								'پایان و ثبت',
								style: TextStyle(fontFamily: _fontFa, color: Colors.white),
							),
						),
					],
				),
			),
		);

		if (choice == 'pause') {
			await widget.notifier.pause();
			if (mounted) Navigator.of(context).pop();
			return;
		}
		if (choice == 'finish') {
			await _openFinishFlow();
		}
	}

	Future<void> _openFinishFlow() async {
		if (_isBusy) return;
		final _FinishResult? result = await showDialog<_FinishResult>(
			context: context,
			barrierDismissible: false,
			builder: (dialogContext) => const Directionality(
				textDirection: TextDirection.rtl,
				child: _FinishDialog(),
			),
		);
		if (result == null) return;

		setState(() => _isBusy = true);
		try {
			RitmoHaptics.success();
			await widget.notifier.finish(
				feeling: result.feeling,
				note: result.note.isEmpty ? null : result.note,
			);
			if (mounted) Navigator.of(context).pop();
		} catch (e) {
			debugPrint('[ss] session_shell.dart: $e');
			if (mounted) setState(() => _isBusy = false);
			_showMessage('ثبت جلسه انجام نشد. دوباره تلاش کن؛ دادهٔ جلسه از دست نرفته است.');
		}
	}

	@override
	Widget build(BuildContext context) {
		return PopScope(
			canPop: false,
			onPopInvokedWithResult: (didPop, result) {
				if (didPop) return;
				_handleExitRequest();
			},
			child: ValueListenableBuilder<bool>(
				valueListenable: SportsDetailMode.notifier,
				builder: (context, isDetail, _) {
					final Map<String, dynamic> live = _readLive();
					final SessionTemplateContext ctx = SessionTemplateContext(
						notifier: widget.notifier,
						kind: widget.kind,
						mode: widget.mode,
						live: live,
						isDetailMode: isDetail,
						updateLive: _updateLive,
						logEvent: _logEvent,
					);
					return SafeArea(
						child: Directionality(
							textDirection: TextDirection.rtl,
							child: _buildLayout(context, ctx, live, isDetail),
						),
					);
				},
			),
		);
	}

	Widget _buildLayout(
		BuildContext context,
		SessionTemplateContext ctx,
		Map<String, dynamic> live,
		bool isDetail,
	) {
		final SessionBanner? banner = widget.template.buildBanner(context, ctx);
		final Widget? body = widget.template.buildBody(context, ctx);
		final List<SessionStat> stats = widget.template.buildSecondaryStats(context, ctx);
		final List<Widget> actions = widget.template.buildActions(context, ctx);
		final bool hasTarget = (widget.notifier.session.targetJson ?? '').isNotEmpty;

		return Column(
			crossAxisAlignment: CrossAxisAlignment.stretch,
			children: [
				_buildHeader(context, isDetail),
				if (banner != null) _buildBanner(banner),
				if (hasTarget) _buildTargetProgress(context, live),
				// ناحیهٔ میانی اسکرول می‌شود تا در فونت درشت یا صفحهٔ کوتاه سرریز نداشته باشیم.
				Expanded(
					child: SingleChildScrollView(
						padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
						child: Column(
							crossAxisAlignment: CrossAxisAlignment.stretch,
							children: [
								Center(child: widget.template.buildHero(context, ctx)),
								if (body != null) ...[
									const SizedBox(height: 20),
									body,
								],
								if (isDetail && stats.isNotEmpty) ...[
									const SizedBox(height: 20),
									_buildStats(stats),
								],
							],
						),
					),
				),
				if (actions.isNotEmpty)
					Padding(
						padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
						child: Column(
							crossAxisAlignment: CrossAxisAlignment.stretch,
							children: actions,
						),
					),
				_buildControls(),
			],
		);
	}

	Widget _buildHeader(BuildContext context, bool isDetail) {
		return Padding(
			padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
			child: Row(
				children: [
					IconButton(
						tooltip: 'بستن صفحهٔ جلسه',
						icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white70),
						onPressed: _isBusy ? null : _handleExitRequest,
					),
					Text(widget.kind.emoji, style: const TextStyle(fontSize: 22)),
					const SizedBox(width: 8),
					Expanded(
						child: Column(
							crossAxisAlignment: CrossAxisAlignment.start,
							children: [
								Text(
									widget.kind.titleFa,
									maxLines: 1,
									overflow: TextOverflow.ellipsis,
									style: const TextStyle(
										fontFamily: _fontFa,
										color: Colors.white,
										fontSize: 17,
										fontWeight: FontWeight.bold,
									),
								),
								Text(
									'${widget.kind.family.emoji} ${widget.kind.family.titleFa}',
									maxLines: 1,
									overflow: TextOverflow.ellipsis,
									style: const TextStyle(fontFamily: _fontFa, color: Colors.white54, fontSize: 11),
								),
							],
						),
					),
					Semantics(
						button: true,
						label: isDetail ? 'تغییر به نمای ساده' : 'تغییر به نمای حرفه‌ای',
						child: Tooltip(
							message: isDetail
									? 'نمای ساده: فقط متریک اصلی'
									: 'نمای حرفه‌ای: متریک‌های بیشتر',
							child: InkWell(
								borderRadius: BorderRadius.circular(20),
								onTap: () {
									RitmoHaptics.tap();
									SportsDetailMode.setEnabled(!isDetail);
								},
								child: Container(
									padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
									decoration: BoxDecoration(
										color: Colors.white10,
										borderRadius: BorderRadius.circular(20),
									),
									child: Text(
										isDetail ? 'حالت حرفه‌ای' : 'حالت ساده',
										style: const TextStyle(
											fontFamily: _fontFa,
											color: Colors.amber,
											fontSize: 11,
											fontWeight: FontWeight.bold,
										),
									),
								),
							),
						),
					),
				],
			),
		);
	}

	Widget _buildBanner(SessionBanner banner) {
		return Container(
			margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
			padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
			decoration: BoxDecoration(
				color: banner.color.withValues(alpha: 0.15),
				borderRadius: BorderRadius.circular(14),
				border: Border.all(color: banner.color.withValues(alpha: 0.5)),
			),
			child: Row(
				children: [
					Icon(banner.icon, color: banner.color, size: 18),
					const SizedBox(width: 8),
					Expanded(
						child: Text(
							banner.text,
							maxLines: 3,
							overflow: TextOverflow.ellipsis,
							style: const TextStyle(fontFamily: _fontFa, color: Colors.white, fontSize: 12),
						),
					),
				],
			),
		);
	}

	Widget _buildTargetProgress(BuildContext context, Map<String, dynamic> live) {
		final double percent = _targetProgress(live);
		final colors = context.colors;
		return Padding(
			padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
			child: Column(
				crossAxisAlignment: CrossAxisAlignment.stretch,
				children: [
					Row(
						mainAxisAlignment: MainAxisAlignment.spaceBetween,
						children: [
							Text(
								'پیشرفت هدف',
								style: TextStyle(fontFamily: _fontFa, color: colors.textSecondary, fontSize: 11),
							),
							Text(
								'${toPersianDigits((percent * 100).round().toString())}٪',
								style: const TextStyle(
									fontFamily: _fontFa,
									color: Colors.white,
									fontSize: 11,
									fontWeight: FontWeight.bold,
								),
							),
						],
					),
					const SizedBox(height: 6),
					ClipRRect(
						borderRadius: BorderRadius.circular(10),
						child: LinearProgressIndicator(
							value: percent,
							backgroundColor: Colors.white24,
							valueColor: const AlwaysStoppedAnimation<Color>(CalendarTokens.emerald),
							minHeight: 6,
						),
					),
				],
			),
		);
	}

	/// کارت‌های متریک در Wrap می‌نشینند، پس در فونت درشت هم سرریز نمی‌کنند.
	Widget _buildStats(List<SessionStat> stats) {
		return Wrap(
			spacing: 10,
			runSpacing: 10,
			alignment: WrapAlignment.center,
			children: stats
					.map(
						(stat) => Container(
							padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
							decoration: BoxDecoration(
								color: Colors.white10,
								borderRadius: BorderRadius.circular(14),
							),
							child: Column(
								crossAxisAlignment: CrossAxisAlignment.center,
								children: [
									Text(
										stat.label,
										style: const TextStyle(fontFamily: _fontFa, color: Colors.white54, fontSize: 11),
									),
									const SizedBox(height: 4),
									Text(
										stat.value,
										style: const TextStyle(
											fontFamily: _fontFa,
											color: Colors.white,
											fontSize: 13,
											fontWeight: FontWeight.bold,
										),
									),
								],
							),
						),
					)
					.toList(),
		);
	}

	Widget _buildControls() {
		final bool isActive = widget.notifier.session.status == MovementSessionStatus.active;
		return Padding(
			padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
			child: Row(
				mainAxisAlignment: MainAxisAlignment.spaceEvenly,
				children: [
					if (isActive)
						FloatingActionButton.large(
							heroTag: 'shellPause',
							tooltip: 'توقف موقت',
							backgroundColor: Colors.amber,
							onPressed: _isBusy
									? null
									: () {
											RitmoHaptics.tap();
											widget.notifier.pause();
										},
							child: const Icon(Icons.pause, size: 36, color: Colors.black),
						)
					else
						FloatingActionButton.large(
							heroTag: 'shellResume',
							tooltip: 'ادامهٔ جلسه',
							backgroundColor: CalendarTokens.emerald,
							onPressed: _isBusy
									? null
									: () {
											RitmoHaptics.tap();
											widget.notifier.resume();
										},
							child: const Icon(Icons.play_arrow, size: 40, color: Colors.white),
						),
					FloatingActionButton.large(
						heroTag: 'shellFinish',
						tooltip: 'پایان و ثبت جلسه',
						backgroundColor: Colors.red,
						onPressed: _isBusy ? null : _openFinishFlow,
						child: _isBusy
								? const SizedBox(
										height: 28,
										width: 28,
										child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
									)
								: const Icon(Icons.stop, size: 40, color: Colors.white),
					),
				],
			),
		);
	}
}

class _FinishResult {
	const _FinishResult({required this.feeling, required this.note});

	final String feeling;
	final String note;
}

/// دیالوگ پایان جلسه — حالت حس و یادداشت را می‌گیرد و فقط نتیجه را برمی‌گرداند.
/// ثبت واقعی و بستن صفحه کار پوسته است، پس دیگر صفحه پیش از ذخیره بسته نمی‌شود.
class _FinishDialog extends StatefulWidget {
	const _FinishDialog();

	@override
	State<_FinishDialog> createState() => _FinishDialogState();
}

class _FinishDialogState extends State<_FinishDialog> {
	final TextEditingController _noteController = TextEditingController();
	String _feeling = 'GOOD';

	static const List<List<String>> _feelings = <List<String>>[
		<String>['EXCELLENT', '🤩', 'حال عالی'],
		<String>['GOOD', '🙂', 'حال خوب'],
		<String>['NORMAL', '😐', 'حال معمولی'],
		<String>['EXHAUSTED', '😫', 'خسته'],
	];

	@override
	void dispose() {
		_noteController.dispose();
		super.dispose();
	}

	@override
	Widget build(BuildContext context) {
		return AlertDialog(
			title: const Text(
				'ثبت و پایان جلسه',
				style: TextStyle(fontFamily: _fontFa, fontWeight: FontWeight.bold, fontSize: 15),
			),
			content: Column(
				mainAxisSize: MainAxisSize.min,
				crossAxisAlignment: CrossAxisAlignment.stretch,
				children: [
					const Text(
						'خسته نباشی! بعد از این جلسه چه حالی داری؟',
						style: TextStyle(fontFamily: _fontFa, fontSize: 13),
					),
					const SizedBox(height: 12),
					Wrap(
						alignment: WrapAlignment.spaceAround,
						children: _feelings.map((entry) {
							final bool isSelected = _feeling == entry[0];
							return Semantics(
								button: true,
								selected: isSelected,
								label: entry[2],
								child: IconButton(
									tooltip: entry[2],
									onPressed: () => setState(() => _feeling = entry[0]),
									icon: Text(
										entry[1],
										style: TextStyle(fontSize: isSelected ? 34 : 24),
									),
								),
							);
						}).toList(),
					),
					const SizedBox(height: 8),
					TextField(
						controller: _noteController,
						maxLength: 140,
						textInputAction: TextInputAction.done,
						inputFormatters: [LengthLimitingTextInputFormatter(140)],
						style: const TextStyle(fontFamily: _fontFa, fontSize: 13),
						decoration: const InputDecoration(
							labelText: 'یادداشت جلسه (اختیاری)',
							labelStyle: TextStyle(fontFamily: _fontFa, fontSize: 13),
							border: OutlineInputBorder(),
							counterText: '',
						),
					),
				],
			),
			actions: [
				TextButton(
					onPressed: () => Navigator.of(context).pop(),
					child: const Text('بازگشت', style: TextStyle(fontFamily: _fontFa, color: Colors.grey)),
				),
				ElevatedButton(
					style: ElevatedButton.styleFrom(backgroundColor: CalendarTokens.emerald),
					onPressed: () => Navigator.of(context).pop(
						_FinishResult(feeling: _feeling, note: _noteController.text.trim()),
					),
					child: const Text(
						'ذخیره',
						style: TextStyle(fontFamily: _fontFa, color: Colors.white, fontWeight: FontWeight.bold),
					),
				),
			],
		);
	}
}
