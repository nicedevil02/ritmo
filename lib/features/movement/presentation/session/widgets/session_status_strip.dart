import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/movement/domain/models/movement_live_session.dart';
import 'package:ritmo/features/movement/presentation/session/widgets/pending_save_badge.dart';

/// نوار وضعیت جلسه و نمایش صف ذخیره‌سازی
class SessionStatusStrip extends StatelessWidget {
  const SessionStatusStrip({
    super.key,
    required this.status,
    required this.pendingSavesCount,
    required this.onRetryPendingSaves,
  });

  final MovementLiveSessionStatus status;
  final int pendingSavesCount;
  final VoidCallback onRetryPendingSaves;

  String _statusLabel(MovementLiveSessionStatus s) {
    switch (s) {
      case MovementLiveSessionStatus.preparing:
        return 'آماده‌سازی';
      case MovementLiveSessionStatus.active:
        return 'در حال اجرا';
      case MovementLiveSessionStatus.paused:
        return 'متوقف‌شده';
      case MovementLiveSessionStatus.recovering:
        return 'استراحت';
      case MovementLiveSessionStatus.finishing:
        return 'در حال ثبت نهایی...';
      case MovementLiveSessionStatus.completed:
        return 'پایان‌یافته';
      case MovementLiveSessionStatus.abandoned:
        return 'رهاشده';
      case MovementLiveSessionStatus.errorRecoverable:
        return 'خطای موقت در ذخیره‌سازی';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final sportsColor = context.modules.sports;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: RitmoSpacing.lg,
        vertical: RitmoSpacing.xs,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: status == MovementLiveSessionStatus.active
                      ? sportsColor
                      : status == MovementLiveSessionStatus.paused
                      ? colors.warning
                      : colors.textTertiary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: RitmoSpacing.xs),
              Text(
                _statusLabel(status),
                style: RitmoTextStyles.caption(colors.textSecondary),
              ),
            ],
          ),
          PendingSaveBadge(
            pendingCount: pendingSavesCount,
            onRetry: onRetryPendingSaves,
          ),
        ],
      ),
    );
  }
}
