import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/agenda/agenda_renderer_registry.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';

/// Renderer for [AgendaDomain.event].
///
/// Ritmo has two independent event pipelines:
///
///  1. **Planner events** — the `کار جدید ← رویداد` flow writes a row into
///     `routines` with `itemType = 'EVENT'`. Since B-FIX-EVENT-2 these stay on
///     [AgendaDomain.routine] and carry `kind = AgendaItemKind.event`, so they
///     are rendered by [RoutineAgendaRenderer] and keep every routine action.
///  2. **Temporary events** — the `temporary_events` table, written by
///     `TemporaryEventCreateSheet` and read back by `EventAgendaSource`. These
///     are the only items that actually reach [AgendaDomain.event].
///
/// Before this renderer existed, group 2 fell through to
/// [DefaultAgendaRenderer], which knows nothing about events: a grey dot, no
/// end time, no duration, no lock state, and — because `event` is absent from
/// its `isCompletable` list — no affordance either. Two things the user
/// created the same way looked like two unrelated concepts.
///
/// Temporary events stay read-only here on purpose: `temporary_events` has no
/// completion column and no action handler, so offering a checkbox would be a
/// lie. What this renderer fixes is identity and information density.
class EventAgendaRenderer extends AgendaTileRenderer {
  const EventAgendaRenderer();

  @override
  Widget build(BuildContext context, AgendaItem item, {required VoidCallback onChanged}) {
    // Defence in depth. If a routine-backed event ever lands on this domain
    // again, hand it to the renderer that can drive a real Routine rather than
    // silently degrading it into a read-only chip.
    final routineMap = item.meta['routine'];
    if (routineMap is Map<String, dynamic> && routineMap.isNotEmpty) {
      return const RoutineAgendaRenderer().build(context, item, onChanged: onChanged);
    }

    final colors = context.colors;
    final isFixed = item.itemType == AgendaItemType.fixed;

    final timeRange = _timeRangeLabel(item);
    final duration = _durationLabel(item);
    final subtitle = item.subtitle;

    final details = <String>[
      if (timeRange != null) timeRange,
      if (duration != null) duration,
      if (subtitle != null && subtitle.isNotEmpty) subtitle,
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.accent.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: colors.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(CupertinoIcons.calendar, size: 15, color: colors.accent),
          ),
          const SizedBox(width: 10),
          Expanded(
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
                  ),
                ),
                if (details.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    details.join(' · '),
                    style: TextStyle(
                      fontFamily: 'Vazirmatn',
                      fontSize: 11,
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (isFixed) ...[
            const SizedBox(width: 6),
            Icon(
              CupertinoIcons.lock_fill,
              size: 13,
              color: colors.textSecondary.withValues(alpha: 0.7),
            ),
          ],
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: colors.accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'رویداد',
              style: TextStyle(
                fontFamily: 'Vazirmatn',
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: colors.accent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// `09:30 – 11:00`, or just the start when the window has no end.
  static String? _timeRangeLabel(AgendaItem item) {
    if (!item.hasValidTimeOfDay) return null;
    final start = item.timeOfDay!;
    final end = item.windowEnd;
    if (end == null) return toPersianDigits(start);
    final endStr = '${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}';
    return toPersianDigits('$start – $endStr');
  }

  static String? _durationLabel(AgendaItem item) {
    final minutes = item.durationMinutes;
    if (minutes == null || minutes <= 0) return null;
    if (minutes < 60) return '${toPersianDigits(minutes.toString())} دقیقه';
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    if (rest == 0) return '${toPersianDigits(hours.toString())} ساعت';
    return '${toPersianDigits(hours.toString())} ساعت و ${toPersianDigits(rest.toString())} دقیقه';
  }
}
