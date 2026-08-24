import 'package:flutter/material.dart';
import 'package:ritmo/core/ai/ai_connection_models.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_card.dart';

/// انتخابگر شبکه‌ای و ۲ ستونهٔ سرویس‌دهنده‌های هوش مصنوعی
class AiProviderGrid extends StatelessWidget {
  const AiProviderGrid({
    super.key,
    required this.presets,
    required this.selectedPresetId,
    required this.onSelect,
  });

  final List<AiProviderPreset> presets;
  final String selectedPresetId;
  final ValueChanged<AiProviderPreset> onSelect;

  IconData _getPresetIcon(String id) {
    switch (id) {
      case 'opencode':
        return Icons.code_rounded;
      case 'zhipu':
        return Icons.auto_awesome_rounded;
      case 'openrouter':
        return Icons.hub_rounded;
      case 'cloudflare':
        return Icons.cloud_queue_rounded;
      case 'groq':
        return Icons.bolt_rounded;
      case 'local':
        return Icons.terminal_rounded;
      case 'chatgpt_web':
        return Icons.public_rounded;
      case 'custom':
      default:
        return Icons.tune_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: RitmoSpacing.sm,
        crossAxisSpacing: RitmoSpacing.sm,
        mainAxisExtent: 102,
      ),
      itemCount: presets.length,
      itemBuilder: (context, index) {
        final preset = presets[index];
        final isSelected = selectedPresetId == preset.id;

        return RitmoCard(
          isSelected: isSelected,
          onTap: () => onSelect(preset),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: preset.brandColor.withValues(alpha: 0.16),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(
                        _getPresetIcon(preset.id),
                        color: preset.brandColor,
                        size: 17,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (isSelected)
                    Icon(
                      Icons.check_circle_rounded,
                      color: colors.primary,
                      size: 18,
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                preset.nameFa,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: isSelected ? colors.primary : colors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              if (preset.worksInIranWithoutVpn)
                Text(
                  'بدون فیلترشکن',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: colors.success,
                  ),
                )
              else
                Text(
                  'نیازمند VPN',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    color: colors.textTertiary,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
