import 'package:flutter/material.dart';
import 'package:ritmo/core/settings/settings_service.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/settings/presentation/widgets/settings_degraded_banner.dart';

class SettingsReadyGate extends StatefulWidget {
  const SettingsReadyGate({
    super.key,
    required this.child,
    this.showDegradedBanner = true,
  });

  final Widget child;
  final bool showDegradedBanner;

  @override
  State<SettingsReadyGate> createState() => _SettingsReadyGateState();
}

class _SettingsReadyGateState extends State<SettingsReadyGate> {
  late Future<void> _initFuture;

  @override
  void initState() {
    super.initState();
    _initFuture = SettingsService.instance.init();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: SettingsService.instance.revision,
      builder: (context, _) {
        if (!SettingsService.instance.isInitialized && !SettingsService.instance.isDegraded) {
          return FutureBuilder<void>(
            future: _initFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done &&
                  !SettingsService.instance.isInitialized &&
                  !SettingsService.instance.isDegraded) {
                return _buildSkeleton(context);
              }
              return _buildContent(context);
            },
          );
        }

        return _buildContent(context);
      },
    );
  }

  Widget _buildContent(BuildContext context) {
    if (widget.showDegradedBanner && SettingsService.instance.isDegraded) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SettingsDegradedBanner(),
          Expanded(child: widget.child),
        ],
      );
    }
    return widget.child;
  }

  Widget _buildSkeleton(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              color: colors.primary,
              strokeWidth: 2.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'در حال بارگذاری تنظیمات...',
            style: TextStyle(
              fontSize: 13,
              color: colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
