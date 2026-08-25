import 'package:shamsi_date/shamsi_date.dart';
import 'package:ritmo/features/worship/logic/hijri_calendar.dart';
import 'package:ritmo/features/worship/models/worship_models.dart';

enum WorshipOccasionCategory {
  celebration, // ولادت / عید (🎉/☀️)
  mourning,    // شهادت / وفات / سوگواری (🏴/🌙)
  worshipDeed, // اعمال خاص / شب قدر / عرفه (✨/🤲)
  fasting,     // روزه واجب یا مستحبی (🌙/🌾)
  national,    // مناسبت ملی / تقویم رسمی (🇮🇷/🏛️)
}

class WorshipOccasion {
  const WorshipOccasion({
    required this.title,
    required this.category,
    this.description,
    this.recommendedAmal,
    this.isReligiousHoliday = false,
    bool? isHoliday,
  }) : _customIsHoliday = isHoliday;

  final String title;
  final WorshipOccasionCategory category;
  final String? description;
  final String? recommendedAmal;
  final bool isReligiousHoliday;
  final bool? _customIsHoliday;

  bool get isHoliday => _customIsHoliday ?? isReligiousHoliday;
}

class WorshipOccasionsData {
  const WorshipOccasionsData._();

  /// Map of Hijri month-day (e.g. "1-10") to list of worship occasions.
  /// ONLY worship/religious occasions. Secular/national events are omitted.
  static final Map<String, List<WorshipOccasion>> hijriOccasions = {
    // 1. Muharram
    '1-1': [
      const WorshipOccasion(
        title: 'آغاز سال نو هجری قمری (اول محرم)',
        category: WorshipOccasionCategory.worshipDeed,
        recommendedAmal: 'زیارت عاشورا، نماز اول ماه، روزه گرفتن در اول محرم',
      )
    ],
    '1-9': [
      const WorshipOccasion(
        title: 'تاسوعای حسینی (روز عزای آل محمد)',
        category: WorshipOccasionCategory.mourning,
        recommendedAmal: 'زیارت عاشورا، امساک تا عصر، عزاداری و اطعام حسینی',
        isReligiousHoliday: true,
      )
    ],
    '1-10': [
      const WorshipOccasion(
        title: 'عاشورای حسینی (شهادت سیدالشهدا ع)',
        category: WorshipOccasionCategory.mourning,
        recommendedAmal: 'زیارت عاشورا، زیارت وارث، امساک تا عصر، پرهیز از کار دنیا',
        isReligiousHoliday: true,
      )
    ],
    '1-12': [
      const WorshipOccasion(
        title: 'شهادت امام سجاد (ع)',
        category: WorshipOccasionCategory.mourning,
        recommendedAmal: 'قرائت صحیفه سجادیه و زیارت امام سجاد (ع)',
      )
    ],
    '1-25': [
      const WorshipOccasion(
        title: 'شهادت امام زین‌العابدین ع (به روایتی)',
        category: WorshipOccasionCategory.mourning,
        recommendedAmal: 'قرائت دعای مکارم الاخلاق و صحیفه سجادیه',
      )
    ],

    // 2. Safar
    '2-5': [
      const WorshipOccasion(
        title: 'شهادت حضرت رقیه (س) در خرابه شام',
        category: WorshipOccasionCategory.mourning,
        recommendedAmal: 'زیارت حضرت رقیه (س) و اقامه عزاداری',
      )
    ],
    '2-7': [
      const WorshipOccasion(
        title: 'ولادت امام موسی کاظم (ع)',
        category: WorshipOccasionCategory.celebration,
        recommendedAmal: 'زیارت حضرت باب الحوائج امام کاظم (ع)',
      )
    ],
    '2-20': [
      const WorshipOccasion(
        title: 'اربعین حسینی (چهلم شهادت حضرت سیدالشهدا ع)',
        category: WorshipOccasionCategory.mourning,
        recommendedAmal: 'قرائت زیارت اربعین و زیارت حضرت امام حسین (ع)',
        isReligiousHoliday: true,
      )
    ],
    '2-28': [
      const WorshipOccasion(
        title: 'رحلت خاتم الانبیاء حضرت محمد (ص) و شهادت امام حسن مجتبی (ع)',
        category: WorshipOccasionCategory.mourning,
        recommendedAmal: 'زیارت از راه دور حضرت رسول (ص) و زیارت حضرت امام حسن (ع)',
        isReligiousHoliday: true,
      )
    ],
    '2-29': [
      const WorshipOccasion(
        title: 'شهادت ثامن الحجج حضرت علی بن موسی الرضا (ع) (آخر صفر)',
        category: WorshipOccasionCategory.mourning,
        recommendedAmal: 'زیارت حضرت امام رضا (ع) و صلوات خاصه امام رضا',
        isReligiousHoliday: true,
      )
    ],

    // 3. Rabi al-Awwal
    '3-1': [
      const WorshipOccasion(
        title: 'لیلة المبیت (فداکاری امیرالمؤمنین ع)',
        category: WorshipOccasionCategory.worshipDeed,
        recommendedAmal: 'شکرگزاری و زیارت امیرالمؤمنین (ع)',
      )
    ],
    '3-8': [
      const WorshipOccasion(
        title: 'شهادت امام حسن عسکری (ع)',
        category: WorshipOccasionCategory.mourning,
        recommendedAmal: 'دعای عهد و زیارت امام حسن عسکری (ع)',
        isReligiousHoliday: true,
      )
    ],
    '3-9': [
      const WorshipOccasion(
        title: 'آغاز امامت و ولایت حضرت ولی‌عصر امام مهدی (عج)',
        category: WorshipOccasionCategory.celebration,
        recommendedAmal: 'زیارت حضرت صاحب‌الزمان (عج) و تجدید بیعت با امام زمان',
      )
    ],
    '3-12': [
      const WorshipOccasion(
        title: 'میلاد حضرت رسول اکرم (ص) (روایت اهل سنت) / آغاز هفته وحدت',
        category: WorshipOccasionCategory.celebration,
        recommendedAmal: 'ارسال صلوات بر پیامبر (ص) و تقویت وحدت اسلامی',
      )
    ],
    '3-17': [
      const WorshipOccasion(
        title: 'میلاد مسعود حضرت رسول اکرم (ص) و امام جعفر صادق (ع)',
        category: WorshipOccasionCategory.celebration,
        recommendedAmal: 'روزه داشتن (ثواب یک سال)، غسل، زیارت حضرت رسول و امیرالمؤمنین',
        isReligiousHoliday: true,
      )
    ],

    // 4. Rabi al-Thani
    '4-8': [
      const WorshipOccasion(
        title: 'ولادت با سعادت امام حسن عسکری (ع)',
        category: WorshipOccasionCategory.celebration,
        recommendedAmal: 'زیارت امام حسن عسکری (ع) و صدقه دادن',
      )
    ],
    '4-10': [
      const WorshipOccasion(
        title: 'وفات حضرت فاطمه معصومه (س)',
        category: WorshipOccasionCategory.mourning,
        recommendedAmal: 'زیارت حضرت معصومه (س) در قم یا از راه دور',
      )
    ],

    // 5. Jumada al-Awwal
    '5-5': [
      const WorshipOccasion(
        title: 'ولادت حضرت زینب کبری (س)',
        category: WorshipOccasionCategory.celebration,
        recommendedAmal: 'قرائت خطبه‌های حضرت زینب (س) و زیارت ایشان',
      )
    ],
    '5-13': [
      const WorshipOccasion(
        title: 'شهادت حضرت فاطمه زهرا (س) (روایت ۷۵ روز)',
        category: WorshipOccasionCategory.mourning,
        recommendedAmal: 'تسبیحات حضرت زهرا (س) و زیارتنامه ایشان',
      )
    ],

    // 6. Jumada al-Thani
    '6-3': [
      const WorshipOccasion(
        title: 'شهادت حضرت فاطمه زهرا (س) (فاطمیه دوم)',
        category: WorshipOccasionCategory.mourning,
        recommendedAmal: 'تسبیحات حضرت زهرا، زیارتنامه و اقامه عزای فاطمی',
        isReligiousHoliday: true,
      )
    ],
    '6-13': [
      const WorshipOccasion(
        title: 'وفات حضرت ام‌البنین (س) (روز تکریم مادران و همسران شهدا)',
        category: WorshipOccasionCategory.mourning,
        recommendedAmal: 'زیارت حضرت ام‌البنین (س) و هدیه فاتحه و صلوات به ایشان',
      )
    ],
    '6-20': [
      const WorshipOccasion(
        title: 'ولادت حضرت فاطمه زهرا (س) و روز زن',
        category: WorshipOccasionCategory.celebration,
        recommendedAmal: 'صلوات حضرت زهرا (س)، نیکی به مادر و تسبیحات',
      )
    ],

    // 7. Rajab
    '7-1': [
      const WorshipOccasion(
        title: 'ولادت امام محمد باقر (ع)',
        category: WorshipOccasionCategory.celebration,
        recommendedAmal: 'دعای استغفار ماه رجب و زیارت امام باقر (ع)',
      )
    ],
    '7-3': [
      const WorshipOccasion(
        title: 'شهادت امام علی النقی الهادی (ع)',
        category: WorshipOccasionCategory.mourning,
        recommendedAmal: 'زیارت جامعه کبیره (یادگار امام هادی ع)',
      )
    ],
    '7-10': [
      const WorshipOccasion(
        title: 'ولادت امام محمد تقی الجواد (ع)',
        category: WorshipOccasionCategory.celebration,
        recommendedAmal: 'زیارت امام جواد (ع) و دعای توسل',
      )
    ],
    '7-13': [
      const WorshipOccasion(
        title: 'ولادت امیرالمؤمنین امام علی (ع) / آغاز ایام البیض',
        category: WorshipOccasionCategory.celebration,
        recommendedAmal: 'زیارت امین‌الله، روزه گرفتن در ایام البیض (۱۳، ۱۴، ۱۵)',
        isReligiousHoliday: true,
      )
    ],
    '7-15': [
      const WorshipOccasion(
        title: 'وفات حضرت زینب (س) / اعمال ام داوود',
        category: WorshipOccasionCategory.worshipDeed,
        recommendedAmal: 'اعمال ام داوود، روزه داشتن و زیارت حضرت زینب (س)',
      )
    ],
    '7-25': [
      const WorshipOccasion(
        title: 'شهادت باب الحوائج امام موسی کاظم (ع)',
        category: WorshipOccasionCategory.mourning,
        recommendedAmal: 'زیارت حضرت امام موسی بن جعفر (ع)',
      )
    ],
    '7-27': [
      const WorshipOccasion(
        title: 'عید سعید مبعث حضرت رسول اکرم (ص)',
        category: WorshipOccasionCategory.celebration,
        recommendedAmal: 'روزه داشتن (از ۴ روز بسیار بافضیلت سال)، غسل و زیارت حضرت رسول',
        isReligiousHoliday: true,
      )
    ],

    // 8. Sha'ban
    '8-3': [
      const WorshipOccasion(
        title: 'ولادت حضرت اباعبدالله الحسین (ع)',
        category: WorshipOccasionCategory.celebration,
        recommendedAmal: 'زیارت حضرت امام حسین (ع) و مناجات شعبانیه',
      )
    ],
    '8-4': [
      const WorshipOccasion(
        title: 'ولادت حضرت ابوالفضل العباس (ع)',
        category: WorshipOccasionCategory.celebration,
        recommendedAmal: 'زیارت حضرت عباس (ع) و مناجات شعبانیه',
      )
    ],
    '8-5': [
      const WorshipOccasion(
        title: 'ولادت امام سجاد (ع)',
        category: WorshipOccasionCategory.celebration,
        recommendedAmal: 'قرائت دعای صحیفه سجادیه و مناجات شعبانیه',
      )
    ],
    '8-11': [
      const WorshipOccasion(
        title: 'ولادت حضرت علی اکبر (ع)',
        category: WorshipOccasionCategory.celebration,
        recommendedAmal: 'زیارت حضرت علی اکبر (ع)',
      )
    ],
    '8-15': [
      const WorshipOccasion(
        title: 'ولادت حضرت ولی‌عصر امام مهدی (عج) (نیمه شعبان)',
        category: WorshipOccasionCategory.celebration,
        recommendedAmal: 'احیای شب نیمه شعبان، دعای کمیل، زیارت امام حسین (ع)، دعای فرج',
        isReligiousHoliday: true,
      )
    ],

    // 9. Ramadan
    '9-1': [
      const WorshipOccasion(
        title: 'آغاز ماه مبارک رمضان (ماه نزول قرآن و روزه‌داری)',
        category: WorshipOccasionCategory.fasting,
        recommendedAmal: 'روزه واجب، قرائت قرآن، دعای افتتاح و غسل شب اول رمضان',
      )
    ],
    '9-10': [
      const WorshipOccasion(
        title: 'وفات ام‌المؤمنین حضرت خدیجه کبری (س)',
        category: WorshipOccasionCategory.mourning,
        recommendedAmal: 'زیارت حضرت خدیجه (س) و هدیه ثواب روزه به ایشان',
      )
    ],
    '9-15': [
      const WorshipOccasion(
        title: 'ولادت سبط اکبر امام حسن مجتبی (ع)',
        category: WorshipOccasionCategory.celebration,
        recommendedAmal: 'اطعام روزه‌داران و زیارت حضرت امام حسن (ع)',
      )
    ],
    '9-19': [
      const WorshipOccasion(
        title: 'ضربت خوردن امیرالمؤمنین (ع) / شب ۱۹ رمضان (اولین شب قدر)',
        category: WorshipOccasionCategory.worshipDeed,
        recommendedAmal: 'احیا، غسل، ۱۰۰ ركعت نماز، صد بار استغفار، زیارت امام حسین (ع) و قرآن بر سر گذاشتن',
      )
    ],
    '9-21': [
      const WorshipOccasion(
        title: 'شهادت امیرالمؤمنین امام علی (ع) / شب ۲۱ رمضان (دومین شب قدر)',
        category: WorshipOccasionCategory.mourning,
        recommendedAmal: 'احیای شب قدر، غسل، زیارت امیرالمؤمنین (ع)، دعای جوشن کبیر',
        isReligiousHoliday: true,
      )
    ],
    '9-23': [
      const WorshipOccasion(
        title: 'شب ۲۳ رمضان (مهم‌ترین شب قدر و نزول قرآن)',
        category: WorshipOccasionCategory.worshipDeed,
        recommendedAmal: 'احیا تا سپیده دم، سوره عنکبوت و روم و دخان، دعای سلامتی امام زمان (عج)',
      )
    ],

    '10-1': [
      const WorshipOccasion(
        title: 'عید سعید فطر (اول شوال)',
        category: WorshipOccasionCategory.celebration,
        recommendedAmal: 'نماز عید فطر، پرداخت زکات فطره، تکبیرات عید و غسل اول روز',
        isReligiousHoliday: true,
      )
    ],
    '10-2': [
      const WorshipOccasion(
        title: 'تعطیلی به مناسبت عید سعید فطر (روز دوم)',
        category: WorshipOccasionCategory.celebration,
        isReligiousHoliday: true,
      )
    ],
    '10-25': [
      const WorshipOccasion(
        title: 'شهادت رئیس مذهب جعفری امام جعفر صادق (ع)',
        category: WorshipOccasionCategory.mourning,
        recommendedAmal: 'زیارت امام جعفر صادق (ع) در بقیع و اقامه عزاداری',
        isReligiousHoliday: true,
      )
    ],

    // 11. Dhu al-Qadah
    '11-1': [
      const WorshipOccasion(
        title: 'ولادت حضرت فاطمه معصومه (س)',
        category: WorshipOccasionCategory.celebration,
        recommendedAmal: 'زیارت حضرت معصومه (س) و آغاز دهه کرامت',
      )
    ],
    '11-11': [
      const WorshipOccasion(
        title: 'ولادت با سعادت حضرت امام رضا (ع)',
        category: WorshipOccasionCategory.celebration,
        recommendedAmal: 'زیارت حضرت امام رضا (ع) و قرائت صلوات خاصه',
      )
    ],
    '11-25': [
      const WorshipOccasion(
        title: 'روز دحو الارض (پهن شدن زمین از زیر کعبه)',
        category: WorshipOccasionCategory.worshipDeed,
        recommendedAmal: 'روزه داشتن (ثواب ۷۰ سال روزه)، غسل، زیارت امام رضا و نماز دحو الارض',
      )
    ],
    '11-29': [
      const WorshipOccasion(
        title: 'شهادت حضرت امام محمد تقی الجواد (ع) (آخر ذی‌القعده)',
        category: WorshipOccasionCategory.mourning,
        recommendedAmal: 'زیارت حضرت امام جواد (ع) و توسل به حضرت باب‌الحوائج',
      )
    ],

    // 12. Dhu al-Hijjah
    '12-1': [
      const WorshipOccasion(
        title: 'سالروز ازدواج آسمانی حضرت علی (ع) و حضرت زهرا (س)',
        category: WorshipOccasionCategory.celebration,
        recommendedAmal: 'روزه داشتن و زیارت امیرالمؤمنین و حضرت زهرا (ع)',
      )
    ],
    '12-7': [
      const WorshipOccasion(
        title: 'شهادت امام محمد باقر (ع)',
        category: WorshipOccasionCategory.mourning,
        recommendedAmal: 'زیارت امام باقر (ع) و قرائت دعای توسل',
      )
    ],
    '12-9': [
      const WorshipOccasion(
        title: 'روز عرفه (روز نیایش و استغفار)',
        category: WorshipOccasionCategory.worshipDeed,
        recommendedAmal: 'دعای عرفه امام حسین (ع)، غسل، روزه (در صورت عدم ضعف از دعا)، زیارت امام حسین',
      )
    ],
    '12-10': [
      const WorshipOccasion(
        title: 'عید سعید قربان (عید الاضحی)',
        category: WorshipOccasionCategory.celebration,
        recommendedAmal: 'نماز عید قربان، غسل، قربانی کردن و تکبیرات عید',
        isReligiousHoliday: true,
      )
    ],
    '12-15': [
      const WorshipOccasion(
        title: 'ولادت امام علی النقی الهادی (ع)',
        category: WorshipOccasionCategory.celebration,
        recommendedAmal: 'زیارت جامعه کبیره و زیارت غدیریه',
      )
    ],
    '12-18': [
      const WorshipOccasion(
        title: 'عید سعید غدیر خم (عید الله الاکبر)',
        category: WorshipOccasionCategory.celebration,
        recommendedAmal: 'روزه (کفاره ۶۰ سال گناه)، غسل، عقد اخوت، اطعام مؤمنین، زیارت امین‌الله',
        isReligiousHoliday: true,
      )
    ],
    '12-24': [
      const WorshipOccasion(
        title: 'روز مباهله پیامبر اکرم (ص) و روز آیه تطهیر',
        category: WorshipOccasionCategory.celebration,
        recommendedAmal: 'غسل، روزه، دعای مباهله و زیارت امیرالمؤمنین (ع)',
      )
    ],
    '12-25': [
      const WorshipOccasion(
        title: 'روز نزول سوره هل اتی (حدیث کساء / روز خانواده)',
        category: WorshipOccasionCategory.worshipDeed,
        recommendedAmal: 'قرائت سوره هل اتی و حدیث کساء، تکریم خانواده',
      )
    ],
    '12-29': [
      const WorshipOccasion(
        title: 'آخرین روز سال هجری قمری / استغفار و محاسبه نفس',
        category: WorshipOccasionCategory.worshipDeed,
        recommendedAmal: 'دو ركعت نماز پایان سال قمری و استغفار',
      )
    ],
  };

