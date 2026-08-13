import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ritmo/core/analytics/sleep_program_engine.dart';
import 'package:ritmo/core/analytics/wellbeing_insight_arbiter.dart';
import 'package:ritmo/core/logging/ritmo_logger.dart';
import 'package:ritmo/features/sleep/data/sleep_program_repository.dart';
import 'package:ritmo/features/sleep/logic/sleep_plan_insights.dart';

/// میانبر یک‌خطی مسیر خواب برای صفحهٔ خانه.
///
/// محل اصلی برنامه داخل «حال و تعادل ← خواب» است؛ این فقط در پنجرهٔ
/// شب (پله منهای ۹۰ دقیقه تا پله به‌علاوهٔ ۳۰ دقیقه) دیده می‌شود و بقیهٔ
/// روز کاملاً ناپیداست تا صفحهٔ خانه شلوغ نشود.
///
/// ناوبری عمداً تزریق می‌شود ([onOpen]) تا این ویجت به هیچ صفحه‌ای وابسته نباشد.
class SleepTonightShortcut extends StatefulWidget {
  const SleepTonightShortcut({
    super.key,
    required this.onOpen,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
  });

  final VoidCallback onOpen;
  final EdgeInsetsGeometry padding;

  @override
  State<SleepTonightShortcut> createState() => _SleepTonightShortcutState();
}

class _SleepTonightShortcutState extends State<SleepTonightShortcut> {
  SleepProgramState? _state;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _load();
    // پنجره زمانی است؛ بدون تیک، کاربری که صفحه را باز گذاشته میانبر را نمی‌بیند.
    _ticker = Timer.periodic(const Duration(minutes: 5), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final repo = await SleepProgramRepository.fromHelper();
      final state = await repo.refreshAndLoadState();
      if (mounted) setState(() => _state = state);
    } catch (e, st) {
      RitmoLog.error('SleepTonightShortcut', 'Failed to load sleep state', e, st);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = _state;
    if (state == null || !state.hasCard) return const SizedBox.shrink();

    final now = DateTime.now();
    final inWindow = WellbeingInsightArbiter.isInTimeWindow(
      (fromMin: state.cardWindowFromMin, toMin: state.cardWindowToMin),
      now.hour * 60 + now.minute,
    );
    if (!inWindow) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final free = state.freeNightTonight;
    final label = free
        ? 'امشب شب آزاد است'
        : 'پلهٔ امشب · ${SleepPlanInsights.hhmm(state.tonightBedtimeMin)}';

    return Padding(
      padding: widget.padding,
      child: Semantics(
        button: true,
        label: '$label؛ باز کردن مسیر خواب',
        child: Material(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: widget.onOpen,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    free ? Icons.nights_stay_outlined : Icons.bedtime_outlined,
                    size: 20,
                    color: scheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                  Icon(Icons.chevron_left, size: 20, color: scheme.outline),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
