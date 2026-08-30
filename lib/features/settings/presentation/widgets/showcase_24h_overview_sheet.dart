// =============================================================================
//  showcase_24h_overview_sheet.dart
//  شیت مرجع داشبورد و چیدمان داده‌های ریتمو (Ritmo Canonical Dashboard Sheet)
// =============================================================================

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/domain/realm/active_realm_resolver.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/ux/ritmo_sheet_scaffold.dart';
import 'package:ritmo/features/settings/presentation/widgets/showcase_realm_edit_form_sheet.dart';

class Showcase24hOverviewSheet extends StatefulWidget {
  const Showcase24hOverviewSheet({
    super.key,
    this.isDarkMode = false,
    this.realmState,
    this.activeZoneColor,
    this.activeZoneName,
    this.activeZoneIcon,
    this.schedules,
    this.realms,
    this.onChanged,
  });

  final bool isDarkMode;
  final ActiveRealmState? realmState;
  final Color? activeZoneColor;
  final String? activeZoneName;
  final String? activeZoneIcon;
  final List<RealmScheduleData>? schedules;
  final List<RealmData>? realms;
  final VoidCallback? onChanged;

  @override
  State<Showcase24hOverviewSheet> createState() => _Showcase24hOverviewSheetState();
}

class _Showcase24hOverviewSheetState extends State<Showcase24hOverviewSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _childSheetAnimController;
  late final DraggableScrollableController _sheetController;
  bool _isDismissing = false;

  int _selectedFilterIndex = 0;
  double _interactiveGaugeValue = 0.72;
  int _selectedWeekday = 6; // شنبه

  static const List<String> _filters = ['روزانه ☀️', 'هفتگی 📅', 'ماهانه 📊', 'سالیانه 📈'];

  static const List<({String label, String fullLabel, int weekday})> _weekdays = [
    (label: 'ش', fullLabel: 'شنبه', weekday: 6),
    (label: 'ی', fullLabel: 'یک‌شنبه', weekday: 7),
    (label: 'د', fullLabel: 'دوشنبه', weekday: 1),
    (label: 'س', fullLabel: 'سه‌شنبه', weekday: 2),
    (label: 'چ', fullLabel: 'چهارشنبه', weekday: 3),
    (label: 'پ', fullLabel: 'پنج‌شنبه', weekday: 4),
    (label: 'ج', fullLabel: 'جمعه', weekday: 5),
  ];

  @override
  void initState() {
    super.initState();
    _sheetController = DraggableScrollableController();
    _sheetController.addListener(_onSheetDragListener);
    _childSheetAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
      reverseDuration: const Duration(milliseconds: 300),
    );
  }

  void _onSheetDragListener() {
    if (_isDismissing || !_sheetController.isAttached) return;
    if (_sheetController.size < 0.30) {
      _isDismissing = true;
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _sheetController.removeListener(_onSheetDragListener);
    _sheetController.dispose();
    _childSheetAnimController.dispose();
    super.dispose();
  }

  void _openShowcaseForm() {
    RitmoHaptics.selection();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      transitionAnimationController: _childSheetAnimController,
      builder: (_) => ShowcaseRealmEditFormSheet(
        onSave: (realm, schedules) async {
          if (mounted) {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('داده‌های فرم «${realm.name}» با موفقیت ذخیره شد'),
                duration: const Duration(seconds: 2),
              ),
            );
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDark;
    final isGlass = context.isGlassEnabled;
    const sheetRadius = BorderRadius.vertical(top: Radius.circular(32));

    return Directionality(
      textDirection: TextDirection.rtl,
      child: DraggableScrollableSheet(
        controller: _sheetController,
        initialChildSize: 0.90,
        minChildSize: 0.0,
        maxChildSize: 0.90,
        snap: true,
        snapSizes: const [0.0, 0.90],
        snapAnimationDuration: const Duration(milliseconds: 250),
        builder: (context, scrollController) {
          return AppleCardDeckHost(
            animation: _childSheetAnimController,
            topCornerRadius: 32.0,
            child: RitmoGlassSheet(
              borderRadius: sheetRadius,
              child: ClipRect(
                child: Column(
                  children: [
                    // 1. Pinned Modal Header (Swipe down to dismiss)
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onVerticalDragUpdate: (details) {
                        if (_isDismissing || !_sheetController.isAttached) return;
                        final screenHeight = MediaQuery.of(context).size.height;
                        if (screenHeight <= 0) return;
                        final deltaFraction = -details.delta.dy / screenHeight;
                        final newSize = (_sheetController.size + deltaFraction).clamp(0.0, 0.90);
                        _sheetController.jumpTo(newSize);
                      },
                      onVerticalDragEnd: (details) {
                        if (_isDismissing || !_sheetController.isAttached) return;
                        final currentSize = _sheetController.size;
                        final velocity = details.primaryVelocity ?? 0.0;
                        if (velocity > 350 || currentSize < 0.65) {
                          _isDismissing = true;
                          Navigator.of(this.context).pop();
                          return;
                        }
                        unawaited(_sheetController.animateTo(
                          0.90,
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOutCubic,
                        ));
                      },
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                        child: Column(
                          children: [
                            Center(
                              child: Container(
                                width: 38,
                                height: 4.5,
                                decoration: BoxDecoration(
                                  color: colors.textTertiary.withValues(alpha: 0.35),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                // Symmetrical Balance Leading Spacer
                                const SizedBox(width: 32, height: 32),

                                // Center: Symmetrical Title & Subtitle
                                Expanded(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            'ویترین شیت‌های تعاملی ریتمو',
                                            style: TextStyle(
                                              fontSize: 16.5,
                                              fontWeight: FontWeight.w900,
                                              color: colors.textPrimary,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          const Text('🪟', style: TextStyle(fontSize: 15)),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'الگوی استاندارد لایه‌بندی ماژول‌ها، سنجه‌های زنده و کارت‌های تعاملی',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontFamily: 'Vazirmatn',
                                          color: colors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Trailing: Tactile Glass Close Button
                                GestureDetector(
                                  onTap: () {
                                    RitmoHaptics.tap();
                                    Navigator.of(context).pop();
                                  },
                                  child: Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? Colors.white.withValues(alpha: 0.10)
                                          : Colors.black.withValues(alpha: 0.06),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isDark
                                            ? Colors.white.withValues(alpha: 0.14)
                                            : Colors.black.withValues(alpha: 0.08),
                                        width: 0.75,
                                      ),
                                    ),
                                    alignment: Alignment.center,
                                    child: Icon(
                                      CupertinoIcons.xmark,
                                      size: 14,
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

                    Divider(height: 1, color: colors.divider),

                    // 2. Scrollable Showcase Content
                    Expanded(
                      child: ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                        children: [
                          // A. Filter Segment Selector
                          _buildFilterSegmentSelector(isDark, colors, isGlass),

                          const SizedBox(height: 16),

                          // B. Weekday Selector
                          _buildWeekdaySelector(isDark, colors, isGlass),

                          const SizedBox(height: 18),

                          // C. Interactive Metric / Focus Gauge Hero Card
                          _buildInteractiveHeroGauge(isDark, colors, isGlass),

                          const SizedBox(height: 16),

                          // D. Balance & Proportions Bar
                          _buildBalanceDistributionBar(isDark, colors, isGlass),

                          const SizedBox(height: 20),

                          // E. Module Cards Stream Header
                          _buildModulesHeader(isDark, colors),
                          const SizedBox(height: 10),

                          // F. Module Cards
                          _buildSampleModuleCard(
                            title: 'تمرکز عمیق و تسک‌های اصلی',
                            time: '۰۸:۳۰ تا ۱۲:۳۰ (۴ ساعت)',
                            icon: '💼',
                            color: const Color(0xFF3B82F6),
                            badge: 'فعال در حال حاضر',
                            isDark: isDark,
                            colors: colors,
                          ),
                          const SizedBox(height: 10),
                          _buildSampleModuleCard(
                            title: 'ورزش، تناسب اندام و انرژی',
                            time: '۱۷:۰۰ تا ۱۸:۳۰ (۱:۳۰ ساعت)',
                            icon: '🏋️',
                            color: const Color(0xFFEF4444),
                            badge: 'برنامه عصرگاهی',
                            isDark: isDark,
                            colors: colors,
                          ),
                          const SizedBox(height: 10),
                          _buildSampleModuleCard(
                            title: 'مطالعه، یادگیری و پژوهش',
                            time: '۲۰:۰۰ تا ۲۱:۳۰ (۱:۳۰ ساعت)',
                            icon: '📚',
                            color: const Color(0xFF8B5CF6),
                            badge: 'شبانه',
                            isDark: isDark,
                            colors: colors,
                          ),
                          const SizedBox(height: 10),
                          _buildSampleModuleCard(
                            title: 'خواب و بازیابی زیستی',
                            time: '۲۳:۳۰ تا ۰۷:۰۰ (۷:۳۰ ساعت)',
                            icon: '🌙',
                            color: const Color(0xFF6366F1),
                            badge: 'سیکل شبانه',
                            isDark: isDark,
                            colors: colors,
                          ),

                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilterSegmentSelector(bool isDark, RitmoColors colors, bool isGlass) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.surfaceElevated.withValues(alpha: isGlass ? 0.55 : 0.90),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? colors.border.withValues(alpha: 0.25) : colors.divider,
          width: 0.8,
        ),
      ),
      child: Row(
        children: List.generate(_filters.length, (index) {
          final isSelected = _selectedFilterIndex == index;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                RitmoHaptics.selection();
                setState(() => _selectedFilterIndex = index);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? colors.primary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: colors.primary.withValues(alpha: 0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  _filters[index],
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                    color: isSelected ? Colors.white : colors.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildWeekdaySelector(bool isDark, RitmoColors colors, bool isGlass) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.surfaceElevated.withValues(alpha: isGlass ? 0.55 : 0.90),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? colors.border.withValues(alpha: 0.25) : colors.divider,
          width: 0.8,
        ),
      ),
      child: Row(
        children: _weekdays.map((day) {
          final isSelected = _selectedWeekday == day.weekday;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                RitmoHaptics.selection();
                setState(() => _selectedWeekday = day.weekday);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(vertical: 7),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isDark ? colors.textPrimary : const Color(0xFF1E293B))
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  day.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                    color: isSelected
                        ? (isDark ? Colors.black : Colors.white)
                        : (day.weekday == 5 ? Colors.redAccent : colors.textSecondary),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildInteractiveHeroGauge(bool isDark, RitmoColors colors, bool isGlass) {
    final pctInt = (_interactiveGaugeValue * 100).round();

    return RitmoNeuMasterCard(
      title: 'سنجه تعاملی سطح ریتم و تمرکز',
      subtitle: 'برای تغییر سطح درصد ریتم، دایره را بکشید',
      statusLabel: 'سطح عملکرد عالی',
      timeRange: 'بازه بهینه: ۰۸:۳۰ الی ۱۶:۳۰',
      remainingTime: toPersianDigits('$pctInt٪ تکمیل‌شده'),
      activeColor: colors.primary,
      height: 195,
      gaugeWidget: GestureDetector(
        onPanUpdate: (details) {
          final delta = -details.delta.dy / 150.0;
          setState(() {
            _interactiveGaugeValue = (_interactiveGaugeValue + delta).clamp(0.0, 1.0);
          });
        },
        child: Container(
          width: 120,
          height: 120,
          alignment: Alignment.center,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 105,
                height: 105,
                child: CircularProgressIndicator(
                  value: _interactiveGaugeValue,
                  strokeWidth: 9,
                  backgroundColor: colors.textPrimary.withValues(alpha: 0.08),
                  valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
                  strokeCap: StrokeCap.round,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    toPersianDigits('$pctInt٪'),
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: colors.textPrimary,
                    ),
                  ),
                  Text(
                    'شارژ روزانه',
                    style: TextStyle(
                      fontSize: 10,
                      color: colors.textSecondary,
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

  Widget _buildBalanceDistributionBar(bool isDark, RitmoColors colors, bool isGlass) {
    return RitmoCard.neumorphic(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'توزیع و توازن شاخص‌های روزانه',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: colors.textPrimary,
                ),
              ),
              Text(
                toPersianDigits('۲۴ ساعت کامل'),
                style: TextStyle(
                  fontSize: 11,
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 10,
              child: Row(
                children: [
                  Expanded(flex: 40, child: Container(color: const Color(0xFF3B82F6))),
                  Expanded(flex: 15, child: Container(color: const Color(0xFFEF4444))),
                  Expanded(flex: 15, child: Container(color: const Color(0xFF8B5CF6))),
                  Expanded(flex: 30, child: Container(color: const Color(0xFF6366F1))),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildLegendItem('کار عمیق ۴۰٪', const Color(0xFF3B82F6), colors),
              _buildLegendItem('ورزش ۱۵٪', const Color(0xFFEF4444), colors),
              _buildLegendItem('یادگیری ۱۵٪', const Color(0xFF8B5CF6), colors),
              _buildLegendItem('خواب ۳۰٪', const Color(0xFF6366F1), colors),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color, RitmoColors colors) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          toPersianDigits(label),
          style: TextStyle(fontSize: 10, color: colors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildModulesHeader(bool isDark, RitmoColors colors) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            const RitmoLuminousDot(size: 8, hasGlow: true),
            const SizedBox(width: 8),
            Text(
              'ماژول‌ها و کارت‌های لایه‌ای',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: colors.textPrimary,
              ),
            ),
          ],
        ),
        GestureDetector(
          onTap: _openShowcaseForm,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: colors.primary.withValues(alpha: 0.25), width: 0.8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(CupertinoIcons.plus, size: 12, color: colors.primary),
                const SizedBox(width: 4),
                Text(
                  'تست فرم ورود داده',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: colors.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSampleModuleCard({
    required String title,
    required String time,
    required String icon,
    required Color color,
    required String badge,
    required bool isDark,
    required RitmoColors colors,
  }) {
    return RitmoCard.neumorphic(
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.35), width: 1),
            ),
            child: Text(icon, style: const TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: colors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        badge,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  toPersianDigits(time),
                  style: TextStyle(
                    fontSize: 11,
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
