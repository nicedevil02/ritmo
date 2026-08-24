import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';

/// فازهای مختلف چرخه بدن
enum CyclePhase {
  menstrual, // قاعدگی
  follicular, // فولیکولار
  ovulatory, //تخمک‌گذاری
  luteal, // لوتئال
}

/// مدل داده‌ای برای تنظیمات ظاهری هر فاز
class PhaseDesignTheme {
  const PhaseDesignTheme({
    required this.title,
    required this.description,
    required this.baseColor,
    required this.gradientColors,
    required this.icon,
  });
  final String title;
  final String description;
  final Color baseColor;
  final List<Color> gradientColors;
  final IconData icon;

  static PhaseDesignTheme getTheme(CyclePhase phase, RitmoColors colors) {
    switch (phase) {
      case CyclePhase.menstrual:
        return PhaseDesignTheme(
          title: 'فاز قاعدگی',
          description: 'زمان استراحت، تغذیه گرم و مراقبت ملایم از خود.',
          baseColor: colors.medicalRed,
          gradientColors: [
            colors.medicalRed,
            colors.medicalRed.withValues(alpha: 0.85),
            colors.accent,
          ],
          icon: Icons.water_drop,
        );
      case CyclePhase.follicular:
        return PhaseDesignTheme(
          title: 'فاز فولیکولار',
          description:
              'افزایش سطح انرژی! زمان ایده‌آل برای برنامه‌ریزی و یادگیری.',
          baseColor: colors.success,
          gradientColors: [
            colors.success,
            colors.success.withValues(alpha: 0.85),
            colors.primary,
          ],
          icon: Icons.wb_sunny_outlined,
        );
      case CyclePhase.ovulatory:
        return PhaseDesignTheme(
          title: 'فاز تخمک‌گذاری',
          description:
              'اوج درخشش و ارتباطات اجتماعی. کارهای گروهی عالی پیش می‌روند.',
          baseColor: colors.primary,
          gradientColors: [
            colors.primary,
            colors.primary.withValues(alpha: 0.85),
            colors.accent,
          ],
          icon: Icons.auto_awesome,
        );
      case CyclePhase.luteal:
        return PhaseDesignTheme(
          title: 'فاز لوتئال',
          description:
              'کاهش تدریجی انرژی. به سمت کارهای انفرادی و آرامش حرکت کنید.',
          baseColor: colors.warning,
          gradientColors: [
            colors.warning,
            colors.warning.withValues(alpha: 0.85),
            colors.accent,
          ],
          icon: Icons.nights_stay_outlined,
        );
    }
  }
}

/// کارت هیرو پرمیوم چرخه بدن همراه با انیمیشن ذرات و گلبرگ‌های صعودی نرم
class CycleHeroCard extends StatefulWidget {
  const CycleHeroCard({
    super.key,
    required this.currentPhase,
    required this.currentDay,
    required this.totalDaysInPhase,
    this.onTap,
  });
  final CyclePhase currentPhase;
  final int currentDay;
  final int totalDaysInPhase;
  final VoidCallback? onTap;

  @override
  State<CycleHeroCard> createState() => _CycleHeroCardState();
}

