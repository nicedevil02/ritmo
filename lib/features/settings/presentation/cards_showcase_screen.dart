import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/domain/realm/realm_mode.dart';
import 'package:ritmo/core/domain/realm/realm_state.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_card.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_page_scaffold.dart';
import 'package:ritmo/core/widgets/ritmo_module_app_bar.dart';
import 'package:ritmo/features/today/presentation/widgets/dashboard/realm_24h_dial.dart';

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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                        color: _selectedCardIndex == 0 ? Colors.white : colors.primary,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'قلمرو روز',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: _selectedCardIndex == 0 ? Colors.white : colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      RitmoCardBadge(
                        label: 'فعال',
                        color: _selectedCardIndex == 0 ? Colors.white : colors.primary,
                        isOutlined: _selectedCardIndex == 0,
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
                        color: _selectedCardIndex == 1 ? Colors.white : colors.textSecondary,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'قلمرو شب',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: _selectedCardIndex == 1 ? Colors.white : colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      RitmoCardBadge(
                        label: 'رزرو',
                        color: _selectedCardIndex == 1 ? Colors.white : colors.textSecondary,
                        isOutlined: _selectedCardIndex == 1,
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
        mode: RealmMode.silent,
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
      subtitle: 'ذهنی آرام‌تر، فردایی بهتر',
      activeChipLabel: 'خواب و ریکاوری',
      activeChipIcon: CupertinoIcons.moon_fill,
      statusLabel: 'قلمرو فعال',
      timeRange: '${toPersianDigits("۰۵:۳۰")}  ➔  ${toPersianDigits("۲۲:۳۰")}',
      remainingTime: toPersianDigits('۰۵:۵۶:۱۶'),
      activeColor: activeColor,
      gaugeWidget: Realm24hDial(
        size: 96,
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
      onActionTap: () {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('دکمه نئومورفیک «مدیریت قلمرو» لمس شد'),
            duration: Duration(seconds: 1),
          ),
        );
      },
      onTap: () {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('کارت شاهکار نئومورفیک لمس شد (فیزیک فرورفتگی + لرزش هپتیک)'),
            duration: Duration(seconds: 1),
          ),
        );
      },
    );
  }
}

