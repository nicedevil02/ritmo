// =============================================================================
//  Ritmo Living Orb — حضورِ تیله در صفحه
//  ورود/خروج فقط با یک کنترلرِ کوتاه‌عمر انجام می‌شود؛ تپشِ دائمی به
//  ساعتِ مشترک واگذار شده. وقتی تیله پنهان، خاموش، پشتِ کادر، یا حرکتِ
//  کاربر خاموش است، مشترکِ ساعت لغو می‌شود: صفر فریم، صفر باتری.
//
//  و وقتی کیبرد بالا می‌آید، تیله با همان انیمیشنِ خروج، در می‌رود داخلِ
//  کادرِ تایپ و جایش را به [RitmoOrbDockLayer] می‌دهد. یک موجود، دو جایِ بودن —
//  و هرگز همزمان.
// =============================================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_marble_core.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_orb_absorb.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_orb_dock.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_orb_eyes.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_orb_halo.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_orb_motion.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_orb_settings.dart';

export 'package:ritmo/core/widgets/ritmo/ritmo_orb_motion.dart'
    show RitmoOrbLife;

/// تیلهٔ زنده: همان موجود، با جسم و حال و صدا.
class RitmoLivingOrb extends StatefulWidget {
  const RitmoLivingOrb({
    super.key,
    required this.life,
    this.size = 96.0,
    this.palette,
    this.glowEnabled = true,
    this.writingPulse,
    this.onTap,
    this.anticsStrength = 1.0,
    this.shellWobble = 1.0,
    this.bulgeStrength = 1.0,
    this.reserveHeightFactor = 1.55,
    this.breathPeriod = const Duration(milliseconds: 5200),
    this.enterDuration = const Duration(milliseconds: 760),
    this.exitDuration = const Duration(milliseconds: 900),
    this.animateOnMount = true,
    this.reactToSuccessFlare = true,
    this.absorbIntoInput = false,
    this.semanticLabel = 'دستیار هوشمند ریتمو',
    this.truth,
    this.attention,
    this.tier,
    this.energyAware = true,
    this.allowDock = true,
    this.eyeMode,
  });

  final RitmoOrbLife life;
  final double size;
  final RitmoOrbPalette? palette;
  final bool glowEnabled;

  /// هر بار که عددش بالا برود = یک تکه متن نوشته شد.
  final ValueNotifier<int>? writingPulse;
  final VoidCallback? onTap;

  /// شدتِ بازیگوشی (فقط روی نوسانِ پوسته و مقیاس؛ دیگر هیچ حرکتِ تصادفی ندارد).
  final double anticsStrength;
  final double shellWobble;
  final double bulgeStrength;

  /// ارتفاعِ رزروشده نسبت به [size]؛ جایی که هاله و بالا-پایین رفتن نفس می‌کشد.
  final double reserveHeightFactor;
  final Duration breathPeriod;
  final Duration enterDuration;
  final Duration exitDuration;
  final bool animateOnMount;
  final bool reactToSuccessFlare;

  /// وقتی true باشد، خروجِ تیله به کادرِ ورودی گزارش می‌شود (جذب شدن).
  /// در هر لحظه فقط یک تیله مالکِ این کانال است.
  final bool absorbIntoInput;
  final String semanticLabel;
  final RitmoOrbTruth? truth;
  final RitmoOrbAttention? attention;
  final RitmoOrbTier? tier;
  final bool energyAware;

  /// اجازهٔ لنگر گرفتن دورِ کادرِ تایپ وقتی کیبرد باز است.
  final bool allowDock;

  /// اگر null باشد، از تنظیماتِ کاربر پیروی می‌کند.
  final RitmoEyeMode? eyeMode;

  @override
  State<RitmoLivingOrb> createState() => _RitmoLivingOrbState();
}

