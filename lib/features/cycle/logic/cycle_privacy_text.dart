/// تک‌منبعِ همهٔ متن‌هایی که ممکن است بیرون از بخش قفل‌شده دیده شوند.
/// هیچ‌کدام نباید واژهٔ صریح داشته باشند.
abstract final class CyclePrivacyText {
  // سطح سیستم‌عامل — روی قفل‌صفحه و در سایهٔ اعلان
  static const String osPublicTitle = 'ریتمو';
  static const String osPublicBody = 'یک یادآوری خصوصی دارید';

  // عنوان مبهم‌شدهٔ اعلان
  static const String osRedactedTitle = 'ریتمو: یادآوری خصوصی 🌸';
  static const String osRedactedBody = 'برای مشاهده باز کنید';

  // عنوان‌های داخلی — بدون واژهٔ صریح
  static const String leadReminderTitle = 'یادآور ریتم بدنی';
  static String leadReminderBody(int days) =>
      'تا شروع پنجرهٔ ریتم بدنی حدود $days روز مانده است.';

  static const String startConfirmTitle = 'بازبینی ریتم بدنی';
  static const String startConfirmBody =
      'امروز موعد تخمینی آغاز پنجرهٔ ریتم بدنی است. برای تأیید یا اصلاح، باز کنید.';

  static const String endConfirmTitle = 'بازبینی ریتم بدنی';
  static const String endConfirmBody =
      'بر اساس میانگین شما، پنجرهٔ فعلی احتمالاً به پایان رسیده است. برای تأیید، باز کنید.';

  static const String prolongedTitle = 'بازبینی ریتم بدنی';
  static const String prolongedBody =
      'پنجرهٔ فعلی طولانی‌تر از میانگین شما شده است. برای بررسی، باز کنید.';

  // متن ماسک‌شدهٔ صندوق پیام پیش از احراز هویت
  static const String inboxMaskedTitle = 'یادآوری خصوصی';
  static const String inboxMaskedBody = 'برای مشاهده، هویت خود را تأیید کنید.';
}
