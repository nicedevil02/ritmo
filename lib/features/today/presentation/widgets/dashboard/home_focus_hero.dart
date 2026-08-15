import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/ux/ritmo_haptics.dart';
import 'package:ritmo/features/today/presentation/widgets/dashboard/next_action_hero.dart';

/// کارت هیروی «تمرکز اکنون» — بازطراحی مدرن NextActionHero.
///
/// مدل داده ([NextActionHeroData]) و رتبه‌بند اولویت (HomeFocusRanker) دست‌نخورده‌اند؛
/// این ویجت فقط لایهٔ نمایش تازه است: تُن رنگی اختصاصی هر اولویت، هالهٔ نور،
/// نوار پیشرفت مسیر روز و دکمهٔ اقدام با هدف لمسی ۵۴ پیکسل.
class HomeFocusHero extends StatefulWidget {
  const HomeFocusHero({
    super.key,
    required this.data,
    this.dayProgress,
    this.progressCaption,
  });

  final NextActionHeroData data;

  /// نسبت پیشرفت مسیر امروز (۰ تا ۱). null یعنی نوار پیشرفت نمایش داده نشود.
  final double? dayProgress;

  /// توضیح کوتاه کنار نوار پیشرفت (مثلاً «۳ کار باقی‌مانده»).
  final String? progressCaption;

  @override
  State<HomeFocusHero> createState() => _HomeFocusHeroState();
}

