// lib/features/supplementary_sports/movement/presentation/planner/movement_slot_actions_sheet.dart

import 'package:flutter/material.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/ux/ritmo_haptics.dart';
import 'package:ritmo/features/calendar/presentation/utils/calendar_tokens.dart';
import 'package:ritmo/features/supplementary_sports/movement/data/movement_slot_override_repository.dart';
import 'package:ritmo/features/supplementary_sports/movement/domain/week_plan_item.dart';

const String _fontFa = 'Vazirmatn';

/// اکشن‌های «فقط این هفته» برای یک اسلات حرکت.
Future<bool> showMovementSlotActionsSheet(
  BuildContext context, {
  required WeekPlanItem item,
}) async {
  if (!item.isMovement || item.dateIso == null) return false;
  final result = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: const Color(0xFF121A2B),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (ctx) => Directionality(
      textDirection: TextDirection.rtl,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${item.emoji} ${item.title}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: _fontFa,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                item.timeLabel == null
                    ? 'فقط این هفته عوض می‌شود. قالب سر جایش می‌ماند.'
                    : 'ساعت ${toPersianDigits(item.timeLabel!)} · فقط این هفته',
                style: const TextStyle(fontFamily: _fontFa, fontSize: 12, color: Color(0xFF8B97AB)),
              ),
              const SizedBox(height: 14),
              _action(
                ctx,
                icon: Icons.nights_stay_outlined,
                label: 'این هفته نرو',
                onTap: () async {
                  await MovementSlotOverrideRepository.instance.skip(
                    routineId: item.id,
                    dateIso: item.dateIso!,
                  );
                  if (ctx.mounted) Navigator.pop(ctx, true);
                },
              ),
              _action(
                ctx,
                icon: Icons.spa_outlined,
                label: 'نسخهٔ سبک همین امروز',
                onTap: () async {
                  await MovementSlotOverrideRepository.instance.light(
                    routineId: item.id,
                    dateIso: item.dateIso!,
                  );
                  if (ctx.mounted) Navigator.pop(ctx, true);
                },
              ),
              _action(
                ctx,
                icon: Icons.schedule_rounded,
                label: 'عوض کردن ساعت این هفته',
                onTap: () async {
                  final picked = await showTimePicker(
                    context: ctx,
                    initialTime: _parseTime(item.timeLabel) ?? const TimeOfDay(hour: 18, minute: 30),
                  );
                  if (picked == null) return;
                  final hh = picked.hour.toString().padLeft(2, '0');
                  final mm = picked.minute.toString().padLeft(2, '0');
                  await MovementSlotOverrideRepository.instance.retime(
                    routineId: item.id,
                    dateIso: item.dateIso!,
                    newTime: '$hh:$mm',
                  );
                  if (ctx.mounted) Navigator.pop(ctx, true);
                },
              ),
            ],
          ),
        ),
      ),
    ),
  );
  if (result == true) RitmoHaptics.success();
  return result == true;
}

Widget _action(
  BuildContext context, {
  required IconData icon,
  required String label,
  required VoidCallback onTap,
}) {
  return ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon, color: CalendarTokens.emerald),
    title: Text(
      label,
      style: const TextStyle(fontFamily: _fontFa, color: Colors.white, fontSize: 14),
    ),
    onTap: onTap,
  );
}

TimeOfDay? _parseTime(String? raw) {
  if (raw == null || !raw.contains(':')) return null;
  final parts = raw.split(':');
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  if (h == null || m == null) return null;
  return TimeOfDay(hour: h, minute: m);
}
