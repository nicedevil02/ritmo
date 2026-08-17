// C-43, C-44: PregnancyProgressTab
import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/cycle/presentation/widgets/labor_mode_screen.dart';
import 'package:ritmo/features/cycle/presentation/widgets/pregnancy/pregnancy_ring_painter.dart';
import 'package:ritmo/features/cycle/presentation/widgets/pregnancy_today_card.dart';
import 'package:ritmo/features/health/data/pregnancy_helpers.dart';
import 'package:ritmo/features/health/data/pregnancy_repository.dart';
import 'package:ritmo/features/health/data/pregnancy_week_data.dart';

class PregnancyProgressTab extends StatelessWidget {
  const PregnancyProgressTab({
    super.key,
    required this.diffDays,
    required this.currentWeek,
    required this.currentDayInWeek,
    required this.progressPercent,
    required this.selectedSymptoms,
    required this.kickCount,
    required this.hospitalBagItems,
    required this.onNavigateTab,
    required this.onOpenAssistant,
    required this.onToggleHospitalBagItem,
  });

  final int diffDays;
  final int currentWeek;
  final int currentDayInWeek;
  final double progressPercent;
  final List<String> selectedSymptoms;
  final int kickCount;
  final List<Map<String, dynamic>> hospitalBagItems;
  final ValueChanged<int> onNavigateTab;
  final VoidCallback onOpenAssistant;
  final void Function(int index, bool done) onToggleHospitalBagItem;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final ga = GestationalAge.fromDays(diffDays);
    final weekInfo = pregnancyWeekData[currentWeek.clamp(1, 40)];

    final babySize = weekInfo?.babySizeFa ?? weekInfo?.size ?? 'میوه کوچک';
    final babyWeight = weekInfo?.babyWeightFa ?? '';
    final developmentText =
        weekInfo?.development ?? 'اندام‌های جنین در حال تکمیل و رشد هستند.';
    final tipText =
        weekInfo?.tip ??
        'تغذیه سالم، نوشیدن آب کافی و استراحت روزانه را در اولویت قرار دهید.';

    final trimesterNum = ga.trimester;
    final trimesterTitle =
        'راهنمای سه ماهه ${trimesterNum == 1 ? "اول" : (trimesterNum == 2 ? "دوم" : "سوم")}';
    final trimesterTips = trimesterNum == 1
        ? 'مصرف منظم فولیک اسید، استراحت در صورت خستگی و مدیریت تهوع صبحگاهی با وعده‌های کوچک.'
        : (trimesterNum == 2
              ? 'بهترین زمان برای انجام سونوگرافی آنومالی، خوابیدن به پهلوی چپ و ثبت اولین لگدها.'
              : 'شروع شمارش منظم لگد جنین، آماده‌سازی ساک بیمارستان و آشنایی با نشانه‌های زایمان.');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // UX-01 Pregnancy Today Card Banner
          PregnancyTodayCard(
            gestationalAge: ga,
            hasSupplementToday: selectedSymptoms.any(
              (s) => s.startsWith('SUPP_'),
            ),
            hasKicksLogged: kickCount > 0,
            onNavigateTab: onNavigateTab,
            onOpenWeightLog: () {},
            onOpenLaborMode: () =>
                LaborModeScreen.show(context, pregnancyId: 'preg_default'),
            onOpenHospitalBag: () => onNavigateTab(0),
          ),

          const SizedBox(height: 16),

