import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/models.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/utils/ritmo_color.dart';
import 'package:ritmo/features/today/presentation/widgets/dashboard/next_action_hero.dart';

/// کارت هیروی «تمرکز اکنون» — متصل به سیستم کارت‌های مرجع نئومورفیک ریتمو.
///
/// با زمینه گرادیانت نوری زنده و رنگ‌های پویای دامنه‌ای (عبادت=سبز، ورزش=نارنجی، دارو=قرمز، خواب/مطالعه=بنفش، کار=آبی، عقب‌افتاده=کهربایی).
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
      backgroundColor: Color.lerp(
        isDark ? colors.card : Colors.white,
        tone,
        isDark ? 0.22 : 0.12,
      ),
      borderColor: tone.withValues(alpha: isDark ? 0.42 : 0.30),
      borderWidth: 1.2,
      customShadows: [
        ...RitmoNeu.raisedShadows(isDark, blur: 14, distance: 4.5),
        BoxShadow(
          color: tone.withValues(alpha: isDark ? 0.28 : 0.18),
          blurRadius: 28,
          spreadRadius: -4,
          offset: const Offset(0, 8),
        ),
      ],
      padding: EdgeInsets.zero,
      enableSpring: true,
      child: ClipRRect(
        borderRadius: radius,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [
                tone.withValues(alpha: isDark ? 0.32 : 0.22),
                (isDark ? colors.card : Colors.white)
                    .withValues(alpha: isDark ? 0.45 : 0.85),
              ],
            ),
          ),
          child: Stack(
            children: [
              // هاله نوری گوشه بالا-راست
              Positioned(
                top: -36,
                left: -24,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        tone.withValues(alpha: isDark ? 0.32 : 0.24),
                        tone.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
              // هاله نوری ملایم پایین
              Positioned(
                bottom: -40,
                right: -20,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        colors.primary.withValues(alpha: isDark ? 0.16 : 0.10),
                        colors.primary.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: _content(context, colors, tone, isDark),
              ),
            ],
          ),
        ),
      ),
    );

    final semantic = Semantics(
      container: true,
      label: data.isCurrentActive
          ? 'کار جاری: ${data.title}'
          : 'اقدام بعدی: ${data.title}',
      child: card,
    );

    final pulse = _pulse;
    if (pulse == null) return RepaintBoundary(child: semantic);

    return RepaintBoundary(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: FadeTransition(
              opacity: pulse,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: radius,
                  boxShadow: [
                    BoxShadow(
                      color: tone.withValues(alpha: 0.28),
                      blurRadius: 30,
                      spreadRadius: -3,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
              ),
            ),
          ),
          semantic,
        ],
      ),
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
    if (data.colorHex != null && data.colorHex!.trim().isNotEmpty) {
      final parsed = RitmoColor.fromHex(data.colorHex);
      if (parsed != Colors.transparent) return parsed;
    }
    if (data.isMedicalAlert || data.type == HeroPriorityType.medicalSafety) {
      return colors.medicalRed;
    }
    final tLower = data.title.toLowerCase();
    if (data.domain == AgendaDomain.prayer ||
        data.domain == AgendaDomain.mustahab ||
        data.domain == AgendaDomain.worshipDebt ||
        data.category == Category.religious ||
        tLower.contains('نماز') ||
        tLower.contains('قرآن') ||
        tLower.contains('دعا') ||
        tLower.contains('اذان') ||
        tLower.contains('صبحگاه') ||
        tLower.contains('ظهر') ||
        tLower.contains('عصر') ||
        tLower.contains('مغرب') ||
        tLower.contains('عشا') ||
        tLower.contains('زیارت') ||
        tLower.contains('مسجد') ||
        tLower.contains('ذکر')) {
      return const Color(0xFF10B981); // Emerald Worship
    }
    if (data.domain == AgendaDomain.sport ||
        data.category == Category.fitness ||
        tLower.contains('ورزش') ||
        tLower.contains('تمرین') ||
        tLower.contains('دویدن') ||
        tLower.contains('شنا') ||
        tLower.contains('باشگاه') ||
        tLower.contains('پیاده‌روی') ||
        tLower.contains('کشش')) {
      return const Color(0xFFF97316); // Exercise Orange
    }
    if (data.domain == AgendaDomain.medicine ||
        data.category == Category.medical ||
        tLower.contains('دارو') ||
        tLower.contains('قرص') ||
        tLower.contains('شربت') ||
        tLower.contains('انسولین') ||
        tLower.contains('پزشک')) {
      return colors.medicalRed;
    }
    if (data.category == Category.learning ||
        data.category == Category.konkur ||
        data.domain == AgendaDomain.course ||
        data.domain == AgendaDomain.konkur ||
        tLower.contains('درس') ||
        tLower.contains('مطالعه') ||
        tLower.contains('کتاب') ||
        tLower.contains('کنکور')) {
      return const Color(0xFF8B5CF6); // Purple / Deep Violet
    }
    if (data.category == Category.work ||
        data.domain == AgendaDomain.task ||
        data.domain == AgendaDomain.commitment ||
        tLower.contains('کار') ||
        tLower.contains('پروژه') ||
        tLower.contains('کد') ||
        tLower.contains('جلسه')) {
      return const Color(0xFF2563EB); // Royal Focus Blue
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
    final tLower = data.title.toLowerCase();
    if (data.domain == AgendaDomain.prayer ||
        data.domain == AgendaDomain.mustahab ||
        data.domain == AgendaDomain.worshipDebt ||
        data.category == Category.religious ||
        tLower.contains('نماز') ||
        tLower.contains('قرآن') ||
        tLower.contains('دعا') ||
        tLower.contains('زیارت')) {
      return CupertinoIcons.sparkles;
    }
    if (data.domain == AgendaDomain.sport ||
        data.category == Category.fitness ||
        tLower.contains('ورزش') ||
        tLower.contains('تمرین') ||
        tLower.contains('باشگاه')) {
      return CupertinoIcons.flame_fill;
    }
    if (data.domain == AgendaDomain.medicine ||
        data.category == Category.medical ||
        tLower.contains('دارو') ||
        tLower.contains('قرص')) {
      return CupertinoIcons.bandage_fill;
    }
    if (data.category == Category.learning ||
        data.domain == AgendaDomain.course ||
        tLower.contains('درس') ||
        tLower.contains('کتاب')) {
      return CupertinoIcons.book_fill;
    }
    if (data.category == Category.work ||
        data.domain == AgendaDomain.task ||
        tLower.contains('کار') ||
        tLower.contains('پروژه')) {
      return CupertinoIcons.briefcase_fill;
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