  /// Map of Solar month-day (e.g. "1-1") to list of Iranian national occasions.
  static final Map<String, List<WorshipOccasion>> solarOccasions = {
    // 1. Farvardin (فروردین)
    '1-1': [
      const WorshipOccasion(
        title: 'جشن نوروز / آغاز سال نو',
        category: WorshipOccasionCategory.national,
        isHoliday: true,
      )
    ],
    '1-2': [
      const WorshipOccasion(
        title: 'عید نوروز (روز دوم)',
        category: WorshipOccasionCategory.national,
        isHoliday: true,
      )
    ],
    '1-3': [
      const WorshipOccasion(
        title: 'عید نوروز (روز سوم)',
        category: WorshipOccasionCategory.national,
        isHoliday: true,
      )
    ],
    '1-4': [
      const WorshipOccasion(
        title: 'عید نوروز (روز چهارم)',
        category: WorshipOccasionCategory.national,
        isHoliday: true,
      )
    ],
    '1-6': [
      const WorshipOccasion(
        title: 'زادروز زرتشت پیامبر',
        category: WorshipOccasionCategory.national,
      )
    ],
    '1-12': [
      const WorshipOccasion(
        title: 'روز جمهوری اسلامی ایران',
        category: WorshipOccasionCategory.national,
        isHoliday: true,
      )
    ],
    '1-13': [
      const WorshipOccasion(
        title: 'روز طبیعت (سیزده‌بدر)',
        category: WorshipOccasionCategory.national,
        isHoliday: true,
      )
    ],
    '1-18': [
      const WorshipOccasion(
        title: 'روز سلامتی (روز جهانی بهداشت)',
        category: WorshipOccasionCategory.national,
      )
    ],
    '1-25': [
      const WorshipOccasion(
        title: 'روز بزرگداشت عطار نیشابوری',
        category: WorshipOccasionCategory.national,
      )
    ],
    '1-29': [
      const WorshipOccasion(
        title: 'روز ارتش جمهوری اسلامی ایران و نیروی زمینی',
        category: WorshipOccasionCategory.national,
      )
    ],

    // 2. Ordibehesht (اردیبهشت)
    '2-1': [
      const WorshipOccasion(
        title: 'روز بزرگداشت سعدی شیرازی',
        category: WorshipOccasionCategory.national,
      )
    ],
    '2-2': [
      const WorshipOccasion(
        title: 'روز زمین پاک',
        category: WorshipOccasionCategory.national,
      )
    ],
    '2-3': [
      const WorshipOccasion(
        title: 'روز بزرگداشت شیخ بهایی / روز معمار',
        category: WorshipOccasionCategory.national,
      )
    ],
    '2-9': [
      const WorshipOccasion(
        title: 'روز شوراها',
        category: WorshipOccasionCategory.national,
      )
    ],
    '2-10': [
      const WorshipOccasion(
        title: 'روز ملی خلیج فارس',
        category: WorshipOccasionCategory.national,
      )
    ],
    '2-11': [
      const WorshipOccasion(
        title: 'روز جهانی کار و کارگر',
        category: WorshipOccasionCategory.national,
      )
    ],
    '2-12': [
      const WorshipOccasion(
        title: 'روز معلم / شهادت استاد مرتضی مطهری',
        category: WorshipOccasionCategory.national,
      )
    ],
    '2-15': [
      const WorshipOccasion(
        title: 'روز بزرگداشت شیخ صدوق / روز شیراز',
        category: WorshipOccasionCategory.national,
      )
    ],
    '2-25': [
      const WorshipOccasion(
        title: 'روز بزرگداشت حکیم فردوسی و پاسداشت زبان فارسی',
        category: WorshipOccasionCategory.national,
      )
    ],
    '2-28': [
      const WorshipOccasion(
        title: 'روز بزرگداشت حکیم عمر خیام نیشابوری',
        category: WorshipOccasionCategory.national,
      )
    ],

    // 3. Khordad (خرداد)
    '3-1': [
      const WorshipOccasion(
        title: 'روز بزرگداشت ملاصدرا (صدرالمتألهین)',
        category: WorshipOccasionCategory.national,
      )
    ],
    '3-3': [
      const WorshipOccasion(
        title: 'فتح خرمشهر در عملیات بیت‌المقدس / روز مقاومت و پیروزی',
        category: WorshipOccasionCategory.national,
      )
    ],
    '3-14': [
      const WorshipOccasion(
        title: 'رحلت حضرت امام خمینی (ره)',
        category: WorshipOccasionCategory.national,
        isHoliday: true,
      )
    ],
    '3-15': [
      const WorshipOccasion(
        title: 'قیام خونین ۱۵ خرداد',
        category: WorshipOccasionCategory.national,
        isHoliday: true,
      )
    ],
    '3-20': [
      const WorshipOccasion(
        title: 'روز ملی صنایع دستی',
        category: WorshipOccasionCategory.national,
      )
    ],
    '3-25': [
      const WorshipOccasion(
        title: 'روز ملی گل و گیاه',
        category: WorshipOccasionCategory.national,
      )
    ],

    // 4. Tir (تیر)
    '4-1': [
      const WorshipOccasion(
        title: 'روز اصناف',
        category: WorshipOccasionCategory.national,
      )
    ],
    '4-7': [
      const WorshipOccasion(
        title: 'شهادت آیت‌الله بهشتی و ۷۲ تن از یاران انقلاب / روز قوه قضائیه',
        category: WorshipOccasionCategory.national,
      )
    ],
    '4-8': [
      const WorshipOccasion(
        title: 'روز مبارزه با سلاح‌های شیمیایی و میکروبی',
        category: WorshipOccasionCategory.national,
      )
    ],
    '4-10': [
      const WorshipOccasion(
        title: 'روز صنعت و معدن',
        category: WorshipOccasionCategory.national,
      )
    ],
    '4-14': [
      const WorshipOccasion(
        title: 'روز قلم',
        category: WorshipOccasionCategory.national,
      )
    ],
    '4-25': [
      const WorshipOccasion(
        title: 'روز بهزیستی و تامین اجتماعی',
        category: WorshipOccasionCategory.national,
      )
    ],
    '4-27': [
      const WorshipOccasion(
        title: 'اعلام پذیرش قطعنامه ۵۹۸ شورای امنیت',
        category: WorshipOccasionCategory.national,
      )
    ],

    // 5. Mordad (مرداد)
    '5-6': [
      const WorshipOccasion(
        title: 'روز ترویج آموزش‌های فنی و حرفه‌ای',
        category: WorshipOccasionCategory.national,
      )
    ],
    '5-8': [
      const WorshipOccasion(
        title: 'روز بزرگداشت شیخ شهاب‌الدین سهروردی (شیخ اشراق)',
        category: WorshipOccasionCategory.national,
      )
    ],
    '5-14': [
      const WorshipOccasion(
        title: 'سالروز صدور فرمان مشروطیت / روز حقوق بشر اسلامی',
        category: WorshipOccasionCategory.national,
      )
    ],
    '5-17': [
      const WorshipOccasion(
        title: 'روز خبرنگار',
        category: WorshipOccasionCategory.national,
      )
    ],
    '5-26': [
      const WorshipOccasion(
        title: 'سالروز ورود آزادگان سرافراز به میهن اسلامی',
        category: WorshipOccasionCategory.national,
      )
    ],
    '5-28': [
      const WorshipOccasion(
        title: 'سالروز کودتای ۲۸ مرداد',
        category: WorshipOccasionCategory.national,
      )
    ],

    // 6. Shahrivar (شهریور)
    '6-1': [
      const WorshipOccasion(
        title: 'روز پزشک / بزرگداشت ابوعلی سینا',
        category: WorshipOccasionCategory.national,
      )
    ],
    '6-2': [
      const WorshipOccasion(
        title: 'آغاز هفته دولت (شهادت رجایی و باهنر)',
        category: WorshipOccasionCategory.national,
      )
    ],
    '6-4': [
      const WorshipOccasion(
        title: 'روز کارمند / جشن شهریورگان',
        category: WorshipOccasionCategory.national,
      )
    ],
    '6-5': [
      const WorshipOccasion(
        title: 'روز داروسازی / بزرگداشت زکریای رازی',
        category: WorshipOccasionCategory.national,
      )
    ],
    '6-8': [
      const WorshipOccasion(
        title: 'روز مبارزه با تروریسم (انفجار دفتر نخست‌وزیری)',
        category: WorshipOccasionCategory.national,
      )
    ],
    '6-13': [
      const WorshipOccasion(
        title: 'روز بزرگداشت ابوریحان بیرونی / روز علوم پایه',
        category: WorshipOccasionCategory.national,
      )
    ],
    '6-21': [
      const WorshipOccasion(
        title: 'روز ملی سینما',
        category: WorshipOccasionCategory.national,
      )
    ],
    '6-27': [
      const WorshipOccasion(
        title: 'روز شعر و ادب فارسی / بزرگداشت استاد شهریار',
        category: WorshipOccasionCategory.national,
      )
    ],
    '6-31': [
      const WorshipOccasion(
        title: 'آغاز هفته دفاع مقدس',
        category: WorshipOccasionCategory.national,
      )
    ],

    // 7. Mehr (مهر)
    '7-1': [
      const WorshipOccasion(
        title: 'آغاز سال تحصیلی و بازگشایی مدارس',
        category: WorshipOccasionCategory.national,
      )
    ],
    '7-7': [
      const WorshipOccasion(
        title: 'روز آتش‌نشانی و ایمنی',
        category: WorshipOccasionCategory.national,
      )
    ],
    '7-8': [
      const WorshipOccasion(
        title: 'روز بزرگداشت مولوی (جلال‌الدین بلخی)',
        category: WorshipOccasionCategory.national,
      )
    ],
    '7-13': [
      const WorshipOccasion(
        title: 'روز نیروی انتظامی',
        category: WorshipOccasionCategory.national,
      )
    ],
    '7-14': [
      const WorshipOccasion(
        title: 'روز دامپزشکی',
        category: WorshipOccasionCategory.national,
      )
    ],
    '7-15': [
      const WorshipOccasion(
        title: 'روز روستا و عشایر',
        category: WorshipOccasionCategory.national,
      )
    ],
    '7-20': [
      const WorshipOccasion(
        title: 'روز بزرگداشت حافظ شیرازی',
        category: WorshipOccasionCategory.national,
      )
    ],
    '7-26': [
      const WorshipOccasion(
        title: 'روز تربیت بدنی و ورزش',
        category: WorshipOccasionCategory.national,
      )
    ],

    // 8. Aban (آبان)
    '8-7': [
      const WorshipOccasion(
        title: 'روز بزرگداشت کوروش بزرگ',
        category: WorshipOccasionCategory.national,
      )
    ],
    '8-8': [
      const WorshipOccasion(
        title: 'روز نوجوان و بسیج دانش‌آموزی (شهادت حسین فهمیده)',
        category: WorshipOccasionCategory.national,
      )
    ],
    '8-10': [
      const WorshipOccasion(
        title: 'روز بزرگداشت ابوالفضل بیهقی / جشن آبان‌گان',
        category: WorshipOccasionCategory.national,
      )
    ],
    '8-13': [
      const WorshipOccasion(
        title: 'روز دانش‌آموز / روز مبارزه با استکبار جهانی',
        category: WorshipOccasionCategory.national,
      )
    ],
    '8-24': [
      const WorshipOccasion(
        title: 'روز کتاب، کتابخوانی و کتابدار / بزرگداشت علامه طباطبایی',
        category: WorshipOccasionCategory.national,
      )
    ],

    // 9. Azar (آذر)
    '9-7': [
      const WorshipOccasion(
        title: 'روز نیروی دریایی',
        category: WorshipOccasionCategory.national,
      )
    ],
    '9-9': [
      const WorshipOccasion(
        title: 'جشن آذرگان',
        category: WorshipOccasionCategory.national,
      )
    ],
    '9-10': [
      const WorshipOccasion(
        title: 'روز مجلس / شهادت آیت‌الله مدرس',
        category: WorshipOccasionCategory.national,
      )
    ],
    '9-12': [
      const WorshipOccasion(
        title: 'روز قانون اساسی جمهوری اسلامی ایران',
        category: WorshipOccasionCategory.national,
      )
    ],
    '9-16': [
      const WorshipOccasion(
        title: 'روز دانشجو',
        category: WorshipOccasionCategory.national,
      )
    ],
    '9-25': [
      const WorshipOccasion(
        title: 'روز پژوهش',
        category: WorshipOccasionCategory.national,
      )
    ],
    '9-26': [
      const WorshipOccasion(
        title: 'روز حمل و نقل',
        category: WorshipOccasionCategory.national,
      )
    ],
    '9-30': [
      const WorshipOccasion(
        title: 'شب یلدا (طولانی‌ترین شب سال / جشن چله)',
        category: WorshipOccasionCategory.national,
      )
    ],

    // 10. Dey (دی)
    '10-1': [
      const WorshipOccasion(
        title: 'جشن خرم‌روز (نخستین جشن دی‌گان)',
        category: WorshipOccasionCategory.national,
      )
    ],
    '10-5': [
      const WorshipOccasion(
        title: 'روز ایمنی در برابر زلزله و کاهش اثرات بلایای طبیعی',
        category: WorshipOccasionCategory.national,
      )
    ],
    '10-13': [
      const WorshipOccasion(
        title: 'روز جهانی مقاومت (شهادت سردار حاج قاسم سلیمانی)',
        category: WorshipOccasionCategory.national,
      )
    ],
    '10-16': [
      const WorshipOccasion(
        title: 'روز شهدای دانشجو (شهادت علم‌الهدی و یاران)',
        category: WorshipOccasionCategory.national,
      )
    ],
    '10-19': [
      const WorshipOccasion(
        title: 'قیام خونین مردم قم در سال ۱۳۵۶',
        category: WorshipOccasionCategory.national,
      )
    ],
    '10-22': [
      const WorshipOccasion(
        title: 'تشکیل شورای انقلاب به فرمان امام خمینی (ره)',
        category: WorshipOccasionCategory.national,
      )
    ],

    // 11. Bahman (بهمن)
    '11-12': [
      const WorshipOccasion(
        title: 'بازگشت حضرت امام خمینی (ره) به میهن و آغاز دهه فجر',
        category: WorshipOccasionCategory.national,
      )
    ],
    '11-14': [
      const WorshipOccasion(
        title: 'روز فناوری فضایی',
        category: WorshipOccasionCategory.national,
      )
    ],
    '11-19': [
      const WorshipOccasion(
        title: 'روز نیروی هوایی (بیعت همافران با امام خمینی)',
        category: WorshipOccasionCategory.national,
      )
    ],
    '11-22': [
      const WorshipOccasion(
        title: 'سالروز پیروزی انقلاب اسلامی ایران',
        category: WorshipOccasionCategory.national,
        isHoliday: true,
      )
    ],
    '11-29': [
      const WorshipOccasion(
        title: 'قیام مردم تبریز به مناسبت چهلم شهدای قم',
        category: WorshipOccasionCategory.national,
      )
    ],

    // 12. Esfand (اسفند)
    '12-5': [
      const WorshipOccasion(
        title: 'روز مهندس / بزرگداشت خواجه نصیرالدین طوسی',
        category: WorshipOccasionCategory.national,
      )
    ],
    '12-15': [
      const WorshipOccasion(
        title: 'روز درختکاری و آغاز هفته منابع طبیعی',
        category: WorshipOccasionCategory.national,
      )
    ],
    '12-22': [
      const WorshipOccasion(
        title: 'روز بزرگداشت شهدا',
        category: WorshipOccasionCategory.national,
      )
    ],
    '12-25': [
      const WorshipOccasion(
        title: 'روز بزرگداشت پروین اعتصامی / پایان سرایش شاهنامه',
        category: WorshipOccasionCategory.national,
      )
    ],
    '12-29': [
      const WorshipOccasion(
        title: 'روز ملی شدن صنعت نفت ایران',
        category: WorshipOccasionCategory.national,
        isHoliday: true,
      )
    ],
    '12-30': [
      const WorshipOccasion(
        title: 'آخرین روز سال (تعطیل رسمی در سال‌های کبیسه)',
        category: WorshipOccasionCategory.national,
        isHoliday: true,
      )
    ],
  };

