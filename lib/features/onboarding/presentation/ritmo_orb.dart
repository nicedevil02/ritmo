import 'dart:math' as math;
import 'package:flutter/material.dart';

class RitmoOrb extends StatefulWidget {

  const RitmoOrb({
    super.key,
    this.size = 180,
    this.isDarkMode,
  });
  final double size;
  final bool? isDarkMode;

  @override
  State<RitmoOrb> createState() => _RitmoOrbState();
}

class _RitmoOrbState extends State<RitmoOrb> with TickerProviderStateMixin {
  late AnimationController _breathingController;
  late AnimationController _heartbeatController;
  late Animation<double> _breathingAnimation;
  late Animation<double> _heartbeatAnimation;

  @override
  void initState() {
    super.initState();

    // 1. Breathing Animation Controller (Slow, persistent breathing)
    // 6-second cycle for a relaxed respiratory rhythm (10 breaths per minute)
    _breathingController = AnimationController(
      duration: const Duration(seconds: 6),
      vsync: this,
    )..repeat(reverse: true);

    _breathingAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _breathingController,
        curve: Curves.easeInOutSine,
      ),
    );

    // 2. Heartbeat Animation Controller (Periodic double-pulse)
    // 4-second cycle: active double-pulse for ~1.2s, resting for 2.8s
    _heartbeatController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat();

    // Custom double-pulse heartbeat sequence using intervals
    // First pulse: expand & contract (0.0 to 0.3)
    // Second pulse: expand slightly less & contract back (0.3 to 0.6)
    // Resting state: flat at 0.0 (0.6 to 1.0)
    _heartbeatAnimation = CurvedAnimation(
      parent: _heartbeatController,
      curve: const _HeartbeatCurve(),
    );
  }

  @override
  void dispose() {
    _breathingController.dispose();
    _heartbeatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode ?? (Theme.of(context).brightness == Brightness.dark);
    // Styling constants based on theme
    final glowColor = isDark
        ? const Color(0xff5B8AF5) // Ice Blue Accent
        : const Color(0xff3B6FE0); // Premium Blue Accent
    final secondaryGlowColor = isDark
        ? const Color(0xff9B89FF) // Delicate Purple
        : const Color(0xffC084FC);

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: Listenable.merge([_breathingAnimation, _heartbeatAnimation]),
        builder: (context, child) {
          final breath = _breathingAnimation.value;
          final pulse = _heartbeatAnimation.value;

          // Combined dynamic values
          // Breathing scales by 4%, heartbeat spikes by 8%
          final scale = 1.0 + (breath * 0.04) + (pulse * 0.08);
          // Breathing shifts glow opacity, heartbeat spikes it
          final outerGlowOpacity = 0.22 + (breath * 0.08) + (pulse * 0.35);
          final borderRadius = BorderRadius.circular(widget.size * 0.22);

          return Center(
            child: SizedBox(
              width: widget.size * 1.35,
              height: widget.size * 1.35,
              child: Center(
                child: Transform.scale(
                  scale: scale,
                  child: Container(
                    width: widget.size,
                    height: widget.size,
                    decoration: BoxDecoration(
                      borderRadius: borderRadius,
                      boxShadow: [
                        // Dynamic Breathing/Heartbeat Neon Accent Glow
                        BoxShadow(
                          color: glowColor.withValues(alpha: outerGlowOpacity.clamp(0.0, 1.0)),
                          blurRadius: (26 + (pulse * 18)) * scale,
                          spreadRadius: (3 + (pulse * 6)) * scale,
                        ),
                        BoxShadow(
                          color: secondaryGlowColor.withValues(alpha: (outerGlowOpacity * 0.65).clamp(0.0, 1.0)),
                          blurRadius: (38 + (pulse * 14)) * scale,
                          spreadRadius: (5 + (pulse * 5)) * scale,
                        ),
                        // Ambient depth shadow
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.16),
                          blurRadius: 16 * scale,
                          offset: Offset(0, 8 * scale),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: borderRadius,
                      child: Image.asset(
                        'assets/images/app_logo.png',
                        cacheWidth: 256,
                        cacheHeight: 256,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Custom Heartbeat Curve to match biological heart pulses
/// S1 -> Systole peak (first pump) -> contraction -> S2 (smaller pump) -> diastole (rest)
class _HeartbeatCurve extends Curve {
  const _HeartbeatCurve();

  @override
  double transformInternal(double t) {
    if (t < 0.12) {
      // First quick expansion
      final val = t / 0.12;
      return math.sin(val * math.pi / 2); // 0 -> 1
    } else if (t < 0.24) {
      // First quick contraction
      final val = (t - 0.12) / 0.12;
      return math.cos(val * math.pi / 2) * 0.7 + 0.3; // 1 -> 0.3
    } else if (t < 0.36) {
      // Second smaller expansion
      final val = (t - 0.24) / 0.12;
      return 0.3 + math.sin(val * math.pi / 2) * 0.4; // 0.3 -> 0.7
    } else if (t < 0.50) {
      // Second contraction back to base
      final val = (t - 0.36) / 0.14;
      return math.cos(val * math.pi / 2) * 0.7; // 0.7 -> 0.0
    }
    // Rest duration (diastole)
    return 0;
  }
}