class _HomeFocusHeroState extends State<HomeFocusHero>
    with SingleTickerProviderStateMixin {
  AnimationController? _pulse;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncPulse();
  }

  @override
  void didUpdateWidget(covariant HomeFocusHero oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncPulse();
  }

  /// نفس‌کشیدن ملایم هاله — فقط وقتی تایمری در جریان است و هرگز با Reduced Motion.
  void _syncPulse() {
    final wantsPulse = widget.data.type == HeroPriorityType.activeTimer &&
        !RitmoMotion.reduceMotion(context);
    if (wantsPulse) {
      _pulse ??= AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 2400),
      )..repeat(reverse: true);
    } else {
      _pulse?.dispose();
      _pulse = null;
    }
  }

  @override
  void dispose() {
    _pulse?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final data = widget.data;
    final tone = _toneFor(colors, data);
    final radius = BorderRadius.circular(RitmoRadius.hero + 4);

    final card = Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            tone.withValues(alpha: isDark ? 0.26 : 0.16),
            (isDark ? colors.card : Colors.white)
                .withValues(alpha: isDark ? 0.55 : 0.88),
          ],
        ),
        border: Border.all(
          color: tone.withValues(alpha: isDark ? 0.38 : 0.26),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: tone.withValues(alpha: isDark ? 0.16 : 0.12),
            blurRadius: 26,
            spreadRadius: -8,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          children: [
            Positioned(top: -46, left: -34, child: _glow(tone, 150)),
            Positioned(
              bottom: -54,
              right: -26,
              child: _glow(colors.primary, 130),
            ),
            Padding(
              padding: const EdgeInsets.all(RitmoSpacing.lg),
              child: _content(context, colors, tone),
            ),
          ],
        ),
      ),
    );

    final semantic = Semantics(
      container: true,
      label: data.isCurrentActive ? 'کار جاری: ${data.title}' : 'اقدام بعدی: ${data.title}',
      child: card,
    );

    final pulse = _pulse;
    if (pulse == null) return semantic;

    return AnimatedBuilder(
      animation: pulse,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(pulse.value);
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            boxShadow: [
              BoxShadow(
                color: tone.withValues(alpha: 0.10 + 0.16 * t),
                blurRadius: 22 + 16 * t,
                spreadRadius: -6,
              ),
            ],
          ),
          child: child,
        );
      },
      child: semantic,
    );
  }

  Widget _glow(Color color, double size) {
    return IgnorePointer(
      child: Container(
        height: size,
        width: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: 0.20),
              color.withValues(alpha: 0.0),
            ],
          ),
        ),
      ),
    );
  }

  Widget _content(BuildContext context, RitmoColors colors, Color tone) {
    final data = widget.data;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onTone = ThemeData.estimateBrightnessForColor(tone) == Brightness.dark
        ? Colors.white
        : Colors.black87;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: tone.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(RitmoRadius.pill),
                border: Border.all(color: tone.withValues(alpha: 0.30)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 6,
                    width: 6,
                    decoration:
                        BoxDecoration(color: tone, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _badgeText(data),
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: tone,
                      ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            Container(
              height: 34,
              width: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: tone.withValues(alpha: 0.14),
                shape: BoxShape.circle,
                border: Border.all(color: tone.withValues(alpha: 0.26)),
              ),
              child: Icon(_iconFor(data), size: 17, color: tone),
            ),
          ],
        ),
        const SizedBox(height: RitmoSpacing.md),
        Text(
          toPersianDigits(data.title),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 20,
            height: 1.35,
            fontWeight: FontWeight.w800,
            color: colors.textPrimary,
            ),
        ),
        const SizedBox(height: 4),
        Text(
          toPersianDigits(data.subtitle),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12.5,
            height: 1.5,
            color: colors.textSecondary,
            ),
        ),
        if (data.isCurrentActive &&
            (data.previousTaskTitle != null || data.nextTaskTitle != null)) ...[
          const SizedBox(height: RitmoSpacing.md),
          _buildTemporalContextStrip(context, colors, tone, isDark, data),
        ],
        if (widget.dayProgress != null) ...[
          const SizedBox(height: RitmoSpacing.md),
          _progress(context, colors, tone, widget.dayProgress!),
        ],
        const SizedBox(height: RitmoSpacing.lg),
        Row(
          children: [
            Expanded(
              child: Semantics(
                button: true,
                label: data.primaryCtaLabel,
                child: SizedBox(
                  height: 54,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: tone,
                      foregroundColor: onTone,
                      elevation: 0,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(RitmoRadius.field + 2),
                      ),
                    ),
                    onPressed: () {
                      RitmoHaptics.confirm();
                      data.onPrimaryTap();
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(_ctaIconFor(data), size: 18),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            data.primaryCtaLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (data.secondaryCtaLabel != null &&
                data.onSecondaryTap != null) ...[
              const SizedBox(width: RitmoSpacing.sm),
              Semantics(
                button: true,
                label: data.secondaryCtaLabel,
                child: SizedBox(
                  height: 54,
                  child: TextButton(
                    onPressed: () {
                      RitmoHaptics.tap();
                      data.onSecondaryTap!();
                    },
                    child: Text(
                      data.secondaryCtaLabel!,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: colors.textSecondary,
                        ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildTemporalContextStrip(
    BuildContext context,
    RitmoColors colors,
    Color tone,
    bool isDark,
    NextActionHeroData data,
  ) {
    final prevTitle = data.previousTaskTitle;
    final nextTitle = data.nextTaskTitle;
    final hasPrev = prevTitle != null;
    final hasNext = nextTitle != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: (isDark ? Colors.black : Colors.white)
            .withValues(alpha: isDark ? 0.26 : 0.55),
        borderRadius: BorderRadius.circular(RitmoRadius.card - 4),
        border: Border.all(
          color: tone.withValues(alpha: isDark ? 0.22 : 0.16),
          width: 0.9,
        ),
      ),
      child: Row(
        children: [
          // 1. Previous Task (Right in RTL)
          if (hasPrev) ...[
            Icon(
              data.isPreviousTaskCompleted == true
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 13.5,
              color: data.isPreviousTaskCompleted == true
                  ? colors.success
                  : colors.textSecondary.withValues(alpha: 0.65),
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                'قبل: ${toPersianDigits(prevTitle)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: colors.textSecondary,
                  decoration: data.isPreviousTaskCompleted == true
                      ? TextDecoration.lineThrough
                      : null,
                ),
              ),
            ),
          ],

          // Flow Separator
          if (hasPrev && hasNext) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Icon(
                Icons.arrow_back_rounded,
                size: 13,
                color: tone.withValues(alpha: 0.75),
              ),
            ),
          ],

          // 2. Next Task (Left in RTL)
          if (hasNext) ...[
            Flexible(
              child: Text(
                'بعد: ${toPersianDigits(nextTitle)}${data.nextTaskTime != null ? ' (${data.nextTaskTime!})' : ''}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: hasPrev ? TextAlign.left : TextAlign.right,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: tone,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.schedule_rounded,
              size: 12,
              color: tone.withValues(alpha: 0.85),
            ),
          ],
        ],
      ),
    );
  }

  Widget _progress(
    BuildContext context,
    RitmoColors colors,
    Color tone,
    double value,
  ) {
    final clamped = value.clamp(0.0, 1.0).toDouble();
    final percent = (clamped * 100).round();
    final caption = widget.progressCaption;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              toPersianDigits('$percent٪ از مسیر امروز'),
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: colors.textSecondary,
                ),
            ),
            const Spacer(),
            if (caption != null)
              Text(
                toPersianDigits(caption),
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: colors.textSecondary,
                  ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(RitmoRadius.pill),
          child: LinearProgressIndicator(
            value: clamped,
            minHeight: 7,
            backgroundColor: tone.withValues(alpha: 0.16),
            valueColor: AlwaysStoppedAnimation<Color>(tone),
          ),
        ),
      ],
    );
  }

  static Color _toneFor(RitmoColors colors, NextActionHeroData data) {
    if (data.isMedicalAlert) return colors.medicalRed;
    return switch (data.type) {
      HeroPriorityType.activeTimer => colors.primary,
      HeroPriorityType.overdueOrNextItem => colors.primary,
      HeroPriorityType.medicalSafety => colors.medicalRed,
      HeroPriorityType.morningCheckIn => colors.accent,
      HeroPriorityType.emptyState => colors.reflectionAccent,
    };
  }

  static IconData _iconFor(NextActionHeroData data) {
    if (data.isCurrentActive) return Icons.bolt_rounded;
    return switch (data.type) {
      HeroPriorityType.activeTimer => Icons.timer_outlined,
      HeroPriorityType.overdueOrNextItem => CupertinoIcons.flag_fill,
      HeroPriorityType.medicalSafety => CupertinoIcons.bandage_fill,
      HeroPriorityType.morningCheckIn => CupertinoIcons.sunrise_fill,
      HeroPriorityType.emptyState => CupertinoIcons.leaf_arrow_circlepath,
    };
  }

  static IconData _ctaIconFor(NextActionHeroData data) {
    if (data.isCurrentActive) return Icons.check_circle_outline_rounded;
    return switch (data.type) {
      HeroPriorityType.activeTimer => Icons.play_arrow_rounded,
      HeroPriorityType.overdueOrNextItem => Icons.play_arrow_rounded,
      HeroPriorityType.medicalSafety => CupertinoIcons.capsule_fill,
      HeroPriorityType.morningCheckIn => CupertinoIcons.sunrise_fill,
      HeroPriorityType.emptyState => CupertinoIcons.add,
    };
  }

  static String _badgeText(NextActionHeroData data) {
    if (data.isCurrentActive) return 'اکنون';
    return switch (data.type) {
      HeroPriorityType.activeTimer => 'در حال اجرا',
      HeroPriorityType.overdueOrNextItem => 'اقدام بعدی',
      HeroPriorityType.medicalSafety => 'هشدار دارویی',
      HeroPriorityType.morningCheckIn => 'ارزیابی اول روز',
      HeroPriorityType.emptyState => 'ریتم امروز',
    };
  }
}
