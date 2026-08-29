import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ritmo/core/domain/realm/active_realm_resolver.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_card.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_page_scaffold.dart';
import 'package:ritmo/core/widgets/ritmo_module_app_bar.dart';
import 'package:ritmo/core/widgets/sheet/ritmo_picker_sheet.dart';
import 'package:ritmo/features/today/presentation/widgets/dashboard/realm_24h_dial.dart';
import 'package:ritmo/features/today/presentation/widgets/dashboard/realm_24h_overview_sheet.dart';
import 'package:ritmo/features/today/presentation/widgets/realm_edit_form_sheet.dart';

class CardsShowcaseScreen extends StatefulWidget {
  const CardsShowcaseScreen({super.key});

  @override
  State<CardsShowcaseScreen> createState() => _CardsShowcaseScreenState();
}

class _CardsShowcaseScreenState extends State<CardsShowcaseScreen> {
  int _selectedCardIndex = 0;
  bool _taskDone = false;
  int _focusMinutes = 25;
  int _counter = 0;
  Timer? _ticker;
  DateTime _now = DateTime.now();
  RealmMode _activeShowcaseMode = RealmMode.normal;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDark;

    return RitmoPageScaffold(
      appBar: RitmoModuleAppBar.fromContext(
        context: context,
        title: 'سیستم مرجع کارت‌های نئومورفیک',
        showBackButton: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        children: [
          // ── هدر معرفی سیستم نئومورفیک ──
          _buildHeroHeader(colors, isDark),
          const SizedBox(height: 20),

          // ── ۱. کارت مرجع شاهکار نئومورفیک (Master Reference Card) ──
          _buildSectionTitle('۱. کارت مرجع کامل نئومورفیک (Master Hero Card)', 'ترکیب گیج ۲۴ ساعته، چیپ‌های فرورفته/برآمده، پیل زمان و تایمر'),
          const SizedBox(height: 10),

          _buildMasterReferenceCard(colors, isDark),
          const SizedBox(height: 24),

          // ── ۲. کارت‌های برجسته نئومورفیک داشبورد (Neumorphic Raised) ──
          _buildSectionTitle('۲. کارت برجسته داشبورد ریتمو (Raised Card)', 'سایه دوگانه متضاد + المان‌های اتمیک نئومورفیک'),
          const SizedBox(height: 10),

          // کارت نمونه ویجت داشبورد با المان‌های اتمیک نئومورفیک
          RitmoCard.neumorphic(
            onTap: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('کارت نئومورفیک لمس شد (انیمیشن فرورفتگی + لرزش اپل)'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                RitmoCardHeader(
                  title: 'نبض ریتم روزانه',
                  subtitle: 'بررسی پیشرفت و فعالیت‌های فعال',
                  icon: CupertinoIcons.waveform_path_ecg,
                  iconColor: colors.primary,
                  trailing: RitmoCardBadge(
                    label: '۸۵٪ تکمیل',
                    color: colors.success,
                    icon: CupertinoIcons.checkmark_alt,
                  ),
                ),
                const SizedBox(height: 8),
                RitmoCardTile(
                  leading: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(CupertinoIcons.flame_fill, size: 17, color: colors.primary),
                  ),
                  title: 'زمان تمرکز عمیق',
                  subtitle: 'هدف امروز: ۲ ساعت',
                  trailing: Text(
                    toPersianDigits('$_focusMinutes دقیقه'),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: colors.textPrimary,
                    ),
                  ),
                  onTap: () {
                    setState(() => _focusMinutes += 5);
                  },
                ),
                const SizedBox(height: 8),
                RitmoCardTile(
                  leading: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: colors.success.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(CupertinoIcons.checkmark_seal_fill, size: 17, color: colors.success),
                  ),
                  title: 'عادت‌های روزانه',
                  subtitle: '۳ از ۴ مورد انجام شده',
                  trailing: CupertinoSwitch(
                    value: _taskDone,
                    activeTrackColor: colors.success,
                    onChanged: (val) => setState(() => _taskDone = val),
                  ),
                ),
                const RitmoCardDivider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'برای فرورفتن و تست کلیک کنید',
                      style: TextStyle(
                        fontSize: 11,
                        color: colors.textTertiary,
                        fontFamily: 'Vazirmatn',
                      ),
                    ),
                    Icon(CupertinoIcons.chevron_left, size: 13, color: colors.textTertiary),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── ۲. کارت‌ها در حالت انتخاب نئومورفیک (Selected State) ──
          _buildSectionTitle('۲. حالت انتخاب‌شده (Selected State)', 'گرادیان زنده پالت + هاله نوری نئومورفیک'),
          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: RitmoCard.neumorphic(
                  isSelected: _selectedCardIndex == 0,
                  onTap: () => setState(() => _selectedCardIndex = 0),
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: [
                      Icon(
                        CupertinoIcons.sun_max_fill,
                        size: 26,
                        color: _selectedCardIndex == 0 ? colors.primary : colors.textSecondary,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'قلمرو روز',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      RitmoCardBadge(
                        label: 'فعال',
                        color: colors.primary,
                        isOutlined: _selectedCardIndex != 0,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: RitmoCard.neumorphic(
                  isSelected: _selectedCardIndex == 1,
                  onTap: () => setState(() => _selectedCardIndex = 1),
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: [
                      Icon(
                        CupertinoIcons.moon_stars_fill,
                        size: 26,
                        color: _selectedCardIndex == 1 ? colors.primary : colors.textSecondary,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'قلمرو شب',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      RitmoCardBadge(
                        label: 'رزرو',
                        color: _selectedCardIndex == 1 ? colors.primary : colors.textSecondary,
                        isOutlined: _selectedCardIndex != 1,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── ۳. کارت فرورفته نئومورفیک (Sunken Inset) ──
          _buildSectionTitle('۳. سطح فرورفته نئومورفیک (Sunken Inset)', 'سایه معکوس برای اینپوت‌ها، پیش‌نمایش و گودی‌ها'),
          const SizedBox(height: 10),

          RitmoCard.neumorphicSunken(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(CupertinoIcons.info_circle_fill, size: 17, color: colors.primary),
                    const SizedBox(width: 8),
                    Text(
                      'گودی نئومورفیک فیزیکی (Physical Inset)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: colors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'این کارت با سایه معکوس در زاویه ۱۳۵ درجه، حس فرورفتن در عمق بوم را شبیه‌سازی می‌کند و برای یادداشت‌ها یا ترک‌های پیشرفت عالی است.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── ۴. دکمه‌های نئومورفیک ۳ بعدی (Tactile 3D Buttons) ──
          _buildSectionTitle('۴. دکمه‌های نئومورفیک ۳ بعدی (Tactile Buttons)', 'فشردن فیزیکی با تغییر وضعیت به فرورفته'),
          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: RitmoNeuButton(
                  onTap: () => setState(() => _counter++),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(CupertinoIcons.add_circled_solid, size: 18, color: colors.primary),
                      const SizedBox(width: 8),
                      Text(
                        toPersianDigits('شمارنده: $_counter'),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: colors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: RitmoNeuButton(
                  onTap: () => setState(() => _counter = 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(CupertinoIcons.refresh_circled, size: 18, color: colors.error),
                      const SizedBox(width: 8),
                      Text(
                        'بازنشانی',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: colors.error,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── ۵. نوار پیشرفت نئومورفیک فرورفته (Sunken Progress Bar) ──
          _buildSectionTitle('۵. نوار پیشرفت نئومورفیک فرورفته (Progress Bar)', 'شیار سه‌بعدی فرورفته با پرکننده نئونی و درخشان'),
          const SizedBox(height: 10),

          RitmoCard.neumorphic(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                RitmoNeuProgressBar(
                  progress: 0.72,
                  label: 'پیشرفت اهداف هفتگی',
                  showLabel: true,
                  height: 12,
                  color: colors.primary,
                ),
                const SizedBox(height: 14),
                const RitmoNeuProgressBar(
                  progress: 0.45,
                  label: 'ریکاوری و خواب شبانه',
                  showLabel: true,
                  height: 10,
                  color: Color(0xFF10B981),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── ۶. کارت اسکلت لودینگ نئومورفیک (Card Skeleton) ──
          _buildSectionTitle('۶. اسکلت لودینگ نئومورفیک (Loading Skeleton)', 'انیمیشن تنفس نوری روان بدون پرش ابعادی بوم'),
          const SizedBox(height: 10),

          const RitmoCardSkeleton(height: 130),
          const SizedBox(height: 24),

          // ── ۷. کارت حالت خالی سه‌بعدی (Empty State Card) ──
          _buildSectionTitle('۷. کارت حالت خالی سه‌بعدی (Empty State Card)', 'برای نمایش زیبا و دلنشین وضعیت‌های بدون داده'),
          const SizedBox(height: 10),

          RitmoNeuEmptyCard(
            title: 'هنوز هیچ برنامه‌ای برای امروز ثبت نشده',
            subtitle: 'می‌توانید با دکمه زیر اولین هدف یا عادت روزانه خود را تعریف کنید.',
            actionLabel: 'افزودن برنامه جدید',
            onActionTap: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('دکمه «افزودن برنامه جدید» لمس شد'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
          ),
          const SizedBox(height: 24),

          // ── ۸. پنجره‌ها و شیت‌های مرجع ریتمو (Reference Glass Sheets & Windows) ──
          _buildSectionTitle(
            '۸. پنجره‌ها و شیت‌های مرجع ریتمو (Reference Sheets)',
            'طراحی شیشه‌ای استاندارد با اکوسیستم اپل، بلور زنده و هاله نوری پالت',
          ),
          const SizedBox(height: 10),

          _buildReferenceSheetsShowcase(colors, isDark),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildHeroHeader(RitmoColors colors, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: isDark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colors.primary.withValues(alpha: 0.25),
          width: 0.9,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: colors.primary,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              CupertinoIcons.cube_box_fill,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ویترین زنده سیستم مرجع نئومورفیک',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w900,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'عمق ۳ بعدی، سایه‌های دوگانه، فرورفتگی و برجستگی',
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

  Widget _buildSectionTitle(String title, String desc) {
    final colors = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w900,
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          desc,
          style: TextStyle(
            fontSize: 11,
            color: colors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildMasterReferenceCard(RitmoColors colors, bool isDark) {
    final activeColor = colors.primary;

    final sampleRealms = [
      RealmData(
        id: 'sleep',
        name: 'خواب و ریکاوری',
        colorHex: '#${activeColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}',
        icon: '🌙',
        mode: _activeShowcaseMode,
      ),
      const RealmData(
        id: 'work',
        name: 'کار و تمرکز',
        colorHex: '#3B82F6',
        icon: '💼',
        mode: RealmMode.focus,
      ),
    ];

    final sampleSchedules = [
      const RealmScheduleData(
        id: 's1',
        zoneId: 'sleep',
        daysOfWeek: {1, 2, 3, 4, 5, 6, 7},
        startTime: '22:30',
        endTime: '05:30',
      ),
      const RealmScheduleData(
        id: 's2',
        zoneId: 'work',
        daysOfWeek: {1, 2, 3, 4, 5, 6, 7},
        startTime: '08:30',
        endTime: '17:00',
      ),
    ];

    return RitmoNeuMasterCard(
      title: 'خواب و ریکاوری',
      subtitle: 'ذهنی آرام‌تر، عملکردی بهتر',
      modeLabel: _activeShowcaseMode.label,
      onModeTap: () => _openShowcaseModeSelectionSheet(context, colors, isDark),
      statusLabel: 'قلمرو فعال',
      timeRange: '${toPersianDigits("۲۲:۳۰")}   ➔   ${toPersianDigits("۰۵:۳۰")}',
      remainingTime: toPersianDigits('۰۵:۵۶:۱۶'),
      activeColor: activeColor,
      height: 180,
      gaugeWidget: Realm24hDial(
        size: 116,
        activeZoneId: 'sleep',
        activeZoneColor: activeColor,
        activeZoneIcon: '🌙',
        activeZoneName: 'خواب و ریکاوری',
        schedules: sampleSchedules,
        realms: sampleRealms,
        isDarkMode: isDark,
        now: _now,
        showHourLabels: false,
      ),
      actionButtonText: 'مدیریت قلمرو',
      onActionTap: () => _openShowcase24hSheet(context, colors, isDark),
      onTap: () => _openShowcase24hSheet(context, colors, isDark),
    );
  }

  Widget _buildReferenceSheetsShowcase(RitmoColors colors, bool isDark) {
    return Column(
      children: [
        _buildSheetLaunchTile(
          title: 'پنجره شیشه‌ای انتخاب حالت قلمرو',
          subtitle: 'انتخاب سریع بین حالت عادی، تمرکز و بی‌صدا (RitmoGlassSheet)',
          badge: 'پنجره اصلی',
          icon: CupertinoIcons.slider_horizontal_3,
          color: colors.primary,
          onTap: () => _openShowcaseModeSelectionSheet(context, colors, isDark),
        ),
        const SizedBox(height: 10),
        _buildSheetLaunchTile(
          title: 'پنجره گاه‌شمار ۲۴ ساعته شبانه‌روز',
          subtitle: 'نمای شبانه‌روز، دایال ساعت، نوار توازن و مدیریت قلمروها',
          badge: 'گاه‌شمار کامل',
          icon: CupertinoIcons.clock_fill,
          color: const Color(0xFF10B981),
          onTap: () => _openShowcase24hSheet(context, colors, isDark),
        ),
        const SizedBox(height: 10),
        _buildSheetLaunchTile(
          title: 'پنجره انتخابگر عمومی گزینه‌ها (Picker)',
          subtitle: 'جست‌وجو، فیلتر و انتخاب تک‌گزینه‌ای با لیست آیتم‌ها (RitmoPickerSheet)',
          badge: 'انتخابگر',
          icon: CupertinoIcons.list_bullet_below_rectangle,
          color: const Color(0xFF8B5CF6),
          onTap: () => _openShowcasePickerSheet(context),
        ),
        const SizedBox(height: 10),
        _buildSheetLaunchTile(
          title: 'پنجره فرم تعریف و ویرایش قلمرو',
          subtitle: 'فرم جامع با پالت رنگ، آیکون، زمان‌بندی و تمپلیت‌های آماده',
          badge: 'فرم تعاملی',
          icon: CupertinoIcons.square_pencil_fill,
          color: const Color(0xFFEC4899),
          onTap: () => _openShowcaseEditFormSheet(context),
        ),
      ],
    );
  }

  Widget _buildSheetLaunchTile({
    required String title,
    required String subtitle,
    required String badge,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final colors = context.colors;
    final isDark = context.isDark;

    return RitmoCard.neumorphic(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      borderRadius: BorderRadius.circular(20),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: color.withValues(alpha: isDark ? 0.20 : 0.12),
              border: Border.all(
                color: color.withValues(alpha: isDark ? 0.35 : 0.20),
                width: 0.9,
              ),
            ),
            child: Icon(icon, size: 20, color: color),
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
                        fontWeight: FontWeight.w800,
                        fontFamily: 'Vazirmatn',
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        badge,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'Vazirmatn',
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            CupertinoIcons.chevron_left,
            size: 14,
            color: colors.textSecondary.withValues(alpha: 0.7),
          ),
        ],
      ),
    );
  }

  void _openShowcaseModeSelectionSheet(BuildContext context, RitmoColors colors, bool isDark) {
    HapticFeedback.mediumImpact();
    final activeColor = colors.primary;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: RitmoGlassSheet(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                padding: EdgeInsets.zero,
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Container(
                            width: 38,
                            height: 4.5,
                            margin: const EdgeInsets.only(bottom: 14),
                            decoration: BoxDecoration(
                              color: colors.textSecondary.withValues(alpha: isDark ? 0.30 : 0.22),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: activeColor.withValues(alpha: isDark ? 0.20 : 0.12),
                                border: Border.all(
                                  color: activeColor.withValues(alpha: isDark ? 0.35 : 0.20),
                                  width: 1,
                                ),
                              ),
                              child: const Text('🌙', style: TextStyle(fontSize: 20)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'حالت قلمرو «خواب و ریکاوری»',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                      fontFamily: 'Vazirmatn',
                                      color: colors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'نحوه رفتار روتین‌ها و دریافت اعلان‌ها را تنظیم کنید',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontFamily: 'Vazirmatn',
                                      color: colors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () => Navigator.of(sheetContext).pop(),
                              child: Container(
                                width: 32,
                                height: 32,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.08)
                                      : Colors.black.withValues(alpha: 0.05),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  CupertinoIcons.xmark,
                                  size: 15,
                                  color: colors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _buildShowcaseModeOptionItem(
                          title: 'حالت عادی',
                          subtitle: 'همه روتین‌ها بدون محدودیت اجرا می‌شوند',
                          mode: RealmMode.normal,
                          isSelected: _activeShowcaseMode == RealmMode.normal,
                          icon: CupertinoIcons.sparkles,
                          color: activeColor,
                          onSelect: () {
                            HapticFeedback.selectionClick();
                            setState(() => _activeShowcaseMode = RealmMode.normal);
                            Navigator.of(sheetContext).pop();
                          },
                        ),
                        const SizedBox(height: 10),
                        _buildShowcaseModeOptionItem(
                          title: 'حالت تمرکز',
                          subtitle: 'فقط روتین‌های ضروری و حیاتی نمایش داده می‌شوند',
                          mode: RealmMode.focus,
                          isSelected: _activeShowcaseMode == RealmMode.focus,
                          icon: CupertinoIcons.flame_fill,
                          color: activeColor,
                          onSelect: () {
                            HapticFeedback.selectionClick();
                            setState(() => _activeShowcaseMode = RealmMode.focus);
                            Navigator.of(sheetContext).pop();
                          },
                        ),
                        const SizedBox(height: 10),
                        _buildShowcaseModeOptionItem(
                          title: 'حالت بی‌صدا',
                          subtitle: 'اعلان‌ها مسدود شده و محیط کاملاً آرام می‌شود',
                          mode: RealmMode.silent,
                          isSelected: _activeShowcaseMode == RealmMode.silent,
                          icon: CupertinoIcons.bell_slash_fill,
                          color: activeColor,
                          onSelect: () {
                            HapticFeedback.selectionClick();
                            setState(() => _activeShowcaseMode = RealmMode.silent);
                            Navigator.of(sheetContext).pop();
                          },
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildShowcaseModeOptionItem({
    required String title,
    required String subtitle,
    required RealmMode mode,
    required bool isSelected,
    required IconData icon,
    required Color color,
    required VoidCallback onSelect,
  }) {
    final colors = context.colors;
    final isDark = context.isDark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onSelect,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withValues(alpha: isDark ? 0.18 : 0.10)
                : (isDark ? colors.surfaceElevated.withValues(alpha: 0.60) : colors.surfaceElevated),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isSelected
                  ? color.withValues(alpha: isDark ? 0.65 : 0.45)
                  : (isDark ? colors.border.withValues(alpha: 0.22) : colors.divider),
              width: isSelected ? 1.4 : 1.0,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: isDark ? 0.25 : 0.12),
                      blurRadius: 12,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: isSelected
                      ? color.withValues(alpha: isDark ? 0.25 : 0.18)
                      : (isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : Colors.black.withValues(alpha: 0.04)),
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: isSelected ? color : colors.textSecondary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                        fontFamily: 'Vazirmatn',
                        color: isSelected
                            ? (isDark ? Color.lerp(color, Colors.white, 0.75)! : Color.lerp(color, Colors.black, 0.30)!)
                            : colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        fontFamily: 'Vazirmatn',
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(
                  CupertinoIcons.checkmark_alt_circle_fill,
                  size: 20,
                  color: color,
                )
              else
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: colors.textSecondary.withValues(alpha: 0.30),
                      width: 1.5,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _openShowcase24hSheet(BuildContext context, RitmoColors colors, bool isDark) {
    HapticFeedback.lightImpact();
    final activeColor = colors.primary;

    final sampleRealms = [
      RealmData(
        id: 'sleep',
        name: 'خواب و ریکاوری',
        colorHex: '#${activeColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}',
        icon: '🌙',
        mode: _activeShowcaseMode,
      ),
      const RealmData(
        id: 'work',
        name: 'کار و تمرکز عمیق',
        colorHex: '#3B82F6',
        icon: '💻',
        mode: RealmMode.focus,
      ),
      const RealmData(
        id: 'sport',
        name: 'ورزش و تندرستی',
        colorHex: '#EF4444',
        icon: '🏃',
        mode: RealmMode.normal,
      ),
      const RealmData(
        id: 'study',
        name: 'مطالعه و یادگیری',
        colorHex: '#8B5CF6',
        icon: '📚',
        mode: RealmMode.focus,
      ),
    ];

    final sampleSchedules = [
      const RealmScheduleData(
        id: 's1',
        zoneId: 'sleep',
        daysOfWeek: {1, 2, 3, 4, 5, 6, 7},
        startTime: '22:30',
        endTime: '05:30',
      ),
      const RealmScheduleData(
        id: 's2',
        zoneId: 'work',
        daysOfWeek: {1, 2, 3, 4, 5, 6, 7},
        startTime: '08:30',
        endTime: '16:00',
      ),
      const RealmScheduleData(
        id: 's3',
        zoneId: 'sport',
        daysOfWeek: {1, 2, 3, 4, 5, 6, 7},
        startTime: '17:00',
        endTime: '18:30',
      ),
      const RealmScheduleData(
        id: 's4',
        zoneId: 'study',
        daysOfWeek: {1, 2, 3, 4, 5, 6, 7},
        startTime: '20:00',
        endTime: '21:30',
      ),
    ];

    final now = DateTime.now();
    final activeState = ScheduledRealmState(
      realm: sampleRealms[0],
      schedule: sampleSchedules[0],
      startsAt: now.subtract(const Duration(hours: 2)),
      endsAt: now.add(const Duration(hours: 5)),
      remaining: const Duration(hours: 5),
      progress: 0.28,
      explanation: 'برنامه خواب شبانه',
    );

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Realm24hOverviewSheet(
        isDarkMode: isDark,
        realmState: activeState,
        activeZoneColor: activeColor,
        activeZoneName: 'خواب و ریکاوری',
        activeZoneIcon: '🌙',
        schedules: sampleSchedules,
        realms: sampleRealms,
        onChanged: () {},
      ),
    );
  }

  void _openShowcasePickerSheet(BuildContext context) async {
    final selected = await RitmoPickerSheet.show<String>(
      context: context,
      title: 'انتخاب سطح انرژی و تمرکز',
      enableSearch: true,
      initialValue: 'high',
      options: const [
        PickerOption(
          label: 'انرژی فوق‌العاده بالا ⚡',
          subtitle: 'مناسب برای کارهای عمیق، تحلیل و حل مسائل پیچیده',
          icon: CupertinoIcons.bolt_fill,
          value: 'high',
        ),
        PickerOption(
          label: 'انرژی متوسط و پایدار 🎯',
          subtitle: 'مناسب برای جلسات، کارهای روتین و پیشبرد اهداف',
          icon: CupertinoIcons.sparkles,
          value: 'medium',
        ),
        PickerOption(
          label: 'انرژی ملایم و ریکاوری 🌿',
          subtitle: 'مناسب برای استراحت، مطالعه سبک و بازیابی قوا',
          icon: CupertinoIcons.leaf_arrow_circlepath,
          value: 'low',
        ),
        PickerOption(
          label: 'خاموشی و استراحت مطلق 🌙',
          subtitle: 'آماده‌سازی برای خواب شبانه و آرامش ذهنی',
          icon: CupertinoIcons.moon_stars_fill,
          value: 'sleep',
        ),
      ],
    );

    if (selected != null && context.mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('گزینه «$selected» از انتخابگر انتخاب شد'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  void _openShowcaseEditFormSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RealmEditFormSheet(
        onSave: (realm, schedules) async {
          if (context.mounted) {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('قلمرو «${realm.name}» ذخیره شد'),
                duration: const Duration(seconds: 1),
              ),
            );
          }
        },
      ),
    );
  }
}

