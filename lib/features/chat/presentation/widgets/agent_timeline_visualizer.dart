import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/ai/agent/agent_event.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_siri_orb.dart';

/// کامپوننت بصری نمایش زنده وضعیت پردازش با گوی کریستالی شفاف و شناور
class AgentTimelineVisualizer extends StatelessWidget {
  final List<AgentStep> steps;
  final String statusText;
  final bool isWorking;

  const AgentTimelineVisualizer({
    super.key,
    required this.steps,
    required this.statusText,
    required this.isWorking,
  });

  @override
  Widget build(BuildContext context) {
    if (!isWorking) {
      return const SizedBox.shrink();
    }

    return const RepaintBoundary(
      child: Center(
        child: Padding(
          padding: EdgeInsets.only(bottom: 14, top: 6),
          child: RitmoSiriOrb(
            size: 52.0,
            mode: RitmoOrbMode.streaming,
            glowEnabled: true,
            isAnimated: true,
          ),
        ),
      ),
    );
  }
}
