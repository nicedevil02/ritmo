import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/models.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/ux/ritmo_haptics.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_card.dart';
import 'package:ritmo/features/today/presentation/widgets/dashboard/next_action_hero.dart';

/// کارت هیروی «تمرکز اکنون» — متصل به سیستم کارت‌های مرجع نئومورفیک ریتمو.
///
/// با حفظ کامل موتور رنگ‌های پویای دامنه‌ای (عبادت=سبز، ورزش=نارنجی، دارو=قرمز، خواب=بنفش، کار=آبی، عقب‌افتاده=کهربایی).
class HomeFocusHero extends StatefulWidget {
  const HomeFocusHero({
    super.key,
    required this.data,
  });

  final NextActionHeroData data;

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
    final radius = BorderRadius.circular(24);

    final card = RitmoCard.neumorphic(
      borderRadius: radius,
      borderColor: tone.withValues(alpha: isDark ? 0.38 : 0.28),
      borderWidth: 1.2,
      padding: const EdgeInsets.all(16),
      enableSpring: true,
      child: _content(context, colors, tone, isDark),
    );

    final semantic = Semantics(
      container: true,
      label: data.isCurrentActive
          ? 'کار جاری: ${data.title}'
          : 'اقدام بعدی: ${data.title}',
      child: card,
    );

    final pulse = _pulse;
    if (pulse == null) return semantic;

