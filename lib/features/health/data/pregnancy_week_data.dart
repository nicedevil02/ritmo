class PregnancyWeekInfo {
  final String size;
  final String development;
  final String tip;
  final String? babySizeFa;
  final String? babyWeightFa;
  final String? symptomsFa;

  const PregnancyWeekInfo({
    required this.size,
    required this.development,
    required this.tip,
    this.babySizeFa,
    this.babyWeightFa,
    this.symptomsFa,
  });

  Map<String, String> toMap() => {
    'size': size,
    'development': development,
    'tip': tip,
  };
}

final Map<int, PregnancyWeekInfo> pregnancyWeekData = {
  4: const PregnancyWeekInfo(size: 'به اندازه یک دانه خشخاش', development: 'لانه‌گزینی جنین در رحم', tip: 'تغذیه سالم، نوشیدن آب کافی و استراحت را در اولویت قرار دهید', babySizeFa: 'دانه خشخاش', babyWeightFa: '< ۱ گرم', symptomsFa: 'حس خستگی ملایم'),
  5: const PregnancyWeekInfo(size: 'به اندازه یک دانه کنجد', development: 'قلب شروع به تپیدن می‌کند', tip: 'از مصرف کافئین زیاد خودداری کنید', babySizeFa: 'دانه کنجد', babyWeightFa: '< ۱ گرم'),
  6: const PregnancyWeekInfo(size: 'به اندازه یک دانه عدس', development: 'صورت در حال شکل‌گیری است', tip: 'استراحت کافی داشته باشید', babySizeFa: 'دانه عدس', babyWeightFa: '< ۱ گرم'),
  8: const PregnancyWeekInfo(size: 'به اندازه یک تمشک', development: 'انگشتان دست شکل گرفته‌اند', tip: 'غذاهای سرشار از آهن طبیعی مصرف کنید', babySizeFa: 'تمشک', babyWeightFa: '۱ گرم'),
  10: const PregnancyWeekInfo(size: 'به اندازه یک زیتون', development: 'اندام‌های حیاتی تشکیل شده‌اند', tip: 'پیاده‌روی روزانه ملایم را فراموش نکنید', babySizeFa: 'زیتون', babyWeightFa: '۴ گرم'),
  12: const PregnancyWeekInfo(size: 'به اندازه یک آلو', development: 'ناخن‌ها رشد می‌کنند', tip: 'ویزیت دوم پزشک و انجام غربالگری اول', babySizeFa: 'آلو', babyWeightFa: '۱۴ گرم'),
  14: const PregnancyWeekInfo(size: 'به اندازه یک لیمو', development: 'جنین می‌تواند اخم کند', tip: 'حالت تهوع معمولاً کاهش می‌یابد', babySizeFa: 'لیمو', babyWeightFa: '۴۵ گرم'),
  16: const PregnancyWeekInfo(size: 'به اندازه یک آووکادو', development: 'جنین حرکات خود را حس می‌کند', tip: 'شاید اولین لگد را حس کنید!', babySizeFa: 'آووکادو', babyWeightFa: '۱۰۰ گرم'),
  18: const PregnancyWeekInfo(size: 'به اندازه یک فلفل دلمه‌ای', development: 'گوش‌ها کامل شده‌اند', tip: 'با جنین حرف بزنید، صدایتان را می‌شنود', babySizeFa: 'فلفل دلمه‌ای', babyWeightFa: '۱۹۰ گرم'),
  20: const PregnancyWeekInfo(size: 'به اندازه یک موز', development: 'نیمه راه! جنسیت قابل تشخیص', tip: 'سونوگرافی آنومالی و غربالگری دوم', babySizeFa: 'موز', babyWeightFa: '۳۰۰ گرم'),
  22: const PregnancyWeekInfo(size: 'به اندازه یک بلال ذرت', development: 'ابروها و مژه‌ها رشد کرده‌اند', tip: 'ورزش‌های کگل را شروع کنید', babySizeFa: 'بلال ذرت', babyWeightFa: '۴۳۰ گرم'),
  24: const PregnancyWeekInfo(size: 'به اندازه یک بادمجان', development: 'ریه‌ها در حال بلوغ هستند', tip: 'تست قند بارداری انجام دهید', babySizeFa: 'بادمجان', babyWeightFa: '۶۰۰ گرم'),
  26: const PregnancyWeekInfo(size: 'به اندازه یک کلم بروکلی', development: 'چشم‌ها باز می‌شوند', tip: 'خواب به پهلوی چپ را عادت کنید', babySizeFa: 'کلم بروکلی', babyWeightFa: '۷۶۰ گرم'),
  28: const PregnancyWeekInfo(size: 'به اندازه یک کدو حلوایی کوچک', development: 'مغز به‌سرعت رشد می‌کند', tip: 'شمارش حرکات جنین را شروع کنید', babySizeFa: 'کدو حلوایی کوچک', babyWeightFa: '۱۰۰۰ گرم'),
  30: const PregnancyWeekInfo(size: 'به اندازه یک کاهو', development: 'جنین وضعیت سر پایین می‌گیرد', tip: 'کلاس آمادگی زایمان را در نظر بگیرید', babySizeFa: 'کاهو', babyWeightFa: '۱۳۰۰ گرم'),
  32: const PregnancyWeekInfo(size: 'به اندازه یک نارگیل', development: 'ناخن‌های پا رشد کرده‌اند', tip: 'ساک بیمارستان را آماده کنید', babySizeFa: 'نارگیل', babyWeightFa: '۱۷۰۰ گرم'),
  34: const PregnancyWeekInfo(size: 'به اندازه یک طالبی', development: 'سیستم ایمنی فعال شده', tip: 'استراحت بیشتر و استفاده از بالش بارداری', babySizeFa: 'طالبی', babyWeightFa: '۲۱۰۰ گرم'),
  36: const PregnancyWeekInfo(size: 'به اندازه یک هندوانه کوچک', development: 'جنین تقریباً کامل است', tip: 'ویزیت‌ها هفتگی می‌شوند', babySizeFa: 'هندوانه کوچک', babyWeightFa: '۲۶۰۰ گرم'),
  38: const PregnancyWeekInfo(size: 'به اندازه یک کدو تنبل', development: 'ریه‌ها بالغ شده‌اند', tip: 'علائم شروع زایمان را بشناسید', babySizeFa: 'کدو تنبل', babyWeightFa: '۳۰۰۰ گرم'),
  40: const PregnancyWeekInfo(size: 'به اندازه یک هندوانه', development: 'آماده تولد! 🎉', tip: 'صبور باشید، نوبتش می‌رسد', babySizeFa: 'هندوانه', babyWeightFa: '۳۴۰۰ گرم'),
};