class _RitmoLivingOrbState extends State<RitmoLivingOrb>
    with SingleTickerProviderStateMixin {
  static Object? _absorbOwner;

  final Object _claim = Object();
  final OverlayPortalController _portal = OverlayPortalController();
  late final AnimationController _pose;
  bool _visible = false;
  bool _exiting = false;
  bool _splashed = false;
  bool _typing = false;
  bool _docked = false;
  bool _portalShown = false;
  bool _hasOverlay = false;
  double _lastSink = -1.0;

  bool get _ownsAbsorb =>
      widget.absorbIntoInput && identical(_absorbOwner, _claim);

  RitmoOrbPalette get _palette => widget.palette ?? RitmoOrbPalette.coral;

  RitmoOrbSettings get _settings => RitmoOrbSettings.instance;

  @override
  void initState() {
    super.initState();
    unawaited(_settings.load());
    _settings.enabled.addListener(_onSettings);
    _settings.dockWhenTyping.addListener(_onSettings);
    _visible = widget.life != RitmoOrbLife.hidden;
    _pose = AnimationController(
      vsync: this,
      duration: widget.enterDuration,
      reverseDuration: widget.exitDuration,
      value: _visible && !widget.animateOnMount ? 1.0 : 0.0,
    );
    _pose.addListener(_reportAbsorb);
    _pose.addStatusListener(_onPoseStatus);
    if (widget.absorbIntoInput) {
      _absorbOwner ??= _claim;
    }
    if (_visible && widget.animateOnMount) {
      _pose.forward();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // خواندنِ viewInsets یک وابستگی می‌سازد: کیبرد که تکان بخورد، همین‌جا خبردار می‌شویم.
    _typing = MediaQuery.viewInsetsOf(context).bottom > 40.0;
    // بدون Overlay جایی برای لنگر نیست؛ به جای خطا، ساده صرف‌نظر می‌کنیم.
    _hasOverlay = Overlay.maybeOf(context) != null;
    _syncDock();
  }

  @override
  void didUpdateWidget(RitmoLivingOrb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enterDuration != widget.enterDuration) {
      _pose.duration = widget.enterDuration;
    }
    if (oldWidget.exitDuration != widget.exitDuration) {
      _pose.reverseDuration = widget.exitDuration;
    }
    if (widget.absorbIntoInput && _absorbOwner == null) {
      _absorbOwner ??= _claim;
    }
    final bool next = widget.life != RitmoOrbLife.hidden;
    if (next != _visible) {
      _visible = next;
      if (next) _splashed = false;
    }
    _syncDock();
  }

  @override
  void dispose() {
    _settings.enabled.removeListener(_onSettings);
    _settings.dockWhenTyping.removeListener(_onSettings);
    _pose.removeListener(_reportAbsorb);
    _pose.removeStatusListener(_onPoseStatus);
    _pose.dispose();
    if (identical(_absorbOwner, _claim)) {
      _absorbOwner = null;
      RitmoOrbAbsorb.instance.reset();
    }
    super.dispose();
  }

  void _onSettings() {
    if (!mounted) return;
    _syncDock();
    setState(() {});
  }

  /// تنها جایی که تصمیم می‌گیرد تیله سرِ جایش باشد یا دورِ کادرِ تایپ.
  void _syncDock() {
    _docked = widget.allowDock &&
        _hasOverlay &&
        _typing &&
        _visible &&
        widget.size >= 48.0 &&
        _settings.enabled.value &&
        _settings.dockWhenTyping.value;
    _syncPose();
    _syncPortal(_docked);
  }

  void _syncPose() {
    final bool present = _visible && !_docked;
    if (present) {
      if (_pose.status != AnimationStatus.completed &&
          _pose.status != AnimationStatus.forward) {
        _exiting = false;
        _splashed = false;
        if (_ownsAbsorb) {
          RitmoOrbAbsorb.instance.report(sink: 0.0, tint: _palette);
          RitmoOrbAbsorb.instance.lift();
        }
        _pose.forward();
      }
      return;
    }
    if (_pose.status == AnimationStatus.forward && _pose.value <= 0.01) {
      // هنوز چیزی دیده نشده — مانندِ وقتی که صفحه با کیبردِ از-قبل-باز سوار
      // می‌شود. بی‌سروصدا منصرف می‌شویم؛ وگرنه تیله هم سرِ جایش بالا می‌آید و
      // هم دورِ کادر پهن می‌شود.
      _pose.stop();
      _pose.value = 0.0;
      _exiting = false;
      return;
    }
    if (_pose.value > 0.0 && _pose.status != AnimationStatus.reverse) {
      _exiting = true;
      _pose.reverse();
    }
  }

  void _syncPortal(bool show) {
    if (show == _portalShown) return;
    _portalShown = show;
    if (show) {
      _portal.show();
    } else {
      _portal.hide();
    }
  }

  void _onPoseStatus(AnimationStatus status) {
    if (status == AnimationStatus.dismissed && _exiting) {
      _exiting = false;
      // از اینجا به بعد دیگر هیچ فریمی لازم نیست.
      if (mounted) setState(() {});
    }
  }

  void _reportAbsorb() {
    if (!_ownsAbsorb) return;
    final double sink = (1.0 - _pose.value).clamp(0.0, 1.0);
    final bool edge = sink <= 0.001 || sink >= 0.999;
    if (!edge && (sink - _lastSink).abs() < 0.02) return;
    _lastSink = sink;
    final RitmoOrbAbsorb bus = RitmoOrbAbsorb.instance;
    bus.report(sink: sink, tint: _palette);
    if (sink >= 0.999 && !_splashed) {
      _splashed = true;
      bus.splash(tint: _palette);
      unawaited(HapticFeedback.lightImpact());
    }
  }

  /// متنِ وضعیت برای screen reader. تیله دیگر فقط برای چشم نیست.
  String _voice(RitmoOrbLife life, RitmoOrbTruth truth) {
    if (truth == RitmoOrbTruth.offline) return 'آفلاین';
    if (truth == RitmoOrbTruth.unsure) return 'مطمئن نیست';
    if (_docked) return 'کنارِ کادرِ پیام، منتظرِ نوشتنِ شما';
    switch (life) {
      case RitmoOrbLife.hidden:
      case RitmoOrbLife.dormant:
        return 'آماده';
      case RitmoOrbLife.breathing:
        return 'آمادهٔ گفتگو';
      case RitmoOrbLife.listening:
        return 'در حال شنیدن';
      case RitmoOrbLife.thinking:
        return 'در حال فکر کردن';
      case RitmoOrbLife.writing:
        return 'در حال نوشتن پاسخ';
      case RitmoOrbLife.celebrating:
        return 'پاسخ آماده شد';
    }
  }

  void _handleTap() {
    // پلکِ آگاهانه: تیله می‌فهمد که صدایش زدند.
    RitmoOrbAttentionSignal.instance.nod();
    unawaited(HapticFeedback.selectionClick());
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    return RitmoOrbSettingsBuilder(
      builder: (context, settings) {
        if (!settings.enabled) {
          // خاموش است: نه نقاشی، نه فریم، نه فضای رزروشده.
          return const SizedBox.shrink();
        }
        return _buildCreature(context, settings);
      },
    );
  }

  Widget _buildCreature(
    BuildContext context,
    RitmoOrbSettingsSnapshot settings,
  ) {
    final bool reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final RitmoOrbTier tier = widget.tier ?? ritmoTierFor(widget.size);
    final double reserve = widget.size * widget.reserveHeightFactor;
    final RitmoEyeMode eyeMode = widget.eyeMode ??
        (settings.eyes ? RitmoEyeMode.occasional : RitmoEyeMode.off);

    return ValueListenableBuilder<RitmoOrbTruth>(
      valueListenable: RitmoAiStateService.instance.truth,
      builder: (context, liveTruth, _) {
        final RitmoOrbTruth truth = widget.truth ?? liveTruth;
        final RitmoOrbSignature base = RitmoOrbSignature.of(widget.life);
        final RitmoOrbSignature signature = base.copyWith(
          wobble: base.wobble * widget.anticsStrength.clamp(0.0, 2.0),
        );
        // تیلهٔ نادیده نباید فریم بگیرد — نه پنهان، نه پشتِ کادر.
        final bool animate =
            !reduceMotion && ((_visible && !_docked) || _exiting);

        // این زیردرخت در طولِ انیمیشنِ ورود/خروج بازساخته نمی‌شود.
        final Widget creature = Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: <Widget>[
            if (widget.glowEnabled && tier != RitmoOrbTier.s)
              OverflowBox(
                maxWidth: widget.size * 1.7,
                maxHeight: widget.size * 1.7,
                child: IgnorePointer(
                  child: CustomPaint(
                    size: Size.square(widget.size * 1.7),
                    painter: RitmoOrbHaloPainter(
                      palette: _palette,
                      strength: signature.aura,
                      breath: 0.5,
                      tier: tier,
                      isDark: isDark,
                    ),
                  ),
                ),
              ),
            RitmoMarbleCore(
              size: widget.size,
              mode: ritmoModeFor(widget.life),
              signature: signature,
              palette: _palette,
              glowEnabled: widget.glowEnabled,
              isAnimated: animate,
              shellWobble: widget.shellWobble,
              bulgeStrength: widget.bulgeStrength,
              tier: widget.tier,
              truth: truth,
              attention: widget.attention,
              tokenPulse: widget.writingPulse,
              energyAware: widget.energyAware,
              reactToFlare: widget.reactToSuccessFlare,
              eyeMode: eyeMode,
            ),
          ],
        );

        final Widget animated = AnimatedBuilder(
          animation: _pose,
          child: creature,
          builder: (context, child) {
            final double raw = reduceMotion
                ? (_visible && !_docked ? 1.0 : 0.0)
                : (_pose.status == AnimationStatus.reverse
                    ? Curves.easeInCubic.transform(_pose.value)
                    : Curves.easeOutBack.transform(_pose.value).clamp(0.0, 1.2));
            final RitmoOrbPose pose = RitmoOrbPose.lerp(
              RitmoOrbPose.gone,
              RitmoOrbPose.present,
              raw.clamp(0.0, 1.0),
            );
            final double scale =
                pose.scale * (1.0 + 0.06 * (raw - 1.0).clamp(0.0, 0.2));
            Widget body = Transform(
              alignment: Alignment.center,
              transform: Matrix4.translationValues(
                0.0,
                pose.lift * widget.size,
                0.0,
              )..scaleByDouble(scale, scale, 1.0, 1.0),
              child: child,
            );
            if (pose.opacity < 0.999) {
              body = Opacity(opacity: pose.opacity, child: body);
            }
            return body;
          },
        );

        Widget content = SizedBox(
          width: widget.size,
          height: reserve,
          child: Center(child: animated),
        );

        if (widget.onTap != null) {
          content = GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _handleTap,
            child: ConstrainedBox(
              // حداقلِ ناحیهٔ لمس، طبق راهنمای دسترسی‌پذیری.
              constraints: const BoxConstraints(minWidth: 48.0, minHeight: 48.0),
              child: content,
            ),
          );
        }

        final Widget spoken = Semantics(
          container: true,
          liveRegion: true,
          button: widget.onTap != null,
          label: widget.semanticLabel,
          value: _voice(widget.life, truth),
          child: ExcludeSemantics(child: content),
        );

        if (!widget.allowDock) return spoken;

        return OverlayPortal(
          controller: _portal,
          overlayChildBuilder: (context) => RitmoOrbDockLayer(
            palette: _palette,
            signature: signature,
            truth: widget.truth,
            tokenPulse: widget.writingPulse,
            eyes: settings.eyes,
          ),
          child: spoken,
        );
      },
    );
  }
}
