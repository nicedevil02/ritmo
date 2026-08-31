import 'package:flutter/material.dart';
import 'package:ritmo/core/ai/agent/agent_event.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_orb_presence.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_siri_orb.dart';

/// نمایش زندهٔ وضعیت پردازش دستیار.
///
/// مهم: این ویجت دیگر هرگز `SizedBox.shrink()` برنمی‌گرداند. خودِ
/// [RitmoLivingOrb] مسئول جمع کردن فضای خودش است؛ وگرنه ویجت بلافاصله
/// unmount می‌شود و انیمیشن خروج هیچ‌وقت پخش نمی‌شود (باگ قبلی).
class AgentTimelineVisualizer extends StatelessWidget {
  const AgentTimelineVisualizer({
    super.key,
    required this.steps,
    required this.statusText,
    required this.isWorking,
    this.writingPulse,
    this.isListening = false,
    this.orbSize = 54.0,
    this.showStatusText = true,
  });

  final List<AgentStep> steps;
  final String statusText;
  final bool isWorking;

  /// روی هر ChatChunk یکی بالا می‌رود تا تیله روی هر توکن ذوق کند.
  final ValueNotifier<int>? writingPulse;

  /// اگر میکروفون باز است، تیله به حالت «گوش می‌دهم» می‌رود.
  final bool isListening;

  final double orbSize;
  final bool showStatusText;

  static RitmoOrbLife _lifeFor({
    required bool isWorking,
    required bool isListening,
    required RitmoOrbMode mode,
  }) {
    if (isListening) return RitmoOrbLife.listening;
    if (!isWorking) return RitmoOrbLife.hidden;

    switch (mode) {
      case RitmoOrbMode.streaming:
        return RitmoOrbLife.writing;
      case RitmoOrbMode.thinking:
        return RitmoOrbLife.thinking;
      case RitmoOrbMode.idle:
      case RitmoOrbMode.compact:
        // پاسخ تمام شده ولی هنوز پنجرهٔ کوتاهی مانده:
        // یک جشن گرم بگیر، بعد محو شو.
        return RitmoOrbLife.celebrating;
    }
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: ValueListenableBuilder<RitmoOrbMode>(
        valueListenable: RitmoAiStateService.instance.orbMode,
        builder: (BuildContext context, RitmoOrbMode mode, Widget? _) {
          final RitmoOrbLife life = _lifeFor(
            isWorking: isWorking,
            isListening: isListening,
            mode: mode,
          );

          final bool showText = showStatusText &&
              life != RitmoOrbLife.hidden &&
              life != RitmoOrbLife.celebrating;

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              RitmoLivingOrb(
                life: life,
                size: orbSize,
                writingPulse: writingPulse,
              ),
              _StatusWhisper(text: statusText, visible: showText),
            ],
          );
        },
      ),
    );
  }
}

/// یک خط متنِ زیرِ تیله که آرام جایگزین می‌شود (بدون پرش لایه‌بندی).
class _StatusWhisper extends StatelessWidget {
  const _StatusWhisper({required this.text, required this.visible});

  final String text;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    final bool show = visible && text.trim().isNotEmpty;
    final Color color = context.colors.textSecondary;

    return AnimatedSize(
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeInOutCubic,
      alignment: Alignment.topCenter,
      child: !show
          ? const SizedBox.shrink()
          : Padding(
              padding: const EdgeInsets.only(bottom: 10.0),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 360),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                layoutBuilder: (Widget? current, List<Widget> previous) {
                  return Stack(
                    alignment: Alignment.topCenter,
                    children: <Widget>[...previous, if (current != null) current],
                  );
                },
                transitionBuilder: (Widget child, Animation<double> anim) {
                  return FadeTransition(
                    opacity: anim,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.0, 0.32),
                        end: Offset.zero,
                      ).animate(
                        CurvedAnimation(
                          parent: anim,
                          curve: Curves.easeOutCubic,
                        ),
                      ),
                      child: child,
                    ),
                  );
                },
                child: Text(
                  text,
                  key: ValueKey<String>(text),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.45,
                    letterSpacing: -0.1,
                    fontWeight: FontWeight.w600,
                    color: color.withValues(alpha: 0.72),
                  ),
                ),
              ),
            ),
    );
  }
}
