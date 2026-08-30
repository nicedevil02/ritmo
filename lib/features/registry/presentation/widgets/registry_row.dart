import 'package:flutter/material.dart';
import 'package:ritmo/core/domain/agenda/action_router.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/utils/ritmo_toast.dart';
import 'package:ritmo/core/utils/time_of_day_minutes.dart';
import 'package:ritmo/core/ux/ritmo_haptics.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_card.dart';
import 'package:ritmo/features/calendar/presentation/utils/domain_palette.dart';
import 'package:ritmo/features/registry/domain/registry_entry.dart';
import 'package:ritmo/features/registry/presentation/widgets/registry_countdown_badge.dart';
import 'package:ritmo/features/registry/presentation/widgets/registry_status_badge.dart';

class RegistryRow extends StatelessWidget {
  const RegistryRow({
    super.key,
    required this.entry,
    this.isSelected = false,
    this.isSelectionMode = false,
    this.onTap,
    this.onLongPress,
    this.onArchive,
    this.onTogglePause,
  });

  final RegistryEntry entry;
  final bool isSelected;
  final bool isSelectionMode;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onArchive;
  final VoidCallback? onTogglePause;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final domainCol = itemColor(context, entry.agendaProxy);
    final icon = itemIcon(entry.agendaProxy);
    final isArchived = entry.status == RegistryStatus.archived;
    final isUrgent = _checkUrgency();

    Widget cardChild = RitmoCard.neumorphic(
      isSelected: isSelected,
      borderColor: isSelected ? domainCol.withValues(alpha: 0.6) : null,
      borderWidth: isSelected ? 1.5 : null,
      onTap: () {
        if (isSelectionMode) {
          onTap?.call();
        } else {
          ActionRouter.open(context, item: entry.agendaProxy);
        }
      },
      onLongPress: () {
        RitmoHaptics.confirm();
        onLongPress?.call();
      },
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      borderRadius: BorderRadius.circular(16),
      child: Row(
        children: [
          // 3D Sunken Icon Well with Domain Glow
          RitmoNeuSurface(
            height: 38,
            width: 38,
            radius: 19,
            sunken: true,
            padding: EdgeInsets.zero,
            glowColor: domainCol.withValues(alpha: 0.38),
            child: Center(
              child: Icon(icon, size: 19, color: domainCol),
            ),
          ),

          const SizedBox(width: 10),

          // 2-Row Content: Line 1 (Title + Status Badge), Line 2 (Schedule + Countdown)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Row: Title + Status Badge
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _stripEmoji(entry.title),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'Vazirmatn',
                          color: isArchived
                              ? colors.textTertiary
                              : colors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    RegistryStatusBadge(
                      status: entry.status,
                      reminderHealth: entry.reminderHealth,
                      isUrgent: isUrgent,
                    ),
                  ],
                ),

                const SizedBox(height: 3),

                // Bottom Row: Schedule summary + Countdown
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        toPersianDigits(entry.scheduleSummary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontFamily: 'Vazirmatn',
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    RegistryCountdownBadge(agendaItem: entry.agendaProxy),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: 4),

          // Three-dot menu
          _buildOverflowMenu(context, colors),
        ],
      ),
    );

    if (isArchived) {
      cardChild = Opacity(opacity: 0.50, child: cardChild);
    }

    // Wrap with dismissible if archivable
    if (!entry.caps.canArchive) {
      return Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: RitmoSpacing.lg,
          vertical: 3.5,
        ),
        child: cardChild,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: RitmoSpacing.lg,
        vertical: 3.5,
      ),
      child: Dismissible(
        key: ValueKey('entry_${entry.id}'),
        direction: DismissDirection.endToStart,
        confirmDismiss: (direction) async {
          if (!entry.caps.canArchive) {
            RitmoHaptics.warning();
            RitmoToast.show(
              context,
              'این مورد سیستمی است و قابل بایگانی نیست.',
            );
            return false;
          }
          return true;
        },
        onDismissed: (_) => onArchive?.call(),
        background: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF64748B),
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: 20),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'بایگانی',
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'Vazirmatn',
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(width: 6),
              Icon(Icons.archive_rounded, color: Colors.white, size: 20),
            ],
          ),
        ),
        child: cardChild,
      ),
    );
  }

  Widget _buildOverflowMenu(BuildContext context, RitmoColors colors) {
    return SizedBox(
      width: 34,
      height: 34,
      child: PopupMenuButton<String>(
        icon: Icon(
          Icons.more_vert_rounded,
          size: 19,
          color: colors.textTertiary,
        ),
        padding: EdgeInsets.zero,
        iconSize: 19,
        splashRadius: 18,
        position: PopupMenuPosition.under,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        onSelected: (action) {
          switch (action) {
            case 'edit':
              ActionRouter.open(context, item: entry.agendaProxy);
              break;
            case 'archive':
              onArchive?.call();
              break;
          }
        },
        itemBuilder: (_) => [
          if (entry.caps.canEdit)
            const PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit_rounded, size: 18),
                  SizedBox(width: 8),
                  Text('ویرایش', style: TextStyle(fontSize: 13, fontFamily: 'Vazirmatn')),
                ],
              ),
            ),
          if (entry.caps.canArchive)
            const PopupMenuItem(
              value: 'archive',
              child: Row(
                children: [
                  Icon(Icons.archive_rounded, size: 18),
                  SizedBox(width: 8),
                  Text('بایگانی', style: TextStyle(fontSize: 13, fontFamily: 'Vazirmatn')),
                ],
              ),
            ),
        ],
      ),
    );
  }

  bool _checkUrgency() {
    final timeStr = entry.agendaProxy.timeOfDay?.trim();
    final targetMins = TimeOfDayMinutes.tryParse(timeStr);
    if (targetMins == null) return false;

    final now = DateTime.now();
    final nowMins = now.hour * 60 + now.minute;
    final diff = targetMins - nowMins;
    return diff >= 0 && diff <= 15;
  }

  /// Strips emoji characters from title for cleaner display.
  /// The domain icon serves as the visual identifier instead.
  static String _stripEmoji(String text) {
    return text
        .replaceAll(
          RegExp(
            r'[\u{1F600}-\u{1F64F}' // Emoticons
            r'\u{1F300}-\u{1F5FF}' // Misc Symbols & Pictographs
            r'\u{1F680}-\u{1F6FF}' // Transport & Map
            r'\u{1F1E0}-\u{1F1FF}' // Flags
            r'\u{2600}-\u{26FF}' // Misc symbols
            r'\u{2700}-\u{27BF}' // Dingbats
            r'\u{FE00}-\u{FE0F}' // Variation Selectors
            r'\u{1F900}-\u{1F9FF}' // Supplemental Symbols
            r'\u{1FA70}-\u{1FAFF}' // Extended-A
            r'\u{200D}' // ZWJ
            r'\u{20E3}' // Combining Enclosing Keycap
            r'\u{FE0F}]', // Variation Selector
            unicode: true,
          ),
          '',
        )
        .trim();
  }
}
