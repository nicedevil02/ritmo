// C-43, C-44: CycleOrbCard (3-Slide Interactive Neumorphic Soft UI & Apple Glassmorphic Carousel)
import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/domain/engines/cycle_engine.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';

class CycleOrbCard extends StatefulWidget {
  const CycleOrbCard({
    super.key,
    required this.phase,
    required this.isTodayPeriod,
    required this.activePeriodDay,
    required this.dayOfCycle,
    required this.totalCycleLength,
    required this.avgPeriodDuration,
    this.onStatusTap,
    this.onForecastTap,
    this.onCareTipsTap,
  });

  final CyclePhase phase;
  final bool isTodayPeriod;
  final int activePeriodDay;
  final int dayOfCycle;
  final double totalCycleLength;
  final double avgPeriodDuration;
  final VoidCallback? onStatusTap;
  final VoidCallback? onForecastTap;
  final VoidCallback? onCareTipsTap;

  @override
  State<CycleOrbCard> createState() => _CycleOrbCardState();
}

class _CycleOrbCardState extends State<CycleOrbCard> {
  late final PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    var phaseText = '';
    var remainingText = '';
    var emoji = '✨';
    var statusTip = '';
    var phaseColor = const Color(0xFFF27A6D);

    switch (widget.phase) {
      case CyclePhase.menstrual:
        phaseText = 'دوران قاعدگی (پریود)';
        remainingText =
            'روز ${PersianDigits.toFa(widget.activePeriodDay.toString())} دوره خونریزی';
        phaseColor = isDark ? const Color(0xFFFF7E70) : const Color(0xFFEB6E60);
        emoji = '🩸';
        statusTip =
            'بدن شما در حال پاکسازی طبیعی است. استراحت کافی، نوشیدن آب ولرم و دمنوش‌های ملایم به کاهش انقباضات کمک می‌کند.';
      case CyclePhase.ovulation:
        phaseText = 'روز تخمک‌گذاری';
        remainingText = 'اوج هورمون‌های زنانه و باروری';
        phaseColor = isDark ? const Color(0xFFFFA048) : const Color(0xFFE88A2E);
        emoji = '🥚';
        statusTip =
            'تخمک‌گذاری رخ داده است. هورمون‌ها در بالاترین سطح خود هستند و آمادگی فیزیکی و سطح نشاط بدنی شما عالی است.';
      case CyclePhase.luteal:
        phaseText = 'روزهای پیش از عادت (PMS)';
        remainingText =
            'روز ${PersianDigits.toFa(widget.dayOfCycle.toString())} چرخه بدنی';
        phaseColor = isDark ? const Color(0xFFE074C4) : const Color(0xFFC752A8);
        emoji = '🌸';
        statusTip =
            'روزهای قبل از پریود؛ نوسان هورمونی طبیعی است. یوگای آرام، کاهش مصرف نمک و خواب منظم بسیار موثر است.';
      case CyclePhase.dataStale:
        phaseText = 'نیاز به بازبینی وضعیت';
        remainingText = 'موعد تخمینی سپری شده است';
        phaseColor = isDark ? const Color(0xFFFFB84D) : const Color(0xFFE59828);
        emoji = '⏳';
        statusTip =
            'لطفاً وضعیت ثبت دورهٔ خود را مشخص کنید تا محاسبات و یادآوری‌ها دقیق بمانند.';
      case CyclePhase.pregnancy:
        phaseText = 'دوران بارداری';
        remainingText = 'محاسبات چرخه متوقف شده است';
        phaseColor = isDark ? const Color(0xFF72A6F8) : const Color(0xFF4C87E8);
        emoji = '🤰';
        statusTip =
            'حالت بارداری فعال است و ریتم متناسب با این دوران تنظیم شده است.';
      case CyclePhase.noData:
        phaseText = 'در انتظار ثبت داده';
        remainingText = 'اولین دورهٔ خود را ثبت کنید';
        phaseColor = colors.textSecondary;
        emoji = '📅';
        statusTip =
            'برای شروع تحلیل‌های هوشمند، اولین دورهٔ ریتم خود را ثبت کنید.';
      case CyclePhase.follicular:
        phaseText = 'فاز فولیکولار (رشد)';
        remainingText =
            'روز ${PersianDigits.toFa(widget.dayOfCycle.toString())} چرخه بدنی';
        phaseColor = isDark ? const Color(0xFF5CC9A7) : const Color(0xFF38AA84);
        emoji = '✨';
        statusTip =
            'فاز فولیکولار با رشد فولیکول‌ها شروع شده است. سطح هورمون استروژن افزایش یافته و انرژی و تمرکز شما رو به رشد است.';
    }

