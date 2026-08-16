import 'dart:async';
import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/movement/domain/models/movement_live_session.dart';
import 'package:ritmo/features/movement/presentation/common/movement_strings.dart';

/// بنر زندهٔ جلسهٔ در حال انجام یا مکث‌شده
class LiveSessionBanner extends StatefulWidget {
  const LiveSessionBanner({
    super.key,
    required this.session,
    required this.onResume,
    required this.onFinishAndSave,
    required this.onDiscard,
  });

  final MovementLiveSession session;
  final VoidCallback onResume;
  final VoidCallback onFinishAndSave;
  final VoidCallback onDiscard;

  @override
  State<LiveSessionBanner> createState() => _LiveSessionBannerState();
}

class _LiveSessionBannerState extends State<LiveSessionBanner> {
  Timer? _timer;
  late int _elapsedSeconds;

  @override
  void initState() {
    super.initState();
    _elapsedSeconds = widget.session.elapsedSeconds;
    if (widget.session.status == MovementLiveSessionStatus.active) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) {
          setState(() {
            _elapsedSeconds = widget.session.elapsedSeconds;
          });
        }
      });
    }
  }

  @override
  void didUpdateWidget(covariant LiveSessionBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.session.status != oldWidget.session.status) {
      _timer?.cancel();
      if (widget.session.status == MovementLiveSessionStatus.active) {
        _timer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (mounted) {
            setState(() {
              _elapsedSeconds = widget.session.elapsedSeconds;
            });
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatDuration(int totalSecs) {
    final m = (totalSecs / 60).floor();
    final s = totalSecs % 60;
    final mStr = m.toString().padLeft(2, '0');
    final sStr = s.toString().padLeft(2, '0');
    return toPersianDigits('$mStr:$sStr');
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final sportsColor = context.modules.sports;

    final activityName = widget.session.activityKind?.nameFa ?? 'جلسهٔ زنده';
    final timeStr = _formatDuration(_elapsedSeconds);
    final isPaused = widget.session.status == MovementLiveSessionStatus.paused;

    return Semantics(
      container: true,
      label: 'جلسهٔ زنده $activityName، مدت سپری‌شده: $timeStr',
      child: Container(
        margin: const EdgeInsets.symmetric(
          horizontal: RitmoSpacing.lg,
          vertical: RitmoSpacing.xs,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: RitmoSpacing.md,
          vertical: RitmoSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: sportsColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(RitmoRadius.card),
          border: Border.all(
            color: sportsColor.withValues(alpha: 0.45),
            width: RitmoElevation.borderWidthDark,
          ),
        ),
        child: Row(
          children: [
            // آیکون ضربان‌دار یا مکث
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: sportsColor.withValues(alpha: 0.20),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isPaused ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: sportsColor,
                size: 20,
              ),
            ),
            const SizedBox(width: RitmoSpacing.sm),

            // عنوان و زمان سپری‌شده
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    activityName,
                    style: RitmoTextStyles.label(colors.textPrimary).copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    isPaused ? 'مکث شده · $timeStr' : 'در حال ضبط · $timeStr',
                    style: RitmoTextStyles.caption(colors.textSecondary),
                  ),
                ],
              ),
            ),

            const SizedBox(width: RitmoSpacing.sm),

            // دکمهٔ ادامه جلسه
            SizedBox(
              height: 36,
              child: FilledButton(
                onPressed: () {
                  RitmoHapticsPolicy.selection();
                  widget.onResume();
                },
                style: FilledButton.styleFrom(
                  backgroundColor: sportsColor,
                  foregroundColor: colors.onPrimary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: RitmoSpacing.md,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(RitmoRadius.pill),
                  ),
                ),
                child: Text(
                  MovementStrings.bannerResumeSession,
                  style: RitmoTextStyles.caption(colors.onPrimary).copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),

            // منوی بیشتر
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert_rounded, color: colors.textSecondary),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(RitmoRadius.card),
              ),
              color: colors.surfaceElevated,
              onSelected: (value) {
                if (value == 'finish') {
                  widget.onFinishAndSave();
                } else if (value == 'discard') {
                  widget.onDiscard();
                }
              },
              itemBuilder: (ctx) => [
                PopupMenuItem(
                  value: 'finish',
                  child: Row(
                    children: [
                      Icon(Icons.check_rounded, color: colors.primary, size: 18),
                      const SizedBox(width: RitmoSpacing.sm),
                      Text(
                        MovementStrings.bannerFinishAndSave,
                        style: RitmoTextStyles.label(colors.textPrimary),
                      ),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'discard',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline_rounded, color: colors.error, size: 18),
                      const SizedBox(width: RitmoSpacing.sm),
                      Text(
                        MovementStrings.bannerDiscardSession,
                        style: RitmoTextStyles.label(colors.error),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
