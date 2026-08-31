// =============================================================================
//  Ritmo Siri Orb — پوستهٔ سازگاری
//
//  این فایل قبلاً حدود ۳۵ کیلوبایت نقاشِ دوم داشت: یک تیلهٔ کاملاً جداگانه با
//  نورپردازی، نویز و فیزیکِ متفاوت. یعنی کاربر در نوارِ پایین یک موجود می‌دید و
//  در صفحهٔ گفتگو یک موجودِ دیگر. حالا همان موجود است، فقط در ردهٔ جزئیاتِ
//  کوچک‌تر. API عمومی دست‌نخورده است.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_marble_core.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_orb_types.dart';

export 'package:ritmo/core/widgets/ritmo/ritmo_orb_types.dart'
    show
        RitmoAiStateService,
        RitmoOrbAttention,
        RitmoOrbAttentionSignal,
        RitmoOrbEnergy,
        RitmoOrbEnergySignal,
        RitmoOrbMode,
        RitmoOrbPalette,
        RitmoOrbTier,
        RitmoOrbTruth,
        ritmoTierFor;

/// تیلهٔ پایه. همان امضای قبلی، اما دیگر نقاشِ جداگانه‌ای ندارد.
class RitmoSiriOrb extends StatelessWidget {
  const RitmoSiriOrb({
    super.key,
    this.size = 42.0,
    this.mode = RitmoOrbMode.idle,
    this.glowEnabled = true,
    this.isAnimated = true,
    this.tiltOffset = Offset.zero,
    this.squeezeFactor = 1.0,
    this.palette = RitmoOrbPalette.coral,
    this.intensity = 1.0,
    this.speed = 1.0,
    this.seed = 11,
  });

  final double size;
  final RitmoOrbMode mode;
  final bool glowEnabled;
  final bool isAnimated;
  final Offset tiltOffset;
  final double squeezeFactor;
  final RitmoOrbPalette palette;
  final double intensity;
  final double speed;
  final int seed;

  @override
  Widget build(BuildContext context) {
    return RitmoMarbleCore(
      size: size,
      mode: mode,
      glowEnabled: glowEnabled,
      isAnimated: isAnimated,
      tiltOffset: tiltOffset,
      squeezeFactor: squeezeFactor,
      palette: palette,
      intensity: intensity,
      speed: speed,
      seed: seed,
    );
  }
}

/// حبابِ فکر کردن: تیله‌ای که زیر انگشت واکنش می‌دهد و به محلِ تماس نگاه می‌کند.
class RitmoThinkingBubble extends StatefulWidget {
  const RitmoThinkingBubble({
    super.key,
    this.size = 96.0,
    this.mode = RitmoOrbMode.idle,
    this.onTap,
    this.palette = RitmoOrbPalette.coral,
    this.enableParallax = true,
    this.glowEnabled = true,
    this.isAnimated = true,
  });

  final double size;
  final RitmoOrbMode mode;
  final VoidCallback? onTap;
  final RitmoOrbPalette palette;
  final bool enableParallax;
  final bool glowEnabled;
  final bool isAnimated;

  @override
  State<RitmoThinkingBubble> createState() => _RitmoThinkingBubbleState();
}

class _RitmoThinkingBubbleState extends State<RitmoThinkingBubble> {
  double _press = 0.0;
  Offset _tilt = Offset.zero;

  void _setPress(double value) {
    if (_press == value) return;
    setState(() => _press = value);
  }

  void _aim(Offset local) {
    if (!widget.enableParallax) return;
    final double half = widget.size / 2.0;
    if (half <= 0.0) return;
    final Offset next = Offset(
      ((local.dx - half) / half).clamp(-1.0, 1.0),
      ((local.dy - half) / half).clamp(-1.0, 1.0),
    );
    if (next == _tilt) return;
    setState(() => _tilt = next);
    // تیله به همان جایی نگاه می‌کند که انگشت هست.
    RitmoOrbAttentionSignal.instance.look(next, strength: 0.6);
  }

  void _rest() {
    if (_tilt != Offset.zero) setState(() => _tilt = Offset.zero);
    RitmoOrbAttentionSignal.instance.relax();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (TapDownDetails details) {
        _setPress(1.0);
        _aim(details.localPosition);
      },
      onTapUp: (TapUpDetails details) {
        _setPress(0.0);
        _rest();
        RitmoOrbAttentionSignal.instance.nod();
        widget.onTap?.call();
      },
      onTapCancel: () {
        _setPress(0.0);
        _rest();
      },
      onPanUpdate: (DragUpdateDetails details) => _aim(details.localPosition),
      onPanEnd: (DragEndDetails details) {
        _setPress(0.0);
        _rest();
      },
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 48.0, minHeight: 48.0),
        child: RitmoMarbleCore(
          size: widget.size,
          mode: widget.mode,
          palette: widget.palette,
          glowEnabled: widget.glowEnabled,
          isAnimated: widget.isAnimated,
          tiltOffset: _tilt,
          squeezeFactor: 1.0 - 0.06 * _press,
          pulse: _press,
        ),
      ),
    );
  }
}
