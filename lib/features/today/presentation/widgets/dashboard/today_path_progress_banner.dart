import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/agenda/models/day_agenda_snapshot.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/ux/ritmo_haptics.dart';
import 'package:ritmo/features/calendar/presentation/logic/today_calendar_convergence_helper.dart';

/// بنر اختصاصی و پریمیوم «مسیر امروز» به همراه قابلیت گسترش کشویی (Expandable)
///
/// این ویجت در بالای صفحهٔ خانه قرار می‌گیرد و علاوه بر نمایش نسبت پیشرفت روز و درصد،
/// با لمس فلش کوچک گسترش یافته و جزئیات کارهای «اکنون»، «بعدی»، «سپس» یا بازهٔ وقت آزاد
/// همراه با دکمه‌های تعاملی و عملیاتی «شروع زودهنگام» و «جبران کارهای جامانده» را نمایش می‌دهد.
class TodayPathProgressBanner extends StatefulWidget {
  const TodayPathProgressBanner({
    super.key,
    required this.progress,
    required this.doneCount,
    required this.totalCount,
    required this.remainingCount,
    this.snapshot,
    this.initiallyExpanded = false,
    this.onTap,
    this.onOpenAgendaItem,
    this.convergenceHelper,
  });

  /// نسبت پیشرفت از ۰٫۰ تا ۱٫۰
  final double progress;

  /// تعداد کارهای انجام‌شده
  final int doneCount;

  /// تعداد کل کارهای برنامه‌ریزی‌شده
  final int totalCount;

  /// تعداد کارهای باقیمانده
  final int remainingCount;

  /// اسنپشات برنامهٔ امروز (شامل فعالیت جاری، بعدی، سپس و پیشنهادات)
  final DayAgendaSnapshot? snapshot;

  /// وضعیت اولیهٔ گسترش پنجره
  final bool initiallyExpanded;

  /// اکشن اختیاری هنگام لمس کارت (در صورت نبود اسنپشات)
  final VoidCallback? onTap;

  /// کالبک باز کردن و ثبت نیت/شروع یک آیتم برنامه در صفحهٔ خانه
  final void Function(AgendaItem item)? onOpenAgendaItem;

  /// هلپر همگرایی با تقویم
  final TodayCalendarConvergenceHelper? convergenceHelper;

  @override
  State<TodayPathProgressBanner> createState() =>
      _TodayPathProgressBannerState();
}

