// lib/features/supplementary_sports/movement/presentation/planner/movement_slot_actions_sheet.dart

import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/ux/ritmo_haptics.dart';
import 'package:ritmo/features/supplementary_sports/movement/data/movement_slot_override_repository.dart';
import 'package:ritmo/features/supplementary_sports/movement/domain/week_plan_item.dart';

const String _fontFa = 'Vazirmatn';

/// اکشن‌های «فقط این هفته» برای یک اسلات حرکت.
Future<bool> showMovementSlotActionsSheet(
  BuildContext context, {
  required WeekPlanItem item,
}) async {
  if (!item.isMovement || item.dateIso == null) return false;
  final colors = context.colors;
  final timeLabel = item.timeLabel;
  final result = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: colors.surfaceElevated,
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
                style: TextStyle(
                  fontFamily: _fontFa,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                timeLabel == null
                    ? 'فقط این هفته عوض می‌شود. قالب سر جایش می‌ماند.'
                    : 'ساعت ${toPersianDigits(timeLabel)} · فقط این هفته',
                style: TextStyle(fontFamily: _fontFa, fontSize: 12, color: colors.textSecondary),
              ),
              const SizedBox(height: 14),
              _action(
                ctx,
                icon: Icons.nights_stay_outlined,
                label: 'این هفته نرو',
                colors: colors,
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
                colors: colors,
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
                colors: colors,
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
  required RitmoColors colors,
  required VoidCallback onTap,
}) {
  return ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon, color: colors.primary),
    title: Text(
      label,
      style: TextStyle(fontFamily: _fontFa, color: colors.textPrimary, fontSize: 14),
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
