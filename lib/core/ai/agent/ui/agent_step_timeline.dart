import 'package:flutter/material.dart';
import 'package:ritmo/core/ai/agent/agent_event.dart';

/// تایم‌لاین گام‌های ایجنت (فاز ۶ · P6-1)
///
/// ورودی همان List<AgentStep> است که از AgentStepStartedEvent و
/// AgentStepCompletedEvent در شیت جمع می‌شود؛ هیچ داده ساختگی ندارد.
class AgentStepTimeline extends StatelessWidget {
  const AgentStepTimeline({
    super.key,
    required this.steps,
    this.statusTextFa,
    this.initiallyExpanded = false,
  });

  final List<AgentStep> steps;
  final String? statusTextFa;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final status = statusTextFa?.trim() ?? '';
    if (steps.isEmpty && status.isEmpty) return const SizedBox.shrink();

    final successCount =
        steps.where((s) => s.status == AgentStepStatus.success).length;
    final failedCount =
        steps.where((s) => s.status == AgentStepStatus.failed).length;
    final running =
        steps.any((s) => s.status == AgentStepStatus.running);

    final header = StringBuffer();
    if (steps.isNotEmpty) {
      header.write('${steps.length} گام');
      header.write(' · $successCount موفق');
      if (failedCount > 0) header.write(' · $failedCount ناموفق');
    } else {
      header.write(status);
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            initiallyExpanded: initiallyExpanded,
            tilePadding: const EdgeInsets.symmetric(horizontal: 12),
            childrenPadding:
                const EdgeInsets.only(right: 12, left: 12, bottom: 8),
            leading: running
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: scheme.primary,
                    ),
                  )
                : Icon(Icons.timeline, size: 18, color: scheme.primary),
            title: Text(
              header.toString(),
              style: TextStyle(fontSize: 12, color: scheme.onSurface),
            ),
            subtitle: (status.isNotEmpty && steps.isNotEmpty)
                ? Text(
                    status,
                    style: TextStyle(
                        fontSize: 11, color: scheme.onSurfaceVariant),
                  )
                : null,
            children: steps
                .map((step) => _StepRow(step: step))
                .toList(growable: false),
          ),
        ),
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.step});

  final AgentStep step;

  IconData _iconFor(AgentStepStatus status) {
    switch (status) {
      case AgentStepStatus.pending:
        return Icons.schedule;
      case AgentStepStatus.running:
        return Icons.autorenew;
      case AgentStepStatus.success:
        return Icons.check_circle_outline;
      case AgentStepStatus.failed:
        return Icons.error_outline;
      case AgentStepStatus.cancelled:
        return Icons.block;
    }
  }

  Color _colorFor(AgentStepStatus status, ColorScheme scheme) {
    switch (status) {
      case AgentStepStatus.success:
        return Colors.green;
      case AgentStepStatus.failed:
        return scheme.error;
      case AgentStepStatus.cancelled:
        return scheme.onSurfaceVariant;
      case AgentStepStatus.pending:
      case AgentStepStatus.running:
        return scheme.primary;
    }
  }

  String _durationText() {
    final end = step.endTime;
    if (end == null) return '';
    final ms = end.difference(step.startTime).inMilliseconds;
    if (ms < 1000) return '$ms ms';
    return '${(ms / 1000).toStringAsFixed(1)} s';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final description = step.descriptionFa?.trim() ?? '';
    final duration = _durationText();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_iconFor(step.status),
              size: 16, color: _colorFor(step.status, scheme)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.titleFa,
                  style: TextStyle(fontSize: 12, color: scheme.onSurface),
                ),
                if (description.isNotEmpty)
                  Text(
                    description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 11, color: scheme.onSurfaceVariant),
                  ),
              ],
            ),
          ),
          if (duration.isNotEmpty)
            Text(
              duration,
              style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant),
            ),
        ],
      ),
    );
  }
}