          // UX-02 Hero Progress Ring & Journey Map (Large 200px)
          Center(
            child: SizedBox(
              width: 210,
              height: 210,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CustomPaint(
                    painter: PregnancyRingPainter(
                      percentage: progressPercent,
                      colors: [colors.primary, colors.accent],
                    ),
                  ),

                  // UX-02 Milestones interactive tap targets (12, 20, 24, 28, 36)
                  ...[12, 20, 24, 28, 36].map((week) {
                    final angleDeg = PregnancyHelpers.milestoneAngle(week);
                    final rad = (angleDeg - 90) * math.pi / 180;
                    const r = 86.0;
                    final x = 105.0 + r * math.cos(rad) - 24.0;
                    final y = 105.0 + r * math.sin(rad) - 24.0;

                    return Positioned(
                      left: x,
                      top: y,
                      child: Semantics(
                        button: true,
                        label: 'مراقبت هفته $week',
                        child: InkWell(
                          onTap: () => onNavigateTab(1),
                          borderRadius: BorderRadius.circular(24),
                          child: Container(
                            width: 48,
                            height: 48,
                            alignment: Alignment.center,
                            child: CircleAvatar(
                              radius: currentWeek >= week ? 9 : 6,
                              backgroundColor: currentWeek >= week
                                  ? colors.primary
                                  : colors.border,
                              child: currentWeek >= week
                                  ? const Icon(
                                      CupertinoIcons.checkmark,
                                      size: 10,
                                      color: Colors.white,
                                    )
                                  : null,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),

                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'هفته ${PersianDigits.toFa(currentWeek.toString())}',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '+ ${PersianDigits.toFa(currentDayInWeek.toString())} روز',
                          style: TextStyle(
                            fontSize: 14,
                            color: colors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: colors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${PersianDigits.toFa((progressPercent * 100).toInt().toString())}% کل مسیر',
                            style: TextStyle(
                              fontSize: 11,
                              color: colors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Weekly Fetus Growth & Fruit Size Card
          RitmoTheme.glassCardLight(
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: colors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: colors.primary.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          CupertinoIcons.heart_circle_fill,
                          color: colors.primary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'جنین هفته ${PersianDigits.toFa(currentWeek.toString())}: $babySize',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: colors.textPrimary,
                              ),
                            ),
                            if (babyWeight.isNotEmpty)
                              Text(
                                'وزن تقریبی: $babyWeight',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colors.textSecondary,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    developmentText,
                    style: TextStyle(
                      fontSize: 14,
                      color: colors.textPrimary,
                      height: 1.5,
                    ),
                  ),
                  const Divider(height: 20),
                  Row(
                    children: [
                      Icon(
                        CupertinoIcons.lightbulb_fill,
                        size: 16,
                        color: colors.warning,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'نکته هفته: $tipText',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: colors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Smart AI Pregnancy Assistant Card
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: LinearGradient(
                colors: [colors.primary, colors.accent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: colors.primary.withValues(alpha: 0.25),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: onOpenAssistant,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          CupertinoIcons.sparkles,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'دستیار هوشمند بارداری ریتمو 🤖',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'مشاوره تغذیه، علائم و خودمراقبتی هفته ${PersianDigits.toFa(currentWeek.toString())} بارداری',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withValues(alpha: 0.85),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        CupertinoIcons.chevron_left,
                        color: Colors.white,
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Trimester Care Advice Card
          RitmoTheme.glassCardLight(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: colors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    trimesterTitle,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    trimesterTips,
                    style: TextStyle(
                      fontSize: 13,
                      color: colors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Quick Actions Grid Hub
          Row(
            children: [
              Expanded(
                child: _buildQuickActionButton(
                  icon: CupertinoIcons.sparkles,
                  color: colors.primary,
                  label: 'شروع لگدشماری',
                  onTap: () => onNavigateTab(2),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildQuickActionButton(
                  icon: CupertinoIcons.timer,
                  color: colors.accent,
                  label: 'حالت زایمان',
                  onTap: () => LaborModeScreen.show(
                    context,
                    pregnancyId: 'preg_default',
                  ),
                ),
              ),
            ],
          ),

          // UX-10 Hospital Bag checklist if week >= 32
          if (currentWeek >= 32) ...[
            const SizedBox(height: 20),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: colors.primary.withValues(alpha: 0.2)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '🎒 چک‌لیست ساک بیمارستان (هفته ۳۲ به بعد)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...hospitalBagItems.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final item = entry.value;
                      return CheckboxListTile(
                        dense: true,
                        activeColor: colors.primary,
                        title: Text(
                          item['title'] as String,
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.textPrimary,
                          ),
                        ),
                        value: item['done'] as bool,
                        onChanged: (val) =>
                            onToggleHospitalBagItem(idx, val ?? false),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