  /// Daily Zikr of the week (ذکر روز هفته)
  static String getDailyZikr(int weekday) {
    switch (weekday) {
      case DateTime.saturday:
        return 'یا رَبَّ الْعالَمین (۱۰۰ مرتبه)';
      case DateTime.sunday:
        return 'یا ذَا الْجَلالِ وَ الْإِكْرام (۱۰۰ مرتبه)';
      case DateTime.monday:
        return 'یا قاضِیَ الْحاجات (۱۰۰ مرتبه)';
      case DateTime.tuesday:
        return 'یا أَرْحَمَ الرّاحِمین (۱۰۰ مرتبه)';
      case DateTime.wednesday:
        return 'یا حَیُّ یا قَیّوم (۱۰۰ مرتبه)';
      case DateTime.thursday:
        return 'لا إِلهَ إِلَّا اللهُ الْمَلِكُ الْحَقُّ الْمُبین (۱۰۰ مرتبه)';
      case DateTime.friday:
        return 'اللّهُمَّ صَلِّ عَلی مُحَمَّدٍ وَ آلِ مُحَمَّدٍ وَ عَجِّلْ فَرَجَهُمْ (۱۰۰ مرتبه)';
      default:
        return 'ذکر روز هفته';
    }
  }

  /// Returns worship and national occasions for a given solar date and Hijri date.
  static List<WorshipOccasion> getOccasionsForDay(Jalali solar, HijriDate hijri) {
    final list = <WorshipOccasion>[];

    // 1. Solar / National Occasions
    final sKey = '${solar.month}-${solar.day}';
    if (solarOccasions.containsKey(sKey)) {
      list.addAll(solarOccasions[sKey]!);
    }

    // 2. Hijri / Religious Occasions
    final daysInMonth = HijriCalendarCalculator.daysInMonth(hijri.year, hijri.month);
    final isLastDay = hijri.day == daysInMonth;

    // Last day of month special handling for 2-29 (End of Safar), 11-29 (End of Dhu al-Qadah), 12-29 (End of Dhu al-Hijjah)
    if (hijri.day == 29 && daysInMonth == 30 && (hijri.month == 2 || hijri.month == 11 || hijri.month == 12)) {
      // In a 30-day month, day 29 is NOT the last day, so do not trigger last-day occasions on day 29
    } else if (isLastDay && daysInMonth == 30 && (hijri.month == 2 || hijri.month == 11 || hijri.month == 12)) {
      final key29 = '${hijri.month}-29';
      if (hijriOccasions.containsKey(key29)) {
        list.addAll(hijriOccasions[key29]!);
      }
    } else {
      final hKey = '${hijri.month}-${hijri.day}';
      if (hijriOccasions.containsKey(hKey)) {
        list.addAll(hijriOccasions[hKey]!);
      }
    }

    return list;
  }
}
