import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/ai/agent/agent_event.dart';

/// کامپوننت بصری نمایش زنده وضعیت و مراحل پردازش ایجنت
class AgentTimelineVisualizer extends StatefulWidget {
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
  State<AgentTimelineVisualizer> createState() => _AgentTimelineVisualizerState();
}

class _AgentTimelineVisualizerState extends State<AgentTimelineVisualizer>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    if (!widget.isWorking && widget.steps.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E2430) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // هدر وضعیت زنده ایجنت
            InkWell(
              onTap: widget.steps.isNotEmpty
                  ? () => setState(() => _isExpanded = !_isExpanded)
                  : null,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    if (widget.isWorking)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
                        ),
                      )
                    else
                      const Icon(
                        CupertinoIcons.checkmark_seal_fill,
                        color: Color(0xFF10B981),
                        size: 18,
                      ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.statusText,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (widget.steps.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${widget.steps.length} ابزار',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        _isExpanded ? CupertinoIcons.chevron_up : CupertinoIcons.chevron_down,
                        size: 14,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // جزئیات مراحل تاشو
            if (_isExpanded && widget.steps.isNotEmpty)
              AnimatedSize(
                duration: const Duration(milliseconds: 250),
                child: Container(
                  padding: const EdgeInsets.only(left: 14, right: 14, bottom: 12, top: 4),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Column(
                    children: widget.steps.map((step) => _buildStepRow(step, isDark)).toList(),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepRow(AgentStep step, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            step.status == AgentStepStatus.success
                ? CupertinoIcons.check_mark_circled_solid
                : (step.status == AgentStepStatus.failed
                    ? CupertinoIcons.xmark_circle_fill
                    : CupertinoIcons.circle),
            size: 16,
            color: step.status == AgentStepStatus.success
                ? const Color(0xFF10B981)
                : (step.status == AgentStepStatus.failed ? const Color(0xFFEF4444) : const Color(0xFF3B82F6)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.titleFa,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                  ),
                ),
                if (step.descriptionFa != null && step.descriptionFa!.isNotEmpty)
                  Text(
                    step.descriptionFa!,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
