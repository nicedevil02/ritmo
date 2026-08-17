import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/agenda/agenda_action_handler.dart';
import 'package:ritmo/core/domain/agenda/agenda_renderer_registry.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';

class QuranDhikrAgendaRenderer extends AgendaTileRenderer {
  const QuranDhikrAgendaRenderer();

  @override
  Widget build(
    BuildContext context,
    AgendaItem item, {
    required VoidCallback onChanged,
  }) {
    final colors = context.colors;
    final isDone = item.isCompleted;

    final Widget card = Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.primary.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () async {
              await HapticFeedback.selectionClick();
              if (!context.mounted) return;
              await AgendaActionHandler.instance.toggleAgendaItem(
                item: item,
                isDone: !isDone,
                context: context,
              );
              onChanged();
            },
            child: Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Icon(
                isDone
                    ? CupertinoIcons.checkmark_circle_fill
                    : CupertinoIcons.circle,
                color: isDone ? colors.success : colors.textSecondary,
                size: 20,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.circle, size: 14, color: colors.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: () {
                Navigator.pushNamed(context, '/worship');
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: TextStyle(
                      fontFamily: 'Vazirmatn',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                      decoration: isDone ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  if (item.subtitle != null && item.subtitle!.isNotEmpty)
                    Text(
                      item.subtitle!,
                      style: TextStyle(
                        fontFamily: 'Vazirmatn',
                        fontSize: 11,
                        color: colors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (item.hasValidTimeOfDay) ...[
            Text(
              item.timeOfDay!,
              style: TextStyle(
                fontFamily: 'Vazirmatn',
                fontSize: 11,
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(width: 8),
          ],
          if (item.hasValidTimeOfDay ||
              (item.meta['practice']?['reminderEnabled'] == 1)) ...[
            Icon(
              Icons.notifications_active_outlined,
              size: 14,
              color: colors.textSecondary.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );

    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(context, '/worship');
      },
      child: card,
    );
  }
}
