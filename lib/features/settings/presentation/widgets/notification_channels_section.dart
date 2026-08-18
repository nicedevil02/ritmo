import 'package:flutter/cupertino.dart';
import 'package:ritmo/core/notifications/notification_channel.dart';
import 'package:ritmo/core/services/alarm_scheduler_service.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/settings/presentation/widgets/settings_section.dart';

/// بخش کانال‌های استاندارد اعلان با سوییچ فعال/غیرفعال برای هر کانال
class NotificationChannelsSection extends StatelessWidget {
  const NotificationChannelsSection({
    super.key,
    required this.loadingChannels,
    required this.channelEnabled,
    required this.onToggleChannel,
  });

  final bool loadingChannels;
  final Map<String, bool> channelEnabled;
  final void Function(NotificationChannelId channel, bool enabled) onToggleChannel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return SettingsSection(
      title: 'کانال‌های استاندارد اعلان',
      footer: 'می‌توانید اعلان‌های هر بخش را به صورت مجزا مدیریت یا موقتاً خاموش کنید.',
      children: [
        if (loadingChannels)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CupertinoActivityIndicator()),
          )
        else ...[
          for (final channel in NotificationChannelId.values)
            _buildChannelRow(channel, colors),
        ],
      ],
    );
  }

  Widget _buildChannelRow(NotificationChannelId channel, RitmoColors colors) {
    final enabled = channelEnabled[channel.nativeId] ?? true;

    final (icon, iconColor) = switch (channel) {
      NotificationChannelId.critical => (CupertinoIcons.heart_fill, const Color(0xFFEF4444)),
      NotificationChannelId.routine => (CupertinoIcons.clock_fill, const Color(0xFF3B82F6)),
      NotificationChannelId.worship => (CupertinoIcons.sun_max_fill, const Color(0xFF10B981)),
      NotificationChannelId.planning => (CupertinoIcons.calendar, const Color(0xFF8B5CF6)),
      NotificationChannelId.insight => (CupertinoIcons.sparkles, const Color(0xFFF59E0B)),
      NotificationChannelId.privateChannel => (CupertinoIcons.shield_fill, const Color(0xFFEC4899)),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      channel.titleFa,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                    if (channel.bypassesQuietHours) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: colors.medicalRed.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'عبور از سکوت',
                          style: TextStyle(fontSize: 10, color: colors.medicalRed, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  channel.descriptionFa,
                  style: TextStyle(fontSize: 12, color: colors.textSecondary),
                ),
              ],
            ),
          ),
          CupertinoSwitch(
            value: enabled,
            activeTrackColor: colors.primary,
            onChanged: (val) => onToggleChannel(channel, val),
          ),
        ],
      ),
    );
  }
}