class _CycleHeroCardState extends State<CycleHeroCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  final List<_PetalParticle> _petals = [];
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    // ایجاد گلبرگ‌های اولیه
    for (var i = 0; i < 12; i++) {
      _petals.add(_PetalParticle.random(_random));
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = PhaseDesignTheme.getTheme(widget.currentPhase, colors);
    final m = context.metrics;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: double.infinity,
          constraints: BoxConstraints(
            minHeight: 180 * m.densityFactor,
          ),
          margin: EdgeInsets.all(m.spaceLg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(m.radiusHero),
            gradient: LinearGradient(
              colors: theme.gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: theme.baseColor.withValues(alpha: 0.4),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // لایه انیمیشن گلبرگ‌های صعودی پرمیوم
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    return CustomPaint(
                      painter: _PetalsPainter(
                        petals: _petals,
                        progress: _animationController.value,
                        baseColor: theme.baseColor,
                      ),
                    );
                  },
                ),
              ),

              // محتوای کارت متنی و اطلاعات چرخه
              Padding(
                padding: EdgeInsets.all(m.spaceXl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(m.spaceSm),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            theme.icon,
                            color: Colors.white,
                            size: m.iconLg,
                          ),
                        ),
                        SizedBox(width: m.spaceMd),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerRight,
                                child: Text(
                                  theme.title,
                                  style: RitmoTextStyles.sectionHeadline(Colors.white),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                toPersianDigits(
                                  'روز ${widget.currentDay} از ${widget.totalDaysInPhase}',
                                ),
                                style: RitmoTextStyles.caption(
                                  Colors.white.withValues(alpha: 0.9),
                                ).copyWith(fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: m.spaceSm),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: m.spaceMd,
                            vertical: m.spaceXs,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(m.radiusHero),
                          ),
                          child: Text(
                            'پرمیوم',
                            style: RitmoTextStyles.badge(Colors.white).copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: m.spaceMd),
                    Text(
                      theme.description,
                      style: RitmoTextStyles.body(
                        Colors.white.withValues(alpha: 0.95),
                      ).copyWith(height: 1.4),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // گل طراحی‌شده لوکس در گوشه پایین سمت چپ کارت
              Positioned(
                bottom: -15,
                left: -15,
                child: IgnorePointer(
                  child: Hero(
                    tag: 'cycle_flower_accent',
                    child: CustomPaint(
                      size: const Size(90, 90),
                      painter: _CornerFlowerPainter(baseColor: theme.baseColor),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// مدل هر گلبرگ متحرک
class _PetalParticle {
  _PetalParticle({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.opacity,
    required this.rotation,
    required this.swingAngle,
    required this.swingSpeed,
  });

  factory _PetalParticle.random(math.Random random) {
    return _PetalParticle(
      x: random.nextDouble(),
      y: random.nextDouble() * 1.2, // شروع در ارتفاع‌های مختلف
      size: random.nextDouble() * 10 + 6,
      speed: random.nextDouble() * 0.05 + 0.03,
      opacity: random.nextDouble() * 0.4 + 0.3,
      rotation: random.nextDouble() * math.pi * 2,
      swingAngle: random.nextDouble() * math.pi,
      swingSpeed: random.nextDouble() * 2 + 1,
    );
  }
  double x;
  double y;
  double size;
  double speed;
  double opacity;
  double rotation;
  double swingAngle;
  double swingSpeed;

  void update(math.Random random, double progress) {
    y -= speed * 0.015; // حرکت صعودی روبه بالا
    swingAngle += swingSpeed * 0.02;
    x += math.sin(swingAngle) * 0.002; // تاب خوردن ملایم به چپ و راست
    rotation += 0.01; // ریست شدن ذره در صورت خروج از سقف کارت
    if (y < -0.2) {
      y = 1.1;
      x =
          random.nextDouble() *
          0.6; // تمرکز بیشتردر سمت چپ (جایی که گل قرار دارد)
      opacity = random.nextDouble() * 0.4 + 0.3;
    }
  }
}

/// رسم‌کننده گلبرگ‌های صعودی
class _PetalsPainter extends CustomPainter {
  _PetalsPainter({
    required this.petals,
    required this.progress,
    required this.baseColor,
  });
  final List<_PetalParticle> petals;
  final double progress;
  final Color baseColor;
  final math.Random _random = math.Random();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (final petal in petals) {
      petal.update(_random, progress);

      final actualX = petal.x * size.width;
      final actualY = petal.y * size.height;

      canvas.save();
      canvas.translate(actualX, actualY);
      canvas.rotate(petal.rotation);

      // ایجاد افکت رنگی شیشه‌ای و درخشان برای گلبرگ‌ها
      paint.color = Colors.white.withValues(alpha: petal.opacity);

      // رسم شکل بیضی‌گون زیبا شبیه به گلبرگ طبیعی
      final path = Path();
      path.moveTo(0, -petal.size);
      path.quadraticBezierTo(
        petal.size * 0.6,
        -petal.size * 0.5,
        petal.size * 0.4,
        petal.size,
      );
      path.quadraticBezierTo(
        0,
        petal.size * 1.2,
        -petal.size * 0.4,
        petal.size,
      );
      path.quadraticBezierTo(
        -petal.size * 0.6,
        -petal.size * 0.5,
        0,
        -petal.size,
      );
      path.close();

      canvas.drawPath(path, paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// رسم‌کننده گل لوکس و چندلایه پرمیوم در گوشه کارت
class _CornerFlowerPainter extends CustomPainter {
  _CornerFlowerPainter({required this.baseColor});
  final Color baseColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.2, size.height * 0.8);
    final paint = Paint()..style = PaintingStyle.fill;

    // لایه اول: سایه گل
    paint.color = Colors.black.withValues(alpha: 0.12);
    _drawFlowerGeometry(canvas, center + const Offset(0, 4), 38, paint);

    // لایه دوم: گلبرگ‌های بیرونی روشن‌تر و بزرگ‌تر
    paint.color = Colors.white.withValues(alpha: 0.35);
    _drawFlowerGeometry(canvas, center, 36, paint);

    // لایه سوم: گلبرگ‌های اصلی همرنگ فاز ولی درخشان‌تر
    paint.color = Colors.white.withValues(alpha: 0.7);
    _drawFlowerGeometry(canvas, center, 26, paint);

    // لایه چهارم: مرکز گل (پرچم گل)
    paint.color = Colors.white;
    canvas.drawCircle(center, 10, paint);

    // پرزهای مرکز گل برای ظاهر لوکس‌تر
    paint.color = baseColor.withValues(alpha: 0.6);
    canvas.drawCircle(center, 6, paint);
  }

  void _drawFlowerGeometry(
    Canvas canvas,
    Offset center,
    double radius,
    Paint paint,
  ) {
    const petalCount = 6;
    for (var i = 0; i < petalCount; i++) {
      final angle = (i * 2 * math.pi) / petalCount;
      final petalX = center.dx + math.cos(angle) * radius * 0.6;
      final petalY = center.dy + math.sin(angle) * radius * 0.6;
      canvas.drawCircle(Offset(petalX, petalY), radius * 0.5, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