    final currentDay = widget.isTodayPeriod ? widget.activePeriodDay : widget.dayOfCycle;
    final totalDays = widget.isTodayPeriod ? widget.avgPeriodDuration : widget.totalCycleLength;
    final targetProgress = totalDays > 0
        ? (currentDay / totalDays).clamp(0.05, 1.0)
        : 0.1;
    final m = context.metrics;

    final cardBgColor = isDark ? const Color(0xFF1E2127) : const Color(0xFFF1F3F6);
    final cardLightShadow = isDark
        ? const Color(0xFF2B3039)
        : Colors.white;
    final cardDarkShadow = isDark
        ? Colors.black.withValues(alpha: 0.65)
        : const Color(0xFFBAC4D0).withValues(alpha: 0.70);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 340;
        final cardHeight = isCompact ? 195.0 : 205.0 * m.densityFactor;

        return Container(
          width: double.infinity,
          height: cardHeight,
          decoration: BoxDecoration(
            color: cardBgColor,
            borderRadius: BorderRadius.circular(34),
            boxShadow: [
              BoxShadow(
                color: cardLightShadow,
                offset: const Offset(-8, -8),
                blurRadius: 18,
              ),
              BoxShadow(
                color: cardDarkShadow,
                offset: const Offset(8, 8),
                blurRadius: 20,
              ),
            ],
          ),
          child: Stack(
            children: [
              PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                children: [
                  // اسلاید ۱: وضعیت لحظه‌ای (کلیک -> ثبت علائم)
                  _buildSlide1Status(
                    context: context,
                    isCompact: isCompact,
                    m: m,
                    phaseColor: phaseColor,
                    isDark: isDark,
                    targetProgress: targetProgress,
                    currentDay: currentDay,
                    emoji: emoji,
                    phaseText: phaseText,
                    remainingText: remainingText,
                    statusTip: statusTip,
                  ),

                  // اسلاید ۲: پیش‌بینی روزهای آینده (کلیک -> تقویم دوره‌ها)
                  _buildSlide2Forecast(
                    context: context,
                    isCompact: isCompact,
                    m: m,
                    isDark: isDark,
                  ),

                  // اسلاید ۳: توصیه‌های امروز (کلیک -> تسکین درد و SOS)
                  _buildSlide3Recommendations(
                    context: context,
                    isCompact: isCompact,
                    m: m,
                    isDark: isDark,
                    phaseColor: phaseColor,
                  ),
                ],
              ),

              // ۳ نقطه نشانگر وضعیت در پایین کارت
              Positioned(
                bottom: 10,
                left: 0,
                right: 0,
                child: _buildBottomStatusDots(
                  activeIndex: _currentPage,
                  phaseColor: phaseColor,
                  isDark: isDark,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // اسلاید ۱: وضعیت لحظه‌ای (کلیک -> ثبت علائم)
  // ---------------------------------------------------------------------------
  Widget _buildSlide1Status({
    required BuildContext context,
    required bool isCompact,
    required RitmoMetrics m,
    required Color phaseColor,
    required bool isDark,
    required double targetProgress,
    required int currentDay,
    required String emoji,
    required String phaseText,
    required String remainingText,
    required String statusTip,
  }) {
    final dialSize = isCompact ? 98.0 : 108.0 * m.densityFactor;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onStatusTap,
        borderRadius: BorderRadius.circular(34),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            16 * m.densityFactor,
            12 * m.densityFactor,
            16 * m.densityFactor,
            20 * m.densityFactor,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // متن‌ها در سمت راست
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        remainingText,
                        style: TextStyle(
                          fontSize: isCompact ? 15.5 : 17.5,
                          fontWeight: FontWeight.w900,
                          color: isDark
                              ? const Color(0xFFF5F5F7)
                              : const Color(0xFF1D2129),
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        statusTip,
                        style: TextStyle(
                          fontSize: isCompact ? 11.0 : 11.8,
                          height: 1.5,
                          color: isDark
                              ? const Color(0xFFA1A8B3)
                              : const Color(0xFF6B7280),
                        ),
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(width: isCompact ? 10 : 14),

              // دایره و کپسول فاز زیر آن در سمت چپ
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _buildNeumorphicAcrylicDial(
                    context: context,
                    dialSize: dialSize,
                    targetProgress: targetProgress,
                    phaseColor: phaseColor,
                    currentDay: currentDay,
                    isDark: isDark,
                    phase: widget.phase,
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: phaseColor.withValues(
                        alpha: isDark ? 0.22 : 0.14,
                      ),
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(
                        color: phaseColor.withValues(
                          alpha: isDark ? 0.40 : 0.28,
                        ),
                        width: 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(emoji, style: const TextStyle(fontSize: 10.5)),
                        const SizedBox(width: 3),
                        Text(
                          phaseText,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? phaseColor
                                : Color.lerp(
                                    phaseColor,
                                    Colors.black,
                                    0.25,
                                  ),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // اسلاید ۲: پیش‌بینی روزهای آینده (کلیک -> اسکرول به تقویم)
  // ---------------------------------------------------------------------------
  Widget _buildSlide2Forecast({
    required BuildContext context,
    required bool isCompact,
    required RitmoMetrics m,
    required bool isDark,
  }) {
    final cycleLen = widget.totalCycleLength > 0 ? widget.totalCycleLength.round() : 28;
    final periodDur = widget.avgPeriodDuration > 0 ? widget.avgPeriodDuration.round() : 5;
    final ovulationDay = (cycleLen - 14).clamp(periodDur + 2, cycleLen - 4);
    final follicularDays = (ovulationDay - periodDur).clamp(3, 16);
    final lutealDays = (cycleLen - ovulationDay - 2).clamp(5, 18);
    final daysUntilPeriodEnd = (periodDur - widget.activePeriodDay).clamp(1, periodDur);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onForecastTap,
        borderRadius: BorderRadius.circular(34),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            16 * m.densityFactor,
            12 * m.densityFactor,
            16 * m.densityFactor,
            20 * m.densityFactor,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'پیش‌بینی روزهای آینده',
                    style: TextStyle(
                      fontSize: isCompact ? 15 : 17,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : const Color(0xFF1D2129),
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    'نمای کلی چرخه تا شروع دوره بعدی (مشاهده تقویم)',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: isDark ? const Color(0xFF9096A2) : const Color(0xFF7A828E),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // ۴ کارت فازهای متوالی
              Expanded(
                child: Row(
                  children: [
                    _buildTimelinePhaseCard(
                      title: 'پایان پریود',
                      duration: '$daysUntilPeriodEnd روز دیگر',
                      icon: CupertinoIcons.drop_fill,
                      color: const Color(0xFFEB6E60),
                      isDark: isDark,
                    ),
                    const SizedBox(width: 6),
                    _buildTimelinePhaseCard(
                      title: 'فاز فولیکولی',
                      duration: '$follicularDays روز',
                      icon: CupertinoIcons.leaf_arrow_circlepath,
                      color: const Color(0xFF38AA84),
                      isDark: isDark,
                    ),
                    const SizedBox(width: 6),
                    _buildTimelinePhaseCard(
                      title: 'تخمک‌گذاری',
                      duration: '۲ روز',
                      icon: CupertinoIcons.sparkles,
                      color: const Color(0xFFE88A2E),
                      isDark: isDark,
                    ),
                    const SizedBox(width: 6),
                    _buildTimelinePhaseCard(
                      title: 'فاز لوتئال',
                      duration: '$lutealDays روز',
                      icon: CupertinoIcons.moon_fill,
                      color: const Color(0xFFC752A8),
                      isDark: isDark,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // خط تایم‌لاین با نقاط متناظر
              _buildConnectingTimelineBar(
                isDark: isDark,
                periodDur: periodDur,
                ovulationDay: ovulationDay,
                cycleLen: cycleLen,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimelinePhaseCard({
    required String title,
    required String duration,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.18 : 0.10),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withValues(alpha: isDark ? 0.35 : 0.22),
            width: 0.9,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 9.2,
                fontWeight: FontWeight.w600,
                color: isDark ? color : Color.lerp(color, Colors.black, 0.3),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              PersianDigits.toFa(duration),
              style: TextStyle(
                fontSize: 11.2,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF1D2129),
              ),
            ),
            const SizedBox(height: 3),
            Icon(icon, size: 15, color: color),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectingTimelineBar({
    required bool isDark,
    required int periodDur,
    required int ovulationDay,
    required int cycleLen,
  }) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              height: 2.5,
              width: double.infinity,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2C323D) : const Color(0xFFD6DCE5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildDot(const Color(0xFFEB6E60)),
                _buildDot(const Color(0xFF38AA84)),
                _buildDot(const Color(0xFFE88A2E)),
                _buildDot(const Color(0xFFC752A8)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 3),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Text(
              PersianDigits.toFa('روز $periodDur'),
              style: TextStyle(
                fontSize: 9.0,
                color: isDark ? const Color(0xFF8E95A2) : const Color(0xFF7A828E),
              ),
            ),
            Text(
              PersianDigits.toFa('روز $ovulationDay'),
              style: TextStyle(
                fontSize: 9.0,
                color: isDark ? const Color(0xFF8E95A2) : const Color(0xFF7A828E),
              ),
            ),
            Text(
              PersianDigits.toFa('روز ${ovulationDay + 2}'),
              style: TextStyle(
                fontSize: 9.0,
                color: isDark ? const Color(0xFF8E95A2) : const Color(0xFF7A828E),
              ),
            ),
            Text(
              PersianDigits.toFa('روز $cycleLen'),
              style: TextStyle(
                fontSize: 9.0,
                color: isDark ? const Color(0xFF8E95A2) : const Color(0xFF7A828E),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDot(Color color) {
    return Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.6),
            blurRadius: 4,
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // اسلاید ۳: توصیه‌های امروز (کلیک -> باز شدن تسکین درد SOS)
  // ---------------------------------------------------------------------------
  Widget _buildSlide3Recommendations({
    required BuildContext context,
    required bool isCompact,
    required RitmoMetrics m,
    required bool isDark,
    required Color phaseColor,
  }) {
    final List<_CareTipItem> tips = _getPhaseRecommendations(widget.phase);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onCareTipsTap,
        borderRadius: BorderRadius.circular(34),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            16 * m.densityFactor,
            12 * m.densityFactor,
            16 * m.densityFactor,
            20 * m.densityFactor,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'توصیه‌های امروز',
                    style: TextStyle(
                      fontSize: isCompact ? 15 : 17,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : const Color(0xFF1D2129),
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    _getPhaseSubtitle(widget.phase),
                    style: TextStyle(
                      fontSize: 10.5,
                      color: isDark ? const Color(0xFF9096A2) : const Color(0xFF7A828E),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // ۴ کارت توصیه (۲×۲)
              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildTipCard(
                              item: tips[0],
                              isDark: isDark,
                              phaseColor: phaseColor,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildTipCard(
                              item: tips[1],
                              isDark: isDark,
                              phaseColor: phaseColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildTipCard(
                              item: tips[2],
                              isDark: isDark,
                              phaseColor: phaseColor,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildTipCard(
                              item: tips[3],
                              isDark: isDark,
                              phaseColor: phaseColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTipCard({
    required _CareTipItem item,
    required bool isDark,
    required Color phaseColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF191B20) : Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.white,
          width: 0.8,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: phaseColor.withValues(alpha: isDark ? 0.20 : 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(item.icon, size: 14, color: phaseColor),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              item.text,
              style: TextStyle(
                fontSize: 10.2,
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFFE2E6EE) : const Color(0xFF2C323D),
                height: 1.25,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _getPhaseSubtitle(CyclePhase phase) {
    switch (phase) {
      case CyclePhase.menstrual:
        return 'برای احساس بهتر در دوران پریود (مشاهده راهکارهای تسکین درد)';
      case CyclePhase.follicular:
        return 'برای بهره‌وری و رشد در فاز فولیکولار (مشاهده راهکارها)';
      case CyclePhase.ovulation:
        return 'برای اوج نشاط و مراقبت در تخمک‌گذاری (مشاهده راهکارها)';
      case CyclePhase.luteal:
        return 'برای آرامش و تعادل در فاز لوتئال (مشاهده راهکارها)';
      case CyclePhase.pregnancy:
        return 'توصیه‌های سلامت و آرامش در بارداری (مشاهده راهکارها)';
      case CyclePhase.dataStale:
      case CyclePhase.noData:
        return 'توصیه‌های خود‌مراقبتی و هماهنگی بدن (مشاهده راهکارها)';
    }
  }

  List<_CareTipItem> _getPhaseRecommendations(CyclePhase phase) {
    switch (phase) {
      case CyclePhase.menstrual:
        return const [
          _CareTipItem(icon: CupertinoIcons.bed_double_fill, text: 'استراحت کافی و خواب باکیفیت'),
          _CareTipItem(icon: Icons.local_cafe_rounded, text: 'نوشیدن آب ولرم و دمنوش‌های گیاهی'),
          _CareTipItem(icon: CupertinoIcons.heart_fill, text: 'مصرف غذاهای سبک و مقوی'),
          _CareTipItem(icon: CupertinoIcons.flame_fill, text: 'استفاده از گرم‌کننده برای کاهش درد'),
        ];
      case CyclePhase.follicular:
        return const [
          _CareTipItem(icon: CupertinoIcons.bolt_fill, text: 'بهره‌گیری از افزایش تمرکز و انگیزه'),
          _CareTipItem(icon: CupertinoIcons.leaf_arrow_circlepath, text: 'مصرف پروتئین و سبزیجات تازه'),
          _CareTipItem(icon: CupertinoIcons.sportscourt_fill, text: 'انجام ورزش‌های هوازی و کاردیو'),
          _CareTipItem(icon: CupertinoIcons.drop_fill, text: 'نوشیدن آب کافی و اسموتی‌های مغذی'),
        ];
      case CyclePhase.ovulation:
        return const [
          _CareTipItem(icon: CupertinoIcons.flame_fill, text: 'ورزش‌های قدرتی و چالش عضلات'),
          _CareTipItem(icon: CupertinoIcons.sparkles, text: 'برنامه‌ریزی جلسات و کارهای تیمی'),
          _CareTipItem(icon: CupertinoIcons.heart_fill, text: 'مصرف فیبر بالا و چربی‌های سالم'),
          _CareTipItem(icon: CupertinoIcons.sun_max_fill, text: 'پیاده‌روی پرانرژی و هوای آزاد'),
        ];
      case CyclePhase.luteal:
        return const [
          _CareTipItem(icon: CupertinoIcons.moon_fill, text: 'یوگای ملایم و پیاده‌روی آرام‌بخش'),
          _CareTipItem(icon: CupertinoIcons.circle_grid_hex_fill, text: 'کاهش مصرف نمک و قندهای تصفیه‌شده'),
          _CareTipItem(icon: Icons.local_cafe_rounded, text: 'دمنوش بابونه و اسطوخودوس'),
          _CareTipItem(icon: CupertinoIcons.bed_double_fill, text: 'تنظیم ساعت خواب و استراحت شبانه'),
        ];
      case CyclePhase.pregnancy:
      case CyclePhase.dataStale:
      case CyclePhase.noData:
        return const [
          _CareTipItem(icon: CupertinoIcons.heart_fill, text: 'خواب منظم و استراحت متناوب'),
          _CareTipItem(icon: CupertinoIcons.drop_fill, text: 'هیدراتاسیون مداوم در طول روز'),
          _CareTipItem(icon: CupertinoIcons.leaf_arrow_circlepath, text: 'رژیم غذایی غنی از آهن و املاح'),
          _CareTipItem(icon: CupertinoIcons.sparkles, text: 'حرکات کششی و تنفس عمیق'),
        ];
    }
  }

  // ---------------------------------------------------------------------------
  // دیال نئومورفیک
  // ---------------------------------------------------------------------------
  Widget _buildNeumorphicAcrylicDial({
    required BuildContext context,
    required double dialSize,
    required double targetProgress,
    required Color phaseColor,
    required int currentDay,
    required bool isDark,
    required CyclePhase phase,
  }) {
    final outerRingSize = dialSize;
    final innerDiscSize = dialSize * 0.62;

    return SizedBox(
      height: outerRingSize,
      width: outerRingSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            height: outerRingSize,
            width: outerRingSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark ? const Color(0xFF181B20) : const Color(0xFFE8EBF0),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.85)
                      : const Color(0xFFB5C0CD).withValues(alpha: 0.85),
                  offset: const Offset(3.5, 3.5),
                  blurRadius: 7,
                ),
                BoxShadow(
                  color: isDark ? const Color(0xFF282D36) : Colors.white,
                  offset: const Offset(-3.5, -3.5),
                  blurRadius: 7,
                ),
              ],
            ),
          ),
          SizedBox(
            height: outerRingSize,
            width: outerRingSize,
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.0, end: targetProgress),
              duration: const Duration(milliseconds: 1200),
              curve: Curves.easeOutCubic,
              builder: (context, animValue, child) {
                return CustomPaint(
                  painter: _NeumorphicGlowRingPainter(
                    percentage: animValue,
                    activeColor: phaseColor,
                    isDark: isDark,
                  ),
                );
              },
            ),
          ),
          Container(
            height: innerDiscSize,
            width: innerDiscSize,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF20242B) : const Color(0xFFF3F5F8),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.65)
                      : const Color(0xFFA8B5C4).withValues(alpha: 0.55),
                  offset: const Offset(4, 4),
                  blurRadius: 8,
                ),
                BoxShadow(
                  color: isDark ? const Color(0xFF2D333D) : Colors.white,
                  offset: const Offset(-4, -4),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    phase == CyclePhase.menstrual ? 'روز پریود' : 'روز چرخه',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xFF9096A2) : const Color(0xFF7A828E),
                    ),
                  ),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        PersianDigits.toFa(currentDay.toString()),
                        style: TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.w900,
                          color: phaseColor,
                          height: 1.15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomStatusDots({
    required int activeIndex,
    required Color phaseColor,
    required bool isDark,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (index) {
        final isActive = index == activeIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 3.5),
          width: isActive ? 7.5 : 5.5,
          height: isActive ? 7.5 : 5.5,
          decoration: BoxDecoration(
            color: isActive
                ? phaseColor
                : (isDark ? const Color(0xFF383E4A) : const Color(0xFFCBD2DC)),
            shape: BoxShape.circle,
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: phaseColor.withValues(alpha: 0.8),
                      blurRadius: 8,
                      spreadRadius: 1.5,
                    ),
                  ]
                : null,
          ),
        );
      }),
    );
  }
}

class _CareTipItem {
  const _CareTipItem({required this.icon, required this.text});
  final IconData icon;
  final String text;
}

class _NeumorphicGlowRingPainter extends CustomPainter {
  _NeumorphicGlowRingPainter({
    required this.percentage,
    required this.activeColor,
    required this.isDark,
  });

  final double percentage;
  final Color activeColor;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 8;
    const strokeWidth = 12.0;

    final glassTrackPaint = Paint()
      ..color = isDark
          ? Colors.white.withValues(alpha: 0.06)
          : Colors.white.withValues(alpha: 0.65)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, glassTrackPaint);

    if (percentage <= 0) return;

    final rect = Rect.fromCircle(center: center, radius: radius);
    final sweepAngle = 2 * math.pi * percentage;

    final jellyArcPaint = Paint()
      ..shader = SweepGradient(
        colors: [
          activeColor.withValues(alpha: 0.35),
          activeColor.withValues(alpha: 0.75),
          activeColor,
        ],
        stops: const [0.0, 0.5, 1.0],
        transform: const GradientRotation(-math.pi / 2),
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth;

    canvas.drawArc(rect, -math.pi / 2, sweepAngle, false, jellyArcPaint);

    final thumbAngle = -math.pi / 2 + sweepAngle;
    final thumbX = center.dx + radius * math.cos(thumbAngle);
    final thumbY = center.dy + radius * math.sin(thumbAngle);
    final thumbCenter = Offset(thumbX, thumbY);

    final outerGlowPaint = Paint()
      ..color = activeColor.withValues(alpha: 0.85)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(thumbCenter, 9, outerGlowPaint);

    final whiteCorePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(thumbCenter, 5.0, whiteCorePaint);

    final innerDotPaint = Paint()
      ..color = activeColor.withValues(alpha: 0.85)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(thumbCenter, 2.2, innerDotPaint);
  }

  @override
  bool shouldRepaint(covariant _NeumorphicGlowRingPainter oldDelegate) {
    return oldDelegate.percentage != percentage ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.isDark != isDark;
  }
}
