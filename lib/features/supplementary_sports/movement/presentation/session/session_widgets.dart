// lib/features/supplementary_sports/movement/presentation/session/session_widgets.dart

import 'package:flutter/material.dart';

const String _fontFa = 'Vazirmatn';

/// کارت مشترک بخش‌های درون جلسه — تا همهٔ قالب‌ها یک زبان بصری داشته باشند.
class SessionCard extends StatelessWidget {
	const SessionCard({
		super.key,
		required this.icon,
		required this.title,
		this.subtitle,
		this.trailing,
		this.child,
	});

	final IconData icon;
	final String title;
	final String? subtitle;
	final Widget? trailing;
	final Widget? child;

	@override
	Widget build(BuildContext context) {
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
							Icon(icon, color: Colors.white70, size: 18),
							const SizedBox(width: 10),
							Expanded(
								child: Column(
									crossAxisAlignment: CrossAxisAlignment.start,
									children: [
										Text(
											title,
											maxLines: 1,
											overflow: TextOverflow.ellipsis,
											style: const TextStyle(
												color: Colors.white,
												fontSize: 13,
												fontWeight: FontWeight.bold,
											),
										),
										if (subtitle != null) ...[
											const SizedBox(height: 2),
											Text(
												subtitle!,
												maxLines: 2,
												overflow: TextOverflow.ellipsis,
												style: const TextStyle(
													color: Colors.white60,
													fontSize: 11,
												),
											),
										],
									],
								),
							),
							if (trailing != null) ...[
								const SizedBox(width: 8),
								trailing!,
							],
						],
					),
					if (child != null) ...[
						const SizedBox(height: 12),
						child!,
					],
				],
			),
		);
	}
}

/// تراشهٔ عملیاتی کوچک (ثبت مقدار، تنظیم، افزودن سریع).
class SessionChip extends StatelessWidget {
	const SessionChip({
		super.key,
		required this.label,
		required this.icon,
		required this.onTap,
	});

	final String label;
	final IconData icon;
	final Future<void> Function()? onTap;

	@override
	Widget build(BuildContext context) {
		final bool isEnabled = onTap != null;
		return Semantics(
			button: true,
			enabled: isEnabled,
			label: label,
			child: Tooltip(
				message: label,
				child: InkWell(
					borderRadius: BorderRadius.circular(20),
					onTap: onTap,
					child: Container(
						padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
						decoration: BoxDecoration(
							color: isEnabled ? Colors.white12 : Colors.white10,
							borderRadius: BorderRadius.circular(20),
							border: Border.all(color: Colors.white24),
						),
						child: Row(
							mainAxisSize: MainAxisSize.min,
							children: [
								Icon(icon, size: 14, color: isEnabled ? Colors.white70 : Colors.white38),
								const SizedBox(width: 6),
								Text(
									label,
									style: TextStyle(
										color: isEnabled ? Colors.white : Colors.white38,
										fontSize: 11,
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

/// تراشهٔ دوحالته (چک‌لیست، انتخاب مرحله).
class SessionToggleChip extends StatelessWidget {
	const SessionToggleChip({
		super.key,
		required this.label,
		required this.isOn,
		required this.onTap,
		this.activeColor = Colors.teal,
	});

	final String label;
	final bool isOn;
	final Future<void> Function() onTap;
	final Color activeColor;

	@override
	Widget build(BuildContext context) {
		return Semantics(
			button: true,
			checked: isOn,
			label: label,
			child: Tooltip(
				message: isOn ? '$label — فعال است' : '$label — انتخاب کن',
				child: InkWell(
					borderRadius: BorderRadius.circular(20),
					onTap: onTap,
					child: Container(
						padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
						decoration: BoxDecoration(
							color: isOn ? activeColor : Colors.white12,
							borderRadius: BorderRadius.circular(20),
							border: Border.all(color: isOn ? activeColor : Colors.white24),
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

/// دکمهٔ اصلی درون قالب — هدف لمس بزرگ برای دست خیس یا دستکش کوه.
class SessionActionButton extends StatelessWidget {
	const SessionActionButton({
		super.key,
		required this.label,
		required this.icon,
		required this.color,
		required this.onTap,
		this.verticalPadding = 12,
	});

	final String label;
	final IconData icon;
	final Color color;
	final Future<void> Function()? onTap;
	final double verticalPadding;

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
							color: Colors.white,
							fontSize: 12,
							fontWeight: FontWeight.bold,
						),
					),
					style: ElevatedButton.styleFrom(
						backgroundColor: color,
						disabledBackgroundColor: Colors.white12,
						padding: EdgeInsets.symmetric(vertical: verticalPadding),
						shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
					),
				),
			),
		);
	}
}

/// دکمهٔ کم/زیاد کردن یک عدد (امتیاز بازی، تعداد دور).
class SessionStepperButton extends StatelessWidget {
	const SessionStepperButton({
		super.key,
		required this.icon,
		required this.semanticLabel,
		required this.onTap,
		this.color = Colors.white12,
	});

	final IconData icon;
	final String semanticLabel;
	final Future<void> Function()? onTap;
	final Color color;

	@override
	Widget build(BuildContext context) {
		return Semantics(
			button: true,
			enabled: onTap != null,
			label: semanticLabel,
			child: Tooltip(
				message: semanticLabel,
				child: InkWell(
					borderRadius: BorderRadius.circular(14),
					onTap: onTap,
					child: Container(
						height: 44,
						width: 44,
						decoration: BoxDecoration(
							color: onTap == null ? Colors.white10 : color,
							borderRadius: BorderRadius.circular(14),
							border: Border.all(color: Colors.white24),
						),
						child: Icon(icon, size: 20, color: onTap == null ? Colors.white38 : Colors.white),
					),
				),
			),
		);
	}
}
