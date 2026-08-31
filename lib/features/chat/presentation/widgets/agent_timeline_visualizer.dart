import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/ai/agent/agent_event.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_orb_presence.dart';

/// کامپوننت بصری نمایش زنده وضعیت پردازش با گوی کریستالی شفاف و شناور
class AgentTimelineVisualizer extends StatelessWidget {
  final List<AgentStep> steps;
  final String statusText;
  final bool isWorking;
  final ValueNotifier<int>? writingPulse;

  const AgentTimelineVisualizer({
    super.key,
    required this.steps,
    required this.statusText,
    required this.isWorking,
    this.writingPulse,
  });

  @override
  Widget build(BuildContext context) {
    if (!isWorking) {
      return const SizedBox.shrink();
    }

    return RepaintBoundary(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 14, top: 6),
          child: RitmoLivingOrb(
            life: RitmoOrbLife.writing,
            writingPulse: writingPulse,
            size: 52.0,
            glowEnabled: true,
          ),
        ),
      ),
    );
  }
}