class _TodayPathProgressBannerState extends State<TodayPathProgressBanner> {
  late bool _isExpanded;
  late final TodayCalendarConvergenceHelper _convergenceHelper;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
    _convergenceHelper =
        widget.convergenceHelper ?? TodayCalendarConvergenceHelper();
  }

  void _toggleExpanded() {
    RitmoHaptics.selection();
    setState(() {
      _isExpanded = !_isExpanded;
    });
  }

  void _handleItemTap(AgendaItem item) {
    RitmoHaptics.tap();
    if (widget.onOpenAgendaItem != null) {
      widget.onOpenAgendaItem!(item);
    } else {
      _convergenceHelper.openCalendarInContext(context, itemId: item.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final clamped = widget.progress.clamp(0.0, 1.0).toDouble();
    final percent = (clamped * 100).round();
    final isCompleted = clamped >= 1.0 && widget.totalCount > 0;

    final accentColor = isCompleted ? colors.success : colors.primary;
    final radius = BorderRadius.circular(RitmoRadius.cardLarge);

    final content = AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOutCubic,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
            horizontal: RitmoSpacing.md + 2, vertical: RitmoSpacing.md),
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [
              accentColor.withValues(alpha: isDark ? 0.22 : 0.12),
              (isDark ? colors.card : Colors.white)
                  .withValues(alpha: isDark ? 0.65 : 0.90),
            ],
          ),
          border: Border.all(
            color: accentColor.withValues(alpha: isDark ? 0.32 : 0.22),
            width: 1.1,
          ),
          boxShadow: [
            BoxShadow(
              color: accentColor.withValues(alpha: isDark ? 0.12 : 0.08),
              blurRadius: 18,
              spreadRadius: -6,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ردیف بالایی: عنوان مسیر، نشانگر درصد، تگ وضعیت و دکمه بازشو
            _buildHeader(
              context,
              colors,
              accentColor,
              percent,
              isCompleted,
              isDark,
            ),

            const SizedBox(height: 10),

            // نوار پیشرفت چندلایه با انیمیشن روان و مارکرهای مرحله‌ای
            _buildProgressBar(context, colors, accentColor, clamped, isDark),

            // ردیف اطلاعاتی زیرین (خلاصهٔ آماری سریع)
            if (widget.totalCount > 0) ...[
              const SizedBox(height: 7),
              Row(
                children: [
                  Text(
                    toPersianDigits(
                        '${widget.doneCount} از ${widget.totalCount} مورد تکمیل شده'),
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: colors.textTertiary,
                    ),
                  ),
                  const Spacer(),
                  if (!isCompleted && widget.remainingCount > 0)
                    Text(
                      'گام‌به‌گام تا پایان روز',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: colors.textTertiary.withValues(alpha: 0.8),
                      ),
                    ),
                ],
              ),
            ],

            // بخش گسترش‌یافته: جزئیات کارهای مسیر امروز (اکنون، بعدی، سپس / وقت آزاد)
            if (_isExpanded)
              _buildExpandedDetails(context, colors, accentColor, isDark),
          ],
        ),
      ),
    );

    return Semantics(
      container: true,
      label:
          'پیشرفت مسیر امروز: $percent درصد، ${widget.remainingCount} مورد باقی‌مانده از ${widget.totalCount}',
      child: content,
    );
  }

  Widget _buildHeader(
    BuildContext context,
    RitmoColors colors,
    Color accentColor,
    int percent,
    bool isCompleted,
    bool isDark,
  ) {
    final hasDetails = widget.snapshot != null;

    return InkWell(
      onTap: hasDetails ? _toggleExpanded : widget.onTap,
      borderRadius: BorderRadius.circular(RitmoRadius.badge + 2),
      child: Row(
        children: [
          // آیکون شاخص
          Container(
            height: 28,
            width: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(RitmoRadius.badge + 1),
              border: Border.all(
                color: accentColor.withValues(alpha: 0.28),
                width: 0.8,
              ),
            ),
            child: Icon(
              isCompleted
                  ? CupertinoIcons.sparkles
                  : CupertinoIcons.compass_fill,
              size: 15,
              color: accentColor,
            ),
          ),
          const SizedBox(width: 8),

          // عنوان
          Text(
            'مسیر امروز',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(width: 8),

          // چیپ نشان‌دهندهٔ درصد
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(RitmoRadius.pill),
              border: Border.all(
                color: accentColor.withValues(alpha: 0.26),
                width: 0.8,
              ),
            ),
            child: Text(
              toPersianDigits('$percent٪'),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: accentColor,
              ),
            ),
          ),

          const Spacer(),

          // برچسب وضعیت (تعداد باقیمانده یا پیام تکمیل)
          if (isCompleted) ...[
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  CupertinoIcons.checkmark_seal_fill,
                  size: 13.5,
                  color: colors.success,
                ),
                const SizedBox(width: 4),
                Text(
                  'مسیر امروز کامل شد',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: colors.success,
                  ),
                ),
              ],
            ),
          ] else if (widget.totalCount > 0) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
              decoration: BoxDecoration(
                color: (isDark ? Colors.white : Colors.black)
                    .withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(RitmoRadius.pill),
                border: Border.all(
                  color: colors.border.withValues(alpha: 0.4),
                  width: 0.7,
                ),
              ),
              child: Text(
                toPersianDigits('${widget.remainingCount} مورد باقی‌مانده'),
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: colors.textSecondary,
                ),
              ),
            ),
          ] else ...[
            Text(
              'آغاز ریتم روز',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: colors.textTertiary,
              ),
            ),
          ],

          if (hasDetails) ...[
            const SizedBox(width: 6),
            // دکمه فلش چرخان برای باز و بسته کردن جزئیات مسیر
            AnimatedRotation(
              turns: _isExpanded ? 0.5 : 0.0,
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeInOutCubic,
              child: Container(
                height: 24,
                width: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  CupertinoIcons.chevron_down,
                  size: 12,
                  color: accentColor,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProgressBar(
    BuildContext context,
    RitmoColors colors,
    Color accentColor,
    double targetValue,
    bool isDark,
  ) {
    const double barHeight = 8.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;

        return TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0.0, end: targetValue),
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutCubic,
          builder: (context, animValue, _) {
            final fillWidth = (totalWidth * animValue).clamp(0.0, totalWidth);

            return Stack(
              clipBehavior: Clip.none,
              children: [
                // ۱. ترک پس‌زمینه
                Container(
                  height: barHeight,
                  width: totalWidth,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: isDark ? 0.15 : 0.10),
                    borderRadius: BorderRadius.circular(RitmoRadius.pill),
                  ),
                ),

                // ۲. نشانگرهای مرحله‌ای (Milestones در ۲۵٪، ۵۰٪، ۷۵٪)
                Positioned.fill(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _milestoneDot(accentColor, animValue >= 0.25),
                      _milestoneDot(accentColor, animValue >= 0.50),
                      _milestoneDot(accentColor, animValue >= 0.75),
                    ],
                  ),
                ),

                // ۳. نوار پر شده با گرادیان درخشان
                if (fillWidth > 0)
                  Container(
                    height: barHeight,
                    width: fillWidth,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(RitmoRadius.pill),
                      gradient: LinearGradient(
                        colors: [
                          accentColor,
                          accentColor.withValues(alpha: 0.85),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: accentColor.withValues(alpha: 0.35),
                          blurRadius: 6,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _milestoneDot(Color color, bool reached) {
    return Container(
      width: 3.5,
      height: 3.5,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: reached
            ? Colors.white.withValues(alpha: 0.8)
            : color.withValues(alpha: 0.3),
      ),
    );
  }

  Widget _buildExpandedDetails(
    BuildContext context,
    RitmoColors colors,
    Color accentColor,
    bool isDark,
  ) {
    final snapshot = widget.snapshot;
    if (snapshot == null) return const SizedBox.shrink();

    final current = snapshot.currentActivity;
    final next = snapshot.nextActivity;
    var afterNext = snapshot.afterNextActivity;

    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;

    // پیدا کردن کارهای گذشتهٔ انجام‌نشده (Overdue Backlog)
    final overdueItems = snapshot.items
        .where((i) =>
            i.isTimed &&
            !i.isCompleted &&
            _parseMinutes(i.timeOfDay) < currentMinutes &&
            i.id != current?.id &&
            i.id != next?.id)
        .toList();

    // Fallback: در صورتی که afterNext در اسنپشات نبود، از روی آیتم‌های زمان‌بندی‌شده استخراج می‌شود
    if (afterNext == null && snapshot.items.isNotEmpty) {
      final timedItems = snapshot.items
          .where((i) => i.isTimed && !i.isCompleted)
          .toList()
        ..sort((a, b) {
          final aM = _parseMinutes(a.timeOfDay);
          final bM = _parseMinutes(b.timeOfDay);
          return aM.compareTo(bM);
        });
      for (final item in timedItems) {
        if (item.id != current?.id && item.id != next?.id) {
          afterNext = item;
          break;
        }
      }
    }

    final topSuggestion =
        snapshot.suggestions.isNotEmpty ? snapshot.suggestions.first : null;
    final isEmpty = current == null &&
        next == null &&
        afterNext == null &&
        topSuggestion == null &&
        overdueItems.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 10),
        Container(
          height: 1,
          width: double.infinity,
          color: accentColor.withValues(alpha: isDark ? 0.20 : 0.14),
        ),
        const SizedBox(height: 10),
        if (isEmpty)
          _buildEmptyState(context, colors)
        else ...[
          // ۱. کار جاری (اگر وجود دارد) یا بازهٔ وقت آزاد و استراحت (اگر کار زودتر تمام شده است)
          if (current != null)
            _buildTimelineRow(
              context,
              colors,
              item: current,
              label: 'اکنون',
              labelColor: colors.primary,
              isNow: true,
              hasConnector: next != null || afterNext != null,
            )
          else if (next != null)
            _buildFreeGapRow(
              context,
              colors,
              next: next,
              overdueItems: overdueItems,
              hasConnector: true,
            ),

          // ۲. کار بعدی
          if (next != null)
            _buildTimelineRow(
              context,
              colors,
              item: next,
              label: 'بعدی',
              labelColor: colors.textSecondary,
              isNow: false,
              hasConnector: afterNext != null,
            ),

          // ۳. کار سپس
          if (afterNext != null)
            _buildTimelineRow(
              context,
              colors,
              item: afterNext,
              label: 'سپس',
              labelColor: colors.textTertiary,
              isNow: false,
              hasConnector: false,
            ),

          // ۴. پیشنهاد هوشمند
          if (topSuggestion != null) ...[
            if (current != null || next != null || afterNext != null)
              const SizedBox(height: RitmoSpacing.sm),
            _buildSuggestionBanner(context, colors, topSuggestion.message),
          ],
        ],
      ],
    );
  }

  static int _parseMinutes(String? timeOfDay) {
    if (timeOfDay == null || timeOfDay.isEmpty) return 0;
    final parts = timeOfDay.split(':');
    if (parts.length != 2) return 0;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    return h * 60 + m;
  }

  Widget _buildFreeGapRow(
    BuildContext context,
    RitmoColors colors, {
    required AgendaItem next,
    required List<AgendaItem> overdueItems,
    required bool hasConnector,
  }) {
    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;
    final nextMinutes = _parseMinutes(next.timeOfDay);
    final gapMinutes = (nextMinutes - currentMinutes).clamp(1, 1440);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ریل خط زمانی
          SizedBox(
            width: 20,
            child: Column(
              children: [
                const SizedBox(height: 7),
                Container(
                  height: 11,
                  width: 11,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.accent,
                    boxShadow: [
                      BoxShadow(
                        color: colors.accent.withValues(alpha: 0.40),
                        blurRadius: 6,
                        spreadRadius: 1.5,
                      ),
                    ],
                  ),
                ),
                if (hasConnector)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      decoration: BoxDecoration(
                        color: colors.border.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(RitmoRadius.pill),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // محتوای کارت وقت آزاد
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: hasConnector ? 10 : 0),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (isDark ? Colors.black : Colors.white)
                      .withValues(alpha: isDark ? 0.35 : 0.65),
                  borderRadius: BorderRadius.circular(RitmoRadius.card),
                  border: Border.all(
                    color: colors.accent.withValues(alpha: isDark ? 0.28 : 0.18),
                    width: 0.9,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // برچسب بالایی
                    Row(
                      children: [
                        Text(
                          'اکنون',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: colors.accent,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          height: 3,
                          width: 3,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: colors.textTertiary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          toPersianDigits('$gapMinutes دقیقه زمان آزاد'),
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: colors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // عنوان
                    Text(
                      'وقت آزاد و استراحت تا ${toPersianDigits(next.timeOfDay ?? '')}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // ۱. کارت شروع زودهنگام کار بعدی
                    _buildEarlyStartCard(
                      context,
                      colors,
                      next: next,
                      isDark: isDark,
                    ),

                    // ۲. کارت جبران کارهای گذشته که تیک نخورده‌اند
                    if (overdueItems.isNotEmpty) ...[
                      const SizedBox(height: 7),
                      _buildCatchUpCard(
                        context,
                        colors,
                        overdueItems: overdueItems,
                        isDark: isDark,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// کارت اکشن تعاملی و پرمیوم «شروع زودهنگام»
  Widget _buildEarlyStartCard(
    BuildContext context,
    RitmoColors colors, {
    required AgendaItem next,
    required bool isDark,
  }) {
    final startColor = colors.primary;
    return Semantics(
      button: true,
      label: 'شروع زودهنگام: ${next.title}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(RitmoRadius.chip),
          onTap: () => _handleItemTap(next),
          splashColor: startColor.withValues(alpha: 0.15),
          highlightColor: startColor.withValues(alpha: 0.08),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7.5),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: isDark
                    ? [
                        startColor.withValues(alpha: 0.16),
                        startColor.withValues(alpha: 0.06),
                      ]
                    : [
                        startColor.withValues(alpha: 0.10),
                        startColor.withValues(alpha: 0.03),
                      ],
              ),
              borderRadius: BorderRadius.circular(RitmoRadius.chip),
              border: Border.all(
                color: startColor.withValues(alpha: isDark ? 0.32 : 0.22),
                width: 0.9,
              ),
              boxShadow: [
                BoxShadow(
                  color: startColor.withValues(alpha: isDark ? 0.08 : 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // آیکون بج با پس‌زمینهٔ هماهنگ و آیکون توپر
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: startColor.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(
                      color: startColor.withValues(alpha: 0.25),
                      width: 0.8,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      CupertinoIcons.play_arrow_solid,
                      size: 12.5,
                      color: startColor,
                    ),
                  ),
                ),
                const SizedBox(width: 9),

                // متن ۲ ردیفه: کیکر «شروع زودهنگام» + عنوان کار
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Text(
                            'شروع زودهنگام',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: startColor,
                              letterSpacing: -0.2,
                            ),
                          ),
                          if (next.timeOfDay != null &&
                              next.timeOfDay!.isNotEmpty) ...[
                            const SizedBox(width: 5),
                            Text(
                              '• موعد: ${toPersianDigits(next.timeOfDay)}',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w500,
                                color: colors.textTertiary,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        toPersianDigits(next.title),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // دکمه اقدام سریع پرمیوم
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8.5, vertical: 4),
                  decoration: BoxDecoration(
                    color: startColor,
                    borderRadius: BorderRadius.circular(RitmoRadius.pill),
                    boxShadow: [
                      BoxShadow(
                        color: startColor.withValues(alpha: 0.35),
                        blurRadius: 5,
                        offset: const Offset(0, 1.5),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'شروع',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.2,
                        ),
                      ),
                      SizedBox(width: 3),
                      Icon(
                        CupertinoIcons.chevron_left,
                        size: 9.5,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// کارت اکشن تعاملی و پرمیوم «جبران کارهای جامانده»
  Widget _buildCatchUpCard(
    BuildContext context,
    RitmoColors colors, {
    required List<AgendaItem> overdueItems,
    required bool isDark,
  }) {
    if (overdueItems.isEmpty) return const SizedBox.shrink();
    final firstItem = overdueItems.first;
    final warningColor = colors.warning;
    final otherCount = overdueItems.length - 1;

    return Semantics(
      button: true,
      label: 'جبران کار جامانده: ${firstItem.title}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(RitmoRadius.chip),
          onTap: () => _handleItemTap(firstItem),
          splashColor: warningColor.withValues(alpha: 0.15),
          highlightColor: warningColor.withValues(alpha: 0.08),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7.5),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: isDark
                    ? [
                        warningColor.withValues(alpha: 0.16),
                        warningColor.withValues(alpha: 0.06),
                      ]
                    : [
                        warningColor.withValues(alpha: 0.10),
                        warningColor.withValues(alpha: 0.03),
                      ],
              ),
              borderRadius: BorderRadius.circular(RitmoRadius.chip),
              border: Border.all(
                color: warningColor.withValues(alpha: isDark ? 0.32 : 0.22),
                width: 0.9,
              ),
              boxShadow: [
                BoxShadow(
                  color: warningColor.withValues(alpha: isDark ? 0.08 : 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // آیکون بج با پس‌زمینهٔ هماهنگ و آیکون بازگشت
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: warningColor.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(
                      color: warningColor.withValues(alpha: 0.25),
                      width: 0.8,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      CupertinoIcons.arrow_counterclockwise,
                      size: 13,
                      color: warningColor,
                    ),
                  ),
                ),
                const SizedBox(width: 9),

                // متن ۲ ردیفه: کیکر «جبران برنامهٔ جامانده» + عنوان کار
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Text(
                            'جبران کار جامانده',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: warningColor,
                              letterSpacing: -0.2,
                            ),
                          ),
                          if (otherCount > 0) ...[
                            const SizedBox(width: 5),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: warningColor.withValues(alpha: 0.2),
                                borderRadius:
                                    BorderRadius.circular(RitmoRadius.pill),
                              ),
                              child: Text(
                                '+${toPersianDigits(otherCount.toString())}',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: warningColor,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        toPersianDigits(firstItem.title),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // دکمه اقدام سریع پرمیوم
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8.5, vertical: 4),
                  decoration: BoxDecoration(
                    color: warningColor,
                    borderRadius: BorderRadius.circular(RitmoRadius.pill),
                    boxShadow: [
                      BoxShadow(
                        color: warningColor.withValues(alpha: 0.35),
                        blurRadius: 5,
                        offset: const Offset(0, 1.5),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'جبران',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.2,
                        ),
                      ),
                      SizedBox(width: 3),
                      Icon(
                        CupertinoIcons.chevron_left,
                        size: 9.5,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimelineRow(
    BuildContext context,
    RitmoColors colors, {
    required AgendaItem item,
    required String label,
    required Color labelColor,
    required bool isNow,
    required bool hasConnector,
  }) {
    final timeParts = <String>[
      if (item.timeOfDay != null) 'ساعت ${toPersianDigits(item.timeOfDay)}',
      if (isNow && item.durationMinutes != null)
        '${toPersianDigits(item.durationMinutes.toString())} دقیقه',
    ];

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ریل خط زمانی
          SizedBox(
            width: 20,
            child: Column(
              children: [
                const SizedBox(height: 7),
                _buildTimelineDot(colors, isNow: isNow),
                if (hasConnector)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      decoration: BoxDecoration(
                        color: colors.border.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(RitmoRadius.pill),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // محتوای کار
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: hasConnector ? 10 : 0),
              child: Material(
                color: isNow
                    ? colors.primary.withValues(alpha: 0.08)
                    : colors.textPrimary.withValues(alpha: 0.035),
                borderRadius: BorderRadius.circular(RitmoRadius.chip),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => _handleItemTap(item),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    label,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.2,
                                      color: labelColor,
                                    ),
                                  ),
                                  if (timeParts.isNotEmpty) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      height: 3,
                                      width: 3,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: colors.textTertiary,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        timeParts.join(' · '),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          color: colors.textTertiary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                toPersianDigits(item.title),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: colors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isNow && item.domain == AgendaDomain.routine) ...[
                          const SizedBox(width: RitmoSpacing.sm),
                          Semantics(
                            button: true,
                            label: 'تکمیل برنامه',
                            child: Material(
                              color: colors.success.withValues(alpha: 0.14),
                              shape: const CircleBorder(),
                              clipBehavior: Clip.antiAlias,
                              child: InkWell(
                                onTap: () {
                                  RitmoHaptics.confirm();
                                  _convergenceHelper.completeItem(item);
                                },
                                child: SizedBox(
                                  height: 32,
                                  width: 32,
                                  child: Icon(
                                    CupertinoIcons.checkmark_alt,
                                    size: 16,
                                    color: colors.success,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ] else ...[
                          const SizedBox(width: RitmoSpacing.xs),
                          Icon(
                            CupertinoIcons.chevron_left,
                            size: 12,
                            color: colors.textTertiary,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineDot(RitmoColors colors, {required bool isNow}) {
    if (isNow) {
      return Container(
        height: 11,
        width: 11,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: colors.primary,
          boxShadow: [
            BoxShadow(
              color: colors.primary.withValues(alpha: 0.35),
              blurRadius: 6,
              spreadRadius: 1.5,
            ),
          ],
        ),
      );
    }
    return Container(
      height: 11,
      width: 11,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colors.card,
        border: Border.all(color: colors.textTertiary, width: 1.8),
      ),
    );
  }

  Widget _buildSuggestionBanner(
    BuildContext context,
    RitmoColors colors,
    String message,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: colors.goldAccent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(RitmoRadius.chip),
        border: Border.all(
          color: colors.goldAccent.withValues(alpha: 0.22),
          width: 0.8,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            CupertinoIcons.lightbulb_fill,
            size: 13,
            color: colors.goldAccent,
          ),
          const SizedBox(width: RitmoSpacing.sm),
          Expanded(
            child: Text(
              toPersianDigits(message),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                height: 1.45,
                color: colors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, RitmoColors colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            height: 32,
            width: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.success.withValues(alpha: 0.12),
            ),
            child: Icon(
              CupertinoIcons.checkmark_seal_fill,
              size: 16,
              color: colors.success,
            ),
          ),
          const SizedBox(width: RitmoSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'مسیر امروز خلوت است',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  'برنامهٔ فعالی برای این ساعت باقی نمانده است.',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
