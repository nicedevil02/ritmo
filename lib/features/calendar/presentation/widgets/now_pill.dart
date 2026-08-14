import 'dart:async';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/features/calendar/presentation/models/now_pill_view_model.dart';

class NowPill extends StatefulWidget {
  const NowPill({
    super.key,
    required this.viewModel,
    this.onTapPill,
    this.onTapComplete,
    this.onTapJumpNow,
  });

  final NowPillViewModel viewModel;
  final VoidCallback? onTapPill;
  final VoidCallback? onTapComplete;
  final VoidCallback? onTapJumpNow;

  @override
  State<NowPill> createState() => _NowPillState();
}

class _NowPillState extends State<NowPill>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  Timer? _ticker;
  late ValueNotifier<DateTime> _nowNotifier;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _nowNotifier = ValueNotifier<DateTime>(DateTime.now());

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _pulseAnimation = Tween<double>(begin: 0.35, end: 1.0).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );

    if (widget.viewModel.isCurrent) {
      _pulseController.repeat(reverse: true);
    }

    _startTicker();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        _nowNotifier.value = DateTime.now();
      }
    });
  }

  void _stopTicker() {
    _ticker?.cancel();
  }

  @override
  void didUpdateWidget(covariant NowPill oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.viewModel.isCurrent != oldWidget.viewModel.isCurrent) {
      if (widget.viewModel.isCurrent) {
        _pulseController.repeat(reverse: true);
      } else {
        _pulseController.stop();
        _pulseController.value = 1.0;
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _stopTicker();
      _pulseController.stop();
    } else if (state == AppLifecycleState.resumed) {
      _nowNotifier.value = DateTime.now();
      _startTicker();
      if (widget.viewModel.isCurrent) {
        _pulseController.repeat(reverse: true);
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopTicker();
    _pulseController.dispose();
    _nowNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.viewModel;

    final colors = context.colors;

    Color badgeColor = colors.primary;
    if (vm.isOverdue) {
      badgeColor = colors.error;
    } else if (!vm.isCurrent) {
      badgeColor = colors.warning;
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTapPill,
          borderRadius: BorderRadius.circular(RitmoRadius.pill),
          child: Container(
            height: 48.0,
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
            decoration: BoxDecoration(
              color: colors.surfaceElevated,
              borderRadius: BorderRadius.circular(RitmoRadius.pill),
              border: Border.all(
                color: badgeColor.withValues(alpha: 0.40),
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: colors.overlay.withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final showPrefix = width >= 300;
                final showJumpButton = width >= 240 && widget.onTapJumpNow != null;

                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Dot + Content Area
                    Expanded(
                      child: Row(
                        children: [
                          // Live pulsing dot indicator
                          RepaintBoundary(
                            child: AnimatedBuilder(
                              animation: _pulseAnimation,
                              builder: (context, child) {
                                final opacity = vm.isCurrent ? _pulseAnimation.value : 1.0;
                                return Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: badgeColor.withValues(alpha: opacity),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: RitmoSpacing.sm),

                          // Animated Switcher for smooth content transitions
                          Expanded(
                            child: AnimatedSwitcher(
                              duration: RitmoMotion.state,
                              child: Row(
                                key: ValueKey('${vm.statusLabel}_${vm.targetItem?.id}'),
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (showPrefix && vm.statusLabel.isNotEmpty) ...[
                                    Text(
                                      vm.isCurrent
                                          ? 'الان: '
                                          : (vm.statusLabel == 'NEXT' ? 'بعدی: ' : ''),
                                      style: TextStyle(
                                        fontSize: 14.0,
                                        fontWeight: FontWeight.w600,
                                        color: badgeColor,
                                      ),
                                    ),
                                  ],
                                  if (vm.targetItem != null) ...[
                                    Flexible(
                                      child: Text(
                                        vm.targetItem!.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 14.0,
                                          fontWeight: FontWeight.w700,
                                          color: colors.textPrimary,
                                        ),
                                      ),
                                    ),
                                  ],

                                  // Scoped Live Relative Time Update
                                  RepaintBoundary(
                                    child: ValueListenableBuilder<DateTime>(
                                      valueListenable: _nowNotifier,
                                      builder: (context, nowVal, _) {
                                        final label = vm.timeLabel;
                                        final prefix = (vm.targetItem != null && label.isNotEmpty) ? ' · ' : '';
                                        return Text(
                                          '$prefix$label',
                                          style: TextStyle(
                                            fontSize: 12.0,
                                            fontWeight: FontWeight.w400,
                                            color: vm.isOverdue
                                                ? badgeColor
                                                : colors.textSecondary,
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Actions Area (Jump + Complete Buttons)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (showJumpButton) ...[
                          IconButton(
                            icon: Icon(Icons.my_location_rounded, size: 18, color: badgeColor),
                            onPressed: () {
                              RitmoHapticsPolicy.tap();
                              widget.onTapJumpNow?.call();
                            },
                            tooltip: 'پرش به زمان فعلی',
                            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                            padding: const EdgeInsets.all(4),
                          ),
                        ],

                        if (widget.onTapComplete != null && vm.targetItem != null && !vm.targetItem!.isCompleted) ...[
                          if (showJumpButton)
                            Container(
                              width: 1,
                              height: 16,
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                              color: colors.borderSubtle,
                            ),

                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: colors.primary.withValues(alpha: 0.12),
                            ),
                            child: IconButton(
                              icon: Icon(
                                Icons.check_circle_outline_rounded,
                                size: 20,
                                color: colors.primary,
                              ),
                              onPressed: () {
                                RitmoHapticsPolicy.success();
                                widget.onTapComplete?.call();
                              },
                              tooltip: 'تکمیل رویداد',
                              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                              padding: const EdgeInsets.all(4),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
