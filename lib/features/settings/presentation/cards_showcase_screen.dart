import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ritmo/core/domain/realm/active_realm_resolver.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_page_scaffold.dart';
import 'package:ritmo/core/widgets/ritmo_module_app_bar.dart';
import 'package:ritmo/core/widgets/sheet/ritmo_picker_sheet.dart';
import 'package:ritmo/features/settings/presentation/widgets/showcase_24h_overview_sheet.dart';
import 'package:ritmo/features/settings/presentation/widgets/showcase_realm_edit_form_sheet.dart';
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
  int _selectedSegmentIndex = 0;
  Timer? _ticker;
  final ValueNotifier<DateTime> _nowNotifier = ValueNotifier(DateTime.now());
  RealmMode _activeShowcaseMode = RealmMode.normal;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      _nowNotifier.value = DateTime.now();
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _nowNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDark;

    return RitmoPageScaffold(
      appBar: RitmoModuleAppBar.fromContext(
        context: context,
        title: 'سیستم مرجع کارت‌ها و پنجره‌ها (AI Guide)',
        showBackButton: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        children: [
          // ── هدر معرفی سیستم نئومورفیک و راهنمای هوش مصنوعی ──
          _buildHeroHeader(colors, isDark),
          const SizedBox(height: 20),

          // ── ۱. کارت مرجع شاهکار نئومورفیک (Master Reference Card) ──
          _buildSectionTitle(
            number: '۱',
            widgetClass: 'RitmoNeuMasterCard',
            title: 'هیرو کارت مرجع داشبورد (Master Hero Card)',
            usage: 'ویجت اصلی بالای داشبورد برای نمایش قلمروی فعال، وضعیت جاری شبانه‌روز، و تایم‌بلاک فعال.',
            features: 'دایال ۲۴ ساعته متصل، پیل حالت تعاملی (عادی/تمرکز/بی‌صدا)، بازه زمانی، تایمر معکوس ثانیه‌شمار و دکمه اکشن.',
            rule: 'همیشه از این ویجت برای هیرو کارت بالای داشبورد قلمرو و وضعیت شبانه‌روز استفاده شود.',
          ),
          const SizedBox(height: 10),

          _buildMasterReferenceCard(colors, isDark),
          const SizedBox(height: 24),

          // ── ۲. کارت‌های برجسته نئومورفیک داشبورد (Neumorphic Raised) ──
          _buildSectionTitle(
            number: '۲',
            widgetClass: 'RitmoCard.neumorphic',
            title: 'کارت برجسته داشبورد و اجزای اتمیک (Raised Card)',
            usage: 'ساختار پایه تمام کارت‌های ریتمویکیشن (روتین‌ها، نبض سلامت، تحلیل‌های روزانه و خلاصه داده‌ها).',
            features: 'سایه دوگانه متضاد در جهت نور ۱۳۵ درجه، فرورفتگی فیزیکی در زمان لمس (Depression Animation) و هپتیک ریتمو.',
            rule: 'از ویجت‌های کمکی RitmoCardHeader ،RitmoCardTile ،RitmoCardBadge و RitmoCardDivider درون این کارت استفاده کنید.',
          ),
          const SizedBox(height: 10),

          // کارت نمونه ویجت داشبورد با المان‌های اتمیک نئومورفیک
          RitmoCard.neumorphic(
            onTap: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('کارت نئومورفیک لمس شد (انیمیشن فرورفتگی + لرزش ریتمو)'),
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

          // ── ۳. کارت‌ها در حالت انتخاب نئومورفیک (Selected State) ──
          _buildSectionTitle(
            number: '۳',
            widgetClass: 'RitmoCard.neumorphic(isSelected: true)',
            title: 'وضعیت انتخاب‌شده و کارت‌های چندگزینه‌ای (Selected State)',
            usage: 'سلکتورهای چندگزینه‌ای، انتخاب فازهای چرخه، پلن‌های هفتگی، قلمروهای پیشنهادی و روزهای تقویم.',
            features: 'کادر رنگی با شفافیت بالا (Border @ 0.70) + هاله نوری درخشان بیرونی به رنگ پالت پویای انتخابی.',
            rule: 'در کارت‌های سلکشن، حتماً مقدار isSelected را با State صفحه هماهنگ کنید.',
          ),
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

          // ── ۴. کارت فرورفته نئومورفیک (Sunken Inset) ──
          _buildSectionTitle(
            number: '۴',
            widgetClass: 'RitmoCard.neumorphicSunken',
            title: 'سطوح و شیارهای فرورفته در بوم (Sunken Inset)',
            usage: 'فیلدهای ورودی متن، کادرهای یادداشت، نمایشگر جزئیات، شیارها و محفظه‌های اطلاعاتی مقعر.',
            features: 'سایه داخلی معکوس عمیق، گرادیان فرورفته و حس عمق واقعی درون بافت پس‌زمینه.',
            rule: 'برای بخش‌هایی که نقش ظرف محتوا (Container) دارند یا دریافت ورودی می‌کنند از Sunken استفاده شود.',
          ),
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

          // ── ۵. دکمه‌های نئومورفیک ۳ بعدی (Tactile 3D Buttons) ──
          _buildSectionTitle(
            number: '۵',
            widgetClass: 'RitmoNeuButton',
            title: 'دکمه‌های تعاملی ۳ بعدی فیزیکی (Tactile 3D Buttons)',
            usage: 'تمام دکمه‌های اکشن، افزایش/کاهش مقادیر، تأیید، بازنشانی و دکمه‌های کنترلی داخل کارت‌ها.',
            features: 'تغییر آنی وضعیت از برجسته (Raised) به فرورفته (Sunken) در زمان فشردن + فیدبک لمسی Haptic.',
            rule: 'جایگزین دکمه‌های تخت متریال؛ برای داشتن حس فیزیکی نئومورفیک همواره از RitmoNeuButton استفاده شود.',
          ),
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

          // ── ۶. نوار پیشرفت نئومورفیک فرورفته (Sunken Progress Bar) ──
          _buildSectionTitle(
            number: '۶',
            widgetClass: 'RitmoNeuProgressBar',
            title: 'نوار پیشرفت شیاردار با پرکننده نئونی (Sunken Progress Bar)',
            usage: 'نمایش درصد پیشرفت اهداف هفتگی، میزان انرژی، گذر زمان بازه و روتین‌های تکمیل‌شده.',
            features: 'شیار مقعر فرورفته عمیق، انیمیشن پر شدن نرم (TweenAnimationBuilder) و درخشش نئونی پرکننده.',
            rule: 'مقدار progress بین 0.0 تا 1.0 پاس داده شود و با showLabel عنوان و درصد فارسی نمایش یابد.',
          ),
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

          // ── ۷. کارت اسکلت لودینگ نئومورفیک (Card Skeleton) ──
          _buildSectionTitle(
            number: '۷',
            widgetClass: 'RitmoCardSkeleton',
            title: 'اسکلت لودینگ نئومورفیک با تنفس نوری (Loading Skeleton)',
            usage: 'حالت در حال بارگذاری (Loading State) تمام کارت‌های داده هنگام فراخوانی دیتابیس یا سرویس‌های هوش مصنوعی.',
            features: 'انیمیشن تنفس نوری Shimmer یکدست، حفظ ابعاد دقیق کارت واقعی و جلوگیری از هرگونه پرش بوم (Zero Layout Shift).',
            rule: 'قبل از آماده شدن دیتای کارت، همیشه به جای لودینگ گردان (Spinner)، اسکلت نئومورفیک متناظر را رندر کنید.',
          ),
          const SizedBox(height: 10),

          const RitmoCardSkeleton(height: 130),
          const SizedBox(height: 24),

          // ── ۸. کارت حالت خالی سه‌بعدی (Empty State Card) ──
          _buildSectionTitle(
            number: '۸',
            widgetClass: 'RitmoNeuEmptyCard',
            title: 'کارت وضعیت خالی و بدون داده (Empty State Card)',
            usage: 'هنگامی که لیست روتین‌ها، اهداف، قلمروها یا تاریخچه خالی است و داده‌ای برای نمایش وجود ندارد.',
            features: 'شیار دایره‌ای فرورفته با آیکون نرم، پیام راهنمای دوستانه و دکمه کال‌تو‌اکشن (CTA) برای ایجاد داده.',
            rule: 'از نمایش صفحات خالی سفید/خاکستری خودداری کنید؛ همیشه از این کارت همراه با اکشن افزودن استفاده شود.',
          ),
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

          // ── ۹. پنجره‌ها و شیت‌های مرجع ریتمو (Reference Glass Sheets & Windows) ──
          _buildSectionTitle(
            number: '۹',
            widgetClass: 'RitmoGlassSheet & Modals',
            title: 'پنجره‌ها و شیت‌های شیشه‌ای مرجع ریتمو (Reference Sheets)',
            usage: 'تنها روش استاندارد و مجاز باز کردن باتم‌شیت‌ها، دیالوگ‌ها و انتخابگرها در سراسر ریتمویکیشن.',
            features: 'بلور زنده اکوسیستم ریتمو (BackdropFilter)، هاله نوری پالت، دستگیره کشیدن به پایین و گوشه‌های گرد ۲۸ پیکسل.',
            rule: 'پروتکل تبدیل ۶ لایه شیت‌ها: ۱) اسکفولد باتم‌شیت شیشه‌ای شفاف، ۲) فیلدها و پیش‌نمایش‌های مقعر فرورفته (neumorphicSunken)، ۳) چیپ‌ها و انتخابگرهای نئومورفیک انتخابی (isSelected)، ۴) نوارهای پیشرفت فرورفته با اعداد فارسی (RitmoNeuProgressBar)، ۵) دکمه‌های لمسی ۳ بعدی (RitmoNeuButton)، ۶) دیالوگ‌های تایید خروج شیشه‌ای (RitmoGlassDialog).',
          ),
          const SizedBox(height: 10),

          _buildReferenceSheetsShowcase(colors, isDark),
          const SizedBox(height: 24),

          // ── ۱۰. هدر کپسولی شناور ریتمو و اسکفولد چندتبی مرجع (Apple Morphing Header & Tabbed Scaffold) ──
          _buildSectionTitle(
            number: '۱۰',
            widgetClass: 'RitmoTabbedMorphingScaffold & Header',
            title: 'اسکفولد و هدر داینامیک کپسولی ریتمو (Morphing Header Scaffold)',
            usage: 'الگوی استاندارد و اجباری برای تمامی صفحات دارای تب (تب‌بار کپسولی شیشه‌ای، اسکرول مستقل هر تب و انیمیشن انتقال ۳۰۰ میلی‌ثانیه‌ای).',
            features: 'ترنزیشن فیزیکی کپسولی ۳۰۰ میلی‌ثانیه با منحنی easeOutCubic، واکنش اسکرول سریع (Quick-Return)، تفکیک کامل آفست اسکرول تب‌ها، و کشسانی اووراسکرول.',
            rule: 'برای تمام صفحات چندتبی ریتمو منحصراً از RitmoTabbedMorphingScaffold استفاده شود و از نوشتن کنترلرهای تکراری خودداری گردد.',
          ),
          const SizedBox(height: 10),

          _buildTabbedMorphingHeaderShowcase(colors, isDark),
          const SizedBox(height: 24),

          // ── ۱۱. اسکفولد تک‌صفحه‌ای مرجع با هدر مورفینگ ریتمو (Single Morphing Scaffold) ──
          _buildSectionTitle(
            number: '۱۱',
            widgetClass: 'RitmoSingleMorphingScaffold',
            title: 'اسکفولد تک‌صفحه‌ای با هدر مورفینگ ریتمو (Single Morphing Scaffold)',
            usage: 'الگوی استاندارد برای تمام صفحات تک‌صفحه‌ای و طویل (مانند تنظیمات، سیستم‌ها و داشبورد اصلی امروز).',
            features: 'محاسبه خودکار پدینگ هوشمند، مدیریت ری‌اکتیو آفست اسکرول، پشتیبانی از آواتار/leading، دکمه‌های اکشن، FAB و Pull-To-Refresh.',
            rule: 'برای صفحات تک‌صفحه‌ای فاقد تب، منحصراً از RitmoSingleMorphingScaffold استفاده شود تا ساختار Stack و اسکرول یکدست باشد.',
          ),
          const SizedBox(height: 10),

          _buildSingleMorphingHeaderShowcase(colors, isDark),
          const SizedBox(height: 24),

          // ── ۱۲. دیالوگ شیشه‌ای استاندارد (RitmoGlassDialog) ──
          _buildSectionTitle(
            number: '۱۲',
            widgetClass: 'RitmoGlassDialog',
            title: 'دیالوگ شیشه‌ای و پنجره تأییدیه کانونی (Glass Dialog)',
            usage: 'برای دیالوگ‌های تایید خروج، حذف، اخطار، ریست اطلاعات و پیام‌های متمرکز کاربر.',
            features: 'بلور زنده عمیق (sigma 20)، هاله و لبه‌های شیشه‌ای با انعکاس نور، دکمه‌های ۳ بعدی و فیدبک هپتیک ریتمو.',
            rule: 'استفاده از AlertDialog پیش‌فرض مات متریال ممنوع است؛ همیشه از RitmoGlassDialog.show(...) استفاده کنید.',
          ),
          const SizedBox(height: 10),

          _buildGlassDialogShowcase(colors, isDark),
          const SizedBox(height: 24),

          // ── ۱۳. کنترل و تب‌های چندگزینه‌ای مایع ریتمو (Apple Liquid Glass Segmented Control) ──
          _buildSectionTitle(
            number: '۱۳',
            widgetClass: 'RitmoGlassSegmentedControl',
            title: 'کنترل چندگزینه‌ای و تب‌بار مایع ریتمو (Segmented Control)',
            usage: 'سوئیچ بین بازه‌های زمانی (روز/هفته/ماه)، فیلترهای لیست و انتخابگرهای چندحالته ماژول‌ها.',
            features: 'شیار ترنسلوسنت فرورفته، کپسول شناور برجسته با هاله نوری اکسنت، انیمیشن فیزیکی لغزش نرم و هپتیک انتخاب.',
            rule: 'برای تمام سوییچ‌های ۲ تا ۴ حالته افقی، از RitmoGlassSegmentedControl استفاده شود.',
          ),
          const SizedBox(height: 10),

          _buildSegmentedControlShowcase(colors, isDark),
          const SizedBox(height: 24),

          // ── ۱۴. نشانگرها و بج‌های وضعیت درخشان (Luminous Status Indicators) ──
          _buildSectionTitle(
            number: '۱۴',
            widgetClass: 'RitmoLuminousDot & RitmoStatusBadge',
            title: 'نشانگرها و بج‌های وضعیت درخشان نئونی (Luminous Badges)',
            usage: 'نمایش وضعیت زنده، اتصال دستیار هوش مصنوعی، چرخه‌های فعال و سامانه‌های در حال اجرا.',
            features: 'نقطه نئونی با هاله نورانی دو لایه (Dual Glow) و کپسول کریستالی Ultra-Glass با لبه شیشه‌ای.',
            rule: 'برای نمایش وضعیت‌های آنلاین/آفلاین/فعال همیشه از این پریمتیوهای استاندارد استفاده شود.',
          ),
          const SizedBox(height: 10),

          _buildLuminousBadgeShowcase(colors, isDark),
          const SizedBox(height: 36),
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
        crossAxisAlignment: CrossAxisAlignment.start,
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
                  'مرجع استاندارد کارت‌ها و پنجره‌های ریتمو',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w900,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'راهنمای معماری برای هوش مصنوعی و توسعه‌دهندگان: از این کامپوننت‌ها به عنوان الگوی رسمی و قطعی (Single Source of Truth) در تمام ماژول‌ها و صفحات استفاده کنید.',
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.5,
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

  Widget _buildSectionTitle({
    required String number,
    required String widgetClass,
    required String title,
    required String usage,
    required String features,
    String? rule,
  }) {
    final colors = context.colors;
    final isDark = context.isDark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: isDark ? 0.08 : 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colors.primary.withValues(alpha: isDark ? 0.22 : 0.12),
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ردیف عنوان بخش و شماره
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                decoration: BoxDecoration(
                  color: colors.primary,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  'بخش $number',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Vazirmatn',
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Vazirmatn',
                    color: colors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // بج نام ویجت و کلاس با آیکون کد
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: isDark ? 0.18 : 0.10),
              borderRadius: BorderRadius.circular(7),
              border: Border.all(
                color: colors.primary.withValues(alpha: isDark ? 0.35 : 0.20),
                width: 0.8,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  CupertinoIcons.chevron_left_slash_chevron_right,
                  size: 11,
                  color: isDark ? Color.lerp(colors.primary, Colors.white, 0.70)! : colors.primary,
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    widgetClass,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w800,
                      color: isDark ? Color.lerp(colors.primary, Colors.white, 0.75)! : colors.primary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // توضیحات و راهنمای هوش مصنوعی
          RichText(
            text: TextSpan(
              style: TextStyle(
                fontSize: 11,
                fontFamily: 'Vazirmatn',
                height: 1.55,
                color: colors.textSecondary,
              ),
              children: [
                TextSpan(
                  text: '📌 موارد استفاده (AI Guidance): ',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: colors.textPrimary,
                  ),
                ),
                TextSpan(text: '$usage\n'),
                TextSpan(
                  text: '⚙️ ویژگی‌ها و رفتار: ',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: colors.textPrimary,
                  ),
                ),
                TextSpan(text: features),
                if (rule != null) ...[
                  TextSpan(
                    text: '\n🛡️ قانون طراحی: ',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: colors.primary,
                    ),
                  ),
                  TextSpan(
                    text: rule,
                    style: TextStyle(
                      color: isDark ? Color.lerp(colors.primary, Colors.white, 0.70)! : colors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
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
      gaugeWidget: RepaintBoundary(
        child: ValueListenableBuilder<DateTime>(
          valueListenable: _nowNotifier,
          builder: (context, currentNow, _) {
            return Realm24hDial(
              size: 116,
              activeZoneId: 'sleep',
              activeZoneColor: activeColor,
              activeZoneIcon: '🌙',
              activeZoneName: 'خواب و ریکاوری',
              schedules: sampleSchedules,
              realms: sampleRealms,
              isDarkMode: isDark,
              now: currentNow,
              showHourLabels: false,
            );
          },
        ),
      ),
      actionButtonText: 'مدیریت قلمرو',
      onActionTap: () => _openShowcase24hSheet(context, colors, isDark),
      onTap: () => _openShowcase24hSheet(context, colors, isDark),
    );
  }

  Widget _buildReferenceSheetsShowcase(RitmoColors colors, bool isDark) {
    return Column(
      children: [
        // کارت جامع راهنمای پروتکل ۶ لایه تبدیل پنجره‌ها و شیت‌ها
        RitmoCard.neumorphicSunken(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(CupertinoIcons.checkmark_shield_fill, size: 18, color: colors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'پروتکل ۶ لایه تبدیل کامل شیت‌ها و پنجره‌ها (AI Transformation Guide)',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'Vazirmatn',
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'هنگام اتصال یا به‌روزرسانی هر شیت در ماژول‌ها، هوش مصنوعی و توسعه‌دهنده موظف به اجرای تمام ۶ لایه زیر هستند:',
                style: TextStyle(fontSize: 11.5, color: colors.textSecondary, height: 1.5),
              ),
              const SizedBox(height: 10),
              _buildProtocolStep(
                number: '۱',
                title: 'اسکفولد شیشه‌ای و دستگیره (Host Scaffolding)',
                desc: 'استفاده از isScrollControlled: true و backgroundColor: Colors.transparent با روت RitmoGlassSheet (دستگیره ریتمو و گوشه ۲۸pt).',
                colors: colors,
              ),
              _buildProtocolStep(
                number: '۲',
                title: 'چاهک‌های فرورفته (Concave Wells)',
                desc: 'تبدیل فیلدهای ورودی، یادداشت‌ها و پیش‌نمایش‌های زنده به RitmoCard.neumorphicSunken.',
                colors: colors,
              ),
              _buildProtocolStep(
                number: '۳',
                title: 'سلکتورها و چیپ‌ها (Selectors & Chips)',
                desc: 'تبدیل انتخابگرهای سطح و چیپ‌های زمان به RitmoCard.neumorphic(isSelected) با RitmoHaptics.selection().',
                colors: colors,
              ),
              _buildProtocolStep(
                number: '۴',
                title: 'نوارهای پیشرفت و وضعیت (Progress & Badges)',
                desc: 'استفاده از RitmoNeuProgressBar (با اعداد فارسی) و بج‌های کانونی RitmoCardBadge.',
                colors: colors,
              ),
              _buildProtocolStep(
                number: '۵',
                title: 'دکمه‌های لمسی ۳ بعدی (Tactile Actions)',
                desc: 'استفاده از RitmoNeuButton یا RitmoPrimaryButton با فیدبک فیزیکی و RitmoHaptics.tap().',
                colors: colors,
              ),
              _buildProtocolStep(
                number: '۶',
                title: 'تأییدیه تغییرات ذخیره‌نشده (Unsaved Guards)',
                desc: 'جایگزینی هرگونه AlertDialog با RitmoGlassDialog.show(...) همراه با آیکون و دکمه‌های ۳ بعدی.',
                colors: colors,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // کارت قوانین فیزیک و رفتارهای اکوسیستم ریتمو برای پنجره‌ها
        RitmoCard.neumorphic(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(CupertinoIcons.device_phone_portrait, size: 18, color: colors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'قوانین فیزیک و رفتار پنجره‌ها در اکوسیستم ریتمو (Apple HIG Rules)',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'Vazirmatn',
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'رفتارهای دینامیک و فیزیکی که تمام شیت‌ها و پنجره‌ها ملزم به رعایت آن هستند:',
                style: TextStyle(fontSize: 11.5, color: colors.textSecondary, height: 1.5),
              ),
              const SizedBox(height: 10),
              _buildAppleRuleRow(
                icon: CupertinoIcons.arrow_up_left_arrow_down_right,
                title: 'دتنت‌های دوگانه (۶۰٪ به ۹۰٪/۹۵٪)',
                desc: 'باز شدن اولیه در ارتفاع ۶۰٪ (Medium Detent) و گسترش نرم به ۹۲٪-۹۵٪ (Large Detent) با درگ به بالا یا اسکرول محتوا.',
                colors: colors,
              ),
              _buildAppleRuleRow(
                icon: CupertinoIcons.keyboard,
                title: 'انطباق خودکار با کیبورد (Keyboard Adaptive)',
                desc: 'به محض باز شدن کیبورد، ارتفاع شیت به طور خودکار به حداکثر (Large Detent) افزایش می‌یابد تا فیلد ورودی و دکمه‌ها بالای کیبورد قرار گیرند.',
                colors: colors,
              ),
              _buildAppleRuleRow(
                icon: CupertinoIcons.square_stack_3d_up,
                title: 'پنجره روی پنجره (Stacked Modals)',
                desc: 'هنگام باز شدن شیت ثانویه (مانند انتخابگر)، شیت زیرین با افکت Card Stacking مقداری کوچک و مات می‌شود (Scale down به ۰.۹۴) تا از تداخل بصری جلوگیری شود.',
                colors: colors,
              ),
              _buildAppleRuleRow(
                icon: CupertinoIcons.hand_draw,
                title: 'بسته شدن طبیعی با اسکرول به پایین (Scroll-to-Dismiss)',
                desc: 'هنگامی که محتوا در بالاترین نقطه (offset == 0) قرار دارد، ادامه درگ/اسکرول به سمت پایین، پنجره را به نرمی می‌بندد (مگر در حالت تغییرات ذخیره‌نشده).',
                colors: colors,
              ),
              _buildAppleRuleRow(
                icon: CupertinoIcons.square_arrow_left,
                title: 'چیدمان دکمه‌های هدر بالای پنجره (Top Action Buttons)',
                desc: 'دکمه انصراف/بستن در لبه آغازین (راست در فارسی) و دکمه تایید/ذخیره در لبه پایانی (چپ در فارسی)؛ در فرآیندهای چندمرحله‌ای، دکمه راست در مراحل بعد به «بازگشت» تبدیل می‌شود.',
                colors: colors,
              ),
              _buildAppleRuleRow(
                icon: CupertinoIcons.shield_lefthalf_fill,
                title: 'قانون طلایی انتخابگرها (The Iron Rule of Pickers)',
                desc: 'شیت‌های انتخابگر (RitmoPickerSheet) هرگز مستقیماً داده‌ای را در دیتابیس ثبت یا ویرایش نمی‌کنند؛ صرفاً مقدار انتخابی (Future<T?>) را به والد بازمی‌گردانند.',
                colors: colors,
              ),
              _buildAppleRuleRow(
                icon: CupertinoIcons.sparkles,
                title: 'قالب‌های سریع فرم (Quick Preset Templates)',
                desc: 'قرارگیری کپسول‌های آماده در بالای فرم‌ها برای پر کردن خودکار تمام فیلدها با یک تپ (کاهش بار شناختی و خطای کاربر).',
                colors: colors,
              ),
              _buildAppleRuleRow(
                icon: CupertinoIcons.color_filter,
                title: 'انتخابگرهای چشمی درون‌فرمی (Inline Visual Pickers)',
                desc: 'انتخاب رنگ و آیکون به‌صورت نوارهای اسکرول افقی درون خود فرم همراه با پیش‌نمایش زنده، بدون باز کردن لایه‌های تودرتوی اضافی.',
                colors: colors,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _buildSheetLaunchTile(
          title: '[RitmoGlassSheet] شیت انتخاب حالت قلمرو',
          subtitle: 'الگوی استاندارد انتخاب وضعیت‌های سه‌گانه (عادی، تمرکز، بی‌صدا) با هپتیک',
          badge: 'پنجره اصلی',
          icon: CupertinoIcons.slider_horizontal_3,
          color: colors.primary,
          onTap: () => _openShowcaseModeSelectionSheet(context, colors, isDark),
        ),
        const SizedBox(height: 10),
        _buildSheetLaunchTile(
          title: '[Showcase24hOverviewSheet] شیت مرجع داشبورد و سنجه‌های تعاملی',
          subtitle: 'لایه‌بندی استاندارد ریتمو با سنجه تعاملی، نوار توازن شاخص‌ها و ماژول‌های کارت',
          badge: 'داشبورد مرجع',
          icon: CupertinoIcons.rectangle_grid_2x2_fill,
          color: const Color(0xFF10B981),
          onTap: () => _openShowcase24hSheet(context, colors, isDark),
        ),
        const SizedBox(height: 10),
        _buildSheetLaunchTile(
          title: '[RitmoPickerSheet] شیت انتخابگر عمومی گزینه‌ها',
          subtitle: 'انتخابگر جست‌وجوپذیر جنریک برای انتخاب تک‌موردی گزینه‌ها با آیکون',
          badge: 'انتخابگر',
          icon: CupertinoIcons.list_bullet_below_rectangle,
          color: const Color(0xFF8B5CF6),
          onTap: () => _openShowcasePickerSheet(context),
        ),
        const SizedBox(height: 10),
        _buildSheetLaunchTile(
          title: '[ShowcaseRealmEditFormSheet] شیت مرجع فرم استاندارد ورود داده',
          subtitle: 'فرم استاندارد ورودی‌های ریتمو با پالت توکن‌ها، آیکون، سطوح اولویت و گارد خروج',
          badge: 'فرم استاندارد',
          icon: CupertinoIcons.square_pencil_fill,
          color: const Color(0xFFEC4899),
          onTap: () => _openShowcaseEditFormSheet(context),
        ),
      ],
    );
  }

  Widget _buildProtocolStep({
    required String number,
    required String title,
    required String desc,
    required RitmoColors colors,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              number,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: colors.primary,
                fontFamily: 'Vazirmatn',
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(fontSize: 11, fontFamily: 'Vazirmatn', height: 1.45, color: colors.textSecondary),
                children: [
                  TextSpan(
                    text: '$title: ',
                    style: TextStyle(fontWeight: FontWeight.w800, color: colors.textPrimary),
                  ),
                  TextSpan(text: desc),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppleRuleRow({
    required IconData icon,
    required String title,
    required String desc,
    required RitmoColors colors,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 14, color: colors.primary),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(fontSize: 11, fontFamily: 'Vazirmatn', height: 1.45, color: colors.textSecondary),
                children: [
                  TextSpan(
                    text: '$title: ',
                    style: TextStyle(fontWeight: FontWeight.w800, color: colors.textPrimary),
                  ),
                  TextSpan(text: desc),
                ],
              ),
            ),
          ),
        ],
      ),
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
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'Vazirmatn',
                          color: colors.textPrimary,
                        ),
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
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'Vazirmatn',
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
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
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Leading (Right in RTL): Cancel action
                            TextButton(
                              onPressed: () {
                                RitmoHaptics.tap();
                                Navigator.of(sheetContext).pop();
                              },
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                'انصراف',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  fontFamily: 'Vazirmatn',
                                  color: colors.textSecondary,
                                ),
                              ),
                            ),
                            Text(
                              'حالت قلمرو «خواب و ریکاوری»',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                fontFamily: 'Vazirmatn',
                                color: colors.textPrimary,
                              ),
                            ),
                            const SizedBox(width: 44),
                          ],
                        ),
                        const SizedBox(height: 18),
                        _buildShowcaseModeOptionItem(
                          title: 'حالت عادی',
                          subtitle: 'همه روتین‌ها بدون محدودیت اجرا می‌شوند',
                          mode: RealmMode.normal,
                          isSelected: _activeShowcaseMode == RealmMode.normal,
                          icon: CupertinoIcons.sparkles,
                          color: activeColor,
                          onSelect: () {
                            RitmoHaptics.selection();
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
                            RitmoHaptics.selection();
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
                            RitmoHaptics.selection();
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

    return RitmoCard.neumorphic(
      isSelected: isSelected,
      onTap: onSelect,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
            ),
        ],
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
      builder: (context) => Showcase24hOverviewSheet(
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
      backgroundColor: Colors.transparent,
      builder: (_) => ShowcaseRealmEditFormSheet(
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

  Widget _buildTabbedMorphingHeaderShowcase(RitmoColors colors, bool isDark) {
    return RitmoCard.neumorphic(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RitmoCardHeader(
            title: 'موتور هماهنگ‌کننده چندتبی ریتمو',
            subtitle: 'RitmoTabbedMorphingScaffold (Single Source of Truth)',
            icon: CupertinoIcons.rectangle_stack_badge_person_crop,
            iconColor: colors.primary,
            trailing: RitmoCardBadge(
              label: 'مرجع رسمی ریتمو',
              color: colors.primary,
              icon: CupertinoIcons.sparkles,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'این ساختار مادر تمام جزئیات فیزیک اسکرول، محاسبه آفست اختصاصی هر تب، همگام‌سازی کپسول هدر، انیمیشن انتقال ۳۰۰ میلی‌ثانیه‌ای (Curves.easeOutCubic) و رفتارهای واکنشی Quick-Return را به شکل ۱۰۰٪ متمرکز پیاده‌سازی می‌کند.',
            style: TextStyle(
              fontSize: 12.5,
              height: 1.6,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildFeatureTag('انیمیشن مورف ۳۰۰ms', colors),
              _buildFeatureTag('آستانه ۲۸px کوئیک‌ریترن', colors),
              _buildFeatureTag('تفکیک آفست هر تب', colors),
              _buildFeatureTag('فیزیک کشسانی فنری ریتمو', colors),
              _buildFeatureTag('سازگاری با IndexedStack', colors),
            ],
          ),
          const SizedBox(height: 16),
          RitmoNeuButton(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const _TabbedMorphingHeaderDemoScreen(),
                ),
              );
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  CupertinoIcons.play_circle_fill,
                  size: 20,
                  color: colors.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'اجرای دمو زنده و سندباکس تعاملی هدر',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: colors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSingleMorphingHeaderShowcase(RitmoColors colors, bool isDark) {
    return RitmoCard.neumorphic(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RitmoCardHeader(
            title: 'داربست تک‌صفحه‌ای با هدر مورفینگ ریتمو',
            subtitle: 'هسته متمرکز مدیریت اسکرول و هدر شیشه‌ای',
            icon: CupertinoIcons.rectangle_fill_on_rectangle_angled_fill,
            iconColor: colors.primary,
          ),
          const SizedBox(height: 12),
          const Text(
            'این داربست تمام پیچیدگی‌های لایه‌بندی Stack، ردیابی آفست اسکرول، پدینگ بالای محتوا و هماهنگی با انیمیشن‌های فیزیکی ریتمو را برای صفحات تک‌صفحه‌ای حذف می‌کند.',
            style: TextStyle(fontSize: 13, height: 1.6),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildFeatureTag('محاسبه هوشمند پدینگ بالا', colors),
              _buildFeatureTag('پشتیبانی از Pull-To-Refresh', colors),
              _buildFeatureTag('پشتیبانی از آواتار و Leading', colors),
              _buildFeatureTag('سازگاری با FAB و اکشن‌ها', colors),
            ],
          ),
          const SizedBox(height: 16),
          RitmoNeuButton(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const _SingleMorphingHeaderDemoScreen(),
                ),
              );
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  CupertinoIcons.play_circle_fill,
                  size: 20,
                  color: colors.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'اجرای دمو زنده اسکفولد تک‌صفحه‌ای',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: colors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassDialogShowcase(RitmoColors colors, bool isDark) {
    return RitmoCard.neumorphic(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RitmoCardHeader(
            title: 'دیالوگ‌های شیشه‌ای و تأییدیه هوشمند',
            subtitle: 'RitmoGlassDialog (Single Source of Truth)',
            icon: CupertinoIcons.shield_lefthalf_fill,
            iconColor: colors.primary,
            trailing: RitmoCardBadge(
              label: 'بلور زنده sigma 20',
              color: colors.primary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'این دیالوگ به عنوان جایگزین قطعی AlertDialogهای خام متریال، با انیمیشن ورود، بلور عمیق شیشه‌ای و دکمه‌های ۳ بعدی رندر می‌شود.',
            style: TextStyle(
              fontSize: 12.5,
              height: 1.6,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: RitmoNeuButton(
                  onTap: () async {
                    final res = await RitmoGlassDialog.show(
                      context,
                      title: 'تأیید اقدام مهم',
                      content: 'آیا مایل به ذخیره‌سازی و اعمال تغییرات در سیستم هستید؟',
                      confirmLabel: 'تأیید و ذخیره',
                      cancelLabel: 'انصراف',
                      icon: CupertinoIcons.checkmark_seal_fill,
                    );
                    if (!mounted || res == null) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(res ? 'اقدام با موفقیت تأیید شد ✅' : 'اقدام لغو گردید ❌'),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(CupertinoIcons.checkmark_shield, size: 16, color: colors.primary),
                      const SizedBox(width: 6),
                      Text(
                        'دیالوگ تأیید',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: colors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: RitmoNeuButton(
                  onTap: () async {
                    final res = await RitmoGlassDialog.show(
                      context,
                      title: 'حذف اطلاعات و بازنشانی',
                      content: 'این عملیات غیرقابل بازگشت است. آیا از حذف دائمی این مورد اطمینان دارید؟',
                      confirmLabel: 'حذف دائمی',
                      cancelLabel: 'انصراف',
                      isDestructive: true,
                      icon: CupertinoIcons.trash_fill,
                    );
                    if (!mounted || res == null) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(res ? 'اطلاعات با موفقیت حذف شد 🗑️' : 'حذف لغو شد'),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(CupertinoIcons.trash, size: 16, color: colors.error),
                      const SizedBox(width: 6),
                      Text(
                        'دیالوگ هشدار/حذف',
                        style: TextStyle(
                          fontSize: 12.5,
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
          const SizedBox(height: 10),
          RitmoNeuButton(
            onTap: () async {
              final res = await RitmoGlassActionSheet.showDiscard(
                context: context,
                title: 'تغییرات ذخیره نشده‌اند',
                message: 'آیا از خروج و حذف تغییرات فرم اطمینان دارید؟',
                discardLabel: 'حذف تغییرات',
                continueEditingLabel: 'ادامه ویرایش',
              );
              if (!mounted || res == null) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(res ? 'تغییرات با موفقیت حذف شدند 🗑️' : 'ویرایش ادامه یافت ✍️'),
                  duration: const Duration(seconds: 1),
                ),
              );
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.square_stack_3d_up, size: 16, color: colors.warning),
                const SizedBox(width: 6),
                Text(
                  'اکشن‌شیت تایید خروج ریتمو (Action Sheet از پایین)',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: colors.warning,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentedControlShowcase(RitmoColors colors, bool isDark) {
    return RitmoCard.neumorphic(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RitmoCardHeader(
            title: 'کنترل چندگزینه‌ای مایع ریتمو',
            subtitle: 'RitmoGlassSegmentedControl (Liquid Glass)',
            icon: CupertinoIcons.square_split_2x1,
            iconColor: colors.primary,
            trailing: RitmoCardBadge(
              label: 'ترنسلوسنت + هپتیک',
              color: colors.primary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'شیار محو ترنسلوسنت با پیل متحرک نوری شناور و فیزیک انیمیشن لغزش نرم ریتمو.',
            style: TextStyle(
              fontSize: 12.5,
              height: 1.6,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          RitmoGlassSegmentedControl<int>(
            selectedIndex: _selectedSegmentIndex,
            onTabChanged: (i) {
              setState(() => _selectedSegmentIndex = i);
            },
            items: const [
              RitmoTabItem(
                title: 'روزانه',
                icon: CupertinoIcons.calendar_today,
                value: 0,
              ),
              RitmoTabItem(
                title: 'هفتگی',
                icon: CupertinoIcons.calendar,
                value: 1,
              ),
              RitmoTabItem(
                title: 'ماهانه',
                icon: CupertinoIcons.calendar_badge_plus,
                value: 2,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLuminousBadgeShowcase(RitmoColors colors, bool isDark) {
    return RitmoCard.neumorphic(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RitmoCardHeader(
            title: 'نشانگرها و بج‌های وضعیت درخشان',
            subtitle: 'RitmoLuminousDot & RitmoStatusBadge',
            icon: CupertinoIcons.bolt_horizontal_circle_fill,
            iconColor: colors.primary,
            trailing: const RitmoCardBadge(
              label: 'Neon Dual-Glow',
              color: Color(0xFF10B981),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'نقطه‌های نئونی با هاله نورانی دو لایه برای نمایش بلادرنگ وضعیت سیستم‌ها و هوش مصنوعی.',
            style: TextStyle(
              fontSize: 12.5,
              height: 1.6,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              RitmoStatusBadge(
                label: 'هوش مصنوعی فعال',
                color: colors.primary,
                onTap: () {},
              ),
              const RitmoStatusBadge(
                label: 'سامانه متصل',
                color: Color(0xFF10B981),
              ),
              const RitmoStatusBadge(
                label: 'در حال شارژ انرژی',
                color: Color(0xFFF59E0B),
              ),
              RitmoStatusBadge(
                label: 'حالت اضطراری',
                color: colors.error,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureTag(String label, RitmoColors colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: colors.primary.withValues(alpha: 0.2),
          width: 0.8,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: colors.primary,
        ),
      ),
    );
  }
}

/// صفحه دمو و سندباکس تعاملی برای تست زنده RitmoTabbedMorphingScaffold
class _TabbedMorphingHeaderDemoScreen extends StatelessWidget {
  const _TabbedMorphingHeaderDemoScreen();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return RitmoTabbedMorphingScaffold(
      title: 'دموی هدر کپسولی ریتمو',
      subtitle: 'تست زنده انیمیشن ۳۰۰ms مورف و اسکرول سریع',
      actions: [
        RitmoVibrancyActionButton(
          icon: CupertinoIcons.sparkles,
          iconColor: colors.primary,
          tooltip: 'اکشن نمونه',
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('دکمه اکشن هوش مصنوعی لمس شد')),
            );
          },
        ),
      ],
      tabItems: const [
        RitmoTabItem(
          title: 'کاوش و تحلیل',
          icon: CupertinoIcons.chart_bar_alt_fill,
          value: 0,
        ),
        RitmoTabItem(
          title: 'آمار زنده',
          icon: CupertinoIcons.waveform_path_ecg,
          value: 1,
        ),
        RitmoTabItem(
          title: 'تنظیمات نمونه',
          icon: CupertinoIcons.gear_alt_fill,
          value: 2,
        ),
      ],
      tabBuilders: [
        // تب اول: لیست بلند برای اسکرول عمیق
        (ctx, scrollController) => ListView.builder(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(14, 190, 14, 80),
              itemCount: 20,
              itemBuilder: (ctx, i) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: RitmoCard.neumorphic(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: colors.primary.withValues(alpha: 0.2),
                      child: Text(
                        PersianDigits.toFa((i + 1).toString()),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: colors.primary,
                        ),
                      ),
                    ),
                    title: Text('کارت تحلیلی شماره ${PersianDigits.toFa((i + 1).toString())}'),
                    subtitle: const Text('برای جمع شدن هدر به سمت پایین اسکرول کنید'),
                  ),
                ),
              ),
            ),

        // تب دوم: اسکرول کوتاه در بالای صفحه
        (ctx, scrollController) => ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(14, 190, 14, 80),
              children: [
                RitmoCard.neumorphic(
                  child: Column(
                    children: [
                      RitmoCardHeader(
                        title: 'وضعیت در بالای صفحه (Resting)',
                        subtitle: 'این تب در بالای صفحه قرار دارد',
                        icon: CupertinoIcons.info_circle_fill,
                        iconColor: colors.success,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'اگر در تب اول اسکرول کرده باشید و به این تب بیایید، هدر با انیمیشن روان ۳۰۰ میلی‌ثانیه‌ای به حالت باز (Expanded) تبدیل می‌شود.',
                        style: TextStyle(fontSize: 13, height: 1.6),
                      ),
                    ],
                  ),
                ),
              ],
            ),

        // تب سوم: تنظیمات نمونه
        (ctx, scrollController) => ListView.builder(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(14, 190, 14, 80),
              itemCount: 8,
              itemBuilder: (ctx, i) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: RitmoCard.neumorphic(
                  child: ListTile(
                    leading: const Icon(CupertinoIcons.slider_horizontal_3),
                    title: Text('تنظیم شماره ${PersianDigits.toFa((i + 1).toString())}'),
                    trailing: const Icon(CupertinoIcons.chevron_left, size: 16),
                  ),
                ),
              ),
            ),
      ],
    );
  }
}

/// صفحه دمو و سندباکس تعاملی برای تست زنده RitmoSingleMorphingScaffold
class _SingleMorphingHeaderDemoScreen extends StatelessWidget {
  const _SingleMorphingHeaderDemoScreen();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return RitmoSingleMorphingScaffold(
      title: 'دموی اسکفولد تک‌صفحه‌ای',
      subtitle: 'هدر مورفینگ ریتمو، پدینگ خودکار و اسکرول پیوسته',
      onBack: () => Navigator.pop(context),
      onRefresh: () async {
        await Future.delayed(const Duration(milliseconds: 1200));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('داده‌ها به‌روزرسانی شدند')),
          );
        }
      },
      actions: [
        RitmoVibrancyActionButton(
          icon: CupertinoIcons.sparkles,
          iconColor: colors.primary,
          tooltip: 'دستیار هوشمند',
          onTap: () {},
        ),
      ],
      bodyBuilder: (context, scrollController, topPadding) {
        return ListView.builder(
          controller: scrollController,
          padding: EdgeInsets.fromLTRB(14, topPadding, 14, 80),
          itemCount: 25,
          itemBuilder: (ctx, i) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: RitmoCard.neumorphic(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: colors.primary.withValues(alpha: 0.15),
                  child: Text(
                    PersianDigits.toFa((i + 1).toString()),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: colors.primary,
                    ),
                  ),
                ),
                title: Text('آیتم تک‌صفحه‌ای شماره ${PersianDigits.toFa((i + 1).toString())}'),
                subtitle: const Text('اسکرول کنید تا انیمیشن مورفینگ هدر را مشاهده کنید'),
              ),
            ),
          ),
        );
      },
    );
  }
}