    return AnimatedBuilder(
      animation: pulse,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(pulse.value);
        return Container(
          decoration: BoxDecoration(
            borderRadius: radius,
            boxShadow: [
              BoxShadow(
                color: tone.withValues(alpha: 0.08 + 0.12 * t),
                blurRadius: 20 + 10 * t,
                spreadRadius: -4,
              ),
            ],
          ),
          child: child,
        );
      },
      child: semantic,
    );
  }

  Widget _content(BuildContext context, RitmoColors colors, Color tone, bool isDark) {
    final data = widget.data;
    final onTone = ThemeData.estimateBrightnessForColor(tone) == Brightness.dark
        ? Colors.white
        : Colors.black87;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // ردیف نشانگر وضعیت + آیکون فرورفته نئومورفیک
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: tone.withValues(alpha: isDark ? 0.18 : 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: tone.withValues(alpha: isDark ? 0.35 : 0.25),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 6,
                    width: 6,
                    decoration: BoxDecoration(
                      color: tone,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: tone.withValues(alpha: 0.5),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    _badgeText(data),
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Vazirmatn',
                      color: tone,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            RitmoNeuSurface(
              height: 38,
              width: 38,
              radius: 19,
              sunken: true,
              padding: EdgeInsets.zero,
              glowColor: tone.withValues(alpha: 0.45),
              child: Center(
                child: Icon(
                  _iconFor(data),
                  size: 18,
                  color: tone,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // عنوان اقدام
        Text(
          toPersianDigits(data.title),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 17.5,
            height: 1.3,
            fontWeight: FontWeight.w800,
            fontFamily: 'Vazirmatn',
            color: colors.textPrimary,
          ),
        ),

        // توضیح / زمان‌بندی
        if (data.subtitle.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            toPersianDigits(data.subtitle),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              fontFamily: 'Vazirmatn',
              color: colors.textSecondary,
            ),
          ),
        ],
        const SizedBox(height: 14),

        // دکمه اقدام با فیدبک لمسی و رنگ دامنه‌ای
        Row(
          children: [
            Expanded(
              child: Semantics(
                button: true,
                label: data.primaryCtaLabel,
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        tone,
                        Color.lerp(tone, isDark ? Colors.black : Colors.white, 0.12)!,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: tone.withValues(alpha: isDark ? 0.35 : 0.28),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        RitmoHaptics.confirm();
                        data.onPrimaryTap();
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(_ctaIconFor(data), size: 17, color: onTone),
                            const SizedBox(width: 7),
                            Flexible(
                              child: Text(
                                data.primaryCtaLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                  fontFamily: 'Vazirmatn',
                                  color: onTone,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
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
                  height: 44,
                  child: TextButton(
                    onPressed: () {
                      RitmoHaptics.tap();
                      data.onSecondaryTap!();
                    },
                    child: Text(
                      data.secondaryCtaLabel!,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Vazirmatn',
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),

        // نوار قبل و بعد: قرارگیری در زیر دکمهٔ ثبت
        if (data.isCurrentActive &&
            (data.previousTaskTitle != null || data.nextTaskTitle != null)) ...[
          const SizedBox(height: RitmoSpacing.md),
          _buildTemporalContextStrip(context, colors, tone, isDark, data),
        ],
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
    final hasPrev = prevTitle != null && prevTitle.isNotEmpty;
    final hasNext = nextTitle != null && nextTitle.isNotEmpty;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7.5),
        decoration: BoxDecoration(
          color: (isDark ? Colors.black : Colors.white)
              .withValues(alpha: isDark ? 0.35 : 0.45),
          borderRadius: BorderRadius.circular(RitmoRadius.card),
          border: Border.all(
            color: tone.withValues(alpha: isDark ? 0.22 : 0.14),
            width: 0.8,
          ),
        ),
        child: Row(
          children: [
            // کار قبلی
            if (hasPrev) ...[
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      data.isPreviousTaskCompleted == true
                          ? CupertinoIcons.checkmark_circle_fill
                          : CupertinoIcons.circle,
                      size: 13,
                      color: data.isPreviousTaskCompleted == true
                          ? colors.success
                          : colors.textSecondary.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 4.5),
                    Flexible(
                      child: Text(
                        toPersianDigits(prevTitle),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10.5,
                          color: colors.textSecondary,
                          decoration: data.isPreviousTaskCompleted == true
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (hasPrev && hasNext)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 6),
                width: 1,
                height: 12,
                color: colors.border.withValues(alpha: 0.5),
              ),

            // کار بعدی
            if (hasNext) ...[
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      CupertinoIcons.arrow_left,
                      size: 11,
                      color: colors.textSecondary.withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: 4.5),
                    Expanded(
                      child: Text(
                        toPersianDigits(nextTitle),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static Color _toneFor(RitmoColors colors, NextActionHeroData data) {
    if (data.isMedicalAlert || data.type == HeroPriorityType.medicalSafety) {
      return colors.medicalRed;
    }
    if (data.domain == AgendaDomain.prayer ||
        data.domain == AgendaDomain.mustahab ||
        data.domain == AgendaDomain.worshipDebt ||
        data.category == Category.religious ||
        data.title.contains('نماز') ||
        data.title.contains('قرآن') ||
        data.title.contains('دعا')) {
      return const Color(0xFF10B981); // Emerald Worship
    }
    if (data.domain == AgendaDomain.sport ||
        data.category == Category.fitness ||
        data.title.contains('ورزش') ||
        data.title.contains('تمرین')) {
      return const Color(0xFFF97316); // Exercise Orange
    }
    if (data.domain == AgendaDomain.medicine || data.category == Category.medical) {
      return colors.medicalRed;
    }
    if (data.type == HeroPriorityType.activeTimer) {
      return const Color(0xFF0EA5E9); // Cyan / Blue Active Timer
    }
    if (data.isOverdue) {
      return const Color(0xFFF59E0B); // Amber / Gold Overdue
    }
    return switch (data.type) {
      HeroPriorityType.activeTimer => const Color(0xFF0EA5E9),
      HeroPriorityType.overdueOrNextItem => colors.primary,
      HeroPriorityType.medicalSafety => colors.medicalRed,
      HeroPriorityType.morningCheckIn => colors.goldAccent,
      HeroPriorityType.emptyState => colors.reflectionAccent,
    };
  }

  static IconData _iconFor(NextActionHeroData data) {
    if (data.isMedicalAlert || data.type == HeroPriorityType.medicalSafety) {
      return CupertinoIcons.bandage_fill;
    }
    if (data.domain == AgendaDomain.prayer ||
        data.domain == AgendaDomain.mustahab ||
        data.domain == AgendaDomain.worshipDebt ||
        data.category == Category.religious ||
        data.title.contains('نماز') ||
        data.title.contains('قرآن') ||
        data.title.contains('دعا')) {
      return CupertinoIcons.sparkles;
    }
    if (data.domain == AgendaDomain.sport ||
        data.category == Category.fitness) {
      return CupertinoIcons.flame_fill;
    }
    if (data.domain == AgendaDomain.medicine || data.category == Category.medical) {
      return CupertinoIcons.bandage_fill;
    }
    if (data.isCurrentActive) return Icons.bolt_rounded;
    if (data.isOverdue) return CupertinoIcons.clock_fill;
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
      HeroPriorityType.emptyState => Icons.add,
    };
  }

  static String _badgeText(NextActionHeroData data) {
    if (data.isCurrentActive) return 'اکنون';
    if (data.isOverdue) return 'عقب‌افتاده';
    return switch (data.type) {
      HeroPriorityType.activeTimer => 'در حال اجرا',
      HeroPriorityType.overdueOrNextItem => 'اقدام بعدی',
      HeroPriorityType.medicalSafety => 'هشدار دارویی',
      HeroPriorityType.morningCheckIn => 'ارزیابی اول روز',
      HeroPriorityType.emptyState => 'ریتم امروز',
    };
  }
}
