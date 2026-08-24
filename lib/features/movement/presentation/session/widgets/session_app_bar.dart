import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/movement/domain/models/movement_activity_kind.dart';
import 'package:ritmo/features/movement/presentation/session/widgets/timer_display.dart';

/// سربرگ متمرکز و ایزولهٔ جلسهٔ زنده
class SessionAppBar extends StatelessWidget implements PreferredSizeWidget {
  const SessionAppBar({
    super.key,
    required this.activityKind,
    required this.elapsedSeconds,
    required this.isPaused,
    required this.onPauseToggle,
    required this.onMorePressed,
    required this.onBackPressed,
  });

  final MovementActivityKind activityKind;
  final int elapsedSeconds;
  final bool isPaused;
  final VoidCallback onPauseToggle;
  final VoidCallback onMorePressed;
  final VoidCallback onBackPressed;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 8);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final sportsColor = context.modules.sports;

    return AppBar(
      backgroundColor: colors.surface,
      elevation: 0,
      centerTitle: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_forward_rounded),
        tooltip: 'بازگشت',
        onPressed: onBackPressed,
      ),
      title: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            activityKind.nameFa,
            style: RitmoTextStyles.cardTitle(colors.textPrimary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          TimerDisplay(
            elapsedSeconds: elapsedSeconds,
            isLarge: false,
            isPaused: isPaused,
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: Icon(
            isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
            color: sportsColor,
          ),
          tooltip: isPaused ? 'ادامه' : 'مکث',
          onPressed: onPauseToggle,
        ),
        IconButton(
          icon: const Icon(Icons.more_vert_rounded),
          tooltip: 'گزینه‌های بیشتر',
          onPressed: onMorePressed,
        ),
      ],
    );
  }
}
